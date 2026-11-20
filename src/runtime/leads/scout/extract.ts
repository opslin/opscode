// Turns a crawled site into ontology records. Deterministic, no model: JSON-LD, meta tags, mailto/tel links,
// tool fingerprints and the industry pack's own phrases. Every observation quotes text that is really in a
// stored document (the page text, or a "#markup" document holding the page's script/link/JSON-LD strings),
// so the store's quote check passes for real and a later reader can find the evidence.
// Running it twice on the same pages adds nothing new (observeOnce / addSignalOnce).

import { quoteInText, normalizeDomain } from "../ontology";
import type { IndustryPack, Location, PackNeedType, SignalType } from "../ontology";
import type { LeadStore } from "../store";
import { fingerprint } from "./tech";
import { INJECTION, PROMPT_VERSION, buildPrompt, parseFindings } from "./llm";
import type { Complete } from "./llm";
import type { CrawlResult, CrawledPage, PageKind } from "./crawl";

const EXTRACTOR = "website-scout@1";
const LLM_EXTRACTOR = "llm-extractor@1";
/** What the model step did, for the person to see. */
export interface LlmReport { enabled: boolean; calls: number; cached: number; rejected: number; errors: number; skipped_budget: number; injection_suspected: string[]; definition?: string }
export interface LlmOpts { complete: Complete; maxCalls?: number; maxChars?: number; signalMs?: number }
export interface ScoutReport {
  domain: string; status: "ok" | "unreachable" | "blocked_by_robots" | "suppressed" | "invalid";
  error?: string; org_id?: string; pages: { url: string; kind: PageKind; rendered: boolean }[]; render: { used: number; failed: string[] }; skipped: { url: string; reason: string }[];
  llm: LlmReport; observations: number; signals: Record<string, number>; needs: { need_type: string; signals: number }[]; tech: string[]; emails: string[]; phones: string[]; locations: number;
}

