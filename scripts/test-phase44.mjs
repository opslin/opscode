// The image rule: any engine's image request goes to image_generate, which runs Codex's image generator and moves
// to the next Codex account when one is out of credits/usage, or tells the time the first account is back.
// The engines and Codex are fakes (scripts/lib/fake-*.mjs); `codex exec` writes its image into the account's
// generated_images/<thread> folder like the real one. Real Codex is exercised by scripts/realtest-imagegen.mjs.
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const ROOT = process.cwd();
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p44-")));
const proj = join(base, "shop");
mkdirSync(join(proj, "refs"), { recursive: true });
writeFileSync(join(proj, "package.json"), "{}");
const PNG = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==", "base64");
writeFileSync(join(proj, "refs", "char.png"), PNG);
const stateDir = join(base, "state");
mkdirSync(stateDir, { recursive: true });
const defHome = join(base, "default-codex-home"); // "the Mac's own" Codex sign-in
mkdirSync(defHome, { recursive: true });
writeFileSync(join(defHome, "fake-auth.json"), JSON.stringify({ email: "one@example.test", plan: "team" }));
const EXTRA = "a-11111111"; // a second Codex account: position 2
writeFileSync(join(stateDir, "accounts.json"), JSON.stringify({ version: 1, accounts: [{ id: EXTRA, engine: "codex", added_at: "2026-11-16T09:00:00.000Z" }], active: {} }));
mkdirSync(join(stateDir, "accounts", "codex", EXTRA), { recursive: true });
writeFileSync(join(stateDir, "accounts", "codex", EXTRA, "fake-auth.json"), JSON.stringify({ email: "two@example.test", plan: "team" }));
const logFile = join(base, "engines.log");
const imgFile = join(base, "image.json");
const usageFile = join(base, "usage.json");
writeFileSync(logFile, "");
const setImg = (o) => writeFileSync(imgFile, JSON.stringify(o));
const setUsageFile = (by) => writeFileSync(usageFile, JSON.stringify({ codex5h: 1, by_home: by }));
setImg({});
setUsageFile({});
const env = {
  OPSCODE_CLAUDE_BIN: join(ROOT, "scripts/lib/fake-claude.mjs"),
  OPSCODE_CODEX_BIN: join(ROOT, "scripts/lib/fake-codex.mjs"),
  OPSCODE_AGY_BIN: join(ROOT, "scripts/lib/fake-acp.mjs"),
  OPSCODE_FAKE_ENGINE_LOG: logFile,
  OPSCODE_FAKE_IMAGE_FILE: imgFile,
  OPSCODE_FAKE_USAGE_FILE: usageFile,
  OPSCODE_FAKE_DEFAULT_CODEX_HOME: defHome,
  OPSCODE_CODEX_HOME: defHome,
  OPSCODE_FAKE_DEFAULT_ACP_HOME: join(base, "agy-home"),
  OPSCODE_FAKE_REAL_HOME: process.env.HOME,
};
mkdirSync(env.OPSCODE_FAKE_DEFAULT_ACP_HOME, { recursive: true });
writeFileSync(join(env.OPSCODE_FAKE_DEFAULT_ACP_HOME, "fake-auth.json"), "{}");
const logLines = () => readFileSync(logFile, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const execs = () => logLines().filter((l) => l.exec);
const dev = (name) => logLines().filter((l) => l.device_tool === name);

// ---- units ---------------------------------------------------------------------------------------------------
const G = await import(join(ROOT, "dist/runtime/imagegen.js"));
const A = await import(join(ROOT, "dist/runtime/autoswitch.js"));
t.check("units: waits are said short (45m, 2h 3m, 3d 4h, under a minute)", G.fmtWait(45 * 60_000) === "45m" && G.fmtWait(123 * 60_000) === "2h 3m" && G.fmtWait(2 * 3600_000) === "2h" && G.fmtWait((3 * 24 + 4) * 3600_000) === "3d 4h" && G.fmtWait(10_000) === "under a minute", [G.fmtWait(45 * 60_000), G.fmtWait(123 * 60_000), G.fmtWait((3 * 24 + 4) * 3600_000)].join(" | "));
const noon = new Date(2026, 10, 16, 12, 0, 0).getTime();
t.check("units: clock times say today / tomorrow / a date with weekday", G.fmtAt(new Date(2026, 10, 16, 19, 12).getTime(), noon) === "7:12 PM" && G.fmtAt(new Date(2026, 10, 17, 7, 12).getTime(), noon) === "tomorrow 7:12 AM" && /Nov 23/.test(G.fmtAt(new Date(2026, 10, 23, 9, 5).getTime(), noon)) && /9:05 AM/.test(G.fmtAt(new Date(2026, 10, 23, 9, 5).getTime(), noon)) && /^\w{3}/.test(G.fmtAt(new Date(2026, 10, 23, 9, 5).getTime(), noon)), G.fmtAt(new Date(2026, 10, 23, 9, 5).getTime(), noon));
t.check("units: Codex's own wording gives the wait ('try again in 2 hours 31 minutes', '1 day 3 hours')", G.retryAfterMs("You've hit your usage limit. Try again in 2 hours 31 minutes.") === (2 * 60 + 31) * 60_000 && G.retryAfterMs("try again in 1 day 3 hours") === 27 * 3600_000 && G.retryAfterMs("Your workspace is out of credits. Add credits to continue.") === null);
const later = new Date(2026, 10, 17, 9, 10).getTime();
t.check("units: 'try again at Nov 17th, 2026 9:10 AM' gives the time", Math.abs(G.retryAfterMs("Try again at Nov 17th, 2026 9:10 AM.", noon) - (later - noon)) < 2000, String(G.retryAfterMs("Try again at Nov 17th, 2026 9:10 AM.", noon)));
const win = (used, mins) => ({ id: "x", kind: "session", label: "x", used_percent: used, resets_at: new Date(noon + mins * 60_000).toISOString() });
t.check("units: an account is used up when a window is at 100% with a reset ahead (latest reset wins); a reset in the past or 99% is not", G.limitBlockUntil({ engine: "codex", state: "ok", windows: [win(100, 120), win(100, 300)], checked_at: "" }, noon) === noon + 300 * 60_000 && G.limitBlockUntil({ engine: "codex", state: "ok", windows: [win(99, 120)], checked_at: "" }, noon) === null && G.limitBlockUntil({ engine: "codex", state: "ok", windows: [win(100, -5)], checked_at: "" }, noon) === null && G.limitBlockUntil(undefined, noon) === null);
t.check("units: 'out of credits' counts as a plan limit (image tool and Normal-chat auto-switch)", G.isImageLimitError("Your workspace is out of credits. Add credits to continue.") && A.isLimitError("Your workspace is out of credits. Add credits to continue.") && G.isImageLimitError("You've hit your usage limit.") && !G.isImageLimitError("The image service returned an unexpected error."));
const note = (await import(join(ROOT, "dist/runtime/imageNote.js"))).IMAGE_NOTE;
const tool = G.imageTool(new G.ImageGen({ codexPath: () => null, accounts: () => [], limitsFor: () => undefined, refreshLimits: async () => undefined }));
const cost = Math.round((note.length + JSON.stringify({ name: tool.def.name, description: tool.def.description, input_schema: tool.def.schema }).length) / 4);
t.check("units: what every chat pays for the rule and the tool is small (about 330 tokens or less)", cost <= 330, `${cost} tokens`);
t.check("units: the rule names the tool, forbids drawing with code, and says to relay the time", /image_generate/.test(note) && /SVG/.test(note) && /exactly/.test(note));

let rt = await startRuntime({ env, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

const waitFor = async (fn, ms = 15000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(40)) { const v = await fn(); if (v) return v; } return null; };
let C;
let wid;
const connect = async () => { C = await session(rt); wid = (await C.call("workspace.add", { path: proj })).result.workspace.id; };
await connect();
const events = (turnId) => C.find("turn.event", (p) => p.turn_id === turnId).map((n) => n.params);
const finished = (turnId, ms) => waitFor(() => events(turnId).some((e) => ["completed", "failed", "interrupted"].includes(e.type)), ms);
const lines = (...calls) => calls.map(([n, a]) => `FAKE_DEVICE ${n} ${JSON.stringify(a)}`).join("\n");
const mk = async (engine = "claude-code", mode = "auto_edits") => (await C.call("chat.create", { workspace_id: wid, engine, mode })).result.chat;
const run = async (chat, text) => { writeFileSync(logFile, ""); return (await C.call("turn.submit", { workspace_id: wid, chat_id: chat.id, text })).result.turn_id; };
const refreshLimits = () => C.call("limits.get", { refresh: true, all_accounts: true });
const img = async (args, mode = "auto_edits") => {
  const id = await run(await mk("claude-code", mode), `make an image\n${lines(["image_generate", args])}`);
  await finished(id, 20000);
  return { id, res: dev("image_generate").at(-1), ex: execs() };
};
const status = async (refresh = false) => (await C.call("imagegen.status", { refresh })).result;

// ---- the tool and the rule reach a chat ------------------------------------------------------------------------
let r = await img({ prompt: "A friendly fox logo, flat orange #FF6A00, white background", save_as: "assets/fox.png" });
const tools = logLines().find((l) => l.device_tools)?.device_tools ?? [];
const claudeArgv = JSON.stringify(logLines().find((l) => l.bin === "claude" && l.argv?.includes("--append-system-prompt"))?.argv ?? []);
t.check("a Claude Code chat gets image_generate with the other shared tools", tools.includes("image_generate") && tools.includes("task_checkpoint"), tools.join(","));
t.check("and its prompt carries the image rule", /Images: for any request to create, draw, design/.test(claudeArgv) && /image_generate/.test(claudeArgv), claudeArgv.slice(0, 120));

// ---- first account makes the image, saved where asked ------------------------------------------------------------
t.check("both accounts fine: the first account makes it (one run, on the Mac's own folder)", r.ex.length === 1 && r.ex[0].key === "default" && /Made 1 image with Codex \(account 1\)/.test(r.res?.result ?? ""), JSON.stringify(r.res?.result));
t.check("the PNG is saved at save_as inside the project", existsSync(join(proj, "assets", "fox.png")) && readFileSync(join(proj, "assets", "fox.png")).subarray(1, 4).toString() === "PNG");
t.check("the result gives the full path and how to link it", (r.res?.result ?? "").includes(join(proj, "assets", "fox.png")) && /\[fox\.png\]\(/.test(r.res.result), r.res?.result);
t.check("Codex got the whole brief on stdin, in an empty folder and a read-only sandbox, one image, no files", /A friendly fox logo, flat orange #FF6A00/.test(r.ex[0]?.prompt ?? "") && /one image/.test(r.ex[0].prompt) && /Do not write, copy, move or edit files/.test(r.ex[0].prompt));
const argv = logLines().find((l) => l.argv?.[0] === "exec")?.argv ?? [];
t.check("run as `codex exec - --json --ephemeral -s read-only -C <empty temp dir>`; not in the project", argv[1] === "-" && argv.includes("--json") && argv.includes("--ephemeral") && argv[argv.indexOf("-s") + 1] === "read-only" && !argv[argv.indexOf("-C") + 1].startsWith(proj) && /opscode-img-/.test(argv[argv.indexOf("-C") + 1]), argv.join(" "));
t.check("the temp working folder is removed afterwards", !existsSync(argv[argv.indexOf("-C") + 1] ?? "/nope"));

// ---- default place, ignore file, several images, references ---------------------------------------------------------
r = await img({ prompt: "Pixel penguin mascot" });
const defPath = (r.res?.result ?? "").match(/(\S*\/\.opscode\/images\/[^\s]+\.png)/)?.[1];
t.check("without save_as the image goes to .opscode/images/<words>-<time>.png", !!defPath && existsSync(defPath) && /pixel-penguin-mascot-\d{8}-\d{6}\.png$/.test(defPath), r.res?.result);
t.check("that folder ignores itself (a draft never lands in a commit)", readFileSync(join(proj, ".opscode", "images", ".gitignore"), "utf8").trim() === "*");
t.check("and the result says it is a draft folder", /not committed/.test(r.res?.result ?? ""));
setImg({ default: { mode: "ok", count: 2 } });
r = await img({ prompt: "Two button states", save_as: "assets/btn.png", count: 2, size: "square, transparent background" });
t.check("count 2: two files numbered -1 and -2", existsSync(join(proj, "assets", "btn-1.png")) && existsSync(join(proj, "assets", "btn-2.png")) && /Made 2 images/.test(r.res?.result ?? ""), r.res?.result);
t.check("the shape goes into the brief", /Format: square, transparent background\./.test(r.ex[0]?.prompt ?? "") && /2 separate images/.test(r.ex[0].prompt));
setImg({});
r = await img({ prompt: "Same fox, waving", save_as: "assets/fox-wave.png", references: ["refs/char.png"] });
const rx = logLines().find((l) => l.argv?.[0] === "exec")?.argv ?? [];
t.check("a reference image is sent with -i (full path) and the brief says it is the reference", rx[rx.indexOf("-i") + 1] === join(proj, "refs", "char.png") && /is the reference/.test(r.ex[0]?.prompt ?? ""), rx.join(" "));

// ---- bad requests cost nothing --------------------------------------------------------------------------------------
const bad = async (args, why, re) => { const x = await img(args); t.check(`${why}: refused before any run`, x.res?.is_error === true && re.test(x.res.result) && x.ex.length === 0, x.res?.result); };
await bad({ prompt: "x", save_as: "../outside.png" }, "save_as outside the project", /inside the project/);
await bad({ prompt: "x", save_as: "/etc/evil.png" }, "an absolute path elsewhere", /inside the project/);
await bad({ prompt: "x", save_as: "assets/photo.jpg" }, "a non-PNG name", /\.png/);
await bad({ prompt: "x", save_as: ".git/hooks/x.png" }, "inside .git", /inside the project/);
await bad({ prompt: "x", save_as: "assets/fox.png" }, "a file that exists (no overwrite)", /already exists/);
await bad({ prompt: "x", save_as: "a.png", references: ["/etc/hosts"] }, "a reference outside the project", /not inside the project/);
await bad({ prompt: "x", save_as: "a.png", references: ["refs/missing.png"] }, "a missing reference", /not found/);
await bad({ prompt: "x", save_as: "a.png", references: ["package.json"] }, "a reference that is not an image", /not an image/);
await bad({ prompt: "   " }, "an empty brief", /prompt is required/);

// ---- permissions ------------------------------------------------------------------------------------------------------
const roChat = await mk("claude-code", "read");
let id = await run(roChat, `look\n${lines(["image_generate", { prompt: "x" }])}`);
await finished(id);
t.check("a read-only chat does not even see the tool (it writes files and spends usage)", !(logLines().find((l) => l.device_tools)?.device_tools ?? []).includes("image_generate"));
const sup = await mk("claude-code", "supervised");
id = await run(sup, `go\n${lines(["image_generate", { prompt: "Deny me", save_as: "assets/denied.png" }])}`);
const card = await waitFor(() => events(id).find((e) => e.type === "approval_request"));
t.check("Supervised asks first, naming the brief and where it goes", /Generate image: Deny me/.test(card?.summary ?? "") && /assets\/denied\.png/.test(card?.detail ?? ""), JSON.stringify(card));
await C.call("turn.approve", { turn_id: id, call_id: card.call_id, allow: false });
await finished(id);
t.check("saying no spends nothing and makes nothing", execs().length === 0 && !existsSync(join(proj, "assets", "denied.png")) && /denied/.test(dev("image_generate").at(-1)?.result ?? ""));
id = await run(sup, `go\n${lines(["image_generate", { prompt: "Allow me", save_as: "assets/allowed.png" }])}`);
const card2 = await waitFor(() => events(id).find((e) => e.type === "approval_request"));
await C.call("turn.approve", { turn_id: id, call_id: card2.call_id, allow: true });
await finished(id, 20000);
t.check("saying yes makes it", existsSync(join(proj, "assets", "allowed.png")) && execs().length === 1);

// ---- the first account fails with "out of credits": the second one makes it, at once ----------------------------------
setImg({ default: { mode: "credits" } });
await refreshLimits();
r = await img({ prompt: "Hop to the second account", save_as: "assets/hop.png" });
t.check("Codex says 'out of credits' on account 1: account 2 makes the image in the same call", r.ex.map((e) => e.key).join(",") === `default,${EXTRA}` && existsSync(join(proj, "assets", "hop.png")) && /Made 1 image with Codex \(account 2\)/.test(r.res?.result ?? ""), `${r.ex.map((e) => e.key)} ${r.res?.result}`);
t.check("the answer tells the model account 1 is out and when it is back", /Account 1 is out of usage until .+\(in /.test(r.res?.result ?? ""), r.res?.result);
t.check("account 2's run used its own Codex folder (CODEX_HOME), account 1's the Mac's own", JSON.stringify(logLines().filter((l) => l.argv?.[0] === "exec").map((l) => l.codex_home)) === JSON.stringify([null, join(stateDir, "accounts", "codex", EXTRA)]), JSON.stringify(logLines().filter((l) => l.argv?.[0] === "exec").map((l) => l.codex_home)));
r = await img({ prompt: "Next one, right after", save_as: "assets/hop2.png" });
t.check("the next request goes straight to account 2 (no wasted run on the used-up account)", r.ex.map((e) => e.key).join(",") === EXTRA && existsSync(join(proj, "assets", "hop2.png")), r.ex.map((e) => e.key).join(","));
let st = await status();
t.check("status: still ready; account 1 waiting with an estimate (Codex gave no time); account 2 ready", st.state === "ready" && st.accounts[0].state === "waiting" && st.accounts[0].estimated === true && st.accounts[1].state === "ready" && st.accounts[1].position === 2, JSON.stringify(st.accounts));
t.check("status never carries an email", !/@/.test(JSON.stringify(st)));
await rt.stop();

// ---- a fresh start: limits already show account 1 used up -> not even tried -----------------------------------------------
setImg({});
setUsageFile({ default: { codex5h: 100 } });
rt = await startRuntime({ env, stateDir, keepState: true });
await connect();
await refreshLimits();
r = await img({ prompt: "Skip the used-up one", save_as: "assets/skip.png" });
t.check("limits at 100% on account 1: it is skipped without a run, account 2 makes it", r.ex.map((e) => e.key).join(",") === EXTRA && /Made 1 image with Codex \(account 2\)/.test(r.res?.result ?? "") && /Account 1 is out of usage until/.test(r.res.result), `${r.ex.map((e) => e.key)} ${r.res?.result}`);
t.check("the real reset time is used (about 4 hours from the limits reading), not a guess", /in (3h 5\d|4h)\)/.test(r.res?.result ?? ""), r.res?.result);

// ---- both used up: the timer ----------------------------------------------------------------------------------------------
setUsageFile({ default: { codex5h: 100 }, [EXTRA]: { codex5h: 100 } });
await refreshLimits();
r = await img({ prompt: "Nobody can", save_as: "assets/none.png" });
t.check("every account used up: an error that says so, with the time the first is back, as a countdown and a clock time", r.res?.is_error === true && /paused: every Codex account is out of usage/.test(r.res.result) && /back in (3h 5\d|4h), at /.test(r.res.result), r.res?.result);
t.check("it names each account by number with its own time", /Account 1: out of usage, back in/.test(r.res?.result ?? "") && /Account 2: out of usage, back in/.test(r.res.result));
t.check("and no run was started (nothing to spend)", r.ex.length === 0 && !existsSync(join(proj, "assets", "none.png")));
st = await status();
t.check("status: waiting, with next_at (ISO) and wait_ms, for the app to show a timer", st.state === "waiting" && !Number.isNaN(Date.parse(st.next_at)) && st.wait_ms > 3.9 * 3600_000 - 120_000 && st.wait_ms <= 4 * 3600_000 + 1000 && /paused/.test(st.message), JSON.stringify({ s: st.state, n: st.next_at, w: st.wait_ms }));
const evs = C.find("imagegen.changed").map((n) => n.params);
t.check("the app is told when the state changes (imagegen.changed)", evs.length > 0 && evs.at(-1).state === "waiting", JSON.stringify(evs.at(-1)?.state));
t.check("the status message is exactly what the tool told the model to relay", st.message === (r.res?.result ?? "").trim(), st.message.slice(0, 80));
// the free reset arrives (limits drop): generation resumes with no restart
setUsageFile({ default: { codex5h: 10 }, [EXTRA]: { codex5h: 100 } });
await refreshLimits();
r = await img({ prompt: "Back again", save_as: "assets/back.png" });
t.check("when the limits read lower again, account 1 is used again right away", r.ex.map((e) => e.key).join(",") === "default" && existsSync(join(proj, "assets", "back.png")), r.ex.map((e) => e.key).join(","));
await rt.stop();

// ---- Codex tells the wait in words ------------------------------------------------------------------------------------------
setUsageFile({});
setImg({ default: { mode: "limit" } });
rt = await startRuntime({ env, stateDir, keepState: true });
await connect();
await refreshLimits();
r = await img({ prompt: "Wait in words", save_as: "assets/words.png" });
st = await status();
t.check("a usage-limit error with 'try again in 2 hours 31 minutes' moves on and uses that time (not an estimate)", r.ex.map((e) => e.key).join(",") === `default,${EXTRA}` && st.accounts[0].state === "waiting" && !st.accounts[0].estimated && st.accounts[0].wait_ms > (2 * 60 + 30) * 60_000 && st.accounts[0].wait_ms <= (2 * 60 + 31) * 60_000, JSON.stringify(st.accounts[0]));
await rt.stop();

// ---- sign-in failure on account 1 -------------------------------------------------------------------------------------------
setImg({ default: { mode: "auth" } });
rt = await startRuntime({ env, stateDir, keepState: true });
await connect();
r = await img({ prompt: "Auth hop", save_as: "assets/auth.png" });
st = await status();
t.check("account 1 not signed in: account 2 makes it, and account 1 is marked as needing sign-in", r.ex.map((e) => e.key).join(",") === `default,${EXTRA}` && /Account 1 is not signed in/.test(r.res?.result ?? "") && st.accounts[0].state === "sign_in", `${r.res?.result} ${JSON.stringify(st.accounts[0])}`);
await rt.stop();

// ---- failures another account would not fix ---------------------------------------------------------------------------------
setImg({ default: { mode: "refuse" } });
rt = await startRuntime({ env, stateDir, keepState: true });
await connect();
r = await img({ prompt: "Refused brief", save_as: "assets/refused.png" });
t.check("Codex declines the brief: no hop (the same brief would be declined), the reason comes back", r.ex.length === 1 && r.res?.is_error === true && /finished without making an image: I can't create that image/.test(r.res.result) && !existsSync(join(proj, "assets", "refused.png")), `${r.ex.length} ${r.res?.result}`);
setImg({ default: { mode: "crash" } });
r = await img({ prompt: "Crash", save_as: "assets/crash.png" });
t.check("an unexpected Codex error is returned as it is, naming the account, without trying others", r.ex.length === 1 && r.res?.is_error === true && /failed on Codex account 1: The image service returned an unexpected error/.test(r.res.result), r.res?.result);
setImg({ default: { mode: "noimage" } });
r = await img({ prompt: "No file", save_as: "assets/nofile.png" });
t.check("Codex finishes but writes no image: said plainly, nothing saved", r.res?.is_error === true && /without making an image/.test(r.res.result) && !existsSync(join(proj, "assets", "nofile.png")));

// ---- stopping the turn stops Codex ------------------------------------------------------------------------------------------
setImg({ default: { mode: "slow", ms: 30000 } });
id = await run(await mk(), `slow\n${lines(["image_generate", { prompt: "Slow one", save_as: "assets/slow.png" }])}`);
const pid = await waitFor(() => logLines().find((l) => l.exec)?.pid);
t.check("a slow run is under way", !!pid);
await C.call("turn.interrupt", { turn_id: id });
const gone = await waitFor(() => { try { process.kill(pid, 0); return false; } catch { return true; } }, 6000);
t.check("interrupting the chat kills that Codex run (it does not keep spending usage)", !!gone && !existsSync(join(proj, "assets", "slow.png")), String(pid));
setImg({});

// ---- Codex and Antigravity chats -----------------------------------------------------------------------------------------------
const cx = await mk("codex", "auto_edits");
id = await run(cx, "hello codex");
await finished(id);
const ts = logLines().find((l) => l.method === "thread/start")?.params;
t.check("a Codex chat: the devices server entry has a 10-minute tool timeout (Codex's default is 60 s, too short for an image)", ts?.config?.["mcp_servers.opscode_devices"]?.tool_timeout_sec === 600, JSON.stringify(ts?.config));
t.check("and its developer instructions carry the image rule", /Images: for any request to create, draw, design/.test(ts?.developerInstructions ?? ""));
await rt.stop();

for (const mcp of ["1", "0"]) {
  rt = await startRuntime({ env: { ...env, OPSCODE_FAKE_ACP_MCP: mcp }, stateDir, keepState: true });
  await connect();
  const ag = await mk("antigravity", "auto_edits");
  id = await run(ag, "hello agy");
  await finished(id);
  const sn = logLines().find((l) => l.ev === "session_new" && l.cwd === proj);
  const pr = logLines().find((l) => l.ev === "prompt");
  if (mcp === "1") {
    const s0 = sn?.mcp?.[0];
    t.check("Antigravity (agent that can use HTTP MCP): gets Opscode's tool server for this turn, with a bearer token", s0?.type === "http" && s0.name === "opscode_devices" && /^http:\/\/127\.0\.0\.1:\d+\/mcp\/devices$/.test(s0.url) && /^Bearer [0-9a-f]{20,}$/.test(s0.headers?.[0]?.value ?? ""), JSON.stringify(sn?.mcp));
    t.check("and its first message carries the image rule", /Images: for any request to create, draw, design/.test(pr?.text ?? ""), (pr?.text ?? "").slice(0, 100));
  } else {
    t.check("an agent without HTTP MCP gets no tool server and no rule (it could not call the tool)", Array.isArray(sn?.mcp) && sn.mcp.length === 0 && !/image_generate/.test(pr?.text ?? ""), JSON.stringify(sn?.mcp));
  }
  await rt.stop();
}

// ---- Codex missing, or not startable ------------------------------------------------------------------------------------------------
const none = await new G.ImageGen({ codexPath: () => null, accounts: () => [{ id: "default", position: 1, active: true, env: {} }], limitsFor: () => undefined, refreshLimits: async () => undefined }).generate({ prompt: "x", count: 1, size: "", refs: [], signal: new AbortController().signal });
t.check("Codex not installed: a clear message with where to fix it (no run, no crash)", none.ok === false && /Codex isn't installed/.test(none.message) && /Models & keys/.test(none.message), none.message);
const noAcct = await new G.ImageGen({ codexPath: () => "/bin/echo", accounts: () => [], limitsFor: () => undefined, refreshLimits: async () => undefined }).generate({ prompt: "x", count: 1, size: "", refs: [], signal: new AbortController().signal });
t.check("no Codex account at all: says to sign in", noAcct.ok === false && /No Codex account is set up/.test(noAcct.message), noAcct.message);
rt = await startRuntime({ env: { ...env, OPSCODE_CODEX_BIN: join(base, "no-such-codex") }, stateDir, keepState: true });
await connect();
r = await img({ prompt: "Broken program", save_as: "assets/broken.png" });
t.check("a Codex program that cannot start: the error is returned plainly, no crash", r.res?.is_error === true && /could not start Codex/.test(r.res.result), r.res?.result);
await rt.stop();

rmSync(base, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
process.exit(t.finish());
