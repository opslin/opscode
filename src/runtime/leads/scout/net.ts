// Polite, safe fetching for the website scout. Company domains come from agents and data vendors, so the
// address is never trusted: every connection (including each redirect hop) is checked at connect time, and
// only public addresses are used. Also here: robots.txt parsing (RFC 9309 rules), the request caps, and the
// identifying user agent. Nothing here executes page content.

import http from "node:http";
import https from "node:https";
import { lookup as dnsLookup } from "node:dns";
import { BlockList, isIP } from "node:net";
import zlib from "node:zlib";

export const USER_AGENT = "OpscodeBot/1.0 (+https://sayanthecoder.in; website research for lead finding)";

export class NetError extends Error {
  constructor(readonly kind: "blocked" | "invalid_url" | "timeout" | "network" | "too_many_redirects" | "not_html" | "http", message: string, readonly status?: number) { super(message); }
}

const NON_PUBLIC = new BlockList();
for (const [a, p] of [
  ["0.0.0.0", 8], ["10.0.0.0", 8], ["100.64.0.0", 10], ["127.0.0.0", 8], ["169.254.0.0", 16], ["172.16.0.0", 12], ["192.0.0.0", 24], ["192.0.2.0", 24],
  ["192.168.0.0", 16], ["198.18.0.0", 15], ["198.51.100.0", 24], ["203.0.113.0", 24], ["224.0.0.0", 4], ["240.0.0.0", 4],
] as const) NON_PUBLIC.addSubnet(a, p, "ipv4");
for (const [a, p] of [["::", 128], ["::1", 128], ["fc00::", 7], ["fe80::", 10], ["ff00::", 8], ["2001:db8::", 32], ["64:ff9b::", 96], ["100::", 64]] as const) NON_PUBLIC.addSubnet(a, p, "ipv6");

/** True for an address on the public internet. Loopback, private, link-local (cloud metadata), multicast and documentation ranges are not. */
export function isPublicAddress(ip: string): boolean {
  const fam = isIP(ip);
  if (fam === 0) return false;
  // An IPv4 address written as IPv6 (::ffff:10.0.0.1) is judged as the IPv4 address.
  const mapped = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/i.exec(ip);
  if (mapped) return !NON_PUBLIC.check(mapped[1]!, "ipv4");
  return !NON_PUBLIC.check(ip, fam === 6 ? "ipv6" : "ipv4");
}

export interface FetchOpts {
  /** Maps a URL to the one actually requested, so a test can point "site.test" at a fixture server on this machine. Production never sets it; the real URL is still what gets checked, followed and reported. */
  rewrite?: (u: URL) => URL;
  timeoutMs?: number; maxBytes?: number; maxRedirects?: number; accept?: "html" | "text";
}
export interface Fetched { url: string; status: number; headers: Record<string, string>; body: string; truncated: boolean; redirects: string[] }

const PORTS = new Set(["", "80", "443", "8080", "8443"]);

function checkUrl(raw: string): URL {
  let u: URL;
  try { u = new URL(raw); } catch { throw new NetError("invalid_url", "not a valid URL"); }
  if (u.protocol !== "http:" && u.protocol !== "https:") throw new NetError("invalid_url", `only http and https are fetched (got ${u.protocol})`);
  if (u.username || u.password) throw new NetError("invalid_url", "URLs with credentials are not fetched");
  const host = u.hostname.replace(/^\[|\]$/g, "");
  if (isIP(host) !== 0 && !isPublicAddress(host)) throw new NetError("blocked", `${host} is not a public address`);
  if (!PORTS.has(u.port)) throw new NetError("blocked", `port ${u.port} is not fetched`);
  return u;
}

function guardedLookup() {
  return (hostname: string, options: { all?: boolean; family?: number }, cb: (err: Error | null, a?: unknown, f?: number) => void): void => {
    dnsLookup(hostname, { all: true, family: options.family ?? 0 }, (err, addrs) => {
      if (err) return cb(err);
      const ok = addrs.filter((a) => isPublicAddress(a.address));
      if (ok.length === 0) return cb(new NetError("blocked", `${hostname} resolves to a non-public address`));
      return options.all ? cb(null, ok) : cb(null, ok[0]!.address, ok[0]!.family);
    });
  };
}

