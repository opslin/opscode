# Prompt playbook: what Caveman Code does, and how Opscode uses it

Source: read-only analysis of `/Applications/Caveman Code.app` (runtime bundles and the bundled skill files). The app was not modified. Everything below is a description in our own words. No Caveman text is copied into Opscode.

## 1. Where Caveman keeps its prompts

| Prompt | Where | Size | Job |
|---|---|---|---|
| **Chief** | `session-protocol-*.mjs` | ~7,000 chars | The coordinator that never codes. Triage of notes, starting chats, reviews, speaking rules |
| **Builder note** | same file | 2 sentences | Added to a worker: commit your work, your last answer goes back to the lead |
| **Setup chat** | same file | ~1,800 chars | A narrow helper: change one file only, 5 tries, stop and say what only the person can fix |
| **Chief voice** | same file | short | The Chief on a voice call: only the 2–3 things that matter |
| **Reviewer** | `lib-*.mjs` | ~2,000 chars | An independent, adversarial check of finished work, with a fixed verdict format |
| **Acceptance-check writer** | `lib-*.mjs` | ~2,000 chars | Writes one program that tests the task's stated requirements and prints PASS/FAIL lines |
| **Requirement extractor** | `lib-*.mjs` | short | Quotes each requirement word for word, or answers NONE |
| **Agent identity, verify, finish** | `lib-*.mjs` | 3 sentences | The base prompt of a coding agent: finish fully, find out how it is checked, run that check |
| **Harness nudges** | `lib-*.mjs` | ~15 short messages | Reminders injected at one moment each (see 2.10) |
| **Skills** | bundled `SKILL.md` files | 8–15 lines each | `grill`, `automations`, and about 40 plugin skills (fix-failing-ci, review-pull-request, reproduce-ui-bug…) |

The Claude Code and Codex prompts themselves are the vendors' own. Caveman does not rewrite them.

## 2. The patterns worth keeping

