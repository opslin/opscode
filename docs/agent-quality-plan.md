# Better code, fewer tokens: plan (2026-11-20)

Based on: your real Opscode chats (Nov 16-19), your Mac's setup, the two Cactus pages you sent, and what developers report on Reddit, Hacker News and in OpenAI's and Anthropic's own guides. Nothing here is built yet. Each phase is built only after your "Start phase N".

---

## 1. Why Codex gives worse code than Claude for you (the real reasons)

| Reason | Evidence on your Mac | Fix |
|---|---|---|
| **Codex does not see your project rules.** Claude Code reads `CLAUDE.md`; Codex reads only `AGENTS.md`. | `dealker-app/CLAUDE.md` (55 lines: real API only, check every UI change on screen, no EMI, brand "Dealkr", do not re-architect) and `dealker-vendor-app/CLAUDE.md`. There is no `AGENTS.md` anywhere in Dealker. | Phase 1: one "project brain" every engine gets. |
| **Codex does not see Claude's memory.** Claude loads its memory index for the Dealker folder each session. | 31 notes, 67 KB in `~/.claude/projects/...dealker.../memory/`: server recipes, flows, your rules ("never upload to server", "use the real API", "no EMI"). Codex only found them when it happened to `cat` a file. | Phase 1: give Codex the index (titles + paths), not the whole 67 KB. |
| **Codex gets the wrong skills.** | `~/.codex/skills` lists about 40 Godot/game skills (state machine, gdscript, shaders...) in every Dealker chat. That is noise and tokens, and it pushes the model the wrong way. | Phase 1: per-project skill filter. |
| **Codex was locked in a sandbox.** | "DNS failed", "Docker denied", Gradle stalled. | **Fixed in Slice A** (installed). |
| **Codex stops early and reports.** | Plan stuck at 0 of 4 even after "proceed without clarification". | Slice D (planned): finish-the-job rule + auto-continue. |

Developers agree on this on Reddit, and OpenAI's own Codex guide says many "quality problems are actually environment-setup problems". Both models are about equal on public coding tests (about 190 of 303 tasks each in one 2026 comparison). The difference you see comes mostly from **what each one is given**, not from the model itself.

**How to use both (what experienced developers do):** one engine writes and the other reviews the diff. Claude is better at guessing what you mean and at UI. Codex is better at following a long, exact spec without drifting. Opscode already hands a task from one engine to the other, so a "review by the other engine" step is cheap to add (Phase 1).

---

## 2. Where your tokens go (measured)

- Every step re-sends the whole conversation. So **cost ≈ number of steps × context size**.
  - Codex, "Customer requests and returns flow": context 142k, **9.1 million** cached tokens re-read.
  - Claude, "deploy updated code": context 161k, **7.7 million** re-read.
- **Reading files is the biggest part of what fills the context:** about 258k tokens came back from `cat`/`sed`/`rg` in these chats, against only 15k from builds and tests.
- Agents read whole files to find one function, and they re-read the same files.

The four things that cut this (each is proven by others):
1. **A map instead of whole files.** A code index (Tree-sitter) answers "where is X, who calls it, what is in this file" in a few hundred tokens. Reported savings are 50-65% on real repos (Reddit r/ClaudeCode, AutoScout24 engineering blog).
2. **Short command output.** Only errors and the summary of a build or test come back; the full log goes to a file. One `AGENTS.md` rule like this cut Codex tokens by about 50% in one report.
3. **A small rules file** loaded every turn (under about 500 tokens), with details in files the agent opens only when needed.
4. **A smaller context.** Start a fresh chat with Opscode's hand-off pack when a chat passes about 80k tokens. Opscode already does this for voice workers; do it for all chats.

---

## 3. Reading Markdown, PDF and other documents

Today an agent `cat`s a whole PDF or Markdown file (or a 200-page export), which is slow and costly.

