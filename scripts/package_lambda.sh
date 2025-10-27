#!/usr/bin/env bash
set -euo pipefail
SERVICE=${1:-harborsim}
BASE="services/${SERVICE}/lambdas"
DIST="dist"
mkdir -p "$DIST"

for fn in normalize deweaponize attachments pii template; do
  WDIR="${BASE}/${fn}"
  REQ="services/${SERVICE}/requirements/${fn}.txt"
  ZIP="${DIST}/${SERVICE}-${fn}.zip"
  rm -f "$ZIP"
  tmpdir=$(mktemp -d)
  pip install -r "$REQ" -t "$tmpdir"
  cp -R ${WDIR}/* "$tmpdir"/
  (cd "$tmpdir" && zip -qr "$OLDPWD/$ZIP" .)
  rm -rf "$tmpdir"
  echo "Packaged $ZIP"
done

