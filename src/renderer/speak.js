// Read aloud (V3): the 🔊 button on a reply. Pocket TTS runs on this Mac (runtime/tts); the runtime sends one
// sentence of speech at a time as `tts.event` audio and this module plays them in order with <audio> elements,
// so pause, stop and speed (pitch kept) are instant. The first time, a plain question asks before the 98 MB voice
// is downloaded. One reply speaks at a time; leaving the chat stops it.

import { h } from "./dom.js";
import { icon } from "./icons.js";
import { confirmDialog } from "./dialogs.js";
import { state, toast } from "./store.js";

const SPEEDS = [1, 1.25, 1.5, 1.75];
const S = { phase: "idle", owner: null, session: null, n: 0, playing: -1, pct: 0, speed: 1 };
const listeners = new Set();
const notify = () => { for (const f of listeners) f(); };
export const speaker = { get: () => S, on: (f) => (listeners.add(f), () => listeners.delete(f)) };

let queue = []; // { i, url } waiting to play
let el = null; // the <audio> playing now
let url = null;
let finished = false; // the runtime sent every sentence
let watch = null;
let installWait = null;
let anchor = null; // the message's DOM node, to stop when its chat is hidden

const call = (m, p = {}) => state.client.call(m, p);

function wav(base64) {
  const bin = atob(base64);
  const n = bin.length;
  const buf = new Uint8Array(44 + n);
  const dv = new DataView(buf.buffer);
  const put = (o, str) => { for (let k = 0; k < str.length; k++) buf[o + k] = str.charCodeAt(k); };
  put(0, "RIFF"); dv.setUint32(4, 36 + n, true); put(8, "WAVEfmt "); dv.setUint32(16, 16, true); dv.setUint16(20, 1, true); dv.setUint16(22, 1, true);
  dv.setUint32(24, 24000, true); dv.setUint32(28, 48000, true); dv.setUint16(32, 2, true); dv.setUint16(34, 16, true); put(36, "data"); dv.setUint32(40, n, true);
  for (let k = 0; k < n; k++) buf[44 + k] = bin.charCodeAt(k);
  return URL.createObjectURL(new Blob([buf], { type: "audio/wav" }));
}

function reset(phase = "idle") {
  if (el) { el.onended = null; el.onerror = null; try { el.pause(); } catch { /* gone */ } el = null; }
  if (url) { URL.revokeObjectURL(url); url = null; }
  for (const q of queue) URL.revokeObjectURL(q.url);
  queue = [];
  finished = false;
  clearInterval(watch);
  watch = null;
  Object.assign(S, { phase, owner: phase === "idle" ? null : S.owner, session: phase === "idle" ? null : S.session, n: 0, playing: -1, pct: 0 });
  if (phase === "idle") anchor = null;
  notify();
}

function playNext() {
  if (S.phase === "paused") return;
  if (url) { URL.revokeObjectURL(url); url = null; }
  const next = queue.shift();
  if (!next) {
    el = null;
    if (finished) reset();
    else if (S.phase === "playing") { S.phase = "preparing"; notify(); } // waiting for the next sentence
    return;
  }
  url = next.url;
  el = new Audio(url);
  el.preservesPitch = true;
  el.playbackRate = S.speed;
  el.onended = () => playNext();
  el.onerror = () => { toast("Couldn't play that part."); playNext(); };
  S.playing = next.i;
  S.phase = "playing";
  notify();
  void el.play().catch(() => playNext());
  void call("tts.progress", { session: S.session, played: next.i + 1 }).catch(() => {});
}

window.addEventListener("opscode:tts", (e) => {
  const v = e.detail;
  if (!v) return;
  if (v.ev === "install") {
    if (v.phase === "download") { S.pct = v.progress ?? 0; if (S.phase === "installing") notify(); }
    else if (v.phase === "verify" || v.phase === "extract") { S.pct = 1; S.label = v.phase === "verify" ? "Checking" : "Unpacking"; notify(); }
    else if (v.phase === "done") { installWait?.(true); installWait = null; }
    else if (v.phase === "error") { installWait?.(false, v.message); installWait = null; }
    return;
  }
  if (v.session !== S.session) return;
  switch (v.ev) {
    case "started": S.n = v.n; notify(); break;
    case "audio": {
      queue.push({ i: v.i, url: wav(v.pcm) });
      if (!el && S.phase !== "paused") playNext();
      break;
    }
    case "done": finished = true; if (!el && queue.length === 0) reset(); break;
    case "stopped": reset(); break;
    case "error": toast(v.message || "Reading aloud stopped.", 6000); reset(); break;
  }
});

/** Waits for the download to finish; resolves true when the voice is ready. */
function waitInstall() {
  return new Promise((resolve) => { installWait = (ok, msg) => { if (!ok) toast(`Couldn't get the voice: ${msg ?? "download failed"}`, 8000); resolve(ok); }; });
}

