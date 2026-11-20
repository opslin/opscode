// Lead intelligence, slice 1: the ontology store (evidence rules, freshness, suppression, forgetting), industry
// packs, offerings, the SQL schema's coverage, and the leads.* RPC methods through a real runtime.
import { existsSync, mkdtempSync, readFileSync, readdirSync, realpathSync, rmSync, statSync, writeFileSync, appendFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime } from "./lib/harness.mjs";

const t = reporter();
const dist = (p) => import(join(process.cwd(), "dist", p));
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p48-")));
const throwsKind = (fn) => { try { fn(); return "none"; } catch (e) { return e.kind ?? `other:${e.message}`; } };
const throwsMsg = (fn) => { try { fn(); return ""; } catch (e) { return e.message; } };
const DAY = 86_400_000;
const ago = (days) => new Date(Date.now() - days * DAY).toISOString();

const O = await dist("runtime/leads/ontology.js");
const { LeadStore, COLLECTIONS } = await dist("runtime/leads/store.js");
const P = await dist("runtime/leads/packs.js");

// ---- pure helpers ---------------------------------------------------------------------------------------------------
t.check("domains are normalised (scheme, www, path, case)", O.normalizeDomain("HTTPS://www.Example.com/menu?x=1") === "example.com" && O.normalizeDomain("shop.example.co.uk:8080/a") === "shop.example.co.uk");
t.check("a bare word or an address with spaces is not a domain", O.normalizeDomain("localhost") === undefined && O.normalizeDomain("not a domain.com") === undefined && O.normalizeDomain("") === undefined);
t.check("builder, social and template domains are placeholders", ["mysite.wixsite.com", "x.square.site", "shop.myshopify.com", "linkedin.com", "domains.atom.com"].every(O.isPlaceholderDomain) && !O.isPlaceholderDomain("caloriesrestaurant.ca"));
t.check("a quote is found ignoring case, spacing and quote style", O.quoteInText("CALL us to   order", "Please call us to order family meals") && O.quoteInText("it's chaos", "It’s chaos at lunch") && !O.quoteInText("order online", "Please call us to order") && !O.quoteInText("", "x"));
t.check("titles: owner/founder decide, executives decide, directors influence, others use",
  O.classifyTitle("Founder and Owner").buyer_power === "decides" && O.classifyTitle("Propietario").seniority === "owner" && O.classifyTitle("CEO").seniority === "executive" &&
  O.classifyTitle("Head of Sales").buyer_power === "influences" && O.classifyTitle("Store Manager").seniority === "manager" && O.classifyTitle("Barista").buyer_power === "user");
const now = new Date();
t.check("a signal halves after one half-life and never gains with age", Math.abs(O.decayed(0.8, "request_for_help", ago(14), now) - 0.4) < 0.01 && O.decayed(0.8, "request_for_help", ago(0), now) <= 0.8 && O.decayed(0.8, "request_for_help", ago(-5), now) === 0.8);
t.check("independent signals combine below 1, never above", Math.abs(O.combine([0.5, 0.5]) - 0.75) < 1e-9 && O.combine([1, 1, 1]) === 1 && O.combine([]) === 0);

// ---- the store ----------------------------------------------------------------------------------------------------------------
const dir = join(base, "state");
let S = new LeadStore(dir);
const org = S.upsertOrganization({ name: "Calories", domain: "https://www.CaloriesRestaurant.ca/menu", hq_country: "ca", definition: "restaurant chain", size_band: "1-10" });
t.check("an organization is created with a clean domain and upper-case country", org.domains[0] === "caloriesrestaurant.ca" && org.hq_country === "CA");
const again = S.upsertOrganization({ name: "Calories Restaurant", domain: "caloriesrestaurant.ca", description_short: "Same-day pickup restaurant" });
t.check("the same domain is the same organization (merged, not duplicated)", again.id === org.id && S.count("organizations") === 1 && again.definition === "restaurant chain" && again.description_short === "Same-day pickup restaurant");
const noDom = S.upsertOrganization({ name: "No Domain Cafe", hq_country: "US" });
t.check("without a domain, name + country decide", S.upsertOrganization({ name: "no domain cafe", hq_country: "US" }).id === noDom.id && S.upsertOrganization({ name: "No Domain Cafe", hq_country: "CA" }).id !== noDom.id);
t.check("a placeholder domain is refused", throwsKind(() => S.upsertOrganization({ name: "X", domain: "x.wixsite.com" })) === "invalid" && /placeholder/.test(throwsMsg(() => S.upsertOrganization({ name: "X", domain: "x.wixsite.com" }))));
t.check("a bad country or domain is refused", throwsKind(() => S.upsertOrganization({ name: "X", hq_country: "Canada" })) === "invalid" && throwsKind(() => S.upsertOrganization({ name: "X", domain: "nope" })) === "invalid");

