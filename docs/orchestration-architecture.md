# Orchestration architecture: modes, agents, engines, end to end

How Opscode takes anything from "the sale button is broken" to "build this grocery app end to end", picks the right amount of power, the right agents and the right engine for every piece, survives full sessions, and spends the fewest tokens that still give a correct result.

Everything marked **built** exists and is tested today. Everything marked **M1..M5** is the build order at the end.

## 0. The one idea

Four dials, each owned by a different layer, never mixed:

| Dial | Who sets it | Values |
|---|---|---|
| **Job size** (how much process) | Conductor, from your words | fix · small change · feature · project |
| **Mode** (how much power) | You; templates per stage; Opscode only suggests | Normal · SHINOBI · WARLORD · GODMODE |
| **Role** (who does this one task) | Conductor, from the task | the agent catalog below |
| **Model and engine** (what it runs on) | The runtime, from the mode table and live limits | exact ids, never "latest" |

Big task → big process, strong models, deep checking. Mini task → one worker, cheap model, one check. The mode scales checking and parallelism; the job size decides which stages exist at all, so a fix never plans in any mode (**built**).

## 1. The layers

```
You
 └─ Conductor chat (one per project, mode set)          small: never reads code
     ├─ Board: items = tasks, queue, approvals          survives restarts (built)
     ├─ Library: features/files/graph, 0 tokens         (built)
     └─ Workers: fresh chat per task, one job each
         ├─ brief + skill + rules + map + report format (built)
         ├─ hand-off past 150k/120k tokens              (built: only when the Conductor messages an idle worker)
         ├─ finish check: no Check line → sent back once (built: fix/feature jobs only)
         └─ escalation: 2 failures → one tier up        (prompt rule only; no failure counter yet → M4)
Runtime (not a model): enforces models per tier, Opus/day, parallel slots,
daily chats, limits-aware engine choice (M1), budgets (M4)
```

Memory lives in three places, never in long chats: the board (state), files in the repo (`spec.md`, `gap.md`, `plan.md`, reports), and the Library (code knowledge). A worker dies when its task ends; nothing is lost because everything it learned worth keeping is in its report and files. That is what lets "any session full → new session continues" work: the hand-off worker starts from the last report plus the files (**built**).

## 2. The agent catalog

Every agent is a worker chat with: one role, one engine, one tier, one skill, an access level, and the same report contract (Status / Found / Branch / Check / Left / Question). The Conductor composes them; the runtime prices them.

| Agent | Engine | Tier (GODMODE / WARLORD / SHINOBI) | Access | Skill | Job |
|---|---|---|---|---|---|
| **Scout** | none — Library | free | read | — | "do we have this? which files?" Zero tokens (built) |
| **Chore runner** | Claude Haiku | fast / fast / fast | read | chore | look-ups, one-off runs, log digests |
| **Planner** | Claude | opus / frontier (opus if complex) / frontier | read | plan (M2) | spec → milestones, tasks, contracts between repos |
| **Builder, logic** | Claude | frontier / frontier / base | edit | fix or feature (built) | backend, data models, payments, auctions, debugging |
| **Builder, UI** | Codex | high / medium / low think | edit | ui-build (M3) | Flutter screens, dashboard pages, assets, mechanical sweeps |
| **Designer** | Codex + image gen | by mode | edit | ui-brief (M3) | screens from the template's design system, icons |
| **Tester** | scripts + Claude Haiku | fast | read | test-digest (M4) | runs suites/crawler; a model sees only failing lines |
| **Reviewer** | Claude | opus / frontier / base | read | review (built) | independent, judges only the brief, cannot edit |
| **Fixer** | Claude | one tier above the failed builder | edit | fix (built) | takes a red check + diagnosis, nothing else |

Role rules the Conductor already follows (**built**): review only when behaviour changed; one review round; parts that touch the same files are stacked, never parallel; cross-repo work is a change set (one chat per repo, shared contract, merge order).

## 3. Claude and Codex: who is good at what, and the failover

