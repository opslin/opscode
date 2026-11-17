# System prompts

Every system prompt Opscode sends to a model, in one place, as readable files. They are **generated from the code** (`npm run prompts:export`), so they are always the real text, and a change to a prompt shows up as a normal diff in a pull request or in GitHub Desktop.

**To change a prompt:** edit the source file named at the top of its page, run `npm run build && npm run prompts:export`, and commit both. `node scripts/export-prompts.mjs --check` fails when these pages are out of date.

| Page | What it is | Source |
|---|---|---|
| [voice-agent.md](voice-agent.md) | The model you talk to in voice mode, and its tools | `src/runtime/voiceagent/` |
| [manager.md](manager.md) | The Manager (Chief) and its souls | `src/runtime/chief/prompt.ts`, `store.ts` |
| [modes.md](modes.md) | GODMODE / WARLORD / SHINOBI | `src/runtime/chief/modes.ts` |
| [workers.md](workers.md) | Rules and skills for worker chats | `src/runtime/chief/pack.ts`, `skills.ts` |
| [agent.md](agent.md) | The built-in agent (API models) | `src/runtime/agent/agent.ts` |
| [notes-and-skills.md](notes-and-skills.md) | Notes given to every engine; built-in skills | several (see page) |

Also prompts, but built on the fly and not rendered here (they depend on the situation): the hand-off pack between engines (`src/runtime/handoff.ts`), automation step prompts (`src/runtime/automations/runner.ts`), sub-agent prompts (`src/runtime/agent/agent.ts`), and the Manager's hand-over text (`src/runtime/chief/manager.ts`). A written guide to prompt style: [../prompt-playbook.md](../prompt-playbook.md).