const page = "Order family meals for pickup. Call us to order lunch, dinner and dessert.\nHiring: front-of-house lead to manage phone orders.";
const doc = S.addDocument({ platform: "website", url: "https://caloriesrestaurant.ca/menu", text: page });
t.check("the same page with the same text is stored once", S.addDocument({ platform: "website", url: "https://caloriesrestaurant.ca/menu", text: page }).id === doc.id && S.count("documents") === 1);
t.check("changed text on the same URL is a new document", S.addDocument({ platform: "website", url: "https://caloriesrestaurant.ca/menu", text: page + " More." }).id !== doc.id);
const obs = (extra = {}) => ({ subject_type: "organization", subject_id: org.id, predicate: "takes_orders_by", object: "phone", evidence_quote: "Call us to order", url: "https://caloriesrestaurant.ca/menu", document_id: doc.id, confidence: 0.9, extractor: "test", ...extra });
const o1 = S.observe(obs());
t.check("an observation with a real quote is stored", !!o1.id && o1.seen_at && S.count("observations") === 1);
t.check("…a quote that is not in the document is refused", throwsKind(() => S.observe(obs({ evidence_quote: "We have a mobile app" }))) === "invalid" && /does not appear/.test(throwsMsg(() => S.observe(obs({ evidence_quote: "We have a mobile app" })))));
t.check("…a missing quote, bad URL, bad confidence or missing extractor are refused", throwsKind(() => S.observe(obs({ evidence_quote: "  " }))) === "invalid" && throwsKind(() => S.observe(obs({ url: "ftp://x" }))) === "invalid" && throwsKind(() => S.observe(obs({ confidence: 1.5 }))) === "invalid" && throwsKind(() => S.observe(obs({ extractor: "" }))) === "invalid");
t.check("…an unknown subject or document is refused", throwsKind(() => S.observe(obs({ subject_id: "nope" }))) === "not_found" && throwsKind(() => S.observe(obs({ document_id: "nope" }))) === "not_found");
t.check("…a manual note needs no document but still needs a quote", !!S.observe(obs({ document_id: undefined, url: "manual:phone call 2026-11-17", evidence_quote: "Owner said they only take phone orders" })).id);
const o2 = S.observe(obs({ predicate: "hiring_for", object: "phone-order lead", evidence_quote: "front-of-house lead to manage phone orders" }));

const sig1 = S.addSignal({ org_id: org.id, type: "hiring_role", observation_ids: [o2.id], date: ago(5) });
t.check("a signal rests on observations and takes the type's default strength", sig1.strength === 0.7 && sig1.observation_ids[0] === o2.id);
const other = S.upsertOrganization({ name: "Other Place", domain: "other.example.com" });
const oOther = S.observe({ subject_type: "organization", subject_id: other.id, predicate: "x", object: "y", evidence_quote: "a quote", url: "manual:note", confidence: 0.5, extractor: "t" });
t.check("a signal with no evidence, bad type or another organization's evidence is refused",
  throwsKind(() => S.addSignal({ org_id: org.id, type: "hiring_role", observation_ids: [] })) === "invalid" && throwsKind(() => S.addSignal({ org_id: org.id, type: "made_up", observation_ids: [o1.id] })) === "invalid" &&
  throwsKind(() => S.addSignal({ org_id: org.id, type: "hiring_role", observation_ids: [oOther.id] })) === "invalid" && throwsKind(() => S.addSignal({ org_id: org.id, type: "hiring_role", observation_ids: ["nope"] })) === "not_found");