Division of labour (what each is better and cheaper at):

- **Claude Code**: multi-file logic, debugging to root cause, data models, security-sensitive code (payments, auth), planning, review. Gets the hard thinking.
- **Codex**: UI screens and styling, image/asset generation, long mechanical edits (rename across 40 files, wire 12 endpoints the same way), small self-contained jobs. Your Codex plan has far more headroom, so every token moved there is a Claude token saved.

**Limits-aware engine choice (M1)** — the runtime already reads both plans live (`limits.get`, `rate_limit_event`, **built**); M1 makes launch() consult it:

| Claude usage (5h or weekly) | What the runtime does |
|---|---|
| < 70% | mode table as is |
| 70–90% soft | fast/chore tasks silently run on Codex or Haiku-equivalents; Conductor's prompt gains one line: "Claude is at N%, resets HH:MM — prefer Codex for anything mechanical" |
| > 90% hard | new Claude chats answer `blocked` with the reset time; eligible work (UI, mechanical, chores) is offered to Codex; logic/review work **parks in the queue** and starts by itself after the reset — never silently downgraded to a weaker brain on payments-grade code |
| Codex high too | everything parks; you get one line with both reset times |

Parking beats swapping: a wrong "fix" from the wrong engine costs more than waiting 2 hours. You can always override per task.

**M1 design rules (from the adversarial design review):**

1. **One pure function decides:** `route(mode, spec, limits) → {engine, action: launch|park, until?, promptLine?}`, called in `startChats` before the daily/slot checks; `launch()` stays dumb. Every rule below is then a unit test.
2. **No data = normal, plus a refresh.** The store is empty at start and a probe can fail; only a fresh `ok` reading (≤5 min old) may trigger soft or hard behaviour. Missing, stale or error state behaves as <70% and forces a refresh — an API-key user is never parked by absence of data.
3. **Which number wins:** max of five-hour and weekly only. Model-scoped windows (weekly Opus) gate only picks of that model, and downgrade to the frontier tier rather than park. The monthly extra-usage number never counts.
4. **Hysteresis, decided per batch:** enter soft at 70, leave at 65; enter hard at 90, leave at 85; one decision stamped per `startChats` call, so a mid-burst flap cannot route two specs of one batch differently.
5. **Park is a field, not a throw:** `item.parked = {reason: "limits", until}` set before any chat is created — it never counts against `daily_chats`, never marks the item failed, is persisted in the board file, and `fillSlots` skips it while `until` is in the future (so a restart with an empty store stays parked).
6. **Un-park by the existing 20s ticker, no timers:** when `until` passes (or is missing and the last check is old), force one free `refresh()` and launch only below the exit threshold.
7. **A rerouted task knows it moved:** the brief gains one line (follow the same Status/Check report), the chat records `rerouted_from`, and escalation goes back to Claude after reset, never to "stronger Codex".
8. **What may reroute:** only `role build` with `tier fast` or `kind chore`. Reviews never reroute. A per-task `engine_override` from your words wins in every band; a claude-code override under hard block parks instead of launching.

## 4. End to end: "build me this app"

Job size = **project** → the 9-stage pipeline (docs/agency-template.md) becomes a real automation (M2), each stage a board item with its own agents, mode, and budget:

| Stage | Agents | Default mode | Gate before next stage |
|---|---|---|---|
| 1 Read requirement → `spec.md` | Chore runner + Planner | WARLORD | your answers to open questions |
| 2 Match templates | Scout (free) | — | — |
| 3 Gap report → `gap.md` | Planner (reads spec + Library only) | SHINOBI | — |
| 4 Plan → `plan.md` | Planner (Opus) | GODMODE | **you approve the plan** |
| 5 UI | Designer + Builder-UI + Reviewer(screens) | WARLORD | **you approve the gallery** |
| 6 Build, feature by feature | Builder-logic / Builder-UI per feature, stacked or parallel by files | SHINOBI; payments/auction features WARLORD | checks green per feature |
| 7 Test | Tester + Fixer loop | WARLORD | suite green |
| 8 Review | Reviewer | GODMODE | findings fixed or rejected with reasons |
| 9 Deliver | scripts | — | **you approve each APK** |

