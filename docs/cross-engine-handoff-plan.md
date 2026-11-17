# Cross-engine hand-off (Claude Code ⇄ Codex) — plan

Status: proposal, 2026-11-16. Nothing built yet.

## 1. The problem today

When a chat moves from one engine to another (`chats.ts` `setEngine`), Opscode deletes the engine session.
The new engine gets only the last about 8,000 characters of plain chat text (`priorContext` in `engines/claude.ts`):

- No plan, no decisions, no "why".
- No tool results: files read, commands run, test output, errors.
- No list of files already changed.
- The interrupted step is lost.
- Long chats lose everything except the last few messages.

The new engine then explores the repository again. That costs a lot of tokens and can lead to wrong guesses.

## 2. What the engines allow (checked on this Mac)

| | Claude Code 2.1.325 | Codex app-server 0.169.0-alpha.11.1 |
|---|---|---|
| Continue own session | `--resume <id>` (works with a new `--model`) | `thread/resume` |
| Copy a session | `--fork-session` | `thread/fork` |
| Put foreign history in | No public way. Its session file (`~/.claude/projects/*/<id>.jsonl`) is an internal format with ~18 record types, so writing one ourselves would be fragile. | **`thread/injectItems`**: "Raw Responses API items to append to the thread's model-visible history". Real history, not a pasted message. |
| Import another agent | — | `externalAgentConfig/detect` + `import` with item types `SESSIONS, SKILLS, MCP_SERVER_CONFIG, AGENTS_MD, MEMORY, …`. Codex has already imported Claude sessions on this Mac (`~/.codex/external_agent_session_imports.json`). It copies the whole session, so it is too expensive for a hand-off. |
| Goal + budget | — | `thread/goal/set {objective, tokenBudget}` |
| Shrink context | `/compact` (interactive) | `thread/compact/start` |
| Extra instructions | `--append-system-prompt` (cached) | `developerInstructions` |

So:

- **Claude → Codex** can be close to lossless: inject a chosen part of the history as real items.
- **Codex → Claude** has to be a written hand-off pack. That is fine if the pack is good.

## 3. Main idea: Opscode owns the task state, not the engine

Do not copy raw transcripts between engines. They are huge (average context is about 434k tokens) and in different formats.

Instead, Opscode keeps a small **task ledger** for each chat. Both engines read it and help update it. A switch then only needs the ledger plus a few recent messages: about 4–8k tokens instead of 100k+.

```
             ┌──────────── Opscode task ledger (per chat) ────────────┐
 events ───▶ │ goal · plan steps+status · decisions · user style/rules │ ◀── task_checkpoint tool
 (free)      │ files changed · last commands+results · open errors     │     (model, ~200 tokens)
             │ next step · in-flight call at stop                      │
             └───────────────┬─────────────────────────────┬───────────┘
                             ▼                             ▼
                   Hand-off pack → Codex          Hand-off pack → Claude
                   thread/injectItems             --append-system-prompt
                   + thread/goal/set              + first message "continue"
```

### 3.1 Ledger, filled at no model cost

Opscode already sees every tool start and end (`toolStart`/`toolEnd` in `turns.ts`), every approval and every result. From those events, with no model call:

- **Files changed**: paths + `git diff --stat` at hand-off time.
- **Commands**: the last 10, each with exit code and the last 20 lines of output when it failed.
- **Open errors**: the last failing test or build, still failing.
- **Files read**: paths only, so the new engine knows what is relevant.
- **User messages**: kept word for word. They carry the user's style and rules.
- **In-flight step**: the tool call that was running when the user pressed Stop.

This part works even when the engine ran out of tokens or hit its limit mid-turn. In that case the engine cannot be asked for anything, which is why the ledger must not depend on it.

### 3.2 Ledger, filled by the model (small)

A new `task_checkpoint` tool on the existing `/mcp/devices` server, available to both engines:

```
task_checkpoint({ plan?: [{step, status}], decisions?: [..], next?: "…", notes?: "…" })
```

