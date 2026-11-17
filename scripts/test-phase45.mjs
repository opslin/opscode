// Voice mode (docs/voice-mode-plan.md): the runtime side, against a fake microphone helper, a fake voice (TTS) and a mock model
// that plays both the front agent and the worker. Covers: hearing and partials, the front agent's prompt and tools, briefing
// the worker, the worker's chat appearing, news from the worker spoken without being asked, status checks, a spoken approval,
// barge-in (cut off and told what was cut), the echo filter, typed input, the hidden chat never listed, clean end.
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const FOLDER = "sherpa-onnx-pocket-tts-int8-2026-01-26";
const b64 = (s) => Buffer.from(s, "latin1").toString("base64");

// ---- pure parts: the sentence splitter for a reply that is still arriving, and the echo filter ---------------------------------
{
  const { SentenceStream } = await import(join(process.cwd(), "dist/runtime/tts/speakable.js"));
  const { isEcho } = await import(join(process.cwd(), "dist/runtime/voiceagent/echo.js"));
  const feed = (chunks) => { const st = new SentenceStream(); const out = []; for (const c of chunks) out.push(st.push(c)); out.push(st.flush()); return out; };
  const a = feed(["On it. I'll ", "have it look at ", "the settings page first. ", "Then I'll tell you."]);
  t.check("a sentence is released as soon as the next one's first letter arrives (not before: a boundary is only known then)", JSON.stringify(a) === JSON.stringify([["On it."], [], [], ["I'll have it look at the settings page first."], ["Then I'll tell you."]]), JSON.stringify(a));
  const b = feed(["Version 3.5 is out. Dr. Smith agrees. e.g. now."]);
  t.check("numbers and abbreviations do not end a sentence", JSON.stringify(b.flat()) === JSON.stringify(["Version 3.5 is out.", "Dr. Smith agrees. e.g. now."]) || b.flat().length === 2, JSON.stringify(b));
  const c = feed(["**Done.** See `src/app.ts` and https://example.com now"]);
  t.check("markup is cleaned for speech (bold, file paths, links)", c.flat().join(" ").includes("Done.") && c.flat().join(" ").includes("app.ts") && !c.flat().join(" ").includes("**") && c.flat().join(" ").includes("link"), JSON.stringify(c));
  const long = "word ".repeat(80).trim();
  const d = feed([long]);
  t.check("a long run with no full stop is cut so speech can start", d.flat().length >= 2 && d.flat().every((s) => s.length <= 290), JSON.stringify(d.flat().map((s) => s.length)));
  // The voice agent's browser: its own rule for sites outside this computer, search, no page JavaScript.
  {
    const { voiceBrowserTools } = await import(join(process.cwd(), "dist/runtime/voiceagent/browser.js"));
    const calls = [];
    const fake = (name) => ({ def: { name, description: name, schema: { type: "object", properties: { url: { type: "string" } } } }, kind: "read", gate: async () => ({ rule: "ask" }), run: async (i) => { calls.push([name, i]); return { output: `${name} ok`, is_error: false }; } });
    const vt = voiceBrowserTools(["browser_navigate", "browser_read", "browser_find", "browser_act", "browser_screenshot", "browser_logs", "browser_eval", "browser_tabs", "browser_batch"].map(fake));
    const tool = (n) => vt.find((x) => x.def.name === n);
    t.check("voice browser tools: search, navigate, read, find, act, screenshot, tabs, batch; no page JavaScript or logs; all run without approval cards", !!tool("browser_search") && !!tool("browser_navigate") && !!tool("browser_act") && !tool("browser_eval") && !tool("browser_logs") && vt.every((x) => x.kind === "chief" && !x.gate), vt.map((x) => x.def.name).join(","));
    const r1 = await tool("browser_navigate").run({ url: "github.com" });
    t.check("an outside site the person did not confirm is not opened (the agent is told to ask)", r1.is_error && /Shall I open github\.com/.test(r1.output) && calls.length === 0, r1.output);
    const r2 = await tool("browser_navigate").run({ url: "github.com", confirmed: true });
    const r3 = await tool("browser_navigate").run({ url: "https://github.com/trending" });
    const r4 = await tool("browser_navigate").run({ url: "localhost:3000" });
    t.check("confirmed opens it; the same site again and local pages open freely", !r2.is_error && !r3.is_error && !r4.is_error && calls.filter((c) => c[0] === "browser_navigate").length === 3);
    const r5 = await tool("browser_search").run({ query: "pocket tts voices" });
    t.check("browser_search opens a search for the words", !r5.is_error && calls.at(-1)[1].url === "https://www.google.com/search?q=pocket%20tts%20voices", JSON.stringify(calls.at(-1)));
    const r6 = await tool("browser_batch").run({ actions: [{ tool: "browser_navigate", input: { url: "example.org" } }] });
    const r7 = await tool("browser_batch").run({ actions: [{ tool: "browser_eval", input: {} }] });
    t.check("a batch cannot open an unconfirmed site or run page JavaScript", r6.is_error && r7.is_error);
    t.check("without a browser there are no browser tools", voiceBrowserTools([]).length === 0);
  }
  {
    const { spokenAnswer } = await import(join(process.cwd(), "dist/runtime/voiceagent/index.js"));
    const yes = ["yes", "Yes please.", "okay do it", "ok, right now do it", "go ahead", "sure", "approve it", "allow"];
    const no = ["no", "No, don't.", "nope", "stop", "deny it", "not now"];
    const other = ["yes but first check the tests", "what does it want", "okay wait", "maybe later", "please add a login page and a settings page and also a footer"];
    t.check("spoken yes: short plain yeses count", yes.every((x) => spokenAnswer(x) === "yes"), JSON.stringify(yes.map((x) => [x, spokenAnswer(x)])));
    t.check("spoken no: short plain noes count", no.every((x) => spokenAnswer(x) === "no"), JSON.stringify(no.map((x) => [x, spokenAnswer(x)])));
    t.check("anything with a condition, a question or more words is left to the agent", other.every((x) => spokenAnswer(x) === null), JSON.stringify(other.map((x) => [x, spokenAnswer(x)])));
  }
  t.check("echo: mostly the agent's own words (4+ words) is an echo", isEcho("the plan is to add the switch", ["The plan is to add the switch and then run the tests."]));
  t.check("…short replies are not (\"yes\" can be both)", !isEcho("yes please do", ["Yes please do that now."]));
  t.check("…and the person's new words are not", !isEcho("please use a different colour for the toggle", ["The plan is to add the switch and then run the tests."]));
}

