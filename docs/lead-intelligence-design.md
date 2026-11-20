# Lead Intelligence: ontology, sources, agents and reuse plan

**Goal:** an Opscode marketing module that works for **any industry**. It finds high-quality leads, understands what each one needs *right now* (from their posts, jobs, website and history), and writes the first email from that evidence. It is built from plugins, MCP servers and multiple agents. Channel 1 is email; WhatsApp comes later.

**Status:** slices 1, 2, 2b and 3 built 2026-11-17 (`src/runtime/leads/`: ontology and evidence store; `scout/` website scout with Chrome renderer and model reader; `lab/` Lead LAB; `leads.*` RPC; tests `scripts/test-phase48.mjs` to `51`). Later slices not started. **Known limits:** the model step and the model judge were tested against mock models only, never a real one; the gold set (22 cases) is hand-written, not real leads, so it proves the harness and gives a first baseline but is not a quality measure until real hand-labelled leads replace it; rendering needs an installed Chrome/Chromium/Edge; no 50-site measurement yet; `Lead` records are not yet created or scored (slice 5).
**Read with:** [explee-teardown.md](explee-teardown.md), which describes how Explee does it today.

---

## 0. The one idea that matters

Sending email is easy and everyone has it. **Quality comes from four things, and the scraper is the least important of them:**

1. **A shared ontology.** Every scraper, whether for a website, Reddit, a job board or Maps, turns what it saw into the *same* small set of objects: Organization, Person, Need, Signal, Evidence. That is why it works for any industry: the objects stay the same and only the vocabulary changes.
2. **Evidence with time.** Every fact keeps the exact quote, the URL and the date it was seen. "Needs a booking app" is worthless. "*Posted on 2026-11-03: 'we still take bookings over WhatsApp, it's chaos'*" is a lead.
3. **Needs, not categories.** Explee matched on the *type* of company ("restaurant chain"). We match on an **open Need with a recent Signal**. Example: a restaurant chain that just opened its 3rd branch *and* is hiring a "digital ordering manager".
4. **Grading.** Every lead is checked against a pass/fail rubric before an email is written. This is the method Harvey LAB uses (see §2), and it is how we prove the quality is higher.

---

## 1. What harvey-labs is, and what we take from it

`harveyai/harvey-labs` is **not a scraper**. It is **Harvey LAB, the Legal Agent Benchmark** (MIT license, Python): about 2,010 legal tasks plus a harness that runs AI agents on them and **grades the results with LLM judges**.

How it works:
- **Task = a folder:** `task.json` (title, instructions, `work_type`, deliverables, **criteria**) + `documents/`.
- **Agent loop:** a provider adapter (Claude, OpenAI, Gemini, vLLM…). Tools: `bash, read, write, edit, glob, grep, finish`. The `finish` tool must list the deliverables, and the harness bounces the agent back if one is missing. Runs in a no-network sandbox. Everything is logged to `transcript.jsonl` + `metrics.json`.
- **Grading:** each criterion is judged **independently** by an LLM against its `match_criteria` text. Two judges are used by default (one Claude and one GPT) and their scores are averaged. **All-pass scoring:** a task scores 1 only if *every* criterion passes. A missing deliverable fails without even calling a judge.
- **Reports:** per-run HTML plus comparison dashboards across models ("sweeps").

**What we reuse (the pattern, not the legal content):**

| Harvey LAB idea | Our use: a "Lead LAB" |
|---|---|
| `task.json` + documents + criteria | A **campaign test case**: ICP brief + a frozen snapshot of crawled pages + rubric criteria per lead |
| Independent per-criterion LLM judge | Each lead is checked on: *evidence supports the need*, *the need is current*, *the person can buy*, *HQ is in the target geo*, *not a competitor*, *email verified* |
| All-pass scoring | A lead becomes "sendable" only if **all** criteria pass |
| Dual judges | A cheap model judges every lead; a stronger model re-judges a 5% sample to catch drift |
| `finish` with deliverables check | Agents must end by returning a list of lead IDs, each with evidence IDs; the harness rejects missing ones |
| Sweeps and compare dashboards | Compare models, prompts and source mixes by **precision** (judged quality) and later by **reply rate** |
| CHANGELOG of score-moving changes | We record which change moved lead quality |

It is fine to read their `lab_core/evaluation/scoring.py` and `judge.py` as a reference (MIT). Our version lives in TypeScript inside Opscode.

---

## 2. The ontology (industry-agnostic core)

### 2.1 Core objects

