# HarborSim — Convert Real Phishing Attacks into Safe Training Templates

**HarborSim** is a serverless pipeline that transforms live phishing emails into PII-free, deweaponized training templates for security awareness programs.

> **IMPORTANT**
> • New standalone repo: `ilminate-harborsim` — does **not** touch `ilminate.com` or `apex.ilminate.com`.
> • Default AWS region uses `${AWS_REGION}`; set via env or Terraform variables.
> • All originals are quarantined; only sanitized templates are published.
> • No external calls to LLMs; optional local model hooks are stubbed.

---

## Architecture

HarborSim uses AWS Step Functions to orchestrate five Lambda functions:

1. **Normalize** — Parse raw EML files and extract HTML content
2. **Deweaponize** — Remove dangerous elements (hrefs, URLs, scripts, forms)
3. **Attachments** — Scan and flatten attachments (stub for future ClamAV integration)
4. **PII** — Redact personally identifiable information using Presidio
5. **Template** — Generate final MJML template and persist to S3/DynamoDB

### Infrastructure

- **S3 Buckets**: `ilminate-harborsim-raw` (quarantine) + `ilminate-harborsim-sanitized` (published)
- **DynamoDB**: Template metadata with global secondary index on `CreatedAt`
- **SQS**: Ingest queue for triggering pipeline
- **KMS**: Encryption at rest for all data
- **Step Functions**: Orchestration pipeline
- **Lambda**: Five functions with shared IAM role

---

## Quick Start

### 1. Bootstrap Environment

```bash
bash setup.sh
source .venv/bin/activate
```

### 2. Package Lambda Functions

```bash
make package
```

This creates five ZIP files under `dist/`:
- `harborsim-normalize.zip`
- `harborsim-deweaponize.zip`
- `harborsim-attachments.zip`
- `harborsim-pii.zip`
- `harborsim-template.zip`

### 3. Deploy Infrastructure

```bash
# Set AWS region (optional, defaults to us-east-1)
export AWS_REGION=us-east-1

# Plan deployment
make plan

# Apply deployment
make apply
```

### 4. Upload Base Template and Rules

After deployment, upload the base template and rules to S3:

```bash
# Upload base MJML template
aws s3 cp services/harborsim/templates/base.mjml \
  s3://ilminate-harborsim-sanitized/templates/base.mjml

# Upload URL rewrite rules
aws s3 cp services/harborsim/rules/url_rewrite.yaml \
  s3://ilminate-harborsim-raw/rules/url_rewrite.yaml
```

### 5. Test the Pipeline

```bash
# Upload a test EML file
aws s3 cp services/harborsim/tests/fixtures/sample_attack.eml \
  s3://ilminate-harborsim-raw/incoming/sample.eml

# Start the Step Functions pipeline manually
aws stepfunctions start-execution \
  --state-machine-arn <ARN_FROM_OUTPUT> \
  --input '{"s3_key": "incoming/sample.eml"}'

# Check the sanitized bucket for output
aws s3 ls s3://ilminate-harborsim-sanitized/templates/

# Check DynamoDB for metadata
aws dynamodb query \
  --table-name ilminate-harborsim-templates \
  --index-name CreatedAtIndex \
  --limit 10
```

---

## Security Guardrails

### Data Protection

- **Originals** are stored in `ilminate-harborsim-raw` with KMS encryption, private access only
- **Sanitized outputs** contain **no** live links, forms, scripts, or PII
- Least-privilege IAM roles with service-specific permissions
- Public access blocked on both buckets

### Redaction Strategy

- **URLs**: Replaced with `<URL_REMOVED>`
- **Domains**: Replaced with `<DOMAIN_REMOVED>`
- **Links**: href attributes removed
- **PII**: Emails → `<EMAIL>`, Names → `<NAME>`, etc.
- **Scripts**: Blocked entirely

---

## Development

### Code Quality

```bash
# Format code
make fmt

# Lint code
make lint

# Run tests
make test
```

### Adding New Lambda Functions

1. Create handler in `services/harborsim/lambdas/<name>/handler.py`
2. Add requirements to `services/harborsim/requirements/<name>.txt`
3. Register Lambda in `infra/terraform/main.tf`
4. Add state to Step Functions in `infra/terraform/stepfn.tf`
5. Re-package: `make package && make apply`

---

## Future Enhancements

### Planned Features

- **ClamAV Integration**: Full attachment scanning via ECS Fargate task
- **MJML Compilation**: Convert MJML → HTML as Lambda layer or CI step
- **API Gateway**: Serve `/api/harborsim/v1/templates` to APEX
- **Human Approval Gate**: Optional review step before publishing templates
- **Metadata Enrichment**: Extract header analysis, timestamps, sender patterns

### Integration Points

- **APEX**: Consume templates via REST API for training simulations
- **S3 Lifecycle**: Auto-archive raw files after N days
- **CloudWatch**: Alarms for pipeline failures
- **EventBridge**: Trigger pipeline on S3 upload events

---

## Troubleshooting

### Lambda Function Not Found

Ensure you've run `make package` before deploying. Lambda functions must exist as ZIP files in `dist/` before Terraform can reference them.

### Presidio Import Errors

Presidio requires spacy models. For Lambda, you may need to package spacy `en_core_web_sm` model or use a Lambda layer.

### MJML Template Issues

MJML templates are stored as-is. To render them as HTML, use the MJML CLI or a Lambda layer with the MJML Node module.

### DynamoDB Query Errors

Ensure the global secondary index is deployed. Run `terraform plan` to verify all resources are up to date.

---

## Directory Structure

```
ilminate-harborsim/
├── .gitignore
├── README.md
├── Makefile
├── setup.sh
├── pyproject.toml
├── scripts/
│   └── package_lambda.sh
├── infra/terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── locals.tf
│   ├── providers.tf
│   ├── iam.tf
│   ├── s3.tf
│   ├── sqs.tf
│   ├── ddb.tf
│   ├── stepfn.tf
│   └── kms.tf
├── services/harborsim/
│   ├── rules/
│   │   ├── redaction_policies.yaml
│   │   └── url_rewrite.yaml
│   ├── templates/
│   │   └── base.mjml
│   ├── lambdas/
│   │   ├── normalize/handler.py
│   │   ├── deweaponize/handler.py
│   │   ├── attachments/handler.py
│   │   ├── pii/handler.py
│   │   ├── template/handler.py
│   │   └── common/
│   │       ├── __init__.py
│   │       ├── utils.py
│   │       └── policy.py
│   ├── requirements/
│   │   ├── normalize.txt
│   │   ├── deweaponize.txt
│   │   ├── attachments.txt
│   │   ├── pii.txt
│   │   └── template.txt
│   └── tests/fixtures/
│       └── sample_attack.eml
└── dist/  # Generated by `make package`
```

---

## License

Internal use only. Contact Ilminate for access.
