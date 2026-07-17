#!/usr/bin/env bash
#
# Import the Skyline Aviation demo data into any org AND populate it end to end.
#
# Steps, all automated:
#   1. Resolve the org's active Standard Price Book and inject its Id (the JSON
#      files are org-agnostic except for PricebookId, which can't be an @ref
#      because the Standard Price Book pre-exists with a different Id per org).
#   2. Import the record tree (Account → Contacts → Cases → Opportunity → SA).
#   3. Resolve the created Account Id and run WorkshopDataSetup.setupSkylineDemo
#      against it (product lines, activation, schedule actuals, adherence, Assets).
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

# Resolve the Account Id the import just created, then run WorkshopDataSetup against it.
# (The Id isn't known until after the import, which is why this step used to be manual.)
echo "Resolving the Skyline Aviation Account Id ..."
ACCOUNT_ID="$(sf data query \
  --query "SELECT Id FROM Account WHERE Name = 'Skyline Aviation' ORDER BY CreatedDate DESC LIMIT 1" \
  --target-org "$TARGET_ORG" --json | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["records"][0]["Id"])')"
echo "  Account Id: $ACCOUNT_ID"

echo "Running WorkshopDataSetup.setupSkylineDemo ..."
echo "WorkshopDataSetup.setupSkylineDemo('$ACCOUNT_ID');" | sf apex run --target-org "$TARGET_ORG"

echo "Done. Activation runs in a queued job — wait a few seconds before checking SalesAgreement.Status."
