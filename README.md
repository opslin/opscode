# Opscode

A desktop coding-agent app for macOS and Windows. One window where you talk or type to coding agents (Claude Code, Codex, Antigravity, Qoder, or any API model), keep several of them working at once, and talk to them by voice. Everything runs on your computer; nothing but the model traffic leaves it.

## What it does

- **Chat with any engine**: Claude Code, Codex, Antigravity, Qoder, or API keys (Anthropic and OpenAI-compatible), with accounts, limits and usage tracked per engine.
- **Modes and Managers**: GODMODE, WARLORD and SHINOBI Conductors, and plain Managers, that split work into short single-task worker chats instead of one ever-growing chat (this saves a lot of tokens).
- **Voice mode**: talk to a front agent that answers aloud, searches and reads the web in the Browser panel itself, briefs worker agents for coding, runs several workers at once, and takes spoken approvals ("yes, do it"). It shows workers as live cards and its browsing as a live mini screen.
- **Dictation and read aloud**: speech to text in the message box; replies read aloud with Pocket TTS.
- **The workspace**: files, terminals, a Browser panel the agents can drive, a Library of your existing apps, automations, plugins, MCP servers and skills, and a usage page.
- **Permission modes** from read-only to full access, with approval cards for anything risky.

## Platforms

| | macOS (Apple Silicon) | Windows 10/11 (x64) |
|---|---|---|
| App | yes | yes |
| Speech to text | Apple's on-device recognizer (macOS 26) | sherpa-onnx + Kroko model (downloaded once, 57 MB) |
| Read aloud | Pocket TTS (downloaded once, 98 MB) | same |
| Terminals | zsh | PowerShell |
| Computer use, iOS Simulator | yes | not available |

Windows support has been built and tested from a Mac only; see [docs/windows-plan.md](docs/windows-plan.md) for what is verified and what is not.

## Getting started

Requirements: Node.js 20 or newer, and Git. On macOS the voice helper is built with Xcode's command-line tools (`xcode-select --install`); without them everything works except Apple's speech input.

```bash
npm install
npm start          # build and open the app
npm test           # the whole automated test suite (runtime, protocol, engines, voice)
npm run smoke      # drives the real window headlessly (macOS)
npm run typecheck
```

Your chats and settings are kept outside the project: `~/Library/Application Support/Opscode` (macOS), `%APPDATA%\Opscode` (Windows). The app also writes `logs/opscode.log` there.

## Building the app

```bash
npm run install-app     # macOS: build Opscode.app and install it to /Applications
npm run package         # macOS: build ./out/Opscode.app only
npm run package:win     # Windows installer + portable zip, built from any computer (no Windows or Wine needed)
```

The Windows installer is not code-signed, so SmartScreen shows "Unknown publisher" the first time (More info, then Run anyway).

## Project layout

```
src/
  main/        Electron main process: window, secure app:// scheme, IPC, the in-app browser driver, permissions
  preload/     the small, typed bridge exposed to the window (bundled with esbuild)
  renderer/    the window: plain JavaScript modules, no framework (voice mode, chat, panels, settings, pages)
  islands/     React "islands" (assistant-ui) built into one bundle for chat messages, task cards, the dock
  runtime/     the local runtime (Node): everything that is not UI
    engines/     Claude Code, Codex, Antigravity/Qoder (ACP) adapters, accounts, limits
    agent/       the built-in agent for API models and its tools
    chief/       Managers and Conductors: board, modes, workers, pipeline
    voiceagent/  the voice-mode front agent, its tools and browser
    voice/       speech input for Windows/Linux (sherpa-onnx); voice.ts picks Apple's helper on a Mac
    tts/         Pocket TTS (read aloud and the agent's voice)
    devices/     browser control and the iOS Simulator
    ...          library, automations, plugins, MCP, usage, ledger, memory, skills
  shared/      protocol types and constants used by both sides
native/        macOS helpers in Swift / Objective-C (Apple speech, iOS Simulator touch)
scripts/       build and packaging scripts, the test suites (test-phaseNN.mjs) and their fakes (scripts/lib)
assets/        brand: logo, pixel mascots, engine marks; build/ holds icons and the installer config
docs/          plans, research, the written guides, and docs/prompts (the system prompts, generated)
testing/       the written reports of real-model test runs
```

## How it fits together

The window never touches the system directly. The main process starts the **runtime** as a child process and gives it a random loopback port and a one-time token over a private pipe; the window talks to the runtime over a WebSocket with JSON-RPC. The runtime owns chats, files (sandboxed to the project), terminals, engines and models, and pushes events back. Engines (Claude Code, Codex and the others) run as the person's own programs with their own sign-in; the Browser panel is driven through the app's own DevTools bridge. See [docs/orchestration-architecture.md](docs/orchestration-architecture.md) and [docs/history/build-log.md](docs/history/build-log.md).

## System prompts

All prompts live in the code and are rendered into readable pages in [docs/prompts](docs/prompts/README.md). Edit the source, then run `npm run build && npm run prompts:export` and commit both, so every prompt change is a visible diff. `npm run prompts:check` fails if the pages are out of date.

## Documentation

See [docs/README.md](docs/README.md) for the index. Start with [CONTRIBUTING.md](CONTRIBUTING.md) when you change something.

## Third-party material and license

Models, voices and logos used by Opscode, and their licenses, are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Some of them restrict commercial use; read it before distributing the app. The project itself has no license chosen yet (all rights reserved by default); `package.json` says `UNLICENSED`.
