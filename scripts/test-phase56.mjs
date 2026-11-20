// Phase 56: the notch. Checks the notch's state model (src/main/notchState.ts) on its own and against a real runtime,
// the page-action checks (what the notch page may ask main to do), the notch measuring, and the page files.
// The Electron window itself (placement, click-through, focus) is checked by hand; see docs/HANDOFF.md.

import { mkdtempSync, readFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, waitFor } from "./lib/harness.mjs";

const ROOT = new URL("..", import.meta.url).pathname;
const { NotchModel, notchAction, hardwareNotchOf, oneLine, toolVerb } = await import(join(ROOT, "dist/main/notchState.js"));
const t = reporter();

// ---- 1. the model on its own ------------------------------------------------------------------------------------
{
  const now = Date.now();
  const iso = (ms) => new Date(ms).toISOString();
  const m = new NotchModel();
  m.setWorkspaces([{ id: "w1", name: "shop", path: "/x/shop", added_at: iso(now) }, { id: "w2", name: "api", path: "/x/api", added_at: iso(now) }]);
  m.setChats([
    { id: "c1", workspace_id: "w1", title: "Fix cart", mode: "auto", created_at: iso(now), updated_at: iso(now - 1000), engine: "claude-code" },
    { id: "c2", workspace_id: "w2", title: "Old one", mode: "auto", created_at: iso(now), updated_at: iso(now - 10 * 3600_000) },
    { id: "cv", workspace_id: "w1", title: "voice", mode: "auto", created_at: iso(now), updated_at: iso(now), voice: { session: "s" } },
  ], [], now);
  let f = m.snapshot();
  t.check("asleep with nothing running", f.pose === "sleeping" && f.counts.working === 0, JSON.stringify(f.counts));
  t.check("recent chat listed, old chat and hidden voice chat not", f.sessions.map((s) => s.chat_id).join() === "c1", f.sessions.map((s) => s.chat_id).join());
  t.check("project name and engine carried", f.sessions[0].project === "shop" && f.sessions[0].engine === "claude-code");
  t.check("quick messages go to the project worked in last", f.workspace_id === "w1", f.workspace_id);

  const ev = (type, extra = {}) => ({ turn_id: "t1", chat_id: "c1", workspace_id: "w1", seq: 0, type, ...extra });
  t.check("started -> changed", m.event(ev("started", { engine: "claude-code" }), now) === true);
  f = m.snapshot();
  t.check("working pose and count", f.pose === "working" && f.counts.working === 1 && f.sessions[0].status === "working" && f.sessions[0].turn_id === "t1");
  m.event(ev("delta", { text: "Looking at the **cart** total\n" }), now);
  t.check("streamed text becomes one clean line", m.snapshot().sessions[0].line === "Looking at the cart total", m.snapshot().sessions[0].line);
  m.event(ev("tool_start", { tool: "run_command", summary: "npm test" }), now);
  t.check("a tool becomes a verb line", m.snapshot().sessions[0].line === "Running npm test", m.snapshot().sessions[0].line);

  m.event(ev("approval_request", { call_id: "k1", tool: "run_command", summary: "npm run migrate", detail: "npm run migrate --env prod" }), now);
  f = m.snapshot();
  t.check("approval -> needs you, red pose, count", f.pose === "needs" && f.counts.needs === 1 && f.sessions[0].status === "needs");
  t.check("approval pulse fired once", f.pulse?.kind === "needs" && f.pulse.chat_id === "c1" && f.pulse.seq === 1);
  t.check("the approval carries what is asked", f.sessions[0].approvals[0]?.summary === "npm run migrate" && f.sessions[0].approvals[0]?.detail?.includes("prod"));
  t.check("only a waiting approval can be answered", !!m.approval("t1", "k1") && !m.approval("t1", "nope"));
  m.event(ev("approval_resolved", { call_id: "k1", approved: true }), now);
  f = m.snapshot();
  t.check("answered -> back to working, approval gone", f.sessions[0].status === "working" && f.counts.needs === 0 && !m.approval("t1", "k1"));

  m.event(ev("delta", { text: " All 12 tests pass." }), now);
  m.event(ev("completed"), now + 5000);
  f = m.snapshot();
  t.check("finished unseen -> done, badge, pulse", f.sessions[0].status === "done" && f.sessions[0].unseen && f.counts.unseen === 1 && f.pose === "done" && f.pulse?.kind === "done" && f.pulse.seq === 2);
  t.check("done line is the end of what it said", f.sessions[0].line.endsWith("All 12 tests pass."), f.sessions[0].line);
  t.check("finish time kept", f.sessions[0].ended_at === now + 5000);
  t.check("opening that chat in a focused window marks it seen", m.setViewing("c1") === true && m.snapshot().counts.unseen === 0 && m.snapshot().sessions[0].status === "idle");

  // Looking at the chat while it finishes: no badge, no pulse.
  m.event(ev("started", { turn_id: "t2" }), now);
  m.event(ev("completed", { turn_id: "t2" }), now);
  f = m.snapshot();
  t.check("finished while on screen -> no badge, no pulse", f.counts.unseen === 0 && f.pulse.seq === 2);
  m.setViewing(null);

  m.event(ev("started", { turn_id: "t3" }), now);
  m.event(ev("failed", { turn_id: "t3", error: "Provider said: overloaded" }), now);
  f = m.snapshot();
  t.check("failed -> failed card, error line, error pose", f.sessions[0].status === "failed" && f.sessions[0].line.includes("overloaded") && f.pose === "error" && f.pulse.kind === "failed");
  m.seenAll();
  t.check("mark all seen clears badges", m.snapshot().counts.unseen === 0);

  m.event(ev("started", { turn_id: "t4" }), now);
  m.event(ev("interrupted", { turn_id: "t4" }), now);
  t.check("stopped -> idle, says Stopped, no pulse", m.snapshot().sessions[0].status === "idle" && m.snapshot().sessions[0].line === "Stopped" && m.snapshot().pulse.seq === 3);

  // A brand-new chat's first event arrives before the chat list: it shows with a placeholder until the list comes.
  t.check("unknown chat's first event shows it", m.event({ turn_id: "t9", chat_id: "c9", workspace_id: "w2", seq: 0, type: "started" }, now) && m.snapshot().sessions.some((s) => s.chat_id === "c9" && s.status === "working"));
  t.check("unknown chat's stray delta ignored", m.event({ turn_id: "t8", chat_id: "c8", workspace_id: "w2", seq: 0, type: "delta", text: "x" }, now) === false);
  m.setChats([{ id: "c1", workspace_id: "w1", title: "Fix cart (renamed)", mode: "auto", created_at: iso(now), updated_at: iso(now) }, { id: "c9", workspace_id: "w2", title: "New API route", mode: "auto", created_at: iso(now), updated_at: iso(now) }], ["c9"], now);
  f = m.snapshot();
  t.check("titles follow the chat list", f.sessions.find((s) => s.chat_id === "c1")?.title === "Fix cart (renamed)" && f.sessions.find((s) => s.chat_id === "c9")?.title === "New API route");
  t.check("working chats sort first", f.sessions[0].chat_id === "c9");
  m.setChats([], [], now);
  t.check("deleted chats leave the notch", m.snapshot().sessions.length === 0);

  t.check("oneLine trims long text from the end for streams", oneLine("a".repeat(400), "end").length === 160 && oneLine("a".repeat(400), "end").startsWith("…"));
  t.check("toolVerb", toolVerb("write_file") === "Editing" && toolVerb("read_file") === "Reading" && toolVerb("web_fetch") === "Browsing" && toolVerb(undefined) === "Working");
}

