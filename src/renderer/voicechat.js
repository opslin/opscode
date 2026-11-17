// Voice mode in a Normal chat (docs/voice-mode-plan.md). Click the big microphone and the message box dissolves into
// pixels; what is left is the orb, the account and model chips, + and the project chips. You talk, a front agent answers
// out loud and briefs the worker (the chat's own engine); files added with + go out with what you say next.
//
//   window mic (echo-cancelled) --voiceagent.audio--> runtime --> helper (on-device recognizer) --> front agent
//   front agent's words --tts.event (audio)--> this window plays them (voiceplayer.js); speaking over it cuts it off
//
// Controls: click the orb = mute / unmute (while it talks: cut it off) · Esc = end · ⌥Space = mute / unmute.

import { h, isMicChord } from "./dom.js";
import { icon } from "./icons.js";
import { state, toast } from "./store.js";
import { createOrb } from "./orb.js";
import { createVoiceBot } from "./voicebot.js";
import { startCapture, micMessage } from "./voicecapture.js";
import { createVoicePlayer } from "./voiceplayer.js";
import { ensureVoice } from "./speak.js";
import { pixelBurst, pixelReveal, pixelVanish } from "./pixelfx.js";
import { openModelPicker, engineMark, modelName, catalog } from "./modelpicker.js";

const reduced = () => window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
const wait = (ms) => new Promise((r) => setTimeout(r, reduced() ? 0 : ms));
const clip = (t, n) => (t.length > n ? `${t.slice(0, n - 1)}…` : t);
// Every engine can be the model you talk to (it only converses, searches and briefs; the worker does the coding).
const BRAIN_ENGINES = ["claude-code", "codex", "antigravity", "qoder", "api"];
// The Pocket TTS voices that come with the model (runtime/tts VOICES).
const VOICES = [
  { id: "bria", name: "Bria", note: "Warm, clear", sample: "Hi, I'm Bria. Tell me what you want built, and I'll brief the worker and keep you posted." },
  { id: "loona", name: "Loona", note: "Soft, bright", sample: "Hey, I'm Loona. Just say what you need, and I'll get the worker started on it." },
];

let statusP = null;
/** Can this computer do voice mode (a speech helper; on a Mac, Apple's recognizer)? */
export function voiceModeAvailable(refresh = false) {
  if (!state.client) return Promise.resolve(false); // not connected yet: ask again later, do not remember "no"
  if (!statusP || refresh) {
    statusP = state.client.call("voiceagent.status", {}).then((s) => !!(s.helper && s.available));
    statusP.then((ok) => { if (!ok) statusP = null; }, () => { statusP = null; }); // only a "yes" is remembered
  }
  return statusP.catch(() => false);
}

/**
 * o: { workspace, root, composerBox, textarea, attach, talkBtn,
 *      getChatId(), bindChat(id), getWorker() -> {engine, model, effort, account_id, mode}, showWorker(), onActive(bool) }
 * Returns { el (the stage), chip (the voice model button), voiceChip (how it sounds), enter(), leave(), active(), toggleMute(), attachChanged() }.
 */
