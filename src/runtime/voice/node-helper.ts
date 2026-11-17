// The speech helper for computers without Apple's recognizer: the same JSON-lines protocol as native/opscode-voice
// (stdin: commands, stdout: events), run by the runtime with Electron-as-Node. The window captures the microphone and
// sends it with `audio`; recognition is on this computer (src/runtime/voice/engine.ts). The speech model is downloaded
// once, on first use (events `asset` with progress).
//
//   status  locales  start{record}  converse{end_ms}  audio{pcm}  vad{boost}  stop  cancel
//   events: ready status locales asset started level partial final speech utterance noise done cancelled error

import { tmpdir } from "node:os";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { SpeechEngine, pcmFromBase64, type Sherpa } from "./engine";
import { ensureSpeechModel, speechInstalled } from "./models";

const out = (o: Record<string, unknown>): void => { process.stdout.write(`${JSON.stringify(o)}\n`); };
const dir = process.env.OPSCODE_VOICE_DIR || join(tmpdir(), "opscode-voice");
const IDLE_MS = Number(process.env.OPSCODE_VOICE_IDLE_MS) || 180_000;

let sherpa: Sherpa | null = null;
let loadError = "";
try { sherpa = require("sherpa-onnx-node") as Sherpa; } catch (e) { loadError = e instanceof Error ? e.message : String(e); }
const engine = sherpa ? new SpeechEngine(sherpa, dir, out) : null;

// Nobody has talked for a while: give the memory back (the runtime starts this helper again when it is needed).
let idle: NodeJS.Timeout | undefined;
const touch = (): void => {
  clearTimeout(idle);
  idle = setTimeout(() => { if (!engine?.active()) process.exit(0); else touch(); }, IDLE_MS);
  idle.unref?.();
};

let starting = false;
async function begin(kind: "dictate" | "converse", m: Record<string, unknown>): Promise<void> {
  if (!engine) { out({ ev: "error", code: "unavailable", message: `Voice input is not available here: ${loadError || "the speech engine did not load"}.` }); return; }
  if (engine.active() || starting) { out({ ev: "error", code: "busy", message: "Already listening" }); return; }
  starting = true;
  try {
    if (!speechInstalled(dir)) {
      out({ ev: "asset", progress: 0 });
      let last = 0;
      await ensureSpeechModel(dir, (p) => { if (p - last >= 0.01 || p >= 1) { last = p; out({ ev: "asset", progress: p }); } });
    }
    engine.start(kind, { endMs: typeof m.end_ms === "number" ? m.end_ms : undefined, record: typeof m.record === "string" ? m.record : undefined });
    out({ ev: "started", locale: "en-US", engine: "kroko", capture: "window" });
  } catch (e) {
    out({ ev: "error", code: "asset", message: `Couldn't get the speech model: ${e instanceof Error ? e.message : String(e)}` });
  } finally {
    starting = false;
  }
}

out({ ev: "ready" });
touch();
const rl = createInterface({ input: process.stdin });
rl.on("line", (line) => {
  let m: Record<string, unknown>;
  try { m = JSON.parse(line) as Record<string, unknown>; } catch { return; }
  touch();
  try {
    switch (m.cmd) {
      case "status": out({ ev: "status", available: !!engine, mic: "window", os: process.platform, engine: "kroko", capture: "window", installed: speechInstalled(dir), ...(loadError ? { error: loadError } : {}) }); break;
      case "locales": out({ ev: "locales", speech: ["en-US"], dictation: ["en-US"], installed: ["en-US"] }); break;
      case "start": void begin("dictate", m); break;
      case "converse": void begin("converse", m); break;
      case "audio": if (engine?.active() && typeof m.pcm === "string") engine.audio(pcmFromBase64(m.pcm)); break;
      case "vad": engine?.setBoost(Number(m.boost) || 1); break;
      case "stop": if (engine?.active()) engine.stop(); else out({ ev: "done", text: "" }); break;
      case "cancel": if (engine?.active()) engine.cancel(); else out({ ev: "cancelled" }); break;
      default: out({ ev: "error", code: "bad_command", message: `unknown ${String(m.cmd)}` });
    }
  } catch (e) {
    out({ ev: "error", code: "audio", message: e instanceof Error ? e.message : String(e) });
  }
});
rl.on("close", () => process.exit(0));
