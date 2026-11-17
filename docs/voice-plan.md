# Voice in Opscode: microphone (speech → text) and read aloud (text → speech) — plan

Status: proposal, 2026-11-16. Nothing built yet.

## What this Mac has (checked)

- macOS 26.2, Swift 6.3, Xcode SDK with Apple's **new on-device speech recognition**: `SpeechAnalyzer` + `SpeechTranscriber` / `DictationTranscriber` (Speech framework, macOS 26).
  - It runs fully on the Mac: no audio leaves it, and there is no cost.
  - It handles long recordings, so it suits voice notes, not just short commands.
- 184 built-in Apple voices (`say -v ?`). None of the better "Premium/Enhanced" voices are installed yet; they are a free download in System Settings → Accessibility → Spoken Content.

## Part 1: Microphone (speech → text)

**Use Apple's own on-device recognizer**, the same engine as macOS dictation. Electron's built-in speech API sends audio to Google and does not work without a key, so it is not an option.

How it works:

- **Helper program:** a small Swift program, `native/opscode-voice`. It is built like the existing `opscode-sim` helper.
  - It records the microphone with AVAudioEngine and turns the audio into text with SpeechAnalyzer.
  - It streams the live words back to Opscode as you speak.
- **Mic button in the composer**, beside Send. It is in every chat: Normal, GODMODE/WARLORD/SHINOBI, Conductor.
  - Click to start. Your words appear in the message box as you speak.
  - Click again to stop. Esc cancels.
  - A small level meter shows it is listening.
  - A shortcut (for example ⌥Space) for push-to-talk.
- **Voice note (record + text)** in the + menu, for "proper recording and text convert". It saves the audio file (`.m4a`) in the project's attachments, puts the transcript in the message, and attaches the audio.
- **Permissions:** macOS asks once for **Microphone** and **Speech Recognition**. The packaged app needs both usage descriptions in its `Info.plist`; `scripts/package-mac.mjs` will add them.
- **Language:**
  - English first.
  - Apple's recognizer needs a one-time language download, which macOS does on its own.
  - Whether Hindi or Bengali (or mixed Hinglish speech) is supported on-device is **not checked yet**. The first build step lists the supported languages on this Mac.
- **Fallback:** on macOS older than 26, the older `SFSpeechRecognizer` with on-device recognition.

## Part 2: Read aloud (text → speech)

- **🔊 button on each reply**, next to Copy: play / pause / stop.
  - It reads only the words: code blocks are skipped, and file links are read as their names.
  - Optional setting: "Read replies aloud" when a reply finishes.
- **Voice A, default, 0 MB download:** Apple's own voices through the same Swift helper (AVSpeechSynthesizer). It starts instantly and works offline. It sounds much better if you download a Premium voice in System Settings.
- **Voice B, optional "natural voice" download:** a small neural model running locally.

| Model | Size | Quality / speed | License | How it would run |
|---|---|---|---|---|
| **Pocket TTS 18.2M** (Kyutai, Oct 2026 "flagship") | ~18M params, about 35–75 MB | Kyutai says it matches the original 100M Pocket TTS; ~9.9× real time on one CPU thread; voice cloning | MIT code | Rust/WebAssembly port (`wasm-pocket-tts`, `pocket-tts-xn`), so no Python or PyTorch needed |
| Pocket TTS (original) | 100M params | High quality, ~6× real time on a MacBook Air M4 CPU | MIT code | Same ports |
| Kokoro-82M | ~86–92 MB (int8 ONNX) | Very natural, ~5× real time on CPU, 54 voices | Apache-2.0 | Needs onnxruntime (+~30–50 MB) |
| KittenTTS nano | ~25 MB (int8) | Smallest, lower quality | — | ONNX |
| Piper | 21–137 MB per voice | OK, 53 languages | GPL engine (avoid shipping it) | — |

**Recommendation:** ship Voice A first (no download). Then add **Pocket TTS 18.2M** as a one-click "natural voice" download, after a listening test against Apple's Premium voices.

**Not checked yet:** the weights' license and size on Hugging Face, and whether the WebAssembly port loads the 18.2M models. Both are checked before building Voice B.

## Build order

- **V1 Mic dictation:** Swift helper (record + on-device text), mic button + live text + level meter + shortcut, permissions in the packaged app. Tests with a fake helper; a real check with this Mac's microphone.
- **V2 Voice note:** recording saved as an attachment + its transcript.
- **V3 Read aloud with Apple voices:** 🔊 on replies, play/pause/stop, text cleaning, the optional auto-read setting.
- **V4 Natural voice (Pocket TTS 18.2M):** optional download, runs locally, voice picker.

## V1 built (2026-11-16)

- **Helper:** `native/opscode-voice/main.swift`, built by `scripts/build-native.mjs` (swiftc, ad-hoc signed) into `dist/native/opscode-voice`, and shipped inside the app.
  - It reads JSON-line commands: status, locales, start, stop, cancel, file.
  - It uses SpeechAnalyzer + SpeechTranscriber with live partial words, and falls back to DictationTranscriber when SpeechTranscriber does not support the language.
  - Apple's language model downloads itself on first use, with progress shown.
  - Project names are passed as contextual words.
  - It can also save the recording (for V2).
