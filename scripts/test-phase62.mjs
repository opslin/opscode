// Slice A of docs/quality-fix-plan.md (bugs found in the user's real chats, 2026-11-20):
//  A1 Claude Code keeps working after its `result` when a background job ends: its input must stay open, or its next
//     permission question fails with "Stream closed".
//  A2 Antigravity sends its command as rawInput.CommandLine: Auto must judge it like any command, not ask for `ls`.
//  A3 Codex runs without its own sandbox in Auto / Full access (network, Docker, local databases); risky commands still ask.
//  A4 A full disk no longer kills the runtime (chat saving retries), and a chat says when the disk is nearly full.
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const ROOT = process.cwd();
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p62-")));
const proj = join(base, "app");
mkdirSync(proj, { recursive: true });
const agyHome = join(base, "agy-default");
const qoderHome = join(base, "qoder-default");
for (const d of [agyHome, qoderHome]) { mkdirSync(d, { recursive: true }); writeFileSync(join(d, "fake-auth.json"), "{}"); }
const logFile = join(base, "engines.log");
writeFileSync(logFile, "");
const freeFile = join(base, "free-bytes");
const diskFull = join(base, "disk-full");
const stateDir = join(base, "state");
const GB = 1024 ** 3;
const env = {
  OPSCODE_CLAUDE_BIN: join(ROOT, "scripts/lib/fake-claude.mjs"),
  OPSCODE_CODEX_BIN: join(ROOT, "scripts/lib/fake-codex.mjs"),
  OPSCODE_AGY_BIN: join(ROOT, "scripts/lib/fake-acp.mjs"),
  OPSCODE_QODER_BIN: join(ROOT, "scripts/lib/fake-acp.mjs"),
  OPSCODE_FAKE_ENGINE_LOG: logFile,
  OPSCODE_FAKE_REAL_HOME: process.env.HOME ?? homedir(),
  OPSCODE_FAKE_DEFAULT_ACP_HOME: agyHome,
  OPSCODE_FAKE_DEFAULT_QODER_HOME: qoderHome,
  OPSCODE_CLAUDE_BG_IDLE_MS: "1500",
  OPSCODE_CLAUDE_BG_SETTLE_MS: "800",
  OPSCODE_FAKE_FREE_BYTES_FILE: freeFile,
  OPSCODE_FAKE_DISK_FULL: diskFull,
  OPSCODE_CHAT_SAVE_RETRY_MS: "300",
};
const L = () => readFileSync(logFile, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));

// ---- unit checks on the compiled code ----------------------------------------------------------------------------------
const { longLived } = await import(join(ROOT, "dist/runtime/engines/claude.js"));
const { commandOf, permissionPolicy } = await import(join(ROOT, "dist/runtime/engines/acp.js"));
const { CODEX_POLICY } = await import(join(ROOT, "dist/runtime/engines/codex.js"));
const { lowDiskCard } = await import(join(ROOT, "dist/runtime/disk.js"));

t.check("A1: a background dev server is not waited for", longLived({ name: "Bash", input: { command: "npm run dev", run_in_background: true } }));
t.check("A1: a background build is waited for", !longLived({ name: "Bash", input: { command: "flutter build apk --release", run_in_background: true } }) && !longLived({ name: "Bash", input: { command: "npm run build -- --watch=false", run_in_background: true } }));
t.check("A1: Monitor and helpers are waited for", !longLived({ name: "Monitor", input: {} }) && !longLived(undefined));
t.check("A2: the command is read from command, CommandLine and lists", commandOf({ command: "ls" }) === "ls" && commandOf({ CommandLine: "ls -la", WaitMsBeforeAsync: 5000 }) === "ls -la" && commandOf({ command: ["git", "status"] }) === "git status" && commandOf({ toolSummary: "x" }) === undefined);
t.check("A2: Auto lets a CommandLine `ls` run and asks for git push", permissionPolicy("auto", "execute", commandOf({ CommandLine: "ls -la" }), proj) === "allow" && permissionPolicy("auto", "execute", commandOf({ CommandLine: "git push origin main" }), proj) === "ask");
t.check("A3: Auto = full access, Codex asks outside its trusted list (Opscode answers by risk)", CODEX_POLICY.auto.sandbox === "danger-full-access" && CODEX_POLICY.auto.approvalPolicy === "untrusted" && CODEX_POLICY.auto.sandboxPolicy.type === "dangerFullAccess");
t.check("A3: Full access is really full; read-only and supervised stay locked", CODEX_POLICY.full.sandbox === "danger-full-access" && CODEX_POLICY.full.approvalPolicy === "never" && CODEX_POLICY.read.sandbox === "read-only" && CODEX_POLICY.read.sandboxPolicy.type === "readOnly" && CODEX_POLICY.supervised.sandbox === "read-only");
process.env.OPSCODE_FAKE_FREE_BYTES_FILE = freeFile; // this process reads it too (the unit checks)
writeFileSync(freeFile, String(2.1 * GB));
t.check("A4: under 5 GB a low-disk card is made", lowDiskCard(proj)?.summary === "Low disk space: 2.1 GB free", JSON.stringify(lowDiskCard(proj)));
writeFileSync(freeFile, String(0.4 * GB));
t.check("A4: under 1 GB it says almost full", lowDiskCard(proj)?.summary === "Disk almost full: 0.4 GB free");
writeFileSync(freeFile, String(50 * GB));
t.check("A4: with enough space there is no card", lowDiskCard(proj) === null);

