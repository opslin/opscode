// Industry packs and offering templates. A pack is data only (vocabulary, need types, signals, roles,
// rubric): the engine is the same for every industry. Built-in packs ship here; a person or a plugin can
// install more as JSON files under <state>/leads/packs/. Nothing in a pack is ever executed.

import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { ensurePrivateDir } from "../jsonFile";
import { SIGNAL_TYPE_IDS } from "./ontology";
import type { IndustryPack, Offering, PackNeedType, SignalType } from "./ontology";

const ID = /^[a-z0-9][a-z0-9-]{0,39}$/;
const isRecord = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null && !Array.isArray(v);

function strings(v: unknown, what: string, o: { min?: number; max: number; item: number }): string[] {
  if (!Array.isArray(v)) throw new Error(`${what} must be a list`);
  if (v.length < (o.min ?? 0) || v.length > o.max) throw new Error(`${what} must have ${o.min ?? 0}-${o.max} entries`);
  return v.map((x, i) => {
    if (typeof x !== "string" || !x.trim() || x.length > o.item) throw new Error(`${what}[${i}] must be 1-${o.item} characters`);
    return x.trim();
  });
}

/** Throws a readable Error for anything off; returns a clean copy (unknown keys dropped). */
export function validatePack(v: unknown): IndustryPack {
  if (!isRecord(v)) throw new Error("a pack must be an object");
  const id = v.id;
  if (typeof id !== "string" || !ID.test(id)) throw new Error("id must be lowercase letters, digits and dashes (max 40)");
  if (typeof v.name !== "string" || !v.name.trim() || v.name.length > 80) throw new Error("name must be 1-80 characters");
  const version = v.version;
  if (!Number.isSafeInteger(version) || (version as number) < 1) throw new Error("version must be a whole number from 1");
  const description = typeof v.description === "string" ? v.description.slice(0, 500) : "";
  const needRaw = v.need_types;
  if (!Array.isArray(needRaw) || needRaw.length < 1 || needRaw.length > 40) throw new Error("need_types must have 1-40 entries");
  const seen = new Set<string>();
  const need_types: PackNeedType[] = needRaw.map((n, i) => {
    if (!isRecord(n)) throw new Error(`need_types[${i}] must be an object`);
    if (typeof n.id !== "string" || !ID.test(n.id)) throw new Error(`need_types[${i}].id must be lowercase letters, digits and dashes`);
    if (seen.has(n.id)) throw new Error(`need_types[${i}].id "${n.id}" is used twice`);
    seen.add(n.id);
    if (typeof n.label !== "string" || !n.label.trim() || n.label.length > 100) throw new Error(`need_types[${i}].label must be 1-100 characters`);
    const signals = strings(n.signals, `need_types[${i}].signals`, { min: 1, max: 12, item: 40 });
    for (const s of signals) if (!(SIGNAL_TYPE_IDS as string[]).includes(s)) throw new Error(`need_types[${i}].signals: "${s}" is not a signal type (${SIGNAL_TYPE_IDS.join(", ")})`);
    return { id: n.id, label: n.label.trim(), phrases: strings(n.phrases, `need_types[${i}].phrases`, { max: 40, item: 120 }), signals: signals as SignalType[] };
  });
  const rubricRaw = v.rubric ?? [];
  if (!Array.isArray(rubricRaw) || rubricRaw.length > 30) throw new Error("rubric must be a list of at most 30 criteria");
  const rubric = rubricRaw.map((r, i) => {
    if (!isRecord(r) || typeof r.id !== "string" || !ID.test(r.id) || typeof r.text !== "string" || !r.text.trim() || r.text.length > 400) throw new Error(`rubric[${i}] needs an id and a text of 1-400 characters`);
    return { id: r.id, text: r.text.trim() };
  });
  return {
    id, name: v.name.trim(), version: version as number, description,
    definitions: strings(v.definitions ?? [], "definitions", { max: 60, item: 80 }),
    naics: strings(v.naics ?? [], "naics", { max: 40, item: 10 }),
    need_types,
    buyer_roles: strings(v.buyer_roles ?? [], "buyer_roles", { max: 40, item: 80 }),
    exclude: strings(v.exclude ?? [], "exclude", { max: 40, item: 160 }),
    sources: strings(v.sources ?? [], "sources", { max: 40, item: 80 }),
    rubric,
  };
}

/** The rubric every pack inherits: the all-pass checks from the design (Lead LAB, slice 3 runs them). */
export const CORE_RUBRIC: { id: string; text: string }[] = [
  { id: "evidence-supports-need", text: "The quoted evidence really shows this need; it is not a guess from the company type." },
  { id: "need-is-current", text: "At least one supporting signal is recent enough to still be live." },
  { id: "person-can-buy", text: "The person is an owner, founder or executive, or leads the function that buys this." },
  { id: "geo-matches", text: "The company's headquarters, not only the person, is in a target country." },
  { id: "not-a-competitor", text: "The company does not sell the same service the user sells." },
  { id: "reachable", text: "There is a verified or plausible business email, or another channel the user enabled." },
];

