# Quality fix plan (from the real-chat audit, 2026-11-20)

Source: all 18 chats in `~/Library/Application Support/Opscode/runtime/chats` (Nov 16-19), the ledger, and `logs/opscode.log`.
Five slices. Each is built only after "Start slice X". Nothing is built yet.

| Slice | What | Changes what models are told? |
|---|---|---|
| A | Bug fixes: stops, extra Allow cards, Codex sandbox, full disk | No |
| B | Question card (options + Other box, task waits) | Yes (small note) |
| C | Live mini plan in the chat + "split every point into steps" rule | Yes |
| D | "Finish the whole task" rule + Codex auto-continue | Yes |
| E | Check before "done" (APK opens, `.env` bundled, screen check) | Yes |

---

## Slice A: bug fixes (detailed)

### A1. Claude Code: stop the "Stream closed" failures

**Problem (9 times, the most common tool error):** in `src/runtime/engines/claude.ts`, when Claude Code sends its first `result`, Opscode closes Claude's input (`child.stdin.end()`). But if Claude started a background job (Monitor, a background build, a background helper), it keeps working after that `result`. Its next permission question then cannot be answered: "Tool permission request failed: AbortError: Stream closed". Claude says "my shell keeps failing" and stops. This hit the deploy check and the APK build on Nov 19.

**Fix:**
- Claude Code reports background jobs in its stream: `system/task_started` (job begins) and `system/task_notification` (job ends: completed, failed, killed). Checked in Claude Code 2.1.325.
- Opscode keeps a list of running job ids. On `result`: if the list is empty, close the input as today. If not, keep it open. Claude continues by itself when a job ends, and Opscode closes the input at the first `result` after the list is empty.
- Safety limits: the turn still stops at once when you press Stop. If no job reports back for 30 minutes, Opscode closes the input and says so in the chat.
- While it waits, the chat keeps showing "working", so it does not look finished.

**Test (fake Claude, no real account):** fake-claude gets a marker that starts a background job, sends `result`, then a permission request and a second `result`. Checks: the permission request is answered, the turn ends only after the second `result`, Stop still works, and a turn with no background job ends as before.

### A2. Antigravity: stop asking "Allow" for every command

**Problem:** Antigravity sends its command as `rawInput.CommandLine`. Opscode only reads `rawInput.command` (`src/runtime/engines/acp.ts`). With no command found, Auto mode asks for every command, even `ls` and `git status`. Seen in every Antigravity command card.

**Fix:** read the command from `command`, `CommandLine`, `commandLine` or `cmd` (text or list), in both places: the card and the permission decision. Then Auto judges Antigravity commands by the same risk rules as Claude and Codex (`engines/safety.ts`).
- Qoder: it sends the tool's own input (`command`), so it should already work. The test covers it too.

**Test (fake ACP agent):** a `CommandLine` command `ls -la` runs without asking in Auto; `git push` with `CommandLine` still asks; the card shows "Run ls -la"; Qoder-style `command` keeps working.

### A3. Codex: let it build, test and check servers like Claude

**Problem:** Opscode starts Codex in its locked sandbox (`workspace-write`, `src/runtime/engines/codex.ts`). That sandbox has no internet, no Docker and no local database. Codex then said "DNS failed", "Docker denied", "Gradle stalled", "could not create shared memory", and stopped. Claude has no such lock, which is a big part of why Claude finished more.

**Two ways to fix it (your choice):**
1. **Full access in Auto (recommended).** Codex runs commands like Claude does. Opscode keeps asking you before risky steps (deploy, push, delete, database writes, scp/ssh changes), using the same rules as Claude. This fixes internet, Docker and local databases.
2. **Internet only.** Keep the sandbox and turn its internet on. This fixes DNS, Gradle and curl. Docker and local databases stay blocked.

Either way: Read-only stays locked. Supervised stays as it is. The "Full access" mode becomes real full access (today it is still the locked sandbox).

**Test (fake Codex):** in Auto, the thread and the turn get the chosen sandbox; risky commands still ask; read-only is unchanged. `test-phase13.mjs` expectations are updated to match.