function once(u: URL, opts: FetchOpts, accept: string): Promise<{ status: number; headers: Record<string, string>; body: string; truncated: boolean }> {
  const max = opts.maxBytes ?? 1_500_000;
  return new Promise((resolve, reject) => {
    const lib = u.protocol === "https:" ? https : http;
    const req = lib.request(u, {
      method: "GET", lookup: guardedLookup() as never,
      headers: { "user-agent": USER_AGENT, accept, "accept-encoding": "gzip, deflate", "accept-language": "en" },
    }, (res) => {
      const headers: Record<string, string> = {};
      for (const [k, v] of Object.entries(res.headers)) if (typeof v === "string") headers[k.toLowerCase()] = v; else if (Array.isArray(v)) headers[k.toLowerCase()] = v.join(", ");
      const status = res.statusCode ?? 0;
      if (status >= 300 && status < 400) { res.resume(); return resolve({ status, headers, body: "", truncated: false }); }
      const enc = headers["content-encoding"];
      let stream: NodeJS.ReadableStream = res;
      if (enc === "gzip") stream = res.pipe(zlib.createGunzip());
      else if (enc === "deflate") stream = res.pipe(zlib.createInflate());
      else if (enc && enc !== "identity") { res.resume(); return reject(new NetError("network", `unsupported content-encoding ${enc}`)); }
      const chunks: Buffer[] = [];
      let size = 0, truncated = false;
      stream.on("data", (c: Buffer) => {
        if (truncated) return;
        size += c.length;
        if (size > max) { truncated = true; chunks.push(c.subarray(0, c.length - (size - max))); res.destroy(); (stream as { destroy?: () => void }).destroy?.(); resolve({ status, headers, body: Buffer.concat(chunks).toString("utf8"), truncated }); return; }
        chunks.push(c);
      });
      stream.on("end", () => { if (!truncated) resolve({ status, headers, body: Buffer.concat(chunks).toString("utf8"), truncated }); });
      stream.on("error", (e) => { if (!truncated) reject(new NetError("network", e.message)); });
    });
    req.setTimeout(opts.timeoutMs ?? 12_000, () => req.destroy(new NetError("timeout", "the site did not answer in time")));
    req.on("error", (e) => reject(e instanceof NetError ? e : new NetError("network", e.message)));
    req.end();
  });
}

/** GET with manual redirects (each hop is re-checked), a size cap and a type check. */
export async function fetchText(url: string, opts: FetchOpts = {}): Promise<Fetched> {
  const accept = opts.accept === "text" ? "text/plain,*/*;q=0.1" : "text/html,application/xhtml+xml;q=0.9,*/*;q=0.1";
  const redirects: string[] = [];
  let current = checkUrl(url);
  for (let hop = 0; hop <= (opts.maxRedirects ?? 4); hop++) {
    const r = await once(opts.rewrite ? opts.rewrite(current) : current, opts, accept);
    if (r.status >= 300 && r.status < 400 && r.headers.location) {
      redirects.push(current.href);
      try { current = checkUrl(new URL(r.headers.location, current).href); } catch (e) { throw e instanceof NetError ? e : new NetError("invalid_url", "bad redirect"); }
      continue;
    }
    const type = (r.headers["content-type"] ?? "").toLowerCase();
    if (r.status < 400 && opts.accept !== "text" && type && !/text\/html|application\/xhtml\+xml/.test(type)) throw new NetError("not_html", `not a web page (${type.split(";")[0]})`, r.status);
    return { url: current.href, status: r.status, headers: r.headers, body: r.body, truncated: r.truncated, redirects };
  }
  throw new NetError("too_many_redirects", "too many redirects");
}

