# Chief, Automations, Plugins and sidebar: what Caveman does and how Opscode builds it

Date: 2026-11-15. Source: a read-only look at `/Applications/Caveman Code.app` (client chunks `Chief-*.js`, `actions-*.js`, `NewChat-*.js`; runtime `session-protocol-*.mjs`, `src-CJLpHYmu.mjs`, `triggers-*.mjs`, and `runtime/automations-plugin/skills/automations/SKILL.md`). Nothing in Caveman was changed.

## 1. What Caveman's pieces are

### Chief (the most important piece for you)
- Chief is **one chat that coordinates and never does the work itself**. Its system prompt says it never reads code, runs commands or browses. Instead it **starts chats** (worker agents), **steers** them, **answers** their questions, and **keeps a board**.
- **Board:** each piece of work is an *item* with a state: queued, running, needs you, ready for review, ready to merge, done, failed. The right side of the Chief screen shows the board as a list or as columns.
- **Tools it has:**
  - Work: `chat_start` (brief + projects + tier fast/frontier), `chat_send` (steer now, or queue for later), `chat_stop`, `chat_answer`, `chat_digest`, `chat_search`.
  - Board: `queue_add`, `queue_update`, `queue_order`, `queue_drop`.
  - Asking you and memory: `ask` (one question with its recommended answer), `remember`, `memory_sql`.
