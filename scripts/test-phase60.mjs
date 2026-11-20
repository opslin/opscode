// Phase 60: computer use in voice mode and from the notch (slice 3). A real runtime with a fake microphone helper, a fake
// voice, the stand-in hands helper and a mock model. Covers: "open chrome" done with no model at all and spoken; every step
// announced (computer.act start/end with the app) for the screen glow and the app frame; the voice agent's own Mac tools and
// instructions; a risky step that needs a spoken yes; a task learned after it worked and replayed next time with no model;
// "show my workers"; the notch's "On my Mac" (computer.task) for an instant command and for a task done by a chat that is then
// learned; and the notch page / overlay files.
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const ROOT = new URL("..", import.meta.url).pathname;
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p60-")));
const hlog = join(base, "hands.log");
const hands = () => (existsSync(hlog) ? readFileSync(hlog, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const tlog = join(base, "tts.log");
const spoken = () => (existsSync(tlog) ? readFileSync(tlog, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)).filter((x) => x.got === "speak").map((x) => x.text) : []);

// ---- page-action checks (pure) ---------------------------------------------------------------------------------------------
{
  const { notchAction } = await import(join(ROOT, "dist/main/notchState.js"));
  t.check("notch: 'workers' toggles or sets the mini screens", notchAction({ type: "workers" })?.type === "workers" && notchAction({ type: "workers", on: false })?.on === false);
  t.check("notch: 'mac' needs text", notchAction({ type: "mac", text: " open chrome " })?.text === "open chrome" && notchAction({ type: "mac", text: "  " }) === null);
}

// ---- mock model -------------------------------------------------------------------------------------------------------------
const sse = (events) => events.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
const text = (s) => sse([{ type: "content_block_start", index: 0, content_block: { type: "text", text: "" } }, { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: s } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "end_turn" } }]);
const tool = (id, name, input) => sse([{ type: "content_block_start", index: 0, content_block: { type: "tool_use", id, name } }, { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: JSON.stringify(input) } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "tool_use" } }]);
const flat = (c) => (typeof c === "string" ? c : c.map((b) => (b.type === "text" ? b.text : b.type === "tool_result" ? `[result] ${typeof b.content === "string" ? b.content : JSON.stringify(b.content)}` : "")).join("\n"));
const brainReqs = [];
const chatReqs = [];
let n = 0;
const server = createServer((req, res) => {
  let body = "";
  req.on("data", (c) => (body += c));
  req.on("end", () => {
    const b = JSON.parse(body);
    const reply = (s) => { res.writeHead(200, { "content-type": "text/event-stream" }); res.end(s); };
    const last = b.messages.at(-1);
    const lastText = flat(last.content);
    const id = () => `tu_${++n}`;
    if (!String(b.system).includes("You are the voice of Opscode")) {
      // A chat started from the notch's "On my Mac": look, click "Add one", report.
      chatReqs.push(b);
      const steps = b.messages.filter((m) => m.role === "assistant").length;
      return reply(steps === 0 ? tool(id(), "computer_see", {}) : steps === 1 ? tool(id(), "computer_click", { id: 1 }) : text("Added one to the basket; the window changed."));
    }
    brainReqs.push({ body: b, lastText });
    const isResult = last.role === "user" && Array.isArray(last.content) && last.content.some((x) => x.type === "tool_result");
    if (isResult) {
      // What the person asked last decides (the agent's chat keeps the earlier requests too).
      const asked = [...JSON.stringify(b.messages).matchAll(/<heard>([^<]*)<\/heard>/g)].map((x) => x[1]).at(-1) ?? "";
      if (/\[result\] App: Shop/.test(lastText) && /^buy it/.test(asked)) return reply(tool(id(), "computer_click", { id: 4 }));
      if (/\[result\] App: Shop/.test(lastText) && /^add one to the basket/.test(asked)) return reply(tool(id(), "computer_click", { id: 1 }));
      if (/ASK FIRST/.test(lastText)) return reply(text("That would buy it. Go ahead?"));
      if (/Done: pressed "Buy now"|Done: pressed "Add one"/.test(lastText)) return reply(text("Done, it changed."));
      return reply(text("Okay."));
    }
    const heard = /<heard>([^<]*)<\/heard>/.exec(lastText)?.[1] ?? "";
    if (heard.startsWith("add one to the basket")) return reply(tool(id(), "computer_see", { app: "Shop" }));
    if (heard.startsWith("buy it")) return reply(tool(id(), "computer_see", { app: "Shop" }));
    if (heard.startsWith("yes")) return reply(tool(id(), "computer_click", { id: 4, confirmed: true }));
    if (heard.startsWith("show my workers")) return reply(tool(id(), "workers_show", { on: true }));
    return reply(text("Got it."));
  });
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const MOCK = `http://127.0.0.1:${server.address().port}`;

const FOLDER = "sherpa-onnx-pocket-tts-int8-2026-01-26";
const state = join(base, "state");
mkdirSync(join(state, "tts", FOLDER), { recursive: true });
writeFileSync(join(state, "tts", FOLDER, "a.onnx"), "x");
const env = {
  OPSCODE_VOICE_HELPER: join(ROOT, "scripts/lib/fake-voice.mjs"), OPSCODE_FAKE_VOICE_LOG: join(base, "voice.log"),
  OPSCODE_TTS_URL: "http://127.0.0.1:1/unused", OPSCODE_TTS_FILES: "a.onnx", OPSCODE_TTS_WORKER: join(ROOT, "scripts/lib/fake-tts-worker.mjs"), OPSCODE_FAKE_TTS_LOG: tlog, OPSCODE_FAKE_TTS_MS: "20",
  OPSCODE_HANDS_BIN: join(ROOT, "scripts/lib/fake-hands.mjs"), OPSCODE_FAKE_HANDS_LOG: hlog,
  OPSCODE_COMPUTER_DRIVER: "mock", OPSCODE_COMPUTER_MOCK_LOG: join(base, "mock.log"), OPSCODE_COMPUTER_MOCK_FRONT: join(base, "front.txt"),
};
const waitFor = async (fn, ms = 8000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(40)) { const v = await fn(); if (v) return v; } return null; };
const rt = await startRuntime({ env, stateDir: state, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);
try {
  const C = await session(rt);
  const ok = async (m, p) => { const r = await C.call(m, p); if (r.error) throw new Error(`${m}: ${r.error.message}`); return r.result; };
  const proj = join(base, "shop");
  mkdirSync(proj, { recursive: true });
  writeFileSync(join(proj, "package.json"), "{}");
  const wid = (await ok("workspace.add", { path: proj })).workspace.id;
  await ok("provider.set", { id: "anthropic", api_key: "sk-test-p60-6060", base_url: MOCK, model: "test-model" });
  await ok("computer.set_enabled", { enabled: true });

  const S = (await ok("voiceagent.start", { workspace_id: wid, brain: { engine: "api" }, worker: { engine: "api" } })).session;
  const ev = (type) => C.find("voiceagent.event", (p) => p.ev === type && p.session === S).map((m) => m.params);
  const acts = () => C.find("computer.act").map((m) => m.params);
  const say = async (words, wait = true) => { const b = brainReqs.length; await ok("voiceagent.say", { session: S, text: words }); if (wait) await waitFor(() => brainReqs.length > b, 6000); await sleep(600); };

  // 1. "open chrome": no model, spoken, announced.
  const b0 = brainReqs.length, a0 = acts().length;
  await say("open chrome", false);
  await sleep(900);
  t.check("voice 'open chrome': opened by the helper with no model at all", hands().some((c) => c.verb === "open" && c.rest[0] === "Google Chrome") && brainReqs.length === b0, JSON.stringify({ brain: brainReqs.length - b0 }));
  t.check("…and it says so out loud", spoken().some((x) => /Opened Google Chrome/.test(x)), JSON.stringify(spoken().slice(-3)));
  const a1 = acts().slice(a0);
  t.check("the step is announced for the glow and the app frame (start and end, with the app)", a1.some((a) => a.phase === "start" && a.app === "Google Chrome") && a1.some((a) => a.phase === "end" && a.ok === true), JSON.stringify(a1));

  // 2. The voice agent's own Mac tools and instructions.
  await say("add one to the basket");
  await waitFor(() => brainReqs.some((r) => /Done: pressed "Add one"/.test(r.lastText)), 8000);
  const r0 = brainReqs.find((r) => r.lastText.includes("<heard>add one to the basket"));
  t.check("its instructions: USING THE MAC, and its tools: computer_* plus workers_show", r0?.body.system.includes("USING THE MAC") && ["computer_see", "computer_click", "computer_open", "workers_show"].every((x) => r0.body.tools.some((y) => y.name === x)), r0?.body.tools.map((x) => x.name).join(","));
  t.check("it looks at the app and clicks, with no approval needed for a plain click", hands().some((c) => c.verb === "click" && c.rest[0] === "1") && brainReqs.some((r) => /Done: pressed "Add one"/.test(r.lastText)));
  await sleep(800);
  t.check("after it worked, the task is learned (it says so in the window)", ev("act").some((a) => a.kind === "learned" && /add one to the basket/.test(a.what)), JSON.stringify(ev("act").slice(-3)));
  const learned = (await ok("computer.replays.list", {})).replays;
  t.check("…kept as plain steps (press 'Add one'), never the look", learned.some((r) => r.phrase === "add one to the basket" && r.steps.length === 1 && r.steps[0].verb === "press" && r.steps[0].args[0] === "Add one"), JSON.stringify(learned));

  // 3. The same words again: replayed with no model.
  const b1 = brainReqs.length, h1 = hands().length;
  await say("Add one to the basket", false);
  await sleep(1200);
  t.check("the same words again: done from memory with no model", brainReqs.length === b1 && hands().slice(h1).some((c) => c.verb === "press-label" && c.rest[0] === "Add one"), JSON.stringify({ brain: brainReqs.length - b1, calls: hands().slice(h1).map((c) => c.verb) }));
  t.check("…and it says it is done", spoken().some((x) => x === "Done."), JSON.stringify(spoken().slice(-3)));

  // 4. A risky step needs a spoken yes.
  await say("buy it now");
  await waitFor(() => brainReqs.some((r) => /ASK FIRST/.test(r.lastText)), 8000);
  t.check("a risky click is not done: the agent is told to ask first", brainReqs.some((r) => /ASK FIRST: .*Buy now/.test(r.lastText)) && !hands().some((c) => c.verb === "click" && c.rest[0] === "4"));
  await say("yes go ahead");
  await waitFor(() => hands().some((c) => c.verb === "click" && c.rest[0] === "4"), 6000);
  t.check("after a clear yes it runs (confirmed)", hands().some((c) => c.verb === "click" && c.rest[0] === "4"));
  const risky = (await ok("computer.replays.list", {})).replays;
  t.check("a task with a risky step is never learned", !risky.some((r) => /buy/.test(r.phrase)), JSON.stringify(risky.map((r) => r.phrase)));

  // 5. "Show my workers".
  await say("show my workers");
  t.check("'show my workers' reaches the screen (show_workers event)", !!(await waitFor(() => ev("show_workers").some((e) => e.on === true), 5000)));

  await ok("voiceagent.stop", { session: S });

  // 6. The notch's "On my Mac".
  const inst = await ok("computer.task", { text: "open youtube" });
  t.check("On my Mac 'open youtube': done at once with no model", inst.done && inst.ok && inst.how === "instant" && hands().some((c) => c.verb === "open" && c.rest[0] === "https://www.youtube.com"));
  const c0 = chatReqs.length;
  const task = await ok("computer.task", { text: "put one more in my shop basket" });
  t.check("On my Mac, a real task: a chat does it (shown in the notch)", task.done === false && !!task.chat_id && task.how === "agent");
  await waitFor(() => chatReqs.length >= c0 + 3, 8000);
  t.check("…with the computer tools, and no approval card for a plain click", chatReqs.slice(c0).some((r) => r.tools.some((x) => x.name === "computer_see")) && !C.find("turn.event", (p) => p.chat_id === task.chat_id && p.type === "approval_request").length);
  const learnedTask = await waitFor(async () => (await ok("computer.replays.list", {})).replays.find((r) => r.phrase === "put one more in my shop basket"), 6000);
  t.check("…and once it worked, it is learned for next time", !!learnedTask, JSON.stringify((await ok("computer.replays.list", {})).replays.map((r) => r.phrase)));
  const again = await ok("computer.task", { text: "Put one more in my shop basket" });
  t.check("next time: done from memory", again.done && again.ok && again.how === "replay", JSON.stringify(again));
  await ok("computer.set_enabled", { enabled: false });
  t.check("with computer use off, On my Mac still opens apps", (await ok("computer.task", { text: "open chrome" })).ok === true);
  t.check("…but a real task says how to turn computer use on", /Settings/.test((await ok("computer.task", { text: "add something to my basket" })).say ?? ""));

  // Voice mode with computer use off: opening still works; the agent can offer to set up the rest.
  const S2 = (await ok("voiceagent.start", { workspace_id: wid, brain: { engine: "api" }, worker: { engine: "api" } })).session;
  const hb = hands().length, bb = brainReqs.length;
  await ok("voiceagent.say", { session: S2, text: "You... Open Chrome." });
  await sleep(1200);
  t.check("computer use off, voice 'You... Open Chrome.': opened with no model", hands().slice(hb).some((c) => c.verb === "open" && c.rest[0] === "Google Chrome") && brainReqs.length === bb, JSON.stringify(hands().slice(hb)));
  await ok("voiceagent.say", { session: S2, text: "click the search box in chrome" });
  await waitFor(() => brainReqs.length > bb, 6000);
  const rq = brainReqs.at(-1);
  const names = rq?.body.tools.map((x) => x.name) ?? [];
  t.check("…the agent can open apps and offer setup, but cannot click yet", names.includes("computer_open") && names.includes("computer_setup") && !names.includes("computer_click") && rq.body.system.includes("THE MAC (opening only"), names.join(","));
  await ok("voiceagent.stop", { session: S2 });
} finally {
  server.close();
  await rt.stop?.();
}

// ---- page files ---------------------------------------------------------------------------------------------------------------
{
  const dist = join(ROOT, "dist");
  t.check("overlay page and preload built", ["renderer/overlay.html", "renderer/overlay.css", "renderer/overlay.js", "preload/overlay.js"].every((f) => existsSync(join(dist, f))));
  const pre = readFileSync(join(dist, "preload/overlay.js"), "utf8").replace(/\/\*[\s\S]*?\*\/|\/\/.*$/gm, "");
  t.check("overlay preload: one bundle, no endpoint or token", !/require\(["']\.\.?\//.test(pre) && !/endpoint|token/.test(pre));
  const js = readFileSync(join(dist, "renderer/overlay.js"), "utf8");
  t.check("overlay animates only while something is shown (no idle loop)", /if \(state\.working \|\| fade > 0\.01\) raf = requestAnimationFrame\(draw\)/.test(js));
  const notch = readFileSync(join(dist, "renderer/notch.js"), "utf8");
  t.check("notch: On my Mac target and Workers button", /On my Mac/.test(notch) && /type: "workers"/.test(notch) && /type: "mac"/.test(notch));
}
process.exit(t.finish());