- **Runtime:** `src/runtime/voice.ts`, with RPCs `voice.status|locales|start|stop` and the event `voice.event`.
  - One session at a time.
  - `fixWords` joins split project words back together ("Ops code" → Opscode, words of 6+ letters, first spelling wins).
  - Setting `voice_locale` (default "auto" = the Mac's language and region).
- **UI:** `src/renderer/voice.js`.
  - Mic button next to Send in every chat: red while listening, with a level ring.
  - Live text in the box. Click to finish; ⌥Space starts and stops; Esc cancels and puts the box back; Enter while listening finishes, then sends.
  - Hidden when the Mac cannot do it.
  - Settings → General → Voice → Voice language.
- **Packaged app:** `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` are set. An apostrophe in the text broke PlistBuddy silently, so neither text uses one.
- **Real check (no microphone):** `say` → audio file → `file` command. "Please update the cart total in the Opscode project and run the tests" became "…card total in the Ops code project and run the test". 3.6 s of audio took 1.6 s, on-device.
- **Languages on this Mac:** SpeechTranscriber has 30, including en-IN, en-US and en-GB, already installed. DictationTranscriber has 43. **No Hindi or Bengali** in either.
- **Tests:** test-phase38 (21) with `scripts/lib/fake-voice.mjs`, and smoke step `05i` (mic fills the box, click finishes, Esc cancels).
- **Not tested:** a real microphone through Opscode. That needs the person to allow the microphone once and speak.

## V2 built (2026-11-16)


- **Voice note:** + menu → "Record a voice note" (not in Conductor chats, which have no project folder).
  - The mic goes red with a running timer (m:ss).
  - Click to stop: the text goes in the box and the recording is attached to the message.
  - Enter while recording stops, attaches and then sends.
  - Esc cancels: the recording and its folder are deleted.
- **Where the recording lives:** `<project>/.opscode/attachments/<id>/voice-note-<date time>.m4a`.
  - Git-ignored, 0700 folder.
  - AAC, written by the Swift helper while it listens, so the audio and the text come from the same microphone stream.
- **The agent gets:** the transcript (your message) and the recording's path (the normal attachments note).
  - Claude and Codex cannot listen to audio, so the text is what they act on; the file is there to keep.
- **Cleanup:** a cancelled note, or a refused microphone, removes the folder it made.
- **Tests:** test-phase39 (11), smoke step `05i-voice-note`.
- **Not tested:** the real microphone recording an `.m4a` (needs the person to allow the mic and speak).

## V3 built: read aloud with Pocket TTS (2026-11-16)

**Decision (the person's): no Apple voices. Pocket TTS is the read-aloud voice.**

- **Engine:** Pocket TTS (Kyutai, ~100M parameters), as an ONNX int8 export run by **sherpa-onnx** (`sherpa-onnx-node` 2.0.1, Apache-2.0, k2-fsa; `sherpa-onnx-darwin-arm64` holds the native libraries). It needs no Python or PyTorch. The model is `sherpa-onnx-pocket-tts-int8-2026-01-26`.
  - Download: 98,336,520 bytes from `github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/…tar.bz2`, **SHA-256 `2f3b8882…967cb`**, ~212 MB unpacked.
  - Why not the official `kyutai/pocket-tts` weights: they are gated on Hugging Face (a login plus accepting Kyutai's terms), so the app cannot fetch them for you. The 18.2M-parameter models Kyutai released in October are not available as ONNX yet.
- **Measured on this Mac (M4):** loads in 0.3 s; about 5 s of speech per 0.8 s (~7–8× real time); first audio ~0.6 s. It holds **~750 MB of memory while loaded**.
  - So it runs in its own **worker process**, started on first use and **stopped after 3 idle minutes**, which returns all of that memory.
- **Quality check:** the generated speech was transcribed back with the Apple recognizer from V1: it matched the text apart from a few recognizer mistakes. `speed` has no effect in Pocket TTS, so speed is applied at playback with the pitch kept.
- **Flow:**
  - The reply's markdown is cleaned to speakable sentences (`src/runtime/tts/speakable.ts`): code blocks skipped (one phrase says so), links read as their label, URLs as "link", file paths as the file name, markup and emoji removed.
  - The runtime (`src/runtime/tts/index.ts`) makes **one sentence at a time** in the worker (`worker.ts`) and sends 16-bit 24 kHz audio to the window as `tts.event`. It stays at most 3 sentences ahead of what is playing.
  - The window (`src/renderer/speak.js`) plays the sentences with `<audio>`, so pause, stop and speed are instant.
- **UI:**
  - 🔊 beside Copy on every reply. While reading: pause/resume, stop, and a speed button (1×, 1.25×, 1.5×, 1.75×).
  - Leaving the chat stops it.
  - **The first press asks** before downloading, and says what, from where, how big and the licence.
  - Settings → General → Voice: status, voice (Bria, Loona), speed, and a "Remove voice files" / "Download" button.
- **Install safety:** only GitHub hosts (redirects included), the SHA-256 must match, the archive is listed first and must only hold the model folder, and unpacking happens in a temporary folder that is renamed into place.
- **Licence (important):**
  - The model package's LICENSE is Creative Commons Attribution 4.0 (credit: Kyutai Pocket TTS; ONNX export by KevinAHM; packaging by sherpa-onnx).
  - Its README also says the export is **for non-commercial use**. Fine for your own use. **Check it before ever selling Opscode.**
  - Kyutai's terms forbid imitating a real person's voice.
- **Tests:** test-phase40 (40 checks: text cleaning, installer checksum/archive/redirect checks, streaming and look-ahead, stop, replacement, errors, idle shutdown); smoke steps `05j-*`. The real model was run through the runtime separately.
- **Not built yet:** more voices (the model clones a voice from a reference recording; only the two sample voices are included), reading replies aloud automatically, word highlighting.

## Open questions for you

1. Which languages do you speak to it? (English only, or also Hindi/Bengali/mixed?)
2. Should replies be read aloud automatically, or only when you press 🔊?
3. Should voice notes keep the audio file, or only the text?
