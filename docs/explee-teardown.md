# Explee teardown: how it finds leads, builds campaigns and runs outreach

**What this is:** a read-only analysis of the logged-in Explee account (project `63402`, domain `sayanthecoder.in`). It covers the UI, the JSON API the app calls, and the full log of the agent's tool calls for the campaign *"Growing Businesses Needing Custom Apps, Websites & Software Platforms"* (segment `379270`).
**Date of analysis:** 2026-11-17
**Purpose:** work out their method so we can build our own lead-finding and outreach engine (email first, then WhatsApp) inside Opscode.

> Nothing was created, sent, edited or paid for during this analysis. One side effect: opening a thread in the Inbox makes the app itself draft an auto-reply (a `POST .../auto-reply/...` it fires on open). That draft was not sent, and auto-replies are paused because no booking link is set.

---

## 0. TL;DR: how Explee actually works

1. **Explee does not scrape live when you run a campaign.** They have a **pre-built, pre-classified database** of about **400M people profiles** and their companies, stored in **ClickHouse** (tables `employees_companies_wide` and `companies`). Their site says it is *"merged from company websites, professional networks, and maps"*. That means LinkedIn-style profiles, company websites and Google-Maps-style listings.
2. **Every company already carries LLM-generated fields:** a one-line `description_short`, a short **`definition` label** (e.g. `'restaurant chain'`, `'wholesale distributor'`, `'logistics delivery company'`), NACE industry codes with confidence scores, a `domain_is_alive` score, web `traffic`, size and country. **This is the secret sauce.** Lead finding becomes an SQL filter on `definition` instead of a keyword search.
3. **Every person has a normalised job title** (`job_title` with an ID, e.g. `8020392 = Owner`, `4304702 = Founder`, `1795650 = CEO`) next to the raw `title`.
4. **The campaign agent is an LLM with three tools:** `clickhouse_query` (SQL), `execute_python` (pandas over parquet files) and `ai_scoring` (LLM scoring of rows against plain-English criteria). It probes, pulls, cleans, scores samples, fixes its own filters, and writes a final `people.parquet` of person IDs.
5. **A separate import hook** ranks, scores, dedupes and geo-filters that pool, then inserts leads into the campaign in windows. Our campaign got **10,151 leads** (9,951 currently in the pool).
6. **After approval, email enrichment runs.** Only **1,131 of 9,951 (≈11%)** came out with a usable email; 6,764 had none. Explee's own UI admits *"only ~30% of leads come with a usable address"*.
7. **Sending happens from Explee's own pool of warmed lookalike domains** (183 mailboxes on 60+ domains like `meetorbitline.com` and `joinriseforge.com`) under **made-up sender personas** ("Kevin Hudson at sayan the coder"). They use one short, personalised first email in the lead's own language, AI reply classification, and AI auto-replies grounded in "Reply facts".
8. **Results so far:** 748 emails sent, 15 replies (2.0%), 7 hot (0.94%), cost $29.96 ($0.04/email). Sending is paused because of an unpaid balance.

---

## 1. App map: every screen and what it does

| Area | URL | What it is |
|---|---|---|
| Dashboard | `/app-auto-gtm/p/63402` | KPIs (emails, LinkedIn, hot leads, spend over 7 days), campaign table with state, spend and cap, "Today's decisions", balance and top-up, daily email budget |
| Campaign (segment) | `/p/63402/segments/{id}` | Left: **Chat** with the agent (plan + tool log). Right: **Campaign / Leads / Progress** tabs |
| New campaign | `/p/63402/new` | **Auto-create** (type an audience name and the ICP auto-fills in about 5 s) or **Import leads** (CSV), plus geography |
| Inbox | `/p/63402/inbox` | Email + LinkedIn replies, filters by intent (Hot, OOO, Not interested…), thread view, AI-drafted reply, Cc, attach |
| Sent | `/p/63402/inbox?tab=sent` | Everything sent |
| Project docs | `/p/63402/docs` | Company profile (scraped from your site), **competitors**, **Reply facts** (pricing, capabilities, proof), extra documents, shared files |
| Channels | `/p/63402/channels` | Email ($0.04/email) and LinkedIn ($49/month per account after a 7-day trial, via **Unipile**) |
| Email sequence | `/p/63402/emails` | First email + follow-ups, sender name, mailbox names, language = "lead's language", A/B variants (AI or "My copy"), instructions up to 3,000 characters |
| LinkedIn sequence | `/p/63402/linkedin-sequence` | Connection-request note (300 characters), message, follow-up |
| Auto-replies | `/p/63402/replies` | Reply instructions, booking link (required, or auto-replies pause), one nudge after 2 working days, auto-send after a 4-hour review window, Cc |
| Sending schedule | `/p/63402/schedule` | Per-country days and local-time windows ("smart sending days") |
| Targeting | `/p/63402/targeting` | Project default geography + company size, with a "Save & re-search" button |
| Integrations | `/p/63402/integrations` | HubSpot, Zapier, GoHighLevel, Make, n8n, Slack, CSV, API key, signed webhook on every hot lead or reply, plus a "Claude or ChatGPT" prompt |
| Suppress list, Own domains & mailboxes | sidebar | Blocklist; bring your own sending domains |