const COUNTRIES: Record<string, string> = { canada: "CA", "united states": "US", usa: "US", "united states of america": "US", australia: "AU", "united arab emirates": "AE", uae: "AE", "united kingdom": "GB", uk: "GB", "new zealand": "NZ", ireland: "IE", india: "IN" };
const TLD: Record<string, string> = { ca: "CA", au: "AU", ae: "AE", uk: "GB", nz: "NZ", ie: "IE", in: "IN" };
const GENERIC_TITLE = /^(home|welcome|homepage|official site|official website|menu|index|main)$/i;
const ORG_TYPES = /^(Organization|LocalBusiness|Restaurant|FoodEstablishment|CafeOrCoffeeShop|Bakery|BarOrPub|Store|ProfessionalService|HealthAndBeautyBusiness|SportsActivityLocation|Corporation|OnlineStore|AutomotiveBusiness)$/;
const EXPANSION = /\b(now open in|opening soon|coming soon|grand opening|new location|second location|third location|we(?:'|’)re expanding|we are expanding|just opened|opening (?:in|this|next))\b/i;
const HIRING_LINE = /^(?:now hiring|we(?:'|’)re hiring|we are hiring|hiring)\s*[:\-–]\s*(.{3,120})$/i;

const typesOf = (n: Record<string, unknown>): string[] => { const t = n["@type"]; return Array.isArray(t) ? t.map(String) : typeof t === "string" ? [t] : []; };
const str = (v: unknown): string => (typeof v === "string" ? v.trim() : typeof v === "number" ? String(v) : "");
const countryCode = (v: string): string | undefined => (/^[A-Za-z]{2}$/.test(v) ? v.toUpperCase() : COUNTRIES[v.toLowerCase()]);

/** Which signal a phrase hit counts as. A "call to order" line is a gap in what they offer; "new location" is expansion; on a careers page it is hiring. */
export function signalFor(need: PackNeedType, kind: PageKind): SignalType {
  const pref: SignalType[] = kind === "careers"
    ? ["hiring_role", "tech_gap", "expansion", "launch", "pain_expressed"]
    : ["tech_gap", "expansion", "launch", "pain_expressed", "hiring_role"];
  return pref.find((s) => need.signals.includes(s)) ?? need.signals[0]!;
}

/** A readable quote around the first match: the whole line when short, else a window around the match. */
function quoteAround(text: string, index: number, len: number): string {
  const start = text.lastIndexOf("\n", index) + 1;
  let end = text.indexOf("\n", index + len);
  if (end < 0) end = text.length;
  const line = text.slice(start, end).trim();
  if (line.length <= 300) return line;
  const from = Math.max(start, index - 120);
  return text.slice(from, Math.min(end, index + len + 160)).trim();
}

function nameOf(domain: string, home: CrawledPage | undefined, ld: Record<string, unknown>[]): string {
  const n = ld.find((x) => typesOf(x).some((t) => ORG_TYPES.test(t)) && str(x.name));
  if (n) return str(n.name).slice(0, 120);
  const p = home?.parsed;
  if (p?.siteName) return p.siteName;
  if (p?.title) {
    const seg = p.title.split(/\s*[|–—·:]\s*|\s+-\s+/).map((s) => s.trim()).filter((s) => s.length >= 2 && !GENERIC_TITLE.test(s));
    if (seg[0]) return seg[0].slice(0, 120);
  }
  const label = domain.split(".")[0] ?? domain;
  return label.charAt(0).toUpperCase() + label.slice(1);
}

export async function extractSite(store: LeadStore, crawl: CrawlResult, pack: IndustryPack | undefined, now: Date = new Date(), llm?: LlmOpts): Promise<ScoutReport> {
  const report: ScoutReport = { domain: crawl.domain, status: "ok", pages: crawl.pages.map((p) => ({ url: p.url, kind: p.kind, rendered: p.rendered })), render: crawl.renders, skipped: crawl.skipped, llm: { enabled: !!llm && !!pack, calls: 0, cached: 0, rejected: 0, errors: 0, skipped_budget: 0, injection_suspected: [] }, observations: 0, signals: {}, needs: [], tech: [], emails: [], phones: [], locations: 0 };
  const home = crawl.pages.find((p) => p.kind === "home");
  if (!crawl.ok || !home) {
    report.status = /robots/.test(crawl.error ?? "") ? "blocked_by_robots" : "unreachable";
    if (crawl.error) report.error = crawl.error;
    return report;
  }

  const allLd = crawl.pages.flatMap((p) => p.parsed.jsonld);
  const addrNodes = allLd.filter((x) => typesOf(x).includes("PostalAddress") || (x.address && typeof x.address === "object")).map((x) => (typesOf(x).includes("PostalAddress") ? x : (x.address as Record<string, unknown>)));
  const hqRaw = addrNodes.map((a) => str(a.addressCountry) || str((a.addressCountry as Record<string, unknown> | undefined)?.name)).find(Boolean) ?? "";
  const ldCountry = hqRaw ? countryCode(hqRaw) : undefined;

  const org = store.upsertOrganization({
    name: nameOf(crawl.domain, home, allLd), domain: crawl.domain,
    ...(ldCountry ? { hq_country: ldCountry } : {}),
    ...(home.parsed.description ? { description_short: home.parsed.description } : {}),
  });
  report.org_id = org.id;

  const obs = (predicate: string, object: string, quote: string, url: string, documentId: string | undefined, confidence: number, extractor: string = EXTRACTOR) => {
    const o = store.observeOnce({ subject_type: "organization", subject_id: org.id, predicate, object, evidence_quote: quote, url, ...(documentId ? { document_id: documentId } : {}), confidence, extractor });
    report.observations++;
    return o;
  };
  const signal = (type: SignalType, observationId: string, date?: string) => {
    const s = store.addSignalOnce({ org_id: org.id, type, observation_ids: [observationId], date: date ?? now.toISOString() });
    report.signals[type] = (report.signals[type] ?? 0) + 1;
    return s;
  };
  // The same sentence can be both a "Hiring:" line and a phrase hit; it is one piece of evidence, so it makes one signal.
  const byQuote = new Map<string, string>();
  const needSignals = new Map<string, Set<string>>();
  const link = (need: string, signalId: string): void => { (needSignals.get(need) ?? needSignals.set(need, new Set()).get(need)!).add(signalId); };

  const lang = home.parsed.lang;
  let expansionHits = 0;
  const pageInfo: { page: CrawledPage; docId: string; docHash: string; text: string; literal: Set<string> }[] = [];
  const seenTech = new Set<string>();

  for (const page of crawl.pages) {
    const p = page.parsed;
    // Documents: the visible text (with the title and description first, so they can be quoted) and the markup strings.
    const ld: string[] = [];
    for (const n of p.jsonld) {
      const types = typesOf(n);
      if (types.some((t) => ORG_TYPES.test(t)) && str(n.name)) ld.push(`ld:name=${str(n.name)}`);
      if (str(n.telephone)) ld.push(`ld:telephone=${str(n.telephone)}`);
      if (types.includes("JobPosting") && str(n.title)) ld.push(`ld:JobPosting=${str(n.title)}${str(n.datePosted) ? ` (posted ${str(n.datePosted)})` : ""}`);
    }
    for (const a of p.jsonld.filter((x) => typesOf(x).includes("PostalAddress") || (x.address && typeof x.address === "object"))) {
      const addr = typesOf(a).includes("PostalAddress") ? a : (a.address as Record<string, unknown>);
      const line = [str(addr.streetAddress), str(addr.addressLocality), str(addr.addressRegion), str(addr.postalCode), str(addr.addressCountry)].filter(Boolean).join(", ");
      if (line) ld.push(`ld:address=${line}`);
    }
    const text = `TITLE: ${p.title}\nDESCRIPTION: ${p.description}\n${p.text}`;
    const doc = store.addDocument({ platform: "website", url: page.url, text, ...(lang ? { language: lang } : {}) });
    const info = { page, docId: doc.id, docHash: doc.hash, text, literal: new Set<string>() };
    pageInfo.push(info);
    const markupLines = [...new Set([...p.markup, ...ld])];
    const mdoc = markupLines.length ? store.addDocument({ platform: "website", url: `${page.url}#markup`, text: markupLines.join("\n") }) : undefined;
    const mUrl = `${page.url}#markup`;

    if (page.kind === "home" && p.description && quoteInText(p.description, text)) obs("describes_as", p.description.slice(0, 400), p.description.slice(0, 400), page.url, doc.id, 0.9);

    // Tools in use (once per site).
    for (const hit of fingerprint(p.markup)) {
      if (seenTech.has(hit.tech) || !mdoc) continue;
      seenTech.add(hit.tech);
      obs("uses_tech", hit.tech, hit.evidence, mUrl, mdoc.id, 0.9);
      report.tech.push(hit.tech);
    }

    // Public contacts. A role mailbox (info@, hello@) is still a business contact; the scorer reads the address.
    if (mdoc) {
      for (const e of p.emails) if (quoteInText(e, markupLines.join("\n")) || quoteInText(e, text)) { const useDoc = quoteInText(e, text) ? doc : mdoc; obs("has_public_email", e, e, quoteInText(e, text) ? page.url : mUrl, useDoc.id, 0.9); if (!report.emails.includes(e)) report.emails.push(e); }
      for (const t of p.phones) { obs("has_phone", t, `tel:${t}`, mUrl, mdoc.id, 0.9); if (!report.phones.includes(t)) report.phones.push(t); }
      for (const l of ld.filter((x) => x.startsWith("ld:telephone="))) { const v = l.slice("ld:telephone=".length); obs("has_phone", v, l, mUrl, mdoc.id, 0.95); if (!report.phones.includes(v)) report.phones.push(v); }
      for (const l of ld.filter((x) => x.startsWith("ld:address="))) {
        const addr = l.slice("ld:address=".length);
        obs("has_location", addr, l, mUrl, mdoc.id, 0.95);
        if (!store.list<Location>("locations", (x) => x.org_id === org.id && x.address === addr).length) {
          const cc = ldCountry;
          store.addLocation({ org_id: org.id, address: addr, ...(cc ? { country: cc } : {}) });
        }
      }
      // Jobs posted as structured data carry their own date.
      for (const l of ld.filter((x) => x.startsWith("ld:JobPosting="))) {
        const title = l.slice("ld:JobPosting=".length).replace(/ \(posted .*\)$/, "");
        const posted = /\(posted ([^)]+)\)$/.exec(l)?.[1];
        const o = obs("hiring_for", title, l, mUrl, mdoc.id, 0.95);
        signal("hiring_role", o.id, posted && !Number.isNaN(new Date(posted).getTime()) ? new Date(posted).toISOString() : undefined);
      }
    }

    // "Hiring: ..." lines and expansion notices in the visible text.
    for (const line of p.text.split("\n")) {
      const h = HIRING_LINE.exec(line.trim());
      if (h && page.kind !== "news") { const q = line.trim().slice(0, 300); const o = obs("hiring_for", h[1]!.trim(), q, page.url, doc.id, 0.8); byQuote.set(`hiring_role|${page.url}|${q}`, signal("hiring_role", o.id).id); }
    }
    const ex = EXPANSION.exec(p.text);
    if (ex && expansionHits < 3) { expansionHits++; const q = quoteAround(p.text, ex.index, ex[0].length); const o = obs("expansion_notice", ex[0].toLowerCase(), q, page.url, doc.id, 0.7); signal("expansion", o.id); }

    // The pack's own phrases: what a business in this industry says when it has the need.
    if (pack) {
      const lower = p.text.toLowerCase();
      for (const need of pack.need_types) for (const phrase of need.phrases) {
        const i = lower.indexOf(phrase.toLowerCase());
        if (i < 0) continue;
        const q = quoteAround(p.text, i, phrase.length);
        const o = obs(`mentions:${need.id}`, phrase, q, page.url, doc.id, 0.7);
        const type = signalFor(need, page.kind);
        const key = `${type}|${page.url}|${q}`;
        let sid = byQuote.get(key);
        if (!sid) { sid = signal(type, o.id).id; byQuote.set(key, sid); }
        link(need.id, sid);
        info.literal.add(need.id);
      }
    }
  }

  // The model step: pages the literal matcher could not read, plus the home page (for the company type). Capped by calls and characters.
  if (llm && pack) {
    const maxCalls = llm.maxCalls ?? 6, maxChars = llm.maxChars ?? 40_000;
    let chars = 0, failures = 0;
    const order: PageKind[] = ["home", "order", "careers", "locations", "menu", "about", "contact", "news", "other"];
    const todo = pageInfo.filter((x) => x.page.kind === "home" || x.literal.size === 0).sort((a, b) => order.indexOf(a.page.kind) - order.indexOf(b.page.kind));
    for (const x of todo) {
      if (INJECTION.test(x.text)) report.llm.injection_suspected.push(x.page.url);
      const key = `${x.docHash}|${pack.id}@${pack.version}|${PROMPT_VERSION}`;
      if (store.llmSeen(key)) { report.llm.cached++; continue; }
      if (report.llm.calls >= maxCalls || chars + Math.min(x.text.length, 6000) > maxChars) { report.llm.skipped_budget++; continue; }
      if (failures >= 3) { report.llm.skipped_budget++; continue; }
      chars += Math.min(x.text.length, 6000);
      report.llm.calls++;
      let raw: string;
      try {
        const { system, user } = buildPrompt(pack, x.page.kind, x.text);
        raw = await llm.complete(system, user, AbortSignal.timeout(llm.signalMs ?? 45_000));
      } catch { report.llm.errors++; failures++; continue; }
      const f = parseFindings(raw, pack, x.text);
      report.llm.rejected += f.rejected;
      if (!f.parsed) { report.llm.errors++; failures++; continue; }
      failures = 0;
      store.markLlmSeen(key);
      if (f.definition && x.page.kind === "home") {
        obs("definition", f.definition.label, f.definition.quote, x.page.url, x.docId, 0.7, LLM_EXTRACTOR);
        store.upsertOrganization({ name: org.name, domain: crawl.domain, definition: f.definition.label });
        report.llm.definition = f.definition.label;
      }
      for (const n of f.needs) {
        if (x.literal.has(n.need_type)) continue; // the literal match already counts this page for this need
        const def = pack.need_types.find((t) => t.id === n.need_type)!;
        const o = obs(`llm:mentions:${n.need_type}`, def.label, n.quote, x.page.url, x.docId, n.confidence, LLM_EXTRACTOR);
        const type = signalFor(def, x.page.kind);
        const k = `${type}|${x.page.url}|${n.quote}`;
        let sid = byQuote.get(k);
        if (!sid) { sid = signal(type, o.id).id; byQuote.set(k, sid); }
        link(n.need_type, sid);
      }
      for (const e of f.expansion) {
        if (expansionHits >= 3) break;
        const k = `expansion|${x.page.url}|${e.quote}`;
        if (byQuote.has(k)) continue;
        expansionHits++;
        const o = obs("expansion_notice", e.quote.slice(0, 80), e.quote, x.page.url, x.docId, 0.6, LLM_EXTRACTOR);
        byQuote.set(k, signal("expansion", o.id).id);
      }
      for (const h of f.hiring) {
        const k = `hiring_role|${x.page.url}|${h.quote}`;
        if (byQuote.has(k)) continue;
        const o = obs("hiring_for", h.role, h.quote, x.page.url, x.docId, 0.6, LLM_EXTRACTOR);
        byQuote.set(k, signal("hiring_role", o.id).id);
      }
    }
  }

  // Where the company is based, when the site does not say: the domain's country suffix is a weak hint, kept as an observation only.
  if (!ldCountry) {
    const tld = normalizeDomain(crawl.domain)?.split(".").pop() ?? "";
    if (TLD[tld]) obs("hq_country_guess", TLD[tld]!, crawl.domain, home.url, undefined, 0.4);
  }
  report.locations = store.list<Location>("locations", (x) => x.org_id === org.id).length;

  const label = new Map((pack?.need_types ?? []).map((n) => [n.id, n.label]));
  for (const [needId, ids] of needSignals) {
    store.upsertNeed({ org_id: org.id, need_type: needId, description: `${label.get(needId) ?? needId}: ${ids.size} signal${ids.size === 1 ? "" : "s"} found on the company's own website`, signal_ids: [...ids] });
    report.needs.push({ need_type: needId, signals: ids.size });
  }
  return report;
}
