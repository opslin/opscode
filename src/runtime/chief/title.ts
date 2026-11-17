// A short, file-name-like label for a mode chat, taken from the first thing the person asks for.

const FILLER = /^(?:hey|hi|hello|ok|okay|so|please|pls|kindly|can you|could you|would you|will you|i need you to|i want you to|i want to|i need to|i would like to|i'd like to|we need to|we want to|let's|lets|go ahead and|just)\b[\s,:-]*/i;
const MAX_CHARS = 32;
const MAX_WORDS = 5;

/** "can you please build the login screen with google sign in" -> "Build the login screen". "" when there is nothing to name it from. */
export function shortTitle(text: string): string {
  let s = (text.split("\n").find((l) => l.trim()) ?? "").replace(/\[\[[^\]]*\]\]|https?:\/\/\S+|[`*_#>]|@\S+/g, " ").replace(/\s+/g, " ").trim();
  for (let i = 0; i < 4; i++) { const next = s.replace(FILLER, ""); if (next === s) break; s = next; }
  // One sentence only.
  const cut = s.search(/[.?!:;](?:\s|$)/);
  if (cut > 8) s = s.slice(0, cut);
  s = s.replace(/[.,;:!?\s-]+$/, "");
  const words = s.split(" ").filter(Boolean);
  let out = "";
  for (const w of words.slice(0, MAX_WORDS)) {
    if ((out ? out.length + 1 : 0) + w.length > MAX_CHARS) break;
    out = out ? `${out} ${w}` : w;
  }
  if (!out && words[0]) out = words[0].slice(0, MAX_CHARS);
  out = out.replace(/\s+(?:and|with|for|to|the|a|an|of|in|on|so|that)$/i, "");
  return out ? out[0].toUpperCase() + out.slice(1) : "";
}