```
Organization ──has──▶ Location (branch/HQ)          Organization ──uses──▶ Technology
     │  ▲                                              Organization ──sells──▶ Offering(theirs)
     │  └──employs── Role ◀──holds── Person ──owns──▶ Account (handle on a Platform)
     │                                   │
     ├──has──▶ Need (open/closed, since, urgency)    Person/Org ──authored──▶ Document (post, job ad, page, review)
     │            ▲                                              │
     │            └──evidenced_by── Signal ◀──extracted_from─────┘
     │                                  │
     └──────────── every edge/attribute is an Observation(evidence quote, url, seen_at, confidence, extractor)

Campaign(ICP) ──targets──▶ Need types × Industry × Geo × Role
Lead = Match(Person, Organization, Need, our Offering) + score + reasons + rubric result
Interaction(email sent/reply/intent) ──about──▶ Lead          Suppression / LegalBasis ──on──▶ Person/Org
```

| Object | Key fields | Notes |
|---|---|---|
| **Organization** | id, name, domains[], hq_country, size_band, industry codes (NAICS/NACE), `definition` label, description_short, founded, traffic, is_alive | `definition` + description_short are LLM-made, as in Explee |
| **Location** | org, address, city, country, lat/lng, phone, opened_at | Branch count and new openings are strong signals |
| **Person** | id, name, country | Business identity only (see §6) |
| **Role** | person, org, title_raw, title_norm (O*NET/ESCO code), seniority, function, **buyer_power** (decides / influences / user), start, end | Explee's normalised title IDs, plus a buying-power estimate |
| **Account** | person or org, platform, handle, url, **link_proof** | The proof that this handle belongs to this person or org (§6) |
| **Document** | id, platform, url, author_account, published_at, fetched_at, text hash, language | Raw source, stored once |
| **Observation** | subject, predicate, object, **evidence_quote**, document_id, observed_at, valid_from/valid_to, confidence, extractor | Every fact is one of these. Nothing exists without evidence |
| **Signal** | type (registry below), org/person, document_id, date, strength | A dated event |
| **Need** | org, need_type (from industry pack), description, status (open / in-progress / solved), first_seen, last_seen, urgency, budget_hint, evidence[] | **What they need now.** Past needs move to `solved` but stay as history |
| **Interest (business taste)** | person or org, topic, stance (+/−), frequency, last_seen | From posts and comments: topics they talk about and tools they like or hate |
| **BuyingStage** | org/person, stage: unaware → problem-aware → solution-seeking → evaluating vendors → bought | Derived from signal wording ("any recommendations for…?" = evaluating) |
| **Offering (ours)** | from Project docs: capabilities, proof, pricing rules | Matched against Need types |
| **Lead / Match** | person, org, need, offering, fit, intent, reach, recency, total, **reasons[] → observation ids**, rubric result | The only thing a campaign sends to |
| **Interaction** | channel, sent / reply text, intent class, timestamps | Feeds learning |
| **Suppression / LegalBasis** | who, why, source, expires | Opt-outs, bounces, country rules |

### 2.2 Signal registry (shared by every industry)

| Signal type | Example evidence | Typical source |
|---|---|---|
| `hiring_role` | "Hiring: Shopify developer", "Operations manager – online orders" | Job boards, careers page |
| `expansion` | "Our 3rd location opens in March" | Website news, Maps new listing, social posts |
| `launch` | "Launching our app next month" | Posts, press |
| `pain_expressed` | "Taking orders on WhatsApp is chaos" | Reddit, X, reviews, forum posts |
| `request_for_help` | "Can anyone recommend a POS for a 2-store grocery?" | Reddit, X, Facebook groups, HN "Ask" |
| `rfp_tender` | Public tender for "inventory system" | Government tender sites |
| `tech_change` | Moved from Wix to Shopify; added Stripe | Tech fingerprinting over time |
| `tech_gap` | No mobile app, slow site, no online ordering, broken booking | Site audit, app stores |
| `negative_review_ops` | Reviews saying "app crashes", "order lost" | Google / Yelp / app-store reviews |
| `funding` | Seed round | News, registries |
| `leadership_change` | New CTO / COO | Company page, news |
| `competitor_churn` | "Leaving <vendor>, looking for alternatives" | Reddit, X, review sites |

**Freshness rules:** each signal type has a half-life (e.g. `request_for_help` 14 days, `hiring_role` 45 days, `expansion` 120 days). A Need is "current" only while it has at least one live signal.

### 2.3 Industry packs (how we support every industry)

