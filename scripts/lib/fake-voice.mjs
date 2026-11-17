#!/usr/bin/env node
// A stand-in for native/opscode-voice (same JSON-lines protocol). Commands are logged to $OPSCODE_FAKE_VOICE_LOG.
// OPSCODE_FAKE_VOICE_MIC=denied refuses the microphone; OPSCODE_FAKE_VOICE_SAY sets what "you" say.
import { appendFileSync, rmSync, writeFileSync } from "node:fs";
const log = process.env.OPSCODE_FAKE_VOICE_LOG;
const out = (o) => process.stdout.write(JSON.stringify(o) + "\n");
const said = (process.env.OPSCODE_FAKE_VOICE_SAY ?? "please update the Ops code cart total|and run the tests").split("|");
let listening = false;
let timers = [];
let full = "";
let record = null;
let conversing = false;
out({ ev: "ready" });
let buf = "";
process.stdin.on("data", (d) => {
  buf += d;
  let i;
  while ((i = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, i); buf = buf.slice(i + 1);
    if (!line.trim()) continue;
    const m = JSON.parse(line);
    if (log) appendFileSync(log, JSON.stringify(m) + "\n");
    if (m.cmd === "status") out({ ev: "status", available: true, mic: process.env.OPSCODE_FAKE_VOICE_MIC ?? "granted", os: "26.2" });
    else if (m.cmd === "locales") out({ ev: "locales", speech: ["en-IN", "en-US"], dictation: ["en-IN", "en-US", "fr-FR"], installed: ["en-US"] });
    else if (m.cmd === "converse") {
      // Conversation mode: audio chunks are scripts. "SAY:<words>" = the person says those words, "SPEECH" = they start
      // talking and say nothing yet, "NOISE" = a sound that is not speech. Anything else is quiet.
      if (listening || conversing) { out({ ev: "error", code: "busy", message: "Already listening" }); continue; }
      if (process.env.OPSCODE_FAKE_VOICE_CONVERSE_ERROR) { out({ ev: "error", code: process.env.OPSCODE_FAKE_VOICE_CONVERSE_ERROR, message: "fake converse failure" }); continue; }
      conversing = true;
      out({ ev: "asset", progress: 1 });
      out({ ev: "started", locale: m.locale === "auto" ? "en_IN" : m.locale, engine: "speech" });
    } else if (m.cmd === "audio") {
      if (!conversing) continue;
      const text = Buffer.from(String(m.pcm), "base64").toString("latin1");
      if (text.startsWith("SAY:")) {
        const words = text.slice(4).split(" ");
        out({ ev: "speech" });
        for (let k = 1; k <= words.length; k++) out({ ev: "partial", text: words.slice(0, k).join(" ") });
        setTimeout(() => out({ ev: "utterance", text: text.slice(4), ms: 1200 }), 40);
      } else if (text === "SPEECH") out({ ev: "speech" });
      else if (text === "NOISE") { out({ ev: "speech" }); setTimeout(() => out({ ev: "noise", ms: 400 }), 30); }
    } else if (m.cmd === "vad") {
      // logged above
    } else if (m.cmd === "start") {
      if (listening) { out({ ev: "error", code: "busy", message: "Already listening" }); continue; }
      if (process.env.OPSCODE_FAKE_VOICE_MIC === "denied") { out({ ev: "error", code: "mic_denied", message: "no mic" }); continue; }
      listening = true; full = "";
      record = typeof m.record === "string" ? m.record : null;
      if (record) writeFileSync(record, "fake m4a audio");
      out({ ev: "asset", progress: 1 });
      out({ ev: "started", locale: m.locale === "auto" ? "en_IN" : m.locale, engine: "speech" });
      // Speak slowly: partial words, then a final sentence, per phrase.
      let t = 100;
      for (const phrase of said) {
        const words = phrase.split(" ");
        for (let k = 1; k <= words.length; k++) { const text = words.slice(0, k).join(" "); timers.push(setTimeout(() => { out({ ev: "level", rms: 0.3 + (k % 3) / 10 }); out({ ev: "partial", text }); }, t)); t += 60; }
        timers.push(setTimeout(() => { full = full ? `${full} ${phrase}` : phrase; out({ ev: "final", text: phrase, full }); }, t)); t += 120;
      }
    } else if (m.cmd === "stop" && conversing) {
      conversing = false; out({ ev: "done", text: "", secs: 1 });
    } else if (m.cmd === "cancel" && conversing) {
      conversing = false; out({ ev: "cancelled" });
    } else if (m.cmd === "stop") {
      if (!listening) { out({ ev: "done", text: "" }); continue; }
      // Like the real one: what was still being heard becomes final before done.
      setTimeout(() => { for (const x of timers) clearTimeout(x); timers = []; listening = false; full = said.join(" "); out({ ev: "done", text: full, secs: 2.5, ...(record ? { file: record } : {}) }); record = null; }, 80);
    } else if (m.cmd === "cancel") {
      for (const x of timers) clearTimeout(x); timers = []; listening = false; if (record) rmSync(record, { force: true }); record = null; out({ ev: "cancelled" });
    } else out({ ev: "error", code: "bad_command", message: `unknown ${m.cmd}` });
  }
});
process.stdin.on("end", () => process.exit(0));
