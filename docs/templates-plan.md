# Templates: ready-made workflows anyone can install, run, change and share

## 1. What a Template is

A **Template** is a ready-made job that Opscode can do for you. You install it once and then it runs.

Each template is one bundle:

| Part | Example (Lead Finder template) |
|---|---|
| **Connectors** (accounts and tools it uses) | Gmail, Google Sheets, a lead source (Apollo or Apify), your CRM |
| **Skills** (know-how) | "Write a short cold email", "Classify a reply" |
| **Agents** (workers with a role) | Researcher, Email writer, Reply reader |
| **Automation** (the steps, in order) | Find leads → check emails → write → you approve → send → read replies → update the CRM |
| **Data** (its own small tables) | Leads, Sent emails, Replies, Unsubscribed |
| **Setup questions** | Your business, who to target, which mailbox, how many emails a day |
| **Safety rules** | Daily send limit, unsubscribe link, approval before sending |
| **Mode** | Usually SHINOBI (cheap); the person can switch |

There are two kinds:
- **Pre-made templates** ship with Opscode.
- **Your own templates:** you or anyone else can make one, often by saying "save this as a template", and share it.

## 2. What other products do (research)

- **n8n:** a template is a workflow file (JSON). Using one is: open the gallery, press "Use this workflow", then connect your own accounts for every step. Their guides say that connecting accounts is where most templates break. So **setup must check every connection before the first run.**
- **Claude Code plugins:** a plugin is one installable bundle of skills, agents, hooks and MCP connectors, with a small manifest. A **marketplace is just a GitHub repository** listing plugins (`.claude-plugin/marketplace.json`). Plugins add no new powers; they package existing ones. Hooks run code on the installer's machine, so **show what is inside before installing.**
- **Relevance AI, Gumloop, Lindy, Relay.app:** galleries of agent templates by category: lead generation, enrichment, outreach, CRM sync, LinkedIn posts, meeting briefs. Each is a ready agent plus its connections.
- **Caveman Code:** has no separate "template" idea. It ships its features as standard plugins (for example its automations plugin).
- **Cold email rules:**
  - Every email needs a working unsubscribe, honoured quickly.
  - Gmail and Yahoo require one-click unsubscribe and a low complaint rate.
  - The laws carry large fines: US CAN-SPAM per email, EU GDPR, Canada CASL; India's DPDP Act also covers personal data.
  - **A lead template must have these built in, not optional.**

(Sources: the n8n templates guide, the Claude Code plugin docs and the official marketplace repository, the Relevance AI / Gumloop / Relay template pages, the FTC CAN-SPAM guide. I read their summaries, not every full page.)

**Decision: build Templates on the standard plugin format.** A template is a normal plugin folder **plus one Opscode file, `template.yaml`**. That gives three things:
- Thousands of existing skills, agents and MCP connectors can be reused.
- Any GitHub repo can be a template marketplace, which covers the "GitHub" part you asked for.
- A template still works as a plain plugin in Claude Code.

## 3. What a template looks like on disk

```
lead-finder/
  .claude-plugin/plugin.json     standard plugin: name, version, author
  template.yaml                  Opscode: what makes it a template (below)
  skills/write-cold-email/SKILL.md
  skills/classify-reply/SKILL.md
  agents/researcher.md
  agents/email-writer.md
  .mcp.json                      connectors (Gmail, Sheets, Apify, CRM…)
  automations/outreach.yaml      the steps (Opscode automations format)
  data/tables.yaml               leads, sent, replies, unsubscribed
  README.md
```

`template.yaml` (short version):

