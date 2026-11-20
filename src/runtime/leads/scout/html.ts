// A small, defensive HTML reader: no DOM and no dependencies. It pulls out what the scout needs (visible text,
// title, description, links, JSON-LD, the markup strings that reveal a site's tools) and nothing is ever run.
// Malformed HTML never throws; it just yields less.

const ENT: Record<string, string> = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ", rsquo: "’", lsquo: "‘", rdquo: "”", ldquo: "“", ndash: "–", mdash: "—", hellip: "…", copy: "©", eacute: "é", egrave: "è", agrave: "à", ccedil: "ç" };
export function decodeEntities(s: string): string {
  return s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e: string) => {
    if (e[0] === "#") {
      const code = e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      return Number.isFinite(code) && code > 0 && code < 0x110000 ? String.fromCodePoint(code) : m;
    }
    return ENT[e.toLowerCase()] ?? m;
  });
}

const attr = (tag: string, name: string): string | undefined => {
  const m = new RegExp(`\\b${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s>]+))`, "i").exec(tag);
  return m ? decodeEntities(m[1] ?? m[2] ?? m[3] ?? "") : undefined;
};
const strip = (s: string): string => decodeEntities(s.replace(/<[^>]*>/g, " ")).replace(/\s+/g, " ").trim();

export interface ParsedPage {
  title: string; description: string; siteName: string; lang: string; canonical: string; noindex: boolean;
  text: string; links: { href: string; text: string }[];
  jsonld: Record<string, unknown>[];
  /** Strings that reveal tools: script/style/iframe sources, the generator meta, form actions, mailto and tel targets. */
  markup: string[];
  emails: string[]; phones: string[];
}

function flatten(node: unknown, out: Record<string, unknown>[], depth = 0): void {
  if (depth > 6 || node === null || typeof node !== "object") return;
  if (Array.isArray(node)) { for (const n of node) flatten(n, out, depth + 1); return; }
  const o = node as Record<string, unknown>;
  out.push(o);
  if (o["@graph"]) flatten(o["@graph"], out, depth + 1);
}

export function parseHtml(html: string, baseUrl: string): ParsedPage {
  const src = html.length > 3_000_000 ? html.slice(0, 3_000_000) : html;
  const noComments = src.replace(/<!--[\s\S]*?-->/g, " ");

  const jsonld: Record<string, unknown>[] = [];
  for (const m of noComments.matchAll(/<script\b[^>]*type\s*=\s*["']?application\/ld\+json["']?[^>]*>([\s\S]*?)<\/script>/gi)) {
    try { flatten(JSON.parse(m[1]!.trim()), jsonld); } catch { /* invalid JSON-LD is common; skip it */ }
  }

  const markup: string[] = [];
  const addUrl = (v: string | undefined): void => { if (v && markup.length < 400) markup.push(v.trim().slice(0, 300)); };
  for (const m of noComments.matchAll(/<(script|iframe|img|source)\b[^>]*>/gi)) { const s = attr(m[0], "src"); if (s && (m[1]!.toLowerCase() !== "img" || /pixel|beacon|track/i.test(s))) addUrl(s); }
  for (const m of noComments.matchAll(/<link\b[^>]*>/gi)) { const h = attr(m[0], "href"); if (h && /stylesheet|preconnect|dns-prefetch|preload/i.test(attr(m[0], "rel") ?? "")) addUrl(h); }
  for (const m of noComments.matchAll(/<form\b[^>]*>/gi)) addUrl(attr(m[0], "action"));
  const metas = [...noComments.matchAll(/<meta\b[^>]*>/gi)].map((m) => m[0]);
  const meta = (key: string): string => { for (const t of metas) { const n = (attr(t, "name") ?? attr(t, "property") ?? "").toLowerCase(); if (n === key) return (attr(t, "content") ?? "").trim(); } return ""; };
  const generator = meta("generator");
  if (generator) markup.push(`generator: ${generator}`.slice(0, 200));

  const titleM = /<title\b[^>]*>([\s\S]*?)<\/title>/i.exec(noComments);
  const htmlTag = /<html\b[^>]*>/i.exec(noComments)?.[0] ?? "";
  const canon = /<link\b[^>]*rel\s*=\s*["']?canonical["']?[^>]*>/i.exec(noComments)?.[0];

  const links: { href: string; text: string }[] = [];
  const emails = new Set<string>(), phones = new Set<string>();
  for (const m of noComments.matchAll(/<a\b([^>]*)>([\s\S]*?)<\/a>/gi)) {
    const href = attr(m[1]!, "href");
    if (!href) continue;
    if (/^mailto:/i.test(href)) { const e = decodeURIComponent(href.slice(7).split("?")[0]!).trim().toLowerCase(); if (/^[^\s@]+@[^\s@]+\.[a-z]{2,}$/.test(e)) { emails.add(e); markup.push(`mailto:${e}`); } continue; }
    if (/^tel:/i.test(href)) { const p = decodeURIComponent(href.slice(4)).trim(); if (p.replace(/\D/g, "").length >= 7) { phones.add(p); markup.push(`tel:${p}`); } continue; }
    if (/^(javascript:|#|data:)/i.test(href)) continue;
    try { links.push({ href: new URL(href, baseUrl).href.split("#")[0]!, text: strip(m[2]!).slice(0, 120) }); } catch { /* skip */ }
  }

  let body = noComments
    .replace(/<head\b[\s\S]*?<\/head>/gi, " ")
    .replace(/<(script|style|noscript|svg|template|iframe)\b[\s\S]*?<\/\1>/gi, " ")
    .replace(/<\/?(p|div|br|li|ul|ol|h[1-6]|tr|td|th|section|article|header|footer|nav|main|aside|form|table|blockquote|dd|dt|figcaption)\b[^>]*>/gi, "\n")
    .replace(/<[^>]+>/g, " ");
  body = decodeEntities(body);
  const lines = body.split("\n").map((l) => l.replace(/[\s ]+/g, " ").trim()).filter(Boolean);
  const text = lines.join("\n").slice(0, 60_000);
  for (const e of text.matchAll(/\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b/gi)) if (!/\.(png|jpe?g|gif|svg|webp)$/i.test(e[0])) emails.add(e[0].toLowerCase());

  return {
    title: titleM ? strip(titleM[1]!).slice(0, 200) : "", description: (meta("description") || meta("og:description")).slice(0, 400), siteName: meta("og:site_name").slice(0, 120),
    lang: (attr(htmlTag, "lang") ?? "").slice(0, 12), canonical: canon ? attr(canon, "href") ?? "" : "", noindex: /noindex/i.test(meta("robots")),
    text, links, jsonld, markup: [...new Set(markup)], emails: [...emails].slice(0, 20), phones: [...phones].slice(0, 20),
  };
}
