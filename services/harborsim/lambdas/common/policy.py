"""Sanitization policy utilities for HarborSim."""
import yaml
import re
from bs4 import BeautifulSoup
import bleach


class Sanitizer:
    """HTML sanitizer with defanging capabilities."""

    def __init__(self, url_rules: dict):
        """Initialize sanitizer with URL rewrite rules."""
        self.rules = url_rules
        allowed_tags = (
            set(bleach.sanitizer.ALLOWED_TAGS)
            | {"p", "span", "div", "table", "tr", "td", "th", "img", "a"}
        )
        self.allowed_tags = list(allowed_tags)
        self.allowed_attrs = {
            "a": ["title"],
            "img": ["alt"],
            "*": ["class", "style"]
        }

    @staticmethod
    def from_yaml(text: str):
        """Create a sanitizer instance from YAML rules."""
        return Sanitizer(yaml.safe_load(text))

    def defang(self, html: str) -> str:
        """Defang HTML by removing/rewriting dangerous elements."""
        soup = BeautifulSoup(html, "lxml")
        # Remove href attributes from links
        for a in soup.find_all("a"):
            a["href"] = "#"
        txt = str(soup)
        # Rewrite bare URLs
        txt = re.sub(
            r"https?://[^\s)>\]]+",
            self.rules["defang"].get("bare_urls", "<URL_REMOVED>"),
            txt,
            flags=re.I
        )
        # Rewrite domains
        txt = re.sub(
            r"\b([a-z0-9-]+\.)+[a-z]{2,}\b",
            self.rules["defang"].get("domains", "<DOMAIN_REMOVED>"),
            txt,
            flags=re.I
        )
        # Apply bleach sanitization
        cleaned = bleach.clean(
            txt,
            tags=self.allowed_tags,
            attributes=self.allowed_attrs,
            strip=True
        )
        return cleaned

