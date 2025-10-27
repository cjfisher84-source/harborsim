"""Deweaponize handler - Remove dangerous HTML elements."""
import os
import boto3
from common.policy import Sanitizer
from common.utils import response

s3 = boto3.client("s3")
RAW_BUCKET = os.environ["RAW_BUCKET"]
RULES_KEY = os.environ.get("URL_RULES_S3_KEY", "rules/url_rewrite.yaml")

_rules_cache = None


def _load_rules():
    """Load URL rewrite rules from S3."""
    global _rules_cache
    if _rules_cache is None:
        obj = s3.get_object(Bucket=RAW_BUCKET, Key=RULES_KEY)
        _rules_cache = obj["Body"].read().decode("utf-8")
    return _rules_cache


def handler(event, context):
    """
    Defang HTML by removing hrefs, rewriting URLs/domains.
    
    Expects: { "normalized": {"html": "..."} }
    Returns: { "normalized": {...}, "deweaponized": {...} }
    """
    html = event["normalized"]["html"]
    rules_text = _load_rules()
    sanitizer = Sanitizer.from_yaml(rules_text)
    safe_html = sanitizer.defang(html)
    
    # Pass through all previous data + add deweaponized
    event["deweaponized"] = {"safe_html": safe_html}
    return event