export async function ensureVoice() {
  const st = await call("tts.status");
  if (st.installed) return true;
  if (st.installing) { S.phase = "installing"; notify(); return waitInstall(); }
  const mb = Math.round(st.download_bytes / 1e6);
  const yes = await confirmDialog({
    title: "Download the Pocket TTS voice?",
    body: `Opscode reads replies aloud with Pocket TTS, a small voice that runs on this Mac, so nothing you listen to is sent anywhere. It downloads once from the sherpa-onnx project on GitHub (${mb} MB, about ${Math.round(st.disk_bytes / 1e6)} MB on disk) and is checked before use. Licence: Creative Commons Attribution 4.0, for personal, non-commercial use. You can remove it again in Settings.`,
    confirm: `Download ${mb} MB`,
  });
  if (!yes) return false;
  S.phase = "installing"; S.pct = 0; S.label = "Downloading"; notify();
  const done = waitInstall();
  try {
    const r = await call("tts.install");
    // Already there (installed meanwhile, or by hand): nothing to wait for.
    if (!r.started && (await call("tts.status")).installed) { installWait = null; return true; }
  } catch (e) { installWait = null; toast(e.message); return false; }
  return done;
}

/** Reads a reply aloud. `key` names the reply (its turn), `node` is its element (leaving the chat stops it). */
export async function speakReply(key, markdown, node) {
  if (!markdown.trim()) { toast("There is nothing to read aloud in this reply."); return; }
  if (S.phase !== "idle") await stopSpeaking();
  S.owner = key; S.speed = state.settings?.tts_speed ?? 1; anchor = node ?? null;
  S.phase = "preparing"; notify();
  try {
    if (!(await ensureVoice())) { reset(); return; }
    if (S.owner !== key) return; // the person pressed something else meanwhile
    S.phase = "preparing"; notify();
    const r = await call("tts.speak", { text: markdown });
    S.session = r.session; S.n = r.sentences;
    // Leaving the chat (its message is no longer on screen) stops the voice.
    clearInterval(watch);
    watch = setInterval(() => { if (anchor && (!anchor.isConnected || !anchor.offsetParent)) void stopSpeaking(); }, 700);
    notify();
  } catch (e) {
    toast(e.message);
    reset();
  }
}

export async function stopSpeaking() {
  const s = S.session;
  reset();
  if (s) await call("tts.stop", { session: s }).catch(() => {});
}

export function pauseResume() {
  if (S.phase === "playing") { S.phase = "paused"; el?.pause(); notify(); }
  else if (S.phase === "paused") {
    S.phase = "playing"; notify();
    if (el) void el.play().catch(() => {}); else playNext();
  }
}

export function cycleSpeed() {
  const i = SPEEDS.indexOf(S.speed);
  S.speed = SPEEDS[(i + 1) % SPEEDS.length];
  if (el) el.playbackRate = S.speed;
  void call("settings.set", { patch: { tts_speed: S.speed } }).catch(() => {});
  notify();
}

/** The buttons for one reply: 🔊 when idle; while it speaks: pause/resume, stop and the speed. */
export function createSpeakControls(get) {
  const root = h("span", { class: "msg-speak" });
  const main = h("button", { class: "icon-btn", type: "button" });
  const stop = h("button", { class: "icon-btn", type: "button", title: "Stop reading", "aria-label": "Stop reading", onclick: () => void stopSpeaking() }, icon("stop"));
  const speed = h("button", { class: "icon-btn msg-speed", type: "button", title: "Reading speed", "aria-label": "Reading speed", onclick: () => cycleSpeed() });
  root.append(main, stop, speed);
  main.addEventListener("click", () => {
    const mine = S.owner === get().key && S.phase !== "idle";
    if (!mine) { const g = get(); void speakReply(g.key, g.text(), g.node); }
    else if (S.phase === "playing" || S.phase === "paused") pauseResume();
    else void stopSpeaking(); // preparing or installing: a click cancels
  });
  const sync = () => {
    const mine = S.owner === get().key && S.phase !== "idle";
    const msg = root.closest(".msg-actions");
    if (msg) msg.dataset.speaking = mine ? "true" : "false";
    stop.hidden = speed.hidden = !mine;
    main.dataset.phase = mine ? S.phase : "idle";
    let label = "Read aloud (Pocket TTS)";
    let glyph = icon("volume");
    if (mine && S.phase === "playing") { label = "Pause"; glyph = icon("pause"); }
    else if (mine && S.phase === "paused") { label = "Resume"; glyph = icon("play"); }
    else if (mine && S.phase === "installing") label = `${S.label ?? "Downloading"} the voice… ${Math.round((S.pct ?? 0) * 100)}% (click to cancel)`;
    else if (mine && S.phase === "preparing") label = "Getting the voice ready… (click to cancel)";
    main.title = label;
    main.setAttribute("aria-label", label);
    main.replaceChildren(glyph, ...(mine && S.phase === "installing" ? [h("span", { class: "msg-speak-pct" }, `${Math.round((S.pct ?? 0) * 100)}%`)] : []));
    speed.textContent = `${S.speed}×`;
  };
  // Stops listening once its reply has been removed from the page (a deleted chat).
  let seen = false;
  let off = () => {};
  const guarded = () => { if (root.isConnected) seen = true; else if (seen) { off(); return; } sync(); };
  off = speaker.on(guarded);
  sync();
  return root;
}