```yaml
name: Lead Finder & Outreach
category: Sales
character: shinobi            # which emblem/character it shows
mode: shinobi                 # cheapest by default
inputs:                        # the setup questions
  business: { ask: "What do you sell, in one line?" }
  target:   { ask: "Who should we find? (e.g. restaurants in Kolkata)" }
  per_day:  { ask: "Emails per day per mailbox", default: 30, max: 50 }
connectors:
  gmail:   { why: "send and read replies", auth: oauth, scopes: [send, read] }
  apify:   { why: "find businesses on Google Maps", auth: api_key, optional: true }
  crm:     { why: "save interested leads", choose: [shotlincrm, hubspot, sheets] }
tables: [leads, sent, replies, suppression]
run:
  automation: outreach
  schedule: "weekdays 10:00"
safety:
  approve_first: 10             # you approve the first 10 emails
  daily_limit: "{{per_day}}"
  unsubscribe: required
  quiet_hours: "20:00-08:00"
  budget_tokens_per_day: 200000
```

## 4. The life of a template

1. **Gallery:** browse by category (Sales, Marketing, Video, Software, Support), search, and see the character and one line.
2. **Preview, before anything installs:**
   - what it does, step by step
   - which accounts it connects and why
   - what it may do: send emails, read the inbox, use files
   - expected cost per day for its mode
   - who made it
3. **Install wizard:**
   - answer the questions
   - connect each account; each one is tested
   - a **dry run** on 3 sample items shows exactly what would happen, and nothing is sent
4. **Run:** on its schedule, or "run now". It works through a Conductor and automations Opscode already has.
5. **Watch:**
   - a page per template with runs, an approvals inbox ("10 emails waiting for you"), its tables (for example the leads list) and its cost
   - everything stops if the budget or a limit is hit
6. **Change by chat:** "send the follow-up after 5 days, not 3", or "add WhatsApp". The Conductor edits the template and shows you the change.
7. **Share:**
   - "Save as template" turns a working chat or automation into a template
   - "Publish" puts it in a GitHub repo, which becomes your marketplace
   - others add that repo and install from it
   - updates arrive as new versions; you choose when to update

## 5. Four pre-made templates to start with

| Template | Steps | Connectors |
|---|---|---|
| **Lead Finder & Outreach** | Find businesses → find and verify emails → remove duplicates and anyone unsubscribed → write a personal email → **you approve** → send within limits → read replies → mark interested / not now / unsubscribe → update the CRM → follow up on day 3 and 7 → weekly report | Gmail or Outlook, a lead source (Apify Google Maps, Apollo, or your own CSV), an email checker, CRM (your **ShotlinCRM**, HubSpot, or a Sheet) |
| **Marketing posts** | Learn the brand voice → plan a monthly calendar → write posts → make images (Codex / ChatGPT images) → **you approve** → schedule → read results → plan next month | Instagram/Facebook (Meta), LinkedIn, Google Drive |
| **Video reels** | Raw clips in a folder → transcript → cut silences and mistakes → captions → music and b-roll → 9:16 reels → **you approve** → publish | Local folder, YouTube, Instagram; uses ffmpeg and the video skills you already have (HyperFrames) |
| **Software agency** | The customer pipeline already planned: requirement → spec → Library check → plan → UI → build → test → APK | GitHub, your Library templates (Grocery, Meat, Laundry…) |

The last one also answers your earlier message. A **code template** (for example "Grocery") is a template whose bundle is a set of **GitHub repos**: backend, app, dashboard, rider app. The Library indexes them together.

Your machine can already read your private GitHub repos through your saved git sign-in; I checked read-only. Your repos already form natural templates:
- **Grocery:** Bakaloo backend, dashboard and rider app
- **Meat:** meet-commerce backend, dashboard, mobile, rider and vendor
- **Laundry:** Lndry app, backend, dashboard and vendor app

## 6. What Opscode already has, and what to build

**Already built:**
- Plugins page with marketplace install
- Skills and sub-agents
- MCP connectors with API keys
- Automations: steps, schedule, approvals, retries, budget
- Conductor and the three modes
- Library: code index
- Usage limits and token tracking

**To build:**