const RESTAURANTS: IndustryPack = {
  id: "restaurants", name: "Restaurants and food service", version: 2,
  description: "Restaurants, cafe groups, cloud kitchens and food businesses that take orders or bookings and are growing.",
  definitions: ["restaurant chain", "cafe group", "cloud kitchen", "food truck fleet", "catering company", "bakery chain"],
  naics: ["7225", "722511", "722513", "722515"],
  need_types: [
    { id: "online-ordering", label: "Online ordering and pickup", phrases: ["call to order", "call us to order", "call to place an order", "order by phone", "order over the phone", "phone orders", "order on whatsapp", "no online ordering", "pickup orders by phone"], signals: ["pain_expressed", "tech_gap", "hiring_role"] },
    { id: "delivery-app", label: "Own delivery or mobile app", phrases: ["we deliver", "delivery on third-party apps", "high commission", "our own app"], signals: ["pain_expressed", "launch", "tech_gap"] },
    { id: "loyalty-app", label: "Loyalty program or app", phrases: ["punch card", "rewards program", "loyalty"], signals: ["launch", "tech_gap"] },
    { id: "table-booking", label: "Table or event booking", phrases: ["reservations by phone", "book a table", "private events enquiries"], signals: ["pain_expressed", "tech_gap"] },
    { id: "multi-location-ops", label: "Multi-location operations system", phrases: ["new location", "second location", "opening soon", "now open in"], signals: ["expansion", "hiring_role"] },
  ],
  buyer_roles: ["owner", "founder", "co-owner", "managing director", "operations director", "head of operations", "marketing director", "general manager (multi-site)"],
  exclude: ["single food stall with no website", "franchise outlet that must use the franchisor's system", "restaurant software vendors"],
  sources: ["website", "maps", "jobs", "review", "news"],
  rubric: [
    { id: "multi-location-or-online", text: "The business has more than one location, or sells online, so a custom system pays off." },
    { id: "not-franchise-locked", text: "It is not a franchise outlet locked into the franchisor's ordering system." },
  ],
};

export class PackRegistry {
  private readonly dir: string;
  constructor(stateDir: string) { this.dir = join(stateDir, "leads", "packs"); ensurePrivateDir(this.dir); }

  /** Built-ins first, then installed packs; an installed pack with a built-in's id is ignored (built-ins cannot be shadowed). */
  list(): (IndustryPack & { builtin: boolean })[] {
    const out: (IndustryPack & { builtin: boolean })[] = [{ ...RESTAURANTS, builtin: true }];
    for (const f of existsSync(this.dir) ? readdirSync(this.dir).sort() : []) {
      if (!f.endsWith(".json")) continue;
      try {
        const p = validatePack(JSON.parse(readFileSync(join(this.dir, f), "utf8")));
        if (!out.some((x) => x.id === p.id)) out.push({ ...p, builtin: false });
      } catch { /* an invalid installed pack is skipped, not fatal */ }
    }
    return out;
  }
  get(id: string): (IndustryPack & { builtin: boolean }) | undefined { return this.list().find((p) => p.id === id); }

  install(raw: unknown): IndustryPack {
    const p = validatePack(raw);
    if (this.list().some((x) => x.id === p.id && x.builtin)) throw new Error(`"${p.id}" is a built-in pack and cannot be replaced`);
    writeFileSync(join(this.dir, `${p.id}.json`), JSON.stringify(p, null, 2) + "\n", { mode: 0o600 });
    return p;
  }
}

/** Which of the offering's need types the pack knows, and which it does not (a typo or a gap in the pack). */
export function matchOffering(offering: Offering, pack: IndustryPack): { covered: { need_type: string; label: string; signals: SignalType[] }[]; unknown: string[]; unserved: string[] } {
  const byId = new Map(pack.need_types.map((n) => [n.id, n]));
  const covered = offering.solves.filter((s) => byId.has(s)).map((s) => ({ need_type: s, label: byId.get(s)!.label, signals: byId.get(s)!.signals }));
  return { covered, unknown: offering.solves.filter((s) => !byId.has(s)), unserved: pack.need_types.filter((n) => !offering.solves.includes(n.id)).map((n) => n.id) };
}

/** The user's own dev-services offering, from their Project docs. A starting point to edit, never saved by itself. */
export const OFFERING_TEMPLATES: Omit<Offering, "id">[] = [
  {
    name: "Custom apps and websites (sayanthecoder.in)",
    summary: "Custom mobile apps (Flutter), websites, e-commerce, ordering and booking systems, CRM/ERP/POS, WhatsApp chatbots and business automation, from design to deployment and support.",
    solves: ["online-ordering", "delivery-app", "loyalty-app", "table-booking", "multi-location-ops"],
    proof: ["Portfolio: https://sayanthecoder.in"],
    pricing_rules: "Project-based and milestone-based. Never promise fixed prices, discounts, free trials or delivery dates without the owner's approval.",
    never_say: ["Do not invent testimonials, client names, business results or project statistics."],
    links: ["https://sayanthecoder.in"],
  },
];