An **Industry Pack is a plugin** (Opscode already supports plugins and skills). It holds only vocabulary and rules, never code:

```
packs/restaurants/
  pack.json          # definitions, need types, signal phrases, role map, rubric, sources to use
  skills/            # SKILL.md: how to read a menu site, what "multi-location" looks like
  rubric.json        # extra pass/fail criteria for this industry
```

```jsonc
{
  "id": "restaurants",
  "definitions": ["restaurant chain", "cloud kitchen", "cafe group", "food truck fleet"],
  "naics": ["7225"],
  "need_types": [
    {"id": "online_ordering", "phrases": ["order on whatsapp", "call to order", "no online ordering"],
     "signals": ["pain_expressed", "tech_gap", "hiring_role"]},
    {"id": "loyalty_app", "phrases": ["punch card", "rewards program"], "signals": ["launch", "tech_gap"]}
  ],
  "buyer_roles": ["owner", "founder", "operations director", "general manager (multi-site)"],
  "exclude": ["single food stall with no website"],
  "sources": ["website", "maps", "reviews", "jobs", "reddit:r/restaurateur", "reddit:r/KitchenConfidential"]
}
```

The **seller side** (what *our user* sells) is also data: their Offering is mapped to the `need_types` it solves. So the same engine serves a dev agency, a dental supply seller or an HVAC software company. Only the pack and the Offering change.

Ready-made vocabularies to start from: NAICS / NACE / ISIC (industries), **O\*NET / ESCO** (job titles to occupations and seniority), schema.org (`Organization`, `Person`, `JobPosting`, `Review`, `Offer`, and GoodRelations `Demand` for needs), and the W3C ORG ontology (roles and memberships).

---

## 3. Sources: what each platform gives and how to get it legally

Legend: ✅ fine to use · ⚠️ needs a licence or official API · ⛔ don't scrape (use a licensed data vendor or the user's manual review).