// ---- 2. what the notch page may ask -------------------------------------------------------------------------------
{
  t.check("open with a chat", JSON.stringify(notchAction({ type: "open", chat_id: "c1" })) === '{"type":"open","chat_id":"c1"}');
  t.check("unknown action dropped", notchAction({ type: "rm -rf" }) === null && notchAction(null) === null && notchAction("open") === null);
  t.check("approve needs ids and a real boolean", notchAction({ type: "approve", turn_id: "t", call_id: "k", allow: "yes" }) === null && notchAction({ type: "approve", turn_id: "t", allow: true }) === null);
  t.check("approve keeps choice and remember, drops other fields", JSON.stringify(notchAction({ type: "approve", turn_id: "t", call_id: "k", allow: true, choice: "global", remember: "allow", evil: 1 })) === '{"type":"approve","turn_id":"t","call_id":"k","allow":true,"choice":"global","remember":"allow"}');
  t.check("remember other than allow dropped", !("remember" in notchAction({ type: "approve", turn_id: "t", call_id: "k", allow: true, remember: "always-everything" })));
  t.check("blank or huge message dropped", notchAction({ type: "send", text: "   " }) === null && notchAction({ type: "send", text: "x".repeat(20_001) }) === null);
  t.check("message to a project", notchAction({ type: "send", text: "hi", workspace_id: "w1" })?.workspace_id === "w1");
  t.check("voice ops only start/stop/cancel", notchAction({ type: "voice", op: "start" }) && notchAction({ type: "voice", op: "record-forever" }) === null);
  t.check("talk ops only start/stop/interrupt", notchAction({ type: "talk", op: "start" })?.op === "start" && notchAction({ type: "talk", op: "record" }) === null);
  t.check("talk audio must be base64 and small", notchAction({ type: "talk_audio", pcm: "AAAA" })?.pcm === "AAAA" && notchAction({ type: "talk_audio", pcm: "<script>" }) === null && notchAction({ type: "talk_audio", pcm: "A".repeat(65537) }) === null);
  t.check("talk approve needs a call id and a real boolean", notchAction({ type: "talk_approve", call_id: "k", allow: true })?.allow === true && notchAction({ type: "talk_approve", call_id: "k", allow: "yes" }) === null);
  t.check("talk progress needs a whole number", notchAction({ type: "talk_progress", tts: "s", played: 2 })?.played === 2 && notchAction({ type: "talk_progress", tts: "s", played: 1.5 }) === null);
  t.check("talk say: blank dropped, text trimmed", notchAction({ type: "talk_say", text: "  " }) === null && notchAction({ type: "talk_say", text: " hi " })?.text === "hi");
  t.check("talk pick: brain or worker only, position kept when sane", notchAction({ type: "talk_pick", which: "brain", x: 10.4, y: 40 })?.x === 10 && notchAction({ type: "talk_pick", which: "everything" }) === null && notchAction({ type: "talk_pick", which: "worker", x: -5 })?.x === undefined);
  t.check("seen one or all", notchAction({ type: "seen", chat_id: "c" })?.chat_id === "c" && notchAction({ type: "seen", all: true })?.all === true && notchAction({ type: "seen" }) === null);
}

