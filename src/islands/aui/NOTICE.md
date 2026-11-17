# Third-party code in src/islands/aui

Files under `components/assistant-ui/` come from **assistant-ui Elements** (https://www.assistant-ui.com/elements,
repository https://github.com/assistant-ui/assistant-ui), fetched from its shadcn registry (`https://r.assistant-ui.com/elements-*.json`)
by `scripts/tools/aui-fetch.mjs`. Files under `ui/` (`button.tsx`, `dialog.tsx`) come from **shadcn/ui** (https://ui.shadcn.com).

Both are MIT licensed:

> MIT License — Copyright (c) assistant-ui contributors; Copyright (c) 2023 shadcn.
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
> files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
> modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
> is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be
> included in all copies or substantial portions of the Software.
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.

Opscode changes (marked "Opscode:" in the code): `image-generation.tsx` gains `src`, `size`, `onOpen` (shows the real image);
`approval-card.tsx` gains a `children` slot. The built bundle's licence comments are collected in `dist/renderer/islands.js.LEGAL.txt`.