| Source | Signals it gives | How to access | Status |
|---|---|---|---|
| **Company websites** (home, about, careers, news, contact) | definition, offering, branches, tech, hiring, launches, emails | Crawl4AI / Crawlee / Firecrawl + trafilatura | ✅ respect robots.txt and rate limits |
| **Search engine results** | discovery ("restaurant group" + city), news | SearXNG self-hosted, or a search API (Brave, Serper, Firecrawl search) | ✅ / ⚠️ by API terms |
| **Maps / local listings** | locations, phone, website, rating, new openings | **OpenStreetMap Overpass** (open data); Google Places API (paid, official); `gosom/google-maps-scraper` exists but scraping Google Maps breaks Google's ToS | ✅ OSM · ⚠️ Places API · ⛔ scraping |
| **Reviews** (Google, Yelp, Trustpilot, app stores) | `negative_review_ops`, pains in customers' words | Official APIs where they exist; app-store reviews via public RSS / APIs | ⚠️ |
| **Job boards + careers pages** | `hiring_role` (the strongest buying signal) | Careers pages (✅); JobSpy for Indeed/Glassdoor/LinkedIn jobs, but check each board's ToS | ✅ / ⚠️ |
| **Reddit** | `request_for_help`, `pain_expressed`, `competitor_churn`, business "taste" | Official Data API via PRAW. **Commercial use needs a written agreement with Reddit** | ⚠️ get the licence before shipping |
| **X / Twitter** | same as Reddit, plus launches | Official X API (paid tiers) | ⚠️ |
| **LinkedIn** | roles, titles, company posts | **Do not scrape.** LinkedIn sued Proxycurl in 2025 and Proxycurl shut down. Use licensed B2B data vendors (people/company APIs) and LinkedIn's own official products; let the user open profiles themselves in the in-app browser | ⛔ scraping · ⚠️ vendors |
| **Hacker News, Product Hunt, GitHub** | launches, tech, "Ask HN: recommend…" | Algolia HN API, PH API, GitHub API | ✅ |
| **Business registries** (Companies House, OpenCorporates, SEC EDGAR, GLEIF) | legal entity, officers, founded, filings | Official APIs | ✅ |
| **Government tenders** (SAM.gov, TED, state portals) | `rfp_tender` (explicit need + budget) | Official feeds | ✅ |
| **News** | funding, expansion, leadership change | GDELT, RSS, news APIs | ✅ |
| **Tech fingerprinting** | `tech_stack`, `tech_change`, `tech_gap` | Wappalyzer-style rules (webappanalyzer, GPL-3.0, run as a separate process), page-speed audits | ✅ |
| **Email finding / verification** | reachable address | Pattern guess + SMTP check with Reacher `check-if-email-exists` (MIT), or a paid verifier | ✅ with care (B2B addresses only) |
| **Data vendors** (people/company/email) | fills LinkedIn-type gaps | Apollo, PDL, Prospeo-type APIs (Firecrawl's catalog already lists several) | ⚠️ paid, licensed |

---

## 4. Multi-agent pipeline (email first)

Every box is an Opscode sub-agent or worker. Every arrow carries **ontology objects** (JSON with evidence IDs), never free text.

```
 ① Strategist      Project docs + Offering + Industry Pack → Campaign ICP + Query Plan
        │           (need types to hunt, signals to look for, sources, geo, roles)
        ▼
 ② Scouts (parallel, one per source, each an MCP server)
        website-scout · search-scout · maps-scout(OSM) · jobs-scout · reddit-scout(licensed)
        news-scout · tenders-scout · registry-scout · vendor-scout
        → raw Documents (stored once, hashed)
        ▼
 ③ Extractor       Document → Observations + Signals (LLM structured output; GLiNER for
        │           cheap entity tagging first; every field must quote its evidence)
        ▼
 ④ Resolver        merge duplicates: same domain / phone / registry id / proven account link
        │           (Splink-style probabilistic matching) → one Organization, one Person
        ▼
 ⑤ Need Analyst    Signals → Needs (open/solved, urgency, buying stage), Interest profile,
        │           freshness decay; past needs kept as history
        ▼
 ⑥ Scorer          fit × intent × reach × recency → Lead + reasons (observation ids)
        ▼
 ⑦ Judge (Lead LAB) all-pass rubric per lead; cheap judge on all, strong judge on 5% sample
        ▼
 ⑧ Review gate     the person approves the list (or auto-approve after N hours, like Explee)
        ▼
 ⑨ Writer          one email per lead; every claim must cite an Observation; real sender name;
        │           unsubscribe line; lead's language
        ▼
 ⑩ Sender + Inbox  own mailboxes and warmup, local-time schedule, reply intent classifier,
                    auto-reply from Reply facts, hot-lead webhook. Replies feed back into ⑥ weights.
```

### Scoring (explainable, no black box)

```
fit     = industry/definition match × size band × HQ geo match × not-competitor      (0–1)
intent  = 1 - Π(1 - signal_strength × 0.5^(age / half_life))  over live signals  (0–1)
                      (built in slice 1: several signals add up but never pass 1)
reach   = verified business email 1.0 · catch-all 0.5 · none 0
recency = days since newest live signal → 1.0 (≤7 d) … 0.2 (≤120 d) … 0
power   = buyer_power(decides 1.0, influences 0.6, user 0.2)

lead_score = fit^1 × intent^1.5 × power × reach × recency
```

Every number links to the Observations that produced it, so the UI can show "why this lead" with quotes and links.

### Example of what the Writer gets (and why emails get better)

```json
{
  "person": "Karan T., Owner", "org": "Calories (Saskatoon, 2 locations)",
  "need": {"type": "online_ordering", "status": "open", "stage": "problem-aware"},
  "evidence": [
    {"quote": "Call us to order family meals for pickup", "url": "caloriesrestaurant.ca/menu", "seen": "2026-11-02"},
    {"quote": "Hiring: front-of-house lead to manage phone orders", "url": "…/careers", "seen": "2026-10-28"}
  ],
  "our_offer": "custom ordering app + admin dashboard",
  "proof": "portfolio link only, no client names (Reply facts rule)"
}
```

---

## 5. Storage (decision changed 2026-11-17: local first, Postgres only if the user wants it)

- **Default: local.** A new user installs Opscode and everything is saved on their computer, with no server and no account. Today that is the JSONL store built in slice 1. The CRM (below) needs fast filtering and search, so the CRM tables go into a **local SQLite file** in Opscode's data folder. Electron 33 ships Node 20.18, which has no built-in SQLite, so this needs a dependency: `better-sqlite3` (native, needs an Electron build step like `node-pty` already has) or `sql.js` (WebAssembly, no native build, slower). To be decided by a small test before building.
- **Optional: Postgres.** If the user wants a shared or cloud database (a team, or an always-on runner, see 8e), they paste a connection string (Supabase is just Postgres). Same tables, same code, behind one `Store` interface with two adapters: `local` and `postgres`. `schema.sql` is the Postgres form; a portable form is needed for SQLite.
- **Raw pages:** a local folder keyed by content hash.
- **Analytics later:** ClickHouse only at millions of rows.
- Graph extras (Graphiti, AGE) stay optional and are not needed for v1.

## 6. Guardrails for "know the owner across platforms"

You asked to link one owner across Reddit, LinkedIn and other platforms and understand their "taste". We can do this **for their business persona**, with these rules. They are also what keeps lead quality high and accounts unbanned:

1. **Link accounts only with proof**, never by guessing. Proof means the company website links to the profile, the profile links back to the domain, or it's the same verified handle on the company page (`Account.link_proof`). Name-matching across sites produces wrong people and privacy complaints.
2. **Business topics only.** Store interests about their business, tools, operations and buying questions. Never store health, religion, politics, family, sexuality or other sensitive categories, even if they appear in a post.
3. **Respect each platform's terms:** licensed Reddit/X API, no LinkedIn scraping, no Google Maps scraping, robots.txt everywhere.
4. **GDPR / CASL / CAN-SPAM:** keep a legitimate-interest note per campaign, a source and date for every personal field, a retention limit (e.g. 12 months without interaction), and a one-click delete for a person across every table (suppression wins over everything).
5. **No fake personas.** Send as the real user. That was Explee's weak point.

---

## 7. Open-source to reuse (checked 2026-11-17)

| Need | Project | License | How we use it |
|---|---|---|---|
| Crawl + clean markdown | **Crawl4AI** (unclecode/crawl4ai, 87k★) | Apache-2.0 | Main self-hosted crawler (Python service behind an MCP server) |
| Crawl from TypeScript | **Crawlee** (apify/crawlee) | Apache-2.0 | Fits Opscode's Node runtime directly (Playwright/Cheerio crawlers, queues, proxy rotation) |
| Crawl + search + extract API | **Firecrawl** (202k★) | **AGPL-3.0** | Use the hosted API or MCP; self-host only as a separate, unmodified service (AGPL: modified code offered as a service must be published) |
| Agentic browser | **browser-use** | MIT | Hard sites with forms and logins (user-owned sessions only) |
| Browser via MCP | **Playwright MCP** (Microsoft) | Apache-2.0 | Already in Opscode's MCP catalog |
| LLM extraction graphs | ScrapeGraphAI | MIT | Reference for prompt → schema extraction |
| Article / text extraction | trafilatura | Apache-2.0 | Clean main text from news and blog pages |
| Docs to text | MarkItDown | MIT | PDFs and Office files (tenders, brochures) |
| Meta-search | SearXNG | AGPL-3.0 | Self-hosted discovery search (separate service) |
| Local businesses | OpenStreetMap Overpass API | ODbL data | Legal maps data with phones and websites |
| Jobs | JobSpy | MIT | Hiring signals (check each board's ToS) |
| Reddit | PRAW | BSD-2 | Only with a Reddit commercial agreement |
| Cheap entity tagging | **GLiNER** | Apache-2.0 | Pull out roles, tools and needs before calling a big LLM (cuts cost) |
| Entity resolution | **Splink** (MIT) / dedupe (MIT) | MIT | Merge duplicate companies and people |
| Temporal graph memory | **Graphiti** (Zep) | Apache-2.0 | Needs and interests that change over time |
| Agent memory graph | Cognee | Apache-2.0 | Alternative to Graphiti |
| Email verify | Reacher check-if-email-exists | MIT | SMTP verification (run from a clean IP) |
| Tech detection | webappanalyzer (Wappalyzer rules) | GPL-3.0 | Separate process; read its output only |
| OSINT (reference only) | SpiderFoot | MIT | Ideas for module design. **Not** for profiling people |
| Grading harness | **harvey-labs** | MIT | Pattern for Lead LAB rubrics and judges |

---

## 8. What Opscode already has, and how each part is reused

| Existing module | Where | Reuse for lead intelligence |
|---|---|---|
| Agent loop + providers (Anthropic + OpenAI-compatible) | `src/runtime/agent/{agent,llm,providers,tools}.ts` | Run Strategist, Extractor, Need Analyst, Writer; cheap vs strong models per step |
| Sub-agents (`run_agent`, access levels) | `src/runtime/agentfiles.ts`, `AgentEngine.subagentTool` | One sub-agent file per role (scout, extractor, judge, writer). **Gap:** helpers run one at a time; Scouts need parallel runs |
| Chief + pipeline stages + gates | `src/runtime/chief/{pipeline,manager,route,modes}.ts` | Add a **"campaign" pipeline**: research → icp → discover → extract → resolve → score → judge → *gate* → write → send. Same "each stage writes one file" rule |
| Automations (YAML, schedule, budget, checks, approve gates) | `src/runtime/automations/*` | **Daily re-scan** for fresh signals; weekly campaign refresh; checks = rubric judge; budget caps on tokens and credits |
| MCP client + catalog | `src/runtime/mcp.ts`, `mcpCatalog.ts` | Add Firecrawl, Crawl4AI, Playwright (already there), Supabase (already there), and our own `scout-*` MCP servers |
| Plugins + skills | `src/runtime/plugins.ts`, `skills.ts` | **Industry Packs** = plugins (pack.json + skills + rubric) |
| Memory notes | `src/runtime/memory.ts` | Campaign learnings ("Canada logistics replies best") |
| Library (deterministic index + search, no model tokens) | `src/runtime/library/*` | Reuse its **scoring/search pattern** (weighted fields, `why[]` evidence) for lead search and dedupe without spending tokens |
| In-app browser (webview) | renderer panel | Human-in-the-loop: the user opens a LinkedIn profile *themselves* to confirm a lead (no scraping) |
| Usage + pricing tracking | `src/runtime/usage/*` | Cost per lead and per campaign (LLM + data vendor + email) |
| Supabase MCP | catalog | Database for the ontology tables |

**To build new:** ontology tables + TypeScript types, the `scout-*` MCP servers, Extractor/Resolver/Need Analyst/Scorer, Lead LAB judge, Marketing UI (campaign builder like Explee's fields, lead review with evidence, inbox), and the email sender with warmup and suppression.

---

## 8b. User experience: from one sentence to a running campaign

**Principle:** the user types one sentence (or pastes a website) and only *approves* after that. Opscode doesn't show a form full of fields like Explee's (offer, pain, positive/negative criteria, keywords, roles). It fills those fields in itself; the user can still open and edit them.

| Step | What the user sees | What runs behind it | User effort |
|---|---|---|---|
| **1. Tell us** | One input box: *"What do you sell, and who should buy it?"* + website chip + optional file. Quick-start chips (Restaurants, Logistics, Dental clinics, Import CSV) | Nothing yet | 1 sentence |
| **2. Research** (~1 min, can leave) | Live checklist: read your site → picked industry pack → competitors excluded → sizing audiences | Strategist agent: Research Company, Offering, Industry Pack match, competitor list, 50-company sample per audience | None |
| **3. Pick audiences** | 2–4 audience cards. Each shows size, geo, roles and **one real evidence quote**, with a keep/drop checkbox. Editable chips for country, size and roles | Need types × signals × geo become audience definitions | Ticks |
| **4. Review leads** | 10 sample leads: score, "why" quotes, draft first line, 👍/👎 | Scouts → Extractor → Scorer → Lead LAB judge on a sample; thumbs adjust scorer weights | 10 clicks |
| **5. Launch** | Send-from mailbox, emails/day, booking link, compliance line → **Launch campaign** | Full discovery runs in the background, then send, inbox, auto-replies | 1 click |

**After launch:** a daily card in Opscode's home ("Today: 3 hot replies, 120 new leads found, 2 need your answer"), the same "decisions for today" idea Explee uses. The user can steer at any time by typing in the campaign chat ("skip franchises", "add Australia"). The agent turns that into ontology filter changes and re-scores.

**Where it lives in Opscode:** a **Marketing** page in the sidebar (next to Chiefs and Automations). Step 1 reuses the new-chat composer. Steps 2–4 are cards inside the campaign chat (like approval cards). The lead list and evidence open in the right-side panel. Launch creates an automation that does the daily re-scan.

## 8c. The research step does everything from one prompt

From the user's one sentence (plus their website), the Strategist runs these in order and produces **one editable Campaign Brief**:

| # | Research task | Output |
|---|---|---|
| 1 | Read the user's website, docs and brochure | Offering: what they sell, proof, price rules, tone (also fills Reply facts) |
| 2 | Pick or create the Industry Pack | Need types, signals and buyer roles for this industry |
| 3 | **Competitor research**: web search ("alternatives to X", "X vs"), lookalike sites, review sites | 5–15 competitors with offer, pricing and positioning. They become the exclusion list |
| 4 | **Competitor customers**: logos, case studies and testimonials on competitor sites | Real example customers, used to find **lookalike audiences** (best source of audience ideas) |
| 5 | Audience design: need type × industry × geo × size × role | 2–4 audiences, each sized with a 50-company sample and one evidence quote |
| 6 | Campaign design | Every Explee field filled in automatically: name, offer, customer problem, geo, size, positive/negative criteria, keywords, target roles, example clients, booking link, daily limit, follow-up rules |
| 7 | Message plan | Angle per audience, first-email draft, follow-up idea, reply facts |

The brief is shown as cards (step 3 of the onboarding flow). Any field can be edited, or changed by chat ("drop UAE, add the UK").

## 8d. Lead sources: built-in, MCP servers and plugins

### The connector contract

Every source, whether built-in, MCP or plugin, is registered as a **Lead Source** that declares which **jobs** it can do:

| Job | Meaning |
|---|---|
| `companies.search` | Find companies by industry, geo, size or keywords |
| `companies.enrich` | Details for a known domain |
| `people.search` | Find decision-makers at a company |
| `people.enrich` | Details for a known person |
| `email.find` / `email.verify` | Get and check a work email |
| `signals.fetch` | Hiring, expansion, pain posts, tech changes, news |
| `web.search` / `web.fetch` | General search and page reading |
| `exclude.list` | Existing customers or CRM contacts never to email |

A **router** picks sources per job, in this order: the user's choice, then free sources, then the cheapest paid source, then the paid source with the best past accuracy. **Paid calls show a credit estimate and need approval** ("Apollo: ~400 credits for 200 people, OK?"). Every result is normalised into ontology Observations with `source = "mcp:apollo"` etc., so evidence and cost are tracked per lead.

### Built-in sources (ship with Opscode, no key needed)

| Source | Jobs | Notes |
|---|---|---|
| Company website crawler (Crawlee, in Node) | companies.enrich, signals.fetch, email.find | Reads home/about/careers/news/contact pages; robots.txt respected |
| OpenStreetMap (Overpass + Nominatim) | companies.search | Local businesses by category and area, with phone and website; open data |
| Careers pages + `JobPosting` structured data | signals.fetch | Hiring signals straight from company sites |
| Business registries (Companies House UK, SEC EDGAR, others with free APIs) | companies.search, companies.enrich | Legal entity, officers, founding date |
| News (GDELT, RSS) | signals.fetch | Funding, expansion, leadership change |
| Public tenders (SAM.gov, EU TED) | signals.fetch | Explicit needs with budgets |
| Hacker News (Algolia), GitHub, Product Hunt | signals.fetch | Launches, tech, "can anyone recommend…" posts |
| Tech fingerprint | signals.fetch | Site builder, shop platform, payments, booking tools, page speed |
| Email pattern + check | email.find, email.verify | Pattern guess from the site plus format/MX checks. Full SMTP checks need a server with port 25 open, so they run through a connected verifier when available |
| Web search | web.search | Needs any one key: Brave Search, Serper, or Firecrawl. A self-hosted SearXNG also works |

### Ready-made MCP connectors (user adds a key)

| Vendor | MCP endpoint | Jobs |
|---|---|---|
| Apollo | `https://mcp.apollo.io/mcp` (OAuth or `X-Api-Key`) | people.search/enrich, companies.search/enrich, email.find, job postings, news |
| Hunter | `https://mcp.hunter.io/mcp` (API key) | email.find, email.verify, people.enrich |
| Clay | `https://api.clay.com/v3/mcp` | enrichment waterfalls |
| Firecrawl | `https://mcp.firecrawl.dev/v2/mcp` (works keyless, rate-limited; `Authorization: Bearer` key for more; 1,000 free credits a month) | web.search, web.fetch, plus its catalogue of data providers. **In Opscode's catalog, tested keyless on 2026-11-17** |
| TinyFish | `https://agent.tinyfish.ai/mcp` (API key as Bearer; or browser sign-in, which Opscode cannot do yet) | web.search (TinySearch) and web.fetch (TinyFetch) are free; Agent and Browser are metered. **In the catalog; refuses without a key (401); not yet tested with a real key** |
| Zoho Campaigns / Zoho Mail | the person's own Zoho MCP server URL (zoho.com/mcp) | email marketing (campaigns, contacts, segments, reports) and mail. In the catalog, **not tested**: Zoho also wants a sign-in approval Opscode cannot show yet |
| Hostinger Mail | URL from hPanel → Emails → Agentic mail → MCP Server | mailbox read/send only. Hostinger's email marketing (Reach) has **no MCP server** yet. In the catalog, **not tested** |
| Playwright | already in Opscode's catalog | web.fetch for hard pages |

### Any custom MCP server or plugin

- **Custom MCP:** the user pastes a URL or command (Opscode's MCP manager already supports stdio, HTTP and secret headers). Opscode lists the server's tools, and an LLM reads each tool's description and **proposes a job mapping** (`search_customers → exclude.list`). The user confirms or fixes it once. Unmapped tools are ignored.
- **Plugin:** a plugin can ship lead sources by declaring them in its manifest, so no mapping step is needed:

```jsonc
// .claude-plugin/plugin.json (extra field read by Opscode)
"leadSources": [
  { "server": "apollo", "tool": "people_search", "job": "people.search", "cost": "paid" },
  { "server": "apollo", "tool": "people_match",  "job": "email.find",    "cost": "paid" }
]
```

- **Industry packs** are plugins too (§2.3), and can recommend which sources to turn on.

## 8e. Mail engine, mini CRM, and what happens when the laptop is off

**Mail engine (slice 7a/7b):** a pool of mailboxes over plain SMTP and IMAP (any provider). Per-mailbox daily caps and warm-up, separate sending domains, one mailbox per lead thread, auto-pause on bounces, unsubscribe list. Replies are read over IMAP and matched by Message-ID / In-Reply-To, then classified (interested, not interested, question, out of office, bounce, unsubscribe). No open-tracking pixels.

**Mini CRM (built in, default):** tables `contacts`, `companies`, `deals` (one per lead and offering, with a stage), `activities` (email sent, reply with its intent, note, call), `tasks` (next follow-up with a due date), custom fields, tags, saved views. Screens: Leads (every lead collected and its status, filters, search), Pipeline (New, Contacted, Replied, Interested, Meeting, Won, Lost, Not interested), and a lead page with the full timeline: which message was sent, which reply came and its class, the need and its evidence, last follow-up and next follow-up. The person can rename stages, add fields and edit any record, and export or import CSV. "Their own CRM": Opscode stays the place where outreach runs and **pushes** contacts, deals and activities to HubSpot, Zoho CRM, Pipedrive or a webhook (one way, keyed by lead id so nothing is duplicated, option to push only interested leads). Local data is always kept.

**Laptop off:** replies are never lost, because they wait in the mailbox on the provider. Opscode keeps a bookmark (last IMAP UID) per mailbox and catches up when it opens. Rules: (1) **sync before send**, so nobody who replied while the app was closed gets a follow-up; (2) after waking up, **no burst**: missed sends go back into the normal daily caps and pacing; (3) a "While you were away" summary on reopen; (4) the person can read and answer from the phone mail app, and Opscode reads the Sent folder too. Optional **always-on runner**: the same runtime (it is already a separate process with a token-protected API) on a small always-on machine (a VPS, a Raspberry Pi or an old Mac mini), with SQLite there or Postgres; the desktop app connects to it. That is the one case where Postgres is a good default.

## 9. Suggested build order (one slice at a time; you approve each)

1. **Ontology + storage:** SQL schema, TS types, Observation/evidence model, one Industry Pack (restaurants) and one Offering (your dev services).
2. **Website scout + Extractor:** crawl a list of domains → Organization, Locations, Tech, Signals with evidence quotes. Measured on 50 real sites.
3. **Lead LAB v0:** a rubric judge plus a gold set of 100 hand-checked leads. From here on, every change is graded.
4. **Discovery scouts:** OSM, search and jobs (all free and legal) → candidate companies. Then the Resolver.
5. **Need Analyst + Scorer:** open Needs, freshness, "why this lead" UI.
6. **People + email:** licensed vendor for decision-makers, email pattern + verification.
7. **Mail engine and mini CRM:** 7a mailbox pool + SMTP sender (caps, warm-up, auto-pause, unsubscribe) + the email writer and review gate; 7b IMAP reply sync, matching, bounce handling, Inbox, and the mini CRM screens (section 8e). Optional 7c: always-on runner and push to the user's own CRM.
8. **Campaign pipeline in Chief + daily automation re-scan.**
9. **Reddit/X (licensed)**, reviews and tenders as extra signal sources.
10. **WhatsApp** (Cloud API, opt-in) after email works.

**Decisions needed from you:** database (Supabase Postgres vs local Postgres), which data vendor for people/emails, the first industry pack to prove quality (I suggest restaurants or logistics in Canada, because your Explee data says they reply), and whether scouts run as Python services (Crawl4AI) or inside Node (Crawlee).
