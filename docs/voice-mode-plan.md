# Voice mode (Normal chat): talk to a front agent that briefs a worker — plan

Status: building, 2026-11-16. Builds on V1 (dictation), V3 (Pocket TTS), attachments, the task ledger and the Chief's "brain" mechanism.

## What the person asked for

- In a **Normal** chat, a big microphone. Click it and the message box goes away (squeezes, pixels dissolve). What is left: the microphone in the middle, the account and model chips, the + button, and the project / This Mac chips.
- A real conversation, like talking to Jarvis: you speak, a **front agent** understands, answers out loud in short words, and when work is needed it writes a proper brief and starts the **worker** (the normal chat engine). You can ask "what is it doing?", it checks the worker and explains in plain words: what is done, what is running, what is left, what is blocked.
- Files added with + while talking go out with the next thing you say. Added before you start talking: they go with your first words.
- Good quality text from speech.

## Pieces

```
mic (Chromium: echo cancel + noise suppression + gain)
  -> 16 kHz PCM, 100 ms chunks  ->  runtime  ->  opscode-voice helper (Apple on-device recognizer)
                                                   endpointing: speech / partial / utterance events
  utterance -> VoiceAgent (runtime)
                 -> front agent = a hidden chat on the chosen model (Claude Code or an API model)
                      tools: work_start, work_tell, work_status, work_stop, work_approve, peek
                 -> worker = the visible chat (its own engine/model, normal permissions, approval cards)
  front agent text -> sentences -> Pocket TTS (live session) -> PCM -> window plays it (WebAudio)
                      the same page plays it, so Chromium's echo canceller knows what to remove
```

### Decisions

