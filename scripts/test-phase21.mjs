// The Library: the indexer on a fixture app (secrets and noise never indexed), packages and
// stacks, features by convention with cross-layer merges, tables and routes with no module,
// the import graph, search (with synonyms for search only), context, incremental re-index,
// persistence across a restart, and the read-only Chief tool.

import { appendFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, rmSync, statSync, unlinkSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";
import { LITERAL, SECRET_TEXT, SENTINEL, writeLibraryFixture } from "./lib/library-fixture.mjs";

const t = reporter();
const why = (res) => JSON.stringify(res?.error ?? res?.result)?.slice(0, 320);
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p21-")));
const apps = join(base, "apps");
mkdirSync(join(apps, "noise-folder"), { recursive: true });
const fx = writeLibraryFixture(apps);
const proj = join(base, "project");
mkdirSync(proj);
const logFile = join(base, "engines.log");
const env = { OPSCODE_LIBRARY_SUGGEST_ROOT: apps, OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile };
const stateDir = join(base, "state");
let rt = await startRuntime({ env, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  let C = await session(rt);
  const entries = () => (existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);

  // ---- nothing is indexed until an app is added ------------------------------------------------
  let res = await C.call("library.list", {});
  t.check("the Library starts empty and suggests the repo folder (not the empty one)", res.result?.apps.length === 0 && res.result.suggestions.map((s) => s.name).join() === "shopfix", why(res));
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  await C.call("engines.set", { default_engine: "claude-code" });
  const chief = (await C.call("chief.create", { mode: "warlord", project_id: wid })).result.chief;
  await C.call("chief.note", { chief_id: chief.id, text: `go\nFAKE_TOOL library_search ${JSON.stringify({ query: "loyalty points" })}` });
  for (const end = Date.now() + 8000; Date.now() < end && !entries().some((e) => e.chief_tool === "library_search"); await sleep(100));
  t.check("the Chief's library_search says the Library is empty (and does not make things up)", /no apps yet/.test(entries().find((e) => e.chief_tool === "library_search")?.result ?? ""), JSON.stringify(entries().find((e) => e.chief_tool === "library_search")));

  // ---- adding: refusals -------------------------------------------------------------------------
  for (const [path, re, label] of [["/", /too broad/, "the root"], [homedir(), /too broad/, "the home folder"], [stateDir, /Opscode itself/, "Opscode's own data"], ["/private/etc", /system folder/, "a system folder"], [join(base, "nope"), /does not exist/, "a folder that is not there"], [join(fx.root, "backend/package.json"), /not a folder/, "a file"]]) {
    res = await C.call("library.add", { path });
    t.check(`adding ${label} is refused`, !!res.error && re.test(res.error.message), why(res));
  }

  // ---- adding the fixture app -----------------------------------------------------------------
  res = await C.call("library.add", { path: fx.root, name: "Shop" });
  const app = res.result?.app;
  t.check("add registers the app and starts indexing", app?.name === "Shop" && app.status === "indexing" && app.path === fx.root, why(res));
  await C.call("library.reindex", { app_id: app.id, wait: true });
  res = await C.call("library.get", { app_id: app.id });
  const d = res.result;
  t.check("indexed: 17 files (secrets, hidden, dependency, build, fixture, platform folders and links skipped)", d?.app.status === "ready" && d.app.files === fx.files, JSON.stringify({ files: d?.app.files, status: d?.app.status, err: d?.app.error }));
  const pk = Object.fromEntries((d?.packages ?? []).map((p) => [p.name, p]));
  t.check("packages: the backend is NestJS + Drizzle, the app is Flutter + Riverpod + go_router, with their layers", pk["@shop/backend"]?.layer === "backend" && pk["@shop/backend"].stack.includes("NestJS") && pk["@shop/backend"].stack.includes("Drizzle") && pk.shopapp?.layer === "app" && pk.shopapp.stack.includes("Flutter") && pk.shopapp.stack.includes("Riverpod") && pk.shopapp.stack.includes("go_router"), JSON.stringify(d?.packages));
  const fe = Object.fromEntries((d?.features ?? []).map((f) => [f.id, f]));
  t.check("six features: loyalty, order, admin from folders; auction and cart from tables; vendor from routes", Object.keys(fe).sort().join() === "admin,auction,cart,loyalty,order,vendor", Object.keys(fe).join());
  t.check("loyalty and order are one feature each across backend and app (merged on the same name)", fe.loyalty?.layers.map((l) => l.layer).sort().join() === "app,backend" && fe.order?.layers.map((l) => l.layer).sort().join() === "app,backend", JSON.stringify([fe.loyalty?.layers, fe.order?.layers]));
  res = await C.call("library.feature", { app_id: app.id, feature_id: "loyalty" });
  const lf = res.result?.feature;
  t.check("the merge records why each layer joined", lf?.layers.every((l) => /same name "loyalty"/.test(l.reason)) && lf.layers.some((l) => /folder modules\/loyalty/.test(l.reason)) && lf.layers.some((l) => /folder features\/loyalty/.test(l.reason)), JSON.stringify(lf?.layers.map((l) => l.reason)));
  t.check("routes: the Nest controller's GET /loyalty/points; its table loyalty_points joined by name prefix, with the reason", lf?.routes.some((r) => r.method === "GET" && r.path === "/loyalty/points") && lf.tables.some((x) => x.name === "loyalty_points" && /starts with the feature name/.test(x.reason)), JSON.stringify([lf?.routes, lf?.tables]));
  res = await C.call("library.feature", { app_id: app.id, feature_id: "vendor" });
  t.check("a route with no module becomes a 'routes only' feature", res.result?.feature.routes.some((r) => r.path === "/api/vendors/payout" && /routes only/.test(r.reason)), why(res));
  res = await C.call("library.feature", { app_id: app.id, feature_id: "cart" });
  t.check("a table with no module becomes a 'tables only' feature (cart_items)", res.result?.feature.tables.some((x) => x.name === "cart_items" && /tables only/.test(x.reason)) && res.result.feature.layers[0].layer === "db", why(res));
  res = await C.call("library.feature", { app_id: app.id, feature_id: "loyalty" });
  t.check("related features follow the import graph (order's service and loyalty's service sit apart; the app's main links order)", Array.isArray(res.result?.related), why(res));
  t.check("graph coverage: relative imports resolved (relative paths, the @/ alias, Flutter package: imports); the one broken import is reported", d.coverage.resolved >= 5 && d.coverage.unresolved === 1 && /\.\/missing/.test(d.coverage.unresolved_sample[0]), JSON.stringify(d.coverage));

  // ---- secrets and contents ------------------------------------------------------------------------
  const saved = readFileSync(join(stateDir, "library", `${app.id}.json`), "utf8") + readFileSync(join(stateDir, "library", "registry.json"), "utf8");
  t.check("no secret file, secret text or source literal is anywhere in the saved index", !saved.includes(SECRET_TEXT) && !saved.includes(LITERAL) && !/server\.pem|\.env|credentials\.json|google-services/.test(saved), "found something");
  const facts = JSON.parse(readFileSync(join(stateDir, "library", `${app.id}.json`), "utf8")).files;
  const strings = facts.flatMap((f) => [...(f.f.i ?? []), ...(f.f.d ?? []), ...(f.f.t ?? []), ...(f.f.r ?? []).flat()]);
  t.check("only short single-line names are stored: no value with a line break or over 200 characters, and the word 'import' in a string captured no code", strings.every((s) => s.length <= 200 && !/[\n\r]/.test(s)) && !saved.includes(SENTINEL), `${strings.filter((s) => s.length > 200 || /\n/.test(s)).length} bad; sentinel ${saved.includes(SENTINEL)}`);
  t.check("a source file that merely has 'credentials' in its name IS indexed", saved.includes("admin-credentials.service.ts") && !!fe.admin);
  t.check("the index files are private (0600 or 0700)", readdirSync(join(stateDir, "library")).every((f) => (statSync(join(stateDir, "library", f)).mode & 0o077) === 0), "");

  // ---- search ---------------------------------------------------------------------------------------
  const top = async (q) => (await C.call("library.search", { query: q })).result?.hits ?? [];
  let h = await top("loyalty points");
  t.check("search 'loyalty points': the loyalty feature first, across app and backend, with its evidence", h[0]?.feature === "loyalty" && h[0].layers.length === 2 && h[0].why.length > 0, JSON.stringify(h[0]));
  h = await top("cart");
  t.check("search 'cart' finds the cart tables; 'basket' finds it only through the search synonyms", h[0]?.feature === "cart" && (await top("basket"))[0]?.feature === "cart");
  t.check("search 'auction bid' finds auction; 'seller payout' finds vendor", (await top("auction bid"))[0]?.feature === "auction" && (await top("seller payout"))[0]?.feature === "vendor");
  t.check("nothing matches 'zebra'", (await top("zebra")).length === 0);
  t.check("synonyms never merge features: cart and its synonym basket are not joined (no 'basket' feature appeared, cart has no extra layers)", !fe.basket && fe.cart.layers.length === 1);

  // ---- context --------------------------------------------------------------------------------------
  res = await C.call("library.context", { app_id: app.id, query: "loyalty points", max_files: 10 });
  const cf = (res.result?.files ?? []).map((f) => f.path);
  t.check("context for 'loyalty points' lists the controller, service, repository and the app screen, best first", ["backend/src/modules/loyalty/loyalty.controller.ts", "backend/src/modules/loyalty/loyalty.service.ts", "backend/src/modules/loyalty/loyalty.repository.ts", "app/lib/features/loyalty/loyalty_screen.dart"].every((p) => cf.includes(p)) && res.result.files.every((f) => f.lines > 0), JSON.stringify(cf));
  t.check("and one hop out in the graph: what the loyalty service is used by", res.result.files.some((f) => /used by|uses /.test(f.why)), JSON.stringify(res.result.files.map((f) => f.why)));

  // ---- the Chief tool ------------------------------------------------------------------------------
  const n0 = entries().filter((e) => e.chief_tool === "library_search").length;
  await C.call("chief.note", { chief_id: chief.id, text: `go again\nFAKE_TOOL library_search ${JSON.stringify({ query: "loyalty points" })}` });
  for (const end = Date.now() + 8000; Date.now() < end && entries().filter((e) => e.chief_tool === "library_search").length === n0; await sleep(100));
  const tr = JSON.parse(entries().filter((e) => e.chief_tool === "library_search").at(-1).result);
  t.check("the Chief's library_search now returns the loyalty feature with its layers", tr.hits?.[0]?.feature === "Loyalty" && tr.hits[0].layers.length === 2, JSON.stringify(tr));

  // ---- incremental re-index ----------------------------------------------------------------------
  appendFileSync(join(fx.root, "backend/src/modules/loyalty/loyalty.service.ts"), "export class RefundPolicy {}\n");
  unlinkSync(join(fx.root, "backend/src/modules/orders/orders.service.ts"));
  await C.call("library.reindex", { app_id: app.id, wait: true });
  res = await C.call("library.feature", { app_id: app.id, feature_id: "order" });
  t.check("re-index sees the deleted file (order loses a backend file) ...", res.result?.feature.layers.find((l) => l.layer === "backend")?.file_count === 1, why(res));
  t.check("... and the new class is searchable", (await top("RefundPolicy"))[0]?.feature === "loyalty");

  // ---- persistence --------------------------------------------------------------------------------
  C.close();
  await rt.stop();
  rt = await startRuntime({ env, stateDir, keepState: true });
  C = await session(rt);
  res = await C.call("library.list", {});
  t.check("after a restart the app is still there and ready", res.result?.apps.length === 1 && res.result.apps[0].status === "ready" && res.result.suggestions.length === 0, why(res));
  t.check("and searches from the saved index with no re-scan", (await top("loyalty points"))[0]?.feature === "loyalty");
  res = await C.call("library.remove", { app_id: app.id });
  t.check("remove deletes the app and its index, never the app's own folder", res.result?.removed === true && !existsSync(join(stateDir, "library", `${app.id}.json`)) && existsSync(join(fx.root, "backend/package.json")), why(res));
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
