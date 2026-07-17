# Headless 360 Workshop — Full Setup & Replication Guide

This guide covers everything built so far (Beats 1–4 groundwork) in the order you'd
replicate it in a fresh org: data model → Apex → seed data → Named Queries →
MCP Server registration → permissions → manual Setup UI steps.

Only components actually used by the working demo are listed. The project contains
several unrelated leftover Apex classes (`PartsInventoryChecker`, `PartsInventoryCheckerReal`,
`ChangePasswordController`, all the `Communities*`/`Site*`/`MicrobatchSelfReg*` controllers) —
**ignore those, they are not part of this implementation.**

---

## 0. Prerequisites

- A Salesforce org with **Manufacturing Cloud** enabled (Sales Agreements, Sales Agreement
  Products, Sales Agreement Product Schedules must exist as standard objects).
- MCP Servers feature enabled in Setup (Setup → search "MCP Servers").
- Salesforce CLI (`sf`) authenticated against the target org.

---

## 1. Data Model — Custom Fields

Five custom fields, all plain `Percent`/`Text`/`Picklist` fields, no formulas, no validation rules.

| Object | Field API Name | Type | Purpose |
|---|---|---|---|
| `Asset` | `health_score__c` | Percent(5,1) | Overall asset health 0–100% |
| `Asset` | `hub_location__c` | Text(100) | Geographic hub (e.g. "Hong Kong") |
| `Asset` | `maintenance_priority__c` | Picklist (Low/Medium/High/Critical, default Medium) | Maintenance priority |
| `SalesAgreement` | `SchedAdherenceScore__c` | Percent(5,1) | Avg adherence across all product lines on the agreement |
| `SalesAgreementProduct` | `AdherenceScore__c` | Percent(5,1) | Adherence % for one product line |

Deploy them:

```bash
sf project deploy start --source-dir force-app/main/default/objects/Asset/fields --target-org <your-org>
sf project deploy start --source-dir force-app/main/default/objects/SalesAgreement/fields --target-org <your-org>
sf project deploy start --source-dir force-app/main/default/objects/SalesAgreementProduct/fields --target-org <your-org>
```

**No trigger, flow, or platform automation calculates `AdherenceScore__c`, `SchedAdherenceScore__c`,
or `health_score__c`.** In the reference org, values for these fields already existed on the
`SalesAgreementProduct`/`Asset` records before this workshop build began — created/modified by
the org's system user, dated before this project's work started — so they came from whatever
seeded the base OrgFarm/workshop org template, not from anything in this repo. In a brand-new
org that doesn't inherit that same seed, these fields will be null/0 and the risk-scoring tools
won't have anything meaningful to work with.

**Fix: `WorkshopDataSetup.setupSkylineDemo(accountId)`** (see §2) populates all of this for you —
no manual field edits needed.

---

## 2. Apex Classes — only what's actually used

Two layers: **calculator classes** (`public`, do the real logic/SOQL) and **action wrapper
classes** (`global`, thin `@InvocableMethod` shims that Setup's "Add Server Assets" picker
and Flow can discover — Salesforce requires `global` visibility for that picker).

| Calculator (logic) | Action wrapper (`global`, invocable) | Used by |
|---|---|---|
| `AdherenceCalculator` | `AdherenceAction` | Adherence summary tool |
| `CaseImpactAnalyzer` | `CaseImpactAction` | Case impact tool |
| `QuarterlyAdherenceTrendCalculator` | `QuarterlyAdherenceTrendAction` | Trend tool |
| `RenewalRiskScorer` (contains both the legacy LWC-facing `calculateRenewalRisk` **and** the invocable `scoreRenewalRisk`) | `RenewalRiskAction` (wraps `calculateRenewalRisk`) — `scoreRenewalRisk` is itself `global` and invocable directly, no separate wrapper class | Renewal risk scoring tool |
| — | `AccountSearchAction` | Account lookup by name (SOSL) tool |
| — | `ScheduleUpdateAction` | Writes `ProposedPlannedQuantity` on a schedule record |

Plus `WorkshopDataSetup` (§3) — a setup-only utility, not registered as an MCP tool, that
populates demo data so the tools above have something meaningful to score.

**⚠️ Deploy all of these in ONE command.** `WorkshopDataSetup` calls
`AdherenceCalculator.updateScheduleAdherence`, so deploying it on its own fails with
`Variable does not exist: AdherenceCalculator` — the dependency isn't in the org yet. Deploying
the whole set together lets them compile as a unit. (Deploy the entire folder with
`--source-dir force-app/main/default/classes` if you prefer.)

