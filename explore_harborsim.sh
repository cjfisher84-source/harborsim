#!/usr/bin/env bash
# explore_harborsim.sh - Interactive exploration of HarborSim

set -euo pipefail

RAW_BUCKET="ilminate-harborsim-raw"
SAN_BUCKET="ilminate-harborsim-sanitized"
DDB_TABLE="ilminate-harborsim-templates"
REGION="us-east-1"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         HarborSim - Interactive Explorer                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# 1. Show what's in the raw bucket (original emails)
echo "📦 RAW EMAIL STORAGE:"
echo "   s3://${RAW_BUCKET}/incoming/"
aws s3 ls s3://${RAW_BUCKET}/incoming/ --region ${REGION} || echo "   (empty)"
echo ""

# 2. Show what's in sanitized bucket (safe templates)
echo "✅ SANITIZED TEMPLATES:"
echo "   s3://${SAN_BUCKET}/templates/"
aws s3 ls s3://${SAN_BUCKET}/templates/ --region ${REGION}
echo ""

# 3. Show DynamoDB records
echo "🗄️  TEMPLATE METADATA (DynamoDB):"
aws dynamodb scan --table-name ${DDB_TABLE} --region ${REGION} --output json | \
  jq -r '.Items[] | "   ID: \(.TemplateId.S)\n   Subject: \(.Subject.S)\n   Created: \(.CreatedAt.S)\n"'
echo ""

# 4. Latest Step Functions execution
echo "🔄 LATEST STEP FUNCTIONS EXECUTION:"
LATEST_EXEC=$(aws stepfunctions list-executions \
  --state-machine-arn "arn:aws:states:us-east-1:657258631769:stateMachine:ilminate-harborsim-pipeline" \
  --region ${REGION} \
  --max-items 1 --output json | jq -r '.executions[0].executionArn')

if [[ -n "${LATEST_EXEC}" && "${LATEST_EXEC}" != "null" ]]; then
  STATUS=$(aws stepfunctions describe-execution --execution-arn "${LATEST_EXEC}" --region ${REGION} --query "status" --output text)
  echo "   Status: ${STATUS}"
  echo "   ARN: ${LATEST_EXEC}"
  echo ""
  echo "   View in console:"
  EXEC_ID=$(basename "${LATEST_EXEC}")
  echo "   https://console.aws.amazon.com/states/home?region=${REGION}#/executions/details/${EXEC_ID}"
else
  echo "   (No executions yet)"
fi
echo ""

# 5. View a generated template (if exists)
LATEST_TEMPLATE=$(aws s3 ls s3://${SAN_BUCKET}/templates/ --region ${REGION} | \
  grep -v "base.mjml" | tail -1 | awk '{print $4}')

if [[ -n "${LATEST_TEMPLATE}" ]]; then
  echo "📄 LATEST GENERATED TEMPLATE:"
  echo "   File: ${LATEST_TEMPLATE}"
  echo "   Content:"
  aws s3 cp "s3://${SAN_BUCKET}/templates/${LATEST_TEMPLATE}" - --region ${REGION} 2>/dev/null | cat
fi
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Quick Commands:                                           ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  Run smoke test again:     ./harborSim_smoke_test.sh     ║"
echo "║  View all Lambda logs:     See script for commands        ║"
echo "║  Upload new email:          (upload to incoming/)        ║"
echo "╚════════════════════════════════════════════════════════════╝"

