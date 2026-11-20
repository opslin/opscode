// Voice mode in the notch: talking with Opscode's voice agent from any app (⌃⌥Space or the Talk button).
//   microphone (voicecapture.js, echo-cancelled) -> main -> voiceagent.audio
//   the agent's events (state, what it heard, what it says, workers, approvals) <- main
//   the agent's voice (tts.event, 24 kHz Int16 per sentence) <- main, played here so the echo canceller can remove it
// The view: pixel sound bars, captions (you / Opscode), what it is doing now, a card per worker (project, model, state,
// Yes / No when it waits on you), and a box to type instead of speaking.

import { startCapture, micMessage } from "./voicecapture.js";

const RATE = 24000;

/** A model id said the way people say it: "claude-opus-5-5" -> "Opus 5.5", "gpt-6.1-sol" -> "GPT-6.1 Sol". */
export function modelName(id) {
  if (!id) return "";
  const m = /^claude-([a-z]+)-(\d+)(?:-(\d+))?/i.exec(id);
  if (m) return `${m[1][0].toUpperCase()}${m[1].slice(1)} ${m[2]}${m[3] ? `.${m[3]}` : ""}`;
  const g = /^gpt-([\d.]+)(?:-([a-z]+))?/i.exec(id);
  if (g) return `GPT-${g[1]}${g[2] ? ` ${g[2][0].toUpperCase()}${g[2].slice(1)}` : ""}`;
  return id;
}
const STATE_WORDS = { starting: "Starting…", listening: "Listening", hearing: "Hearing you", thinking: "Thinking", speaking: "Speaking" };

/** The agent's voice: sentences scheduled back to back on one clock; stop() cuts it at once (you spoke over it). */
function createPlayer({ onPlaying, onProgress }) {
  let ctx = null, out = null, analyser = null, data = null, session = null, nextAt = 0, ended = false, playing = false;
  const sources = new Set(), timers = new Set();
  const ensure = () => {
    if (!ctx) {
      ctx = new AudioContext({ latencyHint: "interactive" });
      out = ctx.createGain();
      analyser = ctx.createAnalyser();
      analyser.fftSize = 512;
      data = new Uint8Array(analyser.fftSize);
      out.connect(analyser).connect(ctx.destination);
    }
    if (ctx.state === "suspended") void ctx.resume();
    return ctx;
  };
  const setPlaying = (p) => { if (p !== playing) { playing = p; onPlaying(p); } };
  const settle = () => { if (ended && sources.size === 0) setPlaying(false); };
  const cut = () => {
    for (const s of sources) { try { s.onended = null; s.stop(); } catch { /* over */ } }
    sources.clear();
    for (const t of timers) clearTimeout(t);
    timers.clear();
    nextAt = 0;
  };
  return {
    open(id) { cut(); session = id; ended = false; nextAt = 0; },
    add(msg) {
      if (msg.session !== session || !msg.pcm) return;
      const c = ensure();
      const bin = atob(msg.pcm);
      const n = bin.length >> 1;
      const rate = Number(msg.rate) > 0 ? Number(msg.rate) : RATE;
      const buf = c.createBuffer(1, n, rate);
      const ch = buf.getChannelData(0);
      for (let k = 0; k < n; k++) { const v = bin.charCodeAt(2 * k) | (bin.charCodeAt(2 * k + 1) << 8); ch[k] = (v > 32767 ? v - 65536 : v) / 32768; }
      const src = c.createBufferSource();
      src.buffer = buf;
      src.connect(out);
      const at = Math.max(c.currentTime + 0.04, nextAt);
      src.start(at);
      nextAt = at + buf.duration;
      sources.add(src);
      setPlaying(true);
      const sid = msg.session, i = msg.i ?? 0;
      const tm = setTimeout(() => { timers.delete(tm); onProgress(sid, i + 1); }, Math.max(0, (at - c.currentTime) * 1000));
      timers.add(tm);
      src.onended = () => { sources.delete(src); settle(); };
    },
    done(id) { if (id === session) { ended = true; settle(); } },
    warm() { ensure(); },
    stop() { cut(); session = null; ended = true; setPlaying(false); },
    level() {
      if (!analyser || !playing) return 0;
      analyser.getByteTimeDomainData(data);
      let sum = 0;
      for (let i = 0; i < data.length; i++) { const v = (data[i] - 128) / 128; sum += v * v; }
      return Math.min(1, Math.sqrt(sum / data.length) * 3.2);
    },
    get session() { return session; },
    close() { cut(); session = null; void ctx?.close().catch(() => {}); ctx = null; },
  };
}

/**
 * The talk controller. ui: { h, ICON, logo, onChange() (repaint: state, workers or captions changed), onAsk() (a worker waits
 * on the person: open the notch), toast(text), play(sound) }.
 */