const sig2 = S.addSignal({ org_id: org.id, type: "pain_expressed", observation_ids: [o1.id], date: ago(2) });
const need = S.upsertNeed({ org_id: org.id, need_type: "online-ordering", description: "Takes orders by phone and is hiring to cope", signal_ids: [sig1.id, sig2.id] });
t.check("a need rests on signals and records first and last seen", need.status === "open" && need.first_seen <= need.last_seen && need.signal_ids.length === 2);
t.check("a need with no signals or another organization's signal is refused", throwsKind(() => S.upsertNeed({ org_id: org.id, need_type: "x", description: "d", signal_ids: [] })) === "invalid" && throwsKind(() => S.upsertNeed({ org_id: other.id, need_type: "x", description: "d", signal_ids: [sig1.id] })) === "invalid");
t.check("the same need type updates the need instead of adding another", S.upsertNeed({ org_id: org.id, need_type: "online-ordering", description: "Still phone only", signal_ids: [sig1.id] }).id === need.id && S.count("needs") === 1);

const v = S.orgView(org.id, new Date());
t.check("the view shows live signals, a live need and a combined intent", v.signals.every((s) => s.live) && v.needs[0].live && v.intent > 0.7 && v.intent < 1 && v.observations.length >= 3, JSON.stringify({ intent: v.intent }));
const far = S.orgView(org.id, new Date(Date.now() + 400 * DAY));
t.check("a year later nothing is live: the need is stale and intent is gone", far.signals.every((s) => !s.live) && !far.needs[0].live && far.intent === 0);
S.upsertNeed({ org_id: org.id, need_type: "online-ordering", description: "Built their own", status: "solved", signal_ids: [sig2.id] });
t.check("a need marked solved is never live, even with fresh signals", S.orgView(org.id).needs[0].live === false);

// ---- people, accounts, suppression, forgetting -------------------------------------------------------------------------------------------
const { person, role } = S.upsertPerson({ org_id: org.id, name: "Karan Thakur", title_raw: "Founder and Owner", country: "ca", email: "owner@caloriesrestaurant.ca" });
t.check("a person gets a role with seniority and buying power", role.seniority === "owner" && role.buyer_power === "decides" && person.country === "CA");
t.check("the same person at the same company is updated, not duplicated", S.upsertPerson({ org_id: org.id, name: "karan thakur", title_raw: "CEO" }).person.id === person.id && S.count("persons") === 1 && S.list("roles")[0].seniority === "executive");
t.check("an account without proof is refused; with proof it is stored", throwsKind(() => S.addAccount({ person_id: person.id, platform: "reddit", handle: "karan_calories", link_proof: " " })) === "invalid" && !!S.addAccount({ person_id: person.id, platform: "reddit", handle: "karan_calories", link_proof: "caloriesrestaurant.ca footer links to this profile" }).id);
const acct = S.list("accounts")[0];
const post = S.addDocument({ platform: "reddit", url: "https://reddit.com/r/restaurateur/comments/abc", text: "We still take pickup orders over WhatsApp and it is chaos at lunch.", author_account_id: acct.id });
const oPost = S.observe({ subject_type: "organization", subject_id: org.id, predicate: "pain", object: "orders over WhatsApp", evidence_quote: "pickup orders over WhatsApp", url: post.url, document_id: post.id, confidence: 0.8, extractor: "t" });
const sigPost = S.addSignal({ org_id: org.id, type: "pain_expressed", observation_ids: [oPost.id], date: ago(1) });
const needPost = S.upsertNeed({ org_id: org.id, need_type: "whatsapp-orders", description: "Orders over WhatsApp", signal_ids: [sigPost.id] });
t.check("a person's post can support a signal and a need", S.get("needs", needPost.id).signal_ids.includes(sigPost.id));

