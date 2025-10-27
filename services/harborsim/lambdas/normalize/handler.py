"""Normalize handler - Parse raw EML files."""
import os
import json
import boto3
from mailparser import parse_from_string
from common.utils import sha256, response

s3 = boto3.client("s3")
RAW_BUCKET = os.environ["RAW_BUCKET"]


def handler(event, context):
    """
    Parse raw EML file and extract HTML content.
    
    Expects: { "s3_key": "incoming/123.eml" }
    Returns: { "normalized": {...} }
    """
    key = event["s3_key"]
    obj = s3.get_object(Bucket=RAW_BUCKET, Key=key)
    raw = obj["Body"].read().decode("utf-8", errors="ignore")

    mail = parse_from_string(raw)
    html = "".join(mail.body_html) if mail.body_html else f"<p>{mail.body}</p>"

    normalized = {
        "source_hash": sha256(raw.encode("utf-8")),
        "subject": mail.subject or "",
        "html": html,
        "headers": dict(mail.headers)
    }
    
    # Return with normalized key - Step Functions passes this as-is to next step
    return {"normalized": normalized}

