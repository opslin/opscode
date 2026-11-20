// Phase 57: voice mode across projects. The voice agent finds the project the person means (even with speech mistakes),
// lists projects, looks inside a folder (read-only, home folder only, never private folders), adds a folder as a project
// only after it looked and the person said yes, and starts each worker in the project and on the engine / model / effort
// the person chose. Against a fake microphone helper, a fake voice and a mock model playing the voice agent and workers.
import { mkdirSync, mkdtempSync, readFileSync, realpathSync, symlinkSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const ROOT = process.cwd();
const P = await import(join(ROOT, "dist/runtime/voiceagent/projects.js"));

// ---- fixture: a fake home folder with projects, a folder that is not a project yet, and private folders ---------------------
const home = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p57-")));
const mk = (rel, files = {}) => { const d = join(home, rel); mkdirSync(d, { recursive: true }); for (const [f, c] of Object.entries(files)) { mkdirSync(join(d, f, ".."), { recursive: true }); writeFileSync(join(d, f), c); } return d; };
const shop = mk("Documents/Shopkart", { "package.json": JSON.stringify({ name: "shopkart", description: "Online shop for groceries", dependencies: { next: "15", react: "19" } }), "src/settings.tsx": "x" });
const dApp = mk("Documents/dealker/dealker-app", { "pubspec.yaml": "name: dealker", "README.md": "# Dealker app\n\nThe Flutter app customers use to book car services." });
const dSrv = mk("Documents/dealker/dealker-server", { "package.json": JSON.stringify({ name: "dealker-server", description: "API for dealker bookings", dependencies: { express: "4" } }), ".git/HEAD": "ref" });
const billing = mk("Developer/billing-tool", { "README.md": "# Billing tool\n\nMakes PDF invoices for freelance clients every month.", "Cargo.toml": "[package]", "src/main.rs": "fn main(){}" });
mk(".ssh", { id_rsa: "SECRET-KEY" });
mk("Library/Keychains", { "login.keychain": "x" });
const outside = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p57-outside-")));
symlinkSync(outside, join(home, "Documents", "sneaky-link"));

// ---- 1. the pure parts ------------------------------------------------------------------------------------------------------
{
  t.check("similar: speech splits a name (deal car is closer to dealker than to anything else)", P.similar("deal car", "dealker") > 0.45 && P.similar("deal car", "dealker") > P.similar("deal car", "billing-tool") + 0.3, String(P.similar("deal car", "dealker")));
  t.check("similar: unrelated names stay low", P.similar("shop cart", "billing-tool") < 0.35, String(P.similar("shop cart", "billing-tool")));
  const list = [{ id: "a", name: "Shopkart", path: shop }, { id: "b", name: "dealker-app", path: dApp }, { id: "c", name: "dealker-server", path: dSrv }];
  const m1 = P.findProjects(list, "shop cart");
  t.check("findProjects: 'shop cart' -> Shopkart first", m1[0]?.name === "Shopkart", JSON.stringify(m1));
  const m2 = P.findProjects(list, "deal car server");
  t.check("findProjects: 'deal car server' -> dealker-server first", m2[0]?.name === "dealker-server", JSON.stringify(m2));
  const m3 = P.findProjects(list, "dealker");
  t.check("findProjects: 'dealker' fits two projects (the agent must ask)", m3.length >= 2 && m3.slice(0, 2).every((x) => x.name.startsWith("dealker")), JSON.stringify(m3));
  const m4 = P.findProjects(list, "the flutter one for car services");
  t.check("findProjects: by what it is (README / kind)", m4[0]?.name === "dealker-app", JSON.stringify(m4));
  const f = P.describeProject(shop, "Shopkart");
  t.check("describeProject: kind and description", f.kind.includes("next.js") && f.what === "Online shop for groceries", JSON.stringify(f));
  const look = P.lookFolder("Developer/billing-tool", home);
  t.check("lookFolder: entries, README, kind", look.path === billing && look.kind.includes("rust") && look.readme.includes("PDF invoices") && look.entries.some((e) => e.name === "src" && e.dir), JSON.stringify(look).slice(0, 300));
  t.check("lookFolder: ~ paths work", P.lookFolder("~/Developer/billing-tool", home).path === billing);
  const refuse = (p) => { try { P.lookFolder(p, home); return false; } catch { return true; } };
  t.check("lookFolder refuses .ssh", refuse(".ssh") && refuse("~/.ssh"));
  t.check("lookFolder refuses Library (keychains, mail, browser data)", refuse("Library/Keychains") && refuse("Library"));
  t.check("lookFolder refuses outside the home folder", refuse("/etc") && refuse(outside));
  t.check("lookFolder refuses a link that leads outside", refuse("Documents/sneaky-link"));
  t.check("lookFolder: a missing folder is a clear error", (() => { try { P.lookFolder("Documents/nope", home); return false; } catch (e) { return /no folder/i.test(e.message); } })());
  const ff = P.findFolders("billing tool", home);
  t.check("findFolders: finds Developer/billing-tool", ff[0]?.path === billing, JSON.stringify(ff));
  t.check("findFolders: never walks into private folders", !P.findFolders("ssh", home).some((x) => x.path.includes(".ssh")));
}

// ---- 2. the voice agent, live -------------------------------------------------------------------------------------------------
const sse = (events) => events.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
const text = (s) => sse([{ type: "content_block_start", index: 0, content_block: { type: "text", text: "" } }, { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: s } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "end_turn" } }]);
const tool = (id, name, input) => sse([{ type: "content_block_start", index: 0, content_block: { type: "tool_use", id, name } }, { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: JSON.stringify(input) } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "tool_use" } }]);
const flat = (c) => (typeof c === "string" ? c : c.map((b) => (b.type === "text" ? b.text : b.type === "tool_result" ? `[result] ${typeof b.content === "string" ? b.content : JSON.stringify(b.content)}` : "")).join("\n"));
const BRIEF = "Goal: Fix the login so a wrong password shows an error.\nContext: The person asked for it.\nWhere to start: the auth routes.\nConstraints: none.\nDone when: a wrong password returns 401 with a message.\nReport: what changed.";
const brainReqs = [];
const results = [];
let n = 0;
const server = createServer((req, res) => {
  let body = "";
  req.on("data", (c) => (body += c));
  req.on("end", () => {
    const b = JSON.parse(body);
    const reply = (s) => { res.writeHead(200, { "content-type": "text/event-stream" }); res.end(s); };
    if (!String(b.system).includes("You are the voice of Opscode")) return reply(text("Done."));
    const last = b.messages.at(-1);
    const lastText = flat(last.content);
    brainReqs.push({ body: b, lastText });
    const id = () => `tu_${++n}`;
    const isResult = last.role === "user" && Array.isArray(last.content) && last.content.some((x) => x.type === "tool_result");
    if (isResult) {
      results.push(lastText);
      if (lastText.includes('[result] project "dealker-server"')) return reply(tool(id(), "work_start", { brief: BRIEF, title: "Server login", project: "dealker-server", engine: "api", effort: "high" }));
      const folder = /\[result\] (\/\S*billing-tool)/.exec(lastText);
      if (folder && !lastText.includes("folder:")) return reply(tool(id(), "folder_look", { path: folder[1] }));
      return reply(text("Okay."));
    }
    const heard = /<heard>([^<]*)<\/heard>/.exec(lastText)?.[1] ?? "";
    if (heard.startsWith("which projects")) return reply(tool(id(), "projects_list", {}));
    if (heard.startsWith("fix the login in deal car server")) return reply(tool(id(), "project_find", { query: "deal car server" }));
    if (heard.startsWith("check the billing tool folder")) return reply(tool(id(), "folder_find", { name: "billing tool" }));
    if (heard.startsWith("add the ssh folder")) return reply(tool(id(), "project_add", { path: join(home, ".ssh"), confirmed: true }));
    if (heard.startsWith("maybe add it")) return reply(tool(id(), "project_add", { path: billing, confirmed: false }));
    if (heard.startsWith("yes add it")) return reply(tool(id(), "project_add", { path: billing, confirmed: true }));
    if (heard.startsWith("look in ssh")) return reply(tool(id(), "folder_look", { path: "~/.ssh" }));
    if (heard.startsWith("fix dealker")) return reply(tool(id(), "work_start", { brief: BRIEF, title: "Ambiguous", project: "dealker" }));
    if (heard.startsWith("use qoder")) return reply(tool(id(), "work_start", { brief: BRIEF, title: "Qoder one", engine: "qoder" }));
    if (heard.startsWith("use a weird engine")) return reply(tool(id(), "work_start", { brief: BRIEF, title: "Weird", engine: "skynet" }));
    if (heard.startsWith("what models")) return reply(tool(id(), "models_list", {}));
    if (heard.startsWith("peek in shopkart")) return reply(tool(id(), "peek", { project: "Shopkart", path: "src" }));
    return reply(text("Got it."));
  });
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const MOCK = `http://127.0.0.1:${server.address().port}`;

const FOLDER = "sherpa-onnx-pocket-tts-int8-2026-01-26";
const state = join(home, "state");
mkdirSync(join(state, "tts", FOLDER), { recursive: true });
writeFileSync(join(state, "tts", FOLDER, "a.onnx"), "x");
const env = {
  OPSCODE_VOICE_HELPER: join(ROOT, "scripts/lib/fake-voice.mjs"), OPSCODE_FAKE_VOICE_LOG: join(home, "voice.log"),
  OPSCODE_TTS_URL: "http://127.0.0.1:1/unused", OPSCODE_TTS_FILES: "a.onnx", OPSCODE_TTS_WORKER: join(ROOT, "scripts/lib/fake-tts-worker.mjs"), OPSCODE_FAKE_TTS_LOG: join(home, "tts.log"), OPSCODE_FAKE_TTS_MS: "20",
  OPSCODE_VOICE_HOME: home, OPSCODE_QODER_BIN: join(home, "no-such-qoder"), OPSCODE_TTS_IDLE_MS: "400",
};
const waitFor = async (fn, ms = 8000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(40)) { const v = await fn(); if (v) return v; } return null; };
const rt = await startRuntime({ env, stateDir: state, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);
try {
  const C = await session(rt);
  const ok = async (m, p) => { const r = await C.call(m, p); if (r.error) throw new Error(`${m}: ${r.error.message}`); return r.result; };
  const ids = {};
  for (const [name, path] of [["Shopkart", shop], ["dealker-app", dApp], ["dealker-server", dSrv]]) ids[name] = (await ok("workspace.add", { path })).workspace.id;
  await ok("provider.set", { id: "anthropic", api_key: "sk-test-voice-5757", base_url: MOCK, model: "test-model" });
  // The person worked in Shopkart last: voice mode with no project picked starts there.
  const c0 = (await ok("chat.create", { workspace_id: ids.Shopkart })).chat;
  await ok("turn.submit", { workspace_id: ids.Shopkart, chat_id: c0.id, text: "hello" });
  await sleep(400);

  const started = await ok("voiceagent.start", { brain: { engine: "api" }, worker: { engine: "api" } });
  const S = started.session;
  t.check("voice mode starts without naming a project", !!S);
  t.check("start returns what it talks with and what new workers run on (the notch shows them at once)", started.picks?.brain?.engine === "api" && !!started.picks?.worker?.engine, JSON.stringify(started.picks));
  const ttsLog = () => { try { return readFileSync(join(home, "tts.log"), "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)); } catch { return []; } };
  t.check("the voice is loaded as soon as voice mode starts, before anything is said", !!(await waitFor(() => ttsLog().some((x) => x.got === "init"))) && !ttsLog().some((x) => x.got === "speak"), JSON.stringify(ttsLog()));
  const say = async (words) => { const before = brainReqs.length; await ok("voiceagent.say", { session: S, text: words }); await waitFor(() => brainReqs.length > before); await sleep(500); };
  const lastResult = () => results.at(-1) ?? "";

  await sleep(1200);
  const inits = ttsLog().filter((x) => x.got === "init").length;
  const pids = new Set(ttsLog().map((x) => x.pid));
  t.check("while voice mode is on the voice stays loaded (no unload between replies, even with a short idle time)", inits === 1 && pids.size === 1 && !ttsLog().some((x) => x.got === "exit"), JSON.stringify({ inits, pids: [...pids] }));
  await say("hello");
  const r0 = brainReqs.at(-1);
  t.check("its instructions: projects, folders and worker setup rules; current project = the one worked in last", r0.body.system.includes("PROJECTS AND FOLDERS") && r0.body.system.includes("WORKER SETUP") && r0.body.system.includes("Current project: Shopkart"), r0.body.system.slice(0, 300));
  t.check("its tools include the new ones", ["projects_list", "project_find", "folder_look", "folder_find", "project_add", "models_list"].every((x) => r0.body.tools.some((y) => y.name === x)));

  await say("which projects do I have");
  t.check("projects_list: every project with what it is", /Shopkart — .*next\.js.*Online shop/.test(lastResult()) && lastResult().includes("dealker-server") && lastResult().includes("dealker-app"), lastResult());

  await say("fix the login in deal car server, use high effort");
  const findRes = results.find((r) => r.includes("match")) ?? "";
  t.check("project_find turns 'deal car server' into dealker-server", findRes.startsWith('[result] project "dealker-server"'), findRes);
  const startRes = await waitFor(() => results.find((r) => r.includes("Started w")));
  t.check("work_start in another project, on the chosen effort", !!startRes && startRes.includes("in project dealker-server") && startRes.includes("high effort"), startRes);
  const chats = (await ok("chat.list", {})).chats;
  const wchat = chats.find((c) => c.title === "Server login");
  t.check("the worker's chat is in dealker-server with effort high", wchat?.workspace_id === ids["dealker-server"] && wchat?.effort === "high", JSON.stringify(wchat));
  const winfo = C.find("voiceagent.event", (p) => p.ev === "worker" && p.title === "Server login").at(-1)?.params;
  t.check("the worker event names its project and effort (for the notch and window)", winfo?.project === "dealker-server" && winfo?.effort === "high", JSON.stringify(winfo));

  await say("fix dealker");
  t.check("an unclear project is not guessed: the agent gets both names to ask", /could be: .*dealker-app.*dealker-server|could be: .*dealker-server.*dealker-app/.test(lastResult()), lastResult());

  await say("use qoder for this");
  t.check("an engine that is not installed is refused with the reason", /not installed/.test(lastResult()), lastResult());
  await say("use a weird engine");
  t.check("an unknown engine is refused", /Unknown engine/.test(lastResult()), lastResult());
  await say("what models can workers use");
  t.check("models_list names the default and the API key's model", /default for new workers/.test(lastResult()) && /api \(your API key\): test-model/.test(lastResult()), lastResult());

  await say("peek in shopkart src");
  t.check("peek in another project", lastResult().includes("settings.tsx"), lastResult());

  // Folders: add only after looking and a yes.
  await say("maybe add it, the billing tool");
  t.check("project_add without confirmed is refused (ask first)", /Ask the person first/.test(lastResult()), lastResult());
  await say("yes add it");
  t.check("project_add before folder_look is refused", /folder_look first/.test(lastResult()), lastResult());
  await say("check the billing tool folder in developer");
  const lookRes = await waitFor(() => results.find((r) => r.includes("folder:")));
  t.check("folder_find then folder_look: what the folder is", !!lookRes && lookRes.includes("billing-tool") && lookRes.includes("not a project yet") && lookRes.includes("rust") && lookRes.includes("PDF invoices"), lookRes);
  await say("yes add it");
  t.check("after looking and a yes, the folder is added", /Added\. The project is called "billing-tool"/.test(lastResult()), lastResult());
  const wsList = (await ok("workspace.list", {})).workspaces;
  t.check("it is a real project now, and the windows were told", wsList.some((w) => w.name === "billing-tool") && C.find("workspace.changed", (p) => p.workspaces?.some((w) => w.name === "billing-tool")).length > 0);

  await say("look in ssh");
  t.check("folder_look never reads .ssh", /private folder/.test(lastResult()) && !lastResult().includes("SECRET-KEY"), lastResult());
  await say("add the ssh folder");
  t.check("…and it cannot be added", /folder_look first|private/.test(lastResult()), lastResult());

  // ---- changing models mid-conversation (the notch's model chips) ----
  const picks0 = C.find("voiceagent.event", (p) => p.ev === "picks" && p.session === S)[0]?.params;
  t.check("start reports what it talks with and what new workers run on", picks0?.brain?.engine === "api" && picks0?.worker?.engine === "api", JSON.stringify(picks0));
  const p1 = await ok("voiceagent.pick", { session: S, brain: { engine: "api", effort: "high", model: "ignored-for-api" } });
  t.check("pick: what the voice agent talks with changes (an API key keeps its own model)", p1.brain?.engine === "api" && p1.brain?.effort === "high" && !p1.brain?.model, JSON.stringify(p1));
  const before = brainReqs.length;
  await say("are you still there");
  const after = brainReqs.slice(before);
  t.check("its next reply comes from a fresh chat on the new pick, starting with a recap (the conversation is kept)", after.length > 0 && after[0].body.messages.length === 1 && /recap|earlier|so far/i.test(after[0].lastText), after[0]?.lastText?.slice(0, 300));
  const p2 = await ok("voiceagent.pick", { session: S, worker: { engine: "api", effort: "low" } });
  t.check("pick: new workers' model and effort", p2.worker?.engine === "api" && p2.worker?.effort === "low" && !p2.worker?.default, JSON.stringify(p2));
  await say("fix the login in deal car server, use high effort");
  const p3 = await ok("voiceagent.pick", { session: S, worker: {} });
  t.check("pick: back to the default for new workers", p3.worker?.default === true, JSON.stringify(p3));
  const bad = await C.call("voiceagent.pick", { session: S, brain: { engine: "skynet" } });
  t.check("pick: an unknown engine is refused", !!bad.error, JSON.stringify(bad.error ?? bad.result));
  const missing = await C.call("voiceagent.pick", { session: S, worker: { engine: "qoder" } });
  t.check("pick: an engine that is not installed is refused with the reason", /not installed/.test(missing.error?.message ?? ""), missing.error?.message);
  t.check("every change is announced (for the notch and window)", C.find("voiceagent.event", (p) => p.ev === "picks" && p.session === S).length >= 4);

  await ok("voiceagent.stop", { session: S });
} finally {
  server.close();
  await rt.stop?.();
}
process.exit(t.finish());