// ---- mock model: the front agent (recognised by its system prompt) and the worker -------------------------------------------
const sse = (events) => events.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
const text = (s) => sse([{ type: "content_block_start", index: 0, content_block: { type: "text", text: "" } }, ...(s.match(/.{1,9}/gs) ?? [""]).map((c) => ({ type: "content_block_delta", index: 0, delta: { type: "text_delta", text: c } })), { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "end_turn" } }]);
const tool = (id, name, input) => { const j = JSON.stringify(input); return sse([{ type: "content_block_start", index: 0, content_block: { type: "tool_use", id, name } }, { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: j.slice(0, 7) } }, { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: j.slice(7) } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "tool_use" } }]); };
const flat = (c) => (typeof c === "string" ? c : c.map((b) => (b.type === "text" ? b.text : b.type === "tool_result" ? `[result] ${typeof b.content === "string" ? b.content : JSON.stringify(b.content)}` : "")).join("\n"));
const brainReqs = [];
const workerReqs = [];
let slowBrain = false;
const BRIEF2 = "Goal: Fix the login page so a wrong password shows an error.\nContext: The person said \"also fix the login page\".\nWhere to start: the login page.\nConstraints: none.\nDone when: a wrong password shows a clear error.\nReport: what changed and how it was checked.";
const BRIEF = "Goal: Add a dark mode switch to the settings page so the person can switch themes.\nContext: The person said \"add dark mode to the settings\".\nWhere to start: the settings page; find it first.\nConstraints: Do not touch the login page.\nDone when: the switch toggles the theme and the existing tests pass; say plainly if you could not run them.\nReport: what changed, files, how it was verified, what is left.";
const server = createServer((req, res) => {
  let body = "";
  req.on("data", (c) => (body += c));
  req.on("end", () => {
    const b = JSON.parse(body);
    const isBrain = String(b.system).includes("You are the voice of Opscode");
    const last = b.messages.at(-1);
    const lastText = flat(last.content);
    const reply = (s) => { res.writeHead(200, { "content-type": "text/event-stream" }); res.end(s); };
    if (isBrain) {
      brainReqs.push({ body: b, lastText });
      const hasResult = last.role === "user" && Array.isArray(last.content) && last.content.some((x) => x.type === "tool_result");
      if (hasResult) {
        if (lastText.includes("[result] Started w2")) return reply(text("Started the login fix as well."));
        if (/\[result\] w\d "[^"]+"\nstate:/.test(lastText)) return reply(text("It has finished the dark mode switch. It did not run the tests though."));
        if (lastText.includes("[result] Started w1")) return reply(text("On it. I have briefed the worker."));
        if (lastText.includes("[result] Approved.")) return reply(text("Done, I approved it."));
        if (lastText.includes("[result] Sent to w")) return reply(text("Sent. It is working on it."));
        return reply(text("Okay."));
      }
      if (lastText.includes("<approval_answered")) return reply(text("Done, it's going ahead."));
      if (lastText.includes("status=\"waiting_for_approval\"")) return reply(text("The worker wants to run a command. Shall I allow it?"));
      if (lastText.includes("<worker_update")) return reply(text("The worker has finished. Dark mode is in the settings page."));
      if (lastText.includes("<heard>also fix the login page")) return reply(tool("tu_6", "work_start", { brief: BRIEF2, title: "Login fix" }));
      if (lastText.includes("<heard>tell the dark mode one")) return reply(tool("tu_7", "work_tell", { worker: "w1", message: "Also add a short note about the switch to the README." }));
      if (lastText.includes("<heard>please add dark mode")) return reply(tool("tu_1", "work_start", { brief: BRIEF, title: "Dark mode" }));
      if (lastText.includes("<heard>what is it doing")) return reply(tool("tu_2", "work_status", {}));
      if (lastText.includes("<heard>please run the tests")) return reply(tool("tu_3", "work_tell", { message: "Please run the test suite and report the result." }));
      if (/<heard>(yes|yes please)/.test(lastText)) { const m = /call_id ([\w-]+)/.exec(lastText); return reply(tool("tu_4", "work_approve", { call_id: m?.[1] ?? "none", allow: true })); }
      if (lastText.includes("<heard>tell me a long story")) { slowBrain = true; return reply(text("Once upon a time there was a SLOW dragon. It lived in a cave by the sea. Every morning it counted its gold twice. Then it went back to sleep.")); }
      if (lastText.includes("<heard>stop talking")) return reply(text("Sure."));
      if (lastText.includes("<heard>what is the plan")) return reply(text("The plan is to add the switch and then run the tests carefully."));
      if (lastText.includes("<heard>")) return reply(text("Got it."));
      return reply(text("Okay."));
    }
    workerReqs.push({ body: b, lastText });
    const toolBack = last.role === "user" && Array.isArray(last.content) && last.content.some((x) => x.type === "tool_result");
    if (toolBack) return reply(text("Ran the tests. All passed."));
    if (lastText.includes("Goal: Fix the login page")) return reply(text("Fixed the login page error."));
    if (lastText.includes("note about the switch")) return reply(text("Added the README note."));
    if (lastText.includes("run the test suite")) return reply(tool("w_1", "run_command", { command: "echo tests-ok" }));
    return reply(text("Added the dark mode switch to the settings page."));
  });
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const MOCK = `http://127.0.0.1:${server.address().port}`;

// ---- fixture ---------------------------------------------------------------------------------------------------------------------
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p45-")));
const proj = join(base, "Shopkart");
mkdirSync(join(proj, "src"), { recursive: true });
writeFileSync(join(proj, "package.json"), "{}");
writeFileSync(join(proj, "src", "settings.tsx"), "export const Settings = () => null;\n");
const state = join(base, "state");
const vlog = join(base, "voice.log");
const tlog = join(base, "tts.log");
const FILES = ["a.onnx"];
mkdirSync(join(state, "tts", FOLDER), { recursive: true });
for (const f of FILES) writeFileSync(join(state, "tts", FOLDER, f), "x");
const engLog = join(base, "engines.log");
const agyHome = join(base, "agy-home");
mkdirSync(agyHome, { recursive: true });
writeFileSync(join(agyHome, "fake-auth.json"), "{}");
const engLines = () => (existsSync(engLog) ? readFileSync(engLog, "utf8").trim().split("\n").filter(Boolean).map((l) => { try { return JSON.parse(l); } catch { return {}; } }) : []);
const env = { OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_AGY_BIN: join(process.cwd(), "scripts/lib/fake-acp.mjs"), OPSCODE_FAKE_ENGINE_LOG: engLog, OPSCODE_FAKE_REAL_HOME: process.env.HOME ?? "", OPSCODE_FAKE_DEFAULT_ACP_HOME: agyHome, OPSCODE_VOICE_HELPER: join(process.cwd(), "scripts/lib/fake-voice.mjs"), OPSCODE_FAKE_VOICE_LOG: vlog, OPSCODE_TTS_URL: "http://127.0.0.1:1/unused", OPSCODE_TTS_FILES: FILES.join(","), OPSCODE_TTS_WORKER: join(process.cwd(), "scripts/lib/fake-tts-worker.mjs"), OPSCODE_FAKE_TTS_LOG: tlog, OPSCODE_FAKE_TTS_MS: "30" };
const cmds = () => (existsSync(vlog) ? readFileSync(vlog, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const spoken = () => (existsSync(tlog) ? readFileSync(tlog, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)).filter((x) => x.got === "speak").map((x) => x.text) : []);
// Waits until the front agent has made no new request for a while (the worker's news after typed work arrives late).
const settle = async (ms = 1200) => { let n = brainReqs.length; for (let quiet = Date.now(); Date.now() - quiet < ms; await sleep(100)) if (brainReqs.length !== n) { n = brainReqs.length; quiet = Date.now(); } };
const waitFor = async (fn, ms = 8000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(40)) { const v = await fn(); if (v) return v; } return null; };

const rt = await startRuntime({ env, stateDir: state, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);
try {
  const C = await session(rt);
  const ok = async (m, p) => { const r = await C.call(m, p); if (r.error) throw new Error(`${m}: ${r.error.message}`); return r.result; };
  const wid = (await ok("workspace.add", { path: proj })).workspace.id;
  await ok("provider.set", { id: "anthropic", api_key: "sk-test-voice-1234", base_url: MOCK, model: "test-model" });
  const ev = (type, session) => C.find("voiceagent.event", (p) => p.ev === type && (!session || p.session === session)).map((m) => m.params);

  // ---- status, start ----------------------------------------------------------------------------------------------------------
  const st = await ok("voiceagent.status", {});
  t.check("status: helper, recognizer, the voice installed", st.helper && st.available && st.voice_installed && st.running === null, JSON.stringify(st));
  const bad = await C.call("voiceagent.start", { workspace_id: wid, brain: { engine: "nonesuch" } });
  t.check("an unknown engine is refused", /Pick a model/.test(bad.error?.message ?? ""), bad.error?.message);
  const started = await ok("voiceagent.start", { workspace_id: wid, brain: { engine: "api" }, worker: { engine: "api", mode: "supervised" } });
  const S = started.session;
  t.check("start gives a session; no worker chat yet", !!S && started.chat_id === null);
  const conv = await waitFor(() => cmds().find((c) => c.cmd === "converse"));
  t.check("the helper is asked for a conversation with the project's names and the pause setting", conv && conv.words.includes("Shopkart") && conv.words.includes("src") && conv.end_ms === 1100, JSON.stringify(conv));
  t.check("it reports ready and listening", !!(await waitFor(() => ev("ready", S)[0])) && ev("state", S).some((e) => e.state === "listening"));
  const again = await C.call("voiceagent.start", { workspace_id: wid, brain: { engine: "api" } });
  t.check("only one voice session at a time", !!again.error && /already running/.test(again.error.message), again.error?.message);
  const listed = (await ok("chat.list", {})).chats;
  t.check("the agent's hidden chat is never listed", !listed.some((c) => c.title === "Voice agent"), JSON.stringify(listed.map((c) => c.title)));

  // ---- the first thing you say: heard -> brief -> worker --------------------------------------------------------------
  await ok("voiceagent.audio", { session: S, pcm: b64("SAY:please add dark mode to the settings") });
  t.check("speech is shown as it comes (hearing, partial words, then what was heard)", !!(await waitFor(() => ev("heard", S)[0])) && ev("state", S).some((e) => e.state === "hearing") && ev("partial", S).length >= 4 && ev("heard", S)[0].text === "please add dark mode to the settings");
  t.check("it thinks, then the worker chat appears (bind) with the brief's title", !!(await waitFor(() => ev("bind", S)[0])), JSON.stringify(ev("bind", S)));
  const wchat = ev("bind", S)[0].chat_id;
  t.check("front agent request: its prompt (briefing rules), its six tools, the worker line and what was heard", (() => {
    const r = brainReqs[0]; if (!r) return false;
    const names = (r.body.tools ?? []).map((x) => x.name).sort().join(",");
    return r.body.system.includes("HOW TO WRITE A BRIEF") && r.body.system.includes("Shopkart") && names === "peek,work_approve,work_start,work_status,work_stop,work_tell" && r.lastText.includes("<workers>none yet") && r.lastText.includes("<heard>please add dark mode to the settings</heard>");
  })(), JSON.stringify(brainReqs[0]?.lastText));
  t.check("the worker received the brief, word for word", !!(await waitFor(() => workerReqs[0])) && flat(workerReqs[0].body.messages[0].content).includes("Goal: Add a dark mode switch to the settings page") && flat(workerReqs[0].body.messages[0].content).includes("Do not touch the login page"), JSON.stringify(workerReqs[0]?.lastText?.slice(0, 120)));
  const chats = (await ok("chat.list", {})).chats;
  const wc = chats.find((c) => c.id === wchat);
  t.check("the worker chat is a normal, listed chat named by the agent's title, on the picked engine and permission mode", wc?.title === "Dark mode" && wc.mode === "supervised" && (wc.engine ?? "api") === "api", JSON.stringify(wc));
  const whist = await waitFor(async () => { const h = (await ok("turn.history", { chat_id: wchat })).messages; return h.length >= 2 && h.at(-1).status === "complete" ? h : null; });
  t.check("the worker's turn ran in that chat", !!whist && whist[0].role === "user" && whist.at(-1).text.includes("Added the dark mode switch"), JSON.stringify(whist)?.slice(0, 200));

  // ---- the agent speaks: sentences become voice while the reply is still arriving ---------------------------------
  const say1 = await waitFor(() => ev("say_start", S)[0]);
  t.check("it speaks: a live voice session opens when the first sentence is ready", !!say1);
  t.check("the agent said what the mock model wrote", !!(await waitFor(() => spoken().some((x) => x.includes("On it. I have briefed the worker.") || x.includes("On it.")))), JSON.stringify(spoken()));
  t.check("the window gets the audio as tts events for that session", !!(await waitFor(() => C.find("tts.event", (p) => p.session === say1.tts && p.ev === "audio")[0])) && !!(await waitFor(() => C.find("tts.event", (p) => p.session === say1.tts && p.ev === "done")[0])));
  await ok("voiceagent.playback", { session: S, playing: true });
  t.check("while the agent talks the detector is made less eager", !!(await waitFor(() => cmds().some((c) => c.cmd === "vad" && c.boost > 1))));
  await ok("voiceagent.playback", { session: S, playing: false });
  t.check("…and back to normal afterwards", !!(await waitFor(() => { const v = cmds().filter((c) => c.cmd === "vad"); const k = v.findIndex((c) => c.boost > 1); return k >= 0 && v.slice(k + 1).some((c) => c.boost === 1); })));

  // ---- the worker finishes: the agent is told and speaks up on its own -------------------------------------------------
  const n0 = brainReqs.length;
  const upd = await waitFor(() => brainReqs.find((r, i) => i >= 1 && /<worker_update worker="w1"[^>]*status="complete"/.test(r.lastText)));
  t.check("when the worker finishes the agent is told (its own words, files, no claims of verification)", !!upd && upd.lastText.includes("Added the dark mode switch to the settings page.") && upd.lastText.includes("Do not claim anything was verified"), upd?.lastText?.slice(0, 300));
  t.check("…and it tells the person without being asked", !!(await waitFor(() => spoken().some((x) => x.includes("The worker has finished")))), JSON.stringify(spoken()));
  t.check("the worker's state reaches the window", ev("worker", S).some((e) => e.status === "running") && ev("worker", S).some((e) => e.status === "complete"));

  // ---- status check ----------------------------------------------------------------------------------------------------------
  await sleep(300);
  await ok("voiceagent.audio", { session: S, pcm: b64("SAY:what is it doing right now") });
  const stat = await waitFor(() => brainReqs.find((r) => /\[result\] w1 "Dark mode"\nstate:/.test(r.lastText)));
  t.check("asked what the worker is doing, the agent calls work_status and gets the whole picture", !!stat && /state: finished/.test(stat.lastText) && stat.lastText.includes("its last words: Added the dark mode switch"), stat?.lastText?.slice(0, 400));
  t.check("…and answers in words", !!(await waitFor(() => spoken().some((x) => x.includes("It has finished the dark mode switch")))));

  // ---- a follow-up that needs approval, answered by voice ---------------------------------------------------------------
  await ok("voiceagent.audio", { session: S, pcm: b64("SAY:please run the tests") });
  const ask = await waitFor(() => brainReqs.find((r) => r.lastText.includes("status=\"waiting_for_approval\"")));
  t.check("the worker's approval request reaches the agent with what it wants to do and the call id", !!ask && /run_command|echo tests-ok/.test(ask.lastText) && /call_id [\w-]+/.test(ask.lastText) && ask.lastText.includes("Do not approve until they say so"), ask?.lastText?.slice(0, 300));
  t.check("the agent asks the person aloud", !!(await waitFor(() => spoken().some((x) => x.includes("Shall I allow it")))));
  const waitingCard = (await ok("turn.history", { chat_id: wchat })).messages.at(-1).parts?.find((p) => p.status === "awaiting_approval");
  const wInfo = ev("worker", S).filter((e) => e.id === "w1").at(-1);
  t.check("the window gets what the worker wants approved (for the card's Allow / Deny)", !!wInfo?.ask?.call_id && /run_command|echo tests-ok/.test(`${wInfo.ask.summary} ${wInfo.ask.detail ?? ""}`), JSON.stringify(wInfo?.ask));
  const badAppr = await C.call("voiceagent.approve", { session: S, call_id: "nope", allow: true });
  t.check("Allow / Deny for an unknown approval does nothing", badAppr.result?.ok === false, JSON.stringify(badAppr));
  t.check("the approval card is waiting in the worker's chat (nothing was approved by itself)", !!waitingCard);
  await ok("voiceagent.audio", { session: S, pcm: b64("SAY:yes please") });
  const nAppr = brainReqs.length;
  t.check("a plain spoken yes to the question it asked is answered at once (no model call needed for it)", !!(await waitFor(() => ev("approval", S).some((e) => e.allow === true && e.worker === "w1"))), JSON.stringify(ev("approval", S)));
  t.check("…then the agent is told it was approved and only confirms", !!(await waitFor(() => brainReqs.find((r, i) => i >= nAppr && r.lastText.includes("<approval_answered worker=\"w1\"") && r.lastText.includes("It was approved")))) && !!(await waitFor(() => spoken().some((x) => x.includes("going ahead")))));
  t.check("…and the card stops waiting (no ask left)", ev("worker", S).filter((e) => e.id === "w1").at(-1)?.waiting === 0 && !ev("worker", S).filter((e) => e.id === "w1").at(-1)?.ask);
  t.check("the worker carries on and finishes; the agent reports it", !!(await waitFor(() => brainReqs.find((r) => /<worker_update worker="w1"[^>]*status="complete"/.test(r.lastText) && r.lastText.includes("Ran the tests. All passed.")))), JSON.stringify(brainReqs.map((r) => r.lastText.slice(0, 40))));

  // ---- several workers: new work gets its own fresh chat; follow-ups go to the worker that has it ---------------------
  await settle();
  const binds0 = ev("bind", S).length;
  await ok("voiceagent.audio", { session: S, pcm: b64("SAY:also fix the login page") });
  const w2 = await waitFor(() => ev("worker", S).find((e) => e.id === "w2"));
  const chats2 = (await ok("chat.list", {})).chats;
  const lc = chats2.find((c) => c.title === "Login fix");
  t.check("a new piece of work starts a second worker (w2) in its own new chat, named by the agent", !!w2 && !!lc && w2.chat_id === lc.id && lc.id !== wchat && w2.view === false, JSON.stringify({ w2, titles: chats2.map((c) => c.title) }));
  t.check("…the window stays on the first chat (no second bind) and is told to animate the start", ev("bind", S).length === binds0 && ev("act", S).some((e) => e.kind === "start" && e.worker === "w2"));
  const w2req = await waitFor(() => workerReqs.find((r) => flat(r.body.messages[0].content).includes("Goal: Fix the login page")));
  t.check("w2's chat starts fresh: its first request holds only its brief (none of w1's history)", !!w2req && w2req.body.messages.length === 1 && !JSON.stringify(w2req.body.messages).includes("dark mode switch"), JSON.stringify(w2req?.body.messages?.length));
  t.check("w2 finishes and the agent is told which work it was", !!(await waitFor(() => brainReqs.find((r) => /<worker_update worker="w2" title="Login fix"[^>]*status="complete"/.test(r.lastText) && r.lastText.includes("Fixed the login page error.")))));
  await settle();
  await ok("voiceagent.audio", { session: S, pcm: b64("SAY:tell the dark mode one to add a readme note") });
  const told = await waitFor(async () => (await ok("turn.history", { chat_id: wchat })).messages.some((m) => m.role === "user" && m.text.includes("note about the switch")));
  t.check("a follow-up for w1 goes into w1's chat (work_tell with worker w1), not a new one", !!told && !(await ok("chat.list", {})).chats.some((c) => c.title === "Also add a short note"));
  t.check("…and the window is told the agent visited that worker", ev("act", S).some((e) => e.kind === "visit" && e.worker === "w1"));
  const both = await waitFor(() => brainReqs.find((r) => /<workers>w1 "Dark mode": [^|]+\| w2 "Login fix": /.test(r.lastText)));
  t.check("every turn the agent sees all workers in one line", !!both, brainReqs.at(-1)?.lastText?.slice(0, 200));
  await settle();
  // ---- short memory: after a few turns the agent continues in a fresh chat with a recap ---------------------------------
  const rot = await waitFor(() => brainReqs.find((r) => r.lastText.includes("<recap>")), 4000);
  t.check("after a few turns the agent's chat is replaced: the request starts fresh with a short recap (cheaper turns)", !!rot && rot.body.messages.length === 1 && rot.lastText.includes("Person: please add dark mode to the settings") && rot.lastText.includes("Workers so far: w1 \"Dark mode\"") && rot.lastText.includes("You: On it. I have briefed the worker."), JSON.stringify({ n: rot?.body?.messages?.length, t: rot?.lastText?.slice(0, 400) }));
  const maxMsgs = Math.max(...brainReqs.map((r) => r.body.messages.length));
  t.check("…so no agent request carries a long history", maxMsgs <= 2 * 6 + 4, String(maxMsgs));

  // ---- barge-in: you speak over it -----------------------------------------------------------------------------------------
  await sleep(500);
  await ok("voiceagent.audio", { session: S, pcm: b64("SAY:tell me a long story") });
  const before = ev("stop_audio", S).length;
  const stoppedBefore = () => C.find("tts.event", (p) => p.ev === "stopped").length;
  t.check("it starts telling a long story (slow voice)", !!(await waitFor(() => spoken().some((x) => x.includes("SLOW dragon")))));
  await ok("voiceagent.playback", { session: S, playing: true });
  const st0 = stoppedBefore();
  await ok("voiceagent.audio", { session: S, pcm: b64("SPEECH") });
  await sleep(400);
  t.check("a sound with no words (its own voice in the mic) does not cut it off", ev("stop_audio", S).length === before && stoppedBefore() === st0, `${ev("stop_audio", S).length - before} ${stoppedBefore() - st0}`);
  await ok("voiceagent.audio", { session: S, pcm: b64("SAY:stop talking") });
  t.check("you speak over it: the audio is cut as soon as your words are recognised (stop_audio) and the voice session stopped", !!(await waitFor(() => ev("stop_audio", S).length > before)) && !!(await waitFor(() => stoppedBefore() > st0)));
  const cut = await waitFor(() => brainReqs.find((r) => r.lastText.includes("<cut_off>")));
  t.check("the agent is told it was cut off, what it had said and what it had not", !!cut && /<cut_off>You were interrupted\./.test(cut.lastText) && cut.lastText.includes("<heard>stop talking</heard>"), cut?.lastText?.slice(0, 500));

  // ---- echo: the agent's own words coming back are not you ----------------------------------------------------------
  await sleep(300);
  await ok("voiceagent.audio", { session: S, pcm: b64("SAY:what is the plan") });
  t.check("it answers with a longer sentence", !!(await waitFor(() => spoken().some((x) => x.includes("The plan is to add the switch")))));
  await ok("voiceagent.playback", { session: S, playing: true });
  const nb = brainReqs.length;
  await ok("voiceagent.audio", { session: S, pcm: b64("SAY:the plan is to add the switch and then run") });
  t.check("a phrase that is only the agent's own words is ignored as an echo (no model call)", !!(await waitFor(() => ev("ignored", S).some((e) => e.why === "echo"))) && brainReqs.length === nb, JSON.stringify(ev("ignored", S)));
  await ok("voiceagent.audio", { session: S, pcm: b64("SAY:please use a different colour for the toggle") });
  t.check("…while real words said over it are still heard (the agent is cut off first)", !!(await waitFor(() => brainReqs.some((r, i) => i >= nb && r.lastText.includes("<heard>please use a different colour for the toggle</heard>")))));
  await ok("voiceagent.playback", { session: S, playing: false });

  // ---- typed fallback, noise ---------------------------------------------------------------------------------------------
  await sleep(400);
  const nc = brainReqs.length;
  await ok("voiceagent.say", { session: S, text: "please add dark mode" }); // worker idle -> work_start again is fine for the mock
  t.check("typed words work like speech (same path)", !!(await waitFor(() => brainReqs.some((r, i) => i >= nc && r.lastText.includes("<heard>please add dark mode</heard>")))));
  await settle();
  const nn = brainReqs.length;
  await ok("voiceagent.audio", { session: S, pcm: b64("NOISE") });
  await sleep(400);
  t.check("a noise is not an utterance: no model call", brainReqs.length === nn);

  // ---- attachments ride with the next thing said ------------------------------------------------------------------------
  await settle();
  await ok("voiceagent.attach", { session: S, paths: ["src/settings.tsx"] });
  const na = brainReqs.length;
  await ok("voiceagent.audio", { session: S, pcm: b64("SAY:what do you think of this file") });
  t.check("files added with + go to the agent with the next utterance", !!(await waitFor(() => brainReqs.some((r, i) => i >= na && r.lastText.includes("<attached>src/settings.tsx</attached>")))), brainReqs.at(-1)?.lastText);

  // ---- end -----------------------------------------------------------------------------------------------------------------------
  const ended = await ok("voiceagent.stop", { session: S });
  t.check("stop ends the session, releases the microphone helper and says which chat to keep", ended.stopped && !!(await waitFor(() => ev("ended", S)[0]?.chat_id === wchat)) && !!(await waitFor(() => cmds().some((c) => c.cmd === "cancel"))), JSON.stringify(ev("ended", S)));
  await sleep(600);
  const metaFile = join(state, "chats.json");
  const metas = existsSync(metaFile) ? JSON.parse(readFileSync(metaFile, "utf8")) : [];
  t.check("the agent's hidden chat is deleted with the session; the worker chat stays", !metas.some((c) => c.voice) && metas.some((c) => c.id === wchat), JSON.stringify(metas.map((c) => [c.title, !!c.voice])));
  const s2 = await C.call("voiceagent.say", { session: S, text: "hello" });
  t.check("a stopped session accepts nothing more", !!s2.error);

  // ---- continuing in an existing chat; a failed microphone ends the session cleanly -------------------------------------------
  const again2 = await ok("voiceagent.start", { workspace_id: wid, chat_id: wchat, brain: { engine: "api" } });
  t.check("voice mode can continue in an existing chat (worker chat given)", again2.chat_id === wchat);
  const nCont = brainReqs.length;
  await ok("voiceagent.audio", { session: again2.session, pcm: b64("SAY:what is it doing") });
  const cont = await waitFor(() => brainReqs.find((r, i) => i >= nCont && r.lastText.includes("<heard>what is it doing</heard>")));
  t.check("…the agent knows the worker already exists and how it ended (state taken from the chat's record)", !!cont && !cont.lastText.includes("not started") && /<workers>w1 "Dark mode": finished/.test(cont.lastText), cont?.lastText?.slice(0, 200));
  await ok("voiceagent.stop", { session: again2.session });

  // ---- the voice agent can run on Codex and Antigravity too (only talks + its own tools; nothing else is allowed) ----------------
  {
    const BRIEF3 = "Goal: fix the footer so it stays at the bottom of short pages. Where to start: the footer component. Done when: it sits at the bottom on a short page.";
    const cx = await ok("voiceagent.start", { workspace_id: wid, brain: { engine: "codex" } });
    t.check("the voice agent can be started on Codex", !!cx.session);
    await ok("voiceagent.audio", { session: cx.session, pcm: b64(`SAY:fix the footer FAKE_CMD=«rm -rf build» FAKE_TOOL work_start ${JSON.stringify({ brief: BRIEF3, title: "Footer fix" })}`) });
    const th = await waitFor(() => engLines().find((l) => l.thread_params));
    t.check("Codex starts in a read-only sandbox, asks before anything, with shell/web/image/computer tools off and only the agent's MCP", !!th && th.thread_params.sandbox === "read-only" && th.thread_params.approvalPolicy === "on-request" && th.thread_params.features["features.shell_tool"] === false && th.thread_params.features["features.computer_use"] === false && th.thread_params.features["features.image_generation"] === false && th.thread_params.features.web_search === "disabled" && th.thread_params.mcp.join() === "mcp_servers.opscode_chief", JSON.stringify(th?.thread_params));
    t.check("…and its instructions are the voice agent's (briefing rules)", !!th?.thread_params.baseInstructions?.includes("HOW TO WRITE A BRIEF"));
    t.check("work_start over Codex's MCP starts a worker with the brief", !!(await waitFor(() => engLines().find((l) => l.chief_tool === "work_start" && /Started w\d/.test(l.result)))), JSON.stringify(engLines().filter((l) => l.chief_tool)));
    t.check("a command Codex asks to run for the voice agent is declined (the worker codes, not the voice agent)", !!(await waitFor(() => engLines().find((l) => l.brain_cmd === "rm -rf build" && l.decision === "decline"))), JSON.stringify(engLines().filter((l) => l.brain_cmd)));
    t.check("the window is told which tool the agent used (named, not 'mcp')", !!(await waitFor(() => C.find("voiceagent.event", (p) => p.session === cx.session && p.ev === "tool" && /Footer fix/.test(p.summary ?? ""))[0])), JSON.stringify(C.find("voiceagent.event", (p) => p.session === cx.session && p.ev === "tool").map((p) => p.summary)));
    t.check("what Codex said is spoken", !!(await waitFor(() => spoken().some((x) => x.includes("Chief handled it.")))));
    await settle(1500);
    await ok("voiceagent.stop", { session: cx.session });

    const ag = await ok("voiceagent.start", { workspace_id: wid, brain: { engine: "antigravity" } });
    t.check("the voice agent can be started on Antigravity", !!ag.session);
    await ok("voiceagent.audio", { session: ag.session, pcm: b64(`SAY:fix the footer FAKE_CMD rm -rf build FAKE_TOOL work_start ${JSON.stringify({ brief: BRIEF3, title: "Footer fix 2" })}`) });
    const sn = await waitFor(() => engLines().find((l) => l.ev === "session_new" && (l.mcp ?? []).some((m) => m.name === "opscode_chief")));
    t.check("Antigravity's session is given the agent's tools over HTTP MCP with a bearer token", !!sn && sn.mcp[0].type === "http" && /^Bearer /.test(sn.mcp[0].headers?.[0]?.value ?? ""), JSON.stringify(sn?.mcp));
    t.check("the agent's own tool is allowed and runs", !!(await waitFor(() => engLines().find((l) => l.ev === "chief_tool" && l.name === "work_start" && l.allowed === true && /Started w\d/.test(l.result)))), JSON.stringify(engLines().filter((l) => l.ev === "chief_tool")));
    t.check("a command Antigravity asks to run is rejected", !!(await waitFor(() => engLines().find((l) => l.ev === "permission" && l.kind === "execute" && l.allowed === false))), JSON.stringify(engLines().filter((l) => l.ev === "permission")));
    t.check("what Antigravity said is spoken (it was refused the command, and said so)", !!(await waitFor(() => spoken().some((x) => x.includes("Not allowed.")))));
    t.check("the first message of its fresh session carries the voice agent's instructions", !!(await waitFor(() => engLines().find((l) => l.ev === "prompt" && l.text.includes("<instructions>") && l.text.includes("HOW TO WRITE A BRIEF")))));
    await settle(1500);
    await ok("voiceagent.stop", { session: ag.session });
    const saved = [];
    for (const e of ["codex", "antigravity", "qoder", "claude-code", "api", ""]) saved.push((await C.call("settings.set", { patch: { voice_brain_engine: e } })).error ? e : "ok");
    t.check("the settings accept every engine for the voice agent", saved.every((x) => x === "ok"), JSON.stringify(saved));
  }
} catch (e) {
  t.check("no unexpected error", false, e instanceof Error ? e.stack : String(e));
} finally {
  await rt.stop();
  server.close();
}
process.exit(t.finish());