| # | Piece | Why |
|---|---|---|
| T1 | **Template format and gallery** (`template.yaml`, built-in templates, GitHub marketplaces) | Templates exist and can be found |
| T2 | **Install wizard**: questions, permission summary, connection tests, dry run | Most templates fail at setup; this is where we win |
| T3 | **Data tables**: a small local database per template (leads, sent, replies), with a table view and CSV import/export | Lead and marketing work needs memory between runs |
| T4 | **Safety layer**: daily limits, quiet hours, unsubscribe + suppression list, approval gates, per-template budget, allowed websites, an activity log | Required by law for email, and protects your accounts |
| T5 | **Account sign-in (OAuth)** for Google, Microsoft, Meta, LinkedIn, YouTube, HubSpot, with tokens in the macOS Keychain | Gmail and social accounts need it; Opscode only has API keys today. **The biggest missing piece.** |
| T6 | **Triggers**: a new email or reply, a webhook, a new file in a folder, a form | "When a reply arrives…" |
| T7 | **Template page**: runs, approvals inbox, tables, cost | So you can see it work |
| T8 | **Create and share**: "Save as template", publish to a GitHub repo, install from a URL, versions and updates | Anyone can make templates |
| T9 | **The four pre-made templates** | Ready to use on day one |

**Order:**
1. T1 + T2 (with API-key connectors first)
2. T3 tables, then T4 safety
3. T5 Gmail sign-in, then T6 reply trigger
4. The **Lead Finder** template working end to end on your own mailbox, with approval on
5. T7 page
6. T8 sharing
7. The other templates

## 7. Decisions for you

1. **First template:** Lead Finder (recommended, real business value) or Marketing posts?
2. **Mailbox:** Gmail / Google Workspace, or Outlook?
3. **CRM:** your own ShotlinCRM (through its API), HubSpot, or a Google Sheet to start?
4. **Lead sources:** your own lists (CSV), Google Maps via Apify (paid, per result), Apollo (paid), or a mix?
5. **Who can publish templates:** only you (a private GitHub repo for Shotlin), or public later?

## 8. Responsibility notes

- Lead finding uses only sources whose terms allow it (official APIs and providers), not scraping sites that forbid it.
- Every cold email carries an unsubscribe and your business address. Opt-outs are honoured at once and kept forever in the suppression list.
- Sending starts slowly (warm-up) and stays under each mailbox's daily limit, so your domain isn't marked as spam.
- Templates from other people show everything inside (connectors, permissions, any code) before you install, because hooks run code on your Mac.

## 9. How connections and changes work when templates are shared

The problem: a shared template file **cannot carry anyone's logins**, and every person uses different tools. You might use ShotlinCRM, someone else Zoho, someone else an Excel sheet. The fix is to split a template into four layers:

| Layer | What it holds | Shared? |
|---|---|---|
| **Recipe** (`template.yaml`) | The steps, and the **slots** it needs: "a CRM", "a mailbox", "a place to save leads" | Yes |
| **Adapters** (`adapters/*.yaml`) | How one tool fills a slot: which MCP tool or API call does "create contact", and how fields map. No secrets | Yes, and reusable by other templates |
| **Bindings** (local only) | On *this* Mac: CRM = Zoho, mailbox = sayan@…, leads also go to `Leads.xlsx` | Never |
| **Secrets** (macOS Keychain) | Tokens and API keys from signing in | Never, not even in Opscode's files |

### Slots: the template asks for a *kind* of tool, not a specific one

```yaml
# template.yaml (shared)
slots:
  crm:
    kind: crm
    needs: [find_contact, create_contact, update_status, add_note]
    default: opscode_tables          # works with nothing connected
  mailbox:
    kind: email
    needs: [send, read_replies]
  lead_copies:
    kind: table_sink                 # extra places to save every lead
    many: true                       # zero, one or several
```

### Adapters: how a tool does those jobs

