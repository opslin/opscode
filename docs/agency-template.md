# The Software Agency template

One template that takes a customer's requirement (for example "a grocery app with a Friday fish auction") and delivers a tested product: backend, dashboard and mobile apps. It uses your GitHub code templates, Claude for logic, Codex for UI and images, and your modes for cost.

## 1. What I found in your code (read-only, no tokens)

All three of your products are built on **the same stack**, your "Shotlin house stack":

| Part | Stack | Already in your repos |
|---|---|---|
| **Backend** | Fastify + Postgres + Redis/BullMQ + Firebase Admin | 124–261 test files per backend |
| **Dashboard** | Next.js (or React + Vite) + Tailwind + Zod | Playwright + Vitest in Bakaloo and Lndry dashboards |
| **Mobile apps** | Flutter + Riverpod + go_router + Dio + Firebase (customer, rider, vendor apps) | Flutter `test/` folders in every app |

Your code templates:

| Template | Repos |
|---|---|
| **Grocery** (Bakaloo) | backend (95 features), dashboard (78), customer app/website (43), rider app |
| **Meat** (FreshCuts) | backend (92), dashboard (119), mobile (42), rider, vendor app |
| **Laundry** (Lndry) | backend (119), dashboard (63), app (50), vendor app, desktop |

So **one agency template plus one "house stack" skill pack covers every product you make.** A new client starts from the closest code template, not from zero.

What this Mac has for testing:

| Ready now | Not ready yet |
|---|---|
| Node, Docker (running), Postgres, Redis: backend tests | **Android SDK and emulator are not installed**, and there are no iOS simulators. Mobile button tests and APK builds need them (a one-time setup, a few GB) |
| Playwright with Chromium: dashboard button tests in a browser | Flutter is installed (`~/dev-tools/flutter`) but not on the PATH; Opscode would point to it |

## 2. How the template is made (files)

It is a template folder (see `docs/templates-plan.md`): a normal plugin plus `template.yaml`.

```
software-agency/
  .claude-plugin/plugin.json
  template.yaml                     stages, slots, approvals, mode rules (below)
  skills/                           the skill pack (section 4)
  agents/                           planner, ui-designer, builder, tester, reviewer
  automations/agency.yaml           the stages in order, with approvals
  adapters/                         GitHub, issue tracker, APK delivery
```

`template.yaml`, short version:

```yaml
name: Software Agency
category: Software
mode: warlord                      # GODMODE for big clients, SHINOBI for small jobs
inputs:
  requirement: { ask: "Paste the requirement or attach files (PDF, DOC, MD, images)" }
  product:     { ask: "Which kind?", choose: [grocery, meat, laundry, other] }
slots:
  code_templates: { kind: repo_bundle, many: true }   # your GitHub repos, via the Library
  test_devices:   { kind: test_runner, needs: [api, browser, android] }
  delivery:       { kind: delivery, needs: [send_file] } # APK to you (in Opscode, Telegram, Firebase…)
approvals: [plan, ui_gallery, each_apk]                 # nothing ships without your OK
budget: { per_stage: true, stop_and_ask_at: 80% }
```

## 3. The stages, who does each, and what it costs

| # | Stage | What happens | Who does it | Approval |
|---|---|---|---|---|
| 1 | **Read the requirement** | Reads the PDF/DOC/MD/images, asks only what is missing, writes `spec.md`: every feature with "done when" checks | Haiku reads and pulls out text; Sonnet writes the spec | answer questions |
| 2 | **Match your code templates** | Picks the closest template (grocery → Bakaloo) and checks every spec feature in the **Library** | **The Library: no model, zero tokens** | — |
| 3 | **Gap report** | Every feature: **have** (where), **change**, or **new** | Sonnet, reading only the spec and the Library results | — |
| 4 | **Plan** | Milestones, tasks, database and API changes, screens list, diagrams, cost estimate | Opus (GODMODE always; WARLORD only for complex projects), else Sonnet | **you approve the plan** |
| 5 | **UI design** | Claude writes a UI brief using **your design system read from the template repo** (colours, fonts, components). **Codex builds the screens** (Flutter widgets, dashboard pages) and makes icons and illustrations (ChatGPT images). Screenshots go to Claude for review against a UI checklist, then are refined (3 / 2 / 1 rounds by mode) | Codex = UI + images; Sonnet = brief + review | **you approve the screens gallery** |
| 6 | **Build, feature by feature** | Each feature gets its own branch and a fresh worker that starts from the exact files the Library points to. Existing modules are copied from the template repo first, then changed | Claude for backend, data, payments, auction logic; Codex for UI wiring and small jobs; Opus only for hard functions in GODMODE | — |
| 7 | **Test** (section 5) | Backend, dashboard, mobile, then the whole flow end to end | Scripts run the tests; Haiku reads failures; the builder fixes them | — |
| 8 | **Review** | Checks the rules, security and the spec's "done when" | Opus (GODMODE), Sonnet (WARLORD/SHINOBI) | — |
| 9 | **Deliver** | Builds the APK and a dashboard preview link, sends them to you; your feedback becomes small change tasks | Scripts | **you approve each APK** |

## 4. The skill pack (what Opscode learns once from your repos)

