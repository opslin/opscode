# Opscode: hand-off for the next session

Written 2026-11-17 at the end of a long session. It is the single place that says what is done, what is pending, how to test it, and what the person has decided. A new session should read this file first, then continue exactly from "Where we stopped" (section 9).

---

## 0. The prompt to paste into a new session

Copy everything in the box below into the first message of a new session opened in `/Users/sayan/Documents/opscode`.

```text
You are continuing a long project with me in /Users/sayan/Documents/opscode (my own desktop app "Opscode", Electron + a local Node runtime). Do not start from scratch.

1. Read these first, in this order, before you answer anything:
   - docs/HANDOFF.md (this is the master file: what is done, what is pending, how to test, my decisions, where we stopped)
   - docs/lead-intelligence-design.md (the design of the lead-finding and email module we are building)
   - docs/explee-teardown.md (how Explee, the product we studied, works)
   - your memory notes in the project memory folder (opscode-build.md and explee-teardown.md)
2. Run `git status --short` and `npm run typecheck`, then run the five lead test suites (scripts/test-phase48.mjs to test-phase52.mjs) to confirm the starting point is green (68, 57, 48, 49, 34 checks). Build first with `npx tsc -p tsconfig.json`.
3. Tell me in a few plain, short sentences: where we stopped, and the decisions I still owe you (section 8 of docs/HANDOFF.md). Then ask me ONE question: which of those I want to answer first. Do not build anything until I answer.

How to work with me (I write in non-native English, so keep your answers short, plain and honest):
- Never commit or push. I push with GitHub Desktop. Never use my API keys or log in to any account without asking me first.
- Show me the plan first. I approve each slice ("Start slice N"). Build one slice at a time.
- Test everything for real: write a scripts/test-phaseNN.mjs, run it, and say exactly what was and was not tested. Never claim something works that you did not run. If a vendor page and a test disagree, say so.
- If I am wrong or something I asked for does not exist (for example Hostinger has no email-marketing MCP server), say so clearly.
- When you finish, update docs/HANDOFF.md (section 5 done, section 7 pending, section 9 where we stopped) and your memory notes, so the next session can continue.
```

---

## 1. The person and the rules

- Owner of Opscode and of the freelance brand "sayan the coder" (sayanthecoder.in), based in Kolkata. Builds apps and sites for businesses. Writes in non-native English: answer in short, plain sentences, no jargon, say what you did and did not test.
- Opscode is **their own original app** (coding agent app with chat, Chief orchestrator, automations, MCP, plugins, voice, devices). The lead module is a new part of it.
- **Never commit or push.** The person pushes manually with GitHub Desktop. The working tree has many uncommitted files (section 2).
- Always show a plan first, then build one slice at a time after "Start slice N".
- Do not enter credentials or create accounts for them. Ask before using any key. There is **no model API key saved in Opscode** and none in the environment.
- Everything outward-facing (sending email, publishing) needs their explicit approval.

## 2. Project snapshot

- Repo: `/Users/sayan/Documents/opscode`. Stack: Electron 33 (Node 20.18.3 inside, no `node:sqlite`), TypeScript runtime in `src/runtime`, renderer in `src/renderer` (plain JS) and `src/islands` (React). The runtime is a separate Node process, spoken to over WebSocket JSON-RPC (`src/runtime/methods.ts` defines every method).
- System Node on this Mac: v24.22.3. Google Chrome is installed. `claude` (Claude Code 2.1.325) is at `~/.local/bin/claude`. `gh` is not installed.
- Opscode's data folder: `~/Library/Application Support/Opscode/runtime` (no `providers.json`: no model key set up).
- Build and test:
  - Typecheck: `npm run typecheck`. Compile the runtime to `dist/`: `npx tsc -p tsconfig.json`. Copy renderer assets: `node scripts/copy-renderer.mjs`.
  - One suite: `npx tsc -p tsconfig.json && node scripts/test-phaseNN.mjs`.
  - Everything: `npm test` (builds, then runs about 50 suites; takes many minutes; run it in the background). It passed (exit 0, 50 suites) on 2026-11-17, before one last small revert; the related suites were rerun after and passed.
- Uncommitted work from this session (all of it is new or edited, none committed):
  - Edited: `THIRD_PARTY_NOTICES.md`, `package.json` (test chain adds phases 48 to 52), `scripts/copy-renderer.mjs`, `src/renderer/pages.js`, `src/renderer/styles.css`, `src/runtime/index.ts`, `src/runtime/mcp.ts`, `src/runtime/mcpCatalog.ts`, `src/runtime/methods.ts`.
  - New: `src/runtime/leads/` (whole module), `assets/brand/integrations/` (logos), `docs/explee-teardown.md`, `docs/lead-intelligence-design.md`, `docs/HANDOFF.md`, `scripts/lib/fake-chrome.mjs`, `scripts/test-phase48.mjs` to `test-phase52.mjs`.