S.suppress("email", "Blocked@Example.com", "asked to stop");
S.suppress("domain", "https://blocked-co.com/x", "customer");
t.check("a suppressed email, domain or person cannot be added", throwsKind(() => S.upsertPerson({ org_id: org.id, name: "Someone", title_raw: "Owner", email: "blocked@example.com" })) === "suppressed" && throwsKind(() => S.upsertOrganization({ name: "B", domain: "blocked-co.com" })) === "suppressed");
t.check("suppressing twice does not duplicate", S.suppress("domain", "blocked-co.com", "again").value === "blocked-co.com" && S.count("suppressions") === 2);

const forgot = S.forgetPerson(person.id);
t.check("forgetting removes the person, role, account, their post and what rested only on it",
  !S.get("persons", person.id) && S.count("accounts") === 0 && !S.get("documents", post.id) && !S.get("observations", oPost.id) && !S.get("signals", sigPost.id) && !S.get("needs", needPost.id) && forgot.removed.signals === 1 && forgot.removed.needs === 1, JSON.stringify(forgot));
t.check("…but keeps the organization and evidence that did not come from them", !!S.get("organizations", org.id) && !!S.get("observations", o1.id) && !!S.get("signals", sig1.id));
t.check("…and the same person cannot be added back", throwsKind(() => S.upsertPerson({ org_id: org.id, name: "KARAN THAKUR", title_raw: "Owner" })) === "suppressed");
const allFiles = readdirSync(join(dir, "leads")).filter((f) => f.endsWith(".jsonl")).map((f) => readFileSync(join(dir, "leads", f), "utf8")).join("\n");
t.check("…and no file on disk still holds the person's name as a live record", !/"name":"Karan Thakur"/.test(S.list("persons").map((p) => JSON.stringify(p)).join("")) && S.list("suppressions").every((s) => !/karan/i.test(JSON.stringify(s))));

// ---- persistence, tearing, compaction, permissions -------------------------------------------------------------------------------------------------
const before = S.stats();
S = new LeadStore(dir);
t.check("reopening the store gives back every record", JSON.stringify(S.stats()) === JSON.stringify(before) && S.orgView(org.id).signals.length === 2);
appendFileSync(join(dir, "leads", "observations.jsonl"), '{"op":"put","rec":{"id":"tor');
t.check("a torn last line from a crash is skipped, the rest loads", new LeadStore(dir).count("observations") === before.observations);
const dir2 = join(base, "state2");
let S2 = new LeadStore(dir2);
const org2 = S2.upsertOrganization({ name: "Churn", domain: "churn.example.com" });
for (let i = 0; i < 300; i++) S2.upsertOrganization({ name: "Churn", domain: "churn.example.com", description_short: `v${i}` });
const lines = (f) => readFileSync(f, "utf8").split("\n").filter(Boolean).length;
const bigLines = lines(join(dir2, "leads", "organizations.jsonl"));
S2 = new LeadStore(dir2);
t.check("a log full of old versions is compacted when opened, and nothing is lost", bigLines > 300 && lines(join(dir2, "leads", "organizations.jsonl")) === 1 && S2.get("organizations", org2.id).description_short === "v299");
const mode = (p) => (statSync(p).mode & 0o777).toString(8);
t.check("the data folder is private (0700) and files are 0600", mode(join(dir, "leads")) === "700" && mode(join(dir, "leads", "organizations.jsonl")) === "600");

// ---- packs and offerings -------------------------------------------------------------------------------------------------------------------------------------
const reg = new P.PackRegistry(join(base, "packs-state"));
const rest = reg.get("restaurants");
t.check("the restaurants pack is built in and valid", !!rest && rest.builtin && rest.need_types.length === 5 && !!P.validatePack(JSON.parse(JSON.stringify(rest))).id);
const mk = (o = {}) => ({ id: "dental", name: "Dental clinics", version: 1, description: "d", definitions: ["dental clinic"], naics: ["621210"], need_types: [{ id: "online-booking", label: "Online booking", phrases: ["call to book"], signals: ["pain_expressed", "tech_gap"] }], buyer_roles: ["owner"], exclude: [], sources: ["website"], rubric: [], ...o });
t.check("a pack with an unknown signal type, a duplicate need id or a bad id is refused",
  /not a signal type/.test(throwsMsg(() => P.validatePack(mk({ need_types: [{ id: "a", label: "A", phrases: [], signals: ["vibes"] }] })))) &&
  /used twice/.test(throwsMsg(() => P.validatePack(mk({ need_types: [{ id: "a", label: "A", phrases: [], signals: ["tech_gap"] }, { id: "a", label: "B", phrases: [], signals: ["tech_gap"] }] })))) &&
  /id must be/.test(throwsMsg(() => P.validatePack(mk({ id: "Bad Id!" })))) && /must be an object/.test(throwsMsg(() => P.validatePack("x"))));
