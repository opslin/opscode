// Connectors: the new catalog entries (Firecrawl, TinyFish, Zoho Campaigns and Mail, Hostinger Mail), optional keys, per-person server
// addresses that are kept secret, an official logo for every entry, and the person's MCP servers reaching Claude Code and Codex
// (not only the built-in agent) through Opscode's own endpoint with the same approvals.
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, rmSync, statSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const root = process.cwd();
const dist = (p) => import(join(root, "dist", p));
const { MCP_CATALOG, catalogSecrets } = await dist("runtime/mcpCatalog.js");
const { McpManager, maskUrl } = await dist("runtime/mcp.js");
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p52-")));
const entry = (id) => MCP_CATALOG.find((e) => e.id === id);
const err = (fn) => { try { fn(); return ""; } catch (e) { return e.message; } };

// ---- the catalog and its logos -------------------------------------------------------------------------------------------------
const dir = join(root, "assets/brand/integrations");
const files = readdirSync(dir).filter((f) => f.endsWith(".svg"));
t.check("ids are unique and every entry names a logo file that exists", new Set(MCP_CATALOG.map((e) => e.id)).size === MCP_CATALOG.length && MCP_CATALOG.every((e) => e.unavailable ? !e.logo : e.logo?.endsWith(".svg") && existsSync(join(dir, e.logo))), MCP_CATALOG.filter((e) => !e.unavailable && (!e.logo || !existsSync(join(dir, e.logo)))).map((e) => e.id).join());
t.check("every logo is a real SVG, small, with no script or external link", files.every((f) => { const s = readFileSync(join(dir, f), "utf8"); return /^<svg[\s>]/.test(s.trim()) && s.length < 30_000 && !/<script|onload=|onerror=|<image|<foreignObject|href="https?:|url\(https?:/i.test(s); }), files.join());
t.check("no logo file is unused, and the notice names every one", files.every((f) => MCP_CATALOG.some((e) => e.logo === f)) && (() => { const n = readFileSync(join(dir, "NOTICE.md"), "utf8"); return files.every((f) => n.includes(f.replace(/\.svg$/, "")) ); })(), files.filter((f) => !MCP_CATALOG.some((e) => e.logo === f)).join());
t.check("the new entries are there with the right addresses", entry("firecrawl")?.url === "https://mcp.firecrawl.dev/v2/mcp" && entry("tinyfish")?.url === "https://agent.tinyfish.ai/mcp" && !!entry("zoho-campaigns")?.urlInput && !!entry("zoho-mail")?.urlInput && !!entry("hostinger-mail")?.urlInput);
t.check("Firecrawl's key is optional (it works without one); TinyFish's is required", entry("firecrawl").inputs[0].optional === true && !entry("tinyfish").inputs[0].optional);
t.check("entries that cannot be sure to work say so (sign-in step Opscode cannot show, not tested)", ["zoho-campaigns", "zoho-mail", "hostinger-mail"].every((id) => /Not yet tested|has not been tested/.test(entry(id).note)) && /no MCP server yet/i.test(entry("hostinger-mail").note));
t.check("the entries made before are unchanged in how they take keys", JSON.stringify(catalogSecrets(entry("supabase"), { SUPABASE_ACCESS_TOKEN: "sbp_x" })) === '{"env":{"SUPABASE_ACCESS_TOKEN":"sbp_x"}}' && /needs its/.test(err(() => catalogSecrets(entry("github"), {}))) && catalogSecrets(entry("playwright"), {}) && JSON.stringify(catalogSecrets(entry("github"), { GITHUB_TOKEN: "ghp_x" })) === '{"headers":{"Authorization":"Bearer ghp_x"}}');

// ---- turning typed values into keys -------------------------------------------------------------------------------------------------
t.check("Firecrawl with no key sends nothing; a blank key counts as none; with a key it is a Bearer header", JSON.stringify(catalogSecrets(entry("firecrawl"), {})) === "{}" && JSON.stringify(catalogSecrets(entry("firecrawl"), { FIRECRAWL_API_KEY: "   " })) === "{}" && JSON.stringify(catalogSecrets(entry("firecrawl"), { FIRECRAWL_API_KEY: "fc-123" })) === '{"headers":{"Authorization":"Bearer fc-123"}}');
t.check("TinyFish needs its key, then sends it as a Bearer header; unknown settings are refused", /needs its api key/i.test(err(() => catalogSecrets(entry("tinyfish"), {}))) && JSON.stringify(catalogSecrets(entry("tinyfish"), { TINYFISH_API_KEY: "tf-1" })) === '{"headers":{"Authorization":"Bearer tf-1"}}' && /no setting/.test(err(() => catalogSecrets(entry("tinyfish"), { TINYFISH_API_KEY: "x", OTHER: "y" }))));
t.check("Zoho needs the person's own server address, over https, and returns it as the url", /needs your zoho mcp server url/i.test(err(() => catalogSecrets(entry("zoho-campaigns"), {}))) && /https/.test(err(() => catalogSecrets(entry("zoho-campaigns"), { ZOHO_MCP_URL: "http://x.test/m?key=1" }))) && catalogSecrets(entry("zoho-campaigns"), { ZOHO_MCP_URL: " https://x.zohomcp.com/mcp/message?key=K " }).url === "https://x.zohomcp.com/mcp/message?key=K" && /no setting/.test(err(() => catalogSecrets(entry("zoho-mail"), { ZOHO_MCP_URL: "https://a.test/", FOO: "1" }))));
t.check("the address is masked down to its host", maskUrl("https://x.zohomcp.com/mcp/message?key=SECRET") === "https://x.zohomcp.com/…" && maskUrl("garbage") === "…");

// ---- a mock MCP server that records how it was reached ------------------------------------------------------------------------------------
const seen = { headers: [], urls: [], calls: [] };
const mock = createServer((req, res) => {
  let b = "";
  req.on("data", (c) => (b += c));
  req.on("end", () => {
    seen.headers.push(req.headers.authorization ?? null); seen.urls.push(req.url);
    if (req.url.startsWith("/locked") && !/key=SECRETKEY/.test(req.url)) return res.writeHead(401, { "content-type": "application/json" }).end("{}");
    const m = JSON.parse(b || "{}");
    if (m.id === undefined) return res.writeHead(202).end();
    const reply = (result) => res.writeHead(200, { "content-type": "application/json", "mcp-session-id": "s1" }).end(JSON.stringify({ jsonrpc: "2.0", id: m.id, result }));
    if (m.method === "initialize") reply({ protocolVersion: "2024-11-05", capabilities: {}, serverInfo: { name: "mock" } });
    else if (m.method === "tools/list") reply({ tools: [{ name: "echo", description: "Echo text back", inputSchema: { type: "object", properties: { text: { type: "string" } } } }, { name: "a_very_long_tool_name_that_goes_on_and_on_and_on_far_past_any_limit", description: "Long", inputSchema: { type: "object", properties: {} } }] });
    else { seen.calls.push(m.params); reply({ content: [{ type: "text", text: `echoed: ${m.params?.arguments?.text ?? ""}` }] }); }
  });
});
await new Promise((r) => mock.listen(0, "127.0.0.1", r));
const URL0 = `http://127.0.0.1:${mock.address().port}`;
const ready = async (m, id, ms = 8000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(40)) { const s = m.list().find((x) => x.id === id); if (s && s.state !== "connecting" && s.state !== "off") return s; } return m.list().find((x) => x.id === id); };

const sd = join(base, "mcp-state");
const M = new McpManager(sd, sd, () => {});
const a = M.addServer({ name: "Keyed", url: `${URL0}/mcp`, enabled: true, headers: { Authorization: "Bearer k-123" } });
t.check("a key typed for a catalog entry is sent as the Authorization header", (await ready(M, a.id)).state === "ready" && seen.headers.includes("Bearer k-123"));
const b2 = M.addServer({ name: "Keyless", url: `${URL0}/mcp2`, enabled: true });
const n0 = seen.headers.length;
await ready(M, b2.id);
t.check("with no key nothing is sent (no empty Authorization header)", seen.headers.slice(n0).every((h) => h === null) && seen.headers.length > n0);
const z = M.addServer({ name: "Zoho test", url: `${URL0}/locked/mcp/message?key=SECRETKEY`, enabled: true, secret_url: true, catalog: "zoho-mail" });
const sz = await ready(M, z.id);
t.check("a server whose address carries the key connects with the full address", sz.state === "ready", JSON.stringify(sz).slice(0, 200));
t.check("…but lists never show the key: the target is masked and the whole list holds no trace of it", sz.target === `${URL0}/…` && !JSON.stringify(M.list()).includes("SECRETKEY"));
t.check("…and the key is kept only in the private file (0600), and the mask survives a restart", (() => { const f = join(sd, "mcp.json"); const raw = readFileSync(f, "utf8"); const M2 = new McpManager(sd, sd, () => {}); const again = M2.list().find((x) => x.name === "Zoho test"); M2.closeAll(); return raw.includes("SECRETKEY") && (statSync(f).mode & 0o777) === 0o600 && again.target === `${URL0}/…`; })());
const bad = M.addServer({ name: "Wrong key", url: `${URL0}/locked/mcp/message?key=WRONG`, enabled: true, secret_url: true });
const sb = await ready(M, bad.id);
t.check("a wrong key shows as 'needs a key' (401), not a crash", sb.state === "error" && sb.needs_key === true && !JSON.stringify(sb).includes("WRONG"));
t.check("setSecrets can replace the address only for a server whose address is secret", (() => { M.setSecrets(bad.id, { url: `${URL0}/locked/mcp/message?key=SECRETKEY` }); const ok = M.list().find((x) => x.id === bad.id).target === `${URL0}/…`; const refused = (() => { M.setSecrets(a.id, { url: "http://127.0.0.1:1/changed" }); return M.list().find((x) => x.id === a.id).target === `${URL0}/mcp`; })(); return ok && refused; })());

// ---- tool names for each kind of model --------------------------------------------------------------------------------------------------------------------------------------------
await ready(M, bad.id);
const long = M.agentTools().filter((x) => x.server === a.id);
const short = M.agentTools(true).filter((x) => x.server === a.id);
t.check("for the built-in agent (any provider) names keep the mcp__server__tool form, up to 64 characters", long.some((x) => x.name === "mcp__keyed__echo") && long.every((x) => x.name.length <= 64));
t.check("for Claude Code and Codex names are shorter (they sit behind Opscode's 22-character server prefix) and stay unique", short.some((x) => x.name === "keyed__echo") && short.every((x) => x.name.length <= 38 && 22 + x.name.length <= 64) && new Set(M.agentTools(true).map((x) => x.name)).size === M.agentTools(true).length);
M.closeAll();

// ---- RPC: the catalog as the Plugins page reads it, and adding entries -----------------------------------------------------------------------------------------------------------
const logFile = join(base, "engines.log");
writeFileSync(logFile, "");
const proj = join(base, "web");
mkdirSync(proj, { recursive: true });
writeFileSync(join(proj, "package.json"), "{}");
const rt = await startRuntime({ env: { OPSCODE_CLAUDE_BIN: join(root, "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(root, "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile } });
const logLines = () => readFileSync(logFile, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
try {
  t.check("the runtime starts", rt.ready, rt.output().slice(0, 300));
  const C = await session(rt);
  const cat = (await C.call("mcp.catalog", {})).result.catalog;
  const fc = cat.find((e) => e.id === "firecrawl"), zc = cat.find((e) => e.id === "zoho-campaigns");
  t.check("mcp.catalog gives the Plugins page the logo, optional flags, the address field and the honest note", fc.logo === "firecrawl.svg" && fc.inputs[0].optional === true && zc.url_input.key === "ZOHO_MCP_URL" && /Not yet tested/.test(zc.note) && cat.every((e) => e.unavailable ? !e.logo : /\.svg$/.test(e.logo)) && cat.find((e) => e.id === "github").inputs[0].optional === false && !JSON.stringify(cat).includes("SECRET"));
  t.check("the first two cards are the web tools you asked for: Firecrawl and TinyFish", cat[0].id === "firecrawl" && cat[1].id === "tinyfish");
  const addF = await C.call("mcp.catalog.add", { id: "firecrawl" });
  t.check("adding Firecrawl needs no key at all", !addF.error && addF.result.server.catalog === "firecrawl" && !addF.result.server.secrets);
  t.check("adding TinyFish without its key is refused with a clear message", /needs its api key/i.test((await C.call("mcp.catalog.add", { id: "tinyfish" })).error?.message ?? ""));
  t.check("adding Zoho with an http address is refused", /https/.test((await C.call("mcp.catalog.add", { id: "zoho-mail", values: { ZOHO_MCP_URL: "http://a.test/x?key=Q" } })).error?.message ?? ""));
  const addZ = await C.call("mcp.catalog.add", { id: "zoho-campaigns", values: { ZOHO_MCP_URL: "https://zoho-test.invalid/mcp/message?key=SECRETZ" } });
  const list = (await C.call("mcp.list", {})).result.servers;
  t.check("…the key is nowhere in what the app can read", !addZ.error && addZ.result.server.target === "https://zoho-test.invalid/…" && !JSON.stringify(list).includes("SECRETZ") && !JSON.stringify(addZ).includes("SECRETZ") && !rt.output().includes("SECRETZ"));
  t.check("…but it is in the private file, so the server can connect", readFileSync(join(rt.stateDir, "mcp.json"), "utf8").includes("SECRETZ"));
  await C.call("mcp.remove", { id: addF.result.server.id });
  await C.call("mcp.remove", { id: addZ.result.server.id });

  // ---- the person's servers reach Claude Code and Codex, not only the built-in agent -----------------------------------------------------------------------------------------------
  const added = (await C.call("mcp.add", { input: `${URL0}/mcp`, name: "Mock Tools" })).result.server;
  const wait = async (fn, ms = 10000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(50)) { const v = await fn(); if (v) return v; } return null; };
  t.check("the server connects", !!(await wait(async () => (await C.call("mcp.list", {})).result.servers.find((s) => s.id === added.id && s.state === "ready"))));
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  const chat = (await C.call("chat.create", { workspace_id: wid, engine: "claude-code", mode: "supervised" })).result.chat;
  const events = (turnId) => C.find("turn.event", (p) => p.turn_id === turnId).map((n) => n.params);
  const finished = (turnId) => wait(() => events(turnId).some((e) => ["completed", "failed", "interrupted"].includes(e.type)), 20000);
  const r = (await C.call("turn.submit", { workspace_id: wid, chat_id: chat.id, text: `use the tool\nFAKE_DEVICE mock_tools__echo ${JSON.stringify({ text: "hello from claude" })}` })).result;
  const ask = await wait(() => events(r.turn_id).find((e) => e.type === "approval_request"));
  t.check("Claude Code is asked for approval first (Supervised mode), with the tool named", !!ask && /mock_tools|Mock/i.test(JSON.stringify(ask)), JSON.stringify(ask)?.slice(0, 200));
  if (ask) await C.call("turn.approve", { turn_id: r.turn_id, call_id: ask.call_id, allow: true });
  await finished(r.turn_id);
  const log = logLines();
  const tools = log.find((l) => l.device_tools)?.device_tools ?? [];
  t.check("Claude Code is shown the person's MCP tools next to Opscode's own", tools.includes("mock_tools__echo") && tools.every((n) => n.length <= 64 - 22), tools.join(","));
  const res = log.find((l) => l.device_tool === "mock_tools__echo");
  t.check("…and the call goes through to the server and its answer comes back", res?.result === "echoed: hello from claude" && res.is_error === false && seen.calls.some((c) => c.name === "echo" && c.arguments.text === "hello from claude"), JSON.stringify(res));
  const r2 = (await C.call("turn.submit", { workspace_id: wid, chat_id: chat.id, text: `again\nFAKE_DEVICE mock_tools__echo ${JSON.stringify({ text: "denied" })}` })).result;
  const ask2 = await wait(() => events(r2.turn_id).find((e) => e.type === "approval_request"));
  if (ask2) await C.call("turn.approve", { turn_id: r2.turn_id, call_id: ask2.call_id, allow: false });
  await finished(r2.turn_id);
  t.check("a declined call never reaches the server", !seen.calls.some((c) => c.arguments?.text === "denied"));
  await C.call("mcp.set_enabled", { id: added.id, enabled: false });
  const r3 = (await C.call("turn.submit", { workspace_id: wid, chat_id: chat.id, text: `off\nFAKE_DEVICE mock_tools__echo ${JSON.stringify({ text: "x" })}` })).result;
  await finished(r3.turn_id);
  const toolsOff = logLines().filter((l) => l.device_tools).at(-1).device_tools;
  t.check("a server turned off disappears from Claude Code's tool list (chats stay light)", !toolsOff.includes("mock_tools__echo"));
  C.close();
} finally {
  await rt.stop();
}

mock.close();
rmSync(base, { recursive: true, force: true });
process.exit(t.finish());