```bash
sf project deploy start --target-org <your-org> \
  --source-dir force-app/main/default/classes/AdherenceCalculator.cls \
  --source-dir force-app/main/default/classes/AdherenceAction.cls \
  --source-dir force-app/main/default/classes/CaseImpactAnalyzer.cls \
  --source-dir force-app/main/default/classes/CaseImpactAction.cls \
  --source-dir force-app/main/default/classes/QuarterlyAdherenceTrendCalculator.cls \
  --source-dir force-app/main/default/classes/QuarterlyAdherenceTrendAction.cls \
  --source-dir force-app/main/default/classes/RenewalRiskScorer.cls \
  --source-dir force-app/main/default/classes/RenewalRiskAction.cls \
  --source-dir force-app/main/default/classes/AccountSearchAction.cls \
  --source-dir force-app/main/default/classes/ScheduleUpdateAction.cls \
  --source-dir force-app/main/default/classes/WorkshopDataSetup.cls
```

**None of the 10 tool-facing classes need anything run after deploy** — they are pure
`@InvocableMethod`/`@AuraEnabled` classes with no static initializers, custom metadata
dependencies, or one-time jobs. `WorkshopDataSetup` is the one exception: it's a setup
utility meant to be *invoked* once per demo account via anonymous Apex — see §3 for the
one-line call.

### Key business-rule gotchas encountered (informs `ScheduleUpdateAction`'s design)
- A Sales Agreement in `Activated` status blocks direct writes to
  `SalesAgreementProductSchedule.PlannedQuantity`.
- It does **not** block writes to `ProposedPlannedQuantity` — that's the field
  `ScheduleUpdateAction.applyUpdate` writes to, so the agreement never has to leave
  `Activated` status.
- `UnderRevision → Approved` auto-promotes to `Activated` (platform automation completes the
  transition); you cannot set `Status = 'Activated'` directly from `UnderRevision`.

---

## 3. Seed Data (Skyline Aviation demo account)

> Deploy the Apex classes (§2) **before** this step — `WorkshopDataSetup.setupSkylineDemo`
> (below) depends on them.

Located in `data/`. Import with the wrapper script (respects lookups via `saveRefs`/`resolveRefs`):

```bash
./data/import-skyline-data.sh <your-org>
```

This creates, in order: `Account` (Skyline Aviation) → `Contact` (Michael Chen, Sarah Wong) →
`Case` (3 open cases, 2 High + 1 Medium priority) → `Opportunity` (2 open opps) →
`SalesAgreement` (SA-2026-HK001, Draft, Quarterly, 4 periods).

> **Why a wrapper, not a raw `sf data import tree`?** Every cross-record link in the JSON uses
> an `@referenceId` token that resolves *within* the plan (lwc-recipes style), so the files are
> org-agnostic — **except `SalesAgreement.PricebookId`**. The Standard Price Book already exists
> in every org but with a *different* Id, so it can't be a `@ref`. The committed
> `data/SalesAgreement.json` therefore carries the placeholder `"@StandardPricebookId"`, and the
> script queries the real Id at runtime and injects it before importing.

If you'd rather do it by hand, query your org's active Standard Price Book and substitute the
placeholder yourself:

```bash
sf data query --query "SELECT Id FROM Pricebook2 WHERE IsStandard = true AND IsActive = true LIMIT 1" --target-org <your-org>
# then replace "@StandardPricebookId" in data/SalesAgreement.json with that Id, and run:
sf data import tree --plan data/skyline-aviation-plan.json --target-org <your-org>
```

> `WorkshopDataSetup` (below) also resolves the Standard Pricebook itself and doesn't depend on
> `SalesAgreement.PricebookId` either way — the field only matters for this tree import.

### Populate demo data with `WorkshopDataSetup.setupSkylineDemo`

**The wrapper script above already does this for you** — after importing, it resolves the new
Account Id and runs `WorkshopDataSetup.setupSkylineDemo` against it. No manual step needed.

If you imported the tree by hand (the manual path), run it yourself once. The no-arg overload
resolves the fixed `Skyline Aviation` account by name, so there's no Id to look up:

```bash
echo "WorkshopDataSetup.setupSkylineDemo();" | sf apex run --target-org <your-org>
```
(or paste the one-liner into Setup → Developer Console → Execute Anonymous instead. A
`setupSkylineDemo(accountId)` overload still exists if you need to target a different account.)