A one-line rule in the system note: call it after making a plan, after finishing a plan step, and before stopping. Cost is about 150–300 tokens per call.

The plan itself is also written to a file (`.opscode/tasks/<chat>/plan.md`) when one exists. A file on disk is the best cross-engine context: both engines read files well.

### 3.3 Hand-off pack (built by Opscode, ≤ 8k tokens)

```
# Continuing a task (you are taking over from <engine/model>)
Goal: …
Plan: 1 ✔ … 2 ✔ … 3 ▶ … (in progress) 4 ☐ …
Decisions made (do not redo): …
User's rules and style: … (from memory notes + user's own words)
Changed so far (git diff --stat): …
Last commands: `npm test` → exit 1, failing: cart.test.ts "total" (last lines…)
Stopped during: Edit src/cart.ts (not finished, re-check this file)
Next step: …
Start by: `git status`, re-run the last failing check, then continue step 3.
```

Plus the last 3 user messages and the last assistant reply, word for word.

### 3.4 Delivery per engine

- **→ Codex**: `thread/start` (same `developerInstructions` as today), then `thread/injectItems` with:
  - one developer item containing the pack;
  - the recent user and assistant messages as real message items.

  Then `thread/goal/set {objective: goal}`, then the user's new message as a normal turn. Codex sees this as its own history.
- **→ Claude Code**: a new session. The pack goes in `--append-system-prompt` (cached, so later turns stay cheap). The first user message is the user's text, or "Continue the task."
- **→ built-in API agent**: the pack becomes a system note.

### 3.5 Keep each engine's session, do not delete it

Change `engine_session` into `engine_sessions: { "claude-code"?: id, codex?: id }`.

When a chat goes back to an engine it used before, Opscode resumes that session and sends only a short **delta**: "While you were away, Codex did: …", built from the ledger. Nothing is re-explained.

## 4. The switches you asked for

| Case | What Opscode does |
|---|---|
| Manual switch in the model chip (Claude ⇄ Codex) | Build the pack and deliver it as above. Show a small "Handed over · 5.2k tokens" card in the chat. |
| **Plan with Opus, build with Codex** | New chat option "Plan → Build". Opus plans (read-only mode), then writes `plan.md` + checkpoint. The user approves, Opscode switches the engine and Codex gets the plan file + pack. Pipelines already do this between stages; this brings it to normal chats. |
| **Claude hits its limit mid-task** | Opt-in setting "When an engine runs out, continue in the other one". On a `rate_limit_event` at 100% or a limit error, Opscode: (1) stops the turn, (2) builds the pack from the ledger with no model call, (3) switches to Codex, (4) continues automatically, (5) shows a notice. `route.ts` already reads limits; this reuses it for normal chats. |
| Going back later (Codex → Claude) | Resume Claude's old session + delta (3.5). |

## 5. Same skills, same configuration, same style on both engines

Mostly in place already. Gaps to close:

- **Skills**: both engines already get the same `SKILL.md` paths (`skillsNote`). Keep one source.
- **Memory notes / user rules**: both get them. They also go in the pack, so they survive a switch.
- **Project instructions**: Claude reads `CLAUDE.md`, Codex reads `AGENTS.md`. Opscode can check that both exist and say the same thing. If only one exists, offer to create the other as a one-line pointer ("See CLAUDE.md"). Never overwrite.
- **MCP tools**: Opscode's own tools (browser, simulator, skills, checkpoint) already reach both through `/mcp/devices`. A user's other MCP servers can be passed to Codex the same way (`config.mcp_servers`).
- **Style**: the pack carries the user's own words and rules. A different engine may still write a little differently; it should not change the plan or redo decisions.

## 6. Getting it right (no wrong work after a switch)

1. The first actions after a hand-off are fixed: `git status`, re-run the last failing check, re-open the file that was being edited. This checks the pack against the real state before any edit.
2. The pack says "decisions made, do not redo" and lists done steps. This stops the second engine from rewriting finished work.
3. If both engines are free, offer an optional review by the first engine at the end. The existing reviewer skill does this.
4. The pack never contains secrets. It reuses the attachment and library secret filters.

