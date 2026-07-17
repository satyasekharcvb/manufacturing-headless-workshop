#!/usr/bin/env bash
#
# Import the Skyline Aviation demo data into any org.
#
# The committed JSON files are org-agnostic: cross-record links use @referenceId
# tokens that resolve within the plan (lwc-recipes style). The one value that
# can't be a @ref is PricebookId — the Standard Price Book already exists in
# every org with a DIFFERENT Id. So we query it at runtime and inject it here,
# keeping data/SalesAgreement.json free of any org-specific Id.
#
# Usage:  ./data/import-skyline-data.sh <target-org-alias-or-username>

set -euo pipefail

TARGET_ORG="${1:-}"
if [[ -z "$TARGET_ORG" ]]; then
  echo "Usage: $0 <target-org-alias-or-username>" >&2
  exit 1
fi

DATA_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Resolving the active Standard Price Book in $TARGET_ORG ..."
PRICEBOOK_ID="$(sf data query \
  --query "SELECT Id FROM Pricebook2 WHERE IsStandard = true AND IsActive = true LIMIT 1" \
  --target-org "$TARGET_ORG" --json | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["records"][0]["Id"])')"
echo "  Standard Price Book Id: $PRICEBOOK_ID"

# Build a temp plan+files with the @StandardPricebookId token replaced.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
cp "$DATA_DIR"/*.json "$TMP_DIR"/
sed -i.bak "s/@StandardPricebookId/$PRICEBOOK_ID/g" "$TMP_DIR/SalesAgreement.json"
rm -f "$TMP_DIR"/*.bak

echo "Importing tree ..."
sf data import tree --plan "$TMP_DIR/skyline-aviation-plan.json" --target-org "$TARGET_ORG"
echo "Done."
