#!/usr/bin/env node
// A stand-in for an ACP coding agent (Antigravity's `agy acp`, Qoder's `qoder --acp`), for tests.
//   fake-acp.mjs acp        Antigravity flavour: its sign-in lives in $HOME (an added account has its own HOME)
//   fake-acp.mjs --acp      Qoder flavour: its sign-in lives in $QODER_CONFIG_DIR
//   fake-acp.mjs login      (Qoder) browser sign-in: opens a link with `open`, finishes when fake-login-complete.json appears
//   fake-acp.mjs --version
// "The Mac's own" sign-in is in OPSCODE_FAKE_DEFAULT_ACP_HOME (agy) / OPSCODE_FAKE_DEFAULT_QODER_HOME (qoder), used when the
// program was not pointed at an account folder. fake-auth.json there = signed in.
// Prompts: "FAKE_CMD <command>" runs a command card (asks first), "FAKE_EDIT <path>" an edit card, "FAKE_SLOW" streams slowly,
// anything else is answered with "ACP reply: <text>".

import { spawn } from "node:child_process";
import { appendFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { createInterface } from "node:readline";

const argv = process.argv.slice(2);
const log = (o) => { if (process.env.OPSCODE_FAKE_ENGINE_LOG) appendFileSync(process.env.OPSCODE_FAKE_ENGINE_LOG, `${JSON.stringify({ bin: "acp", argv, home: process.env.HOME, qoder_dir: process.env.QODER_CONFIG_DIR, has_pat: !!process.env.QODER_PERSONAL_ACCESS_TOKEN, has_gemini_key: !!process.env.GEMINI_API_KEY, ...o })}\n`); };
const qoder = argv[0] === "--acp" || argv[0] === "login" || argv[0] === "logout";
const dir = qoder
  ? process.env.QODER_CONFIG_DIR || process.env.OPSCODE_FAKE_DEFAULT_QODER_HOME
  : process.env.HOME !== process.env.OPSCODE_FAKE_REAL_HOME ? process.env.HOME : process.env.OPSCODE_FAKE_DEFAULT_ACP_HOME;
const authFile = join(dir, "fake-auth.json");
const sessionsFile = join(dir, "fake-sessions.json");
const signedIn = () => existsSync(authFile);
const sessions = () => { try { return JSON.parse(readFileSync(sessionsFile, "utf8")); } catch { return []; } };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

if (argv[0] === "--version") { console.log(qoder ? "qoder 0.9.9 (fake)" : "agy 1.5.9 (fake)"); process.exit(0); }

/** The browser sign-in: open a link, then wait for the test to say the person finished (or failed). */
async function browserLogin() {
  const done = join(dir, "fake-login-complete.json");
  rmSync(done, { force: true });
  const url = `https://${process.env.OPSCODE_FAKE_LOGIN_HOST || (qoder ? "qoder.com/fake-login" : "accounts.google.com/o/oauth2/fake")}?state=${Math.random().toString(36).slice(2, 8)}`;
  spawn("open", [url], { stdio: "ignore" }).on("error", () => {});
  log({ ev: "login_started", url });
  for (let i = 0; i < 600; i++) {
    if (existsSync(done)) {
      const r = JSON.parse(readFileSync(done, "utf8"));
      rmSync(done, { force: true });
      if (r.fail) throw Object.assign(new Error(String(r.fail)), { code: -32603 });
      mkdirSync(dir, { recursive: true });
      writeFileSync(authFile, JSON.stringify({ at: Date.now() }));
      return;
    }
    await sleep(100);
  }
  throw new Error("timed out");
}

if (argv[0] === "login") {
  console.log("Opening your browser to sign in…");
  browserLogin().then(() => { console.log("Signed in."); process.exit(0); }, (e) => { console.error(e.message); process.exit(1); });
} else if (argv[0] === "logout") {
  rmSync(authFile, { force: true });
  process.exit(0);
} else {
  serve();
}

function serve() {
  const out = (m) => process.stdout.write(`${JSON.stringify({ jsonrpc: "2.0", ...m })}\n`);
  const reply = (id, result) => out({ id, result });
  const fail = (id, code, message) => out({ id, error: { code, message } });
  const update = (sessionId, u) => out({ method: "session/update", params: { sessionId, update: u } });
  const waiting = new Map();
  let nextReq = 1000;
  const ask = (method, params) => new Promise((resolve) => { const id = nextReq++; waiting.set(id, resolve); out({ id, method, params }); });
  const cancelled = new Set();
  const modelList = [{ modelId: "fast-1", name: "Fast One" }, { modelId: "smart-2", name: "Smart Two" }];
  const sessionInfo = (sessionId) => ({ sessionId, models: { availableModels: modelList, currentModelId: "fast-1" }, modes: { currentModeId: "default", availableModes: [{ id: "default", name: "Default" }] } });
  const models = new Map();
  const mcpOf = new Map(); // session -> its http MCP servers

  async function prompt(id, p) {
    const sid = p.sessionId;
    const text = (p.prompt ?? []).filter((b) => b.type === "text").map((b) => b.text).join("\n");
    const images = (p.prompt ?? []).filter((b) => b.type === "image").length;
    log({ ev: "prompt", text, images, model: models.get(sid) ?? "fast-1", session: sid });
    // The voice agent (brain mode): FAKE_TOOL <name> <json> calls its tools over MCP like Antigravity (tool named mcp_opscode_chief_<name>, asks first).
    const chiefSrv = (mcpOf.get(sid) ?? []).find((s) => s.name === "opscode_chief");
    const toolCalls = chiefSrv ? [...text.matchAll(/FAKE_TOOL ([a-z_]+) (\{.*\})(?:<\/note>|<\/heard>)?\s*$/gm)] : [];
    if (toolCalls.length) {
      const hdr = Object.fromEntries((chiefSrv.headers ?? []).map((h) => [h.name, h.value]));
      const post = (n, method, params) => fetch(chiefSrv.url, { method: "POST", headers: { ...hdr, "content-type": "application/json" }, body: JSON.stringify({ jsonrpc: "2.0", id: n, method, params }) }).then((x) => x.json());
      await post(1, "initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "fake", version: "1" } });
      let k = 0;
      for (const [, name, json] of toolCalls) {
        const callId = `mcp-${++k}`;
        const nm = `mcp_opscode_chief_${name}`;
        update(sid, { sessionUpdate: "tool_call", toolCallId: callId, title: `Run ${nm}`, kind: "other", status: "in_progress", rawInput: { toolSummary: name } });
        const r = await ask("session/request_permission", { sessionId: sid, toolCall: { toolCallId: callId, name: nm, title: `Run ${nm}`, kind: "other", args: JSON.parse(json), rawInput: { toolSummary: name } }, options: [{ optionId: "yes", name: "Allow", kind: "allow_once" }, { optionId: "no", name: "Reject", kind: "reject_once" }] });
        const allowed = r?.outcome?.outcome === "selected" && r.outcome.optionId === "yes";
        let t = "rejected";
        if (allowed) { const res = await post(k + 1, "tools/call", { name, arguments: JSON.parse(json) }); t = res.result?.content?.find((c) => c.type === "text")?.text ?? ""; }
        log({ ev: "chief_tool", name, allowed, result: t });
        update(sid, { sessionUpdate: "tool_call_update", toolCallId: callId, title: `Run ${nm}`, kind: "other", status: allowed ? "completed" : "failed" });
      }
    }
    const cmd = /FAKE_CMD (.+?)(?: FAKE_TOOL |$)/m.exec(text)?.[1]?.trim();
    const edit = /FAKE_EDIT (\S+)/.exec(text)?.[1];
    update(sid, { sessionUpdate: "agent_thought_chunk", content: { type: "text", text: "thinking" } });
    if (cmd) {
      const callId = `c-${Math.random().toString(36).slice(2, 7)}`;
      update(sid, { sessionUpdate: "tool_call", toolCallId: callId, title: `Run ${cmd}`, kind: "execute", status: "pending", rawInput: { command: cmd } });
      const r = await ask("session/request_permission", { sessionId: sid, toolCall: { toolCallId: callId, title: `Run ${cmd}`, kind: "execute", rawInput: { command: cmd } }, options: [{ optionId: "yes", name: "Allow", kind: "allow_once" }, { optionId: "no", name: "Reject", kind: "reject_once" }] });
      const allowed = r?.outcome?.outcome === "selected" && r.outcome.optionId === "yes";
      log({ ev: "permission", kind: "execute", allowed });
      update(sid, { sessionUpdate: "tool_call_update", toolCallId: callId, status: allowed ? "completed" : "failed", content: [{ type: "content", content: { type: "text", text: allowed ? "command output" : "rejected" } }] });
      update(sid, { sessionUpdate: "agent_message_chunk", content: { type: "text", text: allowed ? "Ran it." : "Not allowed." } });
    } else if (edit) {
      const callId = `e-${Math.random().toString(36).slice(2, 7)}`;
      update(sid, { sessionUpdate: "tool_call", toolCallId: callId, title: `Edit ${edit}`, kind: "edit", status: "pending", locations: [{ path: edit }] });
      const r = await ask("session/request_permission", { sessionId: sid, toolCall: { toolCallId: callId, title: `Edit ${edit}`, kind: "edit" }, options: [{ optionId: "yes", name: "Allow", kind: "allow_once" }, { optionId: "no", name: "Reject", kind: "reject_once" }] });
      const allowed = r?.outcome?.outcome === "selected" && r.outcome.optionId === "yes";
      log({ ev: "permission", kind: "edit", allowed });
      update(sid, { sessionUpdate: "tool_call_update", toolCallId: callId, status: allowed ? "completed" : "failed", content: [{ type: "diff", path: edit, oldText: "", newText: "hello" }] });
      update(sid, { sessionUpdate: "agent_message_chunk", content: { type: "text", text: allowed ? "Edited." : "Not allowed." } });
    } else if (/FAKE_SLOW/.test(text)) {
      for (let i = 0; i < 100 && !cancelled.has(sid); i++) { update(sid, { sessionUpdate: "agent_message_chunk", content: { type: "text", text: `tick${i} ` } }); await sleep(100); }
      if (cancelled.has(sid)) { cancelled.delete(sid); return reply(id, { stopReason: "cancelled" }); }
    } else if (chiefSrv) {
      update(sid, { sessionUpdate: "agent_message_chunk", content: { type: "text", text: toolCalls.length ? "Chief handled it." : "Chief read the note." } });
    } else {
      const words = `ACP reply: ${text.split("\n").at(-1)}`.split(/(\s+)/);
      for (const w of words) if (w) update(sid, { sessionUpdate: "agent_message_chunk", content: { type: "text", text: w } });
    }
    update(sid, { sessionUpdate: "usage_update", used: 1234, size: 100000 });
    reply(id, { stopReason: "end_turn" });
  }

  const rl = createInterface({ input: process.stdin });
  rl.on("line", async (line) => {
    let m;
    try { m = JSON.parse(line); } catch { return; }
    if (m.id !== undefined && !m.method) { waiting.get(m.id)?.(m.result ?? { outcome: { outcome: "cancelled" } }); waiting.delete(m.id); return; }
    const { id, method, params: p } = m;
    switch (method) {
      case "initialize":
        log({ ev: "initialize" });
        return reply(id, { protocolVersion: 1, agentCapabilities: { loadSession: true, ...(process.env.OPSCODE_FAKE_ACP_MCP === "1" ? { mcpCapabilities: { http: true } } : {}), promptCapabilities: { image: true }, sessionCapabilities: qoder ? {} : { resume: {} }, auth: qoder ? {} : { logout: {} } }, agentInfo: { name: qoder ? "Fake Qoder" : "Fake Antigravity", version: "0" }, authMethods: [{ id: "oauth-personal", name: "Log in with Google" }] });
      case "authenticate":
        try { await browserLogin(); reply(id, {}); } catch (e) { fail(id, e.code ?? -32603, e.message); }
        return;
      case "logout": rmSync(authFile, { force: true }); return reply(id, {});
      case "session/new": {
        if (process.env.OPSCODE_FAKE_ACP_SLOW_MS) await sleep(Number(process.env.OPSCODE_FAKE_ACP_SLOW_MS));
        if (!signedIn()) return fail(id, -32000, "Authentication required");
        const sid = `s-${Math.random().toString(36).slice(2, 10)}`;
        mkdirSync(dir, { recursive: true });
        writeFileSync(sessionsFile, JSON.stringify([...sessions(), sid]));
        mcpOf.set(sid, p.mcpServers ?? []);
        log({ ev: "session_new", cwd: p.cwd, mcp: p.mcpServers });
        return reply(id, sessionInfo(sid));
      }
      case "session/resume":
      case "session/load":
        if (!signedIn()) return fail(id, -32000, "Authentication required");
        if (!sessions().includes(p.sessionId)) return fail(id, -32602, "unknown session");
        log({ ev: method, session: p.sessionId });
        if (method === "session/load") update(p.sessionId, { sessionUpdate: "agent_message_chunk", content: { type: "text", text: "REPLAYED HISTORY" } });
        return reply(id, sessionInfo(p.sessionId));
      case "session/set_model": models.set(p.sessionId, p.modelId); return reply(id, {});
      case "session/prompt": prompt(id, p).catch((e) => fail(id, -32603, String(e?.message ?? e))); return;
      case "session/cancel": cancelled.add(p.sessionId); return;
      default: if (id !== undefined) fail(id, -32601, `unknown method ${method}`);
    }
  });
  rl.on("close", () => process.exit(0));
}