// ---- end to end ---------------------------------------------------------------------------------------------------------
const rt = await startRuntime({ env, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const waitFor = async (fn, ms = 8000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(40)) { const v = await fn(); if (v) return v; } return null; };
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  const events = (turnId) => C.find("turn.event", (p) => p.turn_id === turnId).map((n) => n.params);
  const text = (turnId) => events(turnId).filter((e) => e.type === "delta").map((e) => e.text).join("");
  const ended = (turnId) => events(turnId).find((e) => ["completed", "failed", "interrupted"].includes(e.type));
  const submit = async (chatId, txt) => (await C.call("turn.submit", { workspace_id: wid, chat_id: chatId, text: txt })).result.turn_id;
  const say = async (chatId, txt, ms = 10000) => { const id = await submit(chatId, txt); await waitFor(() => ended(id), ms); return id; };
  const newChat = async (engine) => (await C.call("chat.create", { workspace_id: wid, engine })).result.chat;

  // A1 ----------------------------------------------------------------------------------------------------------------------
  const claude = await newChat("claude-code");
  t.check("new chats start in Auto", claude.mode === "auto", claude.mode);
  let turn = await say(claude.id, "build it FAKE_BG");
  t.check("A1: after a background build ends, Claude Code's next question is answered (no Stream closed)", L().some((l) => l.bg_after === "allow") && !L().some((l) => /Stream closed/.test(l.message ?? "")), JSON.stringify(L().filter((l) => "bg_after" in l)));
  t.check("A1: the turn ends only after the second result, with the final text", ended(turn)?.type === "completed" && text(turn).includes("The build is done: app-release.apk."), text(turn));

  let t0 = Date.now();
  turn = await say(claude.id, "start the server FAKE_BG_SERVER");
  t.check("A1: a background dev server does not keep the turn open", ended(turn)?.type === "completed" && Date.now() - t0 < 1400, `${Date.now() - t0} ms`);

  t0 = Date.now();
  turn = await say(claude.id, "build it FAKE_BG_SILENT", 8000);
  t.check("A1: a job that never reports back ends the wait after the idle limit, and says so", ended(turn)?.type === "completed" && Date.now() - t0 >= 1400 && text(turn).includes("Opscode stopped waiting: Release build sent nothing for 2 seconds"), `${Date.now() - t0} ms: ${text(turn)}`);

  turn = await submit(claude.id, "build it FAKE_BG_SILENT");
  await waitFor(() => text(turn).includes("Started it in the background."));
  await C.call("turn.interrupt", { turn_id: turn });
  t.check("A1: Stop still ends a turn that is waiting for a background job", !!(await waitFor(() => ended(turn)?.type === "interrupted", 4000)));

  turn = await say(claude.id, "hello");
  t.check("A1: a turn with no background job ends as before", ended(turn)?.type === "completed" && text(turn).includes("Claude says: hello"));

  // A2 ----------------------------------------------------------------------------------------------------------------------
  const agy = await newChat("antigravity");
  writeFileSync(logFile, "");
  turn = await say(agy.id, "FAKE_CMD_AGY ls -la", 15000);
  t.check("A2: an Antigravity `ls` (CommandLine) runs in Auto without asking", !events(turn).some((e) => e.type === "approval_request") && L().some((l) => l.ev === "permission" && l.allowed === true) && text(turn).includes("Ran it."), JSON.stringify(events(turn).map((e) => e.type)));
  t.check("A2: its card shows the command", events(turn).some((e) => e.type === "tool_start" && e.summary === "Run ls -la"), JSON.stringify(events(turn).filter((e) => e.type === "tool_start").map((e) => e.summary)));
  turn = await submit(agy.id, "FAKE_CMD_AGY git push origin main");
  const ask = await waitFor(() => events(turn).find((e) => e.type === "approval_request"), 15000);
  t.check("A2: an Antigravity git push still asks", !!ask, JSON.stringify(events(turn).map((e) => e.type)));
  if (ask) await C.call("turn.approve", { turn_id: turn, call_id: ask.call_id, allow: false });
  await waitFor(() => ended(turn), 15000);
  t.check("A2: after Deny it does not run", text(turn).includes("Not allowed."), text(turn));
  const qoder = await newChat("qoder");
  turn = await say(qoder.id, "FAKE_CMD ls", 15000);
  t.check("A2: Qoder's `command` keeps working (ls runs without asking)", !events(turn).some((e) => e.type === "approval_request") && text(turn).includes("Ran it."), JSON.stringify(events(turn).map((e) => e.type)));

  // A3 ----------------------------------------------------------------------------------------------------------------------
  const codex = await newChat("codex");
  writeFileSync(logFile, "");
  turn = await say(codex.id, "hi");
  const ts = L().find((l) => l.method === "turn/start");
  const th = L().find((l) => l.method === "thread/start");
  t.check("A3: a Codex chat in Auto starts its thread and turn with full access", th?.params.sandbox === "danger-full-access" && th.params.approvalPolicy === "untrusted" && ts?.params.sandboxPolicy?.type === "dangerFullAccess", JSON.stringify({ thread: th?.params.sandbox, turn: ts?.params.sandboxPolicy }));
  await C.call("chat.set_mode", { chat_id: codex.id, mode: "read" });
  writeFileSync(logFile, "");
  await say(codex.id, "hi again");
  t.check("A3: read-only still locks Codex", L().find((l) => l.method === "turn/start")?.params.sandboxPolicy?.type === "readOnly");

  // A4 ----------------------------------------------------------------------------------------------------------------------
  writeFileSync(freeFile, String(2.1 * GB));
  turn = await say(claude.id, "hello disk");
  const diskCard = events(turn).find((e) => e.type === "tool_start" && e.tool === "disk_space");
  t.check("A4: a chat shows a low-disk card", diskCard?.summary === "Low disk space: 2.1 GB free", JSON.stringify(diskCard));
  t.check("A4: the reply still comes", text(turn).includes("Claude says: hello disk"));
  writeFileSync(freeFile, String(50 * GB));
  turn = await say(claude.id, "hello space");
  t.check("A4: with enough space there is no card", !events(turn).some((e) => e.tool === "disk_space"));

  const chatFile = join(stateDir, "chats", `${claude.id}.json`);
  writeFileSync(diskFull, "");
  turn = await say(claude.id, "while the disk is full");
  await sleep(700);
  const alive = await C.call("chat.list", {});
  t.check("A4: a failed chat save does not crash the runtime", !!alive.result?.chats && rt.child?.exitCode == null, rt.output().split("\n").filter((l) => /ENOSPC|exited/.test(l)).join(" | "));
  t.check("A4: while saving fails, the new message is not on disk", !readFileSync(chatFile, "utf8").includes("while the disk is full"));
  rmSync(diskFull);
  t.check("A4: once there is space again, the chat is saved", !!(await waitFor(() => readFileSync(chatFile, "utf8").includes("while the disk is full"), 3000)));
  t.check("A4: no cut-off temp files are left in the chats folder", !(await import("node:fs")).readdirSync(join(stateDir, "chats")).some((f) => f.endsWith(".tmp")));
  C.close();
} finally {
  await rt.stop();
  rmSync(base, { recursive: true, force: true });
}
process.exit(t.finish());
