// The composer's mic button (V1): speak, and the words appear in the message box as you talk.
// The window captures the microphone for local Whisper transcription through the runtime.
//   click / ⌥Space  start or stop      Esc  cancel (puts the box back)      Enter while listening  stop and send
//   voice note (+ menu): the same, and the recording is kept: saved in the project and attached to the message.

import { h, isMicChord } from "./dom.js";
import { icon } from "./icons.js";
import { state, toast } from "./store.js";
import { ensureSpeechModel } from "./speechmodel.js";
import { startCapture, micMessage } from "./voicecapture.js";

let statusP = null;
/** Is voice input possible here (local runtime available)? Asked once. */
export function voiceStatus(refresh = false) {
  if (!statusP || refresh) statusP = state.client?.call("voice.status", {}).catch(() => ({ helper: false, available: false })) ?? Promise.resolve({ helper: false, available: false });
  return statusP;
}

const MESSAGES = {
  mic_denied: "Opscode may not use the microphone. Allow it in System Settings → Privacy & Security → Microphone, then try again.",
  locale: "On-device speech recognition does not support this language. Pick another one in Settings → General → Voice → Microphone language.",
};

/**
 * opts: { textarea, workspace, isVisible(), onText() (box changed), onSend() (Enter while listening), onNote(absPath) (a voice note's recording) }
 * Returns { el, listening(), toggle(), note(), stop(send), cancel() }.
 */