**Tech stack seen:** Next.js frontend behind Cloudflare. A REST JSON API under `/api/app-auto-gtm/*` and `/api/agent-chat/*`. ClickHouse for the people database. A Prefect-style job queue (`flow_run_id`, `work_queue_name: "agent-chat-interactive"`). Mailboxes from **Icemail** (`mailbox_id: "icemail:k@meetorbitline.com"`). LinkedIn through **Unipile**. Site screenshots from **thum.io**. Favicons from Yandex. The sub-agent's tool IDs look like `chatcmpl-tool-…`, which points to an OpenAI-compatible endpoint (vLLM or open-weights style). The orchestrator's `usage` events report `cache_creation` and `cache_read`, which is Anthropic-style prompt caching.

---

## 2. Project level: what Explee learns about *you*

From `GET /api/app-auto-gtm/projects/63402`:

```json
"domain": "sayanthecoder.in",
"company_name": "sayan the coder",
"description": "Independent DevOps and app developer offering full-stack development, Flutter mobile apps, AI workflows, and cloud infrastructure services. Founder of Opslin ... and Shotlin ...",
"info": { "industry": "Software Development / DevOps / Cloud Services", "location": "Kolkata", "geo_country": "India",
          "product_description_200w": "Freelance full-stack DevOps development" },
"competitors": ["vaibhavk.in","abhishekgarg.xyz","ravikumar.work","mojasim.com","duboiss.fr","darknezz.dev",
                "corymay.com","kevinhughes.ca","mickael.be","hagi-lerman.com","samuelakpo.com","r15cookie.com","markfrancis.io"],
"target_geo": "US and Canada only (United States, Canada), United Arab Emirates, English-speaking countries (US, UK, CA, AU, NZ, IE)",
"target_company_size": "Startups (1–50), Mid-market (51–500)",
"followup_rules": { "max_touches": 2, "delay_days": 3, "stop_on_reply": true },
"auto_reply_enabled": true, "auto_reply_delay_minutes": 240, "auto_nudge_enabled": true, "autopilot_enabled": true,
"reply_cc_emails": ["sayan@opslin.com"],
"schedule": { "days": ["mon".."sun"], "days_source": "user" }
```

### How the pipeline starts (plan steps)
Every campaign runs the same 4-step plan: **Research Company → Find Competitors → Find Companies & People → Outreach**.

- **Research Company** scrapes your website. It produces the company profile above plus cached *"determinants + search queries"* that later steps reuse.
- **Find Competitors** produces 13 lookalike domains. For you these are **other freelance developer portfolio sites** (vaibhavk.in, ravikumar.work, corymay.com…). In practice that means "sites similar to yours", found by similarity search over their website corpus. The list is used to (a) understand positioning and (b) **exclude competitors from targeting**. That is the negative criterion "Companies selling competing development services".
- Both are cached per project. The campaign log says: *"skipping research_company (cached determinants + search queries) and find_competitors (13 competitors cached)"*.

### Project docs → "Reply facts"
These are free-text fact sheets the auto-reply AI is only allowed to answer from: **Pricing**, **Capabilities & integrations**, **Proof & case studies**, plus extra documents and attachable files. Yours include guardrails like *"Do not promise fixed prices… Do not invent testimonials"*, and the AI respected them in a real reply ("I can't name clients or specific cases, but the portfolio has…").

---

## 3. Campaign (segment) design: every field

From `projects/63402 → segments[]` and the Campaign panel. These are the fields that drive lead finding:

| Field (UI) | API key | Your value (campaign 379270) | How it's used |
|---|---|---|---|
| Campaign name | `name` | Growing Businesses Needing Custom Apps, Websites & Software Platforms | Audience label; with Auto-create, typing this alone generates everything below |
| Short description | `description` | "Off-the-shelf tools no longer fit core operations" | One-line pain headline |
| Channels | settings | Email ✅, LinkedIn ✅ | Which senders to use |
| What you offer | `use_case` | "I design and develop custom mobile apps, professional websites, SaaS platforms, e-commerce and quick-commerce…" | Email copy + scoring context |
| Customer problem | `pain` | "Business owners and founders struggle to launch digital products due to high development costs…" | Email hook + ICP reasoning |
| Targeting – geography | `target_geo` | United States, Canada, United Arab Emirates, Australia | Becomes `geo_country IN ('US','CA','AE','AU')` |
| Targeting – size | `target_company_size` | Startups (1–50), Mid-market (51–500) | Becomes `size BETWEEN 1 AND 500` |
| Booking link | `own_booking_url` / project | **Not set** | Needed for auto-replies; this is why they're paused |
| Example clients | `example_clients` | Urban Company; regional grocery and supermarket chains; growing D2C and e-commerce brands; multi-location restaurants and food; delivery and logistics startups; service businesses expanding online | **The agent turns these into `definition` labels to query** |
| Positive criteria | `positive_criterias` | Growing digital operations; needs custom workflows; small internal tech team; expanding online; launching a digital product; needs custom app or website; **managing orders manually via WhatsApp**; opening new stores or branches; needs e-commerce/POS/CRM/ERP; active digital marketing | Used in LLM scoring (company fit) |
| Negative criteria | (in context) | Enterprise procurement; purely brochure websites; large enterprises; students and academic projects; no dev budget; freelancers seeking jobs; **competing dev services**; unrelated software vacancies | Become SQL `NOT definition IN ('software development agency','web design agency','digital marketing agency')` and regex filters |
| Keywords | (in context) | custom software, web app, mobile app, workflow automation, devops, cloud setup, startup build | Search/relevance hints |
| Target role | `decision_maker` | Founders and CEOs, Head of Sales, Marketing leaders, MDs, Startup Founders, Retail Owners, Digital Transformation Managers, IT decision-makers; *exclude individual contributors* | Becomes `job_title IN ('Founder','CEO','Managing Director','Owner','Head of Sales','Marketing Director','Digital Transformation Manager','IT Director','Chief Technology Officer')` |
| Daily cap | `daily_limit_usd` | $30/day | Budget = emails/day ÷ $0.04 → up to 750/day |
| Language | `language` | auto (lead's language) | Wrote Arabic to UAE, French to Québec, Russian to Kyrgyzstan |
| Follow-ups | `followup_rules` | 2 touches, 3-day delay, stop on reply | Starter plan is limited to 1 follow-up (Growth: 3) |
| Email template | `settings.email_templates.1/2` | Variant "a", kind `brief`, 100% split, empty instructions | AI writes each email from scratch per lead |

### Your 7 campaigns

| ID | Name | Pain (short) | Example clients | Decision maker | Daily $ | Status |
|---|---|---|---|---|---|---|
| 379270 | **Growing Businesses Needing Custom Apps…** (you made this one) | Off-the-shelf tools don't fit | Urban Company, grocery chains, D2C, restaurants, logistics | Founders, CEOs, MDs, IT | 30 | Paused (billing) |
| 379115 | Market Platform Teams (demo) | Hard to coordinate buyers/sellers | Quikr, Ninjacart, Magicpin | Product/platform leaders | 10 | Stopped |
| 379116 | Marketplace builders (demo) | Need two-sided platform built | Urban Company, BharatPe, Indiamart | Founders / tech leads | 3 | Paused |
| 379117 | Mobile App Brands (demo) | One app team for both platforms | Urban Company, Cred | Product leaders | 15 | Paused |
| 379118 | D2C Brands (demo) | Sales grow faster than systems | mCaffeine, The Man Company, Sleepy Owl | Founders / ops | 7 | Paused |
| 379119 | Mobile app teams (demo) | One team for build + upkeep | HealthifyMe, CRED, Smallcase, Licious | Eng / product leads | 5 | Paused |
| 379120 | Marketplace Operators (demo) | Manual marketplace ops | Pepperfry, Fashinza, IndiaMART | Ops leaders | 3 | Paused |

The six "demo" campaigns were **auto-generated from your website** (`created_by: "demo"`). Their example clients are all **Indian** brands, while targeting says US/CA/AE/English-speaking. That mismatch is part of why off-geo leads appeared (see §7).

---

## 4. Lead finding: the exact method (most important section)

This is reconstructed step by step from the 59 tool calls in `GET /api/agent-chat/sessions/{id}/events`. The agent ran 22 minutes, used 373k input and 202k output tokens, and made **28 SQL queries, 20 Python steps and 11 AI-scoring runs**.

### 4.1 The database it queries

**Table `employees_companies_wide`** (one row per person × company):

| Column | Meaning |
|---|---|
| `person_id` | Person key (int64) |
| `explee_id` | Company key |
| `full_name`, `title`, `headline` | Raw person data (LinkedIn-style; `title` can be "Propietario", "Founder and Owner", even "founded by") |
| `job_title` (+ `JOB_TITLE_ID`) | **Normalised title** from a fixed vocabulary (Owner=8020392, Founder=4304702, CEO=1795650, CTO=1842687…) |
| `name`, `domain` | Company name and website |
| `geo_country` | ISO-2 country |
| `size` | Employee count |
| `industry` | LinkedIn-style industry (often empty `∅`) |
| **`definition`** | **LLM-assigned company-type label**: `'e-commerce brand'`, `'grocery supermarket chain'`, `'restaurant chain'`, `'logistics delivery company'`, `'retail store chain'`, `'direct-to-consumer brand'`, `'online marketplace platform'`, `'wholesale distributor'`, `'fitness gym studio'`, `'real estate agency'`, `'dental clinic'`, `'convenience store chain'`, `'home services company'`, `'online retail store'`, `'software development agency'`, `'web design agency'`, `'digital marketing agency'`… |
| `description_short` | LLM one-liner written from the website ("Local restaurant chain with online menus and DoorDash delivery…") |
| `traffic` | Monthly web traffic estimate |
| `domain_is_alive` | 0–1 liveness score |
| `relevance` | Ranking score (~14–16), likely search relevance to the campaign context |

**Table `companies`**: company-level with `description_short` and long `description`.

**Company record the UI shows** (from `/segments/{id}/leads`): `Name`, `Description`, **`Industries (NACE)`** (up to 3 codes with `sector_score`/`activity_score`), `Hiring` flag, `Size` bucket, `Emails` (masked), **`Phones`** (e.g. `+971…`), `url`, `screenshot_url`, `favicon`.

**Person record:** `Full Name`, `Job Title`, `Geo`, `linkedin_url`, `profile_photo_url` (licdn), `Email` (masked until sent), **`email_status`** (`valid` / `catch_all` / `catch_all_valid` / `invalid`), `linkedin_status` (`parked` / `rejected`), `manual_status`.

> **Key insight:** they did the hard work *offline*. Every company website was crawled, summarised by an LLM, and tagged with a short "definition" plus NACE codes. That is why one SQL query with `definition IN ('restaurant chain')` returns 25,457 matching decision-makers in 13 seconds. **For our version this classification layer matters more than the scraper.**

### 4.2 Step by step: what the agent did

**Step A, probe (calls #1–15).** For every vertical implied by "Example clients", it runs a `LIMIT 100` probe to see volume and quality:

```sql
SELECT person_id, full_name, title, job_title, name, domain, geo_country, size, industry
FROM employees_companies_wide
WHERE definition IN ('restaurant chain')
  AND job_title IN ('Founder','CEO','Managing Director','Owner','Head of Sales',
                    'Marketing Director','IT Director','Chief Technology Officer')
  AND geo_country IN ('US','CA','AE','AU')
  AND size BETWEEN 1 AND 500
LIMIT 100
```

| `definition` probed | Matching rows |
|---|---|
| e-commerce brand | 2,441 |
| grocery supermarket chain | 4,099 |
| restaurant chain | 25,457 |
| logistics delivery company | 72,325 |
| retail store chain | 2,018 |
| direct-to-consumer brand | 548 (all one domain, lularoe.com, so **rejected**) |
| online marketplace platform | 14,935 |
| wholesale distributor | 7,893 |
| fitness gym studio | 63,724 (probed, not pulled) |
| real estate agency | 363,064 (probed, not pulled) |
| dental clinic | 72,093 (probed, not pulled) |
| convenience store chain | 1,670 |
| home services company | 10,765 |
| online retail store | 13,202 |

The UI renders each probe with histograms (size, title, domain, geo). That is how the agent "eyeballs" concentration, e.g. canadiantire.ca taking 18 of 100 rows means a data-quality problem.

**Step B, read descriptions (calls #8–11).** It re-queries with `description_short, traffic, domain_is_alive` and `LIMIT 40 BY explee_id` (one row per company) to sanity-check that the companies really are what the label says.

**Step C, pull (calls #16–21, #29–31).** Full pulls with stricter filters, written to parquet files (`p_resto`, `p_grocery`, `p_ecom`, `p_retail`, `p_wholesale`, `p_logi`, `p_cstore`, `p_home`, `p_estore`):

```sql
SELECT person_id, explee_id, full_name, title, job_title, name, domain, geo_country,
       size, industry, description_short, traffic, relevance
FROM employees_companies_wide
WHERE definition IN ('e-commerce brand')
  AND NOT (definition IN ('software development agency','web design agency','digital marketing agency'))
  AND job_title IN (... + 'Digital Transformation Manager')
  AND geo_country IN ('US','CA','AE','AU')
  AND size BETWEEN 1 AND 500
  AND domain_is_alive > 0.5          -- only live websites
  AND domain NOT IN ('canadiantire.ca')  -- kill a polluted cluster seen in the probe
LIMIT 5 BY explee_id                 -- max 5 people per company (avoid spamming one org)
LIMIT 3000
```

**Step D, merge and dedupe (Python).** Concatenate, sort by `relevance` and `drop_duplicates('person_id')`. Result: 54,827 people at 36,638 companies.

**Step E, hygiene (Python, iterative).** Each rule was found by inspecting the data:
- **Placeholder / site-builder domains removed:** `atom.com, godaddysites, weebly, wordpress, blogspot, business.site, wixsite, squarespace, myshopify, amzn.to, temu.com…`
- **Bad titles removed:** `former|intern|student|recruiter|talent acquisition`, plus pseudo-titles parsed from website text (`founded by`, `owned by`, `owned and operated`, `family owned`, `shareholder`, `established`, bare `GM`)
- **Store-level General Managers removed** unless the title also says VP/President/Owner/Founder/Director/Head/Group (2,519 rows)
- **Logistics owner-operators removed** (single-truck drivers): `owner.?operator|owner op|independent contractor` (663 rows)
- **Off-vertical removed:** real-estate leakage inside "home services" (2,883 rows, 5.7%), plus dev-agency lookalikes (competitor filter)
- **Templated "domain farms" removed:** groups where ≥10 different domains share the *identical* `description_short` (spun SEO sites, e.g. 18 "North Texas electrician" domains) → 263 rows; generic names ("My Store", "Milestone", "6pm") flagged
- **Integrity asserts:** unique person_id, geo ⊆ {US,CA,AU,AE}, size 1–500

**Step F, calibrate with AI scoring on samples (11 `ai_scoring` calls).** It samples 1,000 companies and 1,000 people and asks an LLM to score each row against plain-English criteria. Each row gets `criterion_N_score` + `criterion_N_reason` + `total_score`. Then it reads the low scorers and rewrites the criteria:

| Attempt | Criteria | What it learned |
|---|---|---|
| 1 (companies) | "operating business that sells physical products/consumer services…", "not software/web/IT agency", "multi-location or online sales" | Too strict: logistics and hospitality scored low |
| 2 | "operating business in retail, food, grocery, …, logistics or home services", "offers products/services", "shows growing digital ops" | Better |
| 3 | Added "trucking, freight, delivery" explicitly | Fixed logistics |
| 4 (final) | **"is a real operating business that sells goods or services to customers"** | Simple sanity check; ~all pass |
| People 1 | "ownership/top-executive role", "authority to choose software vendors" | Scorer marked plain "Owner" low because it had no context, so **this is a false negative** |
| People final | Mechanical: "title contains owner/co-owner/proprietor/propietario…", "contains founder/CEO/president/MD/managing partner", "contains director/head of sales, marketing, IT, digital" | Reliable |

> Lesson they apply: **LLM scoring is for calibration and QA, not the main filter.** The main filter is structured SQL plus regex hygiene. Scoring runs fast (1,000 rows in 3–28 s, with a `ch_enrich` step that joins extra ClickHouse context first).

**Step G, manual QA reads.** It prints 30–40 random rows several times and reads them "like a human" before finalising.

**Step H, output.** `people.parquet` = **47,489 person_ids at 32,783 companies** (US 39,634 · CA 4,116 · AU 2,003 · AE 1,736). By vertical: logistics 15.3k, restaurants 12.9k, online retail 5.6k, home services 5.1k, wholesale 4.5k, grocery 2.0k, convenience 1.1k, retail 0.5k, e-commerce 0.5k.

### 4.3 Import into the campaign (`lead_import` hook)

The artifact registered **200,388 candidate rows** (a background `lead_search` hook ran in parallel during the agent's work). Then the hook:
1. **ranking**: ranks all 200,388
2. **fetching / scoring**: takes the top window (~1,031) and scores it
3. **inserts** with full accounting:

```json
window 1: inserted 9128, deduped_in_wave 402, filtered_geo 254, filtered_no_domain 211, filtered_dach 5
window 2: inserted 1023, deduped 8, filtered_geo 11, filtered_no_domain 9
dedupe layers: in_wave, project, campaign, blacklist, domain; filters: geo, size, DACH, no_domain, target_list
```

4. Announces *"Found 10151 unique leads. Review and approve to start outreach."* The campaign moves to **review** with a 12-hour auto-approve timer (`auto_approve_timeout_s: 43200`, up to 5 rejects). You approved it manually at 05:51.
5. Announces *"Campaign launched. Enriching emails for 10151 unique leads — sending will start automatically within 10–15 minutes."*

### 4.4 Email enrichment (the real bottleneck)

From the Progress tab:

| | Count |
|---|---|
| People found (pool) | **9,951** |
| Can be emailed | **1,131** (11%) |
| No usable address | **6,764** (68%) |
| Still checking | 2,056 |
| LinkedIn pool | 52 (all inactive: account disconnected) |

The emails are pattern-guessed on the company domain and then verified (`valid` / `catch_all` / `catch_all_valid` / `invalid`). Catch-all addresses still get sent to. Small local businesses (restaurants, truckers) mostly have no findable personal address. **That is why 10k leads became only ~1.1k sendable.**

In the 100-lead sample: 80% of companies have 1–10 staff, titles are mostly Founder/CEO/Owner, 98% are "not hiring", and phone numbers exist on company records. Those phones are the obvious input for a WhatsApp channel.

---

## 5. Outreach engine (email)

### 5.1 Sending infrastructure
- **Their own warmed mailboxes, not yours.** 748 sends went out from **183 different mailboxes on 60+ lookalike domains**: `corejust.co`, `useboldripple.com`, `connectvibekit.com`, `meetkeenspirit.com`, `heytidegrove.com`, `meetorbitline.com`, `joinriseforge.com`, `warmbase.digital`, `anchorfresh.org`, `pointkeen.org`, `heyvoxhq.site`… That is about 4 emails per mailbox, which keeps every inbox under spam thresholds. Provider: Icemail.
- **Fake sender personas.** Each mailbox has a random human name, and the email says *"I'm Kevin Hudson at sayan the coder"*, *"I'm Ishmael Aguilar at sayan the coder"*. Custom sender name is a paid (Growth) feature.
- **Schedule:** local business hours per country (US 8–20 ET, CA 8–19 ET, AU 8–17 AET, AE 8–16 GST), all 7 days, with "smart days" that respect local weekends.
- **Cost:** $0.04 per email from a prepaid daily budget. $29.96 spent in total. Sending stopped on 2026-11-07 for `billing_pause` (balance $0); replies are still monitored.

### 5.2 The email copy pattern (from real sent emails)
Every first email follows the same 4-beat structure, around 70–90 words, a 1–2 word subject, no links, and **written in the lead's language** (Arabic, French, Russian seen):

1. **Specific observation from their website:** *"I came across PointForth's final mile and white glove delivery work and the mix of routed deliveries, real-time tracking and multi-location warehouse operations stood out."*
2. **Who I am + what I build (one line):** *"I'm Dave at sayan the coder. I build custom logistics software, from mobile apps for drivers to order, inventory and dispatch systems."*
3. **Tailored outcome for them:** *"…ordering built around your pickup windows and family meals, without patchy add-ons."*
4. **Low-friction ask (never a call):** *"Mind if I send over a few short written ideas on …?"*

Subjects are short nouns about their operation: "Online ordering", "Final mile", "Field Booking", "Program Enrolments", "Wholesale orders", "Commande en ligne", "Продавцы". This is the deep-research agent at work: it reads the lead's site and writes one brief per lead (template kind `brief`).

### 5.3 Reply handling
- **AI intent classification** of every reply: `hot_lead`, `out_of_office` (follow-ups wait until the return date), `not_interested`, `email_changed` (the new contact gets added), `recipient_gone` (suppressed), `auto_acknowledgement`, `self_reply`.
- **Lead statuses:** Hot → Demo → Call booked → Won / Lost / Unqualified.
- **Auto-reply:** an AI draft grounded only in Reply facts, sent after a 4-hour review window, Cc to you. **Requires a booking link**, otherwise it's paused (your current state). A hot lead that goes quiet gets one nudge after 2 working days.
- **The "Yes" reply flow:** when a lead says "yes", the AI sends the promised "short written ideas" (3–4 numbered product ideas tailored to them) plus your portfolio link.
- **Hot-lead export:** webhook / HubSpot deal / Zapier / Slack / n8n / Make.

---

## 6. Results review: your inbox

**Totals:** 748 emailed · 15 replied (2.0%) · 7 hot (0.94%) · 4 not interested · 2 OOO · 1 email-changed · 6 bounced. Explee's own projections assume a 0.25–0.45% reply rate and a 0.06–0.24% meeting rate, so this campaign beat their averages.

| Lead | Company (country) | Vertical | Reply | Status |
|---|---|---|---|---|
| Basel Sarhan, Founder | LOQTAH.ae (AE) | Online snack store, 3 staff | "مرحبا نعم" ("Hi, yes") to an Arabic email | **Hot, needs your reply** |
| Michael Outram, Owner | Tag Performance (CA) | Gymnastics studio | "Yes" | Hot; ideas sent |
| Amirkhan Mukashev, CEO | Bazar Market KG (**Kyrgyzstan**) | Marketplace | "Send info about your company and case studies" | Hot (off-geo) |
| Russ Blanco, GM | Pointblanc Agency | Sales agency | "I'll look at it yes" | Hot |
| Leo Silveira, Managing Partner | PointForth (CA) | Logistics, 32 staff | "Sure, send me some materials" | Hot |
| Phillip Manesh, CEO | Calibre Restaurant Solutions (CA) | Restaurant ordering SaaS (**a competitor-ish lead**) | "You build apps?" | Hot |
| Karan Thakur, Owner | Calories restaurant (CA) | Restaurant | "Yes. Thank you" | Hot |
| Prosper Simba, Founder | Gabs Eats (**Botswana**) | Food delivery | Forwarded to CTO | Marked Unqualified |
| James Zahos, CEO | Business Express (CA) | Courier | Auto-reply with other contacts | Email changed |
| Dave Thompson, GM | Ottawa Megadome (CA) | Sports facility | "Happy with current setup" | Not interested |
| Ralph Meyer, Owner | RMMT (CA) | Moving | "Not interested" | Not interested |
| Neil OConnell, MD | Interactive Consulting (US) | Consulting | "I'm building myself" | Not interested |
| Morgan Lam, Director | Alpha Match (**Hong Kong**) | AI app studio (competitor) | "Already have it" | Not interested |
| Ignazio Oliveri, Connie McInnes | Trans-Cité (CA), RStudios (CA) | Courier, fitness | Out of office | OOO |

**Patterns:**
- **Canada is the best market.** 201 of 748 sends went to `.ca` and about 9 of 15 replies came from Canada. Owners of small logistics, restaurant and fitness businesses reply.
- **Short "yes" answers to the soft ask are the norm.** The "may I send ideas?" CTA works.
- **Off-geo leakage is real.** Sends went to `.in` (15), `.kg`, `.id`, `.ma`, `.kw`, `.ee`, `.uk`, and replies came from Kyrgyzstan, Botswana and Hong Kong. The causes: (a) the six demo campaigns with Indian example clients and a wide "English-speaking" geo, and (b) `geo_country` is the *person's* location, not the company's (e.g. a KZ founder of a .kg marketplace). Their own `why_fits` even flags it: *"outside the target geos"*.
- **The competitor filter leaks.** Calibre (restaurant SaaS) and Alpha Match (AI app studio) are dev/product companies that got through.
- **Follow-ups never ran** (0 sent): billing paused the campaign one day after launch.

---

## 7. Weak points in Explee (where we can do better)

1. **Email coverage of about 11%.** Most found SMB owners can't be reached by email. **WhatsApp and phone are the missing channel.** Company records already hold phone numbers.
2. **Geo is filtered on the person, not the company,** and demo campaigns use a "English-speaking countries" catch-all. We should require company HQ ∈ geo **and** person ∈ geo, and check the domain TLD.
3. **Fake personas and lookalike domains** hurt trust and are legally risky (see §8). Prospects reply to "Kevin Hudson", then meet Sayan.
4. **The competitor exclusion is label-based only.** It needs a second LLM check on `description_short` for "sells software/app/dev services".
5. **No intent or timing signals.** Leads are static database rows, with no "just opened a 2nd branch", "hiring a developer", "launched on Shopify last month" or "takes orders via WhatsApp only". `Hiring` was false for 98%.
6. **Each campaign is one big pool** (10k leads at $0.04 each), with no fast feedback loop by vertical. The data says logistics and restaurants in Canada work, so concentrate budget there.

---

## 8. Compliance notes (must read before we build)

- **Email:** the US (CAN-SPAM) allows B2B cold email but needs a truthful From/identity, a physical address and an opt-out. **Canada (CASL), our best market, is stricter.** It needs implied consent (e.g. a business email *conspicuously published* with no "no solicitation" note, and a message relevant to their role), sender identification and an unsubscribe. The UAE and Australia (Spam Act) also require identification plus unsubscribe. → We should use **real sender names** ("Sayan from sayanthecoder"), an unsubscribe line and a suppression list.
- **WhatsApp:** cold messaging scraped numbers through unofficial WhatsApp Web automation breaks WhatsApp's terms. It gets numbers **banned quickly** and is illegal in some places. The legitimate route is the **WhatsApp Business Platform (Cloud API)**: business-initiated messages only through **pre-approved templates**, and per Meta policy **only to people who opted in**. So WhatsApp fits as a **second touch after a positive email/LinkedIn reply or a website opt-in**, or for leads who asked to be contacted on WhatsApp. It does not fit as a cold blast to 10k numbers.
- **Scraping:** company websites and public map listings are generally fine to crawl politely (robots.txt, rate limits). LinkedIn profile scraping is against LinkedIn's terms. Explee gets LinkedIn-style data from a data vendor, and we should do the same (buy or license) rather than scrape LinkedIn ourselves.

---

## 9. Blueprint: our own version inside Opscode (draft for discussion)

The same architecture, built our way:

```
[1 Research]  your site → profile, offer, pain, reply-facts, competitor list (similar-site search)
      │
[2 ICP brief] campaign: name, offer, pain, geo, size, example clients, +/- criteria, keywords, roles
      │
[3 Lead DB]   ── offline, continuous ────────────────────────────────────────────────
      │   sources: Google Maps/Places (local SMBs + phone + website), company websites (crawl),
      │            licensed people data (Apollo / PDL / Prospeo / LeadsForge-style APIs),
      │            directories (Yelp, Shopify store lists, BuiltWith-style tech detection)
      │   LLM enrichment per company: description_short, definition label, NACE, is_alive,
      │            signals (orders via WhatsApp? online ordering? # of locations? tech stack?)
      │   store: ClickHouse or Postgres + pgvector (companies, people, definitions)
      │
[4 Agent]     LLM + tools {sql, python, ai_score} → probe → pull → hygiene → sample-score → QA
      │
[5 Enrich]    email find + verify (valid/catch-all), phone/WhatsApp number from Maps/site
      │
[6 Outreach]  Email (own domains, real name, warmup, ≤30/mailbox/day, local hours, lead's language)
      │       LinkedIn (optional)  ·  WhatsApp (Cloud API template, after opt-in / positive reply)
      │
[7 Replies]   intent classifier → auto-reply from facts → hot-lead webhook/CRM → booking link
```

**What to copy exactly:**
- The `definition` label + `description_short` per company, generated once and reused across every campaign
- Normalised job-title IDs; `LIMIT N BY company`; `domain_is_alive`; site-builder domain blocklist; dedupe on person, domain and campaign
- The agent loop: probe with histograms → pull → regex hygiene → **sample LLM scoring with reasons** → fix criteria → random-row QA → asserts
- The 4-beat email plus "may I send a few written ideas?" CTA; one brief per lead from their website; the lead's language
- Reply intent taxonomy, OOO deferral, email-changed handoff, auto-reply grounded in facts, booking link

**What to do better (our edge):**
1. **Live signals** (the "latest requirement" you asked about): job posts for developers, new branch openings, new Shopify/Woo stores, "order on WhatsApp" text on their site or Google listing, poor mobile site scores, no app in the stores. Score leads by these, not just by category.
2. **Phone-first data from Maps** for SMB verticals (restaurants, grocery, logistics, fitness), where email coverage is lowest.
3. **Company-HQ geo filter + TLD check** to stop off-country sends.
4. **A second-pass competitor filter** with an LLM over the website text.
5. **Per-vertical micro-campaigns** with budget moving toward whatever replies (the data says CA logistics/restaurants/fitness).
6. **Your real identity and domains**, with proper warmup and compliance footers.

**Open decisions for our next discussion:**
- Data source mix: build Maps + website crawl ourselves, and buy people/email data from which vendor?
- Storage: ClickHouse (fast analytics like Explee) or Postgres/Supabase + pgvector (simpler)?
- Sending: our own domains + Google Workspace/Outlook mailboxes, or a provider (Icemail/Instantly-style)?
- WhatsApp: Meta Cloud API directly, or a BSP (Twilio, 360dialog, Gupshup)? Opt-in flow design.
- Which LLM runs the agent, and which runs the bulk enrichment (cheap model)?

---

## Appendix A: API endpoints observed (read-only GETs)

```
GET /api/app-auto-gtm/user
GET /api/app-auto-gtm/pricing
GET /api/app-auto-gtm/projects/{pid}                     # project + all segments (campaign fields)
GET /api/app-auto-gtm/projects/{pid}/goal | setup-steps | integrations | integrations/webhooks | integrations/deliveries
GET /api/app-auto-gtm/projects/{pid}/linkedin/overview
GET /api/app-auto-gtm/projects/{pid}/inbox/counts?campaign=all
GET /api/app-auto-gtm/projects/{pid}/inbox/contacts?campaign=all&limit=100&offset=0&tab=need_reply|replied|sent
GET /api/app-auto-gtm/projects/{pid}/inbox/contact?person={uuid}
GET /api/app-auto-gtm/projects/{pid}/inbox/lead/{uuid}?why_fits=true
GET /api/app-auto-gtm/projects/{pid}/lead-status-vocab
GET /api/app-auto-gtm/segments/{sid}/leads                # meta + 100 companies + 100 people
GET /api/app-auto-gtm/segments/{sid}/leads/{uuid}/status
GET /api/app-auto-gtm/segments/{sid}/outreach/thread/{uuid}
GET /api/app-auto-gtm/segments/{sid}/retarget-status
GET /api/app-auto-gtm/outreach/materials?project_id={pid}
GET /api/agent-chat/segments/{sid}                        # phase/status
GET /api/agent-chat/segments/{sid}/review
GET /api/agent-chat/sessions/active?segment_id={sid}
GET /api/agent-chat/sessions/{session}/events?since=N     # full agent log, 500/page
POST /api/app-auto-gtm/segments/{sid}/outreach/auto-reply/{uuid}   # (app drafts reply on open)
```

## Appendix B: agent event types
`session.started` (company + segment context) · `plan.set` / `plan.step_update` · `message.user` (automated: "Run the full pipeline…") · `agent.turn_queued/started/ended` · `subagent.started/finished` (`find_companies_people`) · `subagent.tool_call` / `tool_result` (`clickhouse_query`, `execute_python`, `ai_scoring`) · `subagent.thinking` · `hook.started/progress/finished` (`lead_search`, `ai_scoring` phases `ch_enrich → build_items → scoring → samples`, `lead_import` phases `ranking → fetching → scoring → scoring_done`) · `artifact.created` (type `people`, schema `PersonRow`) · `phase.announcement` · `review.updated` · `segment.updated` · `usage`.

## Appendix C: campaign status machine
`discovery` → (pipeline_completed) → `review` → (review_approved_manual / auto after 12h) → `outreach` → `listening` (replies monitored) · pause reasons: `user_pause`, `billing_pause`, `review_search_restarted` (stopped).
