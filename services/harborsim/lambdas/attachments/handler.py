"""Attachments handler - Scan and flatten attachments (stub)."""
from common.utils import response


def handler(event, context):
    """
    Stub for attachment scanning.
    
    TODO: integrate ClamAV/oletools/pdf flattening (containerized if needed)
    
    Expects: { ... }
    Returns: { "ok": True, "attachments": {...}, ... }
    """
    event["attachments"] = {"status": "no_attachments_scanned_in_stub"}
    return response(True, **event)

