"""PII handler - Redact personally identifiable information."""
import re


def simple_pii_redact(html: str) -> str:
    """
    Simple PII redaction without external dependencies.
    Uses regex patterns for basic PII detection.
    """
    # Email addresses
    html = re.sub(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', '<EMAIL>', html)
    
    # Phone numbers (basic US format)
    html = re.sub(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b', '<PHONE>', html)
    
    # Credit card numbers (basic pattern)
    html = re.sub(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b', '<CARD>', html)
    
    return html


def handler(event, context):
    """
    Remove PII from defanged HTML.
    
    Expects: { "deweaponized": {"safe_html": "..."} }
    Returns: { ..., "pii": {...} }
    """
    safe_html = event["deweaponized"]["safe_html"]
    pii_free = simple_pii_redact(safe_html)
    event["pii"] = {"html": pii_free}
    return event