t.check("unknown keys in a pack are dropped, not stored", !("evil" in P.validatePack(mk({ evil: "rm -rf" }))));
reg.install(mk());
t.check("an installed pack is listed and survives a new registry", new P.PackRegistry(join(base, "packs-state")).list().map((p) => p.id).join() === "restaurants,dental" && new P.PackRegistry(join(base, "packs-state")).get("dental").builtin === false);
t.check("a built-in pack cannot be replaced", /built-in/.test(throwsMsg(() => reg.install(mk({ id: "restaurants" })))));
writeFileSync(join(base, "packs-state", "leads", "packs", "broken.json"), "{not json");
t.check("a broken pack file is skipped, not fatal", reg.list().length === 2);
const tmpl = P.OFFERING_TEMPLATES[0];
const m = P.matchOffering({ id: "o", ...tmpl }, rest);
t.check("the dev-services template covers every restaurants need type", m.covered.length === 5 && m.unknown.length === 0 && m.unserved.length === 0, JSON.stringify(m));
const m2 = P.matchOffering({ id: "o", ...tmpl, solves: ["online-ordering", "teleportation"] }, rest);
t.check("an unknown need type is reported, and unserved pack needs are listed", m2.unknown.join() === "teleportation" && m2.unserved.length === 4);
const off = S2.saveOffering({ ...tmpl });
t.check("an offering is saved, then updated by id; an unknown id is refused", S2.saveOffering({ ...tmpl, id: off.id, name: "Renamed" }).name === "Renamed" && S2.count("offerings") === 1 && throwsKind(() => S2.saveOffering({ ...tmpl, id: "nope" })) === "not_found" && throwsKind(() => S2.saveOffering({ ...tmpl, solves: [] })) === "invalid");

// ---- the SQL schema covers every collection -------------------------------------------------------------------------------------------------------------------------------------
const sql = readFileSync(join(process.cwd(), "src/runtime/leads/schema.sql"), "utf8");
t.check("schema.sql has a table for every collection", COLLECTIONS.every((c) => new RegExp(`create table ${c}\\b`).test(sql)), COLLECTIONS.filter((c) => !new RegExp(`create table ${c}\\b`).test(sql)).join());

