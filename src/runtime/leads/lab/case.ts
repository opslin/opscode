// A lead case: one frozen, JSON-only snapshot of everything a reviewer needs to decide whether a lead is worth an email.
// It is what the judge reads and what a gold set stores, so a verdict can be repeated later from the same facts.
// buildCase() takes the snapshot from the lead store; nothing here calls a model.

import type { IndustryPack, Offering } from "../ontology";
import type { LeadStore } from "../store";
import type { Location, Organization, Person, Role, Observation } from "../ontology";

export interface CaseEvidence {
  id: string; predicate: string; object: string; quote: string; url: string; seen_at: string; confidence: number; extractor: string;
  signal_type?: string;
  /** True when this quote is part of what supports the need being judged. */
  supports_need: boolean;
}
export interface LeadCase {
  id: string; as_of: string;
  campaign: { geos: string[]; pack_id: string; offering: { name: string; summary: string; solves: string[] } };
  organization: { name: string; domain?: string; hq_country?: string; definition?: string; description?: string; size_band?: string; locations: number; tech: string[] };
  person?: { name: string; title_raw: string; seniority: string; buyer_power: "decides" | "influences" | "user"; country?: string };
  need?: { need_type: string; label: string; description: string; status: string; live: boolean; strength: number };
  evidence: CaseEvidence[];
  signals: { type: string; date: string; strength_now: number; live: boolean }[];
  emails: string[];
}

export interface CaseRequest {
  org_id: string; person_id?: string; need_type?: string;
  campaign: { geos: string[]; pack: IndustryPack; offering: Offering };
  as_of?: Date;
}

/** Takes the snapshot. Evidence that supports the need is the quotes behind the need's own signals. */
export function buildCase(store: LeadStore, r: CaseRequest): LeadCase {
  const asOf = r.as_of ?? new Date();
  const view = store.orgView(r.org_id, asOf);
  const org: Organization = view.organization;
  const need = r.need_type ? view.needs.find((n) => n.need_type === r.need_type) : undefined;
  const supportIds = new Set<string>();
  const sigType = new Map<string, string>();
  if (need) for (const sid of need.signal_ids) {
    const s = view.signals.find((x) => x.id === sid);
    if (!s) continue;
    for (const oid of s.observation_ids) { supportIds.add(oid); sigType.set(oid, s.type); }
  }
  const evidence: CaseEvidence[] = view.observations
    .filter((o: Observation) => supportIds.has(o.id) || ["describes_as", "uses_tech", "definition", "has_location"].includes(o.predicate))
    .map((o) => ({ id: o.id, predicate: o.predicate, object: o.object, quote: o.evidence_quote, url: o.url, seen_at: o.seen_at, confidence: o.confidence, extractor: o.extractor, ...(sigType.get(o.id) ? { signal_type: sigType.get(o.id)! } : {}), supports_need: supportIds.has(o.id) }));
  const pr = r.person_id ? view.people.find((p) => p.person.id === r.person_id) : undefined;
  const person: { person: Person; role: Role } | undefined = pr;
  const emails = [...new Set(view.observations.filter((o) => o.predicate === "has_public_email").map((o) => o.object))];
  const label = r.campaign.pack.need_types.find((n) => n.id === r.need_type)?.label ?? r.need_type ?? "";
  return {
    id: `${r.org_id}:${r.person_id ?? "-"}:${r.need_type ?? "-"}`, as_of: asOf.toISOString(),
    campaign: { geos: r.campaign.geos.map((g) => g.toUpperCase()), pack_id: r.campaign.pack.id, offering: { name: r.campaign.offering.name, summary: r.campaign.offering.summary, solves: r.campaign.offering.solves } },
    organization: {
      name: org.name, ...(org.domains[0] ? { domain: org.domains[0] } : {}), ...(org.hq_country ? { hq_country: org.hq_country } : {}), ...(org.definition ? { definition: org.definition } : {}),
      ...(org.description_short ? { description: org.description_short } : {}), ...(org.size_band ? { size_band: org.size_band } : {}),
      locations: store.list<Location>("locations", (l) => l.org_id === org.id).length, tech: view.observations.filter((o) => o.predicate === "uses_tech").map((o) => o.object),
    },
    ...(person ? { person: { name: person.person.name, title_raw: person.role.title_raw, seniority: person.role.seniority, buyer_power: person.role.buyer_power, ...(person.person.country ? { country: person.person.country } : {}) } } : {}),
    ...(need ? { need: { need_type: need.need_type, label, description: need.description, status: need.status, live: need.live, strength: need.strength } } : {}),
    evidence,
    signals: view.signals.filter((s) => (need ? need.signal_ids.includes(s.id) : true)).map((s) => ({ type: s.type, date: s.date, strength_now: s.strength_now, live: s.live })),
    emails,
  };
}