**Not tested without your OK:** a real Codex run uses your Codex account. I will ask before one real test (for example, Codex runs `curl` and `docker ps` in a scratch folder).

### A4. Full disk: no more crashes, and a warning

**Problem:** on Nov 19 at 10:32 the disk was full. Saving a chat failed (`ENOSPC`) inside a timer, and the error killed the runtime 4 times. Today the disk is still 99% full, with 2.1 GB free.

**Fix:**
- Chat saving (`src/runtime/chats.ts` `flush`) catches the error, keeps the chat in memory, and tries again every 10 seconds. The runtime no longer crashes.
- When a turn starts, and every 10 minutes while one runs, Opscode checks free space. Under 5 GB, the chat shows a short warning: "Your disk has only X GB free. Builds and saving may fail."
- Under 1 GB, it warns before the turn starts, and you can still go on.

**Test:** a test hook pretends the disk is full: the runtime stays up, the chat is saved once there is space again, and the warning shows.

**Your part:** free some space. Big Opscode folders: voice models (548 MB), read-aloud voices (335 MB), extra accounts (327 MB), and an old usage cache (38 MB). Flutter, Gradle and Android build caches outside Opscode are usually much bigger. I will not delete anything without your yes.

### What Slice A does NOT change
- Nothing in what the models are told (no prompt or token change).
- No question card, plan display or auto-continue yet (Slices B to D).

### How Slice A is checked
- New `scripts/test-phase62.mjs` for A1 to A4, plus updates to `test-phase13.mjs`.
- `npm run typecheck`, then the full `npm test` in the background, then `npm run smoke`.
- Afterwards, `npm run install-app`, but only after you quit Opscode with Cmd+Q.
- I will say exactly what was and was not tested.

---

Status: **Slice A built, tested and installed (2026-11-20).**

---

## Slice B: question card (detailed)

### The problem (from the real chats)
- Every question came as plain text at the end of a reply, so the task ended there. You had to type an answer, and the task restarted from a new message.
- Once you even pasted the agent's own question back as your answer ("Do you want me to deploy... I need a clear yes").
- Questions were long, mixed several decisions, and had no clear "what I recommend".

### What you will see
A card pops up **on top of the message box** while the work is paused:

```
┌──────────────────────────────────────────────────────────┐
│  Deploy                        Waiting for your answer   │
│  Deploy the backend to the live server now?              │
│                                                          │
│  (1) Yes, deploy now (Recommended)                       │
│      Copies the 3 changed files, restarts the API        │
│  (2) Not yet, test locally first                         │
│      Runs the local tests, deploys after your OK         │
│  (3) Other: [ type your own answer...             ]      │
│                                                          │
│  Question 1 of 2           [Skip]  [Back]  [Next →]      │
└──────────────────────────────────────────────────────────┘
```

- **1 to 4 questions in one card**, one at a time, with "1 of 2" and Back/Next. Each question has a short title chip.
- **2 to 4 options per question.** The recommended one is first and marked "Recommended". Each option has one short line saying what it means.
- **"Other" is always there**, with a text box, so you can type your own answer. Some questions can allow several picks (checkboxes).
- **Keys:** 1 to 4 picks an option, Enter goes to the next question or sends, Esc closes the card without answering (the card stays in the chat to answer later).
- **Skip:** the agent goes on with its own best judgment and tells you what it assumed.
- **The task does not end.** The agent waits, gets your answer, and continues in the same turn.
- If you type in the normal message box instead and press Send, that text is the answer.
- The sidebar shows the chat as "Needs you" (same as an Allow card), so you notice it when you are in another chat.
- After you answer, the card shrinks into the chat as a short line: "You chose: Yes, deploy now".

