#!/usr/bin/env bash
#
# Stamp a FederationIdentifier onto the user the CLI is authenticated as for a given org.
#
# Attendee orgs each have their own admin/running user. This resolves whoever the CLI
# is logged in as for the target org (its default/authenticated user), then updates that
# same user's FederationIdentifier. No hardcoded username — it always targets the logged-in
# user, so the same command works unchanged across every attendee org.
#
# Note: FederationIdentifier must be unique per user WITHIN an org. The same value across
# separate attendee orgs is fine; two users in one org sharing it is not.
#
# Usage:  ./data/set-federation-id.sh <target-org-alias-or-username> [federation-id]
#         federation-id defaults to epic.orgfarm@salesforce.com

set -euo pipefail

TARGET_ORG="${1:-}"
FEDERATION_ID="${2:-epic.orgfarm@salesforce.com}"

if [[ -z "$TARGET_ORG" ]]; then
  echo "Usage: $0 <target-org-alias-or-username> [federation-id]" >&2
  exit 1
fi

echo "Resolving logged-in user for org '$TARGET_ORG' ..."
USERNAME="$(sf org display --target-org "$TARGET_ORG" --json | \
  python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["username"])')"

if [[ -z "$USERNAME" ]]; then
  echo "Could not resolve the authenticated username for '$TARGET_ORG'." >&2
  exit 1
fi

echo "Setting FederationIdentifier='$FEDERATION_ID' on user '$USERNAME' ..."
sf data update record --sobject User \
  --where "Username='$USERNAME'" \
  --values "FederationIdentifier='$FEDERATION_ID'" \
  --target-org "$TARGET_ORG"

echo "Done."
