#!/usr/bin/env node
// REAL check of the voice helper's conversation mode (Apple's on-device recognizer, this Mac's speech model).
// Speech is made with `say`, joined with silence, and fed to `opscode-voice` as 16 kHz PCM exactly as the window
// feeds the microphone. Expect: one utterance per sentence, in order, with the project word kept, no utterance for noise.
// Usage: node scripts/realtest-voice-converse.mjs [--keep]   (needs macOS 26 + the built helper; not part of `npm test`)
import { spawn, execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const helper = new URL("../dist/native/opscode-voice", import.meta.url).pathname;
const dir = mkdtempSync(join(tmpdir(), "opscode-conv-"));
const SENTENCES = [
  "Please add a dark mode switch to the settings page.",
  "Also run the tests when you are done.",
  "What is the worker doing right now?",
];
const GAP_S = 1.8;

/** `say` -> 16 kHz mono Int16 PCM bytes. */
function speak(text, n) {
  const aiff = join(dir, `s${n}.aiff`), wav = join(dir, `s${n}.wav`);
  execFileSync("say", ["-v", "Samantha", "-o", aiff, text]);
  execFileSync("afconvert", ["-f", "WAVE", "-d", "LEI16@16000", "-c", "1", aiff, wav]);
  const buf = readFileSync(wav);
  let p = 12;
  while (p + 8 <= buf.length) {
    const id = buf.toString("ascii", p, p + 4), size = buf.readUInt32LE(p + 4);
    if (id === "data") return buf.subarray(p + 8, p + 8 + size);
    p += 8 + size + (size & 1);
  }
  throw new Error("no data chunk");
}
const silence = (s, level = 0) => {
  const b = Buffer.alloc(Math.round(s * 16000) * 2);
  if (level) for (let i = 0; i < b.length; i += 2) b.writeInt16LE(Math.round((Math.random() - 0.5) * level), i); // faint room noise
  return b;
};

const pieces = [silence(1.0, 60)];
SENTENCES.forEach((s, i) => { pieces.push(speak(s, i), silence(GAP_S, 60)); });
// A short click (a cough or a chair) must not become an utterance.
const click = Buffer.alloc(3200 * 2);
for (let i = 0; i < 1600; i++) click.writeInt16LE(Math.round(Math.sin(i / 3) * 9000 * (1 - i / 1600)), i * 2);
const clicks = !process.argv.includes("--noclick");
if (clicks) pieces.splice(3, 0, click, silence(1.6, 60)); // after the first gap, before sentence 2
const audio = Buffer.concat(pieces);

const p = spawn(helper, [], { stdio: ["pipe", "pipe", "inherit"], env: { ...process.env } });
const events = [];
let buf = "";
p.stdout.on("data", (d) => {
  buf += d;
  let i;
  while ((i = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, i); buf = buf.slice(i + 1);
    if (!line.trim()) continue;
    const e = JSON.parse(line);
    events.push({ ...e, at: Date.now() });
    if (e.ev === "utterance" || e.ev === "speech" || e.ev === "noise" || e.ev === "error" || e.ev === "started") console.log(JSON.stringify(e));
  }
});
const send = (o) => p.stdin.write(JSON.stringify(o) + "\n");
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const until = async (f, ms) => { for (const end = Date.now() + ms; Date.now() < end; await wait(50)) if (f()) return true; return false; };

send({ cmd: "converse", locale: "en-US", words: ["Opscode"], end_ms: 1100, speech_ms: 240 });
if (!(await until(() => events.some((e) => e.ev === "started" || e.ev === "error"), 60000)) || events.some((e) => e.ev === "error")) { console.error("could not start:", JSON.stringify(events.find((e) => e.ev === "error"))); p.kill(); process.exit(2); }
// Real-time pacing in 100 ms chunks, like a live microphone (--fast: 5x, which can race the recognizer).
const CH = 3200;
const t0 = Date.now();
for (let o = 0; o < audio.length; o += CH) { send({ cmd: "audio", pcm: audio.subarray(o, o + CH).toString("base64") }); await wait(process.argv.includes("--fast") ? 20 : 100); }
await until(() => events.filter((e) => e.ev === "utterance").length >= SENTENCES.length, 8000);
send({ cmd: "stop" });
await until(() => events.some((e) => e.ev === "done"), 8000);
p.stdin.end();

const utter = events.filter((e) => e.ev === "utterance").map((e) => e.text);
const norm = (s) => s.toLowerCase().replace(/[^a-z ]/g, "").replace(/\s+/g, " ").trim();
let ok = true;
const check = (name, pass, extra = "") => { ok &&= pass; console.log(`${pass ? "PASS" : "FAIL"}  ${name}${extra ? `  ${extra}` : ""}`); };
console.log(`\naudio ${(audio.length / 32000).toFixed(1)} s fed in ${((Date.now() - t0) / 1000).toFixed(1)} s`);
check(`${SENTENCES.length} utterances (the click is not one)`, utter.length === SENTENCES.length, JSON.stringify(utter));
SENTENCES.forEach((s, i) => {
  const a = norm(s).split(" "), b = new Set(norm(utter[i] ?? "").split(" "));
  const hit = a.filter((w) => b.has(w)).length / a.length;
  check(`sentence ${i + 1} understood (${Math.round(hit * 100)}% of words)`, hit >= 0.8, utter[i] ?? "(missing)");
});
check("speech events came before their utterances", events.filter((e) => e.ev === "speech").length >= SENTENCES.length);
check("stop ends the session", events.some((e) => e.ev === "done"));
if (!process.argv.includes("--keep")) rmSync(dir, { recursive: true, force: true });
process.exit(ok ? 0 : 1);