- **Rules it follows:**
  - **Chats per project:** one chat per repository. A change across repositories becomes a *change set* with a shared contract and a merge order. Parts that touch the same files are stacked, never run side by side.
  - **Briefs:** 300–800 tokens, with labelled lines (Goal, Done when, Projects, Start at, Decided, Don't touch). Your words are quoted exactly.
  - **Workstreams around a build chat:**
    - **Review** chat: one adversarial reviewer per pull request.
    - **Benchmark** chat: for hot paths.
    - **Alternatives:** two build chats with different approaches; you pick one.
    - **Monitors:** scheduled checks.
    - **Next:** queues the follow-up.
  - **Talking to you:** only when something is yours to act on. One line: the finding, why it matters, where it is.
  - **Always yours:** approvals, merges, pushes to protected branches, secrets, anything that spends money or deletes.
- **Settings:**
  - **Soul:** standing instructions and crew rules.
  - **Autonomy:** how much it does without asking.
  - **Permissions:** what the chats it starts may do.
  - **Scope and model:** which projects it covers, and its own model.
  - Several Chiefs can exist, each with a name.

### Automations
- An automation is a **YAML file** in the repository, `.caveman/automations/<name>.yaml`, or a personal one in `.caveman/local/`. **Agents** are markdown files in `.caveman/agents/<name>.md`.
- **Triggers:** schedule (time + weekdays, interval, cron, once), GitHub events, by hand with inputs. Cloud-only triggers (Slack, Linear, Jira, webhooks) are out of scope.
- **Steps:** each step is an `agent`, an inline `prompt`, a `run:` command (no model) or a `wait:`. How steps relate:
  - `needs:` turns the file into a graph; up to 4 ready steps run side by side.
  - `if: { triage: implement }` branches on an earlier agent's `decides` value.
  - `checks:` are commands (`pnpm test`) and/or a reviewer agent. The first failure fails the attempt.
  - `retries`, plus `escalate` up a ladder such as `[{model: frontier}, {engine: codex, model: frontier}]`.
  - `parallel: 2–4` attempts with `pick: first | best`.
  - `approve: { by: owner }` makes the run wait for a person.
  - `outcome: { rubric }`: a separate grader scores the work and sends it back.
- **Saving tokens:**
  - Each step picks an **engine** (`claude-agent` = Claude Code, `codex`, …) and a **model class**: `fast` / `base` / `frontier`.
  - Every automation has a **budget** (`$`, tokens, turns).
- **Outputs:** a draft pull request, or one GitHub comment.
- **UI:**
  - An Automations page with a list on the left and the last run on the right.
  - A "New automation" box: title, what to do, project, schedule, engine, permissions, Me/Project, and **Build with agent** (a chat writes the YAML with the automations skill) or **Use template**.
  - An Agents tab next to it.

### Engines (how Caveman uses Claude Code and Codex)
- **Claude Code** runs through `@anthropic-ai/claude-agent-sdk`, which drives the installed `claude` program, so it uses **your Claude login**.
- **Codex** runs as `codex app-server` (JSON-RPC over stdio), so it uses **your ChatGPT login**.
- On this Mac:
  - `claude` 2.1.325 is at `~/.local/bin/claude`.
  - `codex` 0.169 is at `/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex` (it supports `codex exec --json`).

### Sidebar and Plugins page (from your screenshots)
- **Sidebar, top to bottom:**
  - **New chat** (full width), **Review**, **Plugins**, **Automations**.
  - **Chiefs** (with +): each Chief has its own picture.
  - **Projects:** a **Queue** button and ⋯; each project has its chats nested under it, with an indent line.
  - Footer: plan, You, settings gear.
- **Plugins page:**
  - Header: search ("Search plugins, MCP servers and skills"), a source filter, a scope filter ("Everywhere"), and +.
  - **Tabs with counts:** Catalog, Installed, MCP servers, Skills, Rules.
  - A "needs sign-in or a key" warning line.
  - **Sections:** Featured (a 4-column grid of connectors with +), Installed (toggles, "Show all"), MCP servers (toggles, "From Claude Code / Codex", "Needs sign-in").

## 2. Your goal, in these terms

> Give a brief (for example: multi-vendor grocery app, Zepto/Zomato-level UI, loyalty points, auctions), plus a requirements `.md` and the UI you want. Then a team of agents builds it:
> - **Claude Code** is the lead developer.
> - **Codex** takes UI, assets and small tasks, so Claude's tokens are not wasted.
> - It **reuses components from your live grocery/meat e-commerce repo on GitHub**, cloning it and wrapping it, instead of building from zero.
> - You can change the automation from the chat box, and the agent can change it too.

That is a **Chief + automation templates + two engines**:
- **Chief:** you talk to it.
- **"Software agency" automation:**
  - brief → `requirements.md` → plan
  - → build chats (Claude Code, `base`)
  - → UI/asset chats (Codex)
  - → checks (tests, build)
  - → reviewer (Claude, `frontier`, once)
  - → draft PR
- **"Component reuse":** a project setting listing your existing repos. The planner tells each build chat which components to take from them.
- **Marketing automations** use the same engine: scheduled steps that write content, check it, and wait for your approval.

## 3. Build plan (one slice at a time, each tested like before)

| # | Slice | What you get |
|---|---|---|
| 1 | **Engines** | Claude Code and Codex as chat engines next to API keys. Model picker: engine → model → effort (real flags). Approvals map to each engine's permission mode. Token use is shown per chat. |
| 2 | **Sidebar + Plugins page** | Caveman's layout: New chat, Review, Plugins, Automations, Chiefs, Projects with nested chats and Queue; Plugins as a full page with search, tabs and counts, Installed / MCP servers / Skills / Rules sections. |
| 3 | **Automations** | `.opscode/automations/*.yaml` + `.opscode/agents/*.md`; steps, needs, if/decides, checks, retries/escalate, engine + model class per step, budget, approve. Scheduler (this Mac). Runs page. "New automation" box, Build with agent, templates. |
| 4 | **Chief** | Orchestrator chat with a board (queued / running / needs you / review / done), chat_start / steer / stop / ask / remember tools, Soul, Autonomy, permissions, crew rules (which engine does what). |
| 5 | **Software-agency template** | Brief + requirements.md → plan → Claude builds, Codex does UI/assets, tests + review → draft PR. Reuses components from linked GitHub repos. A marketing template on the same engine. |

Order: 1 first, because 3–5 all need Claude Code and Codex as workers.

### What I will not copy
Caveman's mascot pictures, pixel font, name and Cloud/billing features. The layout, structure and wording style are matched. Featured connectors will be real MCP servers you can actually add, not a decorative list.

### Things to know
- **GitHub CLI:** `gh` is not installed, and pull requests and cloning private repos need it (or a token).
- **Featured connectors:** many (Linear, Notion, Sentry…) need OAuth sign-in, which Opscode's MCP client does not do yet. That would be its own small slice.
