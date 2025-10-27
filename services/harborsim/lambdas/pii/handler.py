"""PII handler - Redact personally identifiable information."""
from common.utils import response

# Import Presidio components
try:
    from presidio_analyzer import AnalyzerEngine
    from presidio_anonymizer import AnonymizerEngine
    
    analyzer = AnalyzerEngine()
    anonymizer = AnonymizerEngine()
except ImportError:
    analyzer = None
    anonymizer = None

REPLACE_MAP = {
    "EMAIL_ADDRESS": "<EMAIL>",
    "PHONE_NUMBER": "<PHONE>",
    "PERSON": "<NAME>",
    "CREDIT_CARD": "<CARD>",
    "IBAN_CODE": "<IBAN>"
}


def anonymize_html(html: str) -> str:
    """
    Anonymize PII in HTML text.
    
    Note: This is a naive implementation. For production,
    extract text from HTML and apply Presidio properly.
    """
    if analyzer is None or anonymizer is None:
        # Fallback if Presidio not available
        return html
    
    results = analyzer.analyze(
        text=html,
        entities=list(REPLACE_MAP.keys()),
        language="en"
    )
    
    items = []
    for r in results:
        items.append({
            "entity_type": r.entity_type,
            "start": r.start,
            "end": r.end,
            "operator": "replace",
            "new_value": REPLACE_MAP.get(r.entity_type, "<REDACTED>")
        })
    
    anonymizers_config = {
        item["entity_type"]: {
            "type": "replace",
            "new_value": item["new_value"]
        } for item in items
    }
    
    return anonymizer.anonymize(
        text=html,
        anonymizers_config=anonymizers_config
    ).text


def handler(event, context):
    """
    Remove PII from defanged HTML.
    
    Expects: { "deweaponized": {"safe_html": "..."} }
    Returns: { ..., "pii": {...} }
    """
    safe_html = event["deweaponized"]["safe_html"]
    pii_free = anonymize_html(safe_html)
    event["pii"] = {"html": pii_free}
    return event

