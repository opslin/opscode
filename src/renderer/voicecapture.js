// The microphone for voice mode. Chromium captures it with its own echo canceller, noise suppression and gain control
// (the agent's voice plays in this same window, so it knows what to remove), and an AudioWorklet cuts it into
// 100 ms chunks of 16 kHz mono Int16. The caller sends them to the runtime.

const b64 = (bytes) => {
  let s = "";
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  return btoa(s);
};

const WIN = /win/i.test(navigator.platform) && !/darwin/i.test(navigator.platform);

/** The microphone failed to open: say why in words. */
export function micMessage(e) {
  const n = e?.name ?? "";
  if (n === "NotAllowedError" || n === "SecurityError") return WIN ? "Windows is blocking the microphone for Opscode. Open Settings → Privacy & security → Microphone, turn on “Microphone access” and “Let desktop apps access your microphone”, then try again." : "Opscode may not use the microphone. Allow it in System Settings → Privacy & Security → Microphone, then try again.";
  if (n === "NotFoundError" || n === "OverconstrainedError") return WIN ? "No microphone was found. Plug one in, or check Settings → System → Sound → Input." : "No microphone was found on this Mac.";
  if (n === "NotReadableError") return "The microphone is busy in another app.";
  return `The microphone could not start: ${e?.message ?? n ?? "unknown error"}`;
}

/** Starts capturing. onChunk(base64), onLevel(0..1). Returns { stop(), setMuted(bool) }. Throws if the microphone cannot open. */
export async function startCapture({ onChunk, onLevel }) {
  const stream = await navigator.mediaDevices.getUserMedia({ audio: { channelCount: 1, echoCancellation: true, noiseSuppression: true, autoGainControl: true } });
  let ctx;
  try { ctx = new AudioContext({ sampleRate: 16000, latencyHint: "interactive" }); } catch { ctx = new AudioContext({ latencyHint: "interactive" }); }
  try {
    await ctx.audioWorklet.addModule("./voice-worklet.js");
    const src = ctx.createMediaStreamSource(stream);
    const node = new AudioWorkletNode(ctx, "opscode-chunker", { numberOfInputs: 1, numberOfOutputs: 1, outputChannelCount: [1] });
    node.port.onmessage = (e) => {
      const { pcm, rms } = e.data ?? {};
      if (!pcm) return;
      onLevel?.(Math.min(1, rms * 5));
      onChunk(b64(new Uint8Array(pcm)));
    };
    // The node must be pulled to run: route it through a silent gain to the output.
    const mute = ctx.createGain();
    mute.gain.value = 0;
    src.connect(node);
    node.connect(mute);
    mute.connect(ctx.destination);
    if (ctx.state === "suspended") await ctx.resume();
    return {
      setMuted: (m) => node.port.postMessage({ mute: !!m }),
      stop: () => {
        try { node.port.onmessage = null; src.disconnect(); node.disconnect(); } catch { /* gone */ }
        for (const t of stream.getTracks()) t.stop();
        void ctx.close().catch(() => {});
      },
    };
  } catch (e) {
    for (const t of stream.getTracks()) t.stop();
    void ctx.close().catch(() => {});
    throw e;
  }
}
