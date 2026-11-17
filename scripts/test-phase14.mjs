// Plugins page runtime: MCP server keys (env for stdio, headers for HTTP), never shown
// to clients; "needs a key" detection; the featured catalog; imported servers keep their source.

import { mkdtempSync, readFileSync, realpathSync, rmSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, waitFor } from "./lib/harness.mjs";

const t = reporter();
const E = { INVALID: -32602, NOT_FOUND: -32004, CONFLICT: -32009 };
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 260);
const KEY_SERVER = join(process.cwd(), "scripts/lib/mock-mcp-key.mjs");
const SECRET = "letmein";
const HDR_SECRET = "Bearer hdr-secret-42";

// An HTTP MCP server that needs Authorization: Bearer hdr-secret-42.
const http = createServer((req, res) => {
  let b = ""; req.on("data", (c) => (b += c)); req.on("end", () => {
    if (req.headers.authorization !== HDR_SECRET) return res.writeHead(401, "Unauthorized").end();
    const m = JSON.parse(b || "{}");
    if (m.id === undefined) return res.writeHead(202).end();
    const result = m.method === "initialize" ? { protocolVersion: "2024-11-05", capabilities: {}, serverInfo: { name: "h", version: "1" } } : m.method === "tools/list" ? { tools: [{ name: "hello", description: "hi", inputSchema: { type: "object" } }] } : {};
    res.writeHead(200, { "content-type": "application/json" }).end(JSON.stringify({ jsonrpc: "2.0", id: m.id, result }));
  });
});
await new Promise((r) => http.listen(0, "127.0.0.1", r));
const httpUrl = `http://127.0.0.1:${http.address().port}/mcp`;