## 7. Token cost (estimates)

| Way to switch | Tokens the new engine reads first | Lost |
|---|---|---|
| Today (`priorContext`) | ~2k | almost everything |
| Codex importing the full Claude session | 100k–400k+ | nothing, but expensive |
| **Ledger pack** | **~4–8k** (+ a few files it re-opens) | raw tool output that is no longer useful |

Checkpoint calls add ~200 tokens per plan step. Ledger events are free.

## 8. Build order (each slice tested, like before)

- **H1. Ledger from events** (`runtime/ledger.ts`): files changed/read, commands + results, errors, in-flight call, user messages. Stored at `state/ledger/<chat>.json`. Tests with the fake engines.
- **H2. `task_checkpoint` tool + `plan.md`** on `/mcp/devices`, with a one-line rule in the system note for both engines.
- **H3. Pack builder + delivery**: Codex `thread/injectItems` + `thread/goal/set`; Claude via `--append-system-prompt`. Replaces `priorContext`. `engine_sessions` per engine, plus the delta when going back. Hand-off card in the chat. **Real test**: one task on Claude Sonnet, switch to Codex mid-way, compare with no switch.
- **H4. Auto-switch on limit** (opt-in) for normal chats, reusing `route.ts` limits.
- **H5. "Plan → Build"** chat option (Opus plans, Codex builds) with an approval gate.
- **H6. Config parity check**: `CLAUDE.md`/`AGENTS.md` pointer, user MCP servers to Codex.

## 8b. Built so far (2026-11-16)

- **H1 ledger**: `src/runtime/ledger.ts`, RPC `chat.ledger`, test-phase33.
- **H2 plan**: `task_checkpoint` (`src/runtime/checkpoint.ts`, kind "note", so it works in read-only planning chats) goes to all three engines, with one note line telling them when to use it. Opscode also captures:
  - Codex's own `turn/plan/updated`;
  - Claude's `TodoWrite`, when present;
  - a list in the reply, when the model planned in words only (it never replaces a saved plan).

  It writes `<project>/.opscode/tasks/<chat>/plan.md` (git-ignored, 0600). Test: test-phase34.
- **Real check**: Codex gpt-6-luna planned in a read-only chat, then the chat switched to Claude Haiku in full access.
  - Codex did **not** call `task_checkpoint` and sent no plan event. The reply-list fallback caught its 3-step plan.
  - Haiku built it correctly: `sum` + test, and `npm test` passed. It loaded the tool through ToolSearch, then checkpointed on its own: 3/3 done, decisions, notes.
  - Usage, Codex planning turn: ~16k input, 52k cached, 0.4k output.
  - Usage, Haiku build turn: ~22–45k input, 174–243k cached, ~2k output.

  Most of Claude's cost is its own start-up prompt. The hand-off text is small.