### How each engine asks
| Engine | How | Waits for you? |
|---|---|---|
| Claude Code | Its own built-in question tool (`AskUserQuestion`). Opscode shows it as the card and sends your answers back (checked in Claude Code 2.1.325: it takes `answers` from the app). | Yes |
| Codex | Opscode's new `ask_user` tool (through Opscode's tool connection, which Codex already uses for the browser). If Codex uses its own `request_user_input` instead, the same card shows it. | Yes |
| Antigravity, Qoder | Opscode's `ask_user` tool, through the same tool connection. | Yes |
| Built-in API agent | `ask_user` as a normal tool. | Yes |
| An agent that cannot use Opscode's tools | Backup: it ends its reply with a short "Questions" block in a fixed format. Opscode turns it into the same card, and your answer is sent as the next message. | No (the turn ends, but you still get buttons) |

### Where it does NOT ask
- **Manager workers and automations:** nobody is watching them, so `ask_user` answers at once with "Nobody can answer now: use your best judgment and say what you assumed". A Manager worker keeps reporting questions to its Manager, as today.
- **Permission questions** (run a command, deploy, delete) stay on the Allow cards. The question card is only for choices about the work.

### What the models are told (a prompt change, needs your yes)
About 90 words, added to every chat's notes, the same for all engines:

> When you need the user's decision, ask with the ask_user tool (in Claude Code: AskUserQuestion) instead of asking in your reply and stopping. Ask 1 to 4 questions at once, each with 2 to 4 short options; put the option you recommend first and add "(Recommended)" to its label; add one short line per option saying what it means. The user can always type their own answer, so do not add an "Other" option. After the answer, continue the work in the same turn. Do not ask what you can find out yourself, and do not ask for permission to run commands: Opscode asks for that.

Cost: about 120 tokens of notes, plus about 150 tokens for the `ask_user` tool description, per turn (Claude Code already carries its own tool).

### Build steps
1. **Runtime:** a new question type for cards (questions, options, multi-select, answers); a new RPC `turn.answer` (answers, "other" text, or skip); a question waits like an approval; Stop ends it.
2. **Claude Code:** catch `AskUserQuestion` in the permission handler, show the card, send back `answers` (a list for several picks); Skip → a polite "user skipped" answer.
3. **`ask_user` tool** for Codex, Antigravity, Qoder and the API agent (in the same tool set as the browser tools). Codex's own `request_user_input` goes to the same card.
4. **Backup parser** for agents without the tool connection: a "Questions:" block → card → answer sent as the next message.
5. **Screen:** the card above the message box (keys, Back/Next, Other box, Skip, Recommended mark), the short "You chose" line in the chat, "Needs you" in the sidebar and the notch.
6. **Workers and automations** get the "nobody can answer now" reply.
7. **The note** above (only after your yes).

### How it is checked
- New `scripts/test-phase63.mjs` with the fake engines: a fake Claude asks with `AskUserQuestion`, a fake Codex and a fake Antigravity ask with `ask_user`, and a fake Codex uses `request_user_input`. Checks:
  - the card's questions and options arrive
  - one answer, several answers, "Other" text, Skip, and Stop while waiting
  - the engine gets the answer and goes on in the same turn
  - workers and automations are answered at once
  - the backup parser works
- `npm run smoke` gets a new step: the card appears above the message box, an option is clicked, the answer is sent, and the card turns into "You chose".
- Full `npm test`, then install after you quit Opscode.
- **One real test** with your Claude Code login, asking a tiny question about a scratch folder (a few cents of your plan). I ask you before I run it.
- **Not covered:** voice mode (the voice agent reading the options aloud) and the phone app. These can come later.

---

Status: **Slice B built and tested (2026-11-20)**; not installed yet. See docs/HANDOFF.md 5.13.

---

## Slices C to E (outline, detailed later)

- **C: Live mini plan.** The plan the engine makes (Claude's to-do list, Codex's plan, Antigravity's plan) shows as a checklist under the latest message and ticks off as the work moves. Plus a rule: for a big message, first list every point you asked for as steps, and check them all at the end.
- **D: Finish the job.** A rule that the whole task is done in one go unless a real blocker or your decision is needed (asked with the card). If Codex ends while its plan still has open steps and it asked nothing, Opscode tells it to continue, at most 2 to 3 times.
- **E: Check before "done".** Release APKs must include `.env` and are checked to open (emulator or web build); UI changes get a screenshot. "Not tested" must be said plainly.