export function createMic(opts) {
  const { textarea } = opts;
  const lvl = h("span", { class: "mic-level", "aria-hidden": "true" });
  const el = h("button", { class: "cmp-icon cmp-mic", type: "button", "aria-label": "Dictate (⌥Space)", title: "Dictate (⌥Space). Speech becomes text on this computer.", dataset: { state: "idle" } }, lvl, icon("mic"));
  // A voice note shows the time it has been recording next to the mic.
  const timer = h("span", { class: "mic-timer", hidden: true, "aria-live": "off" });
  let tick = null;
  let noteMode = false;
  const clock = (since) => { const s = Math.floor((Date.now() - since) / 1000); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`; };
  const stopClock = () => { clearInterval(tick); tick = null; timer.hidden = true; };
  let session = null;
  let cap = null;
  let inflight = 0;
  const stopCapture = () => { try { cap?.stop(); } catch { /* gone */ } cap = null; };
  let phase = "idle"; // idle | starting | listening | finishing
  let base = "";
  let committed = "";
  let sendAfter = false;

  const set = (p, title) => {
    phase = p;
    el.dataset.state = p;
    el.setAttribute("aria-pressed", String(p !== "idle"));
    if (title) el.title = title;
    else el.title = p === "idle" ? "Dictate (⌥Space). Speech becomes text on this computer." : p === "listening" ? "Listening… click to stop (Esc cancels)" : "Working…";
    if (p === "idle") { el.style.removeProperty("--lvl"); stopClock(); noteMode = false; }
  };
  const write = (text) => {
    textarea.value = base + text;
    textarea.selectionStart = textarea.selectionEnd = textarea.value.length;
    opts.onText?.();
  };

  async function start(note = false) {
    if (phase !== "idle") return;
    base = textarea.value && !/\s$/.test(textarea.value) ? `${textarea.value} ` : textarea.value;
    committed = "";
    sendAfter = false;
    set("starting", "Getting the microphone ready…");
    noteMode = note;
    try {
      if (!(await ensureSpeechModel()) || phase !== "starting") { if (!session) set("idle"); return; }
      const st = await voiceStatus(true);
      if (phase !== "starting") return;
      const r = await state.client.call("voice.start", { workspace_id: opts.workspace?.id, ...(note ? { note: true } : {}) });
      session = r.session;
      if (phase !== "starting") { void state.client.call("voice.stop", { cancel: true }).catch(() => {}); return; }
      if (st.capture === "window") {
        // The window listens (echo cancelling and noise suppression are Chromium's) and sends 100 ms chunks.
        const mine = r.session;
        try {
          const opened = await startCapture({
            onChunk: (pcm) => { if (session !== mine || inflight > 12) return; inflight++; state.client.call("voice.audio", { session: mine, pcm }).catch(() => {}).finally(() => { inflight--; }); },
            onLevel: () => {},
          });
          if (session === mine && (phase === "starting" || phase === "listening")) cap = opened;
          else opened.stop();
        } catch (e) {
          toast(micMessage(e), 8000);
          void state.client.call("voice.stop", { cancel: true }).catch(() => {});
        }
      }
    } catch (e) {
      set("idle");
      toast(e.message);
    }
  }

  function stop(send = false) {
    if (phase === "idle") return;
    if (!session) { set("idle"); return; }
    sendAfter = send;
    stopCapture(); // no more audio; the helper finishes what it has heard
    set("finishing");
    void state.client.call("voice.stop", {}).catch(() => {});
  }

  function cancel() {
    if (phase === "idle") return;
    if (!session) { set("idle"); return; }
    sendAfter = false;
    stopCapture();
    void state.client.call("voice.stop", { cancel: true }).catch(() => {});
  }

  window.addEventListener("opscode:voice", (e) => {
    const v = e.detail;
    if (!v || v.session !== session) return;
    switch (v.ev) {
      case "asset": set(phase === "idle" ? "starting" : phase, `Getting the speech model… ${Math.round((v.progress ?? 0) * 100)}%`); break;
      case "started":
        set("listening", noteMode ? "Recording a voice note… click to stop (Esc cancels)" : undefined);
        if (noteMode) { const since = Date.now(); timer.hidden = false; timer.textContent = "0:00"; tick = setInterval(() => { timer.textContent = clock(since); }, 500); }
        break;
      case "level": el.style.setProperty("--lvl", String(Math.max(0, Math.min(1, v.rms ?? 0)))); break;
      case "partial": write(committed + (committed && v.text ? " " : "") + (v.text ?? "")); break;
      case "final": committed = v.full ?? committed; write(committed); break;
      case "done": {
        session = null;
        stopCapture();
        set("idle");
        const text = (v.text ?? committed).trim();
        write(text);
        textarea.focus();
        // A voice note: the recording is attached to the message (sending waits until it is attached).
        const attached = v.file ? Promise.resolve(opts.onNote?.(v.file)).catch(() => {}) : Promise.resolve();
        if (!text && !base.trim()) toast("Didn't catch anything. Try again a little closer to the microphone.");
        else if (sendAfter) void attached.then(() => opts.onSend?.());
        break;
      }
      case "cancelled":
        session = null;
        stopCapture();
        set("idle");
        textarea.value = base.trimEnd() === base ? base : base.trimEnd();
        opts.onText?.();
        textarea.focus();
        break;
      case "error":
        if (["mic_denied", "locale", "asset", "audio", "unavailable", "busy", "helper_exit"].includes(v.code)) {
          session = null;
          stopCapture();
          set("idle");
          if (!committed) { textarea.value = base.trimEnd(); opts.onText?.(); }
        }
        toast(MESSAGES[v.code] ?? v.message ?? "Voice input stopped.", 6000);
        if (v.code === "mic_denied") void voiceStatus(true);
        break;
    }
  });

  el.addEventListener("click", () => (phase === "idle" ? void start() : phase === "listening" || phase === "starting" ? stop() : undefined));
  // ⌥Space toggles in the chat on screen; Esc cancels while listening.
  document.addEventListener("keydown", (e) => {
    if (!opts.isVisible()) return;
    if (isMicChord(e)) { e.preventDefault(); phase === "idle" ? void start() : stop(); }
    else if (e.key === "Escape" && phase !== "idle") { e.preventDefault(); e.stopPropagation(); cancel(); }
  }, true);
  // Hidden when this Mac cannot do it.
  void voiceStatus().then((s) => { el.hidden = !(s.helper && s.available); });

  return { el, timer, listening: () => phase !== "idle", toggle: () => (phase === "idle" ? void start() : stop()), note: () => void start(true), stop, cancel };
}
