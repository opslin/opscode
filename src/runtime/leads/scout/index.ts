// The website scout: crawl a company's site politely, then write what it found into the lead store.

import type { IndustryPack } from "../ontology";
import { isPlaceholderDomain, normalizeDomain } from "../ontology";
import type { LeadStore } from "../store";
import { crawlSite } from "./crawl";
import type { CrawlOpts } from "./crawl";
import { extractSite } from "./extract";
import type { LlmOpts, ScoutReport } from "./extract";

export type { ScoutReport } from "./extract";
export { isPublicAddress, parseRobots, USER_AGENT } from "./net";
export { findChrome, renderPage, needsRender } from "./render";
export { makeComplete } from "./llm";
export type { Complete } from "./llm";

export const emptyScout = (domain: string, error: string): ScoutReport => empty(domain, "unreachable", error);
const empty = (domain: string, status: ScoutReport["status"], error: string): ScoutReport => ({ domain, status, error, pages: [], render: { used: 0, failed: [] }, skipped: [], llm: { enabled: false, calls: 0, cached: 0, rejected: 0, errors: 0, skipped_budget: 0, injection_suspected: [] }, observations: 0, signals: {}, needs: [], tech: [], emails: [], phones: [], locations: 0 });

export async function scoutWebsite(store: LeadStore, rawDomain: string, pack: IndustryPack | undefined, opts: CrawlOpts & { now?: Date; llm?: LlmOpts } = {}): Promise<ScoutReport> {
  const domain = normalizeDomain(rawDomain);
  if (!domain) return empty(rawDomain, "invalid", "not a valid website domain");
  if (isPlaceholderDomain(domain)) return empty(domain, "invalid", "a builder, social or placeholder site, not the company's own domain");
  // A suppressed domain is never contacted at all: checked before the first request.
  if (store.isSuppressed("domain", domain)) return empty(domain, "suppressed", "this domain is suppressed");
  const crawl = await crawlSite(domain, opts);
  return extractSite(store, crawl, pack, opts.now, opts.llm);
}