1. **The coordinator never works.** It does not read code, run commands or browse. It starts chats, steers them and keeps a board. What must last goes on the board or in memory, because its own conversation gets summarised.
2. **A short "always the person's" list.** Never approve a permission prompt, merge, push to a protected branch, spend money, delete, publish, or reach outside the repo. No autonomy level lifts this list.
3. **Every note gets exactly one of six actions:** answer it, queue it, start work, send it to an existing chat, remember it, or ask one question. A note about an existing chat is never a new chat (search first).
4. **One chat per repository.** A change across repositories is a *change set*: one chat per repo, a shared contract, and a merge order. Inside one repo, split only into parts that touch different files; parts that share files are stacked, never parallel.
5. **A fixed brief:** 300–800 tokens, labelled lines (Goal, Done when, Projects, Start at, Decided, Don't touch), the person's request quoted word for word, written for someone who saw none of the conversation.
6. **Limits are the runtime's business.** If a start is refused, say so in one line and move on. Never retry to get around it.
7. **Extra chats only where they pay.** A reviewer only when a change alters behaviour. A benchmark only on a hot path. Two competing builders only when two approaches are both credible. One review round; a second only to check the serious fixes.
8. **Speak only when something is the person's.** Report the *finding*, not the state ("found the slow start: all adapters load before the window opens"), not "ready for review". A chat that is still working gets no message at all.
9. **Writing rules.** Answer first, one idea per sentence, no greeting or theatre, code and paths verbatim, full sentences only for warnings. Bad/good examples are included in the prompt, which teaches faster than rules.
10. **Reminders are injected at the right moment, not stuffed in the prompt.** The harness watches the work and sends one short message when it matters:
    - *evidence gate*: "nothing has run since your last change; run the check that proves the requirement, not a proxy like 'it compiles'";
    - *first green*: a first passing check is not proof of being done;
    - *finish audit*: list each requirement with the command and output that prove it;
    - *hedge*: if the summary says "could not verify", try again if it can be done here;
    - *time left*, *clean environment* (do not depend on packages you installed or stray scratch files).
    This costs nothing until it is needed, which suits our token goal.
11. **An independent reviewer** that did not do the work: do not trust the summary, exercise the deliverable the way the user or grader would, re-measure every number, judge only against what the task states (no style remarks, no invented requirements), cannot change the project, limited rounds, "if you cannot tell, count it as passing", and a fixed verdict format (requirement quoted, what fails, the command and output as evidence, at most N findings).
12. **Skills are short procedures:** a name, a description that says *use when…*, then 5–6 numbered steps. Good ones classify before acting (real failure, environment difference, or flake), say "go to the first error, not the last line", and "ask before you post anything".
13. **Narrow helpers have a budget and a stop rule:** change only one file, limited tries and minutes, and "if only the person can fix it, stop and say exactly what".
14. **Interview before building (grill):** a tree of decisions, ask everything that does not depend on an unanswered question in one round, with a recommended option each; facts are looked up, decisions are the person's; finish by writing a decisions file and stop.

## 3. What Opscode has now, and the gaps

| Pattern | Opscode today |
|---|---|
| 1, 2 | Done in the Chief prompt |
| 3 | Partly: no "exactly one of six" rule |
| 4 | **Missing: no change-set rule.** This is the dealker case (app, vendor app, dashboard, backend) |
| 5 | Partly (`pack.ts` adds rules and a map; no fixed brief template) |
| 6 | Done (the runtime enforces limits) |
| 7 | Review depth is in the mode table; no benchmark or alternatives rule |
| 8, 9 | Partly: no "speak only when it is the person's" rule, no good/bad examples |
| 10 | **Missing.** Workers can say "done" with no test run |
| 11 | **Missing.** The mode table names a review model but there is no reviewer prompt |
| 12 | **Missing.** No skills at all (see the skills answer) |
| 13, 14 | Missing |

## 4. Build order for Opscode

**Built 2026-11-15 (phase 22):** worker skills `fix` / `feature` / `chore` / review (`src/runtime/chief/skills.ts`, handed out by `kind` on chat_start, Conductors only), worker rules v2 (edit minimally, prove before done), the Conductor's job-size + change-set rules (in `modePrompt`), and the finish check: a fix/feature worker whose report has no Check line is sent back once by the runtime before the Chief hears. Plain Chief and Normal chat byte-unchanged (tested). Still open: Chief brief examples (P1 part), reviewer verdict adapter to the user's code-review skill levels, acceptance-check writer, grill.

| # | Piece | Modes |
|---|---|---|
| P1 | Chief prompt v2: note triage (patterns 3), change set (4), brief template (5), speak-only-when (8), good/bad examples (9) | all |
| P2 | Evidence gate and finish audit as injected nudges: when a worker's turn ends and files changed after the last test run, send one short message | SHINOBI: gate only. WARLORD: gate + audit. GODMODE: gate + audit + hedge |
| P3 | Reviewer prompt (11) with the fixed verdict format | WARLORD per milestone, GODMODE per feature, SHINOBI one light pass |
| P4 | Skill pack: `fix-bug`, `trace-flow`, `finish-check`, `review`, `ui-brief`, `ui-review`, `cheap-run` (12), in our own words, tested on the dealker sale problem | by job size |
| P5 | Acceptance-check writer (11): a script that checks the task's stated requirements | GODMODE |
| P6 | `grill` for new projects (14): an interview before the plan | New project only |

## 5. Licence

The licence file inside the app says the Caveman repository is Apache-2.0 from version 3.0.0 (the hosted Cloud service is separate). The `grill` skill is adapted from Matt Pocock's skills (MIT). Opscode writes its own wording, so nothing needs to be copied. If we ever copy text closely, we keep the notice and give credit. I have not checked whether every file in the app bundle is covered by that repository licence.

## 6. Leaked prompt collections: not copied

The `asgeirtj/system_prompts_leaks` repository describes itself as the "hidden system prompts" of many chatbots, taken out in full. Those are other companies' proprietary texts with no open licence, so Opscode does not copy or adapt them. I looked only at the file listing (Explore, Plan, general-purpose, fork, claude-code-guide, statusline-setup, web-fetch, shared-notes) and did not read or copy the bodies. The useful part, the techniques (read-only explorer, plan-without-editing, one-job helpers), is in Anthropic's public Claude Code docs and in the Caveman patterns above. We write our own text from those.

### Legitimate sources we use instead

| Source | Licence / status | Use for |
|---|---|---|
| Caveman Code's bundled prompts and skills (section 1) | Apache-2.0 repository | Coordinator, reviewer, finish-check patterns |
| Anthropic's published system prompts, `platform.claude.com/docs/en/release-notes/system-prompts` | Published by Anthropic | Writing style only. They are claude.ai chat prompts (tone, formatting, safety), so little of it applies to a coding agent |
| Claude Code docs (subagents, skills, hooks, memory) and Anthropic engineering posts | Public docs | How to define helpers and skills |
| Our own measurements on your repos | Ours | Deciding what stays |

From the published Opus 5.5 prompt, three style rules are worth keeping: give the reason next to each rule, show a few good and bad examples, and match answer length to the question (edits return only the changed part).

## 7. Skills: install, use, delete

Rule: a skill's description is loaded into every session that has it, so an unused skill costs tokens every time. Opscode keeps only a small permanent set and uses everything else on loan.

| Kind | Rule | Examples |
|---|---|---|
| **Permanent** (about 5) | Always on, short, ours | `fix-bug`, `finish-check`, `trace-flow`, `cheap-run`, `review` |
| **On loan** | Installed for one job or one project, then removed when the job ends | UI audit, Stripe, Playwright, Firebase rules, SEO, a framework's docs |
| **Template-owned** | Installed when a template starts, removed when it is closed | Lead finder, marketing, video skills |

**Where to find them:** the skills.sh directory and its CLI (`npx skills find <words>`, `add <owner/repo> --skill <name>`, `remove`, `list`; MIT; installs into `.agents/skills/<name>`, per project by default, `-g` for global). The directory shows install counts, which is a rough quality signal, not a security check.

**How Opscode does it:**
1. Find: search by task words; show name, source, install count, and size.
2. Vet before install: read the `SKILL.md` and any scripts, check licence, size (tokens) and what it asks to run. Show you a summary. Install only on your OK.
3. Install into the project only, never global, with a note of why and for which job.
4. Remove when the job or the chat ends (or ask "keep it?" once). The Usage page shows what each loaned skill cost.
5. Promote a skill to permanent only after it saved tokens or fixed things on your repos.
