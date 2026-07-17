Chapter 2 · Part B — ChatGPT
Duration: 34 minutes. Implements: ADR Decisions 1, 2, 3 (ChatGPT side).

Five beats, progressive MCP composition. Each beat: 30-sec callback → short code walkthrough → hands-on.

Beat 1 — Standard hosted MCP: SOSL + sObject reads (warm-up, 5 min)
Admin walkthrough (2 min):

Setup → App Manager → MaxTurbine Renewal ChatGPT App (External Client App):
OAuth scopes: mcp_api, refresh_token. PKCE required.
Profile-scoped to holders of Renewal Assistant User perm set.
Setup → MCP Servers: verify sosl-search and sobject-reads are both toggled on.
Hands-on:

In ChatGPT (Developer Mode on), Settings → Connectors → Add.
Paste the pre-provisioned External Client App consumer key. Complete OAuth.
Verify: connector shows both sosl-search and sobject-reads.
Run these prompts in sequence:

"Find the Account for Delta Aviation." → ChatGPT calls sosl-search.
"Now show me that account's active Sales Agreements and their recent adherence." → calls sobject-reads.
"Which of my accounts have Q3 renewals with declining adherence?" → composes both across the portfolio.
"FLS is enforced, but there's no narrower ceiling than 'whatever Priya can read.' That's what Decision 1b rejected. Watch the ceiling shrink in Beat 2."

Beat 2 — Custom MCP with renewal_snapshot (6 min)
Named query — all standard Manufacturing Cloud objects:

SELECT
  Account.Id, Account.Name, Account.Industry, Account.AnnualRevenue,
  (SELECT Id, StartDate, EndDate, CurrentAgreementValue,
          CurrentQuantity, Status, SchedAdherenceScore
   FROM SalesAgreements WHERE Status = 'Activated'),
  (SELECT Id, Name, Title, Email, Is_Key_Contact__c
   FROM Contacts WHERE Is_Key_Contact__c = true),
  (SELECT Id, AssetName, Status, InstallDate, Latitude, Longitude
   FROM Assets)
FROM Account
WHERE Id = :accountId
Steps:

Setup → MCP Servers: activate "MaxTurbine Custom MCP" (pre-configured; includes renewal_snapshot).
In ChatGPT, refresh the connector. Verify renewal_snapshot appears.
Prompt: "Show me the renewal snapshot for Delta Aviation."
The response is scoped — just the joined shape, none of Priya's other accounts.

Beat 3 — RenewalRiskScorer + Apply_Schedule_Update (Apex, 8 min)
public with sharing class RenewalRiskScorer {
    public class Request {
        @InvocableVariable(required=true label='Account Id') public Id accountId;
    }
    public class Response {
        @InvocableVariable public Decimal score;
        @InvocableVariable public Decimal adherenceDelta;
        @InvocableVariable public Integer openCasesInHubs;
        @InvocableVariable public Integer daysToRenewal;
    }

    @InvocableMethod(
        label='Score renewal risk'
        description='Compute a deterministic risk score (0.0–1.0) for an account renewal. Data-only; no interpretation.')
    public static List<Response> scoreRenewalRisk(List<Request> requests) {
        // ...
    }
}
And the bounded write — Apply_Schedule_Update writes exactly one field on one SalesAgreementProductSchedule record:

@InvocableMethod(
    label='Apply Schedule Update'
    description='Update PlannedQuantity on a single SalesAgreementProductSchedule record. Validates FLS. Fails if the schedule is in a closed period or the quantity is non-positive.')
public static List<Response> applyUpdate(List<Request> requests) {
    // FLS check + non-negative check + future-period check → single-field update
}
Hands-on: register both as MCP tools. Then prompt:

"Score Delta's renewal risk. If it's high, look at the current schedule from renewal_snapshot and propose an updated PlannedQuantity for each remaining period to bring adherence back to 90%. Apply the updates."

ChatGPT will chain ~4 tool calls — the scorer, the snapshot, and Apply_Schedule_Update once per remaining schedule.

Beat 4 — MaxTurbine Mail MCP (10 min) — the centerpiece
The workspace is at /workspace. Open /workspace/mail and /workspace/calendar briefly so you know what ChatGPT is about to read.

Add the workspace MCP connector to ChatGPT:

MCP URL: <your workshop host>/workspace/mcp
Auth: none (deliberately — this is a workshop stand-in).
Then prompt:

"Delta's Q4 adherence is dropping. Give me the full picture — Salesforce, email, and meeting rhythm. What's actually going on?"

Expected tool-call sequence:

renewal_snapshot(Delta)
RenewalRiskScorer(Delta)
search_emails("Delta")
get_thread(T-001) — the June 12 VP thread
list_meetings filtered to Delta contacts
get_meeting(M-003) — the skipped QBR
Expected diagnosis (approximately):

"Salesforce shows a 12% adherence drop concentrated in SEA hubs and 3 open cases. But the story is worse: their VP of Ops emailed on 2026-06-12 raising quality concerns and never got a satisfactory reply. Their procurement lead moved the monthly QBR twice in 6 weeks and skipped the last one. They've added their new CFO to the last two threads — someone we've never engaged. This isn't a service issue. Delta is quietly disengaging and staging a renegotiation."

"That diagnosis exists in no single tool. It emerged in the LLM's synthesis across six tool calls it chose to make. That's Decision 2, in the wild."

Beat 5 — Agent as standalone MCP endpoint (5 min)
Register the Renewal QBR Agent as an MCP endpoint. In ChatGPT:

"Prep my QBR for Delta."

Single tool call. Same governed briefing Rahul got in Slack. Response ends with a link to Fleet Health Command Center.

Beats 2 + 3 + 4 (custom MCP + Mail)	Beat 5 (Agent as endpoint)
What ChatGPT gets	Ingredients	A finished briefing
Where reasoning lives	ChatGPT	Salesforce (the agent)
Composability	Free — ChatGPT weaves	None — agent is opaque
Consistency across clients	Differs by client	Identical everywhere
Reach for it when	Novel cross-system questions	Standardized, opinionated output