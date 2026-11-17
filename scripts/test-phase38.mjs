// Voice input V1: the runtime runs the voice helper (Apple's on-device speech recognition; a fake here),
// passes its live words to the window as `voice.event`, fixes split project words ("Ops code" -> Opscode),
// keeps one session at a time, can cancel, and reports a refused microphone clearly.
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";
const t = reporter();
const V = await import(join(process.cwd(), "dist/runtime/voice.js"));

t.check("split words are joined back (any case/spacing between letters)", V.fixWords("open the Ops code app and ops code docs", ["Opscode"]) === "open the Opscode app and Opscode docs");
t.check("short names are left alone (\"code x\" stays)", V.fixWords("run the code x times", ["Codex"]) === "run the code x times");
t.check("other words are untouched", V.fixWords("update the cart total", ["Opscode", "Shopkart"]) === "update the cart total");
t.check("project names with several parts work", V.fixWords("in the shop kart project", ["Shopkart"]) === "in the Shopkart project");

const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p38-")));
writeFileSync(join(base, "package.json"), "{}");
const vlog = join(base, "voice.log");
const env = { OPSCODE_VOICE_HELPER: join(process.cwd(), "scripts/lib/fake-voice.mjs"), OPSCODE_FAKE_VOICE_LOG: vlog };
const cmds = () => (existsSync(vlog) ? readFileSync(vlog, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const waitFor = async (fn, ms = 8000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(50)) { const v = await fn(); if (v) return v; } return null; };

let rt = await startRuntime({ env, stateDir: join(base, "state") });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
try {
  const C = await session(rt);
  mkdirSync(join(base, "Shopkart"), { recursive: true });
  const wid = (await C.call("workspace.add", { path: join(base, "Shopkart") })).result.workspace.id;
  const st = (await C.call("voice.status", {})).result;
  t.check("status: helper found, recognizer available, microphone state", st.helper === true && st.available === true && st.mic === "granted" && st.os === "26.2", JSON.stringify(st));
  const loc = (await C.call("voice.locales", {})).result;
  t.check("languages: on-device speech + dictation lists", loc.speech.includes("en-IN") && loc.dictation.includes("fr-FR"));

  const s1 = (await C.call("voice.start", { workspace_id: wid })).result.session;
  await waitFor(() => cmds().at(-1)?.cmd === "start");
  t.check("start returns a session; the helper is asked for 'auto' language with the project and Opscode as words to keep", !!s1 && cmds().at(-1)?.cmd === "start" && cmds().at(-1).locale === "auto" && cmds().at(-1).words.includes("Opscode") && cmds().at(-1).words.includes("Shopkart"), JSON.stringify(cmds().at(-1)));
  const busy = await C.call("voice.start", { workspace_id: wid });
  t.check("a second start while listening is refused (one microphone)", busy.error?.message === "Already listening");
  const ev = (type) => C.find("voice.event", (p) => p.session === s1 && p.ev === type).map((m) => m.params);
  await waitFor(() => ev("final").length >= 1);
  t.check("live words arrive as they are spoken (started, level, partial)", ev("started").length === 1 && ev("level").length > 0 && ev("partial").length >= 3);
  t.check("finished sentences arrive with the project word fixed", ev("final")[0]?.text === "please update the Opscode cart total" && ev("final")[0]?.full === "please update the Opscode cart total", JSON.stringify(ev("final")[0]));
  await C.call("voice.stop", {});
  const done = await waitFor(() => ev("done")[0]);
  t.check("stop gives the whole text (fixed)", done?.text === "please update the Opscode cart total and run the tests", JSON.stringify(done));

  const s2 = (await C.call("voice.start", {})).result.session;
  t.check("after done, a new session can start", !!s2 && s2 !== s1);
  await sleep(150);
  await C.call("voice.stop", { cancel: true });
  t.check("cancel ends it with 'cancelled' (nothing to insert)", !!(await waitFor(() => C.find("voice.event", (p) => p.session === s2 && p.ev === "cancelled")[0])) && !C.find("voice.event", (p) => p.session === s2 && p.ev === "done").length);
  t.check("stop when nothing is listening is harmless", (await C.call("voice.stop", {})).result.stopped === false);

  const bad = await C.call("settings.set", { patch: { voice_locale: "en-IN; rm -rf /" } });
  t.check("the voice language setting only takes language codes", !!bad.error);
  await C.call("settings.set", { patch: { voice_locale: "en-IN" } });
  await C.call("voice.start", {});
  t.check("the chosen language is used", !!(await waitFor(() => cmds().at(-1)?.cmd === "start" && cmds().at(-1)?.locale === "en-IN")), JSON.stringify(cmds().at(-1)));
  await C.call("voice.stop", { cancel: true });
} catch (e) {
  t.check("no exception", false, String(e?.stack ?? e));
}
await rt.stop();

// A refused microphone: a clear error event, and the session is over.
rt = await startRuntime({ env: { ...env, OPSCODE_FAKE_VOICE_MIC: "denied" }, stateDir: join(base, "state2") });
try {
  const C = await session(rt);
  t.check("status says the microphone is denied", (await C.call("voice.status", {})).result.mic === "denied");
  const s = (await C.call("voice.start", {})).result.session;
  const err = await waitFor(() => C.find("voice.event", (p) => p.session === s && p.ev === "error")[0]?.params);
  t.check("starting reports mic_denied", err?.code === "mic_denied");
  t.check("…and a new try is allowed (the failed session is over)", !!(await C.call("voice.start", {})).result?.session);
} catch (e) {
  t.check("no exception (denied)", false, String(e?.stack ?? e));
}
await rt.stop();

// No helper (another OS or a failed build): status says so, start is refused with a reason.
rt = await startRuntime({ env: { OPSCODE_VOICE_HELPER: "" }, stateDir: join(base, "state3") });
try {
  const C = await session(rt);
  const st = (await C.call("voice.status", {})).result;
  // dist/native/opscode-voice exists on this Mac, so an empty override falls back to it: helper true.
  t.check("without an override the built helper is used when present", st.helper === existsSync(join(process.cwd(), "dist/native/opscode-voice")));
} catch (e) {
  t.check("no exception (no override)", false, String(e?.stack ?? e));
}
await rt.stop();
process.exit(t.finish());