Skills are short instruction files that workers read. Most come from **your own code**: Opscode reads a template repo once and writes them, you correct them, and they are kept in a GitHub repo (`shotlin-skills`) so every project uses the same ones.

| Skill | What it teaches |
|---|---|
| `shotlin-backend` | How a module is laid out in your Fastify backend, migrations, auth, queues, error style, how tests are written |
| `shotlin-dashboard` | Your Next.js/Tailwind page and component patterns, forms with Zod, how Playwright tests are written |
| `shotlin-flutter` | Your Riverpod + go_router feature layout, Dio API clients, widget tests and integration tests |
| `requirement-to-spec` | Turning a customer document into features with "done when" checks |
| `gap-report` | Using the Library to say have / change / new, with file paths |
| `plan-writer` | Milestones, tasks and diagrams in your plan format |
| `ui-brief` | Your design system: colours, type, spacing, components, empty/loading/error states |
| `ui-review` | The checklist screens must pass: overflow, contrast, tap size, states, matches the approved design |
| `image-assets` | Prompts for icons and illustrations in your brand palette (for Codex / ChatGPT images) |
| `reuse-module` | Copying a feature from a template repo safely: rename, adapt, keep its tests |
| `api-tests` | Writing API tests for every endpoint, including bad inputs |
| `dashboard-e2e` | Playwright flows plus the button crawler (below) |
| `flutter-e2e` | Integration tests that tap through screens on the emulator |
| `test-digest` | For Haiku: turn a long test log into the failing lines only |
| `release-apk` | Version bump, build, size check, release notes |

## 5. Testing, layer by layer

| Layer | How it is tested | Tools |
|---|---|---|
| **Backend** | Your existing unit tests, plus new API tests for every new or changed endpoint (good input, bad input, wrong user), against a fresh Postgres + Redis in Docker with seed data | Your test runner, Fastify `inject`, Docker |
| **Dashboard** | Playwright opens the pages in a real browser. **Button crawler:** on every changed page it clicks every button and link and fails on errors, broken pages, console errors or elements off screen. Then the spec's flows are run (e.g. "admin opens Friday auction, sets start price"). Screenshots are compared with the approved UI | Playwright + Chromium (installed) |
| **Mobile apps** | Flutter widget tests for each new screen; integration tests that **tap every button** on the Android emulator, check that it is visible and tappable, catch layout overflow errors, and take screenshots to compare with the approved designs | Flutter `integration_test` (or Maestro), Android emulator: **needs setup** |
| **Whole flow** | One scenario across everything: the customer app bids in the auction → the backend picks the winner → the dashboard shows it → the rider app gets the delivery | All of the above together |

A failing test goes back to the builder with only the failing lines (from the Haiku digest), not the whole log. After two failed fixes, that one task moves up one model, as your mode rules say.

## 6. How it stays cheap (no overspending, no overfilled chats)

1. **The Library before any model.** Matching your templates and finding files costs zero tokens. Workers never explore the repo themselves.
2. **Files, not chat history.** Each stage writes one file (`spec.md`, `gap.md`, `plan.md`, `ui-brief.md`), and the next stage reads only that file. No stage sees the whole conversation.
3. **A fresh worker per task**, a 150k hand-off, lean start, and one model per worker (already built in Phase A).
4. **Tests are run by scripts, not by a model.** Only failures reach a model, already shortened by Haiku.
5. **Screenshots only where they matter:** pixel comparison first; a model looks only at new screens and failed comparisons.
6. **Codex does UI and images**, in one ongoing thread per screen group, so Claude's limits go to logic.
7. **A budget per stage**, with a stop and question at 80%. The Usage page shows the cost per project, so the benchmark is real.

## 7. What to build, in order

| # | Piece | Status |
|---|---|---|
| — | Modes, Conductor, hand-off, Library, Usage | **Built** |
| 1 | **"Learn my stack"**: generate the skill pack from a template repo (backend, dashboard, Flutter), for you to review | New |
| 2 | **Template folder + install wizard** (minimal, for this template) | New (Templates T1/T2) |
| 3 | **Requirement → spec, and the gap report** | Phases C + D |
| 4 | **Test runners for backend and dashboard**, including the button crawler. Runs on this Mac today | Phase G, part 1 |
| 5 | **UI loop**: brief → Codex screens and images → review → your gallery | Phase E |
| 6 | **Build loop**: a branch per feature, reuse from templates, fixes from test failures | Phase F |
| 7 | **Mobile testing and APK**, after the Android SDK and emulator are installed | Phase G part 2 + H |

The first real test: run the template on one feature of a real requirement (for example "Friday fish auction" on the Bakaloo template), in WARLORD, and compare the cost with your old way on the Usage page.

## 8. Decisions for you

1. **The default code template for each kind:** grocery = Bakaloo, meat = FreshCuts (meet-commerce), laundry = Lndry?
2. **Android setup:** may I install the Android SDK, an emulator image and add Flutter to Opscode's path? (Several GB; needed for mobile tests and APKs.)
3. **UI style for a new client:** start from the template's design and change colours and logo, or design fresh each time?
4. **APK delivery:** inside Opscode, Telegram, or Firebase App Distribution?
