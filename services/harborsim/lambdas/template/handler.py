"""Template handler - Generate final MJML template."""
import os
import json
import boto3
from jinja2 import Template
from common.utils import now_iso, response

s3 = boto3.client("s3")
db = boto3.client("dynamodb")

SAN_BUCKET = os.environ["SANITIZED_BUCKET"]
TEMPLATES_TABLE = os.environ["TEMPLATES_TABLE"]
TEMPLATE_KEY = os.environ.get("BASE_TEMPLATE_S3_KEY", "templates/base.mjml")


def handler(event, context):
    """
    Generate and persist final template.
    
    Expects: { "pii": {"html": "..."}, "normalized": {...} }
    Returns: { "ok": True, "template_id": "...", "s3_key": "..." }
    """
    # Load MJML base template
    obj = s3.get_object(Bucket=SAN_BUCKET, Key=TEMPLATE_KEY)
    mjml_base = obj["Body"].read().decode("utf-8")

    mj = Template(mjml_base)
    html = mj.render(SAFE_HTML=event["pii"]["html"])

    # Persist result
    template_id = event["normalized"]["source_hash"]
    out_key = f"templates/{template_id}.mjml"
    
    s3.put_object(
        Bucket=SAN_BUCKET,
        Key=out_key,
        Body=html.encode("utf-8"),
        ContentType="text/mjml"
    )

    # Store metadata in DynamoDB
    db.put_item(
        TableName=TEMPLATES_TABLE,
        Item={
            "TemplateId": {"S": template_id},
            "CreatedAt": {"S": now_iso()},
            "Subject": {"S": event["normalized"].get("subject", "Simulation")},
            "S3Key": {"S": out_key},
            "Meta": {"S": json.dumps({"source": "live", "origin": "harborsim"})}
        }
    )

    return response(True, template_id=template_id, s3_key=out_key)

