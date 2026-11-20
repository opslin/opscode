# Third-party notices

Opscode is the person's own app. It uses these outside works:

## Local speech

- **Kitten TTS 2 Mini** by KittenML (Apache-2.0) provides multilingual speech synthesis. The app downloads the pinned ONNX weights and voice packs from https://huggingface.co/KittenML/kitten-tts-2-mini.
- **Whisper Large-v3 Turbo** by OpenAI (MIT) provides multilingual transcription. The Q5_0 model comes from https://huggingface.co/ggerganov/whisper.cpp. The runtime uses whisper.cpp and pywhispercpp (MIT).
- **Silero VAD** (MIT) detects speech locally via **sherpa-onnx** (Apache-2.0). The model comes from https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models.
- **ONNX Runtime** (MIT), **Misaki** (Apache-2.0), **eSpeak NG** (GPL-3.0-or-later), **Open JTalk** (BSD-3-Clause), and **spaCy** (MIT) are bundled as separate runtime dependencies. Their distributions include their license notices.

## Other

- Brand logos of Claude and Codex: see `assets/brand/engines/NOTICE.md`.
- Logos of the MCP servers and services in the Plugins page (GitHub, Supabase, Firecrawl, TinyFish, Zoho, Hostinger and others): see `assets/brand/integrations/NOTICE.md`.


## Computer use: opscode-hands (native/opscode-hands)

The way opscode-hands reads apps as a numbered text map through Accessibility, finds an element again by its path, role and
label, prefers Accessibility actions, and posts input events to one app's process (the pointer and front app stay put) is
adapted from Atticus (https://github.com/SaarthurR/atticus-mac), MIT License, Copyright (c) 2026 SaarthurR. Atticus's Hands
in turn adapt ideas from Plip (https://github.com/hussainn7/plip-oss, MIT) and trycua/cua-driver (https://github.com/trycua/cua,
MIT). The code in native/opscode-hands is Opscode's own; the key-code table and per-process posting follow Atticus.

MIT License: Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to
whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission
notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT
WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.
