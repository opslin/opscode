// Crawls one company website: the home page plus at most one page per useful kind (careers, locations, order,
// menu, about, contact, news). Same site only, robots.txt obeyed, a pause between requests, hard caps on pages
// and bytes. Returns the pages it read and why it skipped the others.

import { fetchText, loadRobots, NetError } from "./net";
import type { FetchOpts, Robots } from "./net";
import { parseHtml } from "./html";
import type { ParsedPage } from "./html";
import { needsRender } from "./render";

export type PageKind = "home" | "careers" | "locations" | "order" | "menu" | "about" | "contact" | "news" | "other";
export interface CrawledPage { url: string; kind: PageKind; status: number; parsed: ParsedPage; truncated: boolean; rendered: boolean }
export interface CrawlResult {
  domain: string; final_host: string; pages: CrawledPage[]; skipped: { url: string; reason: string }[];
  robots: Robots["mode"]; ok: boolean; error?: string; renders: { used: number; failed: string[] };
}
export interface CrawlOpts extends FetchOpts {
  /** Returns the page's HTML after its scripts ran. Called only for pages that look like empty shells. */
  render?: (url: string) => Promise<string>; maxRenders?: number; maxPages?: number; delayMs?: number; maxDelayMs?: number; sleep?: (ms: number) => Promise<void> }

const KINDS: { kind: PageKind; re: RegExp }[] = [
  { kind: "careers", re: /career|\bjobs?\b|hiring|work-with-us|join-(us|our|the)|employment|opportunit/i },
  { kind: "locations", re: /location|find-us|visit|branches|stores?\b|our-restaurants/i },
  { kind: "order", re: /order|pick-?up|delivery|catering|takeout|take-out/i },
  { kind: "menu", re: /\bmenu/i },
  { kind: "about", re: /about|our-story|who-we-are|story/i },
  { kind: "contact", re: /contact|reach-us/i },
  { kind: "news", re: /news|blog|press|updates|events/i },
];
const ORDER: PageKind[] = ["careers", "locations", "order", "menu", "about", "contact", "news"];
const SKIP_EXT = /\.(pdf|jpe?g|png|gif|webp|svg|ico|css|js|zip|mp4|mp3|docx?|xlsx?|pptx?)(\?|$)/i;
const bareHost = (h: string): string => h.toLowerCase().replace(/^www\./, "");

export function classify(url: string, text: string): PageKind {
  let path = "";
  try { path = new URL(url).pathname; } catch { /* keep empty */ }
  for (const k of KINDS) if (k.re.test(path)) return k.kind;
  for (const k of KINDS) if (k.re.test(text) && text.length < 40) return k.kind;
  return "other";
}

export async function crawlSite(domain: string, o: CrawlOpts = {}): Promise<CrawlResult> {
  const sleep = o.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  const result: CrawlResult = { domain, final_host: domain, pages: [], skipped: [], robots: "none", ok: false, renders: { used: 0, failed: [] } };
  const maxPages = Math.min(Math.max(o.maxPages ?? 8, 1), 15);

  let loaded;
  try { loaded = await loadRobots(domain, o); } catch (e) { result.error = e instanceof NetError ? `${e.kind}: ${e.message}` : String(e); return result; }
  const { robots, origin } = loaded;
  result.robots = robots.mode;
  if (!origin) { result.error = loaded.error ?? "the site did not answer"; return result; }
  result.final_host = new URL(origin).hostname;
  if (robots.mode === "disallow-all") { result.error = loaded.error ?? "robots.txt disallows crawling"; result.skipped.push({ url: origin + "/", reason: result.error }); return result; }
  const pathOf = (u: string): string => { const x = new URL(u); return x.pathname + x.search; };
  if (!robots.allowed("/")) { result.error = "robots.txt disallows crawling"; result.skipped.push({ url: origin + "/", reason: "robots.txt disallows the site" }); return result; }

  /** Plain HTML first; if it is an empty shell and a renderer is available, the rendered page replaces it. */
  const read = async (html: string, url: string): Promise<{ parsed: ParsedPage; rendered: boolean }> => {
    const plain = parseHtml(html, url);
    if (!o.render || result.renders.used >= (o.maxRenders ?? 3) || !needsRender(plain, html)) return { parsed: plain, rendered: false };
    result.renders.used++;
    try { return { parsed: parseHtml(await o.render(url), url), rendered: true }; }
    catch (e) { result.renders.failed.push(`${url}: ${e instanceof Error ? e.message : String(e)}`); return { parsed: plain, rendered: false }; }
  };

  const delay = Math.min(Math.max(o.delayMs ?? 1000, (robots.crawlDelaySec ?? 0) * 1000), o.maxDelayMs ?? 10_000);
  const hostOk = (u: string): boolean => { try { return bareHost(new URL(u).hostname) === bareHost(result.final_host); } catch { return false; } };

  if (delay > 0) await sleep(delay);
  let home;
  try { home = await fetchText(origin + "/", o); } catch (e) { result.error = e instanceof NetError ? `${e.kind}: ${e.message}` : String(e); return result; }
  if (!hostOk(home.url)) { result.error = "the home page redirected to another site"; return result; }
  const { parsed: homeParsed, rendered: homeRendered } = await read(home.body, home.url);
  result.pages.push({ url: home.url, kind: "home", status: home.status, parsed: homeParsed, truncated: home.truncated, rendered: homeRendered });
  if (home.status >= 400) { result.error = `home page answered ${home.status}`; return result; }
  result.ok = true;

  // One candidate per kind, the shortest path first (the "/careers" page rather than a single job post).
  const seen = new Set([home.url]);
  const best = new Map<PageKind, { url: string; len: number }>();
  for (const l of homeParsed.links) {
    if (!hostOk(l.href) || SKIP_EXT.test(l.href) || seen.has(l.href)) continue;
    const kind = classify(l.href, l.text);
    if (kind === "other") continue;
    const len = pathOf(l.href).length;
    const cur = best.get(kind);
    if (!cur || len < cur.len) best.set(kind, { url: l.href, len });
  }
  for (const kind of ORDER) {
    if (result.pages.length >= maxPages) break;
    const c = best.get(kind);
    if (!c || seen.has(c.url)) continue;
    seen.add(c.url);
    if (!robots.allowed(pathOf(c.url))) { result.skipped.push({ url: c.url, reason: "robots.txt disallows this page" }); continue; }
    if (delay > 0) await sleep(delay);
    try {
      const r = await fetchText(c.url, o);
      if (!hostOk(r.url)) { result.skipped.push({ url: c.url, reason: "redirected to another site" }); continue; }
      if (r.status >= 400) { result.skipped.push({ url: c.url, reason: `answered ${r.status}` }); continue; }
      const got = await read(r.body, r.url);
      result.pages.push({ url: r.url, kind, status: r.status, parsed: got.parsed, truncated: r.truncated, rendered: got.rendered });
    } catch (e) {
      result.skipped.push({ url: c.url, reason: e instanceof NetError ? `${e.kind}: ${e.message}` : String(e) });
    }
  }
  return result;
}
