// Lead intelligence, slice 2: the website scout. Pure helpers (address safety, robots.txt, HTML, tool fingerprints),
// then the whole scout against local fixture sites (robots rules, redirects, size caps, gzip, politeness, a hostile
// redirect to a cloud-metadata address), idempotence, evidence checks, and the leads.scout.website RPC.
import { mkdtempSync, realpathSync, rmSync } from "node:fs";
import { createServer } from "node:http";
import { gzipSync } from "node:zlib";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime } from "./lib/harness.mjs";

const t = reporter();
const dist = (p) => import(join(process.cwd(), "dist", p));
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p49-")));
const DAY = 86_400_000;
const posted = new Date(Date.now() - 5 * DAY).toISOString().slice(0, 10);

const NET = await dist("runtime/leads/scout/net.js");
const HTML = await dist("runtime/leads/scout/html.js");
const TECH = await dist("runtime/leads/scout/tech.js");
const CRAWL = await dist("runtime/leads/scout/crawl.js");
const EXT = await dist("runtime/leads/scout/extract.js");
const SCOUT = await dist("runtime/leads/scout/index.js");
const { LeadStore } = await dist("runtime/leads/store.js");
const { PackRegistry } = await dist("runtime/leads/packs.js");

// ---- address safety -----------------------------------------------------------------------------------------------------
t.check("public addresses are allowed", ["8.8.8.8", "93.184.216.34", "2606:4700:4700::1111"].every(NET.isPublicAddress));
t.check("loopback, private, link-local (cloud metadata), CGNAT and multicast are not",
  ["127.0.0.1", "10.1.2.3", "172.16.0.1", "172.31.255.255", "192.168.1.1", "169.254.169.254", "100.64.0.1", "224.0.0.1", "0.0.0.0", "198.18.0.1"].every((a) => !NET.isPublicAddress(a)));
t.check("IPv6 loopback, unique-local, link-local and mapped private addresses are not", ["::1", "::", "fc00::1", "fd12::1", "fe80::1", "::ffff:10.0.0.1", "::ffff:127.0.0.1", "::ffff:169.254.169.254", "64:ff9b::a00:1"].every((a) => !NET.isPublicAddress(a)), ["::1", "fd12::1", "::ffff:10.0.0.1", "64:ff9b::a00:1"].filter(NET.isPublicAddress).join());
t.check("a hostname or garbage is never 'public' here", !NET.isPublicAddress("example.com") && !NET.isPublicAddress(""));
const kind = async (url, o) => { try { await NET.fetchText(url, o); return "ok"; } catch (e) { return e.kind ?? `other:${e.message}`; } };
t.check("fetching refuses non-http schemes, credentials, odd ports and private literals",
  (await kind("ftp://example.com/")) === "invalid_url" && (await kind("http://user:pw@example.com/")) === "invalid_url" && (await kind("http://example.com:22/")) === "blocked" &&
  (await kind("http://127.0.0.1/")) === "blocked" && (await kind("http://[::1]/")) === "blocked" && (await kind("http://169.254.169.254/latest/meta-data/")) === "blocked" && (await kind("not a url")) === "invalid_url");
t.check("a name that resolves to loopback is blocked at connect time", (await kind("http://localhost/")) === "blocked");

// ---- robots.txt -------------------------------------------------------------------------------------------------------------------------------------
const R = NET.parseRobots(`User-agent: *\nDisallow: /private\nAllow: /private/public\nDisallow: /*.pdf$\nCrawl-delay: 3\nSitemap: https://x.test/s.xml\n\nUser-agent: OtherBot\nDisallow: /\n`);
t.check("robots: disallow, a longer allow wins, wildcard and end anchor", !R.allowed("/private/a") && R.allowed("/private/public/x") && !R.allowed("/a/b.pdf") && R.allowed("/a/b.pdf?x=1") && R.allowed("/menu"));
t.check("robots: crawl-delay and sitemaps are read; another bot's group does not apply to us", R.crawlDelaySec === 3 && R.sitemaps[0] === "https://x.test/s.xml");
t.check("robots: a group naming us wins over *", !NET.parseRobots("User-agent: *\nAllow: /\n\nUser-agent: OpscodeBot\nDisallow: /").allowed("/x") && NET.parseRobots("User-agent: *\nDisallow:\n").allowed("/x"));
t.check("robots: comments, blank values and junk lines are ignored", NET.parseRobots("# hi\nUser-agent: *\nDisallow: # nothing\nnonsense\nDisallow: /a # c\n").allowed("/b") && !NET.parseRobots("User-agent: *\nDisallow: /a # c\n").allowed("/a"));