export function createTalk(bridge, ui) {
  const { h, ICON, logo } = ui;
  const t = {
    picks: null,
    on: false, starting: false, state: "starting", you: "", youLive: false, said: "", doing: "", workers: new Map(), mic: null, micLevel: 0, muted: false, session: null,
  };
  let inflight = 0;
  const player = createPlayer({
    onPlaying: (p) => bridge.act({ type: "talk_playback", playing: p }),
    onProgress: (tts, played) => bridge.act({ type: "talk_progress", tts, played }),
  });

  async function start() {
    if (t.on || t.starting) return;
    t.starting = true;
    t.state = "starting";
    t.you = ""; t.said = ""; t.doing = ""; t.workers.clear();
    ui.onChange();
    try {
      t.mic = await startCapture({
        onChunk: (pcm) => { if (!t.on || t.muted || inflight > 12) return; inflight++; bridge.act({ type: "talk_audio", pcm }); setTimeout(() => { inflight--; }, 120); },
        onLevel: (v) => { t.micLevel = v; },
      });
    } catch (e) {
      t.starting = false;
      ui.toast(micMessage(e));
      ui.onChange();
      return;
    }
    // Open the speaker now (inside the press), so the first reply plays at once.
    player.warm();
    bridge.act({ type: "talk", op: "start" });
  }

  function stop() {
    if (!t.on && !t.starting) return;
    bridge.act({ type: "talk", op: "stop" });
    end();
  }

  function end() {
    t.on = false;
    t.starting = false;
    t.mic?.stop();
    t.mic = null;
    t.micLevel = 0;
    player.stop();
    ui.onChange();
  }

  function setMuted(m) { t.muted = m; t.mic?.setMuted(m); ui.onChange(); }

  function handle(e) {
    if (e.kind === "on") { t.on = true; t.starting = false; t.session = e.session; t.state = "listening"; ui.play("open"); ui.onChange(); return; }
    if (e.kind === "off") { const was = t.on || t.starting; end(); if (e.message) ui.toast(e.message); else if (was && e.why !== "stopped") ui.toast("Voice mode ended."); return; }
    if (e.kind === "tts") {
      if (e.ev === "audio") player.add(e);
      else if (e.ev === "done") player.done(e.session);
      else if (e.ev === "error" && e.session === player.session) player.done(e.session);
      return;
    }
    if (e.kind === "computer") {
      // A step on the Mac (from voice mode or a chat): the live line while talking.
      if (!t.on) return;
      if (e.phase === "start" && e.summary) { t.doing = `${e.summary}…`; ui.onChange(); }
      return;
    }
    // kind "agent": the voice agent's own events
    switch (e.ev) {
      case "state": t.state = e.state; break;
      case "partial": t.you = e.text ?? ""; t.youLive = true; break;
      case "heard": t.you = e.text ?? ""; t.youLive = false; t.said = ""; break;
      case "say_start": player.open(e.tts); t.said = ""; break;
      case "say": t.said = `${t.said} ${e.text ?? ""}`.trim(); t.doing = ""; break;
      case "stop_audio": player.stop(); break;
      case "tool": t.doing = doingWords(e.summary ?? ""); break;
      case "act": if (e.kind === "learned") t.doing = "Learned it — next time it's instant"; else if (e.kind === "computer") t.doing = e.what ? `${e.what}` : t.doing; else if (e.kind === "browse") t.doing = "Using the browser…"; else if (e.kind === "peek") t.doing = e.path ? `Looking at ${String(e.path).split("/").filter(Boolean).pop() ?? "the project"}…` : "Taking a look…"; break;
      case "worker": {
        const had = t.workers.get(e.id);
        t.workers.set(e.id, e);
        if (e.ask && (!had?.ask || had.ask.call_id !== e.ask.call_id)) { ui.play("needs"); ui.onAsk(); }
        break;
      }
      case "picks": t.picks = { brain: e.brain, worker: e.worker }; break;
      case "approval": t.doing = e.auto ? "Allowed a routine step" : e.allow ? "Approved" : "Refused"; break;
      case "trust": t.doing = e.on ? "I'll handle routine approvals" : "I'll ask you again"; break;
      case "error": ui.toast(e.code === "mic_denied" ? micMessage({ name: "NotAllowedError" }) : e.message ?? "Voice mode had a problem."); break;
      default: return;
    }
    ui.onChange();
  }

  function doingWords(summary) {
    const s = summary.replace(/\s+/g, " ").trim();
    if (/^Brief/i.test(s)) return s.replace(/^Brief the worker:\s*/i, "Starting a worker: ");
    if (/^Find the project/i.test(s)) return "Finding the project…";
    if (/^List the projects/i.test(s)) return "Looking at your projects…";
    if (/^List the models/i.test(s)) return "Checking the models…";
    if (/^Look in/i.test(s)) return `${s}…`;
    if (/^Find a folder/i.test(s)) return "Searching your folders…";
    if (/^Add /i.test(s)) return s;
    if (/^Check on/i.test(s)) return "Checking on the work…";
    if (/^Stop/i.test(s)) return "Stopping it…";
    if (/^Tell the worker/i.test(s)) return "Passing that on…";
    return s.length > 60 ? `${s.slice(0, 59)}…` : s;
  }

  // ---- the view ---------------------------------------------------------------------------------------------------------
  const bars = document.createElement("canvas");
  bars.className = "talk-bars";
  const BARS = 28;
  let raf = 0;
  const hist = new Array(BARS).fill(0);
  function drawBars() {
    raf = 0;
    if (!bars.isConnected || (!t.on && !t.starting)) return;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const W = bars.clientWidth || 300, H = 30;
    if (bars.width !== Math.round(W * dpr)) { bars.width = Math.round(W * dpr); bars.height = Math.round(H * dpr); }
    const g = bars.getContext("2d");
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, W, H);
    const speaking = player.level();
    const lv = Math.max(speaking, t.muted ? 0 : t.micLevel);
    hist.push(lv); hist.shift();
    const cell = 3, gap = 1.5;
    const colW = (W - (BARS - 1) * 3) / BARS;
    for (let i = 0; i < BARS; i++) {
      const center = 1 - Math.abs(i - (BARS - 1) / 2) / (BARS / 2);
      const v = Math.max(0.06, hist[(i * 7 + hist.length) % hist.length] * (0.45 + 0.55 * center));
      const cells = Math.max(1, Math.round((v * H) / (cell + gap)));
      for (let k = 0; k < cells; k++) {
        const y = H / 2 + (k % 2 ? 1 : -1) * Math.ceil(k / 2) * (cell + gap) - cell / 2;
        const hot = speaking > 0.02;
        g.fillStyle = hot ? (k > 4 ? "#ffd2b8" : "#ff6a3d") : t.state === "hearing" ? (k > 4 ? "#ffffff" : "#ff9a7a") : "rgba(255,255,255,.55)";
        g.globalAlpha = 1 - k * 0.07;
        g.fillRect(i * (colW + 3), y, colW, cell);
      }
    }
    g.globalAlpha = 1;
    raf = requestAnimationFrame(drawBars);
  }
  const kick = () => { if (!raf) raf = requestAnimationFrame(drawBars); };

  function workerCard(w, i) {
    const st = w.ask ? "needs" : w.status === "running" ? "working" : w.status === "complete" ? "done" : w.status === "failed" ? "failed" : "idle";
    const model = [modelName(w.model), w.effort ? `${w.effort} effort` : ""].filter(Boolean).join(" · ");
    const kids = [
      h("div", { class: "top" },
        h("div", { class: "mark" }, logo(w.engine, w.model), h("i", { class: "st" })),
        h("div", { class: "txt" },
          h("div", { class: "l1" }, h("span", { class: "t" }, w.title), w.project ? h("span", { class: "p" }, w.project) : null),
          h("div", { class: "l2" }, h("span", {}, w.ask ? `Wants to: ${w.ask.summary}` : w.current ?? (st === "working" ? "Working…" : st === "done" ? `Done${w.files ? ` · ${w.files} file${w.files === 1 ? "" : "s"} changed` : ""}` : st === "failed" ? "Failed" : "Waiting"))),
        ),
        model ? h("span", { class: "chip" }, model) : null),
    ];
    if (w.ask) {
      if (w.ask.detail) kids.push(h("pre", {}, w.ask.detail));
      kids.push(h("div", { class: "btns" },
        h("button", { class: "wbtn", type: "button", onclick: (ev) => ui.guarded(ev) && bridge.act({ type: "talk_approve", call_id: w.ask.call_id, allow: false }) }, "No"),
        h("button", { class: "wbtn lit", type: "button", onclick: (ev) => ui.guarded(ev) && bridge.act({ type: "talk_approve", call_id: w.ask.call_id, allow: true }) }, "Yes, go ahead")));
    }
    return h("div", { class: `tworker${w.ask ? " card" : ""} stagger`, style: `--i:${i}`, "data-status": st }, ...kids);
  }

  const ENGINE_NAME = { "claude-code": "Claude", codex: "Codex", antigravity: "Antigravity", qoder: "Qoder", api: "API key" };
  function pickChip(which, label, p) {
    const name = p ? (p.model ? modelName(p.model) : ENGINE_NAME[p.engine] ?? p.engine) : "…";
    const extra = p ? [p.model && ENGINE_NAME[p.engine] && p.engine !== "claude-code" && p.engine !== "codex" ? ENGINE_NAME[p.engine] : "", p.effort ?? "", p.default ? "default" : ""].filter(Boolean).join(" · ") : "";
    return h("button", {
      class: "pick", type: "button", title: which === "brain" ? "What Opscode talks with. Click to change (it keeps the conversation)." : "What new workers run on. Click to change.",
      onclick: (ev) => {
        if (!ui.guarded(ev)) return;
        const r = ev.currentTarget.getBoundingClientRect();
        bridge.act({ type: "talk_pick", which, x: Math.round(r.left), y: Math.round(r.bottom + 4) });
      },
    },
      h("span", { class: "pk" }, label),
      p ? h("span", { class: "pm" }, logo(p.engine, p.model)) : null,
      h("span", { class: "pn" }, name),
      extra ? h("span", { class: "px" }, extra) : null,
      h("span", { class: "pc", html: ICON.chev }));
  }

  const typed = h("input", { class: "talk-type", type: "text", placeholder: "Or type to it…", spellcheck: "false" });
  typed.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && typed.value.trim()) { bridge.act({ type: "talk_say", text: typed.value.trim() }); typed.value = ""; }
    if (e.key === "Escape") typed.blur();
  });

  /** The talk panel (built fresh on each repaint; the bars canvas and the typing box are kept). */
  function view(fresh) {
    const ws = [...t.workers.values()].sort((a, b) => Number(!!b.ask) - Number(!!a.ask) || (b.started_at ?? 0) - (a.started_at ?? 0)).slice(0, 4);
    const stateWord = t.starting && !t.on ? "Starting…" : STATE_WORDS[t.state] ?? "Listening";
    const el = h("div", { class: "talk" },
      h("div", { class: "talk-head stagger", style: "--i:0" },
        h("span", { class: "talk-dot", "data-state": t.on ? t.state : "starting" }),
        h("span", { class: "ttl" }, "Voice"),
        h("span", { class: "talk-state" }, t.muted ? "Muted" : stateWord),
        h("span", { style: "flex:1" }),
        h("button", { class: "ibtn", type: "button", title: t.muted ? "Unmute the microphone" : "Mute the microphone", html: t.muted ? ICON.micOff : ICON.mic, onclick: (e) => ui.guarded(e) && setMuted(!t.muted) }),
        t.state === "speaking" ? h("button", { class: "ibtn", type: "button", title: "Stop talking (or just speak)", html: ICON.stop, onclick: (e) => ui.guarded(e) && bridge.act({ type: "talk", op: "interrupt" }) }) : null,
        h("button", { class: "wbtn red end", type: "button", onclick: (e) => ui.guarded(e) && stop() }, "End")),
      h("div", { class: "talk-picks stagger", style: "--i:1" }, pickChip("brain", "Talks with", t.picks?.brain), pickChip("worker", "New workers", t.picks?.worker)),
      h("div", { class: "talk-wave stagger", style: "--i:1" }, bars),
      h("div", { class: "talk-cap stagger", style: "--i:2" },
        h("div", { class: "you", "data-live": t.youLive ? "" : null }, t.you ? h("b", {}, "You  ") : null, t.you || (t.on ? "Say what you need. Any project, any model." : "")),
        t.said ? h("div", { class: "it" }, h("b", {}, "Opscode  "), t.said) : null,
        t.doing ? h("div", { class: "doing" }, h("i", { class: "spark" }), t.doing) : null),
      ws.length ? h("div", { class: "sect stagger", style: "--i:3" }, "Workers") : null,
      ...ws.map((w, i) => workerCard(w, 4 + i)),
      h("div", { class: "talk-foot stagger", style: "--i:9" }, typed, h("span", { class: "hintk" }, ui.shortcut())),
    );
    if (!fresh) for (const s of el.querySelectorAll(".stagger")) s.style.animation = "none";
    kick();
    return el;
  }

  /** One line for the collapsed notch while talking. */
  function peekLine() {
    const ask = [...t.workers.values()].find((w) => w.ask);
    if (ask) return { tag: "Needs you", tone: "needs", text: `${ask.title}: ${ask.ask.summary}` };
    if (t.state === "speaking" && t.said) return { tag: "Opscode", tone: "talk", text: t.said };
    if ((t.state === "hearing" || t.youLive) && t.you) return { tag: "You", tone: "you", text: t.you };
    if (t.doing) return { tag: STATE_WORDS[t.state] ?? "Voice", tone: "talk", text: t.doing };
    return { tag: t.muted ? "Muted" : STATE_WORDS[t.state] ?? "Listening", tone: "talk", text: t.said || "Talk to me. I'm listening." };
  }

  return {
    get on() { return t.on || t.starting; },
    get state() { return t.state; },
    get speaking() { return t.state === "speaking"; },
    get waiting() { return [...t.workers.values()].some((w) => w.ask); },
    level: () => Math.max(player.level(), t.muted ? 0 : t.micLevel),
    start, stop, handle, view, peekLine, kick,
  };
}