```yaml
# adapters/crm/zoho.yaml (shared; no secrets)
kind: crm
provider: zoho
connect: { mcp: "Zoho CRM (official)", auth: oauth }   # first use opens the browser to sign in
verbs:
  find_contact:   { tool: search_records, args: { module: Leads, criteria: "(Email:equals:{{email}})" } }
  create_contact: { tool: create_records, args: { module: Leads, data: { Last_Name: "{{name}}", Email: "{{email}}", Company: "{{company}}", Lead_Source: "Opscode" } } }
  update_status:  { tool: update_records, args: { module: Leads, id: "{{id}}", data: { Lead_Status: "{{status}}" } } }
  add_note:       { tool: create_note,    args: { parent: "{{id}}", text: "{{note}}" } }
```

Opscode ships adapters for the common tools:
- **CRM:** Opscode's own tables, Google Sheets, Excel file, HubSpot, Zoho, Pipedrive.
- **Email:** Gmail, Outlook.

Any other tool can get an adapter in three ways:
- **an MCP server** (official, from a plugin, or your own URL)
- **a plain web API** (URL, endpoints, API key)
- **a local file** (Excel / CSV)

### Bindings: what *this* person chose (stays on this Mac)

```yaml
# kept in Opscode's own data folder, never shared or exported
template: lead-finder
crm: zoho
mailbox: { provider: gmail, account: "sales@shotlin.com" }
lead_copies:
  - { provider: excel, file: "~/Documents/Leads/leads-2026.xlsx", sheet: Leads }
  - { provider: google_sheets, sheet: "Shotlin leads" }
```

### What happens when someone downloads a template

The install wizard walks through each slot and offers every way to fill it:
1. **Use an official connector**, e.g. Zoho CRM. A **Sign in** button opens the browser and the token goes to the Keychain.
2. **Use an MCP server you already have** (picked from the MCP page) or **add your own** by URL.
3. **Use your own API.** Paste the URL and key; Opscode reads the API docs and writes the adapter.
4. **Keep it in Opscode** (local tables). It works with nothing connected, and you can switch later.

Each slot is **tested before the first run**: a dry "find contact", and a test row written and then removed with your OK. A slot that fails says exactly what is wrong.

### Changing a template by chat (no code editing)

The template has its own chat, and you can type a change there:

> "Use Zoho instead of ShotlinCRM."

The Conductor:
1. Finds the Zoho adapter, or builds one from Zoho's MCP tool list.
2. Asks you to sign in.
3. Maps the fields (name → Last_Name, status → Lead_Status) and shows you the mapping.
4. Runs a test.
5. Saves the new **binding**.

The recipe isn't touched, so nothing else breaks.

Other requests work the same way:
- **"Connect my own MCP server at https://…"** It adds the server, lists its tools, and matches them to the slot's jobs. If a job has no matching tool, it says so instead of guessing.
- **"Make my own CRM."**
  - *Simple:* Opscode creates CRM tables (contacts, deals, notes) and a table view inside the template page. That needs no new app.
  - *Full CRM app:* the software-agency template builds one, and an adapter connects it.
- **"Also save every lead in an Excel sheet."** It adds an Excel copy to `lead_copies`. Every new lead is written to the CRM **and** the sheet.
- **"Send the follow-up after 5 days, and only to restaurants."** This changes the **recipe**. You see the change (before → after) and approve it first.

### Keeping data safe across many platforms

- **One source of truth:** every lead, email and reply is saved first in the template's **local tables**, then copied to the CRM, Sheets or Excel. If Zoho is down or a sheet is deleted, nothing is lost; the copy is retried later.
- **Two-way when it matters:** if you change a lead's status in Zoho, Opscode reads it back on the next run, so "unsubscribed" in any place counts everywhere.
- **Backups:** the local tables are backed up daily (kept 30 days), and can be exported to CSV/Excel at any time.
- **Permissions per template:**
  - Each template only gets the slots and scopes it declared (e.g. *send* + *read replies*, not *delete mail*).
  - Every action goes into an activity log.

