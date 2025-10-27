#!/usr/bin/env bash
# harborSim_smoke_test.sh — end-to-end smoke test for ilminate-harborsim
# Safe to re-run; no edits to ilminate.com or apex.ilminate.com.

set -euo pipefail

# ---------- CONFIG & CHECKS ----------
ROOT_DIR="$(pwd)"
TF_DIR="${ROOT_DIR}/infra/terraform"
REGION="${AWS_REGION:-us-east-1}"
PROFILE_OPT=""
if [[ -n "${AWS_PROFILE:-}" ]]; then PROFILE_OPT="--profile ${AWS_PROFILE}"; fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }
need aws
need jq
need terraform

if [[ ! -d "${TF_DIR}" ]]; then
  echo "ERROR: Terraform dir not found at ${TF_DIR}"
  exit 1
fi

echo "==> Using AWS region: ${REGION}"
[[ -n "${AWS_PROFILE:-}" ]] && echo "==> Using AWS profile: ${AWS_PROFILE}"

# ---------- READ TERRAFORM OUTPUTS ----------
echo "==> Reading Terraform outputs…"
pushd "${TF_DIR}" >/dev/null
TF_JSON=$(terraform output -json || true)

if [[ -z "${TF_JSON}" || "${TF_JSON}" == "null" ]]; then
  echo "ERROR: No Terraform outputs found. Run: (cd infra/terraform && terraform init && terraform apply)"
  exit 1
fi

RAW_BUCKET=$(echo "${TF_JSON}" | jq -r '.raw_bucket.value // empty')
SAN_BUCKET=$(echo "${TF_JSON}" | jq -r '.sanitized_bucket.value // empty')
DDB_TABLE=$(echo "${TF_JSON}" | jq -r '.ddb_table.value // empty')
STATE_MACHINE_ARN=$(echo "${TF_JSON}" | jq -r '.state_machine_arn.value // empty')
popd >/dev/null

# Fallbacks if outputs weren't defined (try conventional names)
RAW_BUCKET="${RAW_BUCKET:-ilminate-harborsim-raw}"
SAN_BUCKET="${SAN_BUCKET:-ilminate-harborsim-sanitized}"
DDB_TABLE="${DDB_TABLE:-ilminate-harborsim-templates}"

if [[ -z "${STATE_MACHINE_ARN}" || "${STATE_MACHINE_ARN}" == "null" ]]; then
  echo "WARN: No state machine ARN in outputs. Attempting discovery…"
  STATE_MACHINE_ARN=$(aws stepfunctions list-state-machines --region "${REGION}" ${PROFILE_OPT} \
    --query "stateMachines[?contains(name, 'ilminate-harborsim')].stateMachineArn | [0]" --output text || true)
fi

if [[ -z "${STATE_MACHINE_ARN}" || "${STATE_MACHINE_ARN}" == "None" ]]; then
  echo "ERROR: Could not resolve Step Functions state machine ARN."
  echo "Tip: aws stepfunctions list-state-machines --region ${REGION} ${PROFILE_OPT}"
  exit 1
fi

echo "==> RAW_BUCKET:        ${RAW_BUCKET}"
echo "==> SANITIZED_BUCKET:  ${SAN_BUCKET}"
echo "==> DDB_TABLE:         ${DDB_TABLE}"
echo "==> STATE_MACHINE_ARN: ${STATE_MACHINE_ARN}"

# ---------- VERIFY BUCKETS EXIST ----------
echo "==> Verifying buckets exist…"
aws s3 ls "s3://${RAW_BUCKET}" ${PROFILE_OPT} >/dev/null || { echo "Missing bucket: ${RAW_BUCKET}"; exit 1; }
aws s3 ls "s3://${SAN_BUCKET}" ${PROFILE_OPT} >/dev/null || { echo "Missing bucket: ${SAN_BUCKET}"; exit 1; }

# ---------- UPLOAD BASE TEMPLATE & RULES ----------
echo "==> Uploading base template and rules…"
aws s3 cp services/harborsim/templates/base.mjml \
  "s3://${SAN_BUCKET}/templates/base.mjml" --region "${REGION}" ${PROFILE_OPT}

aws s3 cp services/harborsim/rules/url_rewrite.yaml \
  "s3://${RAW_BUCKET}/rules/url_rewrite.yaml" --region "${REGION}" ${PROFILE_OPT}

echo "==> Verifying uploads…"
aws s3 ls "s3://${SAN_BUCKET}/templates/" ${PROFILE_OPT}
aws s3 ls "s3://${RAW_BUCKET}/rules/" ${PROFILE_OPT}

# ---------- UPLOAD SAMPLE EML ----------
echo "==> Uploading sample EML…"
INCOMING_KEY="incoming/sample.eml"
aws s3 cp services/harborsim/tests/fixtures/sample_attack.eml \
  "s3://${RAW_BUCKET}/${INCOMING_KEY}" --region "${REGION}" ${PROFILE_OPT}

aws s3 ls "s3://${RAW_BUCKET}/incoming/" ${PROFILE_OPT}