const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p14-")));
const stateDir = join(base, "state");
let rt = await startRuntime({ stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);
try {
  let C = await session(rt);
  const servers = async () => (await C.call("mcp.list")).result.servers;
  const one = async (id) => (await servers()).find((s) => s.id === id);

  // ---- stdio server that needs a key ---------------------------------------------------------
  let res = await C.call("mcp.add", { input: `${process.execPath} ${KEY_SERVER}`, name: "keyed" });
  const sid = res.result.server.id;
  await waitFor(async () => false, 10);
  t.check("without its key the server fails and is marked 'needs a key'", await waitFor(() => false, 1) || (await (async () => { for (let i = 0; i < 60; i++) { const s = await one(sid); if (s.state === "error") return s.needs_key === true; await new Promise((r) => setTimeout(r, 100)); } return false; })()), JSON.stringify(await one(sid)));
  res = await C.call("mcp.set_secrets", { id: sid, values: { MOCK_KEY: SECRET } });
  t.check("set_secrets accepts an environment value", !!res.result, why(res));
  t.check("with its key it starts and lists tools", await (async () => { for (let i = 0; i < 60; i++) { const s = await one(sid); if (s.state === "ready") return s.tools.some((x) => x.name === "has_key"); await new Promise((r) => setTimeout(r, 100)); } return false; })(), JSON.stringify(await one(sid)));
  let s = await one(sid);
  t.check("the list names the key but never shows its value", s.secrets?.join() === "MOCK_KEY" && !JSON.stringify(await servers()).includes(SECRET) && !s.target.includes(SECRET), JSON.stringify(s));
  t.check("the server still gets PATH (a key doesn't replace the environment)", s.tools.find((x) => x.name === "has_key")?.description === "PATH set: true");
  for (const [name, values] of [["PATH", { PATH: "/tmp" }], ["DYLD_INSERT_LIBRARIES", { DYLD_INSERT_LIBRARIES: "/x.dylib" }], ["NODE_OPTIONS", { NODE_OPTIONS: "--require /x.js" }], ["a bad name", { "1BAD": "x" }], ["a line break", { OK_KEY: "a\nb" }]]) {
    res = await C.call("mcp.set_secrets", { id: sid, values });
    t.check(`set_secrets refuses ${name}`, res.error?.code === E.INVALID, why(res));
  }
  t.check("mcp.json holds the key and is private (0600)", readFileSync(join(stateDir, "mcp.json"), "utf8").includes(SECRET) && (statSync(join(stateDir, "mcp.json")).mode & 0o777) === 0o600);

  // ---- HTTP server that needs a header ---------------------------------------------------------
  res = await C.call("mcp.add", { input: httpUrl, name: "headered" });
  const hid = res.result.server.id;
  t.check("an HTTP server answering 401 is marked 'needs a key'", await (async () => { for (let i = 0; i < 60; i++) { const x = await one(hid); if (x.state === "error") return x.needs_key === true; await new Promise((r) => setTimeout(r, 100)); } return false; })(), JSON.stringify(await one(hid)));
  res = await C.call("mcp.set_secrets", { id: hid, values: { Authorization: HDR_SECRET } });
  t.check("with the header it connects", !!res.result && (await (async () => { for (let i = 0; i < 60; i++) { const x = await one(hid); if (x.state === "ready") return true; await new Promise((r) => setTimeout(r, 100)); } return false; })()), JSON.stringify(await one(hid)));
  t.check("the header value is never listed", !JSON.stringify(await servers()).includes("hdr-secret-42"));
  res = await C.call("mcp.set_secrets", { id: hid, values: { Host: "evil" } });
  t.check("protected headers can't be set", res.error?.code === E.INVALID, why(res));

  // ---- catalog -------------------------------------------------------------------------------------
  res = await C.call("mcp.catalog");
  const cat = res.result?.catalog ?? [];
  t.check("the catalog lists real servers with what they run", cat.length >= 10 && cat.find((c) => c.id === "supabase")?.target === "npx -y @supabase/mcp-server-supabase@latest" && cat.find((c) => c.id === "github")?.target === "https://api.githubcopilot.com/mcp/", why(res));
  t.check("entries say which keys they need (labels only)", cat.find((c) => c.id === "notion")?.inputs[0]?.key === "NOTION_TOKEN" && cat.find((c) => c.id === "playwright")?.inputs.length === 0);
  res = await C.call("mcp.catalog.add", { id: "supabase" });
  t.check("adding without the required key is refused (nothing runs)", res.error?.code === E.INVALID && !(await servers()).some((x) => x.catalog === "supabase"), why(res));
  res = await C.call("mcp.catalog.add", { id: "supabase", values: { SUPABASE_ACCESS_TOKEN: "x", EXTRA: "y" } });
  t.check("unknown values are refused", res.error?.code === E.INVALID, why(res));
  res = await C.call("mcp.catalog.add", { id: "nope" });
  t.check("an unknown catalog id is not-found", res.error?.code === E.NOT_FOUND, why(res));
  res = await C.call("mcp.catalog.add", { id: "figma" }); // local URL; nothing listening, so it just errors
  t.check("a catalog server is added, tagged with its catalog id", res.result?.server.catalog === "figma" && res.result.server.target === "http://127.0.0.1:3845/mcp", why(res));
  res = await C.call("mcp.catalog.add", { id: "figma" });
  t.check("adding the same catalog server twice is refused", res.error?.code === E.CONFLICT, why(res));
  res = await C.call("mcp.catalog");
  t.check("the catalog marks it as added", res.result.catalog.find((c) => c.id === "figma")?.added === true);

  // ---- keys survive a restart ---------------------------------------------------------------------------
  C.close();
  await rt.stop();
  rt = await startRuntime({ stateDir, keepState: true });
  C = await session(rt);
  t.check("after a restart the stored keys still work (refresh connects both)", await (async () => { for (let i = 0; i < 80; i++) { const all = (await C.call("mcp.list")).result.servers; if (all.find((x) => x.id === sid)?.state === "ready" && all.find((x) => x.id === hid)?.state === "ready") return true; if (i === 0) { await C.call("mcp.refresh", { id: sid }).catch(() => {}); await C.call("mcp.refresh", { id: hid }).catch(() => {}); } await new Promise((r) => setTimeout(r, 100)); } return false; })());
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  http.close();
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