### Your changes survive updates

Your changes are saved as **your layer** on top of the shared recipe, not inside it. When the author publishes v2, Opscode applies v2 under your layer:
- your Zoho binding stays
- your 5-day follow-up stays
- if v2 changed the same step you changed, it shows both and you choose

### Sharing safely

**Publish** exports only:
- the recipe
- adapters
- skills
- agents

It never exports bindings, secrets, data or account names. Before installing someone else's template, Opscode shows:
- every connector it wants and why
- every permission
- any code it runs (hooks)

## 10. One template, any mode

**The rule:** a template says **what** to do (steps, skills, connectors, checks). The mode says **how much power** to use. Every template works in all four modes without being rewritten.

### What each mode changes

| | **Normal** | **SHINOBI** | **WARLORD** | **GODMODE** |
|---|---|---|---|---|
| Who works | Your one chat follows the template's steps as a checklist; 1–2 helpers for heavy side jobs (UI images via Codex, reading test logs) | A Conductor with 1 worker at a time | A Conductor with up to 2 workers in parallel | A Conductor with up to 4 workers in parallel |
| Models | The model you picked | Sonnet medium; Opus at most once a day for a plan | Sonnet; Opus for complex plans | Opus for plans and hard parts, Sonnet for the rest |
| Checking the work | Tests you ask for | Smoke tests + a light review at the end | Full tests of what changed + review per milestone | Full test suite + button crawler + exploratory tests + Opus review per feature |
| UI refinement | 1 round | 1 round | 2 rounds | 3 rounds |
| You steer | Every step | Only at approvals | Only at approvals | Only at approvals |
| Best for | Small changes, learning a template, when you want control | Cheap jobs, one feature | Most projects | Big clients, risky work |

The template author doesn't fill this in for every template. A template **inherits this table** and only overrides what it needs. For example, Software Agency says testing in SHINOBI must still include API tests, because shipping an untested backend is never acceptable.

### Mix modes per stage (the most efficient way)

The mode can be set **per stage**, not only for the whole run. For the Software Agency template:

| Stage | Mode | Why |
|---|---|---|
| Plan | GODMODE | A wrong plan wastes everything after it; Opus pays for itself here |
| Build normal features | SHINOBI | Routine work, cheap |
| Build hard features (payments, auction) | WARLORD or GODMODE | Where mistakes are expensive |
| Test | WARLORD | Full tests of what changed |
| Final review | GODMODE | One careful look before the APK |

Each template ships with a sensible per-stage default; you change any stage with one click or one sentence.

Opscode may also **suggest** a stronger mode from facts. For example: "the gap report has 7 new features, 3 of them touch payments: WARLORD recommended for those". You decide.

### Make once, use in every project and session

- **Templates live in your template library** (Opscode's data folder) and in a GitHub repo (your marketplace). Installed once, they show up in every project and every new chat.
- **Using a template in a project** creates a *run* with that project's choices (which repo, which client, which mailbox). The template itself stays clean.
- **Templates improve over time.** When you correct something ("our APIs always return `{ data, error }`"), it is saved to the template's skill, with your OK, so every later project gets it.

### Where accuracy really comes from

More agents alone do not make work more accurate. What raises accuracy:
1. **Checking:** tests, the button crawler, review against the "done when" checks. This is the biggest lever.
2. **The right model on the hard parts:** Opus for plans and difficult logic, not for everything.
3. **Small, focused chats:** your logs showed chats averaging 434k tokens. Quality drops in very long chats, so even Normal mode should keep each task short (Opscode offers a hand-off past ~150k).
4. **Good context:** the Library gives each worker the right files instead of letting it guess.

So the modes scale mostly **checking depth and model choice**, and only partly the number of agents. Parallel agents mainly make work **faster**, not more correct.
