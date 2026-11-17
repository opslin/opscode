# Opscode for Windows (x64)

Built 2026-11-17 from a Mac, for the user's MSI Bravo 15 (8 GB RAM). `npm run package:win` (scripts/package-win.mjs) makes:
`out/win-installer/Opscode-Setup-<version>-x64.exe` (NSIS, per-user, no admin) and `out/Opscode-<version>-win-x64-portable.zip`.
Not code-signed: SmartScreen says "Unknown publisher" the first time (More info → Run anyway).

## What was done

- **Package**: Electron's Windows build (checksum-verified) renamed to Opscode.exe with the Opscode icon/version (resedit), app copied to resources/app, Mac-only pieces left out (Swift/ObjC helpers, darwin natives), Windows natives added: node-pty's win32-x64 prebuilds (ConPTY), `sherpa-onnx-win-x64`.
- **Speech (voice mode + the mic in the box)**: Apple's recognizer is Mac-only, so Windows uses `src/runtime/voice/` (a Node helper speaking the same JSON-lines protocol): the window captures the microphone (Chromium echo cancel / noise suppression, 16 kHz) and sends it (`voice.audio` / `voiceagent.audio`); sherpa-onnx recognizes it on the CPU with Kroko's streaming English model (57 MB, CC-BY-SA, downloaded on first use with progress) and Silero for speech start/end. Measured on this Mac with spoken test sentences (Indian, US, British, Australian English voices): Kroko 3.3 % word errors at 50× real time; Whisper base.en 6.2 % at 12×; NeMo streaming 22.7 %. Dictation also keeps the recording as a WAV (voice note). The helper exits after 3 idle minutes to give the RAM back. `OPSCODE_VOICE_ENGINE=sherpa` runs the same helper on a Mac (that is how it is tested).
- **Programs**: npm `.cmd` shims (Claude Code, Codex, MCP servers via npx) are read and started as their real Node script with Electron-as-Node, or their .exe (src/runtime/proc.ts), so long multi-line system prompts survive; program lookup by extension (.exe/.cmd), npm / scoop / .local\bin folders; the Windows environment variables kept for child programs.
- **Shells**: terminals and the built-in agent's run_command use PowerShell; process trees stop with taskkill; `tar.exe` (Windows 10+) unpacks the voice downloads.
- **Window**: normal frame, menu bar hidden (Alt shows it), taskbar id and icon; wording and shortcuts translated in one place (renderer/dom.js `words()`): this PC, Ctrl+, File Explorer; the mic shortcut is Ctrl+Shift+Space (Alt+Space opens the window menu on Windows). File links understand `C:\...` and never open programs/scripts.
- **Robustness**: file renames retried when antivirus holds the file; an app log at `%APPDATA%\Opscode\logs\opscode.log`.

## Not on Windows (by design)

Computer use (macOS only), the iOS Simulator tab, Apple speech. Everything else is the same code.

## Tests (run on the Mac)

test-phase46 (speech helper on real recorded speech: download, conversation, boost, dictation, recording, cancel; 22 checks), test-phase47 (shims, shells, wording, downloader safety, dictation and voice mode through the helper; 27 checks). **Never run on real Windows**: the installer, ConPTY terminals, PowerShell, `.cmd` shims against the real npm layout, the microphone in Chromium on Windows. Expect first-run issues; the log file is the first place to look.

## 8 GB RAM

Electron ≈ 400–600 MB, speech model ≈ 150 MB while talking (helper exits when idle), Pocket TTS ≈ 750 MB while speaking (unloads after 3 idle minutes), plus Claude Code / Codex processes. Close heavy browsers while using voice mode; use a fast voice model (Haiku, Codex luna low).