**Plan: a document reader inside Opscode** (one tool for every engine):
- Convert the file once (PDF, DOCX, XLSX, MD) to text, and remember it by its content hash, so it is never converted twice.
- The first answer is **only an outline**: headings or page numbers, the size of each part, and the tables found.
- The agent then asks for **only the part it needs** ("section 3.2", "pages 14-16", "rows where status = failed").
- Images inside documents are described locally by Mirage (see section 4) instead of being sent to Claude as pictures.

Expected effect: a 40-page PDF costs about 1-3k tokens to use instead of 30-60k.

---

## 4. The two small Cactus models: what they can and cannot do

Read from cactuscompute.com:
- **Needle 3:** 29-121M parameters, 8-29 MB. It does tool picking, structured extraction (messy text → typed fields) and text embeddings. It runs on a Mac CPU at thousands of tokens a second, free and offline.
- **Mirage:** 22 MB vision model. It describes a screenshot, finds objects, reads text (Latin script only) and answers multiple-choice questions about an image, in about 0.1 s.

**They cannot write or review code.** They are too small for that. Their value is doing the cheap jobs, so the big model's tokens go only to the hard work:

| Job in Opscode | Today | With a small local model |
|---|---|---|
| Find the 3 memory notes / skills / docs that matter for this message | All notes or a long list go into every turn | Needle embeddings rank them; only the top few go in |
| Pick which tools a turn needs | Every tool description is sent every turn | Needle picks the tool groups; fewer tool definitions are sent |
| Turn your voice-typed message into a clean brief (goal, apps, constraints) | A big model rewrites it, or nobody does | Needle extraction gives a first draft; the big model only checks it |
| "Is the app showing a black screen? Did the login popup appear?" | Screenshot sent to Claude (expensive) | Mirage answers locally; the big model looks only when something is wrong |
| Read text from a screenshot or a scanned PDF page | Image sent to the big model | Mirage OCR locally |

Honest limits: these models are new and English-first; your messages mix languages; Mirage reads Latin script only. **We test them on your real messages and screenshots before relying on them** (Phase 3 starts with a measurement, not a build).

---

## 5. Where Rust helps (and where it does not)

Rust does not cut tokens by itself; **what we send** cuts tokens. Rust makes the local helper fast and small enough to run on every turn, even in big repos:
- **Code index** (Tree-sitter has native Rust bindings): parse Dealker's 4 repos in seconds and update only changed files.
- **Search and ranking** (the ripgrep libraries): faster than starting `rg` many times from Node.
- **Document conversion** (PDF/DOCX → text, cached).
- **Output filter** (compress build and test logs as they stream).
- One small binary, like your Swift helpers, with no Python install.

Plan: build the first version in Node/TypeScript inside the runtime (fast to ship, easy to test). Move to a Rust helper (`opscode-index`) only if measurement shows it is slow on Dealker. The Cactus engine also ships a C library, so it could live inside the same helper later.

---

## 6. Top problems developers report with coding agents, and our fix for each

| # | Problem (Reddit, Hacker News, vendor guides) | What we do | Where |
|---|---|---|---|
| 1 | Says "done" without checking; fake or skipped tests | Check before done: builds, the app opens, screenshot; "not tested" said plainly | Slice E |
| 2 | Stops early, asks too often, ends the turn with a question | Question card (done), finish-the-job rule, auto-continue | Slices B (done), D |
| 3 | Forgets project rules as the chat grows | One project brain for every engine; short rules file; fresh chat with a hand-off pack at about 80k | Phase 1, Phase 2 |
| 4 | Burns tokens re-reading files | Code map tool, document reader, output filter | Phase 2 |
| 5 | Invents APIs, fields, versions (hallucination) | Rules point to the real source (route files, `API_REFERENCE.md`, real API); code map shows real names | Phase 1, Phase 2 |
| 6 | Touches unrelated files, rewrites instead of reusing | "Reuse first" in the brain; a diff-size check that warns on big unrelated changes | Phase 1 |
| 7 | Loops on the same failing fix | Opscode spots the same error 3 times and stops: other engine reviews, or asks you with options | Phase 2 |
| 8 | Misses parts of a long message | Mini plan with every point you wrote, ticked at the end | Slice C |
| 9 | Too many permission prompts | Risk rules + Antigravity fix | Slice A (done) |
| 10 | Turns die mid-task (crash, restart, disk) | Background-job fix, disk guard | Slice A (done) |

