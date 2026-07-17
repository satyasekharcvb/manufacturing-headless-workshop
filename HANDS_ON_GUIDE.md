# Hands-On Guide — Chapter 2 · Part B: ChatGPT

**Duration:** ~34 min · **Format:** 5 exercises, progressive MCP composition.
Your org is **pre-provisioned** (Apex, data, MCP servers, the agent). You focus on the hands-on.

Each exercise: *30-sec callback → quick look → hands-on prompt.* Run the prompts in order and watch how much reasoning shifts from you to the model.

---

## Setup — Connect ChatGPT to your Salesforce Org

You'll create an **External Client App** in Salesforce (the OAuth client ChatGPT logs in through), then register it as a connector in ChatGPT.

### A. In the Salesforce Org — create the External Client App

1. **Setup → App Manager → New External Client App.**
2. Name it `MaxTurbine Renewal ChatGPT App` and add your email.
3. Enable **OAuth Settings**.
4. **Callback URL:** paste the redirect URL ChatGPT gives you when adding the connector (see step C2).
5. **OAuth scopes:** add `mcp_api` and `refresh_token` (offline access).
6. **Require PKCE** — leave enabled.
7. Save. Open the app's **Settings → OAuth** and copy the **Consumer Key** and **Consumer Secret**.

### B. In the Salesforce Org — enable the MCP server

1. **Setup → MCP Servers.**
2. **Enable** the MCP server if it isn't already on.
3. Under the **Salesforce Servers** tab, **activate** `sobject-reads`.

### C. In ChatGPT — create the plugin

1. Turn on **Developer Mode**: click your **name → Settings → Connectors → Advanced**, and enable **Developer Mode**.
2. Click your **name → Settings → Plugins → Browse Plugins**.
3. Click **+** to create a new plugin.
4. Give it a meaningful name — e.g. `MaxTurbine Renewal`.
5. Copy the **redirect/callback URL** shown here back into step A4 if you haven't yet.
6. Select **OAuth** as the auth type.
7. Provide the credentials from the Salesforce Org — the **Consumer Key** and **Consumer Secret** from step A7.
8. In the Salesforce Org, click the **View Details** of `sobject-reads` MCP Server, copy its URL, and paste it as the **MCP endpoint URL** in ChatGPT.
9. **Agree → Connect** and complete the Salesforce login.

**Verify:** the plugin lists `sobject-reads`. You're ready for Exercise 1.

---

## Exercise 1 — Standard hosted MCP

**Hands-on:**

1. Start a **new chat** in ChatGPT.
2. Click the **+** in the message box and add your **`MaxTurbine Renewal`** plugin.
3. Now run these prompts in sequence:
   - `Find the Account for Skyline Aviation.`
   - `Now show me that account's active Sales Agreements and their recent adherence.` → calls `sobject-reads`
   - `Which of my accounts have Q3 renewals with declining adherence?` → composes reads across the portfolio

> You just queried live Salesforce data from ChatGPT with zero custom code — the hosted MCP server exposes standard reads directly. But notice the ceiling: the model can see *everything the running user can*, with no narrower scope. In Exercise 2 you'll watch a purpose-built tool tighten that down.

---

## Exercise 2 — Custom MCP with Named Query

**Idea:** one purpose-built query returns a scoped, joined shape — not the whole object graph.

**Look:** the Named Query joins Account + active Sales Agreements + key Contacts + Assets for a single account.

**Hands-on:**

1. In ChatGPT, refresh the connector — confirm `renewal_snapshot` appears.
2. `Show me the renewal snapshot for Skyline Aviation.`

> Scoped to the joined shape for one account — none of the user's other accounts leak through.

---

## Exercise 3 — Apex logic: risk scoring + a bounded write (8 min)

**Idea:** deterministic Apex the model can call — a read-only scorer and a tightly-bounded write.

**Look:**
- `RenewalRiskScorer` — returns a 0–1 risk score, adherence delta, open cases, days to renewal. Data-only, no interpretation.
- `Apply_Schedule_Update` — updates `PlannedQuantity` on **one** schedule record. Validates FLS, rejects closed periods and non-positive quantities.

**Hands-on:**

`Score Skyline's renewal risk. If it's high, look at the current schedule from renewal_snapshot and propose an updated PlannedQuantity for each remaining period to bring adherence back to 90%. Apply the updates.`

> ChatGPT chains ~4 calls: scorer → snapshot → `Apply_Schedule_Update` once per remaining period.

---

## Exercise 4 — Workspace Mail MCP (10 min) — the centerpiece

**Idea:** the real story lives *across* systems. Give the model email + calendar alongside Salesforce and let it synthesize.

**Look:** browse `/workspace/mail` and `/workspace/calendar` so you know what the model is about to read. Add the workspace MCP connector (MCP URL: `<workshop host>/workspace/mcp`, auth: none — a workshop stand-in).

**Hands-on:**

`Skyline's Q4 adherence is dropping. Give me the full picture — Salesforce, email, and meeting rhythm. What's actually going on?`

Expected chain: `renewal_snapshot` → `RenewalRiskScorer` → `search_emails` → `get_thread` → `list_meetings` → `get_meeting`.

> The diagnosis — quiet disengagement, a skipped QBR, a new CFO added to threads — exists in **no single tool**. It emerges from the model's synthesis across calls it chose to make.

---

## Exercise 5 — Agent as a standalone MCP endpoint (5 min)

**Idea:** expose the whole **Renewal QBR Assistant** agent as one MCP tool. The reasoning stays in Salesforce; the client just asks.

**Hands-on:**

`Prep my QBR for Skyline Aviation.`

> A single tool call returns the same governed briefing the rep got in Slack — identical everywhere.

---

## The trade-off

| | Exercises 2–4 (custom MCP + Mail) | Exercise 5 (agent as endpoint) |
|---|---|---|
| What the client gets | Ingredients | A finished briefing |
| Where reasoning lives | ChatGPT | Salesforce (the agent) |
| Composability | Free — the model weaves | None — the agent is opaque |
| Consistency across clients | Differs by client | Identical everywhere |
| Reach for it when | Novel cross-system questions | Standardized, opinionated output |
