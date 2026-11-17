// The image rule, as one prompt note every engine gets (Claude Code, Codex, Antigravity, Qoder, the built-in
// agent). Kept in its own file with no imports so the engine adapters can use it without import cycles.
// Every chat pays for this note, so it stays short.

export const IMAGE_NOTE =
  "Images: for any request to create, draw, design or edit an image (logo, icon, UI screen, character, sprite sheet, banner, illustration) call image_generate. Never draw it with code (SVG, canvas, PIL) or use another image service unless asked. " +
  "Write a full brief (subject, style, hex colors, background); save_as puts it in the project; references keep a character consistent. It switches Codex accounts by itself; if it says generation is paused, give the user that time exactly and stop retrying.";
