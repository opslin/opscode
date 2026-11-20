// The lead ontology (docs/lead-intelligence-design.md §2). Plain types and pure helpers: no disk, no
// network. Every fact about an organization or a person is an Observation that carries its own evidence
// (a quote, a URL and a date); signals, needs and leads point back at observations and never stand alone.

export const PLATFORMS = ["website", "maps", "jobs", "reddit", "x", "news", "registry", "tender", "hn", "github", "review", "vendor", "manual", "other"] as const;
export type Platform = (typeof PLATFORMS)[number];

export interface Organization {
  id: string; name: string; domains: string[]; hq_country?: string; size_band?: string;
  industry_codes?: string[]; /** Short LLM-made company-type label, e.g. "restaurant chain". */ definition?: string;
  description_short?: string; founded?: number; created_at: string; updated_at: string;
}
export interface Location { id: string; org_id: string; city?: string; country?: string; address?: string; phone?: string; opened_at?: string }
export interface Person { id: string; name: string; country?: string; created_at: string }
export type BuyerPower = "decides" | "influences" | "user";
export interface Role { id: string; person_id: string; org_id: string; title_raw: string; seniority: "owner" | "executive" | "director" | "manager" | "staff"; buyer_power: BuyerPower; start?: string; end?: string }
export interface Account { id: string; person_id?: string; org_id?: string; platform: Platform; handle: string; url?: string; /** Why we believe this handle belongs to them (§6). Required. */ link_proof: string }
export interface Doc { id: string; platform: Platform; url: string; text: string; hash: string; published_at?: string; fetched_at: string; author_account_id?: string; language?: string }

export type SubjectType = "organization" | "person";
export interface Observation {
  id: string; subject_type: SubjectType; subject_id: string; predicate: string; object: string;
  evidence_quote: string; url: string; document_id?: string; seen_at: string;
  valid_from?: string; valid_to?: string; confidence: number; extractor: string;
}

export const SIGNAL_TYPES = {
  hiring_role: { half_life_days: 45, strength: 0.7 },
  expansion: { half_life_days: 120, strength: 0.6 },
  launch: { half_life_days: 60, strength: 0.6 },
  pain_expressed: { half_life_days: 30, strength: 0.7 },
  request_for_help: { half_life_days: 14, strength: 0.9 },
  rfp_tender: { half_life_days: 45, strength: 0.9 },
  tech_change: { half_life_days: 90, strength: 0.5 },
  tech_gap: { half_life_days: 90, strength: 0.5 },
  negative_review_ops: { half_life_days: 60, strength: 0.5 },
  funding: { half_life_days: 120, strength: 0.5 },
  leadership_change: { half_life_days: 90, strength: 0.4 },
  competitor_churn: { half_life_days: 21, strength: 0.8 },
} as const;
export type SignalType = keyof typeof SIGNAL_TYPES;
export const SIGNAL_TYPE_IDS = Object.keys(SIGNAL_TYPES) as SignalType[];

export interface Signal { id: string; org_id: string; type: SignalType; date: string; strength: number; observation_ids: string[] }
export type NeedStatus = "open" | "in_progress" | "solved";
export interface Need { id: string; org_id: string; need_type: string; description: string; status: NeedStatus; first_seen: string; last_seen: string; signal_ids: string[] }
export interface Interest { id: string; subject_id: string; topic: string; stance: "positive" | "negative" | "neutral"; last_seen: string; observation_ids: string[] }
export interface Interaction { id: string; lead_id: string; channel: "email" | "linkedin" | "whatsapp"; direction: "sent" | "reply"; intent?: string; text: string; at: string }
export interface Lead { id: string; person_id: string; org_id: string; need_id: string; offering_id: string; scores: Record<string, number>; reasons: string[]; rubric?: Record<string, boolean>; created_at: string }
export interface Suppression { id: string; kind: "email" | "domain" | "person"; value: string; reason: string; created_at: string }

export interface PackNeedType { id: string; label: string; phrases: string[]; signals: SignalType[] }
export interface IndustryPack {
  id: string; name: string; version: number; description: string;
  definitions: string[]; naics: string[]; need_types: PackNeedType[]; buyer_roles: string[]; exclude: string[]; sources: string[];
  rubric: { id: string; text: string }[];
}
export interface Offering { id: string; name: string; summary: string; solves: string[]; proof: string[]; pricing_rules: string; never_say: string[]; links: string[] }

// ---- pure helpers -------------------------------------------------------------------------------------------

const DAY = 86_400_000;

/** Strength after decay: halves every `half_life_days`. A signal dated in the future counts at full strength. */
export function decayed(strength: number, type: SignalType, date: string, asOf: Date): number {
  const age = Math.max(0, (asOf.getTime() - new Date(date).getTime()) / DAY);
  return strength * Math.pow(0.5, age / SIGNAL_TYPES[type].half_life_days);
}
/** A signal is live while its decayed strength is still at least this. */
export const LIVE_FLOOR = 0.15;

/** Several independent signals add up without passing 1: 1 - Π(1 - sᵢ). */
export const combine = (values: number[]): number => 1 - values.reduce((p, s) => p * (1 - Math.min(1, Math.max(0, s))), 1);

/** Sites that are a template, a builder subdomain or a shortener, not a company's own domain. */
const PLACEHOLDER = /(^|\.)(atom\.com|godaddysites\.com|weebly\.com|wordpress\.com|blogspot\.com|business\.site|wixsite\.com|squarespace\.com|myshopify\.com|square\.site|amzn\.to|temu\.com|linktr\.ee|facebook\.com|instagram\.com|linkedin\.com)$/i;

/** "https://www.Example.com/path?x" -> "example.com"; undefined if it is not a usable company domain. */
export function normalizeDomain(input: string): string | undefined {
  let s = input.trim().toLowerCase();
  if (!s) return undefined;
  s = s.replace(/^[a-z]+:\/\//, "").replace(/^www\./, "").split(/[/?#:]/)[0] ?? "";
  if (!/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/.test(s)) return undefined;
  return s;
}
export const isPlaceholderDomain = (domain: string): boolean => PLACEHOLDER.test(domain);

const norm = (s: string): string => s.toLowerCase().replace(/[\s ]+/g, " ").replace(/[“”"‘’']/g, "'").trim();
/** Is `quote` really in `text`? Whitespace, case and quote style are ignored; nothing else is. */
export const quoteInText = (quote: string, text: string): boolean => { const q = norm(quote); return q.length > 0 && norm(text).includes(q); };

/** Seniority and buying power from a raw job title. Title only: it decides who we write to, not what we assume about them. */
export function classifyTitle(title: string): { seniority: Role["seniority"]; buyer_power: BuyerPower } {
  const t = title.toLowerCase();
  if (/\b(owner|co-?owner|founder|co-?founder|proprietor|propietario|propri[eé]taire|managing partner)\b/.test(t)) return { seniority: "owner", buyer_power: "decides" };
  if (/\b(ceo|chief executive|president|managing director|chief [a-z]+ officer|cto|coo|cfo|cmo)\b/.test(t)) return { seniority: "executive", buyer_power: "decides" };
  if (/\b(director|head of|vp|vice president)\b/.test(t)) return { seniority: "director", buyer_power: "influences" };
  if (/\bmanager\b/.test(t)) return { seniority: "manager", buyer_power: "influences" };
  return { seniority: "staff", buyer_power: "user" };
}
