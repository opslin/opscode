// A stand-in for src/runtime/tts/worker.js (same IPC protocol): makes a short tone per sentence instead of speech.
// OPSCODE_FAKE_TTS_LOG logs what it receives; OPSCODE_FAKE_TTS_MS is the time one sentence takes (default 40).
// A sentence containing FAILME fails; a sentence containing SLOW takes a second.
import { appendFileSync } from "node:fs";
const log = process.env.OPSCODE_FAKE_TTS_LOG;
const L = (o) => log && appendFileSync(log, JSON.stringify({ pid: process.pid, ...o }) + "\n");
const ms = Number(process.env.OPSCODE_FAKE_TTS_MS ?? 40);
const cancelled = new Set();
let chain = Promise.resolve();
const send = (m) => process.send(m);
process.on("message", (m) => {
  L({ got: m.t, ...(m.t === "speak" ? { id: m.id, text: m.text, voice: m.voice, steps: m.steps } : {}), ...(m.t === "cancel" ? { id: m.id } : {}), ...(m.t === "init" ? { dir: m.dir } : {}) });
  if (m.t === "init") chain = chain.then(() => new Promise((r) => setTimeout(r, 30))).then(() => send({ t: "ready", ms: 30, rate: 24000 }));
  else if (m.t === "speak") chain = chain.then(async () => {
    if (cancelled.has(m.id)) { cancelled.delete(m.id); return send({ t: "cancelled", id: m.id }); }
    await new Promise((r) => setTimeout(r, m.text.includes("SLOW") ? 1000 : ms));
    if (cancelled.has(m.id)) { cancelled.delete(m.id); return send({ t: "cancelled", id: m.id }); }
    if (m.text.includes("FAILME")) return send({ t: "error", id: m.id, message: "fake voice failure" });
    const n = Math.min(Number(process.env.OPSCODE_FAKE_TTS_MAX ?? 24000), (2400 + m.text.length * 120) * Number(process.env.OPSCODE_FAKE_TTS_SCALE ?? 1));
    const pcm = new Int16Array(n);
    const f = 220 + (m.text.length % 7) * 40;
    for (let i = 0; i < n; i++) pcm[i] = Math.round(Math.sin((2 * Math.PI * f * i) / 24000) * 8000);
    send({ t: "audio", id: m.id, pcm, rate: 24000, ms });
  });
  else if (m.t === "cancel") cancelled.add(m.id);
  else if (m.t === "exit") { L({ exit: true }); process.exit(0); }
});
process.on("disconnect", () => { L({ disconnect: true }); process.exit(0); });
send({ t: "hello" });
