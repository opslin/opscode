// Keeps Kitten loaded in a dedicated process while retaining the app's sentence playback protocol.
import { LocalVoiceWorker } from "../voice/localRuntime";

const send = (m: Record<string, unknown>): void => { process.send?.(m); };
let model: LocalVoiceWorker | undefined;
let chain = Promise.resolve();
const pending = new Map<string, { cancelled: boolean }>();

function close(): void { model?.close(); process.exit(0); }

process.on("message", (m: Record<string, unknown>) => {
  switch (m.t) {
    case "init":
      chain = chain.then(async () => {
        model = new LocalVoiceWorker("kitten", String(m.dir));
        const result = await model.call({ cmd: "load" });
        send({ t: "ready", ms: result.ms, rate: 24_000 });
      }).catch((error) => { send({ t: "error", message: error.message }); });
      break;
    case "speak": {
      const id = String(m.id);
      const req = { cancelled: false };
      pending.set(id, req);
      chain = chain.then(async () => {
        try {
          if (req.cancelled) return;
          if (!model) throw new Error("Kitten TTS is unavailable");
          const res = await model.call({ cmd: "speak", text: m.text, voice: m.voice, language: m.language, hint: m.hint });
          if (req.cancelled) return;
          const bytes = Buffer.from(String(res.pcm ?? ""), "base64");
          const pcm = new Int16Array(bytes.length / 2);
          for (let i = 0; i < pcm.length; i++) pcm[i] = bytes.readInt16LE(i * 2);
          if (!pcm.length) throw new Error("Kitten couldn't pronounce this text in the selected language");
          send({ t: "audio", id, pcm, rate: res.rate, ms: res.ms });
        } catch (error) {
          if (!req.cancelled) send({ t: "error", id, message: error instanceof Error ? error.message : String(error) });
        } finally { pending.delete(id); }
      });
      break;
    }
    case "cancel": { const req = pending.get(String(m.id)); if (req) req.cancelled = true; break; }
    case "exit": close(); break;
  }
});
process.on("disconnect", close);
send({ t: "hello" });
