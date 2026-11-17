// Accounts (A1 sign-in/out status, A2 switch and add, A3 per chat / per Conductor / per account usage).
// Fake `claude` and `codex` programs keep their sign-in in a config folder, like the real ones do, so the checks
// cover the real design: who is signed in, sign in through the browser flow (link, cancel, paste a code, failure),
// sign out, adding a second account in its own folder, a chat staying on the account it started on, switching,
// duplicates, removal, per-account limits and usage. The real programs are checked separately (read-only).
import { existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p41-")));
const ROOT = process.cwd();
const A = await import(join(ROOT, "dist/runtime/engines/accounts.js"));
const { AutoSwitch } = await import(join(ROOT, "dist/runtime/autoswitch.js"));

// ---- the programs' answers, parsed ---------------------------------------------------------------------------------
const cs = A.parseClaudeStatus(JSON.stringify({ loggedIn: true, authMethod: "claude.ai", email: "a@x.io", orgName: "A's Org", subscriptionType: "Pro", loginExpiresAt: "2026-12-02T04:32:32.032Z" }));
t.check("claude auth status -> signed in, email, plan (lower case), organization, method, expiry", cs.signed_in && cs.email === "a@x.io" && cs.plan === "pro" && cs.org === "A's Org" && cs.method === "claude.ai" && cs.expires_at === "2026-12-02T04:32:32.032Z", JSON.stringify(cs));
const co = A.parseClaudeStatus(JSON.stringify({ loggedIn: false, authMethod: "none", email: "left@over.io" }));
t.check("signed out: no email or plan is shown even if the program left one in its answer", !co.signed_in && co.email === undefined && co.method === undefined);
t.check("an answer that is not JSON is reported as unreadable, not as signed out silently", /too old/.test(A.parseClaudeStatus("garbage").error ?? ""));
const xs = A.parseCodexAccount({ account: { type: "chatgpt", email: "c@y.io", planType: "team", workspaceName: "Shotlin workspace " }, requiresOpenaiAuth: true });
t.check("codex account/read -> ChatGPT email, plan, workspace", xs.signed_in && xs.email === "c@y.io" && xs.plan === "team" && xs.org === "Shotlin workspace" && xs.method === "chatgpt", JSON.stringify(xs));
t.check("codex with an API key -> signed in as 'api_key' (no email)", A.parseCodexAccount({ account: { type: "apiKey" } }).method === "api_key" && A.parseCodexAccount({ account: null }).signed_in === false);
t.check("auth failures are recognised (and a plan limit is not one)", A.isAuthError("Not logged in · Please run /login") && A.isAuthError("401 Unauthorized") && !A.isAuthError("usage limit reached") && !A.isAuthError("it broke"));

// ---- fixtures ---------------------------------------------------------------------------------------------------------
const proj = join(base, "app");
mkdirSync(proj, { recursive: true });
const claudeHome = join(base, "claude-default"); // "the Mac's own" Claude sign-in
const codexHome = join(base, "codex-default");
const sharedClaude = join(base, "shared-claude"); // what a new account shares: skills, CLAUDE.md, settings
mkdirSync(join(sharedClaude, "skills"), { recursive: true });
writeFileSync(join(sharedClaude, "CLAUDE.md"), "be kind");
writeFileSync(join(sharedClaude, "settings.json"), "{}");
writeFileSync(join(sharedClaude, ".claude.json"), "{\"oauthAccount\":\"secret\"}"); // sign-in state must never be shared
for (const h of [claudeHome, codexHome]) mkdirSync(h, { recursive: true });
writeFileSync(join(claudeHome, "fake-auth.json"), JSON.stringify({ email: "me@claude.test", plan: "max", org: "Me Org" }));
writeFileSync(join(codexHome, "fake-auth.json"), JSON.stringify({ email: "me@chatgpt.test", plan: "team", workspace: "Shotlin" }));
const logFile = join(base, "engines.log");
const openLog = join(base, "open.log");
writeFileSync(logFile, "");
writeFileSync(openLog, "");
const env = {
  OPSCODE_CLAUDE_BIN: join(ROOT, "scripts/lib/fake-claude.mjs"),
  OPSCODE_CODEX_BIN: join(ROOT, "scripts/lib/fake-codex.mjs"),
  OPSCODE_OPEN_BIN: join(ROOT, "scripts/lib/fake-open.mjs"),
  OPSCODE_FAKE_OPEN_LOG: openLog,
  OPSCODE_FAKE_ENGINE_LOG: logFile,
  OPSCODE_FAKE_DEFAULT_HOME: claudeHome,
  OPSCODE_FAKE_DEFAULT_CODEX_HOME: codexHome,
  OPSCODE_CLAUDE_HOME: sharedClaude,
  OPSCODE_CODEX_HOME: join(base, "shared-codex"),
  OPSCODE_CLAUDE_LOGS: join(base, "logs-claude"),
  OPSCODE_CODEX_LOGS: join(base, "logs-codex"),
};
const stateDir = join(base, "state");
const L = () => readFileSync(logFile, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
/** Claude chat processes (not the limit probes or sign-in commands): their config folder, in order. */
const claudeChats = () => L().filter((l) => l.bin === "claude" && l.argv?.includes("--permission-prompt-tool")).map((l) => ({ dir: l.config_dir, resumed: l.argv.includes("--resume") }));

let rt = await startRuntime({ env, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  let C = await session(rt);
  const waitFor = async (fn, ms = 8000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(40)) { const v = await fn(); if (v) return v; } return null; };
  const list = async (refresh = true) => (await C.call("accounts.list", { refresh })).result;
  const of = async (engine, id) => (await list()).accounts.find((a) => a.engine === engine && a.id === id);
  const lastLogin = () => C.find("accounts.login").at(-1)?.params.login ?? null;
  const loginIn = (state) => waitFor(() => lastLogin()?.state === state ? lastLogin() : null);
  const complete = (home, body) => writeFileSync(join(home, "fake-login-complete.json"), JSON.stringify(body));
  const newHome = (engine, id) => join(stateDir, "accounts", engine, id);

  // ============ A1: who is signed in ==========================================================================
  let r = await list();
  const cd = r.accounts.find((a) => a.engine === "claude-code" && a.id === "default");
  const xd = r.accounts.find((a) => a.engine === "codex" && a.id === "default");
  t.check("A1 accounts.list: the Mac's own Claude Code sign-in with email, plan and organization", cd?.status.signed_in && cd.status.email === "me@claude.test" && cd.status.plan === "max" && cd.status.org === "Me Org" && cd.is_default && cd.active, JSON.stringify(cd));
  t.check("A1 accounts.list: the Mac's own Codex sign-in with email, plan and workspace", xd?.status.signed_in && xd.status.email === "me@chatgpt.test" && xd.status.plan === "team" && xd.status.org === "Shotlin", JSON.stringify(xd));
  t.check("A1 only the four programs' own accounts exist before anything is added, and no sign-in is open", r.accounts.length === 4 && r.accounts.every((a) => a.is_default) && r.login === null);

  // sign out of Claude: asks the program, Codex is untouched, the account stays listed (signed out)
  r = (await C.call("accounts.logout", { engine: "claude-code", account_id: "default" }));
  t.check("A1 sign out (Claude): done by the program's own command; the auth file is gone", !r.error && !existsSync(join(claudeHome, "fake-auth.json")), JSON.stringify(r.error));
  const cd2 = await of("claude-code", "default");
  const xd2 = await of("codex", "default");
  t.check("A1 after sign out: Claude shows signed out (still listed, no email); Codex still signed in", cd2.status.signed_in === false && cd2.status.email === undefined && xd2.status.signed_in === true);
  t.check("A1 an accounts.changed notice reached the window", C.find("accounts.changed").length > 0);

  // sign in again (default account), through the browser flow
  r = await C.call("accounts.login_start", { engine: "claude-code", account_id: "default", method: "claudeai" });
  t.check("A1 sign in starts: link is shown, the program says it can take a pasted code", !r.error && r.result.login.state === "starting" || r.result?.login.state === "waiting", JSON.stringify(r));
  const w = await loginIn("waiting");
  t.check("A1 waiting: the sign-in link (claude.com) is available for 'open the link yourself'", /^https:\/\/claude\.com\//.test(w?.url ?? "") && w.can_paste === true && /method=claude\.ai/.test(w.url), JSON.stringify(w));
  r = await C.call("accounts.login_start", { engine: "codex", account_id: "default" });
  t.check("A1 a second sign-in while one is open is refused with a clear message", /already open/.test(r.error?.message ?? ""), JSON.stringify(r.error));
  complete(claudeHome, { email: "again@claude.test", plan: "pro", org: "Again Org" });
  const done = await loginIn("done");
  t.check("A1 browser finished -> done, and the account now shows the new sign-in", !!done && (await of("claude-code", "default")).status.email === "again@claude.test", JSON.stringify(done));

  // failure, cancel, paste
  await C.call("accounts.logout", { engine: "claude-code", account_id: "default" });
  await C.call("accounts.login_start", { engine: "claude-code", account_id: "default" });
  await loginIn("waiting");
  complete(claudeHome, { fail: "access denied" });
  const failed = await loginIn("failed");
  t.check("A1 a failed sign-in says why and leaves the account signed out", /access denied/.test(failed?.message ?? "") && (await of("claude-code", "default")).status.signed_in === false, JSON.stringify(failed));
  await C.call("accounts.login_start", { engine: "claude-code", account_id: "default" });
  const w2 = await loginIn("waiting");
  r = await C.call("accounts.login_cancel", { login_id: w2.id });
  t.check("A1 cancel closes the sign-in and the program is stopped", (await loginIn("cancelled")) !== null && !r.error);
  await C.call("accounts.login_start", { engine: "claude-code", account_id: "default" });
  const w3 = await waitFor(() => { const l = lastLogin(); return l?.state === "waiting" && l.can_paste ? l : null; });
  r = await C.call("accounts.login_code", { login_id: w3.id, code: "abc#def123" });
  t.check("A1 the code from the browser can be pasted (passed to the program, nothing kept)", !r.error && (await loginIn("done")) !== null && (await of("claude-code", "default")).status.email === "pasted@example.com", JSON.stringify(r.error));
  r = await C.call("accounts.login_code", { login_id: w3.id, code: "abc#def123" });
  t.check("A1 a code for a sign-in that is over is refused", !!r.error);
  r = await C.call("accounts.login_code", { login_id: "0".repeat(12), code: "has space" });
  t.check("A1 a code with odd characters is refused before it reaches the program", /does not look like/.test(r.error?.message ?? ""));

  // sign-in methods and email
  await C.call("accounts.logout", { engine: "claude-code", account_id: "default" });
  await C.call("accounts.login_start", { engine: "claude-code", account_id: "default", method: "console" });
  t.check("A1 'Anthropic Console' sign-in uses --console", /method=console/.test((await loginIn("waiting"))?.url ?? ""));
  await C.call("accounts.login_cancel", { login_id: lastLogin().id });
  await loginIn("cancelled");
  await C.call("accounts.login_start", { engine: "claude-code", account_id: "default", method: "sso", email: "boss@corp.io" });
  const sso = await loginIn("waiting");
  t.check("A1 single sign-on uses --sso and passes the email (--email)", /method=sso/.test(sso?.url ?? "") && /login_hint=given/.test(sso.url));
  await C.call("accounts.login_cancel", { login_id: sso.id });
  await loginIn("cancelled");
  r = await C.call("accounts.login_start", { engine: "claude-code", account_id: "default", email: "not an email" });
  t.check("A1 a bad email is refused", /not an email address/.test(r.error?.message ?? ""));
  r = await C.call("accounts.login_start", { engine: "codex", account_id: "default", email: "a@b.co" });
  t.check("A1 Codex takes no email", !!r.error);

  // Codex: sign out, sign in (link opened by Opscode), failure, cancel
  r = await C.call("accounts.logout", { engine: "codex", account_id: "default" });
  t.check("A1 sign out (Codex) works and Claude is untouched", !r.error && (await of("codex", "default")).status.signed_in === false && !existsSync(join(codexHome, "fake-auth.json")));
  writeFileSync(openLog, "");
  r = await C.call("accounts.login_start", { engine: "codex", account_id: "default" });
  const cw = await loginIn("waiting");
  t.check("A1 Codex sign-in: link given by the program, no paste", /^https:\/\/auth\.openai\.com\//.test(cw?.url ?? "") && cw.can_paste === false, JSON.stringify(cw));
  const opened = await waitFor(() => readFileSync(openLog, "utf8").trim());
  t.check("A1 Opscode opened that link in the browser (https only, once)", opened && opened.split("\n").length === 1 && JSON.parse(opened).argv[0] === cw.url, opened);
  complete(codexHome, { email: "new@chatgpt.test", plan: "plus", workspace: "Personal" });
  await loginIn("done");
  const xn = await of("codex", "default");
  t.check("A1 Codex sign-in finished: new email, plan, workspace", xn.status.email === "new@chatgpt.test" && xn.status.plan === "plus" && xn.status.org === "Personal", JSON.stringify(xn.status));
  await C.call("accounts.logout", { engine: "codex", account_id: "default" });
  await C.call("accounts.login_start", { engine: "codex", account_id: "default" });
  await loginIn("waiting");
  complete(codexHome, { fail: "Login was not completed" });
  const cf = await loginIn("failed");
  t.check("A1 Codex failed sign-in: message without the program's prefix", cf?.message === "Login was not completed", JSON.stringify(cf));
  await C.call("accounts.login_start", { engine: "codex", account_id: "default" });
  const cw2 = await loginIn("waiting");
  await C.call("accounts.login_cancel", { login_id: cw2.id });
  t.check("A1 Codex cancel", (await loginIn("cancelled")) !== null);
  // leave both signed in for what follows
  await C.call("accounts.login_start", { engine: "codex", account_id: "default" });
  await loginIn("waiting");
  complete(codexHome, { email: "me@chatgpt.test", plan: "team", workspace: "Shotlin" });
  await loginIn("done");
  await C.call("accounts.login_start", { engine: "claude-code", account_id: "default" });
  await loginIn("waiting");
  complete(claudeHome, { email: "me@claude.test", plan: "max", org: "Me Org" });
  await loginIn("done");
  t.check("A1 both are signed in again, and no sign-in is left open", (await of("claude-code", "default")).status.email === "me@claude.test" && (await list()).login?.state !== "waiting");

  // ============ A2: add a second account, side by side =======================================================================
  // chat 1 starts on the Mac's own account and is pinned to it
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  const events = (turnId) => C.find("turn.event", (p) => p.turn_id === turnId).map((n) => n.params);
  const say = async (chatId, text) => {
    const r = (await C.call("turn.submit", { workspace_id: wid, chat_id: chatId, text })).result;
    await waitFor(() => events(r.turn_id).some((e) => ["completed", "failed", "interrupted"].includes(e.type)), 15000);
    return events(r.turn_id);
  };
  const newChat = async (engine, extra = {}) => (await C.call("chat.create", { workspace_id: wid, engine, ...extra })).result.chat;
  const chatNow = async (id) => (await C.call("chat.list", {})).result.chats.find((c) => c.id === id);
  const chat1 = await newChat("claude-code");
  await say(chat1.id, "hello from chat one");
  t.check("A2 a chat on the Mac's own account runs without any account folder set", claudeChats().at(-1)?.dir === null);
  t.check("A2 the chat remembers its account (pinned on the first message)", (await chatNow(chat1.id)).accounts?.["claude-code"] === "default");

  r = await C.call("accounts.login_start", { engine: "claude-code", new_account: true, method: "claudeai" });
  const addId = r.result.login.account_id;
  const homeB = newHome("claude-code", addId);
  t.check("A2 add account: it gets its own private folder (0700) inside Opscode's data", /^a-[0-9a-f]{8}$/.test(addId) && existsSync(homeB) && (statSync(homeB).mode & 0o777) === 0o700, addId);
  t.check("A2 the new folder shares skills, CLAUDE.md and settings with the Mac's own, but never the sign-in state", lstatSync(join(homeB, "CLAUDE.md")).isSymbolicLink() && lstatSync(join(homeB, "skills")).isSymbolicLink() && lstatSync(join(homeB, "settings.json")).isSymbolicLink() && !existsSync(join(homeB, ".claude.json")));
  r = await list(false);
  t.check("A2 while signing in, the new account is listed (signed out) and the old one is still active", r.accounts.some((a) => a.id === addId) && r.accounts.find((a) => a.engine === "claude-code" && a.id === "default").active);
  await loginIn("waiting");
  complete(homeB, { email: "work@claude.test", plan: "team", org: "Work Org" });
  const added = await loginIn("done");
  const accB = await of("claude-code", addId);
  t.check("A2 the second account signs in on its own: its email and plan, the first account unchanged", added && accB.status.email === "work@claude.test" && accB.status.plan === "team" && (await of("claude-code", "default")).status.email === "me@claude.test", JSON.stringify(accB));
  const pushed = C.find("accounts.changed").at(-1)?.params.accounts.find((a) => a.id === addId);
  t.check("A2 the update pushed to the windows when the sign-in finishes already says who is signed in (no 'checking…' flash)", pushed?.status?.signed_in === true && pushed.status.email === "work@claude.test" && pushed.active, JSON.stringify(pushed));
  t.check("A2 the new account becomes the one new chats use", accB.active && !(await of("claude-code", "default")).active);

  // chat isolation
  const chat2 = await newChat("claude-code");
  await say(chat2.id, "hello from chat two");
  t.check("A2 a new chat runs with the new account's folder (CLAUDE_CONFIG_DIR), not the Mac's own", claudeChats().at(-1)?.dir === homeB, JSON.stringify(claudeChats().at(-1)));
  await say(chat1.id, "chat one again");
  const last1 = claudeChats().at(-1);
  t.check("A2 a chat already running stays on its own account and resumes its own session", last1.dir === null && last1.resumed === true, JSON.stringify(last1));
  t.check("A2 both pins are kept", (await chatNow(chat1.id)).accounts["claude-code"] === "default" && (await chatNow(chat2.id)).accounts["claude-code"] === addId);

  // switch back and forth
  r = await C.call("accounts.switch", { engine: "claude-code", account_id: "default" });
  t.check("A2 switch account: new chats use the other one", !r.error && r.result.accounts.find((a) => a.engine === "claude-code" && a.id === "default").active);
  const chat3 = await newChat("claude-code");
  await say(chat3.id, "chat three");
  t.check("A2 after switching, a new chat uses the account switched to", claudeChats().at(-1)?.dir === null);
  await C.call("accounts.switch", { engine: "claude-code", account_id: addId });
  r = await C.call("accounts.switch", { engine: "claude-code", account_id: "a-deadbeef" });
  t.check("A2 switching to an account that does not exist is refused", !!r.error);

  // an account that is signed out cannot be switched to
  const xtra = await C.call("accounts.login_start", { engine: "claude-code", new_account: true });
  const idX = xtra.result.login.account_id;
  r = await C.call("accounts.switch", { engine: "claude-code", account_id: idX });
  t.check("A2 an account that is not signed in cannot be switched to", /Sign in to that account first/.test(r.error?.message ?? ""), JSON.stringify(r.error));
  await loginIn("waiting");
  // the same person signs in again as an account already added: no duplicate
  complete(newHome("claude-code", idX), { email: "WORK@claude.test", plan: "team", org: "Work Org" });
  const dup = await loginIn("done");
  const afterDup = await list();
  t.check("A2 signing in as an account that is already added adds nothing, says so, and cleans up the folder", /already added/.test(dup?.message ?? "") && !afterDup.accounts.some((a) => a.id === idX) && !existsSync(newHome("claude-code", idX)), JSON.stringify(dup));
  t.check("A2 ...and the existing account is the active one", (await of("claude-code", addId)).active);

  // cancel while adding leaves nothing behind
  const c4 = await C.call("accounts.login_start", { engine: "claude-code", new_account: true });
  const id4 = c4.result.login.account_id;
  await loginIn("waiting");
  await C.call("accounts.login_cancel", { login_id: lastLogin().id });
  await loginIn("cancelled");
  t.check("A2 cancelling 'add account' removes the half-made account and its folder", !(await list()).accounts.some((a) => a.id === id4) && !existsSync(newHome("claude-code", id4)));
  const c5 = await C.call("accounts.login_start", { engine: "claude-code", new_account: true });
  await loginIn("waiting");
  complete(newHome("claude-code", c5.result.login.account_id), { fail: "nope" });
  await loginIn("failed");
  t.check("A2 a failed 'add account' leaves nothing behind either", !existsSync(newHome("claude-code", c5.result.login.account_id)) && (await list()).accounts.filter((a) => a.engine === "claude-code").length === 2);

  // Codex: a second account, isolated by CODEX_HOME
  r = await C.call("accounts.login_start", { engine: "codex", new_account: true });
  const cxId = r.result.login.account_id;
  const cxHome = newHome("codex", cxId);
  await loginIn("waiting");
  complete(cxHome, { email: "second@chatgpt.test", plan: "pro", workspace: "Second" });
  await loginIn("done");
  const cxB = await of("codex", cxId);
  if (!cxB) console.log("DEBUG codex add:", JSON.stringify(lastLogin()), JSON.stringify((await list()).accounts.filter((a) => a.engine === "codex")));
  t.check("A2 Codex: a second account in its own CODEX_HOME folder, signed in separately", cxB.status.email === "second@chatgpt.test" && cxB.status.plan === "pro" && cxB.active && (await of("codex", "default")).status.email === "me@chatgpt.test", JSON.stringify(cxB));
  const codexChat = await newChat("codex");
  await say(codexChat.id, "hello codex");
  const procs = new Map();
  for (const l of L()) if (l.bin === "codex") { const p = procs.get(l.pid) ?? { home: undefined, methods: [] }; if (l.argv) p.home = l.codex_home; if (l.method) p.methods.push(l.method); procs.set(l.pid, p); }
  t.check("A2 Codex: a chat on the second account runs with that CODEX_HOME", [...procs.values()].some((p) => p.methods.includes("thread/start") && p.home === cxHome), JSON.stringify([...procs.values()].map((p) => p.home)));

  // ============ A3: per chat, per Conductor, per account =======================================================================
  // per chat: move a chat to another account
  const sess2 = (await chatNow(chat2.id)).engine_session;
  r = await C.call("chat.set_account", { chat_id: chat2.id, account_id: "default" });
  t.check("A3 pick the account for one chat: it moves, and its old session (kept in the old account's folder) is dropped", !r.error && r.result.chat.accounts["claude-code"] === "default" && !r.result.chat.engine_session && !!sess2, JSON.stringify(r.error ?? r.result.chat));
  await say(chat2.id, "chat two on the other account");
  const m2 = claudeChats().at(-1);
  t.check("A3 its next message runs on that account, starting a fresh session (no --resume of a session that is not there)", m2.dir === null && m2.resumed === false, JSON.stringify(m2));
  r = await C.call("chat.set_account", { chat_id: chat2.id, account_id: idX });
  t.check("A3 a chat cannot be moved to an account that does not exist", !!r.error);
  const apiChat = await newChat("api");
  r = await C.call("chat.set_account", { chat_id: apiChat.id, account_id: "default" });
  t.check("A3 a chat on an API key has no account to pick", /only chats on a coding agent/.test(r.error?.message ?? ""));
  const chat5 = await newChat("claude-code", { account_id: addId });
  await say(chat5.id, "start on account two");
  t.check("A3 a chat can be created on a chosen account", chat5.accounts?.["claude-code"] === addId && claudeChats().at(-1)?.dir === homeB);
  r = await C.call("chat.create", { workspace_id: wid, engine: "claude-code", account_id: "a-00000000" });
  t.check("A3 ...but not on one that does not exist", !!r.error);

  // a failed chat that says "not logged in" points to Settings and refreshes the account list
  const before = C.find("accounts.changed").length;
  const chat6 = await newChat("claude-code", { account_id: addId });
  const ev6 = await say(chat6.id, "FAKE_AUTH_FAIL please");
  const fail6 = ev6.find((e) => e.type === "failed");
  t.check("A3 'Not logged in' from the program: the message says where to sign in again", /Sign in again: Settings → Models & keys/.test(fail6?.error ?? ""), fail6?.error);
  t.check("A3 ...and the account list is re-read and pushed to the windows", await waitFor(() => C.find("accounts.changed").length > before));

  // per Conductor
  const ch = (await C.call("chief.create", { name: "Boss" })).result.chief;
  r = await C.call("chief.update", { chief_id: ch.id, accounts: { "claude-code": addId } });
  t.check("A3 a Conductor can be set to an account; it is saved on the profile", !r.error && r.result.chief.accounts?.["claude-code"] === addId, JSON.stringify(r.error ?? r.result.chief.accounts));
  t.check("A3 ...and its own chat is pinned to it", (await chatNow(ch.chat_id)).accounts?.["claude-code"] === addId);
  r = await C.call("chief.update", { chief_id: ch.id, accounts: { "claude-code": "a-00000000" } });
  t.check("A3 a Conductor cannot be set to an account that does not exist", !!r.error);
  r = await C.call("chief.update", { chief_id: ch.id, accounts: { "claude-code": "" } });
  t.check("A3 an empty choice clears it (back to whichever new chats use)", !r.error && r.result.chief.accounts?.["claude-code"] === undefined);
  await C.call("chief.update", { chief_id: ch.id, accounts: { "claude-code": addId } });

  // per account: limits
  r = await C.call("limits.get", { refresh: true, all_accounts: true });
  const by = r.result.by_account;
  const lim = (e, a) => by.find((l) => l.engine === e && l.account_id === a);
  t.check("A3 limits are kept per account: Claude has one set for each of its accounts, tagged", !!lim("claude-code", "default") && !!lim("claude-code", addId) && lim("claude-code", addId).plan === "pro", JSON.stringify(by.map((l) => [l.engine, l.account_id])));
  t.check("A3 ...and Codex too", !!lim("codex", "default") && !!lim("codex", cxId));
  t.check("A3 `limits` (what the sidebar and routing read) is the active account's, one per engine", r.result.limits.length === 2 && r.result.limits.find((l) => l.engine === "claude-code").account_id === addId && r.result.limits.find((l) => l.engine === "codex").account_id === cxId);
  const probes = L().filter((l) => l.bin === "claude" && l.argv?.includes("--strict-mcp-config") && !l.argv.includes("--permission-prompt-tool"));
  t.check("A3 each account's limits were read with that account's own folder", probes.some((p) => p.config_dir === homeB) && probes.some((p) => p.config_dir === null));

  // auto-switch on the chat's own account
  const lim100 = { engine: "claude-code", state: "ok", windows: [{ id: "five_hour", kind: "session", label: "5-hour", used_percent: 100 }], checked_at: new Date().toISOString() };
  const free = { ...lim100, windows: [{ ...lim100.windows[0], used_percent: 5 }] };
  const codexFree = { engine: "codex", state: "ok", windows: [{ id: "primary", kind: "session", label: "5h", used_percent: 1 }], checked_at: new Date().toISOString() };
  const sw = new AutoSwitch({ enabled: () => true, installed: () => true, limits: () => [], limitsFor: (e, id) => (e === "codex" ? codexFree : id === addId ? lim100 : free), accountOf: (e, c) => c?.accounts?.[e] ?? "default" });
  const mk = (acct) => ({ id: "c", workspace_id: "w", title: "", mode: "supervised", created_at: "", updated_at: "", engine: "claude-code", accounts: { "claude-code": acct } });
  t.check("A3 auto-switch looks at the chat's own account: out of limit on account two -> moves to Codex", sw.beforeTurn(mk(addId)) === "codex");
  t.check("A3 ...but a chat on the other account (which has room) does not move", sw.beforeTurn(mk("default")) === null);

  // per account: usage ("where tokens go") from each account's own logs
  const iso = (ms) => new Date(ms).toISOString();
  const callLine = (sid, id, t0, out) => JSON.stringify({ type: "assistant", sessionId: sid, timestamp: iso(t0), cwd: "/x/proj", entrypoint: "sdk-cli", isSidechain: false, message: { id, model: "claude-sonnet-5-5", content: [{ type: "text", text: "ok" }], usage: { input_tokens: 10, cache_creation_input_tokens: 100, cache_read_input_tokens: 1000, output_tokens: out, cache_creation: { ephemeral_1h_input_tokens: 0 } } } });
  mkdirSync(join(base, "logs-claude", "-x-proj"), { recursive: true });
  mkdirSync(join(homeB, "projects", "-x-proj"), { recursive: true });
  writeFileSync(join(base, "logs-claude", "-x-proj", "own.jsonl"), callLine("own-1", "m-own", Date.now() - 3_600_000, 500) + "\n");
  writeFileSync(join(homeB, "projects", "-x-proj", "work.jsonl"), [callLine("work-1", "m-w1", Date.now() - 7_200_000, 700), callLine("work-1", "m-w2", Date.now() - 7_100_000, 900)].join("\n") + "\n");
  const all = (await C.call("usage.report", { days: 7, refresh: true, wait: true })).result;
  const onlyOwn = (await C.call("usage.report", { days: 7 })).result;
  const onlyB = (await C.call("usage.report", { days: 7, account_id: addId })).result;
  const onlyDef = (await C.call("usage.report", { days: 7, account_id: "default" })).result;
  t.check("A3 usage reads every account's logs: the total covers both", all.report.claude.sessions === 2 && all.report.claude.calls === 3, JSON.stringify([all.report.claude.sessions, all.report.claude.calls]));
  t.check("A3 usage can be narrowed to one account", onlyB.report.claude.sessions === 1 && onlyB.report.claude.calls === 2 && onlyDef.report.claude.sessions === 1 && onlyDef.report.claude.calls === 1, JSON.stringify([onlyB.report.claude.calls, onlyDef.report.claude.calls]));
  const heads = all.accounts ?? [];
  t.check("A3 with more than one account, a headline per account is returned", heads.length >= 2 && heads.find((a) => a.account === addId)?.claude_sessions === 1 && heads.find((a) => a.account === "default")?.claude_sessions === 1, JSON.stringify(heads));
  void onlyOwn;

  // ============ sign out of an added account, and what survives a restart ============================================================
  // a chat running on the account blocks sign-out
  const busy = await newChat("claude-code", { account_id: addId });
  const bt = (await C.call("turn.submit", { workspace_id: wid, chat_id: busy.id, text: "FAKE_HANG" })).result;
  await waitFor(() => events(bt.turn_id).some((e) => e.type === "started"));
  r = await C.call("accounts.logout", { engine: "claude-code", account_id: addId });
  t.check("A2 sign out is refused while a chat is running on that account", /running on this account/.test(r.error?.message ?? ""), JSON.stringify(r.error));
  await C.call("turn.interrupt", { turn_id: bt.turn_id });
  await waitFor(() => events(bt.turn_id).some((e) => ["interrupted", "completed", "failed"].includes(e.type)));

  // restart: the account, the choice of active account and each chat's pin survive
  const accountsFile = JSON.parse(readFileSync(join(stateDir, "accounts.json"), "utf8"));
  t.check("A2 the account list is saved privately (0600) and holds no email, token or password", (statSync(join(stateDir, "accounts.json")).mode & 0o777) === 0o600 && !/@|token|password/i.test(JSON.stringify(accountsFile)), JSON.stringify(accountsFile));
  C.close();
  await rt.stop();
  rt = await startRuntime({ env, stateDir, keepState: true });
  C = await session(rt);
  const re = await list();
  t.check("A2 after a restart the second account is still there and still active", re.accounts.find((a) => a.id === addId)?.active && re.accounts.find((a) => a.id === addId).status.email === "work@claude.test" && re.accounts.find((a) => a.id === cxId)?.active);
  t.check("A2 ...and chats keep their pins", (await chatNow(chat1.id)).accounts["claude-code"] === "default" && (await chatNow(chat5.id)).accounts["claude-code"] === addId);

  // sign out of the added account: it leaves the list, its folder is deleted, chats pinned to it let go, the other is active again
  const keep = await chatNow(chat5.id);
  r = await C.call("accounts.logout", { engine: "claude-code", account_id: addId });
  const gone = await list();
  t.check("A2 signing out an added account removes it from the list and deletes its folder", !r.error && !gone.accounts.some((a) => a.id === addId) && !existsSync(homeB), JSON.stringify(r.error));
  t.check("A2 ...the Mac's own account is active again and still signed in", gone.accounts.find((a) => a.engine === "claude-code" && a.id === "default").active && gone.accounts.find((a) => a.engine === "claude-code" && a.id === "default").status.signed_in);
  const after5 = await chatNow(chat5.id);
  t.check("A2 ...chats that ran on it are released (no pin, no session of a folder that is gone)", !after5.accounts?.["claude-code"] && !after5.engine_session && !!keep.engine_session, JSON.stringify(after5));
  await say(chat5.id, "after account two is gone");
  t.check("A2 such a chat carries on, on the account new chats use", claudeChats().at(-1)?.dir === null && claudeChats().at(-1)?.resumed === false);
  r = await C.call("accounts.logout", { engine: "claude-code", account_id: "a-00000000" });
  t.check("A2 signing out an account that does not exist is refused", !!r.error);
  const ak = JSON.parse(readFileSync(join(stateDir, "accounts.json"), "utf8"));
  t.check("A2 the removed account is gone from the saved list too", !ak.accounts.some((a) => a.id === addId) && ak.active["claude-code"] === undefined);
  // the sixth extra account is the last
  const made = [];
  for (let i = 0; i < 6; i++) { const s = await C.call("accounts.login_start", { engine: "codex", new_account: true }); if (s.error) break; made.push(s.result.login.account_id); await loginIn("waiting"); complete(newHome("codex", s.result.login.account_id), { email: `x${i}@chatgpt.test`, plan: "plus", workspace: `W${i}` }); await loginIn("done"); }
  const seventh = await C.call("accounts.login_start", { engine: "codex", new_account: true });
  t.check("A2 at most 6 extra accounts per program", made.length === 5 && /At most 6/.test(seventh.error?.message ?? "") || (made.length === 5 && !!seventh.error), `${made.length} ${JSON.stringify(seventh.error)}`);
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("runtime stops cleanly", /code=0/.test(exit), exit);
  rmSync(base, { recursive: true, force: true });
}
process.exit(t.finish());
