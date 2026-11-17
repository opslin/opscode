# Working on Opscode

A short checklist for yourself (and anyone who joins).

## Before you commit

1. `npm run typecheck`
2. `npm test` (the whole suite; it builds first). For a UI change also `npm run smoke`; for voice mode only: `OPSCODE_SMOKE_FOCUS=voice node scripts/smoke.mjs` (about 30 seconds).
3. If you changed a system prompt: `npm run build && npm run prompts:export`, and commit `docs/prompts/` with the change.
4. If you added a test file, add it to the `test:runtime` script in `package.json` (always `ls scripts/test-phase*` first so you do not reuse a number).

## Branches and commits

- One branch per change, short name (`voice-windows-mic`, `fix-approval-card`). Merge to `main` when the checks above pass.
- Commit messages: a short summary line, then what and why in a few sentences.
- Never commit `node_modules`, `dist`, `out`, installers, API keys or anything from your own state folder; `.gitignore` already covers them.

## Core parts: change with care

These run on every machine and carry the most risk; change them only with a test:

- `src/runtime/tts/` (Pocket TTS) and `src/runtime/voice/`, `src/runtime/voice.ts`, `native/opscode-voice/` (speech input)
- `src/runtime/engines/` (the adapters for Claude Code, Codex, Antigravity, Qoder)
- `src/runtime/proc.ts` (starting programs, Windows shims)

## Releases

`npm run install-app` (macOS) and `npm run package:win` build the apps. Bump `version` in `package.json` first. Real-device checks that tests cannot do (real microphone, real Windows) go in `testing/reports/`.

## Local-only folders

`research/` (notes about another app, ignored by Git) and `testing/runs/` (raw results of real-model tests) stay on your computer.
