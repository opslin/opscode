// Voice note (V2): the mic can also keep the recording. It is saved inside the project in a git-ignored
// folder (.opscode/attachments/<id>/voice-note-<date time>.m4a), arrives with the text on `done`, attaches
// like any file, goes to the agent as a path, and a cancelled note leaves nothing behind.
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";
const t = reporter();

const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p39-")));
const proj = join(base, "Shopkart");
mkdirSync(proj);
writeFileSync(join(proj, "package.json"), "{}");
const vlog = join(base, "voice.log");
const elog = join(base, "engines.log");
const env = { OPSCODE_VOICE_HELPER: join(process.cwd(), "scripts/lib/fake-voice.mjs"), OPSCODE_FAKE_VOICE_LOG: vlog, OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_FAKE_ENGINE_LOG: elog };
const cmds = () => (existsSync(vlog) ? readFileSync(vlog, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const waitFor = async (fn, ms = 8000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(50)) { const v = await fn(); if (v) return v; } return null; };
const attDir = join(proj, ".opscode", "attachments");

const rt = await startRuntime({ env, stateDir: join(base, "state") });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;

  // Plain dictation keeps nothing.
  const d = (await C.call("voice.start", { workspace_id: wid })).result.session;
  await waitFor(() => cmds().at(-1)?.cmd === "start");
  t.check("dictation does not record a file", cmds().at(-1)?.cmd === "start" && cmds().at(-1)?.record === undefined);
  await C.call("voice.stop", { cancel: true });
  await waitFor(() => C.find("voice.event", (p) => p.session === d && p.ev === "cancelled")[0]);

  // A voice note needs a project.
  t.check("a voice note without a project is refused", !!(await C.call("voice.start", { note: true })).error);

  // Record, then stop: the file and the text arrive together.
  const s1 = (await C.call("voice.start", { workspace_id: wid, note: true })).result.session;
  await waitFor(() => cmds().at(-1)?.cmd === "start");
  const rec = cmds().at(-1)?.record;
  t.check("the recording goes in the project's git-ignored attachments folder, named by date and time", /^.*\/Shopkart\/\.opscode\/attachments\/\d{8}-[0-9a-f]{6}\/voice-note-\d{8}-\d{6}\.m4a$/.test(rec ?? "") && rec.startsWith(`${proj}/`) && existsSync(rec) && readFileSync(join(attDir, ".gitignore"), "utf8").trim() === "*", rec);
  await waitFor(() => C.find("voice.event", (p) => p.session === s1 && p.ev === "final")[0]);
  await C.call("voice.stop", {});
  const done = (await waitFor(() => C.find("voice.event", (p) => p.session === s1 && p.ev === "done")[0]))?.params;
  t.check("done carries the text (project word fixed) and the recording's path", done?.text === "please update the Opscode cart total and run the tests" && done.file === rec && existsSync(done.file), JSON.stringify(done));

  // It attaches like any file (already inside the project: used in place) and reaches the agent as a path.
  const att = (await C.call("attachment.add", { workspace_id: wid, paths: [done.file] })).result.items[0];
  t.check("attaching it keeps it in place, as a file", att?.kind === "file" && att.path === rec.slice(proj.length + 1) && /^voice-note-/.test(att.name), JSON.stringify(att));
  const chat = (await C.call("chat.create", { workspace_id: wid, mode: "full", engine: "claude-code" })).result.chat;
  const r = (await C.call("turn.submit", { workspace_id: wid, chat_id: chat.id, text: done.text, attachments: [att.path] })).result;
  await waitFor(() => C.find("turn.event", (p) => p.turn_id === r.turn_id && p.type === "completed")[0]);
  const prompt = readFileSync(elog, "utf8").trim().split("\n").map((l) => JSON.parse(l)).filter((e) => e.prompt).at(-1)?.prompt ?? "";
  t.check("the agent gets the text and the recording's path", prompt.includes("please update the Opscode cart total") && prompt.includes(att.path), prompt.slice(0, 300));

  // Cancel: the file and its folder are removed.
  const before = readdirSync(attDir).length;
  const s2 = (await C.call("voice.start", { workspace_id: wid, note: true })).result.session;
  await waitFor(() => cmds().at(-1)?.cmd === "start");
  const rec2 = cmds().at(-1)?.record;
  await sleep(150);
  await C.call("voice.stop", { cancel: true });
  await waitFor(() => C.find("voice.event", (p) => p.session === s2 && p.ev === "cancelled")[0]);
  await sleep(150);
  t.check("a cancelled note leaves nothing behind (no file, no empty folder)", !existsSync(rec2) && !existsSync(join(rec2, "..")) && readdirSync(attDir).length === before, `${rec2} ${readdirSync(attDir).length}/${before}`);
  t.check("each note gets its own folder", join(rec2, "..") !== join(rec, ".."));
} catch (e) {
  t.check("no exception", false, String(e?.stack ?? e));
}
const exit = await rt.stop();
t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);

// A failed microphone also removes the folder it made.
const rt2 = await startRuntime({ env: { ...env, OPSCODE_FAKE_VOICE_MIC: "denied" }, stateDir: join(base, "state2") });
try {
  const C = await session(rt2);
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  const before = readdirSync(attDir).length;
  const s = (await C.call("voice.start", { workspace_id: wid, note: true })).result.session;
  const err = await waitFor(() => C.find("voice.event", (p) => p.session === s && p.ev === "error")[0]);
  await sleep(150);
  t.check("microphone refused: error reported and no folder left", err?.params.code === "mic_denied" && readdirSync(attDir).length === before);
} catch (e) {
  t.check("no exception (denied)", false, String(e?.stack ?? e));
}
await rt2.stop();
process.exit(t.finish());