// ---- 3. measuring the screen's notch --------------------------------------------------------------------------------
{
  const n = hardwareNotchOf(JSON.stringify({ width: 1470, top: 32, left: 642.5, right: 642.5 }));
  t.check("MacBook notch measured", n?.width === 185 && n.height === 32, JSON.stringify(n));
  t.check("screen without a notch", hardwareNotchOf(JSON.stringify({ width: 2560, top: 0, left: 0, right: 0 })) === null);
  t.check("garbage from osascript", hardwareNotchOf("not json") === null && hardwareNotchOf(JSON.stringify({ width: "x" })) === null);
}

// ---- 4. against a real runtime: a second client sees every chat's turn, like the notch's own connection ---------------
{
  const rt = await startRuntime();
  t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
  try {
    const app = await session(rt);
    const watcher = await session(rt);
    const proj = mkdtempSync(join(tmpdir(), "opscode-notch-"));
    const wid = (await app.call("workspace.add", { path: proj })).result.workspace.id;
    const m = new NotchModel();
    m.setWorkspaces((await watcher.call("workspace.list", {})).result.workspaces);
    let seen = 0;
    const pump = () => {
      for (; seen < watcher.notes.length; seen++) {
        const n = watcher.notes[seen];
        if (n.method === "turn.event") m.event(n.params);
        if (n.method === "chat.changed") m.setChats(n.params.chats);
      }
    };
    const chat = (await app.call("chat.create", { workspace_id: wid })).result.chat;
    const sub = await app.call("turn.submit", { workspace_id: wid, chat_id: chat.id, text: "hello from the app window" });
    t.check("turn submitted", !!sub.result, JSON.stringify(sub.error ?? ""));
    const ended = await waitFor(() => { pump(); const s = m.snapshot().sessions.find((x) => x.chat_id === chat.id); return s && (s.status === "done" || s.status === "failed"); }, 15000);
    const s = m.snapshot().sessions.find((x) => x.chat_id === chat.id);
    t.check("the notch's connection sees the chat finish", ended, JSON.stringify(s ?? null));
    t.check("it counts as new (not seen) with a pulse", !!s?.unseen && m.snapshot().pulse?.chat_id === chat.id);
    t.check("project name from workspace.list", s?.project === proj.split("/").pop(), s?.project);

    // A quick message from the notch: a new chat is created and the turn starts in it.
    const created = await watcher.call("chat.create", { workspace_id: wid });
    const r2 = await watcher.call("turn.submit", { workspace_id: wid, chat_id: created.result.chat.id, text: "quick one from the notch" });
    t.check("notch quick message starts a new chat", !!r2.result && r2.result.chat_id === created.result.chat.id, JSON.stringify(r2.error ?? r2.result));
    const listed = await waitFor(() => { pump(); return m.snapshot().sessions.some((x) => x.chat_id === created.result.chat.id); }, 15000);
    t.check("and it shows in the notch", listed);
  } finally {
    await rt.stop?.();
  }
}

// ---- 5. page files ---------------------------------------------------------------------------------------------------
{
  const dist = join(ROOT, "dist/renderer");
  const files = ["notch.html", "notch.css", "notch.js", "notchchar.js", "notchsound.js", "notchtalk.js", "voicecapture.js", "voice-worklet.js"];
  t.check("notch page files built", files.every((f) => existsSync(join(dist, f))), files.filter((f) => !existsSync(join(dist, f))).join());
  t.check("notch preload built", existsSync(join(ROOT, "dist/preload/notch.js")));
  const html = readFileSync(join(dist, "notch.html"), "utf8");
  t.check("page has no inline script (CSP script-src 'self')", !/<script(?![^>]*src=)[^>]*>/.test(html));
  const sound = readFileSync(join(dist, "notchsound.js"), "utf8");
  t.check("sounds are made in code (no audio files)", !/\.(aiff|wav|mp3|m4a)/i.test(sound) && /createOscillator/.test(sound));
  const pre = readFileSync(join(ROOT, "dist/preload/notch.js"), "utf8").replace(/\/\*[\s\S]*?\*\/|\/\/.*$/gm, "");
  t.check("notch preload exposes no endpoint/token", !/endpoint|token|opscode:runtime/.test(pre));
  t.check("notch preload is one bundle (a sandboxed preload cannot require local files)", !/require\(["']\.\.?\//.test(pre));
}

process.exit(t.finish());