This single call does everything the old manual steps used to require:
1. If the account has no `SalesAgreement` yet, creates one in `Draft` status against the
   Standard Pricebook.
2. Inserts `SalesAgreementProduct` lines for Turbine Blade Assembly, Gasket Seal Kit, and
   Heavy-Duty Bearing Kit (Standard Pricebook entries), then queues a `Queueable`
   (`WorkshopDataSetup.AgreementActivationJob`) to move the agreement from `Draft` → `Approved`
   in a separate transaction. **This is required, not optional** — Manufacturing Cloud rejects
   the status change if it's attempted in the same transaction as the product-line insert
   (`UNKNOWN_EXCEPTION, Save other edits before changing the status.`). The platform then
   auto-promotes `Approved` → `Activated` and synchronously generates the
   `SalesAgreementProductSchedule` child records.
3. Backfills `ActualQuantity` on the three most recently completed schedule periods per
   product, using a declining-adherence ratio applied to each period's own `PlannedQuantity`
   (95%→80%→62% for Turbine Blade Assembly, similar for the other two) — this produces a
   realistic "adherence trending down" signal for the risk-scoring tools to act on.
4. Computes `AdherenceScore__c` on each `SalesAgreementProduct` as
   `SUM(ActualQuantity) / SUM(PlannedQuantity) * 100` across periods with actuals, then calls
   the existing `AdherenceCalculator.updateScheduleAdherence` to roll that up into
   `SalesAgreement.SchedAdherenceScore__c`.
5. Creates one `Asset` per product (health scores 58/60/58, `hub_location__c = 'Hong Kong'`,
   `maintenance_priority__c = 'Medium'`) — skipped if the account already has any Assets.

The whole thing is idempotent-ish: if the account already has a `SalesAgreement`, it reuses
it and skips straight to steps 3–5 (so re-running it just refreshes actuals/adherence); if the
account already has Assets, step 5 is skipped.

Because activation runs in a queued job, wait a few seconds after calling `setupSkylineDemo`
before checking `SalesAgreement.Status`.

---

## 4. Named Queries (Api Named Query)

Two Named Queries, both parameterized by `accountid` (must be lowercase, no spaces).

| Name | Purpose |
|---|---|
| `AccountManufacturing360` | One-shot Account 360 view: profile + active Sales Agreements (with adherence score) + Contacts + Assets |
| `RenewalScheduleSnapshot` | Recent (last 120 days) + upcoming schedule periods per product, with Planned/Actual/Proposed quantities and each product's `AdherenceScore__c`, so an agent can see the real consumption trend and calculate a proposed quantity |

> The `RenewalScheduleSnapshot` query filters on `EndDate >= LAST_N_DAYS:120` so it returns
> recently completed periods (with real `ActualQuantity`) alongside upcoming ones — an agent
> needs the completed periods to compute a consumption trend. (A note if you ever iterate on a
> Named Query already registered as an active MCP tool: it **cannot be updated via metadata
> deploy while active**. Deactivate/remove the `McpServerToolDefinition` referencing it first,
> or ship a new query under a new name. Fresh attendee orgs don't hit this — they deploy this
> query once, clean.)

Deploy:

```bash
sf project deploy start --target-org <your-org> \
  --source-dir force-app/main/default/apiNamedQueries/AccountManufacturing360.apiNamedQuery-meta.xml \
  --source-dir force-app/main/default/apiNamedQueries/RenewalScheduleSnapshot.apiNamedQuery-meta.xml
```

**⚠️ Manual step — Named Queries deploy Inactive.** In Setup → Named Query API (Quick Find
"Named Query"), open each query and toggle **API Registration → Active**. This is separate
from MCP server activation in §5.

---

## 5. MCP Server Registration (Setup UI — manual, no metadata for this part)

Two Salesforce-hosted MCP Servers were created in Setup (Setup → MCP Servers → Salesforce
Servers → Add MCP Server). This step is **UI-only**; there's no source-deployable metadata
for the server + tool-registration linkage in this project.

| MCP Server | Tools registered |
|---|---|
| **Manufacturing Sales Agreement Tools** | `AccountSearchAction`, `CaseImpactAction`, `RenewalRiskAction`, `AdherenceAction`, `QuarterlyAdherenceTrendAction` |
| **Product Custom MCP** | `AccountManufacturing360` (Named Query), `ScheduleUpdateAction`, `RenewalScheduleSnapshot` (Named Query) |

