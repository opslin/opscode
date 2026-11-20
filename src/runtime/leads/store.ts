// The lead store: one append-only JSONL file per collection, replayed into memory on open. The rules that
// make lead quality checkable live here, not in the callers:
//   * an Observation must carry a quote, a URL and a date, and when it names a stored document the quote
//     must really appear in that document's text;
//   * a Signal must rest on observations about the same organization; a Need must rest on live-checkable signals;
//   * a suppressed email, domain or person can never be added again;
//   * forgetting a person removes everything that came only from them, and suppresses them.
// A Postgres adapter can replace this class later (schema.sql lists the same tables).

import { randomUUID, createHash } from "node:crypto";
import { appendFileSync, chmodSync, existsSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "../jsonFile";
import {
  LIVE_FLOOR, PLATFORMS, SIGNAL_TYPES, SIGNAL_TYPE_IDS, classifyTitle, combine, decayed, isPlaceholderDomain, normalizeDomain, quoteInText,
} from "./ontology";
import type { Account, Doc, Interaction, Interest, Lead, Location, Need, NeedStatus, Observation, Offering, Organization, Person, Platform, Role, Signal, SignalType, Suppression } from "./ontology";

export const COLLECTIONS = ["organizations", "locations", "persons", "roles", "accounts", "documents", "observations", "signals", "needs", "interests", "leads", "interactions", "suppressions", "offerings"] as const;
export type Collection = (typeof COLLECTIONS)[number];
interface Rec { id: string }
type LogLine = { op: "put"; rec: Rec } | { op: "del"; id: string };

export class LeadError extends Error {
  constructor(readonly kind: "invalid" | "not_found" | "conflict" | "suppressed", message: string) { super(message); }
}
const bad = (m: string): LeadError => new LeadError("invalid", m);
const missing = (m: string): LeadError => new LeadError("not_found", m);

const LIMITS = { quote: 600, text: 200_000, name: 200, field: 2_000 } as const;
const IMMUTABLE: ReadonlySet<Collection> = new Set(["documents", "observations", "signals", "suppressions", "interactions"]);
const iso = (d: Date = new Date()): string => d.toISOString();
const isDate = (s: unknown): s is string => typeof s === "string" && s.length >= 10 && !Number.isNaN(new Date(s).getTime());

export interface NeedView extends Need { live: boolean; strength: number }
export interface SignalView extends Signal { strength_now: number; live: boolean }
export interface OrgView { organization: Organization; observations: Observation[]; signals: SignalView[]; needs: NeedView[]; intent: number; people: { person: Person; role: Role }[] }

export class LeadStore {
  private readonly dir: string;
  private readonly data = new Map<Collection, Map<string, Rec>>();
  private readonly lines = new Map<Collection, number>();
  private seen?: Set<string>;

  constructor(stateDir: string) {
    this.dir = join(stateDir, "leads");
    ensurePrivateDir(this.dir);
    for (const c of COLLECTIONS) this.load(c);
  }

  // ---- persistence ----------------------------------------------------------------------------------------
  private file(c: Collection): string { return join(this.dir, `${c}.jsonl`); }

  private load(c: Collection): void {
    const live = new Map<string, Rec>();
    let n = 0;
    if (existsSync(this.file(c))) {
      for (const line of readFileSync(this.file(c), "utf8").split("\n")) {
        if (!line.trim()) continue;
        n++;
        try {
          const l = JSON.parse(line) as LogLine;
          if (l.op === "put" && l.rec && typeof l.rec.id === "string") live.set(l.rec.id, l.rec);
          else if (l.op === "del" && typeof l.id === "string") live.delete(l.id);
        } catch { /* a torn last line from a crash: skip it, keep the rest */ }
      }
    }
    this.data.set(c, live);
    this.lines.set(c, n);
    if (n > live.size * 2 + 100) this.compact(c);
  }

  private compact(c: Collection): void {
    const body = [...this.map(c).values()].map((rec) => JSON.stringify({ op: "put", rec } satisfies LogLine)).join("\n");
    const tmp = `${this.file(c)}.${process.pid}.tmp`;
    writeFileSync(tmp, body ? body + "\n" : "", { mode: 0o600 });
    renameSync(tmp, this.file(c));
    this.lines.set(c, this.map(c).size);
  }

  private write(c: Collection, line: LogLine): void {
    const f = this.file(c);
    const fresh = !existsSync(f);
    appendFileSync(f, JSON.stringify(line) + "\n", { mode: 0o600 });
    if (fresh) chmodSync(f, 0o600);
    this.lines.set(c, (this.lines.get(c) ?? 0) + 1);
  }

  private map(c: Collection): Map<string, Rec> { return this.data.get(c)!; }
  get<T extends Rec>(c: Collection, id: string): T | undefined { return this.map(c).get(id) as T | undefined; }
  list<T extends Rec>(c: Collection, where?: (r: T) => boolean): T[] { const all = [...this.map(c).values()] as T[]; return where ? all.filter(where) : all; }
  count(c: Collection): number { return this.map(c).size; }

  private put(c: Collection, rec: Rec): void {
    if (IMMUTABLE.has(c) && this.map(c).has(rec.id)) throw new LeadError("conflict", `${c} are append-only; ${rec.id} already exists`);
    this.map(c).set(rec.id, rec);
    this.write(c, { op: "put", rec });
  }
  private del(c: Collection, id: string): void {
    if (!this.map(c).delete(id)) return;
    this.write(c, { op: "del", id });
  }

  // ---- model-read pages: remembered so a rescan of an unchanged page does not pay for the model again -----------------------
  private seenFile(): string { return join(this.dir, "llm-seen.json"); }
  private seenSet(): Set<string> {
    if (!this.seen) { const raw = readJson(this.seenFile()); this.seen = new Set(Array.isArray(raw) ? raw.filter((x): x is string => typeof x === "string") : []); }
    return this.seen;
  }
  llmSeen(key: string): boolean { return this.seenSet().has(key); }
  markLlmSeen(key: string): void {
    const s = this.seenSet();
    s.add(key);
    while (s.size > 20_000) s.delete(s.values().next().value as string);
    writeJsonAtomic(this.seenFile(), [...s]);
  }

  // ---- suppression ----------------------------------------------------------------------------------------
  /** What is stored for a suppression. A person is kept as a hash, so forgetting someone does not keep their name. */
  private suppressionKey(kind: Suppression["kind"], value: string): string | undefined {
    if (kind === "domain") return normalizeDomain(value);
    const v = value.trim().toLowerCase();
    if (!v) return undefined;
    return kind === "person" ? createHash("sha256").update(v).digest("hex") : v;
  }
  isSuppressed(kind: Suppression["kind"], value: string): boolean {
    const v = this.suppressionKey(kind, value);
    return v !== undefined && this.list<Suppression>("suppressions").some((s) => s.kind === kind && s.value === v);
  }
  suppress(kind: Suppression["kind"], value: string, reason: string): Suppression {
    const v = this.suppressionKey(kind, value);
    if (!v) throw bad(`not a valid ${kind}`);
    const have = this.list<Suppression>("suppressions").find((s) => s.kind === kind && s.value === v);
    if (have) return have;
    const s: Suppression = { id: randomUUID(), kind, value: v, reason: reason.slice(0, 300), created_at: iso() };
    this.put("suppressions", s);
    return s;
  }

  // ---- organizations ----------------------------------------------------------------------------------------
  upsertOrganization(i: { name: string; domain?: string; hq_country?: string; size_band?: string; industry_codes?: string[]; definition?: string; description_short?: string; founded?: number }): Organization {
    const name = i.name.trim();
    if (!name || name.length > LIMITS.name) throw bad("name must be 1-200 characters");
    let domain: string | undefined;
    if (i.domain !== undefined && i.domain.trim() !== "") {
      domain = normalizeDomain(i.domain);
      if (!domain) throw bad("domain is not a valid website domain");
      if (isPlaceholderDomain(domain)) throw bad(`${domain} is a builder, social or placeholder site, not the company's own domain`);
      if (this.isSuppressed("domain", domain)) throw new LeadError("suppressed", `${domain} is suppressed`);
    }
    const country = i.hq_country?.toUpperCase();
    if (country !== undefined && !/^[A-Z]{2}$/.test(country)) throw bad("hq_country must be a 2-letter ISO code");
    const found = domain
      ? this.list<Organization>("organizations").find((o) => o.domains.includes(domain!))
      : this.list<Organization>("organizations").find((o) => o.name.toLowerCase() === name.toLowerCase() && (o.hq_country ?? "") === (country ?? ""));
    const now = iso();
    if (found) {
      const next: Organization = { ...found, updated_at: now };
      if (domain && !next.domains.includes(domain)) next.domains = [...next.domains, domain];
      // Fill what is missing; a value the caller supplies replaces the old one (newer evidence wins).
      if (country) next.hq_country = country;
      if (i.size_band) next.size_band = i.size_band;
      if (i.industry_codes?.length) next.industry_codes = [...new Set([...(next.industry_codes ?? []), ...i.industry_codes])];
      if (i.definition) next.definition = i.definition;
      if (i.description_short) next.description_short = i.description_short.slice(0, 400);
      if (i.founded) next.founded = i.founded;
      this.map("organizations").set(next.id, next);
      this.write("organizations", { op: "put", rec: next });
      return next;
    }
    const org: Organization = {
      id: randomUUID(), name, domains: domain ? [domain] : [], ...(country ? { hq_country: country } : {}), ...(i.size_band ? { size_band: i.size_band } : {}),
      ...(i.industry_codes?.length ? { industry_codes: i.industry_codes } : {}), ...(i.definition ? { definition: i.definition } : {}),
      ...(i.description_short ? { description_short: i.description_short.slice(0, 400) } : {}), ...(i.founded ? { founded: i.founded } : {}), created_at: now, updated_at: now,
    };
    this.put("organizations", org);
    return org;
  }

  // ---- people ---------------------------------------------------------------------------------------------
  upsertPerson(i: { name: string; org_id: string; title_raw: string; country?: string; email?: string }): { person: Person; role: Role } {
    if (!this.get("organizations", i.org_id)) throw missing("organization not found");
    const name = i.name.trim();
    if (!name || name.length > LIMITS.name) throw bad("name must be 1-200 characters");
    if (i.email && this.isSuppressed("email", i.email)) throw new LeadError("suppressed", "that email is suppressed");
    if (this.isSuppressed("person", `${name.toLowerCase()}|${i.org_id}`)) throw new LeadError("suppressed", "that person asked to be forgotten");
    const existing = this.list<Role>("roles", (r) => r.org_id === i.org_id).map((r) => ({ r, p: this.get<Person>("persons", r.person_id)! })).find((x) => x.p && x.p.name.toLowerCase() === name.toLowerCase());
    const cls = classifyTitle(i.title_raw);
    if (existing) {
      const role: Role = { ...existing.r, title_raw: i.title_raw.slice(0, 200), ...cls };
      this.map("roles").set(role.id, role);
      this.write("roles", { op: "put", rec: role });
      return { person: existing.p, role };
    }
    const person: Person = { id: randomUUID(), name, ...(i.country ? { country: i.country.toUpperCase() } : {}), created_at: iso() };
    const role: Role = { id: randomUUID(), person_id: person.id, org_id: i.org_id, title_raw: i.title_raw.slice(0, 200), ...cls };
    this.put("persons", person);
    this.put("roles", role);
    return { person, role };
  }

  addAccount(i: { person_id?: string; org_id?: string; platform: Platform; handle: string; url?: string; link_proof: string }): Account {
    if (!i.person_id && !i.org_id) throw bad("an account belongs to a person or an organization");
    if (i.person_id && !this.get("persons", i.person_id)) throw missing("person not found");
    if (i.org_id && !this.get("organizations", i.org_id)) throw missing("organization not found");
    if (!(PLATFORMS as readonly string[]).includes(i.platform)) throw bad("unknown platform");
    if (!i.link_proof.trim()) throw bad("link_proof is required: say why this handle belongs to them (their site links to it, it links back, ...)");
    const a: Account = { id: randomUUID(), ...(i.person_id ? { person_id: i.person_id } : {}), ...(i.org_id ? { org_id: i.org_id } : {}), platform: i.platform, handle: i.handle.trim().slice(0, 200), ...(i.url ? { url: i.url } : {}), link_proof: i.link_proof.trim().slice(0, 500) };
    this.put("accounts", a);
    return a;
  }

  // ---- documents and observations ---------------------------------------------------------------------------------------
  /** Stores a fetched page once: the same URL with the same text returns the document already held. */
  addDocument(i: { platform: Platform; url: string; text: string; published_at?: string; author_account_id?: string; language?: string }): Doc {
    if (!(PLATFORMS as readonly string[]).includes(i.platform)) throw bad("unknown platform");
    if (!/^https?:\/\/[^\s]+$/i.test(i.url)) throw bad("url must be an http(s) address");
    if (i.text.length === 0 || i.text.length > LIMITS.text) throw bad("text must be 1-200000 characters");
    if (i.published_at !== undefined && !isDate(i.published_at)) throw bad("published_at is not a date");
    if (i.author_account_id && !this.get("accounts", i.author_account_id)) throw missing("author account not found");
    const hash = createHash("sha256").update(i.text).digest("hex");
    const same = this.list<Doc>("documents", (d) => d.url === i.url && d.hash === hash)[0];
    if (same) return same;
    const doc: Doc = { id: randomUUID(), platform: i.platform, url: i.url, text: i.text, hash, ...(i.published_at ? { published_at: i.published_at } : {}), fetched_at: iso(), ...(i.author_account_id ? { author_account_id: i.author_account_id } : {}), ...(i.language ? { language: i.language } : {}) };
    this.put("documents", doc);
    return doc;
  }

  observe(i: { subject_type: Observation["subject_type"]; subject_id: string; predicate: string; object: string; evidence_quote: string; url: string; document_id?: string; seen_at?: string; valid_from?: string; valid_to?: string; confidence: number; extractor: string }): Observation {
    const subj = i.subject_type === "organization" ? this.get("organizations", i.subject_id) : this.get("persons", i.subject_id);
    if (!subj) throw missing(`${i.subject_type} not found`);
    if (!i.predicate.trim() || i.predicate.length > 100) throw bad("predicate must be 1-100 characters");
    if (!i.object.trim() || i.object.length > LIMITS.field) throw bad("object must be 1-2000 characters");
    const quote = i.evidence_quote.trim();
    if (!quote) throw bad("evidence_quote is required: an observation without a quote is a guess");
    if (quote.length > LIMITS.quote) throw bad(`evidence_quote can be at most ${LIMITS.quote} characters`);
    if (!/^https?:\/\/[^\s]+$/i.test(i.url) && !/^manual:/.test(i.url)) throw bad("url must be an http(s) address, or manual:<note> for something the user entered");
    if (!Number.isFinite(i.confidence) || i.confidence < 0 || i.confidence > 1) throw bad("confidence must be between 0 and 1");
    if (!i.extractor.trim()) throw bad("extractor is required (which tool or model produced this)");
    for (const d of [i.seen_at, i.valid_from, i.valid_to]) if (d !== undefined && !isDate(d)) throw bad("dates must be ISO dates");
    if (i.document_id) {
      const doc = this.get<Doc>("documents", i.document_id);
      if (!doc) throw missing("document not found");
      if (!quoteInText(quote, doc.text)) throw bad("the quote does not appear in that document");
    }
    const o: Observation = { id: randomUUID(), subject_type: i.subject_type, subject_id: i.subject_id, predicate: i.predicate.trim(), object: i.object.trim(), evidence_quote: quote, url: i.url, ...(i.document_id ? { document_id: i.document_id } : {}), seen_at: i.seen_at ?? iso(), ...(i.valid_from ? { valid_from: i.valid_from } : {}), ...(i.valid_to ? { valid_to: i.valid_to } : {}), confidence: i.confidence, extractor: i.extractor.trim() };
    this.put("observations", o);
    return o;
  }

  /** Like observe(), but a second scan of the same page returns the observation already held instead of adding a duplicate. */
  observeOnce(i: Parameters<LeadStore["observe"]>[0]): Observation {
    const same = this.list<Observation>("observations", (o) => o.subject_type === i.subject_type && o.subject_id === i.subject_id && o.predicate === i.predicate.trim() && o.object === i.object.trim() && o.url === i.url && o.extractor === i.extractor.trim())[0];
    return same ?? this.observe(i);
  }

  // ---- signals and needs ---------------------------------------------------------------------------------------------
  addSignal(i: { org_id: string; type: SignalType; observation_ids: string[]; date?: string; strength?: number }): Signal {
    if (!this.get("organizations", i.org_id)) throw missing("organization not found");
    if (!SIGNAL_TYPE_IDS.includes(i.type)) throw bad(`type must be one of: ${SIGNAL_TYPE_IDS.join(", ")}`);
    if (!i.observation_ids.length) throw bad("a signal needs at least one observation as evidence");
    for (const oid of i.observation_ids) {
      const o = this.get<Observation>("observations", oid);
      if (!o) throw missing(`observation ${oid} not found`);
      if (o.subject_type !== "organization" || o.subject_id !== i.org_id) throw bad(`observation ${oid} is not about this organization`);
    }
    if (i.date !== undefined && !isDate(i.date)) throw bad("date is not a date");
    const strength = i.strength ?? SIGNAL_TYPES[i.type].strength;
    if (!Number.isFinite(strength) || strength < 0 || strength > 1) throw bad("strength must be between 0 and 1");
    const s: Signal = { id: randomUUID(), org_id: i.org_id, type: i.type, date: i.date ?? iso(), strength, observation_ids: [...new Set(i.observation_ids)] };
    this.put("signals", s);
    return s;
  }

  /** Like addSignal(), but a signal of the same type already resting on the same first observation is returned as it is. */
  addSignalOnce(i: Parameters<LeadStore["addSignal"]>[0]): Signal {
    const same = this.list<Signal>("signals", (s) => s.org_id === i.org_id && s.type === i.type && i.observation_ids.length > 0 && s.observation_ids.includes(i.observation_ids[0]!))[0];
    return same ?? this.addSignal(i);
  }

  upsertNeed(i: { org_id: string; need_type: string; description: string; status?: NeedStatus; signal_ids: string[] }): Need {
    if (!this.get("organizations", i.org_id)) throw missing("organization not found");
    if (!i.need_type.trim() || i.need_type.length > 80) throw bad("need_type must be 1-80 characters");
    if (!i.description.trim() || i.description.length > LIMITS.field) throw bad("description must be 1-2000 characters");
    if (!i.signal_ids.length) throw bad("a need needs at least one signal as evidence");
    let first = iso(), last = "";
    for (const sid of i.signal_ids) {
      const s = this.get<Signal>("signals", sid);
      if (!s) throw missing(`signal ${sid} not found`);
      if (s.org_id !== i.org_id) throw bad(`signal ${sid} is about another organization`);
      if (s.date < first) first = s.date;
      if (s.date > last) last = s.date;
    }
    const have = this.list<Need>("needs", (n) => n.org_id === i.org_id && n.need_type === i.need_type)[0];
    const need: Need = have
      ? { ...have, description: i.description.trim(), status: i.status ?? have.status, signal_ids: [...new Set([...have.signal_ids, ...i.signal_ids])], first_seen: have.first_seen < first ? have.first_seen : first, last_seen: have.last_seen > last ? have.last_seen : last }
      : { id: randomUUID(), org_id: i.org_id, need_type: i.need_type.trim(), description: i.description.trim(), status: i.status ?? "open", first_seen: first, last_seen: last, signal_ids: [...new Set(i.signal_ids)] };
    this.map("needs").set(need.id, need);
    this.write("needs", { op: "put", rec: need });
    return need;
  }

  // ---- the view an agent or the UI reads ------------------------------------------------------------------------------------------------
  orgView(orgId: string, asOf: Date = new Date()): OrgView {
    const organization = this.get<Organization>("organizations", orgId);
    if (!organization) throw missing("organization not found");
    const signals: SignalView[] = this.list<Signal>("signals", (s) => s.org_id === orgId).map((s) => {
      const strength_now = decayed(s.strength, s.type, s.date, asOf);
      return { ...s, strength_now: Math.round(strength_now * 1000) / 1000, live: strength_now >= LIVE_FLOOR };
    });
    const bySignal = new Map(signals.map((s) => [s.id, s]));
    const needs: NeedView[] = this.list<Need>("needs", (n) => n.org_id === orgId).map((n) => {
      const parts = n.signal_ids.map((id) => bySignal.get(id)).filter((s): s is SignalView => !!s);
      const strength = combine(parts.map((s) => s.strength_now));
      // A need is current only while something still supports it, and only if nobody marked it solved.
      return { ...n, strength: Math.round(strength * 1000) / 1000, live: n.status !== "solved" && parts.some((s) => s.live) };
    });
    const people = this.list<Role>("roles", (r) => r.org_id === orgId).map((role) => ({ person: this.get<Person>("persons", role.person_id)!, role })).filter((x) => x.person);
    return {
      organization, signals, needs, people,
      observations: this.list<Observation>("observations", (o) => o.subject_type === "organization" && o.subject_id === orgId),
      intent: Math.round(combine(signals.filter((s) => s.live).map((s) => s.strength_now)) * 1000) / 1000,
    };
  }

  // ---- offerings -----------------------------------------------------------------------------------------------------------
  saveOffering(o: Omit<Offering, "id"> & { id?: string }): Offering {
    if (!o.name.trim() || o.name.length > 100) throw bad("name must be 1-100 characters");
    if (!o.summary.trim() || o.summary.length > LIMITS.field) throw bad("summary must be 1-2000 characters");
    if (!o.solves.length) throw bad("solves must name at least one need type");
    const id = o.id ?? randomUUID();
    if (o.id && !this.get("offerings", o.id)) throw missing("offering not found");
    const rec: Offering = { id, name: o.name.trim(), summary: o.summary.trim(), solves: [...new Set(o.solves)], proof: o.proof, pricing_rules: o.pricing_rules, never_say: o.never_say, links: o.links };
    this.map("offerings").set(id, rec);
    this.write("offerings", { op: "put", rec });
    return rec;
  }

  // ---- forgetting a person ---------------------------------------------------------------------------------------------------------------------
  /** Removes a person and everything that came only from them, then suppresses them so a later import cannot bring them back. */
  forgetPerson(personId: string): { removed: Record<string, number> } {
    const person = this.get<Person>("persons", personId);
    if (!person) throw missing("person not found");
    const removed: Record<string, number> = {};
    const bump = (k: string): void => { removed[k] = (removed[k] ?? 0) + 1; };
    const roles = this.list<Role>("roles", (r) => r.person_id === personId);
    for (const r of roles) { this.suppress("person", `${person.name.toLowerCase()}|${r.org_id}`, "forgotten on request"); this.del("roles", r.id); bump("roles"); }
    const accounts = this.list<Account>("accounts", (a) => a.person_id === personId);
    const accountIds = new Set(accounts.map((a) => a.id));
    // Immutable collections are append-only for normal writes; forgetting is the one allowed deletion.
    const docs = this.list<Doc>("documents", (d) => !!d.author_account_id && accountIds.has(d.author_account_id));
    const docIds = new Set(docs.map((d) => d.id));
    const obs = this.list<Observation>("observations", (o) => (o.subject_type === "person" && o.subject_id === personId) || (!!o.document_id && docIds.has(o.document_id)));
    const obsIds = new Set(obs.map((o) => o.id));
    for (const o of obs) { this.del("observations", o.id); bump("observations"); }
    for (const d of docs) { this.del("documents", d.id); bump("documents"); }
    for (const a of accounts) { this.del("accounts", a.id); bump("accounts"); }
    // A signal loses the evidence that was removed; with none left it goes, and so does a need with no signals left.
    const goneSignals = new Set<string>();
    for (const s of this.list<Signal>("signals", (x) => x.observation_ids.some((id) => obsIds.has(id)))) {
      const left = s.observation_ids.filter((id) => !obsIds.has(id));
      if (left.length === 0) { this.del("signals", s.id); goneSignals.add(s.id); bump("signals"); }
      else { const next = { ...s, observation_ids: left }; this.map("signals").set(s.id, next); this.write("signals", { op: "put", rec: next }); }
    }
    for (const n of this.list<Need>("needs", (x) => x.signal_ids.some((id) => goneSignals.has(id)))) {
      const left = n.signal_ids.filter((id) => !goneSignals.has(id));
      if (left.length === 0) { this.del("needs", n.id); bump("needs"); }
      else { const next = { ...n, signal_ids: left }; this.map("needs").set(n.id, next); this.write("needs", { op: "put", rec: next }); }
    }
    for (const i of this.list<Interest>("interests", (x) => x.subject_id === personId)) { this.del("interests", i.id); bump("interests"); }
    const leads = this.list<Lead>("leads", (l) => l.person_id === personId);
    const leadIds = new Set(leads.map((l) => l.id));
    for (const x of this.list<Interaction>("interactions", (i) => leadIds.has(i.lead_id))) { this.del("interactions", x.id); bump("interactions"); }
    for (const l of leads) { this.del("leads", l.id); bump("leads"); }
    this.del("persons", personId); bump("persons");
    return { removed };
  }

  stats(): Record<Collection, number> { return Object.fromEntries(COLLECTIONS.map((c) => [c, this.count(c)])) as Record<Collection, number>; }
  /** Locations are stored for completeness; only the website scout (slice 2) writes them. */
  addLocation(l: Omit<Location, "id">): Location {
    if (!this.get("organizations", l.org_id)) throw missing("organization not found");
    const rec: Location = { id: randomUUID(), ...l };
    this.put("locations", rec);
    return rec;
  }
}
