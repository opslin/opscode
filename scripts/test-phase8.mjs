// Skills and plugins: skill files (user/project/plugin), the agent seeing them,
// previews before install, plugin install/disable/uninstall, marketplaces.

import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, waitFor } from "./lib/harness.mjs";

const t = reporter();
const E = { INVALID: -32602, NOT_FOUND: -32004 };
const code = (res) => res.error?.code;
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 220);
const MOCK_MCP = join(process.cwd(), "scripts/lib/mock-mcp.mjs");

// ---- mock Anthropic ---------------------------------------------------------------
const llm = { requests: [], script: [] };
const sse = (evs) => evs.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
const textEv = (s) => [{ type: "content_block_start", index: 0, content_block: { type: "text", text: "" } }, { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: s } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "end_turn" } }];
const toolEv = (id, name, input) => [{ type: "content_block_start", index: 0, content_block: { type: "tool_use", id, name } }, { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: JSON.stringify(input) } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "tool_use" } }];
const llmServer = createServer((req, res) => {
  let b = "";
  req.on("data", (c) => (b += c));
  req.on("end", () => {
    llm.requests.push(JSON.parse(b));
    const step = llm.script.shift();
    res.writeHead(200, { "content-type": "text/event-stream" }).end(step?.sse ?? sse(textEv("ok")));
  });
});
await new Promise((r) => llmServer.listen(0, "127.0.0.1", r));
const step = (evs) => llm.script.push({ sse: sse(evs) });

// ---- fixtures ------------------------------------------------------------------------
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p8-")));
const proj = join(base, "project");
const outside = join(base, "outside");
mkdirSync(proj);
mkdirSync(outside);
writeFileSync(join(outside, "secret.txt"), "TOP SECRET");
const skillMd = (name, desc, body) => `---\nname: ${name}\ndescription: ${JSON.stringify(desc)}\n---\n\n${body}\n`;

const acme = join(base, "market", "plugins", "acme");
mkdirSync(join(acme, ".claude-plugin"), { recursive: true });
mkdirSync(join(acme, "skills", "release-notes"), { recursive: true });
mkdirSync(join(acme, "node_modules", "junk"), { recursive: true });
writeFileSync(join(acme, ".claude-plugin", "plugin.json"), JSON.stringify({ name: "acme", description: "Acme helpers", version: "1.2.0" }));
writeFileSync(join(acme, "skills", "release-notes", "SKILL.md"), skillMd("release-notes", "Write release notes from commits", "1. List commits.\n2. Group by area."));
writeFileSync(join(acme, "node_modules", "junk", "x.js"), "junk");
copyFileSync(MOCK_MCP, join(acme, "server.mjs"));
writeFileSync(join(acme, ".mcp.json"), JSON.stringify({ mcpServers: { acmetools: { command: process.execPath, args: ["${CLAUDE_PLUGIN_ROOT}/server.mjs"], env: { TOKEN: "x" } }, remote: { url: "http://example.com/mcp" } } }));
symlinkSync(outside, join(acme, "link-out")); // must not be copied

const market = join(base, "market");
mkdirSync(join(market, ".claude-plugin"), { recursive: true });
writeFileSync(join(market, ".claude-plugin", "marketplace.json"), JSON.stringify({ name: "Acme Market", plugins: [{ name: "acme", source: "./plugins/acme", description: "Acme helpers" }, { name: "escape", source: "../outside" }] }));

const skillsFolder = join(base, "skillsfolder");
mkdirSync(join(skillsFolder, "lint-fix"), { recursive: true });
mkdirSync(join(skillsFolder, "Bad Name"), { recursive: true });
writeFileSync(join(skillsFolder, "lint-fix", "SKILL.md"), skillMd("lint-fix", "Fix lint errors", "Run the linter, fix, rerun."));
writeFileSync(join(skillsFolder, "Bad Name", "SKILL.md"), skillMd("Bad Name", "ignored", "x"));
const emptyFolder = join(base, "empty");
mkdirSync(emptyFolder);
const bigPlugin = join(base, "big");
mkdirSync(join(bigPlugin, "skills", "s"), { recursive: true });
writeFileSync(join(bigPlugin, "skills", "s", "SKILL.md"), skillMd("s", "d", "b"));
for (let i = 0; i < 501; i++) writeFileSync(join(bigPlugin, `f${i}.txt`), "x");