To replicate:
1. Setup → MCP Servers → Salesforce Servers → **Add MCP Server**. Create the two servers
   above (names/labels are your choice, but keep them distinguishable).
2. On each server, **Add Server Assets** → search by Apex class name or Named Query name →
   add the tools listed in the table.
3. **Only `global` Apex classes appear in the "Add Server Assets" search.** If a class you
   expect to see is missing, check its declaration is `global class ...` (not `public`) —
   this was the actual root cause the one time a class didn't show up.
4. Toggle each MCP Server to **Active** (top of the server detail page). This is a *separate*
   toggle from the Named Query's own Active/Inactive state in §4 — both must be Active.

`RenewalRiskScorer.scoreRenewalRisk` (the invocable risk-scoring method used in the Beat 3
chain) was **not** separately added as a server asset — the chain currently relies on
`RenewalRiskAction` (which wraps the older `calculateRenewalRisk`) for risk scoring in MCP.
If you want `scoreRenewalRisk` itself callable via MCP, add it explicitly in step 2.

---

## 6. Permission Set — `Workshop_User`

Grants workshop attendees (or any test user) access to everything above.

```bash
sf project deploy start --source-dir force-app/main/default/permissionsets/Workshop_User.permissionset-meta.xml --target-org <your-org>
```

Then assign it to whichever user(s) will run the demo:

```bash
sf org assign permset --name Workshop_User --target-org <your-org>
```

What it grants (already encoded in the metadata, nothing else to configure):
- Class access to the tool-facing Apex classes in §3 (calculators + action wrappers).
  `WorkshopDataSetup` is intentionally **not** included — it's a setup-only utility meant to
  be run by an admin via anonymous Apex (system context), not exposed to workshop attendees.
- Object permissions: Account, Asset, Case (read-only), Contact, SalesAgreement,
  SalesAgreementProduct, SalesAgreementProductSchedule (edit allowed, no create/delete).
- Field permissions: `SalesAgreementProductSchedule.ProposedPlannedQuantity` (editable),
  `.PlannedQuantity`/`.ActualQuantity` (read-only), plus the custom adherence/health fields.

---

## 7. Connecting ChatGPT (or another MCP client)

1. In ChatGPT (or your MCP client), add a new connector per Salesforce MCP Server, using
   that server's MCP endpoint URL from its Setup detail page, with Salesforce OAuth login.
2. **Client-side tool-list caching**: if you activate a server/tool or add a new asset
   *after* the connector is already connected, the client won't see it until you
   **disconnect and reconnect (or refresh) the connector**. This was the fix every single
   time a newly-activated tool "didn't show up" in ChatGPT despite being correctly
   registered server-side.

---

## 8. End-to-end smoke test (what "done" looks like)

Against the Skyline Aviation account (or your equivalent test account), in ChatGPT:

> "Score Skyline Aviation's renewal risk. If it's high, look at the current schedule from
> RenewalScheduleSnapshot and use the actual quantities from the most recent completed
> period to propose an updated PlannedQuantity for each remaining period that would bring
> adherence back to 90%. Apply the updates."

Expected tool-call chain: `AccountSearchAction` (or equivalent lookup) →
`RenewalRiskAction`/risk scorer → `RenewalScheduleSnapshot` → `ScheduleUpdateAction`
(once per remaining schedule period). Confirm success by re-querying
`RenewalScheduleSnapshot` and seeing non-null `ProposedPlannedQuantity` values.

---

## Deploy order summary (copy/paste checklist)

1. Custom fields (§1)
2. Apex classes incl. `WorkshopDataSetup` (§2) — **deploy all in one command**
3. Seed data import (§3), then run `WorkshopDataSetup.setupSkylineDemo(accountId)` —
   populates Sales Agreement, products, activation, schedule actuals, adherence scores,
   and Assets in one call
4. Named Queries (§4) → **manually activate each in Setup**
5. MCP Server registration (§5) — **entirely manual, Setup UI**
6. Permission Set (§6) → assign to test user(s)
7. Connect MCP client (§7) — **manual OAuth connect, refresh after any later change**

Only three genuinely manual steps remain (confirmed non-automatable via Tooling API/Apex):
Named Query activation (§4 — `ApiNamedQuery` fields aren't updateable via Tooling API),
MCP Server + tool registration (§5 — Setup UI only, no deployable metadata for the
server/tool linkage), and the MCP client OAuth connection (§7 — an external auth handshake).