---

## 7. The phased plan

**Phase 1: same knowledge for every engine** (largest quality win; small).
- Opscode builds a short "project brain" from what exists: the `CLAUDE.md` files, Claude's memory index (titles + paths), the Opscode project skills, and your pinned notes.
  - Claude keeps reading its own files as today.
  - Codex, Antigravity and Qoder get the same brain in their instructions, under about 800 tokens; long notes stay as files they open.
- Per-project skill filter, so Godot skills don't show in Dealker chats.
- Optional `AGENTS.md` that points to `CLAUDE.md`, so Codex outside Opscode also sees the rules. This writes a file into your repos, so I'll ask first.
- "Review by the other engine" button and auto step: Claude writes → Codex reviews the diff (or the reverse).

**Phase 2: token cuts** (measured before and after on the same tasks).
- Output filter for builds and tests.
- Code map tool (Tree-sitter outline, find symbol, who calls it), in Node first.
- Document reader (outline first, then only the needed sections; cached).
- Fresh chat with a hand-off at about 80k context for all chats, not only voice.
- Small jobs (titles, summaries, commit messages, checkpoints) go to a cheap model (Haiku), not Opus or Sonnet.

**Phase 3: small local models** (Needle and Mirage, with measurement first).
- Measure Needle on 50 of your real messages (routing, extraction) and Mirage on 30 of your real app screenshots. Use them only where they are right at least 90% of the time.

**Phase 4: Rust helper** (only if Phase 2 measurements show Node is slow).

**Slices C, D and E** (already planned) run alongside Phase 1, because they fix stopping early and saying "done" too soon.

---

## 8. What we will measure (so we know it worked)

On 5 fixed tasks from your Dealker work, run before and after each phase with Claude and with Codex:
- tokens per task (input, cached, output) and cost
- steps per task
- did it finish without you having to repeat yourself (yes/no)
- did the result build and open (yes/no)
- did it break a project rule (yes/no)

The goal is fewer tokens with the same or better results. Any change that does not help on these numbers is removed.

---

## Phase 1 in detail: the same knowledge for every engine

### What exists today (checked 2026-11-20)
| Source | Size | Claude sees it | Codex / Antigravity / Qoder see it |
|---|---|---|---|
| `dealker-app/CLAUDE.md` (rules) | 6.4 KB | Yes, when it works in that folder | **No** |
| `dealker-vendor-app/CLAUDE.md` | 1.6 KB | Yes, when it works in that folder | **No** |
| Claude's Dealker memory index (`MEMORY.md`, 31 lines) | 4.7 KB | Yes, every session | **No** |
| The 31 memory notes themselves | 67 KB | Opens them when needed | Only if it happens to `cat` one |
| Opscode pinned note "Dealker project setup" | ~1 KB | Yes | Yes (already sent) |
| Opscode project skills (dealker-project, dealker-ui, ...) | list | Yes | Yes (already sent) |
| `~/.codex/skills` (about 40 Godot/game skills) | list | No | **Codex: yes, in every chat (noise)** |

What each engine reads by itself:
- Codex reads `AGENTS.md`, and can read `CLAUDE.md` as a fallback (a setting).
- Antigravity reads `AGENTS.md` and `GEMINI.md`.
- Qoder reads `AGENTS.md`.
- None of them reads Claude's memory.

**Found while checking:** `dealker-app/CLAUDE.md` says "No git repo here, do not git init". Each Dealker app is a git repo now (Shotlin/...). The rules file is out of date, and every engine that reads it gets a wrong rule.

