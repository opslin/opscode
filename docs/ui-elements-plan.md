# UI upgrade: assistant-ui elements for Opscode

Source: https://www.assistant-ui.com/elements (151 elements in 14 groups; MIT licence, repo assistant-ui/assistant-ui, 13.2k stars). Each element ships as source code (shadcn registry: `npx shadcn add @assistant-ui/elements-<name>`), built with React + Tailwind on shadcn tokens. Opscode already uses shadcn-style HSL tokens, so their look fits our theme directly.

## What users complain about in other agent apps (Reddit, reviews)

1. **The screen jumps while the agent works** ("everything jumps around"), and streaming steals the scroll position.
2. **Changes are hard to review**: people want a clear per-file diff they can keep or discard, not a wall of edits.
3. **Many agents, no overview**: "see what's running, what's blocked on you, and what's done at a glance; reply inline to unblock" (the most-upvoted ask; Claude Code's new agent view does exactly this).
4. **Two agents edit the same file**, or one redoes work another already did.
5. **Failures are hidden or noisy**: either silent, or a modal in your face with no retry.

Every pick below answers one of these.

## The picks (32 of 151), by Opscode screen

### A. Every chat (Normal and Conductor)

| Element | Why | Fixes |
|---|---|---|
| **Message pair** + **Message actions** | Clean bubbles, hover actions (copy, retry) that confirm themselves | look |
| **Streaming text** | New words land softly instead of popping | look |
| **Thinking indicator** | One live line: what it is doing now + elapsed time | 3 |
| **Run activity** + **Tool group** | Tool calls folded under one disclosure, the final answer always visible | 1 |
| **Tool timeline** | A finished run as verbs, targets and file stats ("Edited 4 files +38 −6") | 2 |
| **Terminal block** | Command output streaming line by line, ending in its exit status | 5 |
| **Code diff** / **Reviewable diff** | Tinted diffs in chat; each hunk keep / discard | 2 |
| **File tree** | Everything a run touched, with churn per file | 2, 4 |
| **Tool failure** + **Error state** | The error, attempt count, retry that doesn't restart the turn; quiet banner, no modal | 5 |
| **Stopped run** | Half-written answer stays; continue in one tap | 5 |
| **Scroll anchor** | Streaming never steals your scroll; a pill takes you back down | 1 |
| **Message queue** | What you typed while it worked, stacked and cancelable | 1 |
| **Markdown text** + **Shiki highlighter** + **Mermaid** | Proper rendering of answers, code, diagrams | look |

### B. The Conductor (multi-agent)

| Element | Why | Fixes |
|---|---|---|
| **Subagent list** | Parallel workers, each with model and progress (replaces my crew cards) | 3 |
| **Agent status** | One pill per worker: what it is doing, and for how long | 3 |
| **Task card** | A delegated task: state, timing, result and its transcript in one card | 3 |
| **Agent plan** / **Todo list** | The Conductor's checklist with glanceable progress | 3 |
| **Approval card** | Human in the loop before side effects (permission prompts, gates) | 3 |
| **Option list** / **Question flow** | The Conductor's questions as tappable answers that stay as a receipt | 3 |
| **Handoff** | "Fresh worker took over: why, and what came along" (our 150k hand-off) | 3 |
| **Background runs** | Work still going elsewhere, results waiting to be collected | 3 |
| **Job progress** | The pipeline as weighted stages with an ETA and a way out | 3 |
| **Speaker identity** | Who is talking when Claude, Codex and the Conductor share a thread | 3 |

### C. Images and assets

| Element | Why |
|---|---|
| **Image generation** | A dot grid holds the frame while the image resolves out of a blur (replaces my progress tile) |
| **Image gallery** | Compact grid with a shared lightbox (gate gallery, asset batches) |
| **Artifact card** | A generated document (spec.md, plan.md, brand.md) as an object, written live and versioned |

### D. Composer, limits, cost

| Element | Why |
|---|---|
| **Composer** + **Models** + **Context** | One input surface: attachments, model, a context ring that warns near the limit |
| **Attachments** | Drop the logo or a screenshot in; it becomes the Codex reference image |
| **Slash commands** + **Mentions** | `/fix`, `/feature`, `@WARLORD`, `@dealker-backend` |
| **Quota banner** + **Cost meter** | Plan left, reset time, spend per model (from our Usage data) |
| **Context breakdown** | Where the window went (pairs with the hand-off) |
| **Command palette** | Every action one keystroke away |

### E. Browser and preview

| Element | Why |
|---|---|
| **Web preview** | URL bar, reload, open-in-new around the dev server (dashboard testing in M4) |
| **Computer use** | The screen the agent drives, with a cursor trail (mobile/emulator tests later) |

### Not picked (and why)

Voice, maps, weather/ride/flight/shopping generative cards, math, research report, retrieval chunks, launcher bubble, mobile composer: not what Opscode does. Confidence markers and citations: later, for research tasks.

## How we build it (a decision for you)

Opscode's screens today are plain JavaScript (no React). The elements are React source. Two ways:

| | **1. Add React "islands" (recommended)** | 2. Re-draw them by hand in our current code |
|---|---|---|
| Quality | Their exact code, motion and accessibility | Close, but each one re-made by me |
| Speed | Faster: copy source, wire our data | Slower: 32 components by hand |
| Cost | One build step (esbuild + Tailwind) added; React only inside the chat, Conductor and Work panel | Nothing new to install |
| Risk | Two UI styles side by side while we move over | Drift from the polished originals |

With option 1 the elements read Opscode's data directly (props mode, no assistant-ui runtime or server needed): turn events, worker cards, pipeline, usage. Licence: MIT; we keep their notice in `THIRD_PARTY_NOTICES`.

## Status

**Step 1 done (2026-11-15):** React islands foundation. `src/islands/` (React 19 + Tailwind v4, built by `scripts/build-islands.mjs` into `dist/renderer/islands.js` + `islands.css`, part of `npm run build`; type-checked with `tsconfig.islands.json`). Elements are vendored with `node scripts/tools/aui-fetch.mjs <names>` (MIT notice in `src/islands/aui/NOTICE.md`). Opscode's tokens map onto shadcn names; dark mode follows `html[data-theme]`. Opscode's element resets moved into `@layer reset` so island classes win. First island: the Conductor dock (Approval card for gates with Image gallery and a feedback box; Agent status pills; Task cards with Tool timeline and Image generation resolving into the real image). Vendored so far: subagent-list, agent-status, task-card, approval-card, job-progress, image-generation, image-gallery, agent-handoff, thinking-indicator, tool-timeline (+ surfaces, range, href, receipt-focus, collapsible-root, shadcn dialog and button).

**Step 2 done (2026-11-16):** Conductor elements. Pipelines on the Work panel are assistant-ui Job progress (weighted stages: build 6, UI 3, plan 2, test 2, others 1; an estimate from the pace so far; stop with confirmation), with the stage chips and mode menus kept below. The dock shows a Subagent list when two or more workers are present, and an Agent handoff card for 5 minutes when a worker's chat passed its mode's limit (runtime now records `handoff: {at, tokens, limit, waiting}` on the old chat). Smoke checks all three in the real window.

**Step 3 done (2026-11-16):** every assistant reply (Normal and Conductor chats) is a React island (`src/islands/message.tsx`): the work folds into Run activity ("Worked 1m 14s · 4 steps", commentary and tools inside, the answer always visible); commands are Terminal blocks with exit status; edits are Code diffs (Claude's old/new and Codex's unified diffs); failures are Tool failure cards; other tools are Tool calls; a call that needs the person is an Approval card in view; a Thinking indicator shows while nothing new is visible; a File tree of what changed ends the reply; a stopped reply is a Stopped run (Continue); a failed one an Error state (Retry). Markdown stays Opscode's own safe renderer, mounted as nodes. Scroll anchor: new output never pulls you down while you read above (a "Latest" pill), only an approval does. Not done from the step-3 list: streaming-text fade, message queue (the Chief already queues notes).

## Build order

1. **Foundation**: React + Tailwind build, our tokens mapped, one island (the Conductor dock) as proof.
2. **Conductor**: Subagent list, Agent status, Task card, Approval card, Job progress, Image generation, Image gallery, Handoff.
3. **Chat**: Message pair, Streaming text, Thinking indicator, Run activity, Tool timeline, Terminal block, Code diff, File tree, Scroll anchor, Stopped run, Tool failure.
4. **Composer**: Composer, Attachments, Slash commands, Mentions, Context, Quota banner.
5. **Review and browser**: Reviewable diff, Web preview (with M4 testing).