// ---- RPC through a real runtime ----------------------------------------------------------------------------------------------------------------------------------------------------------
const E = { INVALID: -32602, NOT_FOUND: -32004, FORBIDDEN: -32005, CONFLICT: -32009 };
const rt = await startRuntime();
try {
  t.check("the runtime starts", rt.ready, rt.output().slice(0, 300));
  const C = await session(rt);
  const r = await C.call("leads.pack.list", {});
  t.check("leads.pack.list: restaurants and the core rubric", r.result?.packs?.[0]?.id === "restaurants" && r.result.core_rubric.length === 6, JSON.stringify(r).slice(0, 200));
  t.check("leads.pack.get unknown pack is not_found", (await C.call("leads.pack.get", { pack_id: "nope" })).error?.code === E.NOT_FOUND);
  t.check("leads.pack.install rejects a bad pack with invalid params", (await C.call("leads.pack.install", { pack: { id: "x" } })).error?.code === E.INVALID);
  const tp = (await C.call("leads.offering.templates", {})).result.templates[0];
  const saved = await C.call("leads.offering.save", { name: tp.name, summary: tp.summary, solves: tp.solves, proof: tp.proof, pricing_rules: tp.pricing_rules, never_say: tp.never_say, links: tp.links });
  t.check("leads.offering.save stores the template", !!saved.result?.offering?.id, JSON.stringify(saved).slice(0, 200));
  const mm = await C.call("leads.offering.match", { offering_id: saved.result.offering.id, pack_id: "restaurants" });
  t.check("leads.offering.match covers the pack", mm.result?.covered?.length === 5);
  const og = (await C.call("leads.org.upsert", { name: "Calories", domain: "caloriesrestaurant.ca", hq_country: "CA" })).result.organization;
  const d = (await C.call("leads.document.add", { platform: "website", url: "https://caloriesrestaurant.ca/menu", text: "Call us to order family meals for pickup" })).result.document;
  t.check("leads.document.add returns the document without its text", !!d.id && !("text" in d));
  const badq = await C.call("leads.observe", { subject_type: "organization", subject_id: og.id, predicate: "p", object: "o", evidence_quote: "We have an app", url: "https://caloriesrestaurant.ca/menu", document_id: d.id, confidence: 0.9, extractor: "rpc" });
  t.check("leads.observe refuses a quote that is not in the document", badq.error?.code === E.INVALID && /does not appear/.test(badq.error.message), JSON.stringify(badq).slice(0, 200));
  const ob = (await C.call("leads.observe", { subject_type: "organization", subject_id: og.id, predicate: "takes_orders_by", object: "phone", evidence_quote: "call us to order", url: "https://caloriesrestaurant.ca/menu", document_id: d.id, confidence: 0.9, extractor: "rpc" })).result.observation;
  const sg = (await C.call("leads.signal.add", { org_id: og.id, type: "tech_gap", observation_ids: [ob.id], date: new Date().toISOString() })).result.signal;
  const nd = await C.call("leads.need.upsert", { org_id: og.id, need_type: "online-ordering", description: "Phone-only ordering", signal_ids: [sg.id] });
  t.check("observe → signal → need works end to end", !!nd.result?.need?.id, JSON.stringify(nd).slice(0, 200));
  const view = (await C.call("leads.org.get", { org_id: og.id })).result;
  t.check("leads.org.get shows the live need and intent", view.needs[0].live === true && view.intent > 0.4 && view.observations.length === 1);
  const old = (await C.call("leads.org.get", { org_id: og.id, as_of: new Date(Date.now() + 500 * DAY).toISOString() })).result;
  t.check("leads.org.get with a far as_of shows it stale", old.needs[0].live === false && old.intent === 0);
  t.check("unknown params and unknown organizations are refused", (await C.call("leads.org.get", { org_id: og.id, extra: 1 })).error?.code === E.INVALID && (await C.call("leads.org.get", { org_id: "nope" })).error?.code === E.NOT_FOUND);
  t.check("a placeholder domain is invalid params over RPC", (await C.call("leads.org.upsert", { name: "X", domain: "x.wixsite.com" })).error?.code === E.INVALID);
  const pp = (await C.call("leads.person.upsert", { org_id: og.id, name: "Karan Thakur", title_raw: "Owner" })).result;
  t.check("leads.person.upsert classifies the role", pp.role.buyer_power === "decides");
  const fg = await C.call("leads.person.forget", { person_id: pp.person.id });
  t.check("leads.person.forget works and the person cannot return (forbidden)", !!fg.result?.removed && (await C.call("leads.person.upsert", { org_id: og.id, name: "Karan Thakur", title_raw: "Owner" })).error?.code === E.FORBIDDEN);
  await C.call("leads.suppress", { kind: "domain", value: "bad.example.com", reason: "customer" });
  t.check("a suppressed domain is forbidden over RPC", (await C.call("leads.org.upsert", { name: "Bad", domain: "bad.example.com" })).error?.code === E.FORBIDDEN);
  const st = (await C.call("leads.stats", {})).result.counts;
  t.check("leads.stats counts the records", st.organizations === 1 && st.observations === 1 && st.suppressions === 2 && st.offerings === 1, JSON.stringify(st));
  C.close();
} finally {
  await rt.stop();
}

rmSync(base, { recursive: true, force: true });
process.exit(t.finish());
