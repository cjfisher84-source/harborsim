# How to See HarborSim Working

## 🎯 Quick View Commands

### View Everything at Once
```bash
./explore_harborsim.sh
```

### Run the Smoke Test Again
```bash
./harborSim_smoke_test.sh
```
This will upload a test phishing email and run it through the complete pipeline.

---

## 🌐 AWS Console Views

### 1. Step Functions (See the Pipeline in Action)
Open this URL to watch executions in real-time:
```
https://console.aws.amazon.com/states/home?region=us-east-1#/statemachines/view/arn:aws:states:us-east-1:657258631769:stateMachine:ilminate-harborsim-pipeline
```

**What you'll see:**
- Visual flow: Normalize → Deweaponize → Attachments → PII → Template
- Execution history with timestamps
- Click "Executions" to see all runs
- See which steps passed/failed and timing

### 2. Lambda Functions (See the Processing Code)
```
https://console.aws.amazon.com/lambda/home?region=us-east-1#/functions
```
Then search for: `ilminate-harborsim-`
- Click any function to see code, logs, and metrics

### 3. S3 Buckets (See Data Storage)
**Raw emails (quarantine):**
```
https://console.aws.amazon.com/s3/buckets/ilminate-harborsim-raw?region=us-east-1
```

**Sanitized templates (safe for training):**
```
https://console.aws.amazon.com/s3/buckets/ilminate-harborsim-sanitized?region=us-east-1
```

### 4. DynamoDB (See Template Metadata)
```
https://console.aws.amazon.com/dynamodbv2/home?region=us-east-1#tables/selected/ilminate-harborsim-templates
```
See all template records with subjects, timestamps, and S3 locations.

---

## 🧪 Test Commands

### Upload a New Phishing Email
```bash
# Upload your own .eml file
aws s3 cp your-file.eml s3://ilminate-harborsim-raw/incoming/test-$(date +%s).eml

# Trigger the pipeline
aws stepfunctions start-execution \
  --state-machine-arn "arn:aws:states:us-east-1:657258631769:stateMachine:ilminate-harborsim-pipeline" \
  --input '{"s3_key": "incoming/test-YOUR_FILE.eml"}'
```

### View Generated Template
```bash
# List all templates
aws s3 ls s3://ilminate-harborsim-sanitized/templates/

# Download the latest template
aws s3 cp s3://ilminate-harborsim-sanitized/templates/83d82c35e78c2df7c81686b3e2d82c3bbe1135ce9c8b3cbec9bae28dfdff9781.mjml output.mjml

# View it
cat output.mjml
```

### Check Lambda Logs
```bash
# See normalize step logs
aws logs tail /aws/lambda/ilminate-harborsim-normalize --follow --region us-east-1

# See deweaponize step logs
aws logs tail /aws/lambda/ilminate-harborsim-deweaponize --follow --region us-east-1

# See template step logs
aws logs tail /aws/lambda/ilminate-harborsim-template --follow --region us-east-1
```

### View DynamoDB Records
```bash
aws dynamodb scan --table-name ilminate-harborsim-templates --region us-east-1 | jq
```

---

## 🎬 What You Just Created

✅ **Working end-to-end pipeline** that:
1. Ingests phishing emails (S3)
2. Parses and extracts content (Lambda)
3. Removes dangerous links/scripts (Lambda)
4. Redacts PII (Lambda)
5. Generates safe training template (Lambda)
6. Stores in S3 + DynamoDB

✅ **Security guardrails:**
- KMS encryption
- Private buckets
- Least-privilege IAM
- Isolated from production

✅ **No external dependencies:**
- Pure Python standard library
- Only uses boto3 (built-in to Lambda)
- No npm/complex builds needed

---

## 📊 Current Status

Run this to see the current state:
```bash
./explore_harborsim.sh
```

Expected output shows:
- 1 email in raw storage (sample.eml)
- 2 files in sanitized (base.mjml + generated template)
- 1 record in DynamoDB
- Latest execution: **SUCCEEDED** ✅