const stateDir = join(base, "state");
let rt = await startRuntime({ stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);
let mcpPid = null;
const dead = (p) => { try { process.kill(p, 0); return false; } catch { return true; } };

try {
  let C = await session(rt);
  const evs = (turn) => C.find("turn.event", (p) => p.turn_id === turn).map((n) => n.params);
  const finished = (turn) => evs(turn).some((e) => ["completed", "failed", "interrupted"].includes(e.type));
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  const poll = async (fn, ms = 6000) => { for (const end = Date.now() + ms; Date.now() < end; await new Promise((r) => setTimeout(r, 50))) { const v = await fn(); if (v) return v; } return null; };
  const server = async (name) => (await C.call("mcp.list")).result.servers.find((s) => s.name === name);

  // ---- skills: CRUD --------------------------------------------------------------------
  let res = await C.call("skill.save", { scope: "user", name: "release-notes", description: "Personal release notes", body: "personal steps" });
  t.check("skill.save (user)", res.result?.skills?.some((s) => s.name === "release-notes" && s.scope === "user"), why(res));
  res = await C.call("skill.save", { scope: "user", name: "Bad Name", description: "d", body: "b" });
  t.check("bad skill name refused", code(res) === E.INVALID, why(res));
  res = await C.call("skill.save", { scope: "user", name: "empty-desc", description: "  ", body: "b" });
  t.check("a skill needs a description", code(res) === E.INVALID, why(res));
  res = await C.call("skill.save", { scope: "user", name: "empty-body", description: "d", body: " " });
  t.check("a skill needs steps", code(res) === E.INVALID, why(res));
  res = await C.call("skill.save", { scope: "project", name: "p-only", description: "d", body: "b" });
  t.check("project skill needs a project", code(res) === E.INVALID, why(res));
  res = await C.call("skill.save", { scope: "project", workspace_id: "nope", name: "p-only", description: "d", body: "b" });
  t.check("project skill for an unknown project -> not found", code(res) === E.NOT_FOUND, why(res));
  res = await C.call("skill.save", { scope: "project", workspace_id: wid, name: "release-notes", description: "Project release notes", body: "project steps" });
  t.check("skill.save (project)", res.result?.skills?.find((s) => s.name === "release-notes")?.scope === "project", why(res));
  t.check("project skill is a SKILL.md in <project>/.opscode/skills", existsSync(join(proj, ".opscode/skills/release-notes/SKILL.md")) && /name: release-notes/.test(readFileSync(join(proj, ".opscode/skills/release-notes/SKILL.md"), "utf8")));
  res = await C.call("skill.read", { name: "release-notes", workspace_id: wid });
  t.check("project beats personal for the same name", res.result?.body === "project steps" && res.result.skill.scope === "project", why(res));
  res = await C.call("skill.read", { name: "release-notes" });
  t.check("without a project, the personal one shows", res.result?.body === "personal steps", why(res));
  res = await C.call("skill.read", { name: "missing" });
  t.check("read unknown skill -> not found", code(res) === E.NOT_FOUND, why(res));
  // hand-written file with quoted frontmatter
  mkdirSync(join(proj, ".opscode/skills/hand-made"), { recursive: true });
  writeFileSync(join(proj, ".opscode/skills/hand-made/SKILL.md"), `---\nname: 'hand-made'\ndescription: "Written by hand"\n---\nDo the thing.\n`);
  res = await C.call("skill.list", { workspace_id: wid });
  t.check("hand-written SKILL.md is picked up", res.result?.skills?.some((s) => s.name === "hand-made" && s.description === "Written by hand"), why(res));
  res = await C.call("skill.delete", { scope: "project", workspace_id: wid, name: "hand-made" });
  t.check("skill.delete (project)", res.result?.deleted === true && !existsSync(join(proj, ".opscode/skills/hand-made")), why(res));
  res = await C.call("skill.delete", { scope: "project", workspace_id: wid, name: "hand-made" });
  t.check("delete twice -> not found", code(res) === E.NOT_FOUND, why(res));
  res = await C.call("skill.delete", { scope: "user", name: "../../etc" });
  t.check("path-like skill names are refused", res.error && code(res) !== undefined, why(res));
  t.check("skill.changed is broadcast", C.find("skill.changed", () => true).length > 0);

  // .opscode as a symlink must not be followed
  const proj2 = join(base, "project2");
  mkdirSync(proj2);
  symlinkSync(outside, join(proj2, ".opscode"));
  const wid2 = (await C.call("workspace.add", { path: proj2 })).result.workspace.id;
  res = await C.call("skill.save", { scope: "project", workspace_id: wid2, name: "evil", description: "d", body: "b" });
  t.check("a linked .opscode is refused", code(res) === E.INVALID && !existsSync(join(outside, "skills")), why(res));

  // ---- the agent sees skills ------------------------------------------------------------
  await C.call("provider.set", { id: "anthropic", api_key: "sk-test-1234", base_url: `http://127.0.0.1:${llmServer.address().port}`, model: "m" });
  const chat = (await C.call("chat.create", { workspace_id: wid, mode: "supervised" })).result.chat;
  const submit = async (text) => (await C.call("turn.submit", { workspace_id: wid, chat_id: chat.id, text })).result.turn_id;
  step(textEv("hi"));
  let turn = await submit("hello");
  await waitFor(() => finished(turn), 8000);
  let req = llm.requests.at(-1);
  t.check("the catalog is in the system prompt", req.system.includes("- release-notes: Project release notes") && !req.system.includes("project steps"), req.system.slice(-300));
  t.check("use_skill is offered", req.tools.some((x) => x.name === "use_skill"));

  step(toolEv("u1", "use_skill", { name: "release-notes" }));
  step(textEv("done"));
  turn = await submit("write release notes");
  await waitFor(() => finished(turn), 8000);
  t.check("use_skill returns the steps without asking", evs(turn).find((e) => e.type === "tool_end")?.output === "project steps" && !evs(turn).some((e) => e.type === "approval_request"));
  step(toolEv("u2", "use_skill", { name: "nope" }));
  step(textEv("done"));
  turn = await submit("unknown skill");
  await waitFor(() => finished(turn), 8000);
  t.check("use_skill on an unknown name is an error the model can read", evs(turn).find((e) => e.type === "tool_end")?.is_error === true);

  step(textEv("ok"));
  turn = await submit("/release-notes for v2");
  await waitFor(() => finished(turn), 8000);
  req = llm.requests.at(-1);
  t.check("/skill puts its steps in the prompt", req.system.includes('The user invoked the skill "release-notes"') && req.system.includes("project steps"));
  t.check("/skill sends only the rest as the user's message", req.messages.at(-1).content.at(-1).text.includes("for v2") && !req.messages.at(-1).content.at(-1).text.includes("/release-notes"), JSON.stringify(req.messages.at(-1)));
  step(textEv("ok"));
  turn = await submit("/nothere hi");
  await waitFor(() => finished(turn), 8000);
  t.check("an unknown /name is just text", llm.requests.at(-1).messages.at(-1).content.at(-1).text.includes("/nothere hi") && !llm.requests.at(-1).system.includes("invoked the skill"));

  // ---- previews -----------------------------------------------------------------------------
  res = await C.call("plugin.preview", { path: acme });
  const pv = res.result?.preview;
  t.check("preview a plugin: name, version, skills", pv?.kind === "plugin" && pv.name === "acme" && pv.version === "1.2.0" && pv.skills[0]?.name === "release-notes", why(res));
  t.check("preview lists MCP servers and warns about env/skipped ones", pv?.mcp_servers?.some((s) => s.name === "acmetools" && s.transport === "stdio") && pv.warnings.some((w) => /environment/.test(w)) && pv.warnings.some((w) => /remote/.test(w)), JSON.stringify(pv?.warnings));
  t.check("preview changes nothing", !(await C.call("plugin.list")).result.plugins.length && !existsSync(join(stateDir, "plugins", "acme")));
  res = await C.call("plugin.preview", { path: market });
  t.check("preview a marketplace", res.result?.preview?.kind === "marketplace" && res.result.preview.plugins.length === 2, why(res));
  res = await C.call("plugin.preview", { path: skillsFolder });
  t.check("preview a folder of skills (bad names skipped)", res.result?.preview?.kind === "skills" && res.result.preview.skills.length === 1 && res.result.preview.skills[0].name === "lint-fix", why(res));
  res = await C.call("plugin.preview", { path: emptyFolder });
  t.check("preview of an empty folder -> error", code(res) === E.INVALID, why(res));
  res = await C.call("plugin.preview", { path: "relative/path" });
  t.check("relative path refused", code(res) === E.INVALID, why(res));
  res = await C.call("plugin.preview", { path: join(base, "nope") });
  t.check("missing folder refused", code(res) === E.INVALID, why(res));

  // ---- install ---------------------------------------------------------------------------------
  res = await C.call("plugin.install", { path: market });
  t.check("a marketplace cannot be installed as a plugin", code(res) === E.INVALID, why(res));
  res = await C.call("plugin.install", { path: bigPlugin });
  t.check("an oversized plugin is refused and leaves nothing behind", code(res) === E.INVALID && !existsSync(join(stateDir, "plugins", "s")) && !existsSync(join(stateDir, "plugins", "big")), why(res));
  res = await C.call("plugin.install", { path: acme });
  const installed = res.result?.plugin;
  t.check("plugin.install", installed?.id === "acme" && installed.enabled && installed.skills[0] === "release-notes" && installed.mcp_servers.includes("acmetools"), why(res));
  t.check("files are copied; symlinks and node_modules are not", existsSync(join(stateDir, "plugins/acme/server.mjs")) && !existsSync(join(stateDir, "plugins/acme/link-out")) && !existsSync(join(stateDir, "plugins/acme/node_modules")));
  res = await C.call("plugin.install", { path: acme });
  t.check("installing twice is refused", code(res) === E.INVALID, why(res));
  t.check("plugin.changed is broadcast", C.find("plugin.changed", () => true).length > 0);

  res = await C.call("skill.list", { workspace_id: wid });
  t.check("plugin skill is listed (project one still wins the name)", res.result.skills.find((s) => s.name === "release-notes")?.scope === "project");
  await C.call("skill.delete", { scope: "project", workspace_id: wid, name: "release-notes" });
  await C.call("skill.delete", { scope: "user", name: "release-notes" });
  res = await C.call("skill.list", { workspace_id: wid });
  t.check("…after removing those, the plugin's skill shows", res.result.skills.find((s) => s.name === "release-notes")?.scope === "plugin" && res.result.skills.find((s) => s.name === "release-notes").plugin === "acme", why(res));

  const srv = await poll(async () => { const s = await server("acmetools"); return s?.state === "ready" ? s : null; });
  t.check("the plugin's MCP server starts (plugin root substituted) and lists its tool", srv?.plugin === "acme" && srv.tools[0]?.name === "echo_text", JSON.stringify(srv));
  t.check("an http server on a remote host is not added", !(await server("remote")));
  res = await C.call("mcp.remove", { id: srv.id });
  t.check("a plugin's server cannot be removed directly", code(res) === E.INVALID && /plugin/.test(res.error.message), why(res));
  res = await C.call("mcp.set_enabled", { id: srv.id, enabled: false });
  t.check("…nor disabled directly", code(res) === E.INVALID, why(res));

  step(toolEv("pm", "mcp__acmetools__echo_text", { text: "from plugin" }));
  step(textEv("done"));
  turn = await submit("use the plugin tool");
  t.check("plugin MCP tool is offered and asks for approval", await waitFor(() => evs(turn).some((e) => e.type === "approval_request"), 8000) && llm.requests.at(-1).tools.some((x) => x.name === "mcp__acmetools__echo_text"));
  await C.call("turn.approve", { turn_id: turn, call_id: "pm", allow: true });
  await waitFor(() => finished(turn), 8000);
  const out = evs(turn).find((e) => e.type === "tool_end")?.output ?? "";
  t.check("plugin MCP tool runs", /echo: from plugin/.test(out), out);
  mcpPid = Number(/pid (\d+)/.exec(out)?.[1]);

  // ---- disable / enable / restart / uninstall -------------------------------------------------------
  res = await C.call("plugin.set_enabled", { id: "acme", enabled: false });
  t.check("plugin.set_enabled(false)", res.result?.plugins?.[0]?.enabled === false, why(res));
  res = await C.call("skill.list", { workspace_id: wid });
  t.check("a disabled plugin's skills vanish", !res.result.skills.some((s) => s.name === "release-notes"));
  t.check("a disabled plugin's server is stopped and gone", !(await server("acmetools")) && (await waitFor(() => dead(mcpPid), 4000)), `pid ${mcpPid}`);
  await C.call("plugin.set_enabled", { id: "acme", enabled: true });

  C.close();
  await rt.stop();
  rt = await startRuntime({ stateDir, keepState: true });
  C = await session(rt);
  res = await C.call("plugin.list");
  t.check("installed plugins survive a restart", res.result?.plugins?.[0]?.id === "acme" && res.result.plugins[0].enabled === true, why(res));
  const again = await poll(async () => { const s = (await C.call("mcp.list")).result.servers.find((x) => x.name === "acmetools"); return s?.state === "ready" ? s : null; });
  t.check("…and their servers start again", !!again);
  res = await C.call("skill.list", {});
  t.check("…and their skills are back", res.result.skills.some((s) => s.name === "release-notes" && s.scope === "plugin"));

  // ---- marketplaces -----------------------------------------------------------------------------------
  res = await C.call("plugin.uninstall", { id: "acme" });
  t.check("plugin.uninstall", res.result?.uninstalled === true && !existsSync(join(stateDir, "plugins/acme")), why(res));
  res = await C.call("plugin.uninstall", { id: "acme" });
  t.check("uninstall twice -> not found", code(res) === E.NOT_FOUND, why(res));
  t.check("uninstall removes its server", await poll(async () => !(await C.call("mcp.list")).result.servers.some((s) => s.name === "acmetools")));

  res = await C.call("marketplace.add", { path: emptyFolder });
  t.check("a non-marketplace folder is refused", code(res) === E.INVALID, why(res));
  res = await C.call("marketplace.add", { path: market });
  const mk = res.result?.marketplace;
  t.check("marketplace.add lists its plugins (and drops ones that escape the folder)", mk?.name === "Acme Market" && mk.plugins.length === 1 && mk.plugins[0].name === "acme" && mk.plugins[0].installed === false, why(res));
  res = await C.call("marketplace.add", { path: market });
  t.check("adding it twice is refused", code(res) === E.INVALID, why(res));
  res = await C.call("plugin.install", { marketplace_id: mk.id, plugin: "escape" });
  t.check("a plugin the marketplace doesn't list (or that escapes) can't be installed", code(res) === E.INVALID, why(res));
  res = await C.call("plugin.install", {});
  t.check("install needs a path or marketplace + plugin", code(res) === E.INVALID, why(res));
  res = await C.call("plugin.install", { marketplace_id: mk.id, plugin: "acme" });
  t.check("install from a marketplace", res.result?.plugin?.id === "acme", why(res));
  res = await C.call("plugin.list");
  t.check("the marketplace shows it as installed", res.result.marketplaces[0].plugins[0].installed === true, why(res));
  res = await C.call("marketplace.remove", { id: mk.id });
  t.check("marketplace.remove keeps installed plugins", res.result?.removed === true && (await C.call("plugin.list")).result.plugins.length === 1);
  res = await C.call("marketplace.remove", { id: mk.id });
  t.check("remove twice -> not found", code(res) === E.NOT_FOUND, why(res));

  // ---- skill.import ---------------------------------------------------------------------------------------
  res = await C.call("skill.import", { path: skillsFolder, scope: "user" });
  t.check("skill.import (user)", res.result?.imported?.join() === "lint-fix", why(res));
  res = await C.call("skill.import", { path: skillsFolder, scope: "project", workspace_id: wid });
  t.check("skill.import (project)", existsSync(join(proj, ".opscode/skills/lint-fix/SKILL.md")), why(res));
  res = await C.call("skill.import", { path: emptyFolder, scope: "user" });
  t.check("import from a folder without skills -> error", code(res) === E.INVALID, why(res));
  res = await C.call("skill.import", { path: skillsFolder, scope: "project" });
  t.check("project import needs a project", code(res) === E.INVALID, why(res));

  mcpPid = (await C.call("mcp.list")).result.servers.length;
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  llmServer.close();
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