Per-stage mode is data in the template (`stages: {plan: godmode, build: shinobi, …}`), you can change any stage with one click, and Opscode may *suggest* a stronger mode from facts ("3 features touch payments") — never switch silently.

**Auto-continue (M2):** a stage's item completes → the automation queues the next stage's items by itself, inside the mode's daily limits; approvals gate where marked. Full session? hand-off (built). App restarted? the board and queue are on disk (built), the automation resumes from the last incomplete item.

**Escalation ladder (built as prompt rule, M4 adds runtime enforcement):** red check → same builder retries with failing lines only → still red → Fixer one tier up with the digest → still red → mode-ceiling reviewer look + you get one line. Accuracy scales with task importance because only hard, failing, or behaviour-changing work climbs the ladder.

## 5. Cost model (why this is cheap)

Per task, tokens ≈ brief (≤600 words) + skill (~300) + rules+map (~700) + the files the Scout named + the work itself. No worker ever carries another task's history (fresh chat per task, built), no model ever reads a full test log (digest, M4), no exploration (Library, built), reviews only where behaviour changed (built), Opus capped per day (built), start flags trimmed (built, measured 45–58k → lean levels). Measured on your logs, the pattern this replaces burned 70% of cost in multi-day chats and 60% in cache re-reads; simulation of this architecture saved ~58%. The benchmark (M5) turns that into a real number on 10 dealker tasks.

## 6. What to build, in order

| # | Slice | Contents | Proof |
|---|---|---|---|
| **M1** | Limits-aware engine choice | thresholds in launch()/fillSlots, park-until-reset, Conductor prompt line, per-task override | fake engines report fake limits; tests: soft routes chores to Codex, hard parks logic work, reset un-parks |
| **M2** | Pipeline automation | agency stages as a built-in automation; per-stage mode; auto-continue; plan/gallery/APK approval gates | fake run: 9 stages advance, gates stop, restart resumes |
| **M3** | UI loop | ui-brief + ui-build skills, Codex screens, screenshot → Claude review, rounds by mode (3/2/1) | fake codex produces files; review round count per mode |
| **M4** | Test loop | runners (backend, dashboard+crawler), Haiku digest worker, Fixer wiring, budget per stage with stop-at-80% | seeded failing repo: digest → fix → green; budget stops |
| **M5** | Benchmark + Observer | 10 real dealker tasks, plain chat vs SHINOBI vs WARLORD; Usage page per-project cost; weekly report | the numbers |

Mobile testing/APK (Android SDK) stays after M4, as already planned.

## 6b. Status and review findings

**M1 built 2026-11-15** (`src/runtime/chief/route.ts`, wired in `manager.ts`): all eight design rules above, plus `fillSlots` no longer deletes queued work when a start fails (it retries 3 times, 2 minutes apart, and keeps the pending chats). 37 checks in `test-phase23` (16 pure router, 21 live on fake engines with controlled plan usage, including restart and auto-start after reset). All 21 suites pass (848 checks).

