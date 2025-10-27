"""Deweaponize handler - Remove dangerous HTML elements."""
import os
import re
import boto3

s3 = boto3.client("s3")
RAW_BUCKET = os.environ["RAW_BUCKET"]
RULES_KEY = os.environ.get("URL_RULES_S3_KEY", "rules/url_rewrite.yaml")


def simple_defang(html):
    """Simple defanging without external dependencies."""
    # Remove href attributes
    html = re.sub(r'href=["\']([^"\']*)["\']', 'href="#"', html, flags=re.IGNORECASE)
    
    # Replace URLs with placeholder
    html = re.sub(r'https?://[^\s)>\]]+', '<URL_REMOVED>', html, flags=re.IGNORECASE)
    
    # Replace domains with placeholder
    html = re.sub(r'\b([a-z0-9-]+\.)+[a-z]{2,}\b', '<DOMAIN_REMOVED>', html, flags=re.IGNORECASE)
    
    # Remove dangerous tags
    html = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL | re.IGNORECASE)
    html = re.sub(r'<iframe[^>]*>.*?</iframe>', '', html, flags=re.DOTALL | re.IGNORECASE)
    html = re.sub(r'<form[^>]*>.*?</form>', '', html, flags=re.DOTALL | re.IGNORECASE)
    
    return html


def handler(event, context):
    """
    Defang HTML by removing hrefs, rewriting URLs/domains.
    
    Expects: { "normalized": {"html": "..."} }
    Returns: { "normalized": {...}, "deweaponized": {...} }
    """
    html = event["normalized"]["html"]
    safe_html = simple_defang(html)
    
    # Pass through all previous data + add deweaponized
    event["deweaponized"] = {"safe_html": safe_html}
    return event

