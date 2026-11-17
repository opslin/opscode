// The speech helper for Windows/Linux (src/runtime/voice): the same protocol as the Apple helper, recognition on the CPU.
// Real recognition of recorded speech (scripts/fixtures/voice), real model download the first time (cached in the temp
// folder), no microphone: audio is fed faster than real time (the helper runs on the audio's own clock).
import { existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, sleep } from "./lib/harness.mjs";

const t = reporter();
const ROOT = process.cwd();
const dir = process.env.OPSCODE_VOICE_TEST_DIR || join(tmpdir(), "opscode-voice-test-cache");
mkdirSync(dir, { recursive: true });
const wav = (name) => { const b = readFileSync(join(ROOT, "scripts/fixtures/voice", name)); const off = b.indexOf("data") + 8; return new Int16Array(b.buffer.slice(b.byteOffset + off, b.byteOffset + b.length - ((b.length - off) % 2))); };
const silence = (sec) => new Int16Array(Math.round(16000 * sec));
const noiseClick = () => { const x = new Int16Array(4800); for (let i = 0; i < 400; i++) x[2000 + i] = Math.round(Math.sin(i / 3) * 18000 * Math.exp(-i / 80)); return x; };
const concat = (...parts) => { const out = new Int16Array(parts.reduce((a, p) => a + p.length, 0)); let o = 0; for (const p of parts) { out.set(p, o); o += p.length; } return out; };
const b64 = (x) => Buffer.from(x.buffer, x.byteOffset, x.byteLength).toString("base64");
const norm = (s) => s.toLowerCase().replace(/[^a-z' ]+/g, " ").replace(/\s+/g, " ").trim();

function startHelper(env = {}) {
  const p = spawn(process.execPath, [join(ROOT, "dist/runtime/voice/node-helper.js")], { stdio: ["pipe", "pipe", "pipe"], env: { ...process.env, ELECTRON_RUN_AS_NODE: "1", OPSCODE_VOICE_DIR: dir, ...env } });
  const events = []; let buf = "";
  p.stdout.setEncoding("utf8");
  p.stdout.on("data", (d) => { buf += d; let i; while ((i = buf.indexOf("\n")) >= 0) { const l = buf.slice(0, i); buf = buf.slice(i + 1); if (l.trim()) events.push(JSON.parse(l)); } });
  p.stderr.on("data", (d) => process.stderr.write(`[helper] ${d}`));
  const send = (m) => p.stdin.write(JSON.stringify(m) + "\n");
  const feed = (pcm) => { for (let i = 0; i < pcm.length; i += 1600) send({ cmd: "audio", pcm: b64(pcm.subarray(i, Math.min(i + 1600, pcm.length))) }); };
  const wait = async (fn, ms = 20000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(30)) { const v = fn(); if (v) return v; } return null; };
  return { p, events, send, feed, wait, ev: (n) => events.filter((e) => e.ev === n), stop: () => { try { p.stdin.end(); } catch {} setTimeout(() => p.kill(), 500).unref(); } };
}

const t0 = Date.now();
let h = startHelper();
try {
  t.check("the helper starts and says ready", !!(await h.wait(() => h.ev("ready")[0], 8000)));
  h.send({ cmd: "status" });
  const st = await h.wait(() => h.ev("status")[0], 8000);
  t.check("status: available, microphone comes from the window, engine named", st?.available === true && st.mic === "window" && st.capture === "window" && st.engine === "kroko", JSON.stringify(st));
  h.send({ cmd: "locales" });
  t.check("locales: English", (await h.wait(() => h.ev("locales")[0], 5000))?.speech?.[0] === "en-US");

  // ---- conversation: speech, a click, speech --------------------------------------------------------------------------------
  h.send({ cmd: "converse", locale: "auto", words: ["Opscode"], end_ms: 1100, speech_ms: 240 });
  const started = await h.wait(() => h.ev("started")[0], 180_000); // the first run downloads the model
  const assets = h.ev("asset");
  t.check("the first start gets the speech model (progress reported) and then starts", !!started && started.capture === "window" && (existsSync(join(dir, "kroko", "encoder.onnx")) && existsSync(join(dir, "silero_vad.onnx"))), JSON.stringify({ started, assets: assets.length }));
  if (assets.length) t.check("download progress runs from 0 to 1", assets[0].progress === 0 && assets.at(-1).progress === 1 && assets.every((a, i) => i === 0 || a.progress >= assets[i - 1].progress), JSON.stringify(assets.map((a) => a.progress)));
  const audio = concat(silence(1.2), wav("a.wav"), silence(2), noiseClick(), silence(2), wav("b.wav"), silence(2));
  h.feed(audio);
  const ut = await h.wait(() => h.ev("utterance").length >= 2, 30000);
  const us = h.ev("utterance").map((e) => e.text);
  t.check("two sentences become two utterances, in order, with the right words", !!ut && norm(us[0]) === "please add a dark mode switch to the settings page" && norm(us[1]) === "run the tests and tell me which ones failed", JSON.stringify(us));
  t.check("they are capitalised and end with a full stop", /^Please add/.test(us[0] ?? "") && /\.$/.test(us[0] ?? ""), JSON.stringify(us));
  t.check("a speech event came before each, and partial words as it went", h.ev("speech").length >= 2 && h.ev("partial").length >= 4 && h.ev("partial")[0].text.length > 0, `${h.ev("speech").length} speech, ${h.ev("partial").length} partial`);
  t.check("the click between them was not an utterance", us.length === 2, JSON.stringify(us));

  // ---- barge-in boost: a quiet sound is not enough while the agent talks ---------------------------------------------------------
  const before = h.ev("speech").length;
  h.send({ cmd: "vad", boost: 4 });
  const quiet = wav("c.wav").map((v) => Math.round(v * 0.04)); // far quieter than speech meant for the microphone
  h.feed(concat(silence(0.5), quiet, silence(2.5)));
  await sleep(1500);
  t.check("while the boost is on, very quiet speech does not start an utterance", h.ev("speech").length === before && h.ev("utterance").length === 2, `${h.ev("speech").length - before} new`);
  h.send({ cmd: "vad", boost: 1 });
  h.feed(concat(wav("c.wav"), silence(2.5)));
  const third = await h.wait(() => h.ev("utterance").length >= 3, 15000);
  t.check("back to normal it is heard", !!third && norm(h.ev("utterance")[2].text) === "yes go ahead and approve that", JSON.stringify(h.ev("utterance").map((e) => e.text)));
  h.send({ cmd: "stop" });
  t.check("stop ends the conversation (done)", !!(await h.wait(() => h.ev("done")[0], 5000)));

  // ---- dictation: live partial words, finals per sentence, done with the full text, the recording kept -----------------------------
  const rec = join(dir, `note-${Date.now()}.m4a`);
  h.send({ cmd: "start", locale: "auto", words: [], record: rec });
  t.check("dictation starts", !!(await h.wait(() => h.ev("started").length >= 2, 10000)));
  const nPartial = h.ev("partial").length;
  h.feed(concat(wav("a.wav"), silence(2.6), wav("b.wav")));
  await h.wait(() => h.ev("final").length >= 1, 15000);
  t.check("a pause closes the first sentence: final with its text", h.ev("final").length >= 1 && norm(h.ev("final").at(-1).text) === "please add a dark mode switch to the settings page" && h.ev("final").at(-1).full === h.ev("final").at(-1).text, JSON.stringify(h.ev("final")));
  t.check("the words arrive live (partials) and the level moves", h.ev("partial").length > nPartial && h.ev("level").length > 5 && h.ev("level").some((l) => l.rms > 0.05));
  h.send({ cmd: "stop" });
  const done = await h.wait(() => h.ev("done").length >= 2, 10000);
  const dn = h.ev("done").at(-1);
  t.check("stop finishes what was being said: done carries both sentences", !!done && norm(dn.text) === "please add a dark mode switch to the settings page run the tests and tell me which ones failed", JSON.stringify(dn));
  const wavFile = dn?.file;
  t.check("the recording is kept as a WAV beside the requested name", !!wavFile && wavFile.endsWith(".wav") && existsSync(wavFile) && statSync(wavFile).size > 100_000, wavFile);
  if (wavFile) { const hd = readFileSync(wavFile).subarray(0, 12).toString("latin1"); t.check("…a real WAV file (RIFF/WAVE)", hd.startsWith("RIFF") && hd.endsWith("WAVE"), hd); rmSync(wavFile, { force: true }); }

  // ---- cancel, busy, bad command --------------------------------------------------------------------------------------------------
  h.send({ cmd: "start", locale: "auto", words: [], record: join(dir, "cancelled.m4a") });
  await h.wait(() => h.ev("started").length >= 3, 10000);
  h.send({ cmd: "converse", locale: "auto", words: [] });
  t.check("a second session while listening is refused (busy)", !!(await h.wait(() => h.ev("error").find((e) => e.code === "busy"), 5000)));
  h.feed(wav("c.wav"));
  h.send({ cmd: "cancel" });
  t.check("cancel ends it and leaves no recording", !!(await h.wait(() => h.ev("cancelled")[0], 5000)) && !existsSync(join(dir, "cancelled.wav")));
  h.send({ cmd: "nonsense" });
  t.check("an unknown command is answered with an error, not a crash", !!(await h.wait(() => h.ev("error").find((e) => e.code === "bad_command"), 5000)) && h.p.exitCode === null);
} catch (e) {
  t.check("no unexpected error", false, e instanceof Error ? e.stack : String(e));
} finally {
  h.stop();
}

// ---- the helper gives its memory back when nobody is talking ---------------------------------------------------------------------
{
  const g = startHelper({ OPSCODE_VOICE_IDLE_MS: "700" });
  await g.wait(() => g.ev("ready")[0], 8000);
  const exited = await new Promise((res) => { g.p.on("exit", () => res(true)); setTimeout(() => res(false), 4000); });
  t.check("an idle helper exits by itself (the runtime starts it again when needed)", exited === true);
}
t.check("the whole run took a reasonable time", Date.now() - t0 < 240_000, `${Math.round((Date.now() - t0) / 1000)} s`);
process.exit(t.finish());
