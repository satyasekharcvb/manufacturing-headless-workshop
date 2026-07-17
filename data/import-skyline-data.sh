#!/usr/bin/env bash
#
# Import the Skyline Aviation demo data into any org AND populate it end to end.
#
# Steps, all automated:
#   1. Import the record tree (Account -> Contacts -> Cases -> Opportunity).
#   2. Run WorkshopDataSetup.setupSkylineDemo(), which creates the SalesAgreement
#      itself (with relative dates so past periods can be backfilled), adds product
#      lines, activates, backfills schedule actuals, computes adherence, adds Assets.
#      The no-arg overload resolves the fixed "Skyline Aviation" account by name.
#
# The SalesAgreement is intentionally NOT in the data tree: an imported SA has fixed
# StartDate/EndDate, and once "today" passes those dates all periods are in the future,
# which makes the actuals backfill fail ("You can edit actuals for up to only 0 future
# schedules"). Letting the Apex create it keeps the periods relative to today.
#
# Usage:  ./data/import-skyline-data.sh <target-org-alias-or-username>

set -euo pipefail

TARGET_ORG="${1:-}"
if [[ -z "$TARGET_ORG" ]]; then
  echo "Usage: $0 <target-org-alias-or-username>" >&2
  exit 1
fi

DATA_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Importing tree ..."
sf data import tree --plan "$DATA_DIR/skyline-aviation-plan.json" --target-org "$TARGET_ORG"

echo "Running WorkshopDataSetup.setupSkylineDemo ..."
echo "WorkshopDataSetup.setupSkylineDemo();" | sf apex run --target-org "$TARGET_ORG"

echo "Done. Activation runs in a queued job — wait a few seconds before checking SalesAgreement.Status."