1. **Front agent = a hidden chat run through the same turn engine as every other chat**, using the Chief-brain path (own system prompt, only its own tools). So it works on any account/model the person already set up and costs what a chat costs. It runs on Claude Code or an API model (not Codex/Antigravity/Qoder: they cannot take a custom tool set). An API model (e.g. a Flash/Haiku class one) is the fast choice; Claude Code works but each turn starts a process (seconds).
2. **The worker is the visible chat.** The brief the front agent writes is the first message in it (shown as a voice brief). The chat's own engine, model, account and permission mode are used, so nothing about permissions changes: approval cards still appear, and the front agent can read one out and answer it only after a clear spoken yes/no.
3. **Echo and interruptions:** capture and playback both stay in the window, so Chromium's echo canceller can remove what the agent says. The helper raises its speech threshold while the agent talks; a speech start cuts the agent off at once (barge-in), the brain turn is stopped, and the next turn is told what was cut. A text filter drops a recognised phrase that is just the agent's own last words coming back.
4. **Endpointing** is done in the helper from the audio clock (so a file feed tests the same code): speech starts after 240 ms of voice above an adaptive noise floor, the utterance ends after 1.1 s of quiet, then the recognizer is told to finalize. Short coughs/noise are dropped.
5. **The front agent always knows the worker:** every turn it receives a one-line worker state (running / idle / waiting for approval / failed, current activity, files changed) plus anything that happened since. When the worker finishes, fails or needs an approval, the agent is told and says so by itself (unless you are speaking).
6. **Briefs** follow a fixed shape (Goal, Context in the person's words, Where to start, Constraints, Done when, How to report) and are written for a worker that cannot hear the conversation. The prompt says so explicitly and forbids invented requirements.
7. **Language:** the voice (Pocket TTS) speaks English only, so the agent answers in English. Apple's on-device recognizer has no Hindi/Bengali; en-IN is the Mac's own default here.

## Build order (each slice verified before the next)

- **VM1 helper**: `converse` + `audio` commands in `native/opscode-voice`. Real test: `say` speech + silence + speech through the helper = two utterances.
- **VM2 live TTS**: streaming sentence splitter, TTS session that grows while the agent is still talking.
- **VM3 runtime**: `VoiceAgentService` (session, brain chat, tools, worker tracker, echo filter, barge-in), RPCs `voiceagent.*`, events `voiceagent.event`, settings, hidden chats.
- **VM4 window**: mic capture (worklet), WebAudio player, pixel orb, voice stage + squeeze/dissolve transition, captions, worker line, + files, model chip for the front agent.
- **VM5 checks**: runtime tests with a fake helper + mock model, smoke through the real UI, a spoken loop on this Mac (TTS audio -> recognizer -> brain), install.

## Not in this build

- Hindi/Bengali speech input (no on-device recognizer for them here), reading answers in another language.
- Voice approval of anything other than a tool/command card the worker is already waiting on.
- A hands-free wake word. The microphone stays on only while voice mode is open, and the window shows it.

## Built (2026-11-16)

- **Where:** a **Voice mode** pill above the message box, in the Normal / GODMODE / WARLORD / SHINOBI row (Normal chats only; icon-only when narrow). The small mic in the box is unchanged (dictation). In voice mode the box squeezes away and dissolves into pixels, the small mic and Send hide, and the pill becomes **End voice** (Esc also ends; ⌥Space mutes).
- **Stage:** pixel orb (renderer/orb.js: listening / hearing / thinking / speaking / muted), live captions (what you said, what it says), a status pill, a Worker chip (what it is doing, time, files), and labelled chips: **Voice** (the front agent's model: Claude Code or API, saved as voice_brain_*) and **Worker** (the chat's own model). + adds files: they go with your next words.
- **Helper:** `converse` + `audio` + `vad` commands. Endpointing on the audio clock; non-speech is fed as silence (a click no longer confuses the recognizer); finalize through the speech end. Real test: `node scripts/realtest-voice-converse.mjs` (3/3 sentences, click ignored).
- **Runtime:** src/runtime/voiceagent (prompt, tools work_start/work_tell/work_status/work_stop/work_approve/peek, echo filter, barge-in with "cut off" note, worker news spoken unasked, spoken approvals), live TTS sessions + SentenceStream. Hidden agent chat is never listed and is deleted at the end.
- **Window:** voicecapture.js (Chromium echo cancel + worklet, 16 kHz), voiceplayer.js (gapless WebAudio, instant stop), voicechat.js. main/permissions.ts: only the app may use the microphone; in-app browser pages get no permissions.
- **Tests:** test-phase45 (50), smoke step 05k (+ shots 05k-*). Full suite + smoke green; installed.
- **Not tested:** a real person talking into the real microphone (echo cancellation, barge-in by voice, real model latency). That needs you to allow the microphone and talk.

## Added (2026-11-16, later)

- **Barge-in on words, not sound:** the agent is cut off only when the recognizer hears 2+ words that are not its own (its voice in the mic no longer silences it).
- **Agent voice panel:** chip next to the Voice model: Bria / Loona with a sample, speed 0.8–1.4×, pitch −4..+4 semitones (window-side WSOLA time-stretch + playback rate; Pocket TTS has no speed control of its own). Settings voice_tts_voice / _speed / _pitch.
- **Browser:** the agent drives the Browser panel itself (voiceagent/browser.ts: search, navigate, read, find, act, screenshot, tabs, batch; no page JS). Outside sites need confirmed:true (the person named it / said yes). Browser skill in the prompt.
- **Several workers:** work_start = a new worker in a fresh chat (the window's chat if still empty); work_tell/status/stop take worker w1, w2…; up to 4 running. `<workers>` line every turn.
- **Cheaper agent turns:** every 6 turns the hidden agent chat is replaced by a fresh one that starts with a `<recap>` (last 12 lines of the talk + workers).
- **Stage:** worker boxes left/right of the orb (pixel reveal; orange while working, amber waiting for OK, dark when done; a row under the orb when narrow), a browser door bottom right, and a pixel robot (renderer/voicebot.js) that carries briefs to new boxes, steps into a box to check it, goes into the browser door and scrolls/taps, and talks by the orb.

## Voice model = any engine (2026-11-17)

- The model you TALK to (the Voice chip) can now be Claude Code, Codex, Antigravity, Qoder or an API model: the same list as the worker's picker. It only talks, searches/browses and briefs; the worker (its own chip, its own engine/model) does the coding.
- Codex as the agent (engines/codex.ts): thread with the agent's MCP server only, `features.shell_tool/image_generation/browser_use/computer_use/in_app_browser` off, `web_search` disabled, read-only sandbox, approvalPolicy on-request; every approval is answered by us (the agent's own MCP tools accepted, everything else declined). baseInstructions = the voice prompt.
- Antigravity / Qoder as the agent (engines/acp.ts): the agent's tools passed as an HTTP MCP server in session/new (agy names them `mcp_opscode_chief_<tool>` and asks permission first: allowed only for those, everything else rejected); the voice prompt is the first message of a fresh session.
- Real runs (scripts/realtest-voice-brain.mjs codex|antigravity|qoder [model] [effort]): all three talk and call work_status. Speed: Claude Haiku fastest; Codex gpt-6-luna low ≈5 s; Antigravity ≈9–13 s; Qoder ≈8–11 s. Default (nothing chosen yet) = a fast model (Haiku, flash, mini, luna).
- Worker cards show which model does the work; tooltips say VOICE = talks, WORKER = codes.
