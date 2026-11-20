// Turns a reply's markdown into text worth reading aloud, cut into sentences for the voice (the voice makes
// one sentence at a time, so audio starts after the first one). Pure: no model, no I/O.
//   - code blocks are skipped (one short phrase says so), inline code is read as its words, long ones as "code"
//   - links read as their label, bare URLs as "link", file paths as the file's name
//   - markdown marks, tables, HTML and emoji are removed; list items and headings end like sentences

export const MAX_CHARS = 20_000;
const SENTENCE_MAX = 280;
const FIRST_MAX = 160;
const MERGE_BELOW = 45;

const ABBREV = /\b(?:e\.g|i\.e|vs|etc|approx|dept|est|fig|no|mr|mrs|ms|dr|prof|sr|jr|st|inc|ltd)\.$/i;

const pathName = (p: string): string => {
  const clean = p.replace(/[?#].*$/, "").replace(/:\d+(?::\d+)?$/, "").replace(/\/+$/, "");
  return clean.split("/").filter(Boolean).pop() ?? p;
};

/** Inline code: a path reads as its file name, short code as its words, anything long as "code". */
function inlineCode(code: string): string {
  const c = code.trim();
  if (!c) return "";
  if (/^(?:~|\.{0,2})?\/[^\s]*[^\s/]$/.test(c) || /^[\w.-]+\/[\w./-]+$/.test(c)) return pathName(c);
  if (c.length > 40 || /[{}<>;=]/.test(c) && c.length > 20) return "code";
  return c;
}

export function toSpeakable(markdown: string): string {
  let skippedCode = false;
  let text = markdown.replace(/\r\n/g, "\n");
  if (text.length > MAX_CHARS) text = `${text.slice(0, MAX_CHARS)}\n`;

  // Fenced code blocks (also an unclosed one at the end).
  text = text.replace(/^[ \t]*(```|~~~)[^\n]*\n[\s\S]*?(?:^[ \t]*\1[ \t]*$|$(?![\s\S]))/gm, () => { skippedCode = true; return "\n\u0001\n"; });
  const lines = text.split("\n");
  const out: string[] = [];
  for (let line of lines) {
    if (line === "\u0001") { out.push(""); continue; }
    // Tables: separator rows go, cells are read as a short list.
    if (/^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$/.test(line)) continue;
    if (/^\s*\|.*\|\s*$/.test(line)) { const cells = line.trim().replace(/^\||\|$/g, "").split("|").map((c) => c.trim()).filter(Boolean).join(", "); line = cells ? `${cells}.` : ""; }
    // Headings and list items end like sentences.
    const heading = /^\s{0,3}#{1,6}\s+(.*)$/.exec(line);
    const item = /^\s*(?:[-*+•]|\d{1,3}[.)])\s+(.*)$/.exec(line);
    const quote = /^\s*>\s?(.*)$/.exec(line);
    let body = heading ? heading[1] : item ? item[1] : quote ? quote[1] : line;
    body = body.replace(/^\s*\[[ xX]\]\s+/, ""); // task list boxes
    out.push((heading || item) && body.trim() && !/[.!?:;]\s*$/.test(body.trim()) ? `${body.trim()}.` : body);
  }
  text = out.join("\n");

  text = text
    .replace(/!\[([^\]]*)\]\([^)]*\)/g, "$1") // images: their alt text
    .replace(/\[([^\]]+)\]\((?:<[^>]*>|[^)\s]*)(?:\s+"[^"]*")?\)/g, "$1") // links: the label
    .replace(/`([^`\n]+)`/g, (_m, c: string) => inlineCode(c))
    .replace(/<\/?[a-z][^>]*>/gi, " ") // HTML tags
    .replace(/https?:\/\/[^\s)>\]]+/g, "link")
    .replace(/(?<![\w/.:~-])(?:~|\.{0,2})?\/(?:[\w.@+%-]+\/)+[\w.@+%-]+/g, (p) => pathName(p)) // bare paths
    .replace(/(\*\*|__)(.*?)\1/g, "$2")
    .replace(/(?<![\w*])\*(?!\s)([^*\n]+?)\*(?![\w*])/g, "$1")
    .replace(/(?<![\w_])_(?!\s)([^_\n]+?)_(?![\w_])/g, "$1")
    .replace(/~~(.*?)~~/g, "$1")
    .replace(/^[-*_]{3,}\s*$/gm, "")
    .replace(/\p{Extended_Pictographic}️?/gu, "")
    .replace(/[​-‍﻿]/g, "")
    .replace(/[ \t]+([.,!?;:])/g, "$1")
    .replace(/[ \t]+/g, " ")
    .replace(/ *\n */g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
  if (skippedCode) text = `${text}\nCode block skipped.`.trim();
  return text;
}

/** Splits cleaned text into sentences, then packs them: tiny ones join the next, long ones break at a comma or space. */
export function toSentences(text: string): string[] {
  const raw: string[] = [];
  for (const para of text.split(/\n{1,}/)) {
    const p = para.trim();
    if (!p) continue;
    const parts = p.split(/(?<=[.!?…।॥。！？])["')\]]*\s+(?=["'(\[]?[\p{Lu}\p{Lt}\p{Lo}\p{N}₹$])|(?<=[।॥。！？])(?=\p{L})/u);
    let acc = "";
    for (const part of parts) {
      acc = acc ? `${acc} ${part}` : part;
      if (ABBREV.test(acc.trim())) continue; // "e.g." / "Dr." do not end a sentence
      raw.push(acc.trim());
      acc = "";
    }
    if (acc.trim()) raw.push(acc.trim());
  }
  // Break long sentences.
  const broke: string[] = [];
  for (const s of raw) {
    let rest = s;
    while (rest.length > SENTENCE_MAX) {
      const window = rest.slice(0, SENTENCE_MAX);
      let cut = Math.max(window.lastIndexOf(", "), window.lastIndexOf("; "), window.lastIndexOf(": "), window.lastIndexOf(" — "));
      if (cut < SENTENCE_MAX * 0.4) cut = window.lastIndexOf(" ");
      if (cut <= 0) cut = SENTENCE_MAX;
      broke.push(rest.slice(0, cut + 1).trim());
      rest = rest.slice(cut + 1).trim();
    }
    if (rest) broke.push(rest);
  }
  // Join tiny ones to the next so the voice has enough to work with; the very first stays short (faster start).
  const out: string[] = [];
  for (const s of broke) {
    const last = out[out.length - 1];
    const limit = out.length === 1 ? FIRST_MAX : SENTENCE_MAX;
    if (last !== undefined && (last.length < MERGE_BELOW) && last.length + 1 + s.length <= limit && !(out.length === 1 && last.length >= 20)) out[out.length - 1] = `${last} ${s}`;
    else out.push(s);
  }
  // Without a letter or digit there is nothing to say.
  return out.filter((s) => /[\p{L}\p{N}]/u.test(s));
}

/** Markdown -> sentences to speak. */
export function speakableSentences(markdown: string): string[] {
  return toSentences(toSpeakable(markdown));
}

/**
 * Cuts a reply that is still arriving into sentences, each as soon as it is complete, so the voice can start
 * on the first one while the model is still writing the rest. A boundary is known once the next sentence's
 * first character has arrived ("3.5" and "e.g." do not end a sentence); a long run with no boundary is cut at a comma.
 */
export class SentenceStream {
  private buf = "";
  /** Words before the first boundary after which a comma may end the very first sentence (a faster start). */
  private first = true;

  push(delta: string): string[] {
    this.buf += delta;
    return this.drain(false);
  }

  /** The reply ended: whatever is left is the last sentence. */
  flush(): string[] {
    return this.drain(true);
  }

  private cut(): number {
    const re = /(?<=[.!?…।॥。！？])["')\]]*\s+(?=["'(\[]?[\p{Lu}\p{Lt}\p{Lo}\p{N}₹$])|(?<=[।॥。！？])(?=\p{L})|\n+/gu;
    let m: RegExpExecArray | null;
    while ((m = re.exec(this.buf))) {
      const before = this.buf.slice(0, m.index + (m[0].startsWith("\n") ? 0 : m[0].length)).trim();
      if (ABBREV.test(before)) continue;
      return m.index + m[0].length;
    }
    // No boundary yet: an unusually long run is cut at its last comma (or the first sentence earlier).
    const limit = this.first ? FIRST_MAX : SENTENCE_MAX;
    if (this.buf.length >= limit) {
      const win = this.buf.slice(0, limit);
      const c = Math.max(win.lastIndexOf(", "), win.lastIndexOf("; "), win.lastIndexOf(": "), win.lastIndexOf(" — "));
      return c > limit * 0.4 ? c + 2 : win.lastIndexOf(" ") > 0 ? win.lastIndexOf(" ") + 1 : -1;
    }
    return -1;
  }

  private drain(final: boolean): string[] {
    const out: string[] = [];
    for (;;) {
      const at = final ? this.buf.length : this.cut();
      if (at <= 0) break;
      const raw = this.buf.slice(0, at);
      this.buf = this.buf.slice(at);
      for (const s of toSentences(toSpeakable(raw))) { out.push(s); this.first = false; }
      if (final) break;
    }
    return out;
  }
}