// ---- HTML reader ------------------------------------------------------------------------------------------------------------------------------------
const page = HTML.parseHtml(`<!doctype html><html lang="fr-CA"><head><title>Chez Moi | Montréal</title><meta name="description" content="Cuisine &amp; café"><meta property="og:site_name" content="Chez Moi"><meta name="robots" content="noindex"><meta name="generator" content="WordPress 6.4">
<script type="application/ld+json">{"@graph":[{"@type":"Restaurant","name":"Chez Moi"},{"@type":"PostalAddress","addressLocality":"Montréal"}]}</script><script type="application/ld+json">{broken</script>
<script src="https://js.stripe.com/v3/"></script><link rel="stylesheet" href="/wp-content/x.css"></head><body><!-- comment hidden --><script>var secret="NEVERSEEN"</script><style>.a{}</style>
<h1>Bienvenue</h1><p>Call us&nbsp;to order &#233;t&eacute; &#x1F600;</p><a href="/menu">Menu</a><a href="mailto:Info@Chez.test?subject=x">Mail</a><a href="tel:+1 514 555 0100">Call</a><a href="javascript:void(0)">x</a><a href="#top">top</a><a href="https://other.test/x#frag">Other</a>
<footer>write info@chez.test or team@chez.test</footer><img src="/logo.png"></body></html>`, "https://chez.test/");
t.check("title, description (entities decoded), site name, language, canonical flag, noindex", page.title === "Chez Moi | Montréal" && page.description === "Cuisine & café" && page.siteName === "Chez Moi" && page.lang === "fr-CA" && page.noindex);
t.check("visible text drops scripts, styles and comments and decodes entities", page.text.includes("Call us to order été") && !/NEVERSEEN|comment hidden|\.a\{/.test(page.text) && page.text.includes("Bienvenue"));
t.check("links are absolute, without fragments; mailto, tel, javascript and # are not links", page.links.map((l) => l.href).join() === "https://chez.test/menu,https://other.test/x");
t.check("emails (mailto and text) and phones are found and lower-cased", page.emails.includes("info@chez.test") && page.emails.includes("team@chez.test") && page.phones[0] === "+1 514 555 0100");
t.check("JSON-LD is flattened (@graph) and a broken block is skipped", page.jsonld.length === 3 && page.jsonld.some((n) => n["@type"] === "Restaurant"));
t.check("markup keeps script sources, stylesheets and the generator", page.markup.includes("https://js.stripe.com/v3/") && page.markup.includes("/wp-content/x.css") && page.markup.some((m) => m.startsWith("generator: WordPress")));
t.check("garbage never throws", HTML.parseHtml("<<<>>><a href=><div", "https://x.test/").text !== undefined && HTML.parseHtml("", "https://x.test/").title === "");
const fp = TECH.fingerprint(page.markup);
t.check("tools are fingerprinted with the exact string that proved them", fp.find((h) => h.tech === "Stripe")?.evidence === "https://js.stripe.com/v3/" && fp.some((h) => h.tech === "WordPress"));
t.check("page kinds come from the path", CRAWL.classify("https://x.test/careers/", "") === "careers" && CRAWL.classify("https://x.test/our-menu", "") === "menu" && CRAWL.classify("https://x.test/pickup", "") === "order" && CRAWL.classify("https://x.test/xyz", "") === "other");
const packs = new PackRegistry(join(base, "pk"));
const rest = packs.get("restaurants");
const need = (id) => rest.need_types.find((n) => n.id === id);
t.check("a phrase hit becomes the right signal: gap, expansion, or hiring on a careers page", EXT.signalFor(need("online-ordering"), "home") === "tech_gap" && EXT.signalFor(need("online-ordering"), "careers") === "hiring_role" && EXT.signalFor(need("multi-location-ops"), "news") === "expansion");

// ---- fixture sites ----------------------------------------------------------------------------------------------------------------------------------------------
const hits = {};
const servers = [];
const ports = {};
async function site(host, handler) {
  hits[host] = [];
  const s = createServer((req, res) => { hits[host].push(req.url); handler(req, res); });
  await new Promise((r) => s.listen(0, "127.0.0.1", r));
  servers.push(s);
  ports[host] = s.address().port;
}
const send = (res, body, type = "text/html; charset=utf-8", status = 200, extra = {}) => res.writeHead(status, { "content-type": type, ...extra }).end(body);
const wrap = (title, body, head = "") => `<!doctype html><html lang="en"><head><title>${title}</title>${head}</head><body>${body}</body></html>`;

await site("calories.test", (req, res) => {
  const u = req.url;
  if (u === "/robots.txt") return send(res, "User-agent: *\nDisallow: /private\nCrawl-delay: 2\n", "text/plain");
  if (u === "/") return send(res, wrap("Calories | Saskatoon Restaurant", `
    <script>var hidden="should-not-appear-anywhere"</script>
    <h1>Calories</h1><p>Same-day pickup for lunch, dinner and dessert.</p><p>Call us to order family meals for pickup.</p><p>Now open in Regina!</p>
    <a href="/menu">Menu</a> <a href="/order">Order</a> <a href="/careers">Careers</a> <a href="/about">About</a> <a href="/contact">Contact</a> <a href="/private/staff">Staff</a> <a href="/blog">Blog</a> <a href="/old">Old</a>
    <a href="https://elsewhere.test/">Partner</a> <a href="mailto:owner@calories.test">Email the owner</a> <a href="tel:+13066657991">Phone</a>`,
    `<meta name="description" content="Same-day pickup lunch, dinner and dessert in Saskatoon.">
     <script type="application/ld+json">{"@context":"https://schema.org","@type":"Restaurant","name":"Calories","telephone":"+1-306-665-7991","address":{"@type":"PostalAddress","streetAddress":"721 Broadway Avenue","addressLocality":"Saskatoon","addressRegion":"SK","postalCode":"S7N 1B3","addressCountry":"CA"}}</script>
     <script src="https://js.stripe.com/v3/"></script><script async src="https://www.googletagmanager.com/gtag/js?id=G-1"></script>`));
  if (u === "/menu") return send(res, wrap("Menu", "<p>Soups, salads, desserts.</p>"));
  if (u === "/order") return send(res, wrap("Order", "<p>For pickup orders by phone, ring the kitchen between 11 and 8.</p>"));
  if (u === "/careers") return send(res, wrap("Careers", `<h1>Join us</h1><p>Hiring: front-of-house lead to manage phone orders</p>`, `<script type="application/ld+json">{"@type":"JobPosting","title":"Kitchen Helper","datePosted":"${posted}","hiringOrganization":{"@type":"Organization","name":"Calories"}}</script>`));
  if (u === "/about") return send(res, wrap("About", "<p>Family run since 2009.</p>"));
  if (u === "/contact") return send(res, wrap("Contact", `<p>Write to <a href="mailto:info@calories.test">info@calories.test</a></p>`));
  if (u === "/blog") return send(res, wrap("Blog", "<p>News from the kitchen.</p>"));
  if (u === "/old") return res.writeHead(301, { location: "/menu" }).end();
  if (u.startsWith("/private")) return send(res, wrap("Private", "<p>staff only</p>"));
  send(res, "nope", "text/plain", 404);
});
await site("robotsblock.test", (req, res) => (req.url === "/robots.txt" ? send(res, "User-agent: *\nDisallow: /\n", "text/plain") : send(res, wrap("Blocked", "<p>x</p>"))));
await site("down.test", (req, res) => (req.url === "/robots.txt" ? send(res, "oops", "text/plain", 503) : send(res, wrap("Down", "<p>x</p>"))));
await site("evil.test", (req, res) => (req.url === "/robots.txt" ? send(res, "nope", "text/plain", 404) : res.writeHead(302, { location: "http://169.254.169.254/latest/meta-data/" }).end()));
await site("loop.test", (req, res) => (req.url === "/robots.txt" ? send(res, "nope", "text/plain", 404) : res.writeHead(302, { location: "/" }).end()));
await site("pdf.test", (req, res) => (req.url === "/robots.txt" ? send(res, "nope", "text/plain", 404) : send(res, "%PDF-1.4", "application/pdf")));
await site("big.test", (req, res) => (req.url === "/robots.txt" ? send(res, "nope", "text/plain", 404) : send(res, wrap("Big Site", "<p>Call us to order</p>" + "<p>filler</p>".repeat(200_000)))));
await site("gz.test", (req, res) => (req.url === "/robots.txt" ? send(res, "nope", "text/plain", 404) : send(res, gzipSync(wrap("Gzip Site", "<p>Hello</p>")), "text/html", 200, { "content-encoding": "gzip" })));
await site("slow.test", (req, res) => (req.url === "/robots.txt" ? setTimeout(() => send(res, "nope", "text/plain", 404), 500) : send(res, wrap("Slow Site", "<p>Hello</p>"))));

const MAP = Object.fromEntries(Object.entries(ports).map(([h, p]) => [h, `127.0.0.1:${p}`]));
const rewrite = (u) => { const to = MAP[u.hostname]; if (!to) return u; const n = new URL(u.href); n.host = to; n.protocol = "http:"; return n; };
const OPTS = { rewrite, delayMs: 0, maxDelayMs: 0 };

// ---- the scout on a real-looking site ----------------------------------------------------------------------------------------------------------------------------------------------
const dir = join(base, "state");
const S = new LeadStore(dir);
const rep = await SCOUT.scoutWebsite(S, "https://www.Calories.test/menu", rest, OPTS);
t.check("the scout reads the site: status ok, an organization with name, country, description", rep.status === "ok" && !!rep.org_id && S.get("organizations", rep.org_id).name === "Calories" && S.get("organizations", rep.org_id).hq_country === "CA" && S.get("organizations", rep.org_id).description_short.startsWith("Same-day pickup"), JSON.stringify(rep).slice(0, 300));
const kinds = rep.pages.map((p) => p.kind);
t.check("it reads home, careers, order, menu, about, contact, news — and nothing robots.txt forbids", ["home", "careers", "order", "menu", "about", "contact", "news"].every((k) => kinds.includes(k)) && !hits["calories.test"].some((u) => u.startsWith("/private")), kinds.join());
t.check("robots.txt is fetched first, once, before any page", hits["calories.test"][0] === "/robots.txt" && hits["calories.test"].filter((u) => u === "/robots.txt").length === 1, hits["calories.test"].join());
t.check("other sites are never followed", !Object.entries(hits).some(([h, l]) => h === "elsewhere.test" && l.length));
const view = S.orgView(rep.org_id);
const preds = (p) => view.observations.filter((o) => o.predicate === p).map((o) => o.object);
t.check("contacts: both mailboxes and the phone are recorded", preds("has_public_email").includes("owner@calories.test") && preds("has_public_email").includes("info@calories.test") && preds("has_phone").some((p) => p.includes("306")), JSON.stringify(preds("has_public_email")));
t.check("tools: Stripe and Google Analytics, each quoting the script that proved it", preds("uses_tech").includes("Stripe") && preds("uses_tech").includes("Google Analytics") && view.observations.find((o) => o.object === "Stripe").evidence_quote === "https://js.stripe.com/v3/");
t.check("a location with an address is stored once", S.list("locations").length === 1 && S.list("locations")[0].address.includes("721 Broadway") && rep.locations === 1 && preds("has_location").length === 1);
t.check("hiring: the structured job (dated) and the 'Hiring:' line both become signals", view.signals.filter((s) => s.type === "hiring_role").length === 2 && preds("hiring_for").includes("Kitchen Helper") && preds("hiring_for").some((p) => p.startsWith("front-of-house")));
const job = view.signals.find((s) => s.type === "hiring_role" && Math.abs(new Date(s.date) - (Date.now() - 5 * DAY)) < 2 * DAY);
t.check("…and the structured job keeps its real posting date", !!job);
t.check("expansion: 'Now open in Regina' is a signal quoting the sentence", view.signals.some((s) => s.type === "expansion") && view.observations.some((o) => o.predicate === "expansion_notice" && /Now open in Regina/i.test(o.evidence_quote)));
t.check("needs from the pack: online ordering and multi-location, both live", rep.needs.map((n) => n.need_type).sort().join() === "multi-location-ops,online-ordering" && view.needs.every((n) => n.live) && view.intent > 0.7, JSON.stringify(rep.needs));
const phoneNeed = view.observations.filter((o) => o.predicate === "mentions:online-ordering");
t.check("…with the page's own words as evidence ('call to order', 'pickup orders by phone')", phoneNeed.some((o) => /call us to order/i.test(o.evidence_quote)) && phoneNeed.some((o) => /pickup orders by phone/i.test(o.evidence_quote)));
const docs = S.list("documents");
t.check("script contents never reach a stored document", !docs.some((d) => /should-not-appear-anywhere/.test(d.text)) && docs.every((d) => d.platform === "website"));
t.check("every quote is real: each observation names a stored document containing its quote, except the one TLD-free case", view.observations.every((o) => o.document_id && S.get("documents", o.document_id).text.toLowerCase().replace(/\s+/g, " ").includes(o.evidence_quote.toLowerCase().replace(/\s+/g, " "))), String(view.observations.filter((o) => !o.document_id).length));
const counts = JSON.stringify(S.stats());
const rep2 = await SCOUT.scoutWebsite(S, "calories.test", rest, OPTS);
t.check("scanning the same site again adds nothing (documents, observations, signals, needs, locations)", rep2.status === "ok" && JSON.stringify(S.stats()) === counts, counts + " vs " + JSON.stringify(S.stats()));
t.check("a 301 on the site is followed (the /old link redirected to /menu without a second /menu page)", rep.pages.filter((p) => p.url.endsWith("/menu")).length === 1);

// ---- politeness and caps -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
const sleeps = [];
const c1 = await CRAWL.crawlSite("calories.test", { rewrite, delayMs: 500, sleep: async (ms) => { sleeps.push(ms); } });
t.check("it pauses between requests, and robots.txt's Crawl-delay (2s) beats a shorter setting", sleeps.length >= c1.pages.length - 1 && sleeps.every((ms) => ms === 2000), sleeps.join());
const sleeps2 = [];
await CRAWL.crawlSite("calories.test", { rewrite, delayMs: 500, maxDelayMs: 800, sleep: async (ms) => { sleeps2.push(ms); } });
t.check("…but never longer than the cap", sleeps2.every((ms) => ms === 800));
const c2 = await CRAWL.crawlSite("calories.test", { ...OPTS, maxPages: 2 });
t.check("maxPages limits what is read", c2.pages.length === 2);

// ---- sites that must not be crawled, and ones that go wrong ---------------------------------------------------------------------------------------------------------------------------------------------------------
const S2 = new LeadStore(join(base, "state2"));
const before = hits["robotsblock.test"].length;
const rb = await SCOUT.scoutWebsite(S2, "robotsblock.test", rest, OPTS);
t.check("robots.txt 'Disallow: /' means no page is fetched and no organization is created", rb.status === "blocked_by_robots" && hits["robotsblock.test"].join() === "/robots.txt" && S2.count("organizations") === 0 && before === 0);
const dn = await SCOUT.scoutWebsite(S2, "down.test", rest, OPTS);
t.check("a robots.txt that answers 503 means we do not crawl", dn.status === "blocked_by_robots" && /503/.test(dn.error) && hits["down.test"].join() === "/robots.txt");
const ev = await SCOUT.scoutWebsite(S2, "evil.test", rest, OPTS);
t.check("a redirect to the cloud metadata address is refused, never followed", ev.status === "unreachable" && /not a public address/.test(ev.error) && S2.count("organizations") === 0, ev.error);
const lp = await SCOUT.scoutWebsite(S2, "loop.test", rest, OPTS);
t.check("a redirect loop stops", lp.status === "unreachable" && /redirect/.test(lp.error), lp.error);
const pd = await SCOUT.scoutWebsite(S2, "pdf.test", rest, OPTS);
t.check("a non-HTML home page is not read", pd.status === "unreachable" && /not a web page/.test(pd.error), pd.error);
const bg = await SCOUT.scoutWebsite(S2, "big.test", rest, OPTS);
t.check("a huge page is cut at the size cap and still read", bg.status === "ok" && S2.get("organizations", bg.org_id).name === "Big Site" && S2.list("documents").every((d) => d.text.length <= 200_000));
const gz = await SCOUT.scoutWebsite(S2, "gz.test", rest, OPTS);
t.check("a gzip-encoded page is decoded", gz.status === "ok" && S2.get("organizations", gz.org_id).name === "Gzip Site");
t.check("a placeholder domain and a bad domain are refused before any request", (await SCOUT.scoutWebsite(S2, "shop.myshopify.com", rest, OPTS)).status === "invalid" && (await SCOUT.scoutWebsite(S2, "no spaces allowed", rest, OPTS)).status === "invalid");
S2.suppress("domain", "calories.test", "existing customer");
const hitsBefore = hits["calories.test"].length;
const sp = await SCOUT.scoutWebsite(S2, "calories.test", rest, OPTS);
t.check("a suppressed domain is never contacted", sp.status === "suppressed" && hits["calories.test"].length === hitsBefore);
const nopack = await SCOUT.scoutWebsite(new LeadStore(join(base, "state3")), "calories.test", undefined, OPTS);
t.check("without a pack it still records facts and generic signals but makes no needs", nopack.status === "ok" && nopack.needs.length === 0 && (nopack.signals.hiring_role ?? 0) >= 2);

// ---- RPC through a real runtime ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
const E = { INVALID: -32602, NOT_FOUND: -32004, CONFLICT: -32009 };
const rt = await startRuntime({ env: { OPSCODE_LEADS_TEST_MAP: JSON.stringify(MAP) } });
try {
  t.check("the runtime starts", rt.ready, rt.output().slice(0, 300));
  const C = await session(rt);
  t.check("bad params: no domains, too many, unknown pack, bad delay", (await C.call("leads.scout.website", { domains: [] })).result?.reports?.length === 0 && (await C.call("leads.scout.website", { domains: Array(21).fill("a.test") })).error?.code === E.INVALID && (await C.call("leads.scout.website", { domains: ["a.test"], pack_id: "nope" })).error?.code === E.NOT_FOUND && (await C.call("leads.scout.website", { domains: ["a.test"], delay_ms: 99999 })).error?.code === E.INVALID);
  const r = await C.call("leads.scout.website", { domains: ["calories.test", "shop.myshopify.com", "robotsblock.test"], pack_id: "restaurants", delay_ms: 0 });
  t.check("leads.scout.website reports each domain", r.result?.reports?.map((x) => x.status).join() === "ok,invalid,blocked_by_robots", JSON.stringify(r).slice(0, 300));
  t.check("progress events: a start and a done for each domain", C.find("leads.scout.progress", (p) => p.state === "start").length === 3 && C.find("leads.scout.progress", (p) => p.state === "done").length === 3);
  const orgId = r.result.reports[0].org_id;
  const v = (await C.call("leads.org.get", { org_id: orgId })).result;
  t.check("the scanned organization is readable through leads.org.get with live needs", v.needs.length === 2 && v.needs.every((n) => n.live) && v.signals.length >= 4);
  const first = C.call("leads.scout.website", { domains: ["slow.test"], delay_ms: 0 });
  const second = await C.call("leads.scout.website", { domains: ["gz.test"], delay_ms: 0 });
  t.check("a second scan while one is running is refused (conflict)", second.error?.code === E.CONFLICT);
  t.check("…and the first one still finishes", (await first).result?.reports?.[0]?.status === "ok");
  t.check("after it finishes, scanning works again", (await C.call("leads.scout.website", { domains: ["gz.test"], delay_ms: 0 })).result?.reports?.[0]?.status === "ok");
  C.close();
} finally {
  await rt.stop();
}

for (const s of servers) s.close();
rmSync(base, { recursive: true, force: true });
process.exit(t.finish());
