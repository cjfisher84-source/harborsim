#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="harborsim"
AWS_REGION=${AWS_REGION:-"us-east-1"}

python3 -m venv .venv && source .venv/bin/activate
pip install --upgrade pip wheel

# Basic Python tooling
pip install black==24.8.0 ruff==0.6.9 pytest==8.3.3

echo "Service ${SERVICE_NAME} bootstrapped in region ${AWS_REGION}."

