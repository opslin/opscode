# Your Claude Code and Codex usage (16 Oct – 15 Nov 2026)

Read from the session logs on this Mac (`~/.claude/projects` and `~/.codex/sessions`). Nothing was sent anywhere.

"Usage value" below is what the same tokens would cost at API list prices. It's a way to compare models and habits, **not** what you pay: your plans are Claude Pro and ChatGPT Team.

## Claude Code

| | Last 7 days | Last 30 days |
|---|---|---|
| Model calls | 4,399 | 25,928 |
| Sessions | 22 | 99 |
| Days active | 7 of 7 | 30 of 30 |
| Usage value | ~$492 | ~$2,004 |
| Output written | 4.3M tokens | 22.9M tokens |
| Average context per call | ~443k tokens | ~434k tokens |

**Models (30 days, share of usage):**

| Model | Calls | Share |
|---|---|---|
| Sonnet 5.5 | 23,406 | **79%** |
| Opus 5.5 | 1,936 | 15% |
| Fable 5.2 | 157 | 4% |
| Sonnet 5 / Opus 4.8 / Opus 5 | 405 | 1% |
| Haiku 5.5 | 24 | ~0% |

**Projects (30 days, most used first):** Project_opslin, opslin-api, dealker X shotlin, dealker-app, opscode, opslin-agent, ShotlinCRM.

**When you work:** every day, from about 7 AM to 1 AM IST. The busiest hours are 11 AM–9 PM, peaking around 2 PM.

**How you work:**
- Long sessions: a typical session makes about 116 model calls, and the longest made 3,152.
- Sub-agents are almost never used (about 1% of usage).

### Where the usage goes

| Part | Share |
|---|---|
| **Re-reading the conversation** (cache reads) | **60%** |
| Saving the conversation to cache (cache writes) | 27% |
| Writing answers and code (output) | 13% |
| New input | ~0% |

- **81%** of calls carry more than 200k tokens of conversation.
- **37%** carry more than 500k.
- Every new message re-reads all of it, so long sessions are the main cost driver, far more than the choice between Opus and Sonnet.

**What would have saved the most:** short chats (under ~150k tokens) with a hand-off note between them would have cut **about 40%** of last month's usage. This is the "fresh chat for every task" rule in the plan.

## Codex

| | Last 7 days | Last 30 days |
|---|---|---|
| Sessions | 344 | 353 |
| Main model | GPT-6.1-Terra (216 sessions) | GPT-6.1-Terra |
| Also | GPT-6-Astra, auto-review, GPT-6.1-Sol | |
| Input tokens | 231M (95% cached) | 402M (96% cached) |
| Output tokens | 0.35M | 0.69M |

- **Projects:** Project_opslin, Lndry X Shotlin, personal-assistant, ShotPETPUJA.
- **Limits:**
  - **Weekly:** peaked at 69% and is 55% now. There is room to give Codex more work.
  - **5-hour window:** fills in bursts (96% on 12 Nov, 82% on 10 Nov).

## What this means for the modes

- **Sonnet 5.5 medium as the workhorse** matches how you already work. Keep Opus for plans, complex functions and GODMODE reviews, as you set.
- **Haiku is a free win:** it's barely used today, and chores like search, summaries, test runs and logs belong there.
- **The biggest saving is not the model, it's chat length:** fresh chat per task, plus a hand-off before 150k.
- **Codex has room for UI, images and tests;** spread its work so the 5-hour window doesn't spike.
- **Right now** (checked today): Claude 5-hour session 32% used, weekly 45% used. Codex 5-hour 1% used, weekly 55% used.
