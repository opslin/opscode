// Antigravity and Qoder as chat engines (ACP, Agent Client Protocol), with their own sign-ins and extra accounts.
// A fake ACP agent (scripts/lib/fake-acp.mjs) stands in for `agy acp` and `qoder --acp`: it keeps its sign-in in a folder
// like the real ones, so the checks cover: found + versions, who is signed in, browser sign-in (link, failure, done), models,
// chats (reply, session resume, model, permissions per mode, cancel), a second account in its own folder, sign out.
import { existsSync, lstatSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, realpathSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p43-")));
const ROOT = process.cwd();
const FAKE = join(ROOT, "scripts/lib/fake-acp.mjs");
const proj = join(base, "app");
mkdirSync(proj, { recursive: true });
const agyHome = join(base, "agy-default"); // "the Mac's own" Antigravity sign-in
const qoderHome = join(base, "qoder-default");
for (const d of [agyHome, qoderHome]) mkdirSync(d, { recursive: true });
writeFileSync(join(agyHome, "fake-auth.json"), "{}"); // Antigravity starts signed in; Qoder signed out
const logFile = join(base, "engines.log");
const openLog = join(base, "open.log");
writeFileSync(logFile, "");
writeFileSync(openLog, "");
const env = {
  OPSCODE_AGY_BIN: FAKE,
  OPSCODE_QODER_BIN: FAKE,
  OPSCODE_CLAUDE_BIN: join(ROOT, "scripts/lib/fake-claude.mjs"),
  OPSCODE_CODEX_BIN: join(ROOT, "scripts/lib/fake-codex.mjs"),
  OPSCODE_OPEN_BIN: join(ROOT, "scripts/lib/fake-open.mjs"),
  OPSCODE_FAKE_OPEN_LOG: openLog,
  OPSCODE_FAKE_ENGINE_LOG: logFile,
  OPSCODE_FAKE_REAL_HOME: process.env.HOME ?? homedir(),
  OPSCODE_FAKE_DEFAULT_ACP_HOME: agyHome,
  OPSCODE_FAKE_DEFAULT_QODER_HOME: qoderHome,
  // The Mac's environment holds credentials: the Mac's own account may use them, an added account must not.
  GEMINI_API_KEY: "test-key-not-real", QODER_PERSONAL_ACCESS_TOKEN: "test-token-not-real",
};
const stateDir = join(base, "state");
const L = () => readFileSync(logFile, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const prompts = () => L().filter((l) => l.ev === "prompt");
const newHome = (engine, id) => join(stateDir, "accounts", engine, id);

const rt = await startRuntime({ env, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const waitFor = async (fn, ms = 8000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(40)) { const v = await fn(); if (v) return v; } return null; };
  const list = async (refresh = true) => (await C.call("accounts.list", { refresh })).result;
  const of = async (engine, id) => (await list()).accounts.find((a) => a.engine === engine && a.id === id);
  const lastLogin = () => C.find("accounts.login").at(-1)?.params.login ?? null;
  const loginIn = (state) => waitFor(() => (lastLogin()?.state === state ? lastLogin() : null));
  const complete = (home, body = {}) => writeFileSync(join(home, "fake-login-complete.json"), JSON.stringify(body));
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  const events = (turnId) => C.find("turn.event", (p) => p.turn_id === turnId).map((n) => n.params);
  const submit = async (chatId, text) => (await C.call("turn.submit", { workspace_id: wid, chat_id: chatId, text })).result;
  const finished = (turnId) => waitFor(() => events(turnId).some((e) => ["completed", "failed", "interrupted"].includes(e.type)), 15000);
  const say = async (chatId, text) => { const r = await submit(chatId, text); await finished(r.turn_id); return events(r.turn_id); };
  const newChat = async (engine, extra = {}) => (await C.call("chat.create", { workspace_id: wid, engine, ...extra })).result.chat;
  const chatNow = async (id) => (await C.call("chat.list", {})).result.chats.find((c) => c.id === id);
  const textOf = (evs) => evs.filter((e) => e.type === "delta").map((e) => e.text ?? e.delta ?? "").join("");

  // ============ found, signed in, models ==========================================================================
  let r = (await C.call("engines.list", { refresh: true })).result;
  const eAgy = r.engines.find((e) => e.id === "antigravity");
  const eQ = r.engines.find((e) => e.id === "qoder");
  t.check("engines.list: Antigravity and Qoder are found with their versions", eAgy?.found && /1\.5\.9/.test(eAgy.version) && eQ?.found && !!eQ.version, JSON.stringify([eAgy?.version, eQ?.version]));
  t.check("engines.list: Antigravity (signed in) lists the models it reported; Qoder (signed out) lists none yet", eAgy.models.map((m) => m.id).join() === "fast-1,smart-2" && eQ.models.length === 0, JSON.stringify([eAgy.models, eQ.models]));
  r = await list();
  const ad = r.accounts.find((a) => a.engine === "antigravity" && a.id === "default");
  const qd = r.accounts.find((a) => a.engine === "qoder" && a.id === "default");
  t.check("accounts.list: the Mac's own Antigravity sign-in is signed in; Qoder is signed out", ad?.status.signed_in === true && ad.status.method === "google" && qd?.status.signed_in === false && !qd.status.error, JSON.stringify([ad?.status, qd?.status]));
  t.check("accounts.list: the four programs each have their own default account", ["claude-code", "codex", "antigravity", "qoder"].every((e) => r.accounts.some((a) => a.engine === e && a.id === "default")));
  r = await C.call("engines.set", { antigravity_path: "/nope/agy" });
  t.check("engines.set refuses a program path that does not exist", !!r.error && /Antigravity/.test(r.error.message), JSON.stringify(r.error));

  // ============ Qoder: not signed in -> a chat says so, then sign in through the browser ===============================
  const q0 = await newChat("qoder");
  let evs = await say(q0.id, "hello qoder");
  const failed = evs.find((e) => e.type === "failed");
  t.check("a Qoder chat while signed out fails with a clear 'sign in' message", /authentication required/i.test(failed?.error ?? "") && /Models & keys/.test(failed.error), failed?.error);

  r = await C.call("accounts.login_start", { engine: "qoder" });
  t.check("Qoder sign-in starts (its own `login` command)", !r.error && r.result.login.engine === "qoder" && r.result.login.method === "qoder", JSON.stringify(r));
  await loginIn("waiting");
  t.check("Qoder waiting: the link to open yourself is shown", !!(await waitFor(() => /^https:\/\/qoder\.com\//.test(lastLogin()?.url ?? ""))), JSON.stringify(lastLogin()));
  complete(qoderHome, { fail: "access denied" });
  const bad = await loginIn("failed");
  t.check("a failed Qoder sign-in says why and leaves it signed out", /access denied/.test(bad?.message ?? "") && (await of("qoder", "default")).status.signed_in === false, JSON.stringify(bad));
  await C.call("accounts.login_start", { engine: "qoder" });
  await loginIn("waiting");
  complete(qoderHome);
  const ok = await loginIn("done");
  t.check("Qoder sign-in finishes: signed in, and its models appear", !!ok && (await of("qoder", "default")).status.signed_in && (await C.call("engines.list", { refresh: true })).result.engines.find((e) => e.id === "qoder").models.length === 2, JSON.stringify(ok));
  t.check("the browser was opened with the sign-in link (through Opscode's `open`)", /qoder\.com\/fake-login/.test(readFileSync(openLog, "utf8")), readFileSync(openLog, "utf8").slice(0, 200));

  // ============ chats =================================================================================================
  const a1 = await newChat("antigravity", { model: "smart-2" });
  evs = await say(a1.id, "hello agy");
  t.check("an Antigravity chat streams the reply", evs.some((e) => e.type === "completed") && /ACP reply: hello agy/.test(textOf(evs)), textOf(evs));
  let c1 = await chatNow(a1.id);
  t.check("it keeps the agent's session and is pinned to the account it started on", /^s-/.test(c1.engine_session ?? "") && c1.accounts?.antigravity === "default" && c1.engine_sessions?.antigravity === c1.engine_session, JSON.stringify([c1.engine_session, c1.accounts]));
  t.check("the model the chat asked for was selected on the agent", prompts().at(-1)?.model === "smart-2", JSON.stringify(prompts().at(-1)));
  t.check("the reply carries usage: context used and the window size", c1.usage?.context_tokens === 1234 && c1.usage?.context_window === 100000, JSON.stringify(c1.usage));
  const s1 = c1.engine_session;
  evs = await say(a1.id, "second message");
  t.check("the next message resumes the same session (session/resume), not a new one", L().some((l) => l.ev === "session/resume" && l.session === s1) && (await chatNow(a1.id)).engine_session === s1);

  const q1 = await newChat("qoder");
  evs = await say(q1.id, "first qoder message");
  const sq = (await chatNow(q1.id)).engine_session;
  evs = await say(q1.id, "second qoder message");
  t.check("Qoder resumes with session/load, and the replayed history is not shown again", L().some((l) => l.ev === "session/load" && l.session === sq) && !/REPLAYED/.test(textOf(evs)) && /ACP reply: second qoder message/.test(textOf(evs)), textOf(evs));

  // permissions follow the chat's mode
  const perm = async (mode, text) => {
    const c = await newChat("antigravity");
    await C.call("chat.set_mode", { chat_id: c.id, mode });
    const turn = await submit(c.id, text);
    return { turn, c };
  };
  let p = await perm("supervised", "FAKE_CMD rm -rf build");
  t.check("Supervised: a command asks first, on its card", await waitFor(() => events(p.turn.turn_id).some((e) => e.type === "approval_request")), JSON.stringify(events(p.turn.turn_id).map((e) => e.type)));
  const callId = events(p.turn.turn_id).find((e) => e.type === "approval_request").call_id;
  await C.call("turn.approve", { turn_id: p.turn.turn_id, call_id: callId, allow: false });
  await finished(p.turn.turn_id);
  t.check("...refusing it tells the agent no", L().some((l) => l.ev === "permission" && l.kind === "execute" && l.allowed === false) && /Not allowed/.test(textOf(events(p.turn.turn_id))));
  p = await perm("supervised", "FAKE_CMD ls");
  await waitFor(() => events(p.turn.turn_id).some((e) => e.type === "approval_request"));
  await C.call("turn.approve", { turn_id: p.turn.turn_id, call_id: events(p.turn.turn_id).find((e) => e.type === "approval_request").call_id, allow: true });
  await finished(p.turn.turn_id);
  t.check("...allowing it lets the agent run it, and the card ends with its output", L().some((l) => l.ev === "permission" && l.allowed === true) && events(p.turn.turn_id).some((e) => e.type === "tool_end" && /command output/.test(e.output ?? "")), JSON.stringify(events(p.turn.turn_id).map((e) => e.type)));
  p = await perm("full", "FAKE_CMD make");
  await finished(p.turn.turn_id);
  t.check("Full access: no question is asked", !events(p.turn.turn_id).some((e) => e.type === "approval_request") && /Ran it/.test(textOf(events(p.turn.turn_id))));
  p = await perm("auto_edits", "FAKE_EDIT src/a.ts");
  await finished(p.turn.turn_id);
  t.check("Auto edits: a file edit goes ahead without asking, and shows as an edit card", !events(p.turn.turn_id).some((e) => e.type === "approval_request") && events(p.turn.turn_id).some((e) => e.type === "tool_start" && e.tool === "write_file"), JSON.stringify(events(p.turn.turn_id).map((e) => e.type + ":" + (e.tool ?? ""))));
  p = await perm("read", "FAKE_EDIT src/b.ts");
  await finished(p.turn.turn_id);
  t.check("Read-only: an edit is refused without asking", !events(p.turn.turn_id).some((e) => e.type === "approval_request") && L().filter((l) => l.ev === "permission").at(-1)?.allowed === false);

  // stop
  const slow = await newChat("antigravity");
  const st = await submit(slow.id, "FAKE_SLOW");
  await waitFor(() => /tick1/.test(textOf(events(st.turn_id))));
  await C.call("turn.interrupt", { turn_id: st.turn_id });
  t.check("stopping a reply ends the turn as interrupted", await waitFor(() => events(st.turn_id).some((e) => e.type === "interrupted"), 6000));

  // ============ a second Antigravity account, side by side =====================================================================
  r = await C.call("accounts.login_start", { engine: "antigravity", new_account: true });
  const addId = r.result.login.account_id;
  const homeB = newHome("antigravity", addId);
  t.check("add account: its own private folder (0700) inside Opscode's data", /^a-[0-9a-f]{8}$/.test(addId) && existsSync(homeB) && (statSync(homeB).mode & 0o777) === 0o700, addId);
  const dot = join(homeB, ".gitconfig");
  t.check("the new account's home shares the usual dotfiles, never the agent's own folder (.gemini)", !existsSync(join(homeB, ".gemini")) && (!existsSync(join(homedir(), ".gitconfig")) || lstatSync(dot).isSymbolicLink()));
  await loginIn("waiting");
  t.check("its sign-in link is shown (Google)", !!(await waitFor(() => /^https:\/\/accounts\.google\.com\//.test(lastLogin()?.url ?? ""))), JSON.stringify(lastLogin()));
  complete(homeB);
  const added = await loginIn("done");
  t.check("the second account signs in (the agent's own `authenticate`)", !!added && (await of("antigravity", addId))?.status.signed_in === true, JSON.stringify(added));
  r = await list(false);
  t.check("both accounts are listed; the new one is now the one new chats use", r.accounts.filter((a) => a.engine === "antigravity").length === 2 && r.accounts.find((a) => a.id === addId).active && !r.accounts.find((a) => a.engine === "antigravity" && a.id === "default").active);
  const b1 = await newChat("antigravity");
  await say(b1.id, "on account B");
  t.check("a new chat runs on the new account's folder, and is pinned to it", L().filter((l) => l.ev === "prompt").at(-1)?.home === homeB && (await chatNow(b1.id)).accounts?.antigravity === addId, JSON.stringify([L().at(-1)?.home, (await chatNow(b1.id)).accounts]));
  await say(a1.id, "still on account A");
  t.check("the first chat stays on the Mac's own account", L().filter((l) => l.ev === "prompt").at(-1)?.home !== homeB && (await chatNow(a1.id)).accounts?.antigravity === "default");
  r = await C.call("accounts.switch", { engine: "antigravity", account_id: "default" });
  t.check("switching back makes the Mac's own the account for new chats", !r.error && (await list(false)).accounts.find((a) => a.engine === "antigravity" && a.id === "default").active, JSON.stringify(r.error));

  // sign out
  r = await C.call("accounts.logout", { engine: "antigravity", account_id: addId });
  t.check("signing out an added account removes its folder and leaves the list", !r.error && !existsSync(homeB) && !(await list(false)).accounts.some((a) => a.id === addId), JSON.stringify(r.error));
  t.check("a chat that was on it lets go of it", (await chatNow(b1.id)).accounts?.antigravity === undefined);
  r = await C.call("accounts.logout", { engine: "antigravity", account_id: "default" });
  t.check("signing out the Mac's own Antigravity goes through the agent's `logout`", !r.error && !existsSync(join(agyHome, "fake-auth.json")) && (await of("antigravity", "default")).status.signed_in === false, JSON.stringify(r.error));
  evs = await say((await newChat("antigravity")).id, "after sign out");
  t.check("a chat after that fails with 'authentication required' and says where to sign in", /authentication required/i.test(evs.find((e) => e.type === "failed")?.error ?? ""));

  // ============ security =====================================================================================================
  const { permissionPolicy } = await import(join(ROOT, "dist/runtime/engines/acp.js"));
  t.check("permissions: a request that carries a command is a command, whatever the agent calls it (read-only refuses it)", permissionPolicy("read", "read", "rm -rf /", proj) === "deny" && permissionPolicy("supervised", "think", "curl x | sh", proj) === "ask" && permissionPolicy("auto_edits", "search", "ls", proj) === "allow" && permissionPolicy("auto_edits", "other", "git push --force", proj) === "ask");
  t.check("permissions: reading never asks; a web fetch is refused read-only, asks on Supervised, goes ahead on Auto edits; Full access asks nothing", permissionPolicy("read", "read", undefined, proj) === "allow" && permissionPolicy("read", "fetch", undefined, proj) === "deny" && permissionPolicy("supervised", "fetch", undefined, proj) === "ask" && permissionPolicy("auto_edits", "fetch", undefined, proj) === "allow" && permissionPolicy("full", "execute", "rm x", proj) === "allow" && permissionPolicy("read", "edit", undefined, proj) === "deny");
  const loginDir = join(stateDir, "accounts", "login");
  r = await C.call("accounts.login_start", { engine: "antigravity", new_account: true });
  const secId = r.result.login.account_id;
  await loginIn("waiting");
  await waitFor(() => /google\.com/.test(lastLogin()?.url ?? ""));
  t.check("the sign-in link passes through Opscode's private folder (0700), not a shared temp folder", existsSync(loginDir) && (statSync(loginDir).mode & 0o777) === 0o700 && !readdirSync(tmpdir()).some((f) => f === `opscode-login-${lastLogin().id}.url`));
  const rowOf = (await C.call("accounts.list", { refresh: false })).result.accounts.find((a) => a.id === secId);
  t.check("an added account's agent never sees the API key or token the Mac's environment may hold (it would not be its own account)", L().filter((l) => l.ev === "login_started").at(-1)?.has_gemini_key === false && !!rowOf);
  await C.call("accounts.login_cancel", { login_id: lastLogin().id });
  await loginIn("cancelled");
  t.check("cancelling a sign-in removes the account it was adding", !(await list(false)).accounts.some((a) => a.id === secId));

  // a Manager or an automation does not run on these (they are chat engines)
  r = await C.call("chief.create", { brain: { engine: "api" } });
  t.check("a Manager still works as before", !r.error);
  C.close();
} finally {
  const code = await rt.stop();
  t.check("runtime stops cleanly", /code=0/.test(String(code)), String(code));
}

// ============ speed: the last answers are remembered, the programs are asked again in the background ============================
{
  const mode = (f) => (statSync(f).mode & 0o777);
  t.check("the engine list and who is signed in are kept on disk, private (0600)", existsSync(join(stateDir, "engines-cache.json")) && mode(join(stateDir, "engines-cache.json")) === 0o600 && existsSync(join(stateDir, "accounts-status.json")) && mode(join(stateDir, "accounts-status.json")) === 0o600);
  // From here every start of a session takes 1.5 s (a network answer): the next start must not wait for it.
  const slow = await startRuntime({ env: { ...env, OPSCODE_FAKE_ACP_SLOW_MS: "1500" }, stateDir, keepState: true });
  t.check("runtime starts again on the same data", slow.ready);
  const S = await session(slow);
  let t0 = Date.now();
  let r = await S.call("engines.list", {});
  const quick = Date.now() - t0;
  const qd2 = r.result?.engines.find((e) => e.id === "qoder");
  t.check("engines.list answers at once from what was remembered: found, and its models are there", quick < 400 && qd2?.found && qd2.models.length === 2 && r.result.engines.find((e) => e.id === "antigravity")?.found, `${quick} ms, ${JSON.stringify(qd2?.models)}`);
  t0 = Date.now();
  r = await S.call("accounts.list", { refresh: false });
  const quickA = Date.now() - t0;
  const was = r.result?.accounts.find((a) => a.engine === "antigravity" && a.id === "default");
  t.check("accounts.list answers at once with what was read last time (marked as not yet re-read)", quickA < 400 && was?.status?.stale === true, `${quickA} ms, ${JSON.stringify(was?.status)}`);
  t.check("...and the windows hear the fresh answers by themselves (accounts.changed), no longer marked stale", !!(await (async () => { for (const end = Date.now() + 8000; Date.now() < end; await sleep(60)) { const x = S.find("accounts.changed").at(-1)?.params.accounts.find((a) => a.engine === "antigravity" && a.id === "default"); if (x?.status && !x.status.stale) return x; } return null; })()));
  t.check("...and the engine list is re-read in the background too (engines.changed arrives)", !!(await (async () => { for (const end = Date.now() + 8000; Date.now() < end; await sleep(60)) if (S.find("engines.changed").length) return true; return false; })()));
  // Check: every program is asked at the same time, so two 1.5 s answers take about 1.5 s, not 3 s.
  await sleep(2500);
  t0 = Date.now();
  r = await S.call("engines.list", { refresh: true });
  const check = Date.now() - t0;
  t.check("Check asks the programs at the same time (two slow ones take about one's time, not both)", check < 2800 && r.result.engines.find((e) => e.id === "qoder")?.models.length === 2, `${check} ms`);
  t0 = Date.now();
  r = await S.call("accounts.list", { refresh: true });
  const checkA = Date.now() - t0;
  t.check("...and so does the account check", checkA < 2800 && r.result.accounts.every((a) => a.status && !a.status.stale), `${checkA} ms`);
  S.close();
  await slow.stop();
  rmSync(base, { recursive: true, force: true });
}
process.exit(t.finish());