- **H3 hand-off** (`src/runtime/handoff.ts`, test-phase35):
  - **Codex's method name:** this Codex really calls it **`thread/inject_items`**. The schema's `thread/injectItems` is refused. A real probe gave the result back exactly: codeword, earlier user/assistant turn and decision.
  - **Detecting a switch:** at submit, the ledger's last finished turn was by another engine family (claude-code / codex / api). Echo never counts.
  - **`full`** (the engine has no session for this chat): the whole pack. Codex gets a new thread with a developer item (the pack without your messages) plus the last 6 messages as real user/assistant items, then your plain text. Claude gets a new session whose first message is the pack (with your messages and the other engine's last reply), then your text.
  - **`update`** (the engine comes back to its own session): `ChatMeta.engine_sessions` keeps each engine's session id across switches, and `setEngine` resumes it. The pack only carries what happened after that engine's last turn: your words to the other engine, files, commands, new decisions, the plan as it is now.
  - **Fallback:** if `inject_items` is refused, the full pack goes in front of the message.
  - **No more `priorContext`** when there is a pack.
  - **Pack size:** at most 24k characters (~6k tokens). It includes `git status --short` + `git diff --stat HEAD` when the project is a git repo.
  - **UI:** a "⇄ Took over from Codex · ~N tokens" pill on the reply (`turn.event` type `handoff`, also kept as `ChatMessage.handoff`).

- **H3 real run** (real engines, git project, 2026-11-16):

  | Case | Handed over | Result | Turn usage |
  |---|---|---|---|
  | A. Codex gpt-6-luna plans (read only) → Claude Haiku builds | full, ~335 tokens, in message | sum + test written, `npm test` passes, checkpointed twice | 22k in / 201k cached / 2k out |
  | B. Claude Haiku plans (read only, 2 decisions) → Codex builds | full, ~1k tokens, **inject** | subtract + tests, TypeError decision kept, tests pass | 19k in / 139k cached / 0.6k out |
  | C. back to Claude (own session resumed) | update, ~454 tokens | answered correctly what Codex changed and that tests passed, no tools | 2.5k in / 45k cached |

  Smoke step `05g-handoff` checks the "Took over from Claude Code · ~N tokens · as history" line in the real UI.

- **H4 auto-switch on limit** (`src/runtime/autoswitch.ts`, test-phase37):
  - **Setting:** off by default. Settings → Models & keys, on the Codex card: "When one runs out, continue in the other" (`engines.set { auto_switch }`).
  - **During a turn:** a turn fails with a plan-limit error. Recognised: Claude's "Claude AI usage limit reached" (plus `rate_limit_event` status rejected) and Codex's "You've hit your usage limit". The chat then moves to the other engine, using the model it last used there. Opscode sends the runtime line "Continue the task from where it stopped." with the H3 hand-off, and the pack says the other engine's last turn stopped early.
  - **Before a turn:** if the chat's engine has a fresh reading at 100% (or a "reached" flag), the person's message starts on the other engine. No failed turn first.
  - **Never:** with the setting off; for Chief/Conductor workers or automation chats (they have `route.ts`); to an engine that is missing or also at its limit; more than once per message.
  - **UI:** the pill reads "Claude Code hit its limit · continued in Codex · ~N tokens".
  - **Not tested:** a real limit hit. It cannot be triggered on purpose; only the fakes reproduce the real error texts.

### How context gets INTO Claude Code (Codex → Claude), checked

Claude Code 2.1.325 has no way to take in history from another engine. In `-p` stream-json mode it has no `TodoWrite`; Task tools are deferred behind ToolSearch. It accepts:

| Way | Verdict |
|---|---|
| Write our own session `.jsonl` + `--resume` | No: private format (~18 record types), breaks on updates |
| `--append-system-prompt` | For **stable** text only. Opscode starts Claude per turn, so a changing pack here breaks the prompt cache on every turn. |
| SessionStart hook via `--settings` (`additionalContext`) | Works, but adds nothing over the first message, and `--bare`/user settings can switch hooks off |
| **First user message of the new session** (`<handoff>` pack + the user's text) | **Use this.** It stays in Claude's own session, so later `--resume` turns keep it with no resend, and it is cached after the first turn. |
| `plan.md` on disk + its path in the pack | Also. Claude re-reads it when needed, and later checkpoints keep it current. |

So in H3, Codex → Claude = a new Claude session whose first message is the pack (ledger + `git diff --stat` + the plan.md path + the user's last messages) followed by the user's text. Claude → Codex = `thread/injectItems` (fallback: the same pack as the first message).

**"Graph" context (optional, H3+)**: the pack can add a small code map: `projectMap()` from `chief/pack.ts`, plus Library features (`library_search`) that match the changed files. This tells the next engine where things are without exploring. It is capped at ~1.5k tokens and only added when the Library has indexed the project.

## 9. Risks / not checked yet

- `thread/injectItems` is in the schema of this alpha Codex, but has not been called yet. H3 starts with a tiny real call to check that the injected items are really seen by the model. If it is not, fall back to a developer-instructions pack.
- Codex may drop or rename alpha methods in an update. Keep the fallback.
- Claude Code has no way to take in foreign history, so Codex → Claude always uses the pack.
