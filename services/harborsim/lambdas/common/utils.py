"""Common utility functions for HarborSim."""
import os
import json
import re
import hashlib
from datetime import datetime, timezone

ISO = "%Y-%m-%dT%H:%M:%SZ"

RAW_BUCKET = os.environ.get("RAW_BUCKET")
SAN_BUCKET = os.environ.get("SANITIZED_BUCKET")
TABLE = os.environ.get("TEMPLATES_TABLE")


def now_iso():
    """Get current timestamp in ISO format."""
    return datetime.now(timezone.utc).strftime(ISO)


def sha256(s: bytes) -> str:
    """Compute SHA256 hash of input bytes."""
    h = hashlib.sha256()
    h.update(s)
    return h.hexdigest()


def response(ok: bool, **kwargs):
    """Create a standardized response object."""
    return {"ok": ok, **kwargs}