**M2 built 2026-11-15** (`src/runtime/chief/pipeline.ts`, manager, tools, board UI): the pipeline (§4) with the runtime owning stage order, per-stage mode (a stage's item carries its mode, so GODMODE's Opus plans inside a WARLORD Conductor) and gates; the Conductor writes briefs and calls `stage_done` (refused while the stage's chats run or have not started); only the person approves or sends back a gate (RPC + card on the Work panel; the Conductor has no tool and waiting never approves); stage files in `docs/opscode/<project>/`; the person can change any unfinished stage's mode or stop the pipeline. 31 checks in `test-phase24`, plus a smoke step that clicks Approve on the card. 22 suites, 879 checks green.

**M3 built 2026-11-15: UI plus brand assets, and engines by strength.**

- **Research:** your dealker runs show Codex's built-in image tool driven by detailed art-direction prompts (style header with exact hex, "no text", safe areas, 3x3 icon sheets, banner job lists, reference images attached with `-i`); your Codex (0.169) offers GPT-6-Astra (frontier), GPT-6.1-Sol (workhorse), GPT-6.1-Terra, GPT-6-Luna (fast), GPT-Reserve. Its app-server accepts `localImage` input and reports `imageGeneration` items.
- **Five new kinds, each with its own short skill:** `brand` (Claude writes `docs/opscode/brand/brand.md`: palette hex with roles, type, shape, icon and 3D style, the one-sentence style header every prompt starts with, formats per use, safe areas, never-list, reference images), `art` (Claude writes one prompt per asset), `asset` (Codex makes images with its image tool in one chat per batch, saves at exact paths, crops sheets, writes SVG for flat icons, looks at each result), `ui` (Codex builds screens with the project's tokens and the new assets), `visual` (Claude reviews images and screens against the brand kit; fails only on the brief or brand rules; gives a corrected prompt line).
- **Engines by strength, not only at limits:** with no engine named, the kind decides (ui and asset to Codex; brand, art, plan, fix, feature and visual review to Claude); asset jobs always run on Codex (only Codex makes images). The Conductor is told Codex is also a second opinion on a bug Claude failed twice. Codex models per mode and tier: GODMODE Luna / 6.1-Sol / Astra, WARLORD Luna / 6.1-Sol / 6.1-Sol, SHINOBI Luna / 6.1-Sol / 6.1-Sol (a model this Codex does not list is left out). The model list is learned at startup.
- **Reference images:** `chat_start images` (paths inside the project) reach Codex as attached local images and every worker as paths.
- **Asset proof:** an asset, art or brand worker's Check line must name files that exist; if none do, it is sent back once.
- **Pipeline UI stage** is now "UI & assets": brand kit, art briefs, Codex asset batches, screens, visual review with rounds by mode (3/2/1), `ui.md`; the gate card shows a gallery of the stage's images (only from its own folder).
- 25 checks in `test-phase25`, smoke checks the gallery thumbnail. 23 suites, 904 checks green.

Review findings, and where each went:

| # | Finding | Status |
|---|---|---|
| 1 | A restart failed items that still held pending chats | **Fixed in M2**: such items go back to waiting and start; a cut-off pipeline stage is queued and its Conductor is woken to continue it |
| 2 | Hand-off skipped slots, the daily cap and limits routing; a missing context count never handed off; the finish-check nudge continued a bloated chat | **Fixed in M2**: hand-off goes through `startChats` (may wait or park), falls back to input+cached tokens, the nudge goes through the hand-off path |
| 3 | Approval gates on `ask` could approve themselves; any note froze every auto-go-ahead | **Fixed in M2**: pipeline gates are not asks (runtime-only, person-only); a note now postpones go-aheads by the wait time instead of cancelling them |
| 4 | A worker waiting on approval held a slot (SHINOBI deadlock) | **Fixed in M2**: approval waits no longer hold a slot |
| 5 | Escalation has no failure counter; in SHINOBI base and frontier are the same model | M4 |
| 6 | No planner skill | **Fixed in M2**: `kind plan` with its own skill |
| 7 | Opus/day double-counts hand-offs and counts reviews; "today" is UTC | M4 |
| 8 | The finish check is skipped without `kind`; a second proof-less "done" still counts | M4 |
| 9 | The agent catalog's tier columns do not match the mode table exactly | Open (doc fix) |

## 7. Honest limits

- Opscode cannot rewrite what Claude Code's or Codex's own tools return mid-turn; trimming is briefs, skills and digests, not interception.
- Engine failover never moves frontier-tier logic to Codex automatically; that is a deliberate quality floor.
- A "project" pipeline needs the template repos in the Library first; otherwise stage 2 finds nothing and stage 3 marks everything "new".
- All accuracy claims until M5 are design expectations, not measurements.