export function createVoiceMode(o) {
  const call = (m, p = {}) => state.client.call(m, p);
  let session = null;
  let phase = "off"; // off | entering | on | leaving
  let cap = null;
  let muted = false;
  let micLevel = 0;
  let agent = "starting";
  let inflight = 0;
  const workers = new Map(); // id -> { info, el }
  let tick = null;
  let noticeTimer = null;
  const sentFiles = new Set();

  let previewing = false; // a voice sample is playing: the mic is not sent, so the agent does not hear it
  let previewEnd = null;
  const player = createVoicePlayer({
    onPlaying: (p) => {
      if (session && !previewing) void call("voiceagent.playback", { session, playing: p }).catch(() => {});
      if (!p && previewing) { clearTimeout(previewEnd); previewEnd = setTimeout(() => { previewing = false; panel?.sync(); }, 500); }
      paint();
    },
    tone: () => tone(),
  });
  const orb = createOrb();
  orb.levelFrom(() => (player.playing && agent !== "hearing" ? player.level() : muted ? 0 : micLevel));

  // ---- the stage ---------------------------------------------------------------------------------------------------------
  const userLine = h("p", { class: "vox-line vox-user" });
  const agentLine = h("p", { class: "vox-line vox-agent" });
  const notice = h("p", { class: "vox-notice", hidden: true, role: "status" });
  const statusText = h("span", { class: "vox-status-text" }, "Getting ready…");
  const orbBtn = h("button", { class: "vox-orb", type: "button", "aria-label": "Mute the microphone", "aria-pressed": "false", title: "Click to mute. While it talks, click to cut it off." }, orb.el);
  // Workers: a box each, left and right of the orb (w1 left, w2 right, …).
  const colL = h("div", { class: "vox-col vox-col-l", "aria-label": "Workers" });
  const colR = h("div", { class: "vox-col vox-col-r", "aria-label": "Workers" });
  // The live browser screen: what the agent sees in the Browser tab, while it browses (top of the right column).
  const scrHost = h("span", { class: "vs-host" }, "Browser");
  const scrImg = h("img", { class: "vs-img", alt: "", draggable: "false" });
  const scrCap = h("span", { class: "vs-cap" });
  const screen = h("div", { class: "vox-screen", hidden: true, role: "img", "aria-label": "Live view of the voice agent's browser", title: "The voice agent is using the Browser itself (no worker). Live view of the Browser tab." },
    h("div", { class: "vs-chrome" },
      h("span", { class: "vs-dots", "aria-hidden": "true" }, h("i"), h("i"), h("i")),
      h("span", { class: "vs-addr" }, icon("browser", "icon vs-globe"), scrHost),
      h("span", { class: "vs-live" }, h("i"), "Live")),
    h("div", { class: "vs-view" },
      h("div", { class: "vs-skel", "aria-hidden": "true" }, h("i"), h("i"), h("i"), h("i"), h("i")),
      scrImg,
      h("span", { class: "vs-scan", "aria-hidden": "true" }),
      scrCap));
  colR.append(screen);
  const el = h("div", { class: "vox", hidden: true, role: "region", "aria-label": "Voice mode" },
    colL, colR,
    h("div", { class: "vox-center" },
      h("div", { class: "vox-lines", "aria-live": "polite" }, userLine, agentLine),
      orbBtn,
      h("div", { class: "vox-status" }, h("span", { class: "vox-dot" }), statusText),
      notice));
  const bot = createVoiceBot(el);
  bot.setHome(() => {
    const v = el.getBoundingClientRect(), r = orbBtn.getBoundingClientRect();
    return { x: r.left - v.left - 52, y: r.bottom - v.top - 92 };
  });

  const SAY = { starting: "Getting ready…", listening: "Listening", hearing: "Hearing you", thinking: "Thinking…", speaking: "Speaking · talk to interrupt", muted: "Muted · click the orb to unmute" };
  function shown() { return muted ? "muted" : player.playing && agent !== "hearing" ? "speaking" : agent; }
  function paint() {
    const s = shown();
    el.dataset.state = s;
    orb.set(s === "muted" ? agent : s);
    orb.setMuted(muted);
    statusText.textContent = SAY[s] ?? s;
    orbBtn.setAttribute("aria-pressed", String(muted));
    orbBtn.setAttribute("aria-label", muted ? "Unmute the microphone" : player.playing ? "Cut it off" : "Mute the microphone");
    bot.setMood(s);
  }

  function flash(text, ms = 2600) {
    notice.hidden = false;
    notice.textContent = text;
    clearTimeout(noticeTimer);
    if (ms) noticeTimer = setTimeout(() => { notice.hidden = true; }, ms);
  }

  const since = (ms) => { const secs = Math.max(0, Math.round(ms / 1000)); return secs >= 3600 ? `${Math.floor(secs / 3600)}h ${Math.floor((secs % 3600) / 60)}m` : secs >= 60 ? `${Math.floor(secs / 60)}m ${String(secs % 60).padStart(2, "0")}s` : `${secs}s`; };
  const STATE_WORD = { running: "Working", waiting: "Needs your OK", complete: "Done", failed: "Failed", interrupted: "Stopped" };
  /** One worker's card: pixel status icon, title, time, what it is doing, a progress line, and an approval panel. */
  function paintCard(w) {
    const rec = workers.get(w.id);
    if (!rec) return;
    const st = w.waiting ? "waiting" : w.status === "none" ? "running" : w.status;
    if (rec.status === "running" && st === "complete") bot.cheer();
    rec.status = st;
    const now = st === "waiting" ? "Waiting for your answer" : st === "running" ? (w.current ? clip(w.current, 80) : "Thinking it through…") : st === "complete" ? "Finished" : st === "failed" ? "Stopped with an error" : "Stopped";
    const time = st === "running" || st === "waiting" ? (w.started_at ? since(Date.now() - w.started_at) : "") : w.started_at && w.ended_at ? since(w.ended_at - w.started_at) : "";
    rec.el.dataset.status = st;
    rec.title.textContent = w.title;
    rec.title.title = `${w.title}${w.view ? " · this chat" : " · its own chat in the sidebar"}`;
    rec.time.textContent = time;
    rec.now.textContent = now;
    rec.state.textContent = STATE_WORD[st] ?? st;
    rec.files.textContent = w.files ? `${w.files} file${w.files === 1 ? "" : "s"}` : "";
    rec.files.hidden = !w.files;
    rec.model.replaceChildren(...[engineMark(w.engine ?? "api", "icon em"), h("span", {}, modelName({ engine: w.engine ?? "api", model: w.model }))].filter(Boolean));
    const ask = st === "waiting" ? w.ask : null;
    rec.ask.hidden = !ask;
    if (ask) {
      rec.askWhat.textContent = ask.summary ?? "Approve a step";
      rec.askDetail.textContent = ask.detail ?? "";
      rec.askDetail.hidden = !ask.detail;
      rec.callId = ask.call_id;
    }
  }
  function paintWorkers() { for (const r of workers.values()) paintCard(r.info); }
  function answer(id, allow) {
    const rec = workers.get(id);
    if (!rec?.callId || !session) return;
    rec.el.dataset.answered = allow ? "allow" : "deny";
    void call("voiceagent.approve", { session, call_id: rec.callId, allow }).catch((e) => toast(e.message));
  }
  function upsertWorker(w) {
    let rec = workers.get(w.id);
    const fresh = !rec;
    if (!rec) {
      const title = h("span", { class: "vw-title" });
      const time = h("span", { class: "vw-time" });
      const now = h("span", { class: "vw-now" });
      const state = h("span", { class: "vw-chip vw-state" });
      const files = h("span", { class: "vw-chip vw-files", hidden: true });
      const model = h("span", { class: "vw-model", title: "The worker's model: it does the coding" });
      const askWhat = h("div", { class: "vw-ask-what" });
      const askDetail = h("div", { class: "vw-ask-detail", hidden: true });
      const ask = h("div", { class: "vw-ask", hidden: true },
        h("div", { class: "vw-ask-label" }, "Wants to"),
        askWhat, askDetail,
        h("div", { class: "vw-ask-row" },
          h("span", { class: "vw-say", title: "Say yes or no" }, icon("mic", "icon"), "Say yes / no"),
          h("button", { class: "vw-deny", type: "button", onclick: (e) => { e.stopPropagation(); answer(w.id, false); } }, "Deny"),
          h("button", { class: "vw-allow", type: "button", onclick: (e) => { e.stopPropagation(); answer(w.id, true); } }, "Allow")));
      const open = () => { const cur = workers.get(w.id)?.info; if (cur?.view) o.showWorker?.(); else flash(`“${cur?.title ?? "That work"}” has its own chat in the sidebar.`); };
      const card = h("div", { class: "vw-card", role: "group", tabindex: "0", "aria-label": `Worker: ${w.title}`, dataset: { worker: w.id }, onclick: open, onkeydown: (e) => { if (e.key === "Enter" && e.target === card) open(); } },
        h("div", { class: "vw-top" },
          h("span", { class: "vw-icon", "aria-hidden": "true" }, ...Array.from({ length: 9 }, (_, i) => h("i", { style: `--i:${i}` }))),
          title, time),
        now,
        h("span", { class: "vw-track", "aria-hidden": "true" }, h("i")),
        h("div", { class: "vw-foot" }, state, files, model),
        ask);
      rec = { info: w, el: card, title, time, now, state, files, model, ask, askWhat, askDetail, callId: null, status: null };
      workers.set(w.id, rec);
      const n = workers.size;
      const col = n % 2 === 1 ? colL : colR;
      const first = col.querySelector(".vw-card");
      if (first) col.insertBefore(card, first); else col.append(card);
      // At most three cards a side: the oldest make room.
      for (const c of [colL, colR]) for (const old of [...c.querySelectorAll(".vw-card")].slice(3)) old.remove();
    }
    rec.info = w;
    if (!w.waiting) delete rec.el.dataset.answered;
    paintCard(w);
    if (fresh) {
      rec.el.classList.add("vw-new");
      requestAnimationFrame(() => pixelReveal(rec.el, { cell: 6, ms: 560 }));
      setTimeout(() => rec.el.classList.remove("vw-new"), 800);
    }
  }
  // ---- the live browser screen: a small picture of the Browser tab, a few times a second while the agent browses ----
  let screenTimer = null, framing = false, screenOpen = false;
  async function pullFrame() {
    if (framing || !screenOpen) return;
    framing = true;
    try {
      const t = await o.browserWcId?.();
      const f = t?.id != null ? await window.opscode?.browserHost?.frame?.(t.id, 640, t.rect ?? null) : null;
      if (f && screenOpen) {
        if (scrImg.src !== f.image) scrImg.src = f.image;
        screen.dataset.has = "true";
        try { scrHost.textContent = new URL(f.url).host.replace(/^www\./, "") || f.title || "Browser"; } catch { scrHost.textContent = f.title || "Browser"; }
      }
    } catch { /* the tab went away */ } finally { framing = false; }
  }
  function openScreen(caption) {
    clearTimeout(screenTimer);
    if (caption != null) { scrCap.textContent = caption; scrCap.hidden = !caption; }
    screen.classList.add("vs-busy");
    if (!screenOpen) {
      screenOpen = true;
      screen.hidden = false;
      delete screen.dataset.has;
      requestAnimationFrame(() => pixelReveal(screen, { cell: 6, ms: 480 }));
      const tick = () => { if (!screenOpen) return; void pullFrame(); screenTimer = setTimeout(tick, 650); };
      tick();
    }
  }
  function closeScreenSoon() {
    screen.classList.remove("vs-busy");
    scrCap.textContent = "";
    setTimeout(() => {
      if (screen.classList.contains("vs-busy")) return;
      screenOpen = false;
      clearTimeout(screenTimer);
      screen.hidden = true;
    }, 6000);
  }
  /** The robot acts out what the agent does. */
  function act(v) {
    if (phase !== "on" && phase !== "entering") return;
    const cardOf = (id) => workers.get(id)?.el;
    switch (v.kind) {
      case "start": setTimeout(() => void bot.deliver(cardOf(v.worker)), 120); break; // the box appears with the worker event
      case "visit": void bot.visit(cardOf(v.worker)); break;
      case "peek": void bot.peek(); break;
      case "browse": {
        const t = String(v.tool ?? "");
        const cap = { browser_search: `Searching “${clip(v.what ?? "", 40)}”`, browser_navigate: `Opening ${v.what || "a page"}`, browser_read: "Reading the page", browser_find: "Looking for something", browser_act: "Clicking and typing", browser_batch: "Working on the page", browser_screenshot: "Taking a look", browser_tabs: "Switching tabs" }[t] ?? "Browsing";
        openScreen(cap);
        void bot.browse(screen, t === "browser_search" || t === "browser_navigate" || t === "browser_tabs" ? "enter" : t === "browser_act" || t === "browser_batch" ? "tap" : t === "browser_screenshot" ? "look" : "scroll");
        break;
      }
      case "home": if (screenOpen) closeScreenSoon(); void bot.home(); break;
    }
  }

  function setMuted(m) {
    muted = !!m;
    cap?.setMuted(muted);
    paint();
  }

  orbBtn.addEventListener("click", () => {
    if (phase !== "on" || !session) return;
    if (muted) { setMuted(false); return; } // muted: a click always unmutes first
    if (player.playing) { player.stop(); void call("voiceagent.interrupt", { session }).catch(() => {}); return; }
    setMuted(true);
  });

  // ---- the voice model chip ------------------------------------------------------------------------------------------------
  function brainValue() {
    const s = state.settings ?? {};
    if (s.voice_brain_engine) return { engine: s.voice_brain_engine, ...(s.voice_brain_model ? { model: s.voice_brain_model } : {}), ...(s.voice_brain_effort ? { effort: s.voice_brain_effort } : {}) };
    // Not chosen yet: a fast, cheap model (talking needs speed, not depth): Claude Haiku when Claude Code is here,
    // else a fast model of the worker's engine, else the active API model, else the worker's own engine.
    const w = o.getWorker();
    const cat = catalog();
    const fast = (engine) => cat.find((m) => m.engine === engine && /haiku|flash|mini|luna|fast/i.test(`${m.id} ${m.label}`));
    const cc = fast("claude-code");
    if (cc) return { engine: "claude-code", model: cc.id };
    const mine = fast(w.engine);
    if (mine) return { engine: w.engine, model: mine.id };
    if ((state.providers ?? []).some((p) => p.active)) return { engine: "api" };
    if (BRAIN_ENGINES.includes(w.engine)) return { engine: w.engine, ...(w.model ? { model: w.model } : {}) };
    return { engine: "claude-code" };
  }
  const chip = h("button", { class: "cmp-voice-model", type: "button", "aria-label": "Voice agent model", title: "VOICE: the model you talk to. It answers, searches the web in the Browser and briefs the worker. Pick a fast one." });
  function paintChip() {
    const v = brainValue();
    chip.replaceChildren(h("span", { class: "cmp-role" }, "Voice"), engineMark(v.engine, "icon em"), h("span", { class: "cmp-model-name" }, modelName({ engine: v.engine, model: v.model })), icon("chevron-down", "icon chip-caret"));
  }
  function pickBrain() {
    openModelPicker(chip, {
      value: brainValue(),
      engines: BRAIN_ENGINES,
      onChange: (v) => {
        const patch = { voice_brain_engine: v.engine, voice_brain_model: v.engine === "api" ? "" : v.model ?? "", voice_brain_effort: v.effort ?? "" };
        if (v.engine === "api" && v.provider) void call("provider.select", { id: v.provider }).catch((e) => toast(e.message));
        void call("settings.set", { patch }).then(() => { Object.assign(state.settings ?? {}, patch); paintChip(); if (session) toast("The new voice model is used the next time you start voice mode."); }).catch((e) => toast(e.message));
      },
    });
  }
  chip.addEventListener("click", pickBrain);
  // (painted by the chat once its engine is known: repaintChip())

  // ---- the agent's voice: which Pocket TTS voice, speed and pitch (settings voice_tts_*) ---------------------------------------------
  const tone = () => { const s = state.settings ?? {}; return { speed: s.voice_tts_speed ?? 1, pitch: s.voice_tts_pitch ?? 0 }; };
  const voiceId = () => { const s = state.settings ?? {}; return s.voice_tts_voice || s.tts_voice || VOICES[0].id; };
  const voiceChip = h("button", { class: "cmp-voice-tts", type: "button", "aria-label": "Agent voice", "aria-haspopup": "dialog", "aria-expanded": "false", title: "How the agent sounds: voice, speed and pitch" });
  function paintVoiceChip() {
    const v = VOICES.find((x) => x.id === voiceId()) ?? VOICES[0];
    const t = tone();
    const tuned = Math.abs(t.speed - 1) > 0.001 || Math.abs(t.pitch) > 0.001;
    voiceChip.replaceChildren(...[h("span", { class: "vtc-bars", "aria-hidden": "true" }, h("i"), h("i"), h("i"), h("i")), h("span", { class: "cmp-model-name" }, v.name), tuned ? h("span", { class: "vtc-tuned", title: "Speed or pitch changed" }) : null, icon("chevron-down", "icon chip-caret")].filter(Boolean));
  }
  let saveTimer = null;
  const pending = {};
  function saveVoice(patch) {
    Object.assign(state.settings ?? (state.settings = {}), patch);
    Object.assign(pending, patch);
    paintVoiceChip();
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      const p = { ...pending };
      for (const k of Object.keys(pending)) delete pending[k];
      void call("settings.set", { patch: p }).catch((e) => toast(e.message));
    }, 250);
  }
  async function preview(id = voiceId()) {
    if (!session) return;
    const v = VOICES.find((x) => x.id === id) ?? VOICES[0];
    if (agent === "thinking") { flash("Try the voice when it has finished answering."); return; }
    if (player.playing && !previewing) { void call("voiceagent.interrupt", { session }).catch(() => {}); }
    previewing = true;
    clearTimeout(previewEnd);
    panel?.sync();
    try {
      const r = await call("tts.speak", { text: v.sample, voice: v.id });
      player.open(r.session);
    } catch (e) { previewing = false; panel?.sync(); toast(e.message); }
  }
  function stopPreview() { if (!previewing) return; player.stop(); void call("tts.stop", {}).catch(() => {}); previewing = false; panel?.sync(); }

  let panel = null;
  function openPanel() {
    if (panel) { panel.close(); return; }
    const row = (label, out, input, lo, hi) => h("div", { class: "vtone-row" },
      h("div", { class: "vtone-row-head" }, h("span", { class: "vtone-label" }, label), out),
      input,
      h("div", { class: "vtone-ends" }, h("span", {}, lo), h("span", {}, hi)));
    const speedOut = h("output", { class: "vtone-val" });
    const pitchOut = h("output", { class: "vtone-val" });
    const speed = h("input", { type: "range", min: "0.8", max: "1.4", step: "0.05", class: "vtone-range", "aria-label": "Speed" });
    const pitch = h("input", { type: "range", min: "-4", max: "4", step: "0.5", class: "vtone-range", "aria-label": "Pitch" });
    const cards = VOICES.map((v) => {
      const play = h("span", { class: "vtone-play", "aria-hidden": "true" }, icon("play"));
      const b = h("button", { class: "vtone-voice", type: "button", role: "radio", dataset: { voice: v.id }, onclick: () => { saveVoice({ voice_tts_voice: v.id }); sync(); void preview(v.id); } },
        h("span", { class: "vtone-ava", "aria-hidden": "true" }, ...Array.from({ length: 5 }, () => h("i"))),
        h("span", { class: "vtone-vtext" }, h("span", { class: "vtone-vname" }, v.name), h("span", { class: "vtone-vnote" }, v.note)),
        play);
      return b;
    });
    const sampleBtn = h("button", { class: "vtone-sample", type: "button", onclick: () => (previewing ? stopPreview() : void preview()) });
    const reset = h("button", { class: "vtone-reset", type: "button", onclick: () => { saveVoice({ voice_tts_speed: 1, voice_tts_pitch: 0 }); sync(); } }, "Reset");
    const el = h("div", { class: "vtone", role: "dialog", "aria-label": "Agent voice" },
      h("div", { class: "vtone-head" }, h("span", { class: "vtone-title" }, "Agent voice"), h("span", { class: "vtone-sub" }, "Pocket TTS · on this Mac")),
      h("div", { class: "vtone-voices", role: "radiogroup", "aria-label": "Voice" }, ...cards),
      row("Speed", speedOut, speed, "Slower", "Faster"),
      row("Pitch", pitchOut, pitch, "Deeper", "Higher"),
      h("div", { class: "vtone-foot" }, reset, sampleBtn));
    const fmtPitch = (p) => (p === 0 ? "Natural" : `${p > 0 ? "+" : "−"}${Math.abs(p)} st`);
    function sync() {
      const t = tone();
      const id = voiceId();
      speed.value = String(t.speed);
      pitch.value = String(t.pitch);
      speedOut.textContent = `${Number(t.speed).toFixed(2)}×`;
      pitchOut.textContent = fmtPitch(Number(t.pitch));
      for (const c of cards) c.setAttribute("aria-checked", String(c.dataset.voice === id));
      el.dataset.previewing = String(previewing);
      sampleBtn.replaceChildren(icon(previewing ? "stop" : "play"), h("span", {}, previewing ? "Stop" : "Play a sample"));
      reset.disabled = Math.abs(t.speed - 1) < 0.001 && Math.abs(t.pitch) < 0.001;
      for (const r of [speed, pitch]) r.style.setProperty("--fill", `${((Number(r.value) - Number(r.min)) / (Number(r.max) - Number(r.min))) * 100}%`);
    }
    speed.addEventListener("input", () => { saveVoice({ voice_tts_speed: Math.round(Number(speed.value) * 100) / 100 }); sync(); });
    pitch.addEventListener("input", () => { saveVoice({ voice_tts_pitch: Number(pitch.value) }); sync(); });
    // Let go of a slider: hear the result.
    for (const r of [speed, pitch]) r.addEventListener("change", () => void preview());
    document.body.append(el);
    const place = () => {
      const r = voiceChip.getBoundingClientRect();
      const w = el.offsetWidth, hh = el.offsetHeight;
      el.style.left = `${Math.min(Math.max(8, r.left + r.width / 2 - w / 2), window.innerWidth - w - 8)}px`;
      el.style.top = `${Math.max(8, r.top - hh - 10)}px`;
    };
    sync();
    place();
    requestAnimationFrame(() => el.classList.add("vtone-open"));
    const onDown = (e) => { if (!el.contains(e.target) && !voiceChip.contains(e.target)) close(); };
    const onKey = (e) => { if (e.key === "Escape") { e.preventDefault(); e.stopPropagation(); close(); voiceChip.focus(); } };
    function close() {
      if (!panel) return;
      panel = null;
      voiceChip.setAttribute("aria-expanded", "false");
      document.removeEventListener("mousedown", onDown, true);
      document.removeEventListener("keydown", onKey, true);
      window.removeEventListener("resize", place);
      el.classList.remove("vtone-open");
      setTimeout(() => el.remove(), 180);
    }
    document.addEventListener("mousedown", onDown, true);
    document.addEventListener("keydown", onKey, true);
    window.addEventListener("resize", place);
    voiceChip.setAttribute("aria-expanded", "true");
    panel = { close, sync };
    cards.find((c) => c.dataset.voice === voiceId())?.focus();
  }
  voiceChip.addEventListener("click", openPanel);
  paintVoiceChip();

  // ---- runtime events --------------------------------------------------------------------------------------------------------
  // Events can arrive before the start reply has told us our session id: keep them and replay.
  const early = [];
  function onAgent(e) {
    const v = e.detail;
    if (!v) return;
    if (!session) { if (phase === "entering") early.push(v); return; }
    if (v.session !== session) return;
    switch (v.ev) {
      case "asset": flash(`Getting the speech model… ${Math.round((v.progress ?? 0) * 100)}%`, v.progress >= 1 ? 1200 : 0); break;
      case "ready": notice.hidden = true; break;
      case "state": agent = v.state; paint(); break;
      case "partial": userLine.textContent = v.text; userLine.dataset.live = "true"; break;
      case "heard":
        userLine.textContent = v.text;
        delete userLine.dataset.live;
        agentLine.textContent = "";
        // The files that were waiting went out with these words.
        if (sentFiles.size) { o.attach.clear(); sentFiles.clear(); }
        break;
      case "say_start": player.open(v.tts); agentLine.textContent = ""; break;
      case "say": agentLine.textContent = `${agentLine.textContent} ${v.text}`.trim(); break;
      case "stop_audio": if (!previewing) player.stop(); break;
      case "tool": flash(/Brief/i.test(v.summary ?? "") ? "Briefing the worker…" : /Check/i.test(v.summary ?? "") ? "Checking on the worker…" : /Stop/i.test(v.summary ?? "") ? "Stopping the worker…" : clip(v.summary ?? "Working…", 48)); break;
      case "worker": upsertWorker(v); break;
      case "act": act(v); break;
      case "approval": flash(v.allow ? "Approved: it is going ahead." : "Refused: it will not do that."); break;
      case "bind": o.bindChat(v.chat_id); break;
      case "error": toast(v.code === "mic_denied" ? micMessage({ name: "NotAllowedError" }) : v.message ?? "Voice mode had a problem.", 7000); break;
      case "ended": if (phase === "on" || phase === "entering") void finish(v.why !== "stopped"); break;
    }
  }
  function onTts(e) {
    const v = e.detail;
    if (!session || !v) return;
    if (v.ev === "audio") player.add(v);
    else if (v.ev === "done") player.done(v.session);
    else if (v.ev === "error" && v.session === player.session) { toast(v.message ?? "The voice stopped."); player.done(v.session); }
  }
  window.addEventListener("opscode:voiceagent", onAgent);
  window.addEventListener("opscode:tts", onTts);

  // ---- the microphone: chunks go to the runtime (never queued: a late chunk is worse than a dropped one) -----------------------
  function sendChunk(pcm) {
    if (!session || inflight > 12 || previewing) return;
    inflight++;
    call("voiceagent.audio", { session, pcm }).catch(() => {}).finally(() => { inflight--; });
  }

  // ---- files: they go out with the next thing you say ---------------------------------------------------------------------------
  function attachChanged() {
    if (!session) return;
    const paths = o.attach.ready().map((a) => a.path).filter((p) => !sentFiles.has(p));
    if (!paths.length) return;
    for (const p of paths) sentFiles.add(p);
    void call("voiceagent.attach", { session, paths }).catch((e) => toast(e.message));
  }

  // ---- animation ----------------------------------------------------------------------------------------------------------------
  async function animateIn() {
    o.root.dataset.voice = "entering";
    // The message box breaks into pixels where it stands; the frame squeezes away.
    pixelVanish(o.textarea, { cell: 8, ms: 520, fill: getComputedStyle(o.composerBox).backgroundColor });
    pixelBurst(o.talkBtn, 3);
    await wait(440);
    o.root.dataset.voice = "on";
    el.hidden = false;
    el.classList.remove("vox-open");
    void el.offsetHeight;
    el.classList.add("vox-open");
    orb.start();
    paint();
    pixelReveal(el, { cell: 9, ms: 560 });
    setTimeout(() => { if (phase === "entering" || phase === "on") { bot.start(); pixelBurst(bot.el, 2); } }, 380);
  }
  async function animateOut() {
    if (!el.hidden) {
      await orb.dissolve(380);
      el.classList.remove("vox-open");
      await wait(220);
    }
    el.hidden = true;
    orb.stop();
    o.root.dataset.voice = "leaving";
    await wait(430);
    delete o.root.dataset.voice;
    pixelReveal(o.composerBox, { cell: 10, ms: 420 });
    o.textarea.focus();
  }

  // ---- enter / leave --------------------------------------------------------------------------------------------------------------
  async function enter() {
    if (phase !== "off") return;
    phase = "entering";
    early.length = 0;
    try {
      if (!(await voiceModeAvailable(true))) { toast(navigator.platform.toLowerCase().includes("mac") ? "Voice mode needs macOS 26 (Apple's on-device speech recognition)." : "Voice mode could not start the speech engine on this computer."); phase = "off"; return; }
      // The agent speaks with Pocket TTS: asks before the one-time download.
      if (!(await ensureVoice())) { phase = "off"; return; }
    } catch (e) { toast(e.message); phase = "off"; return; }
    o.onActive?.(true);
    const anim = animateIn();
    muted = false;
    agent = "starting";
    userLine.textContent = "";
    agentLine.textContent = "";
    workers.clear();
    colL.replaceChildren();
    colR.replaceChildren(screen);
    screen.hidden = true;
    screenOpen = false;
    sentFiles.clear();
    try {
      cap = await startCapture({ onChunk: sendChunk, onLevel: (r) => { micLevel += (r - micLevel) * 0.5; } });
    } catch (e) {
      toast(micMessage(e), 8000);
      await anim;
      await abort();
      return;
    }
    const w = o.getWorker();
    const b = brainValue();
    const sameAccount = w.account_id && w.engine === b.engine ? { account_id: w.account_id } : {};
    let r;
    try {
      r = await call("voiceagent.start", { workspace_id: o.workspace.id, ...(o.getChatId() ? { chat_id: o.getChatId() } : {}), brain: { engine: b.engine, ...(b.model ? { model: b.model } : {}), ...(b.effort ? { effort: b.effort } : {}), ...sameAccount }, worker: { ...(w.engine ? { engine: w.engine } : {}), ...(w.model ? { model: w.model } : {}), ...(w.effort ? { effort: w.effort } : {}), ...(w.account_id ? { account_id: w.account_id } : {}), ...(w.mode ? { mode: w.mode } : {}) } });
    } catch (e) {
      toast(e.message, 9000);
      if (/Claude Code or an API model|No API key|Claude Code is not installed/.test(e.message)) setTimeout(pickBrain, 300);
      await anim;
      await abort();
      return;
    }
    session = r.session;
    for (const v of early.splice(0)) if (v.session === session) onAgent({ detail: v });
    await anim;
    phase = "on";
    document.addEventListener("keydown", onKey, true);
    tick = setInterval(() => { paintWorkers(); if (!o.root.isConnected || !o.root.offsetParent) void leave(); }, 1000);
    paint();
    attachChanged(); // files added before talking go with the first words
    const typed = o.textarea.value.trim();
    if (typed) { o.textarea.value = ""; o.textarea.dispatchEvent(new Event("input", { bubbles: true })); void call("voiceagent.say", { session, text: typed }).catch((e) => toast(e.message)); }
  }

  /** Something failed while opening: undo cleanly. */
  async function abort() {
    cap?.stop();
    cap = null;
    session = null;
    o.onActive?.(false);
    await animateOut();
    phase = "off";
  }

  function cleanup() {
    panel?.close();
    previewing = false;
    clearInterval(tick);
    tick = null;
    document.removeEventListener("keydown", onKey, true);
    cap?.stop();
    cap = null;
    player.stop();
    bot.stop();
    screenOpen = false;
    clearTimeout(screenTimer);
    micLevel = 0;
  }

  /** The session ended (by us, or because the helper or microphone failed). */
  async function finish(unexpected) {
    if (phase === "off" || phase === "leaving") return;
    phase = "leaving";
    cleanup();
    session = null;
    if (unexpected) toast("Voice mode stopped.", 5000);
    await animateOut();
    o.onActive?.(false);
    phase = "off";
  }

  async function leave() {
    if (phase !== "on" && phase !== "entering") return;
    const s = session;
    if (s) void call("voiceagent.stop", { session: s }).catch(() => {});
    await finish(false);
  }

  function onKey(e) {
    if (phase !== "on" || !o.root.isConnected || !o.root.offsetParent) return;
    if (panel) return; // the voice panel is open: its own keys (Esc closes the panel, not voice mode)
    if (e.key === "Escape") { e.preventDefault(); e.stopPropagation(); void leave(); }
    else if (isMicChord(e)) { e.preventDefault(); e.stopPropagation(); setMuted(!muted); }
  }

  return {
    el,
    chip,
    voiceChip,
    enter,
    leave,
    active: () => phase === "on" || phase === "entering",
    toggleMute: () => setMuted(!muted),
    attachChanged,
    repaintChip: () => { paintChip(); paintVoiceChip(); },
  };
}