- Memory notes (project memory folder `~/.claude/projects/-Users-sayan-Documents-opscode/memory/`): `opscode-build.md` (the app's history and gotchas) and `explee-teardown.md` (everything about this lead module, decisions, facts). Keep both updated.

## 3. The two documents that explain the work

1. `docs/explee-teardown.md`: how Explee works. Key facts: it queries a pre-built database of about 400M people with an LLM label per company (`definition`), an agent with SQL, Python and AI-scoring tools finds leads, only about 11% of leads had a usable email, it sends from about 183 lookalike mailboxes under made-up names, results were 748 emails, 15 replies (2.0%), 7 hot.
2. `docs/lead-intelligence-design.md`: the design of our own version. Sections: ontology (2), sources and their legality (3), agent pipeline and scoring (4), storage (5, decision changed to local-first), guardrails (6), open-source tools (7), what Opscode already has (8), onboarding flow (8b), research step (8c), lead sources and connectors (8d), mail engine, mini CRM and laptop-off plan (8e), build order (9).

## 4. Product goal in one paragraph

A user says what they sell and which industry they target (one sentence or a website). Opscode researches the business and competitors, designs the campaign, finds high-quality leads from the web with evidence (quotes, links, dates), judges each lead against a rubric, writes a personal first email, sends it safely from a pool of mailboxes, reads the replies, and keeps everything in a built-in mini CRM (or pushes to the user's own CRM). Works for any industry through industry packs. Email first, WhatsApp later. Local first; Postgres only if the user wants it. Users can add their own MCP servers and plugins as lead sources.

## 5. What is DONE

All of it is in `src/runtime/` unless noted. Every item has a test suite that passes.

### 5.1 Slice 1: ontology and evidence store (`src/runtime/leads/`) , `scripts/test-phase48.mjs` (68 checks)
- `ontology.ts`: types (Organization, Person, Role, Account, Doc, Observation, Signal, Need, Interest, Lead, Interaction, Suppression, IndustryPack, Offering), 12 signal types with half-lives, `decayed()`, `combine()` (noisy-or), `normalizeDomain()`, placeholder-domain blocklist, `quoteInText()`, `classifyTitle()`.
- `store.ts`: `LeadStore`, one JSONL file per collection (append-only log, compaction, private permissions). Rules enforced in code: an Observation needs quote, URL, date, confidence and extractor; if it names a stored document the quote must appear in that text; a Signal must rest on observations about the same organization; a Need must rest on signals; suppressed email/domain/person can never be added (person suppression is hashed); `forgetPerson()` cascades; `observeOnce()` and `addSignalOnce()` make rescans idempotent; `llmSeen()` remembers model-read pages.
- `packs.ts`: `PackRegistry` (built-in restaurants pack, version 2, plus installable JSON packs), `validatePack`, `CORE_RUBRIC` (6 criteria), `matchOffering`, `OFFERING_TEMPLATES` (the person's dev-services offering).
- `schema.sql`: Postgres form of the tables (SQLite form not written yet).
- RPC: `leads.pack.list/get/install`, `leads.offering.templates/list/save/match`, `leads.org.upsert/get/list`, `leads.person.upsert/forget`, `leads.account.add`, `leads.document.add`, `leads.observe`, `leads.signal.add`, `leads.need.upsert`, `leads.suppress`, `leads.stats`.

### 5.2 Slice 2: website scout (`src/runtime/leads/scout/`) , `scripts/test-phase49.mjs` (57)
- `net.ts`: safe fetch (public addresses only, checked at connect time including redirects, no odd ports, no credentials, size cap, gzip), robots.txt per RFC 9309 (fetched before any page; a 5xx or no answer means do not crawl), user agent `OpscodeBot`.
- `html.ts` (dependency-free HTML reader), `tech.ts` (tool fingerprints), `crawl.ts` (home plus one page per kind, polite delay, Crawl-delay honored), `extract.ts` (deterministic extractor: JSON-LD, meta, mailto/tel, tools, the pack's phrases to observations, signals and needs).
- RPC `leads.scout.website`: up to 20 domains, one scan at a time, progress events, test hook `OPSCODE_LEADS_TEST_MAP`.

### 5.3 Slice 2b: browser renderer and model reader , `scripts/test-phase50.mjs` (48) with `scripts/lib/fake-chrome.mjs`
- `proxy.ts` (local forward proxy that keeps a rendered page's scripts away from private addresses), `render.ts` (installed Chrome/Chromium/Edge, headless, throw-away profile, `needsRender()` heuristic fixed on real client-rendered apps).
- `llm.ts`: model reader, page treated as data, answers validated (need ids and company types from the pack, quotes must be on the page, quotes inside instruction lines rejected, confidence capped at 0.85), call and character budgets, stops after 3 failures.
- RPC `leads.scout.website` options: `render` (default on), `use_llm` (default off; needs a configured provider and a pack), `max_llm_calls`.

### 5.4 Slice 3: Lead LAB (`src/runtime/leads/lab/`) , `scripts/test-phase51.mjs` (49)
- `case.ts` (frozen JSON lead case, `buildCase` from the store), `criteria.ts` (rules, judge questions, or both; missing input fails without a model call), `judge.ts` (strict JSON verdict, one retry, error means fail), `run.ts` (all-pass scoring, deterministic audit sample with a stronger judge), `gold.ts` (22 hand-written gold cases), `score.ts` (agreement, false-pass list, gate, Markdown report).
- RPC: `leads.lab.criteria/case/evaluate/gold` (`dry_run` counts model questions for free; a real run saves a report under `<state>/leads/lab/reports/`; own gold files go in `<state>/leads/lab/gold/`).
- **Tested only with keyword judges and a mock model server. Never run against a real model.**

### 5.5 Connectors, logos, engine reach , `scripts/test-phase52.mjs` (34)
- `mcpCatalog.ts`: new entries Firecrawl (keyless `https://mcp.firecrawl.dev/v2/mcp`, optional Bearer key), TinyFish (`https://agent.tinyfish.ai/mcp`, Bearer key required), Zoho Campaigns, Zoho Mail, Hostinger Mail (the person pastes their own server URL, kept secret: `secret_url`, `maskUrl`), optional inputs, honest notes. Existing entries unchanged.
- Official logos for all 16 entries in `assets/brand/integrations/` (+ `NOTICE.md`), shown on white plate tiles in `src/renderer/pages.js` and `styles.css`; copied to `dist/renderer/brand/integrations` by `scripts/copy-renderer.mjs`.
- `index.ts`/`mcp.ts`: the person's MCP servers now also reach Claude Code and Codex chats through Opscode's own `/mcp/devices` endpoint (short names `server__tool`, max 38 characters), with the same approvals as the built-in agent. Servers connect at the start of each turn (no startup connect).
- Real checks done: Opscode's MCP client connected to Firecrawl keyless (3 tools: scrape, search, parse) and scraped example.com; TinyFish without a key answered 401 and showed "needs a key".

### 5.6 Browser sign-in for MCP servers, Plugins page, skill install scope (2026-11-17) , `scripts/test-phase54.mjs` (42) + `scripts/test-phase55.mjs` (24)
- Asked for by the person after looking at Caveman Code's Plugins page. Caveman's catalog (`Caveman Code.app/.../runtime/catalog`) was read for the list of servers and which need sign-in; the OAuth code is our own, written from the public MCP authorization spec.
- `src/runtime/mcpOAuth.ts`: discovery (WWW-Authenticate `resource_metadata`, RFC 9728, then RFC 8414 / OpenID), dynamic client registration (RFC 7591, public native client "Opscode"), authorization code + PKCE S256, `resource` parameter (RFC 8707), loopback redirect on 127.0.0.1 (state checked, Host checked, only `/callback`, closes when done), token refresh (single-flight, rotated refresh tokens, `invalid_grant` = sign in again). All endpoints must be https (http only when the MCP server itself is on localhost); an authorization server on a private address is refused; resource must be the same site as the server. Tokens only in `mcp-oauth.json` (0600); lists and events never carry them.
- `mcp.ts`: `HttpClient` takes a token source and retries once after a refresh; a typed Authorization header always wins. A server that answers 401 with sign-in settings is marked `oauth` by itself (so imported servers like firecrawl get a Sign in button). New fields on `McpServerInfo`: `auth`, `signed_in`, `signing_in`, `needs_signin`, `expires_at`. RPCs `mcp.oauth.start|cancel|sign_out`, event `mcp.oauth.done`.
- `mcpCatalog.ts`: categories, `featured`, `auth: "oauth"`, `unavailable`. New servers with sign-in (sign-in settings read from each server on 2026-11-17): Linear, Notion, Sentry, Supabase, Neon, Vercel (reviewed apps only), Atlassian, monday.com, Figma, Stripe, Cloudflare, PostHog, Firecrawl (sign in). Slack and Asana are listed as not available (they do not register apps dynamically). The old token entries were renamed "(token)". Logos in `assets/brand/integrations`.
- Plugins page rewritten in `src/renderer/plugins.js` (old one removed from `pages.js`): Recommended row, catalog by category, "N need a sign-in or a key" + Set up dialog, detail page per server (Sign in / Waiting / Signed in + Sign out, keys, tools list, facts panel with status/from/whose/engines/idle cost) and per skill (instructions + facts, move between all projects and this project, remove).
- Skill install from chat now asks WHERE: card with All projects / This project / Just this task. `GateResult.choices`, `ToolCtx.choice`, `turn.approve {choice}` (only offered ids accepted; no choice = the narrowest), `ApprovalChoice` on events and message parts, `SkillFinder.install(source, skill, chat, scope, workspaceId)`. All projects = personal skills (works as /name in every project); This project = `<project>/.opscode/skills` (not offered when `.opscode` is a link); Just this task = the old temporary behaviour. A skill needed 3 times, or asked with keep, is not offered as temporary. `skill.changed` fires so the / menu refreshes. phase30 was updated for this.
- NOT tested for real: a real sign-in at a real service (DCR registers a client at the vendor, and the browser login is the person's), Zoho/Hostinger/TinyFish, Vercel and Figma (may refuse unapproved apps). Real checks done: sign-in settings of 18 servers read live; phase54 uses a fake service that checks PKCE, redirect, resource, refresh.

### 5.7 The notch (2026-11-17) , `scripts/test-phase56.mjs` (53)
- Always-on notch at the top of the screen, like Agent Notch / Dynamic Island, in Opscode's own code and art. Research notes (Agent Notch via REA, Caveman's notch, coucou, Reddit complaints): `research/notch-research.md` (git-ignored).
- `src/main/notchState.ts` (pure, tested): `NotchModel` turns `turn.event` / `chat.changed` / `workspace.list` into sessions (working / needs / done / failed / idle), one-line tickers, approvals, unseen badges, a pose and a pulse; `notchAction()` checks every page action; `hardwareNotchOf()` reads the camera notch.
- `src/main/notch.ts`: the clear panel window (type panel, level main-menu+3, all Spaces + fullscreen, click-through except the shape, cursor watch), its own runtime connection (works with the main window hidden or closed, reconnects), actions (open chat, new chat, Allow / Always / Deny only for an approval it shows, stop, quick message to a chat or a new chat, voice dictation via `voice.start/stop`), global shortcut ⌘⇧Space, right-click menu (Open, New chat, Sounds, Hide for an hour, Quit), settings in `userData/notch.json`.
- `src/main/index.ts`: macOS red close button hides the window (⌘Q quits); focus/blur tell the notch which chat is seen; `OPSCODE_PROFILE` (dev only) runs from source on a separate profile beside the installed app; notch off in smoke/realtest or with `OPSCODE_NOTCH=0`.
- Renderer: `notch.html/.css/.js` (closed / peek / open shapes with spring open and soft close, flared corners, red glow ring + halo while something needs you, warm sweep on done, red-black pixel dissolve + bloom on open, hover intent, 0.7 s click guard, approval cards, chat rows with engine logos and marquee, composer with project / reply target, click-to-dictate and hold-to-talk-and-send), `notchchar.js` (Ember, own pixel character: sleeping / working / needs / done / error, plus pixel digits), `notchsound.js` (own Web Audio sounds: done = "pu-pu-pu-pu" + chime, needs, failed, open, send; no audio files; Agent Notch's sounds were only measured, not copied). `app.js` reports the chat on screen and opens chats the notch asks for. Demo in a browser: `dist/renderer/notch.html?demo=open|needs|working|done|sleep`.
- Tested: 53 checks (model, actions, measuring, a real runtime seen by a second client, built files). Real Electron run on a throwaway profile: notch measured 179x32, window 640x640 at level 27 centred on top, connected to the runtime. Looked at in the browser preview (open, needs, closed, peek).
- NOT tested by hand yet: hover/click-through on the real screen, typing in the panel while another app is in front (panel focus), the red close button hiding, the sounds through speakers, voice from the notch, fullscreen video. Installed to /Applications on 2026-11-17 (npm run install-app, exit 0).

### 5.8 Voice mode in the notch, across projects (2026-11-18) , `scripts/test-phase57.mjs` (37) + phase56 (58) + phase45 updated (87)
- Runtime `voiceagent/projects.ts`: describeProject, findProjects (speech-tolerant: "deal car server" -> dealker-server), lookFolder (read-only, home folder only, never .ssh/.gnupg/.aws/Library/…, links leading outside refused), findFolders (bounded walk of the usual code places).
- Voice agent (`voiceagent/index.ts`, `tools.ts`): no longer tied to one project. New tools projects_list, project_find, folder_look, folder_find, project_add (needs folder_look first AND confirmed=true after the person's yes), models_list; work_start takes project, engine, model, effort (checked against installed engines and their models); peek takes project. Each worker keeps its own project (status line and worker events carry project/model/effort). voiceagent.start without workspace_id = the project worked in last. `OPSCODE_VOICE_HOME` (tests) sets the home folder. engineProblem now also checks the engine program exists on disk.
- Prompt (approved plan): sections PROJECTS AND FOLDERS and WORKER SETUP (ask one short question only when project / what to do / done-when is unclear and a wrong guess wastes work; say when a worker starts in another project or on a non-default model). `docs/prompts/voice-agent.md` regenerated.
- Notch: Talk button + ⌃⌥Space (Control-Option-Space) start/stop. `renderer/notchtalk.js`: mic via voicecapture.js (echo-cancelled), agent voice played in the notch (own small player, reports playback/progress through main), pixel sound bars, captions (you / Opscode), what it is doing, worker cards (logo, project, model + effort, Yes / No for approvals), type-instead box, mute, interrupt, End. Collapsed while talking = one live caption line under the notch (not closed); a worker asking opens it with the red glow; ember ring while talking. Ember poses listen + talk. Main relays voiceagent.* and tts.event for the notch's own session only; actions validated in notchAction.
- Tested: 37 + 58 + 87 checks with a fake microphone helper, fake voice and a mock model; real Electron launch (notch placed, connected); browser preview of the voice view (demo: notch.html?demo=talk).
- NOT tested for real: a spoken conversation through the real microphone and speakers in the notch, Chromium echo cancellation in the notch window, the ⌃⌥Space shortcut on the real keyboard, a real model choosing projects. Installed to /Applications 2026-11-18.

### 5.9 Computer use, slice 1: native opscode-hands (2026-11-18) , `scripts/test-phase58.mjs` (7 + 9 live)
- Plan (approved): S1 native hands helper, S2 runtime tools + risk-only asking + instant no-AI commands + learned replays, S3 voice agent + notch "On my Mac" + live steps, S4 cheap model with step-up + budget tests. Decisions: ask ONLY for risky steps (buy/pay/send/delete/submit/passwords; denylist and per-app "never" still block); computer steps on a fast cheap model, step up after 2 failures. Research: research/atticus-notes.md (Atticus is MIT; credit in THIRD_PARTY_NOTICES.md).
- `native/opscode-hands/main.swift` (built by scripts/build-native.mjs to dist/native/opscode-hands, ad-hoc signed): check, apps, see (numbered AX text map: role, label, value, place; secrets masked; risky labels marked; visible text as data; <2.5k chars), click (AXPress/Confirm/Pick/Open, AXShowMenu, else per-process mouse events), type/append (AXValue, else unicode keys to the pid; reads the field back), key, scroll, menu ("File > New Window"), open (app or URL), wait (until settled); every action re-reads the window and reports changed true/false. State (numbers) in --state file; an element is found again by path, else by unique role+label, never guessed. selftest = 27 in-memory checks.
- `native/opscode-hands/fixture.swift`: tiny test app (built only by the test).
- NOT done in slice 1: no runtime tools use it yet (slice 2). Live checks need the Accessibility permission for the process running the test (this shell has none: 9 live checks SKIPPED). Chromium background keys (SkyLight auth message) and focus-without-raise from Atticus are not ported yet.

### 5.10 Computer use, slice 2: runtime tools, risk-only asking, instant commands, learned replays (2026-11-18) , `scripts/test-phase59.mjs` (44)
- `src/runtime/hands.ts`: Hands (runs opscode-hands, per-chat state file in <state>/hands/), handsTools (computer_see/click/type/key/scroll/menu/open/apps): gates run plain steps with NO card in any mode; ASK for risky labels (buy/pay/send/delete/submit…), cmd+q/w/delete, card numbers or "password:" text, risky menu items; DENY denylist apps, "never" apps, password fields. Results carry "window changed?" + the new list. parseInstant/runInstant (open/quit/switch apps and sites, no AI). ReplayStore + runReplay (keeps only confirmed plain steps; never risky/quit/cmd+q/card numbers/"this-that" requests; replay stops when nothing changes). Native gained quit, activate, press-label.
- Chats: with the helper AND Accessibility allowed (checked every 20 s) a chat gets the new tools + computer_screenshot; otherwise the old screenshot tools. COMPUTER_GUIDE (API engine prompt) updated: use computer_see, trust only confirmed results; docs/prompts regenerated.
- RPCs: computer.instant {text} -> {handled, ok, say}; computer.replays.list / computer.replays.forget.
- Test stand-in: scripts/lib/fake-hands.mjs (OPSCODE_HANDS_BIN, OPSCODE_FAKE_HANDS_AX=0, OPSCODE_FAKE_HANDS_STALE=1).
- NOT yet: replays are learned/played only by code that calls them (slice 3 wires voice/notch: instant first, then replay, then AI, then learn); the Settings page does not list learned tasks yet; real apps untested (no Accessibility in this shell).

### 5.11 Computer use, slice 3: voice + notch + on-screen effects (2026-11-18) , `scripts/test-phase60.mjs` (26) + phase59 (45) + phase45 (87)
- Voice agent (voiceagent/index.ts): VoiceComputer dep (index.ts) gives it the computer_* tools (risky steps answer "ASK FIRST"; they run only with confirmed=true right after a spoken yes), instant commands and learned replays BEFORE the model (heard() -> fast(): "open chrome" or a learned phrase is done and spoken with no model call), and learning after a reply whose Mac steps all worked. New tool workers_show. Prompt section USING THE MAC (docs/prompts regenerated). With computer use off, instant commands step aside (never take words from the agent). Instant verbs: open/launch/fire up, quit/close, switch to/go to/focus (not run/start/show; never with my/workers/projects).
- Runtime: every step is announced as computer.act {source chat|voice|task, phase start|end, summary, app, pid}. RPC computer.task {text} (the notch's "On my Mac"): instant -> learned replay -> else a chat (auto) that does it with the tools; when its turn completes, its steps are learned.
- Native: opscode-hands bounds <app|pid> (window list, no permission).
- Overlay (src/main/overlay.ts + renderer overlay.html/js/css + preload/overlay.ts): one clear click-through window over the main screen at "status" level (under the notch). While steps run: red/ember pixel comets round the screen's rounded edge, sparks, breathing glow, caption pill "Opscode is using <app> · <step>"; a marching red pixel frame with white corner brackets round the app's window (follows it via bounds every 0.4 s) + OPSCODE tag; fades 2.5 s after the last step. "Show my workers" (voice, or the notch's grid button): mini app-window screens of every chat at work (status, live step, end of what it said, its ask as an input line, project, model, time); click opens the chat; Esc / backdrop closes; only then does the window take clicks. Demo: dist/renderer/overlay.html?demo=working|workers (window.__frames(n) draws frames in a hidden tab).
- Notch: header grid button = workers view; the composer target cycles projects -> "On my Mac" (computer.task); voice view shows each Mac step live.
- Tested: 26 + 45 + 87 checks with stand-ins (fake mic, fake voice, fake hands, mock model); overlay and notch looked at in the browser preview. NOT tested for real: the overlay on the real screen in Electron (window level over full-screen apps), real apps (no Accessibility in this shell), a real voice conversation driving the Mac.

### 5.12 Quality fixes, Slice A (2026-11-20) , `scripts/test-phase62.mjs` (32) + phase13 updated (50)
Plan and audit: `docs/quality-fix-plan.md` (from the person's real chats, Nov 16-19). Slice A = bug fixes, no prompt changes.
- A1 Claude Code "Stream closed": `engines/claude.ts` no longer closes Claude's input at the first `result` while a background job runs (tracks `system/task_started` / `task_notification`; background dev servers/watchers are not waited for, see `longLived`). Closes 20 s after the last job ends and Claude is idle, or after 30 min of silence from a job (says so in the chat). Env for tests: OPSCODE_CLAUDE_BG_IDLE_MS, OPSCODE_CLAUDE_BG_SETTLE_MS. Fake: FAKE_BG / FAKE_BG_SERVER / FAKE_BG_SILENT.
- A2 Antigravity asked for every command: it sends `rawInput.CommandLine`; `engines/acp.ts commandOf()` reads command / CommandLine / commandLine / command_line / cmd. Fake: FAKE_CMD_AGY. Qoder sends `command` (checked in its binary) and works.
- A3 Codex sandbox: `CODEX_POLICY` auto = danger-full-access + untrusted (Opscode answers by riskOf, as for Claude), full = danger-full-access + never; read/supervised read-only, auto_edits workspace-write. turn/start now also sends `sandboxPolicy` (so resumed threads change too). The person chose full access.
- A4 Full disk: `chats.ts flush` catches save errors (ENOSPC killed the runtime 4x on 2026-11-19), keeps chats in memory, retries every 10 s; `jsonFile.writeJsonAtomic` removes its cut-off temp file on failure; `disk.ts` + `turns.ts` show a `disk_space` card under 5 GB free (at turn start and every 10 min). Test hooks: OPSCODE_FAKE_FREE_BYTES_FILE, OPSCODE_FAKE_DISK_FULL, OPSCODE_CHAT_SAVE_RETRY_MS, OPSCODE_DISK_CHECK_MS.
- Checked: `npm test` (59 suites, 2,265 checks, exit 0) and `npm run smoke` (PASS). The smoke step "show the project in the sidebar" (right after its crash-recovery step) is FLAKY: it failed 3 of 4 runs, and the installed Nov 19 build fails it too, so it is not from Slice A. The smoke now prints the window and store state when a step fails (src/main/index.ts `until`); cause not found yet.
- NOT tested for real: a real Claude Code run with a background build, real Antigravity, real Codex with full access (uses the person's Codex account: ask first). The disk card is shown by the generic error card in the chat (not designed further).

### 5.13 Quality fixes, Slice B: question cards (2026-11-20) , `scripts/test-phase63.mjs` (37) + smoke step "question card"
Plan: `docs/quality-fix-plan.md` Slice B (the person said "Start slice B", note included).
- `src/runtime/ask.ts`: normalizeQuestions (any engine's shape; 1-4 questions, 2-4 options, drops "Other"/duplicates), checkAnswers, resultText, claudeAnswers (keyed by Claude's own question text; multi = list), codexAnswers, askTool (`ask_user`, kind note), parseQuestionBlock + QUESTION_BLOCK_NOTE (backup "Questions:" block), QUESTION_NOTE (~90 words, in devicesNote when ask_user is present).
- Protocol: AskQuestion/AskAnswer/ASK_LIMITS, ToolStatus "awaiting_answer", part.questions/answers/skipped, events "question" / "question_answered", RPC `turn.answer {turn_id, call_id, answers?|skip}` (a late card from an ended turn returns {turn_id, text}: the answer was sent as the next message).
- turns.ts: TurnHost.askUser waits like an approval; Stop resolves it as skipped; deps.noAsk + defaultNoAsk (automation steps, Manager workers, voice-mode workers answered at once); backup block -> late card after "completed".
- Engines: Claude AskUserQuestion via can_use_tool (allow + updatedInput.answers, skip = deny with message); Codex item/tool/requestUserInput; ask_user over the device MCP (Codex, ACP with MCP, Claude) and the API agent (ToolCtx.ask, GrantHost.askUser); ACP without MCP gets QUESTION_BLOCK_NOTE.
- Screen: `src/renderer/askcard.js` (card on top of the message box: keys 1-4/Enter/Esc, Back/Next, Other box, Skip, Recommended chip; Esc hides -> "Waiting for your answer · Open" pill; typing in the message box answers), message.tsx AskLine ("Waiting…/You chose/Skipped"), state.waiting -> sidebar "Needs you", notch "needs".
- ALSO FIXED (found by the smoke): app.js reconnect overwrote newer workspace/chat pushes with an older list (a project added during a runtime restart vanished) -> `pushed` counters. This was the "flaky" smoke step "show the project in the sidebar".
- NOT tested for real: whether real Claude Code (-p mode) offers AskUserQuestion to the model, and whether a real Codex/Antigravity chooses ask_user. Voice mode reading questions aloud and the phone app: not built. Another smoke flake seen once: `.vtone` (voice settings) not yet present.

## 6. Facts learned (verified 2026-11-17; re-check before relying on them)

- Firecrawl: keyless free tier for scrape/search/parse (rate-limited); free plan 1,000 credits a month, no card; OAuth URL `https://mcp.firecrawl.dev/v2/mcp-oauth`; self-hosting is AGPL-3.0.
- TinyFish: Search and Fetch are free per the vendor; Agent and Browser are metered; MCP needs a key (Bearer) or browser sign-in.
- Hostinger: its email-marketing product (Reach) has **no MCP server**. A Hostinger Mail MCP exists (mailbox read/send, paid Business Email plan, URL and OAuth connector from hPanel). Mailbox limits: 1,000 sent a day (Starter), 3,000 (Premium), 100 on free/trial. Their Mail API says it is for product and workflow email, not bulk. Their cold-email policy was not checked.
- Zoho: Zoho Mail external sending is 50 to 500 an hour, dynamic. Zoho's community says Zoho Mail is not for cold emailing. Zoho Campaigns blocks accounts that use purchased or harvested addresses. Zoho MCP (Mail, Campaigns with 80+ tools) uses a per-user server URL plus an OAuth approval that Opscode cannot show yet.
- Inbox providers: Gmail and Yahoo treat 5,000+ a day as bulk and need SPF, DKIM, DMARC, one-click unsubscribe and a spam rate under 0.3% (Google asks for under 0.1%).
- Legal: LinkedIn sued Proxycurl in 2025 and Proxycurl shut down, so no LinkedIn scraping. Reddit commercial use needs a written agreement. Do not scrape Google Maps (use OpenStreetMap or the official Places API). CASL (Canada, the best market in the data) is the strictest of the target countries.
- Open-source reuse list is in design section 7 (Crawl4AI, Crawlee, GLiNER, Splink, Graphiti, Reacher, etc.). Kuzu is archived: avoid.
- The first Explee run: Canada small businesses (logistics, restaurants, fitness) replied best.

## 7. PENDING work

Legend: **[ ]** not started. Each item lists the goal, what to build, and how to test it. Tests must follow the existing pattern: a new `scripts/test-phaseNN.mjs` (next number is 53), local fixture servers, mock providers, no real accounts, and a short list of what was not tested.

### 7.0 Decisions that block work (ask the person; section 8)
See section 8.

### 7.1 Lead module, in the planned order

**[ ] S0. Storage test and the storage interface** (do first; small)
- Goal: decide how the CRM is stored locally. Electron's Node 20.18.3 has no `node:sqlite`.
- Build: a throw-away spike for `better-sqlite3` (native; needs an Electron ABI 130 build, like `scripts/ensure-native.mjs` does for `node-pty`) and `sql.js` (WebAssembly). Measure: 100k rows insert and filtered queries, crash safety, loads in the packaged app (`npm run package`), and whether a Windows build is plausible. Then put a `Store` interface in front of `LeadStore` (adapters: `local`, later `postgres`), without changing behaviour.
- Test: all five lead suites unchanged and passing on the interface; spike results written into design section 5.
- Output: record the choice in the design doc and memory.

**[ ] Slice 4. Discovery scouts and the Resolver**
- Goal: from "restaurants in Saskatoon" to a list of candidate companies, without one site at a time.
- Build: a source router with jobs (`companies.search`, `companies.enrich`, `people.search`, `email.find`, `signals.fetch`, `web.search`, `web.fetch`, `exclude.list`) as in design 8d, choosing user choice first, then free sources, then cheapest paid; paid calls show a credit estimate and need approval. Scouts: OpenStreetMap (Overpass and Nominatim, polite, cached, correct User-Agent), web search through a configured MCP (Firecrawl or TinyFish), careers/job signals. Wire the TinyFish and Firecrawl connectors in as `web.search` and `web.fetch` sources. Resolver: merge duplicate companies and people by domain, phone, registry id, and proven account links.
- Test: fixture servers for OSM-like data and a mock search MCP; duplicates merge; placeholder and suppressed domains are skipped; a paid call without approval is refused; router order is correct; idempotent reruns.

**[ ] Slice 5. Need Analyst, Scorer and Lead records (and the first UI)**
- Goal: turn organizations and signals into scored leads with reasons.
- Build: persist `Lead` (person, organization, need, offering, scores, reasons as observation ids, rubric result). Need Analyst: open or solved needs, freshness, buying stage, interests. Scorer using the formula in design section 4 (fit, intent, power, reach, recency). Call Lead LAB to judge and store the verdict on the lead. RPC `leads.lead.*`. UI: the "why this lead" view with quotes and links.
- Test: scoring math with hand-computed cases, time decay moves scores, every reason points to a real observation, the rubric result is saved, a stale need lowers the score, a forgotten person's lead disappears.

**[ ] Slice 5b. Marketing page, onboarding flow, research step** (design 8b and 8c)
- Goal: one sentence in, a campaign brief out.
- Build: a Marketing page in the sidebar; step 1 input box; research agent (reads their site and Project docs, picks the industry pack, finds competitors and their customers, proposes 2 to 4 audiences with one evidence quote each, fills every campaign field); audience cards; 10-lead review with thumbs; launch.
- Test: a mock model returns a research plan; fields are all filled; competitor domains go to the exclusion list; the thumbs change scorer weights; the UI works in the smoke test (screenshots).

**[ ] Real-model gold run** (needs the person's decision, section 8)
- Run `leads.lab.gold` against a real model. Look at disagreements, fix prompts or wrong gold labels, save the report. Then also run the scout's model step on a few real sites.

**[ ] Slice 6. People and email**
- Goal: find a decision-maker and a usable address.
- Build: people and company data through user-chosen connectors (Apollo MCP at `https://mcp.apollo.io/mcp`, Hunter at `https://mcp.hunter.io/mcp`, or any custom MCP with the job-mapping step from design 8d); site-published contacts; email pattern guessing and checks (format, MX); full SMTP verification only through a verifier because home networks block port 25. Add `email_status` (valid, catch-all, invalid) to the model. Suppression checked everywhere.
- Test: mock vendor MCP; pattern and MX checks against a local DNS stub; cost estimate shown and approval required; suppressed people and domains never returned.

**[ ] Slice 7a. Mail engine: mailbox pool and sender, with the email writer and review gate**
- Goal: send safely (rules in section 6 and design 8e).
- Build: mailboxes over SMTP (any provider) in a pool: per-mailbox daily cap and warm-up ramp (about 5, 10, 20, 30 a day), separate sending domains, per-domain cap, one mailbox per lead thread, Message-ID saved for each email, random pacing inside the lead's local business hours (the per-country schedule in `docs/explee-teardown.md`), auto-pause on bounce rate over about 3% or provider errors, unsubscribe list and header (a `mailto:` List-Unsubscribe, because a desktop app has no public URL for the one-click POST: say this clearly), real sender name and address in the footer (CASL, CAN-SPAM). The writer: one short email per lead from the need evidence, every claim must cite an observation, lead's language, brief from the Offering and "Reply facts". A review gate before launch.
- Library choice to decide: `nodemailer` and `imapflow` (both MIT) as dependencies.
- Test: a local fake SMTP server; caps and warm-up respected; spread over time; a suppressed address is never sent; auto-pause triggers; a claim without evidence is refused; the schedule respects local hours and the "no burst after wake" rule.

**[ ] Slice 7b. Reply sync, matching and the mini CRM**
- Goal: know which emails got replies, and show them (design 8e and the CRM mockup).
- Build: IMAP sync per mailbox (UID bookmark, UIDVALIDITY handling, Sent folder too), matching by Message-ID and In-Reply-To with a fallback on sender address, bounce (DSN) parsing, classes (interested, not interested, question, out of office, bounce, unsubscribe), **sync before send**, a "While you were away" summary on reopen. Mini CRM in a local store: contacts, companies, deals with stages, activities (sent, reply with its class), tasks (next follow-up), custom fields, tags, editable stages, CSV import and export. Screens: Leads table with filters, Pipeline, lead page with timeline, Inbox.
- Test: a fake IMAP server with replies, out-of-office, a bounce and an unsubscribe; matching is correct; a reply that arrives while the app is closed stops the follow-up; stage changes; CSV round trip; the screens in the smoke test.

**[ ] Slice 7c (optional). Push to the user's own CRM, and the always-on runner**
- Push one way (keyed by lead id, option "interested only") to HubSpot, Zoho CRM, Pipedrive or a webhook. The always-on runner is the same runtime on a VPS, Pi or Mac mini with token auth and TLS; this is where Postgres is a good default.
- Test: a mock CRM endpoint receives each lead once (idempotent); a runner started on another port serves the same RPC with auth.

**[ ] Slice 8. Campaign pipeline in Chief and the daily re-scan**
- A "campaign" pipeline for Chief (research, audience, discover, extract, resolve, score, judge, gate, write, send) following `src/runtime/chief/pipeline.ts`, and an automation (`src/runtime/automations`) that rescans for fresh signals daily with a budget.
- Test: stage order and gates, budget stops, a daily run finds a new signal and re-scores.

**[ ] Slice 9. More signal sources**
- Reddit and X through licensed APIs only (Reddit commercial use needs an agreement), reviews, public tenders, news. No LinkedIn scraping, no Google Maps scraping.
- Test: mock APIs; terms and keys required before enabling; account links need proof.

**[ ] Slice 10. WhatsApp**
- WhatsApp Business Cloud API only, template messages, only to people who opted in or replied by email. Never cold blast scraped numbers.
- Test: a mock Cloud API; a message to a number without opt-in is refused.

### 7.2 Cross-cutting items (not numbered slices)
- **[x] OAuth sign-in for remote MCP servers**: built 2026-11-17, see 5.6. Still open: a real sign-in against a real service (needs the person's browser login), Zoho/Hostinger/TinyFish (not tested with real accounts), "use this computer's GitHub login" (not built; GitHub's MCP server has no dynamic registration, so GitHub still takes a token).
- **[ ] Real hand-labelled gold set**: replace the 22 hand-written gold cases with about 100 real leads labelled by the person (a labelling screen or a JSON file).
- **[ ] 50 real sites measurement** for the website scout (precision of needs and signals, time, failures).
- **[ ] Real tests of the new connectors** once the person has accounts: TinyFish key, Zoho MCP URL, Hostinger Mail URL.
- **[ ] Compliance pack**: CASL, CAN-SPAM, GDPR notes per country, retention limit, one-click delete across all tables (the store already has `forgetPerson`), legitimate-interest note per campaign.
- **[ ] `definition` labels** exist only from the model step; decide whether to add a cheap non-model labeller.
- **[ ] Update `schema.sql`** to a portable form (SQLite and Postgres) once S0 decides.

### 7.3 Opscode app track (older, not the lead module)
- **[ ] Quality fixes Slices C to E** (B done 2026-11-20, see 5.13) (`docs/quality-fix-plan.md`): B question card (options + Other box, task waits), C live mini plan in the chat, D finish-the-whole-task rule + Codex auto-continue, E check before "done". C/D/E change what models are told: written plan + the person's yes first.
- **[ ] Chief plan slice 5**: the software-agency template (brief to plan to Claude builds, Codex does UI and assets, tests and review to a draft PR; reuse components from linked GitHub repos). `gh` is not installed; PRs and private clones need `gh` or a token.
- Known gaps listed earlier: git and GitHub plugin marketplaces, per-project plugin scope, importing old chats, parallel sub-agents, PR creation, live screen stream, HTML artifact preview, and the effort picker (listed as not built in the build memory).
- Windows installer exists but was never run on real Windows; log at `%APPDATA%\Opscode\logs\opscode.log`.
- `docs/templates-plan.md` has a "decisions for you" section that was not re-checked.

## 8. Decisions the person still owes (ask these first)

1. **Real model route** for the real gold run (the question was asked and not answered): (a) run the judge through the logged-in `claude` program with the small Haiku model and no tools (needs a small CLI judge added to Lead LAB; uses their plan quota; about 85 short questions), (b) they add an Anthropic or OpenAI-compatible key in Opscode Settings, Models and keys, or (c) skip for now.
2. **Storage test first?** Run the SQLite spike (S0), or keep the JSONL files and put the CRM on them for now.
3. **Mailboxes:** how many sending domains and mailboxes they can buy, and which provider hosts them (Hostinger, Zoho, Google Workspace, Microsoft 365 or a dedicated cold-email mailbox provider). Cold outreach from Zoho is against its policy; Hostinger's policy was not verified.
4. **People and email data vendor** for slice 6 (Apollo, Hunter, Prospeo and others, or site-published contacts only).
5. **First industry** to prove quality: suggested restaurants or logistics in Canada (best replies in the Explee data).
6. **Library choice** for mail: `nodemailer` and `imapflow`.
7. **Browser/Chrome and CASL**: confirm the sender identity (real name and a postal address) for email footers.

## 9. Where we stopped

- 2026-11-20 (later): Slice B (question cards, section 5.13) built and tested; NOT installed yet (needs the person to quit Opscode). A real Claude test of AskUserQuestion needs the person's OK. Next: plan Slice C (live mini plan).
- 2026-11-20: audited the person's real chats (`docs/quality-fix-plan.md`), built Slice A (section 5.12) and INSTALLED it to /Applications (smoke --app on the installed build: PASS). Disk was 99% full (2.1 GB free): the person must free space. Next: plan Slice B (question card) in detail, build after "Start slice B".

- 2026-11-18: Accessibility AND Screen Recording confirmed Granted by the person (screenshot); log shows opscode=true helper=true osascript=true. Added: every Mac step is logged ("computer: <source> start|end ok|FAILED app=… step=… error=…" in opscode.log; computer.act end carries error). To see what a live test did: grep "computer:" ~/Library/Application Support/Opscode/logs/opscode.log, and look at <state>/runtime/hands/voice-<session>.json (the helper's last look). The first REAL run of see/click/type on a real app is the person's live voice test (never run by me: this shell has no Accessibility). This logging build is queued to install when the person next quits Opscode.
- 2026-11-18: Accessibility showed Granted after the fix (the person confirmed with a screenshot). Screen Recording now has the same: opscode-hands check returns "screen" (CGPreflightScreenCaptureAccess, no prompt), ask-screen (CGRequestScreenCaptureAccess); Settings shows a status pill + Allow… (askAccess("screen"): tccutil reset ScreenCapture com.opscode.app, then the macOS prompt + opens the Screen Recording page); the page re-checks every 2 s while either permission is missing; log line now also reports screen recording. Screen Recording is only needed for computer_screenshot.
- 2026-11-18 (Accessibility shown "Not granted" although Opscode is ON in the list): measured on the installed build (second instance via `open -n -a Opscode --args --user-data-dir=<scratch>`, log line "accessibility: …"): opscode=false helper=false osascript=false, so macOS does NOT apply the person's grant to the current build — a stale TCC row from an older build's signature (macOS keeps the row ON but the stored requirement no longer matches). Changes: helper now installed at Contents/MacOS/opscode-hands signed with --identifier com.opscode.app (same designated requirement as the app; package-mac.mjs); handsBin() prefers that path; Settings/voice/chats use ONE check (the helper), osascript only as fallback; startup log line "accessibility: opscode=… helper(direct)=… helper(runtime)=… osascript=… helperPath=…" (notch.ts diagnoseAccess, RPC computer.diagnose); Allow… (computer.request_access / askAccess in index.ts) now, when Accessibility is NOT working, runs `tccutil reset Accessibility com.opscode.app` (the person's own click) then the macOS prompt + opens the Accessibility page, creating a fresh row that matches. I never run tccutil myself (security setting). To check after the person tries: read ~/Library/Application Support/Opscode/logs/opscode.log for the "accessibility:" line.
- 2026-11-18: STABLE SIGNING set up (the person said yes): self-signed code-signing certificate "Opscode Local Signing" (O = Opscode (this Mac only), 10 years, SHA-256 42:DD:A6:F3…A9:80) imported into the login keychain (codesign allowed; private key never kept on disk; shows as CSSMERR_TP_NOT_TRUSTED, which is fine for signing). scripts/package-mac.mjs signs with it when present (OPSCODE_SIGN_IDENTITY overrides, "-" = ad hoc): designated requirement is now identifier "com.opscode.app" and certificate root = H"ef12bee7…", so macOS keeps Accessibility / Screen Recording / Microphone across reinstalls. After the first install with it, the person grants Accessibility once more (new identity). The other identity in the keychain ("Apple Distribution: Nikhil Patel") is not ours and is not used.
- 2026-11-18 (after the person tried voice "open Chrome"): fixes — instant commands ignore speech filler ("You... Open Chrome.", "uh, hey Opscode, open Chrome please"); opening/quitting/switching apps works without the Computer use switch and without Accessibility (person's own command); voice always has computer_open + computer_apps, and computer_setup (after a spoken yes: switch on + macOS Accessibility prompt) until clicking is set up; prompt section "THE MAC (opening only)". Settings → Computer use: "Allow…" uses macOS's own prompt (opscode-hands ask-access → AXIsProcessTrustedWithOptions) + RPC computer.request_access; the page re-checks every 2 s; texts updated (only risky steps ask). FOUND: the app is ad-hoc signed (designated requirement = cdhash), so every reinstall makes macOS forget the Accessibility grant; fix needs a stable self-signed code-signing certificate in the login keychain (asked the person, not done).
- 2026-11-18: computer use slice 3 (section 5.11) built, tested with stand-ins, installed to /Applications. Next: install after the person quits Opscode, then slice 4 (cheap model + step-up + budget test) after "Start slice 4".
- 2026-11-18: computer use slice 2 (section 5.10) built and tested with the stand-in helper. Next: slice 3 (voice agent + notch "On my Mac" + live steps) after "Start slice 3".
- 2026-11-18: computer use slice 1 (opscode-hands, section 5.9) built; live checks skipped (no Accessibility for the test process). Next: slice 2 after the person says "Start slice 2".
- 2026-11-18 (fixes after the person tried it): (1) notch mic: any second press stops (slow presses used to be ignored), a stop pressed while voice.start is still pending is queued in main, and the button frees itself after 4 s if the recognizer never answers; (2) voice-mode model chips showed "…": the picks event was sent before main knew the session, now voiceagent.start returns picks and main buffers early events; (3) first sentences silent: the voice (Pocket TTS worker) now loads when voice mode starts (TtsService.warm(true)) and stays loaded until it ends (release()), and the notch opens its speaker on the Talk press. Tests: phase57 48, phase56 59; mic toggle checked in the browser preview.
- 2026-11-18 (later): voice mode model chips in the notch: "Talks with" (the voice agent: saved as voice_brain_* settings; switches from its next reply in a fresh hidden chat with a recap) and "New workers" (runtime `voiceagent.pick`, kept in notch.json, passed to voiceagent.start). Native macOS menu built from engines.list + provider.list (each found engine's models, API key, effort). API-key chats always use the key's own model (pick drops a model for api). Tests: phase57 45, phase56 59. Not tried on the real screen (the native menu) yet.
- 2026-11-18: voice mode in the notch across projects (section 5.8) built and tested with fakes; not installed. Next: install after the person quits Opscode, then a real spoken test.
- 2026-11-17 (latest): the notch (section 5.7) was built and tested (53 checks + one real Electron launch). Next: the person tries it (`npm run build` then quit the installed Opscode and `npm run install-app`, or run from source with `OPSCODE_PROFILE=/tmp/x npx electron .`), then fix what they see. Ideas not built: Agent Notch-style plan-usage page in the notch, Claude Code/Codex hook bridge for sessions outside Opscode, fullscreen detection to mute sounds, a Settings page section for the notch.
- 2026-11-17 (later): section 5.6 was built (OAuth sign-in for MCP servers, new Plugins page, skill install asks where). It is not installed to /Applications yet and the source smoke was not re-run after the smoke steps were updated; run `npm run smoke` (or `OPSCODE_SMOKE_FOCUS=...`) and `npm run install-app` after the person quits Opscode.
- All of section 5 is built and tested; nothing is committed.
- The last thing done was updating the design doc: storage is local first with Postgres optional, the mini CRM and the laptop-off plan are in section 8e, and slice 7 is split into 7a, 7b and 7c.
- The person asked for this hand-off file. The next real step is to ask them the decisions in section 8, then start with S0 or Slice 4 depending on the answers.
- Recommended order: S0, then Slice 4, then Slice 5, then the real-model gold run (before any email is sent), then 5b, 6, 7a, 7b, then 7c, 8, 9, 10, with OAuth any time.

## 10. Test playbook (follow it for every new slice)

1. Plan first; wait for "Start slice N".
2. Write code and a `scripts/test-phaseNN.mjs` using `scripts/lib/harness.mjs` (`reporter`, `startRuntime`, `session`). Use local fixture servers and mock providers. Existing fakes: `fake-claude.mjs`, `fake-codex.mjs`, `fake-chrome.mjs` (headless Chrome stand-in), `mock-mcp.mjs`, a mock Anthropic SSE server pattern (see `test-phase51.mjs`). Test hooks use environment variables such as `OPSCODE_LEADS_TEST_MAP`.
3. Test the failure paths and the hostile inputs, not only the happy path (injection in page text, private addresses, suppressed people, missing keys, broken judges).
4. Register the suite in `package.json` (`test:runtime` chain), run `npm run typecheck`, rerun related suites, and run `npm test` in the background at the end of a slice.
5. After a real-world check (real sites, real vendor), say exactly what was real and what was mocked.
6. Update this file (sections 5, 7, 9), the design doc, and the memory notes.

## 11. Gotchas (from this and earlier sessions)

- `tsc` emits to `dist/`; tests import `dist/...`, so compile before running a suite.
- Opscode's runtime runs on Electron's Node 20.18.3: no `node:sqlite`; some npm install scripts are blocked in this environment (see `scripts/ensure-native.mjs`).
- A quote in an Observation is checked against the stored document text: store the text you will quote (the scout writes a `#markup` document for JSON-LD and script sources).
- Lead facts must never exist without evidence; do not loosen the store rules to make a test easier.
- Do not trust page text: it can contain instructions to a model (see `scout/llm.ts` `INJECTION`).
- Do not touch `tts/`, `voice/` or `engines/` without a test (from the build memory).
- The assistant's own session may have extra tools (Firecrawl, browser). Opscode itself only has what is in its MCP catalog and settings.
- Never put a person's key or personal data in a URL or a request to an outside service without asking.
