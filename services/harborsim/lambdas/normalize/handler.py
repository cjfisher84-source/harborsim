"""Normalize handler - Parse raw EML files."""
import os
import json
import boto3
import re
from common.utils import sha256

s3 = boto3.client("s3")
RAW_BUCKET = os.environ["RAW_BUCKET"]


def parse_simple_eml(raw_content):
    """Simple EML parser using regex - no external dependencies."""
    headers = {}
    body = ""
    html = ""
    
    # Parse headers
    header_end = raw_content.find("\n\n")
    if header_end == -1:
        header_end = raw_content.find("\r\n\r\n")
    
    if header_end != -1:
        header_section = raw_content[:header_end]
        body_section = raw_content[header_end:].strip()
        
        # Extract headers
        for line in header_section.split("\n"):
            if ":" in line:
                key, value = line.split(":", 1)
                headers[key.strip().lower()] = value.strip()
        
        # Extract content
        content_type = headers.get("content-type", "").lower()
        if "text/html" in content_type:
            # Look for HTML content
            html_start = body_section.find("<html>")
            html_end = body_section.find("</html>")
            if html_start != -1 and html_end != -1:
                html = body_section[html_start:html_end + 7]
            else:
                html = body_section
        else:
            body = body_section
    
    # Extract subject
    subject = headers.get("subject", "")
    
    # If no HTML found, create a simple one from text
    if not html and body:
        html = f"<p>{body.replace(chr(10), '<br>')}</p>"
    elif not html:
        html = "<p>No content found</p>"
    
    return {
        "subject": subject,
        "html": html,
        "headers": headers
    }


def handler(event, context):
    """
    Parse raw EML file and extract HTML content.
    
    Expects: { "s3_key": "incoming/123.eml" }
    Returns: { "normalized": {...} }
    """
    key = event["s3_key"]
    obj = s3.get_object(Bucket=RAW_BUCKET, Key=key)
    raw = obj["Body"].read().decode("utf-8", errors="ignore")
    
    parsed = parse_simple_eml(raw)
    
    normalized = {
        "source_hash": sha256(raw.encode("utf-8")),
        "subject": parsed["subject"],
        "html": parsed["html"],
        "headers": parsed["headers"]
    }
    
    # Return with normalized key - Step Functions passes this as-is to next step
    return {"normalized": normalized}