// ---- robots.txt (RFC 9309) --------------------------------------------------------------------------------

export interface Robots { allowed(pathAndQuery: string): boolean; crawlDelaySec?: number; sitemaps: string[]; mode: "rules" | "none" | "disallow-all" }
const ALLOW_ALL: Robots = { allowed: () => true, sitemaps: [], mode: "none" };
export const DISALLOW_ALL: Robots = { allowed: () => false, sitemaps: [], mode: "disallow-all" };

function patternToRegex(p: string): RegExp {
  const anchored = p.endsWith("$");
  const body = (anchored ? p.slice(0, -1) : p).replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*");
  return new RegExp("^" + body + (anchored ? "$" : ""));
}

export function parseRobots(text: string, agent = "opscodebot"): Robots {
  type Group = { agents: string[]; rules: { allow: boolean; pattern: string }[]; delay?: number };
  const groups: Group[] = [];
  const sitemaps: string[] = [];
  let cur: Group | undefined, lastWasAgent = false;
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.replace(/#.*/, "").trim();
    const m = /^([A-Za-z-]+)\s*:\s*(.*)$/.exec(line);
    if (!m) continue;
    const key = m[1]!.toLowerCase(), val = m[2]!.trim();
    if (key === "user-agent") {
      if (!cur || !lastWasAgent) { cur = { agents: [], rules: [] }; groups.push(cur); }
      cur.agents.push(val.toLowerCase());
      lastWasAgent = true;
      continue;
    }
    lastWasAgent = false;
    if (key === "sitemap") { sitemaps.push(val); continue; }
    if (!cur) continue;
    if (key === "allow" || key === "disallow") cur.rules.push({ allow: key === "allow", pattern: val });
    else if (key === "crawl-delay") { const n = Number(val); if (Number.isFinite(n) && n >= 0) cur.delay = n; }
  }
  const mine = groups.filter((g) => g.agents.some((a) => a !== "*" && agent.includes(a)));
  const used = mine.length ? mine : groups.filter((g) => g.agents.includes("*"));
  const rules = used.flatMap((g) => g.rules).filter((r) => r.pattern !== "").map((r) => ({ allow: r.allow, re: patternToRegex(r.pattern), len: r.pattern.length }));
  const delay = used.find((g) => g.delay !== undefined)?.delay;
  return {
    sitemaps, mode: "rules", ...(delay !== undefined ? { crawlDelaySec: delay } : {}),
    allowed(path) {
      let best: { allow: boolean; len: number } | undefined;
      for (const r of rules) if (r.re.test(path) && (!best || r.len > best.len || (r.len === best.len && r.allow))) best = r;
      return best ? best.allow : true;
    },
  };
}

/**
 * robots.txt comes before any page, so the site is never touched without its rules. Tries https, then http.
 * Missing (4xx) means everything is allowed; a 5xx, or no answer at all, means we do not crawl (RFC 9309 §2.3.1.4).
 * Returns the origin the file was served from (it follows redirects such as www), which is where the crawl starts.
 */
export async function loadRobots(domain: string, opts: FetchOpts): Promise<{ robots: Robots; origin: string; error?: string }> {
  let last = "";
  for (const scheme of ["https", "http"]) {
    try {
      const r = await fetchText(`${scheme}://${domain}/robots.txt`, { ...opts, accept: "text", maxBytes: 500_000 });
      const origin = new URL(r.url).origin;
      if (r.status >= 500) return { robots: DISALLOW_ALL, origin, error: `robots.txt answered ${r.status}` };
      if (r.status >= 400) return { robots: ALLOW_ALL, origin };
      return { robots: parseRobots(r.body), origin };
    } catch (e) {
      if (e instanceof NetError && (e.kind === "blocked" || e.kind === "invalid_url")) throw e;
      last = e instanceof NetError ? `${e.kind}: ${e.message}` : String(e);
    }
  }
  return { robots: DISALLOW_ALL, origin: "", error: last || "the site did not answer" };
}
