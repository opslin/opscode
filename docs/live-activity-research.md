# Live activity UI: what ChatGPT (Codex desktop) and Caveman Code do

Read-only analysis (2026-11-15) of `/Applications/ChatGPT.app` (Electron; its `app.asar` webview bundle, ~10,200 JS/CSS chunks, unpacked to a scratch copy) and `/Applications/Caveman Code.app` (its React client bundle). Neither app was modified. Opscode copies the patterns, not their code or assets.

## ChatGPT / Codex desktop

- **Image generation progress:** a placeholder card with an estimated progress bar from elapsed time, and a headline that rotates by time: "Creating image" (0 s), "Sketching it out" (10 s), "Making the first draft" (20 s), "Setting the scene" (25 s), "Polishing details" (30 s), "Finishing up" (35 s), "Adding final touches" (40 s), "One last tweak…" (50 s). Plural form "Creating 3 images". (Optional mini-game while waiting; not copied.)
- **Live verb + detail, then a past-tense summary:** "Editing {file}" / "Editing 3 files" → "Edited 3 files"; "Running command"; "Searching…"; "Writing"; "<action>Creating</action> <detail>visualization</detail>"; at the end "Worked for {time}".
- **Shimmer on the live verb:** a gradient swept across the text (`@keyframes loading-shimmer { 0% { background-position: -100% 0 } to { background-position: 250% 0 } }`), off when reduced motion is on.
- **Codex app-server image item** (`ImageGenerationItem`): id, status, revisedPrompt, result, savedPath. Files land in `~/.codex/generated_images/<thread>/…png`.

## Caveman Code

- **Action table:** each tool action has a present and a past verb, an icon and a counted summary: read (Reading/Read), edit (Editing/Edited, +added −removed), create (Created), search (Searched for), test (Running tests/Ran tests), image_generation (Generating image/Generated image, "generated # images").
- **Group label for a run of tool calls:** Exploring · Running a command · Editing files · Searching the web · Using an app · Generating an image · Using a tool.
- **"Subagents working" panel:** each agent has a title, its engine, status, startedAt (live elapsed) and its own live tool rows; finished ones show a summary.
- **Pixel mascots** (their own art; Opscode uses its own mode characters).

## What Opscode builds from this (no model tokens: all from events the runtime already streams)

1. **Crew strip above the Conductor's composer:** one chip per running worker: engine logo, model, mode emblem, kind, live verb with shimmer, elapsed; a small pixel wave while it works.
2. **Live worker cards in the Conductor chat:** title, engine + model, live verb + detail, files touched (Edited N files, with names), "Creating image" card with the rotating headlines and a progress bar, replaced by the real image preview when Codex saves it; "Worked for 2m 10s" with the report's Found line when done.
3. **Gate card in the chat** (not only the Work panel): stage summary, image gallery, feedback box, Send back and Approve.
