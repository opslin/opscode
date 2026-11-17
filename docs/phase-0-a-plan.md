# Phase 0 and Phase A: build plan

Built one slice at a time. Each slice ends with: tests on the fake CLIs, a smoke step, the smoke run against the packaged app, `npm run install-app`, and a short note to you. You see each slice in `/Applications/Opscode.app` after I reinstall. Normal chat is never changed; a smoke check proves it.

## Decisions (settled)

- **A mode is a preset on the existing Chief.** A "Conductor" is a Chief with `mode` set and `project_ids = [one project]`. No new orchestration system.
- **Mode chats live in the project's chat list** (New chat → pick a mode), carry an emblem, and do not appear under "Chiefs".
- **Models are exact ids per mode** (`claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`), not "latest" aliases. Each mode has a table `tier → { engine, model, effort }`, and escalation is a tier ceiling plus a prompt rule.
- **Cards:** one big posed pixel character, the name, one line. No stats or spec tables.
- **Cleanup** only touches worktrees and chats Opscode itself created, opt-in, with confirmation. It never touches `~/.caveman-code` or the transcripts Claude Code and Codex keep (deleting those breaks `--resume`).

## Slices

| # | Slice | Done when |
|---|---|---|
| 0 | **Token measurer**: Usage → "Where tokens go" | Reads Claude and Codex logs off the main loop, caches per file, de-duplicates, shows where tokens burn per project and session, and attributes Opscode chats. List-price estimates, clearly labelled. Fixture tests + smoke. |
| A1 | **Mode presets in the runtime** | `mode` on the Chief; per-mode tier table; review depth, parallelism and escalation as inputs to the Chief's prompt; tests that each mode starts workers on the exact models in your table. |
| A2 | **Conductor chat and mode picker** | New chat → pick Normal, GODMODE, WARLORD or SHINOBI; pixel character cards; emblem on chat, sidebar and header; Normal chat byte-for-byte unchanged (smoke assertion). |
| A3 | **Worker rules Opscode can enforce** | Hand-off to a fresh worker when a turn ends above ~150k; context pack in briefs; lean start measured on a real worker before any promise about start size; opt-in cleanup of Opscode's own worktrees. |

## What I will not promise

- **"Logs go to Haiku" and "tool output trimmed"** are instructions in the brief and, later, optional Claude Code hooks. Opscode cannot rewrite what Claude Code's own Bash or Read returns inside a running turn.
- **The ~25k lean start** stays unverified until measured on a real worker session.

## Status

| Slice | State |
|---|---|
| 0 Token measurer | Done and installed. 20 fixture checks, smoke step, run on your real logs (12 s for 7.7 GB). |
| A1 Mode presets | Done. 27 checks: exact models per tier for all three modes, the Opus daily limit, mode switching, plain Chief untouched. |
| A2 Conductor chat and picker | Done and installed. Pixel characters (art in `src/renderer/conductorart.js`), picker beside New chat, Conductor under its project, emblem in sidebar and header, Normal chat unchanged (smoke checks it). |
| A3 Worker rules | Done and installed. Hand-off to a fresh worker past 150k (120k in SHINOBI), Conductors only; working rules and a project map in each Conductor worker's brief; lean start levels (Standard / Lean / Leanest) for a Chief's workers only, with a Measure button you press yourself. 21 checks. |

### What A3 found and did not do

- **Real start-up cost:** from your own logs, Claude desktop chats start at about 92k tokens and Opscode's workers at 45–58k (not the 25k I hoped for). The Measure button shows the real saving of each lean level on your computer.
- **Not built, on purpose:** automatic cleanup. Opscode's own data is under 2 MB and it creates no worktrees yet. The 10 GB is Claude's and Codex's session logs and Caveman's worktrees, which Opscode must not delete on its own. A "free up space" tool that moves old logs to the Trash, with a preview and your OK, can be its own small slice.

## Phase B: Library (done)

- **What it is:** Library page in the sidebar. You add an app (a folder, or one click from the suggestions found in Documents); Opscode reads it once, off the main thread, with no model, and then knows its packages and stacks, its features, routes, database tables and import graph.
- **Features by convention:** `modules/<name>`, `features/<name>`, `controllers|services|screens|pages…`, Go `internal/<name>`, Next.js routes. A backend module and a Flutter feature merge only when the names match exactly after ignoring case and plural, and every merge records its reason. Tables and routes with no module become "tables only" / "routes only" features so they are still searchable.
- **Search** ("do we already have loyalty points?") ranks features across all apps with the evidence (route, table, symbol, file). A small synonym list (cart/basket, vendor/seller, loyalty/points…) is used for search only, never for merging.
- **Context:** `library.context` returns the files a worker should start from, plus one hop of the import graph.
- **Safety:** secrets are skipped by name and never opened (`*.pem`, `.env*`, keys, keystores, `credentials.json`, `google-services.json`…); only names, paths, routes and table names are stored, never code; other apps' data (`~/.caveman-code`, `~/.claude`, `~/.codex`) and system folders cannot be added. A real run caught and fixed an over-capture bug, now covered by a test.
- **Proven on your repos:** Radha (1,312 files, 110 features, 19 across backend and app) in 0.2 s, Project_opslin (2,587 files, 228 features) in 0.3-0.7 s; 99.5% of imports linked.
- **Not in B:** GitHub cloning (needs `gh`), LLM summaries of features, the gap report (Phase D).