### Step 1: the project brain (Opscode builds it; no files written in your repos)
A new runtime part (`src/runtime/brain.ts`) builds, per project:
1. **Rules:** every `CLAUDE.md`, `AGENTS.md` and `GEMINI.md` in the project folder and one level down (the 4 apps). A rule that appears in several files is kept once ("real API only", "no EMI", "INR from the server").
2. **Memory list:** Claude's memory index for this folder. Each line becomes title + one-line summary + full path, so the engine opens a note only when the task needs it.
3. **Pinned notes and skills:** as today.

Size budget: about 2,000-2,500 tokens. The engines cache this part (it is the same every turn), so it costs about one tenth after the first turn. If the rules files grow past the budget, the brain keeps the "Hard rules" sections in full and gives the rest as "open this file" with the headings.

### Step 2: give it to each engine
| Engine | How |
|---|---|
| Codex | In its developer instructions when a chat starts. When the brain changes mid-chat, the change goes into the thread as one short developer note (the same way hand-offs are sent today). |
| Antigravity, Qoder | At the top of the first message of the session (as the other notes are today). Changes go in front of the next message. |
| Built-in API agent | In its system prompt. |
| Claude Code | Nothing new: it already reads `CLAUDE.md` and its memory. It gets only the parts it does not read itself (rules files in sibling folders it has not opened yet). |

Opscode remembers which version of the brain each chat got, so it never sends the same thing twice.

### Step 3: a "What every engine knows" page
A section on the project page:
- Each source (file, note, skill), its size in tokens, and an Open button.
- The total size of the brain.
- Warnings for rules that look out of date or that disagree, for example "No git repo" while `git` finds a repo. These are only shown to you; nothing is changed without you.

### Step 4: skills that belong to another project
Codex can only turn a skill on or off for every project at once, not per project. Options:
- **(a) Recommended:** move the Godot/game skills from `~/.codex/skills` into the game project's own skills folder. Codex then shows them only in that project. Before I move anything, I'll confirm which folder Codex reads per project and show you the list; nothing moves without your yes.
- **(b)** Leave them, and tell Codex in the brain to ignore game skills here. Weak: they still cost tokens.

### Step 5 (optional, your choice): small `AGENTS.md` pointer files
One short file in each app: "Read CLAUDE.md in this folder first." Then Codex, Antigravity and Qoder also know the rules when you use them **outside** Opscode. This writes into your repos, so it is off unless you say yes.

### Step 6: review by the other engine
- A **"Review with Codex"** / **"Review with Claude"** button on a finished reply that changed files.
- The other engine gets, read-only: your goal, the project brain, the changed files' diff and the test results. It checks real bugs, broken project rules, missing parts of your request and unsafe changes.
- Its findings come back as a list card with **"Fix these"**, which sends them to the first engine.
- Settings has an "Auto-review big changes" switch, off by default, because each review is one extra turn.

### What the models are told (needs your yes; a prompt change)
- The brain itself.
- One line before it: "These are the project's rules and notes (the same for every engine). Follow the rules. Open a listed note only when your task needs it."

### How it is checked
- New `scripts/test-phase64.mjs`:
  - The brain builder: finds the rule files and the memory index, including the path with a space ("dealker X shotlin"); keeps the size budget; works with missing files; does not repeat a shared rule.
  - Codex, Antigravity and the API agent get the brain; Claude does not get it twice.
  - A changed rules file reaches a running Codex chat once.
  - The review button sends the diff and returns a findings card.
- Full `npm test` and smoke, then install after you quit Opscode.
- **Real check (uses your Codex account; I'll ask first):** in a Dealker chat, before and after, ask Codex three questions:
  - "What is the brand name?"
  - "Which API do you test against?"
  - "Can you upload the APK to the server?"

  Then run one small real Dealker task with Codex and compare tokens, steps and rule breaks.

### Not in Phase 1
Picking notes automatically with the small Needle model (Phase 3), and the code map and document reader (Phase 2).