# ---------- START PIPELINE ----------
echo "==> Starting HarborSim pipeline…"
EXEC_JSON=$(aws stepfunctions start-execution --region "${REGION}" ${PROFILE_OPT} \
  --state-machine-arn "${STATE_MACHINE_ARN}" \
  --input "{\"s3_key\":\"${INCOMING_KEY}\"}")

EXEC_ARN=$(echo "${EXEC_JSON}" | jq -r '.executionArn')
echo "==> Execution ARN: ${EXEC_ARN}"

# ---------- POLL FOR COMPLETION ----------
echo "==> Polling execution status (up to ~3 minutes)…"
ATTEMPTS=36
SLEEP=5
STATUS="RUNNING"
while (( ATTEMPTS-- > 0 )); do
  DESC=$(aws stepfunctions describe-execution --execution-arn "${EXEC_ARN}" --region "${REGION}" ${PROFILE_OPT})
  STATUS=$(echo "${DESC}" | jq -r '.status')
  echo "   - status: ${STATUS}"
  if [[ "${STATUS}" != "RUNNING" ]]; then break; fi
  sleep "${SLEEP}"
done

if [[ "${STATUS}" != "SUCCEEDED" ]]; then
  echo "ERROR: Execution finished with status: ${STATUS}"
  echo "==> Recent history:"
  aws stepfunctions get-execution-history --execution-arn "${EXEC_ARN}" --region "${REGION}" ${PROFILE_OPT} \
    --max-items 50 --query "events[].{id:id,timestamp:timestamp,type:type,detail:executionFailedEventDetails||taskFailedEventDetails}" --output table || true
  echo "==> Consider checking Lambda logs with the commands at the bottom of this script."
  exit 1
fi

# ---------- PARSE OUTPUT & INSPECT ARTIFACTS ----------
OUT=$(aws stepfunctions describe-execution --execution-arn "${EXEC_ARN}" --region "${REGION}" ${PROFILE_OPT} --query "output" --output text)
# Some integrations double-encode JSON; try to parse if present
TEMPLATE_ID=$(echo "${OUT}" | jq -r 'try fromjson | .template_id // .templateMeta?.template_id // empty' 2>/dev/null || true)
S3_KEY=$(echo "${OUT}" | jq -r 'try fromjson | .s3_key // .templateMeta?.s3_key // empty' 2>/dev/null || true)

echo "==> Execution output (raw): ${OUT}"
echo "==> Parsed template_id: ${TEMPLATE_ID:-<unknown>}"
echo "==> Parsed s3_key:      ${S3_KEY:-<unknown>}"

echo "==> Listing sanitized templates:"
aws s3 ls "s3://${SAN_BUCKET}/templates/" ${PROFILE_OPT}

if [[ -n "${TEMPLATE_ID:-}" && "${TEMPLATE_ID}" != "null" ]]; then
  echo "==> Attempting to fetch DynamoDB record for ${TEMPLATE_ID}"
  aws dynamodb get-item --region "${REGION}" ${PROFILE_OPT} \
    --table-name "${DDB_TABLE}" \
    --key "{\"TemplateId\": {\"S\":\"${TEMPLATE_ID}\"}}" \
    --output json || true

  # Download the produced template (file may be MJML per scaffold)
  echo "==> Attempting to download produced template to ./out.mjml (if present)"
  aws s3 cp "s3://${SAN_BUCKET}/templates/${TEMPLATE_ID}.mjml" ./out.mjml ${PROFILE_OPT} --region "${REGION}" || true
fi

# ---------- QUICK LOG VIEWERS ----------
echo
echo "==== Quick log viewers (run as needed) ===="
echo "# Normalize:"
echo "aws logs filter-log-events --log-group-name \"/aws/lambda/ilminate-harborsim-normalize\"   ${PROFILE_OPT} --region ${REGION} --query \"events[].message\" --output text | tail -n 50"
echo "# Deweaponize:"
echo "aws logs filter-log-events --log-group-name \"/aws/lambda/ilminate-harborsim-deweaponize\" ${PROFILE_OPT} --region ${REGION} --query \"events[].message\" --output text | tail -n 50"
echo "# Attachments:"
echo "aws logs filter-log-events --log-group-name \"/aws/lambda/ilminate-harborsim-attachments\"  ${PROFILE_OPT} --region ${REGION} --query \"events[].message\" --output text | tail -n 50"
echo "# PII:"
echo "aws logs filter-log-events --log-group-name \"/aws/lambda/ilminate-harborsim-pii\"          ${PROFILE_OPT} --region ${REGION} --query \"events[].message\" --output text | tail -n 50"
echo "# Template:"
echo "aws logs filter-log-events --log-group-name \"/aws/lambda/ilminate-harborsim-template\"     ${PROFILE_OPT} --region ${REGION} --query \"events[].message\" --output text | tail -n 50"

echo
echo "==== Done ===="
echo "If the state machine SUCCEEDED and you see a new file under s3://${SAN_BUCKET}/templates/, HarborSim's E2E path is healthy."

