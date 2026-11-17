# Third-party notices

Opscode is the person's own app. It uses these outside works:

## Read aloud: Pocket TTS (downloaded on request, not shipped inside the app)

- **Pocket TTS** by Kyutai (https://github.com/kyutai-labs/pocket-tts). Code: MIT. The model is distributed under Creative Commons Attribution 4.0 with Kyutai's prohibited-use terms (no voice impersonation or cloning without consent, no deception).
- **ONNX export** by KevinAHM (https://github.com/KevinAHM/pocket-tts-onnx-export). Its README asks for **non-commercial** use.
- **Packaging** `sherpa-onnx-pocket-tts-int8-2026-01-26` by the sherpa-onnx project (k2-fsa), downloaded once from its GitHub release when the person agrees, and checked against a pinned SHA-256. Sample voices (bria, loona) come from Kyutai's `delayed-streams-modeling` audio samples.
- **sherpa-onnx** / `sherpa-onnx-node` (Apache-2.0, k2-fsa) runs the model on the CPU.

Check these licences before distributing Opscode to others.

## Other

- Brand logos of Claude and Codex: see `assets/brand/engines/NOTICE.md`.


## Speech recognition on Windows and Linux (voice input)

- **Kroko streaming English speech model** (`sherpa-onnx-streaming-zipformer-en-kroko-2025-08-06`, about 57 MB): Banafo's Kroko community model, **CC-BY-SA**. Downloaded on first use from the sherpa-onnx releases on GitHub (https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models); not part of the installer. Source and license: https://huggingface.co/Banafo/Kroko-ASR
- **Silero VAD** (`silero_vad.onnx`, 0.6 MB): voice-activity detection, MIT license (https://github.com/snakers4/silero-vad). Downloaded with the model.
- **sherpa-onnx** (Apache-2.0, k2-fsa) runs both, and Pocket TTS, on the CPU: https://github.com/k2-fsa/sherpa-onnx
- On a Mac, voice input uses Apple's on-device speech recognition and nothing is downloaded.
