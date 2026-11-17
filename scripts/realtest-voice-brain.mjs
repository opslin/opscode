// REAL test (uses your own sign-in; two tiny turns): the voice agent running on a real engine other than Claude Code.
//   node scripts/realtest-voice-brain.mjs codex|antigravity|qoder [model-id] [effort]
// The microphone and the voice (TTS) are fakes (words are typed in), the engine is the real program with your own sign-in.
// It says hello, then asks what the workers are doing (the agent should call its work_status tool over MCP), and prints what
// the agent said, which tools it used, and how long each took. No worker is started and no project file is touched.
import { mkdirSync, mkdtempSync, realpathSync, writeFileSync, existsSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { session, startRuntime, sleep } from "./lib/harness.mjs";

const engine = process.argv[2] ?? "codex";
const model = process.argv[3] ?? "";
const effort = process.argv[4] ?? "";
const FOLDER = "sherpa-onnx-pocket-tts-int8-2026-01-26";
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-rt-vb-")));
const proj = join(base, "Demo");
mkdirSync(join(proj, "src"), { recursive: true });
writeFileSync(join(proj, "package.json"), "{}");
const state = join(base, "state");
mkdirSync(join(state, "tts", FOLDER), { recursive: true });
writeFileSync(join(state, "tts", FOLDER, "a.onnx"), "x");
const tlog = join(base, "tts.log");
const env = {
  OPSCODE_VOICE_HELPER: join(process.cwd(), "scripts/lib/fake-voice.mjs"),
  OPSCODE_TTS_URL: "http://127.0.0.1:1/unused", OPSCODE_TTS_FILES: "a.onnx",
  OPSCODE_TTS_WORKER: join(process.cwd(), "scripts/lib/fake-tts-worker.mjs"), OPSCODE_FAKE_TTS_LOG: tlog, OPSCODE_FAKE_TTS_MS: "20",
};
const spoken = () => (existsSync(tlog) ? readFileSync(tlog, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)).filter((x) => x.got === "speak").map((x) => x.text) : []);
const rt = await startRuntime({ env, stateDir: state, keepState: true });
if (!rt.ready) { console.error("runtime did not start", rt.output()); process.exit(1); }
let code = 0;
try {
  const C = await session(rt);
  const ok = async (m, p) => { const r = await C.call(m, p); if (r.error) throw new Error(`${m}: ${r.error.message}`); return r.result; };
  const wid = (await ok("workspace.add", { path: proj })).workspace.id;
  const st = await ok("engines.list", {});
  console.log("engine found:", JSON.stringify((st.engines ?? []).filter((e) => e.id === engine).map((e) => ({ id: e.id, found: e.found, models: (e.models ?? []).slice(0, 6).map((m) => m.id) }))));
  const s = (await ok("voiceagent.start", { workspace_id: wid, brain: { engine, ...(model ? { model } : {}), ...(effort ? { effort } : {}) } })).session;
  const turn = async (words, label) => {
    const t0 = Date.now(); const before = spoken().length; const evBefore = C.find("voiceagent.event", (p) => p.session === s).length;
    await ok("voiceagent.say", { session: s, text: words });
    // done = the agent said something and then nothing new for 3 s
    let last = Date.now(); let n = -1;
    for (const end = Date.now() + 120_000; Date.now() < end; await sleep(150)) {
      const cur = spoken().length + C.find("voiceagent.event", (p) => p.session === s).length;
      if (cur !== n) { n = cur; last = Date.now(); }
      if (spoken().length > before && Date.now() - last > 3000) break;
    }
    const evs = C.find("voiceagent.event", (p) => p.session === s).slice(evBefore).map((m) => m.params);
    console.log(`\n[${label}] "${words}"  -> first speech after ${Math.round((Date.now() - t0 - 3000) / 100) / 10}s`);
    console.log("  agent said:", JSON.stringify(spoken().slice(before)));
    console.log("  tools used:", JSON.stringify(evs.filter((e) => e.ev === "tool").map((e) => e.summary)));
    const errs = evs.filter((e) => e.ev === "error");
    if (errs.length) { console.log("  ERRORS:", JSON.stringify(errs.map((e) => e.message))); code = 1; }
    if (spoken().length === before) { console.log("  (nothing was said)"); code = 1; }
  };
  await turn("Hello buddy, good morning. What can you do for me?", "greeting");
  await turn("What are the workers doing right now?", "status (should call work_status)");
  await ok("voiceagent.stop", { session: s });
} catch (e) {
  console.error("FAILED:", e instanceof Error ? e.message : String(e));
  code = 1;
} finally {
  await rt.stop();
}
console.log(code === 0 ? "\nREAL TEST OK" : "\nREAL TEST HAD PROBLEMS");
process.exit(code);
