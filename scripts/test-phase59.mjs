// Phase 59: computer use through Accessibility, the runtime side (src/runtime/hands.ts) with a stand-in helper
// (scripts/lib/fake-hands.mjs). Covers: instant commands (no AI), the risk rules, which steps ask / run / are refused, learned
// replays (what is kept, what never is, replay stops when the app changed), and a real runtime: a chat whose model reads an
// app and clicks without an approval card, a risky click that does ask, computer.instant, the replay RPCs, and the fallback
// to the screenshot tools when Accessibility is not allowed.
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const ROOT = new URL("..", import.meta.url).pathname;
const H = await import(join(ROOT, "dist/runtime/hands.js"));
const { ComputerStore } = await import(join(ROOT, "dist/runtime/computer.js"));
const FAKE = join(ROOT, "scripts/lib/fake-hands.mjs");
const base = mkdtempSync(join(tmpdir(), "opscode-p59-"));
const hlog = join(base, "hands.log");
const calls = () => (existsSync(hlog) ? readFileSync(hlog, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);

// ---- 1. instant commands -------------------------------------------------------------------------------------------------
{
  const p = (s) => H.parseInstant(s);
  t.check("open chrome -> Google Chrome", p("open chrome")?.kind === "open" && p("open chrome").target === "Google Chrome");
  t.check("polite forms: 'please launch spotify for me'", p("please launch spotify for me")?.target === "Spotify");
  t.check("a site by name: 'open youtube'", p("open youtube")?.target === "https://www.youtube.com");
  t.check("an address: 'go to github.com/trending'", p("go to github.com/trending")?.target === "https://github.com/trending");
  t.check("quit slack / switch to notes", p("quit slack")?.kind === "quit" && p("quit slack").target === "Slack" && p("switch to notes")?.kind === "activate");
  t.check("speech filler around a command is ignored", ["You... Open Chrome.", "uh, open chrome please", "Hey Opscode, open Chrome", "okay so open chrome"].every((x) => p(x)?.target === "Google Chrome"));
  t.check("not instant: work words ('run the tests', 'start the server', 'show my workers')", [p("please run the tests"), p("start the server"), p("show my workers"), p("open my workers"), p("switch to my projects")].every((x) => x === null));
  t.check("not instant: anything that needs thinking", [p("open the file I was editing"), p("open chrome and search for usb hubs"), p("close this tab"), p("open my project in vs code please now"), p("what is open")].every((x) => x === null));
}

// ---- 2. risk rules -----------------------------------------------------------------------------------------------------------
{
  t.check("risky words", H.risky("Place order") && H.risky("Delete") && H.risky("Send message") && !H.risky("Add to list") && !H.risky("Search"));
  t.check("risky keys: cmd+q, cmd+w, cmd+delete, cmd+opt+esc", H.riskyKey("cmd+q") && H.riskyKey("cmd+w") && H.riskyKey("cmd+delete") && H.riskyKey("cmd+option+esc") && !H.riskyKey("cmd+t") && !H.riskyKey("return"));
  t.check("sensitive text: card numbers and password: lines", H.sensitiveText("4111 1111 1111 1111") && H.sensitiveText("password: hunter2") && !H.sensitiveText("usb c hub under 30"));
}

// ---- 3. the tools' decisions -----------------------------------------------------------------------------------------------
const store = new ComputerStore(join(base, "store"));
store.setEnabled(true);
process.env.OPSCODE_FAKE_HANDS_LOG = hlog;
const hands = new H.Hands(FAKE, join(base, "hands"));
{
  const steps = [];
  const tools = H.handsTools(hands, store, { key: "chat1", onStep: (s, ok) => steps.push({ step: s, ok }) });
  const T = (n) => tools.find((x) => x.def.name === n);
  t.check("tools: see, click, type, key, scroll, menu, open, apps", ["computer_see", "computer_click", "computer_type", "computer_key", "computer_scroll", "computer_menu", "computer_open", "computer_apps"].every((n) => T(n)));
  t.check("clicking before looking is refused", (await T("computer_click").gate({ id: 1 })).rule === "deny");
  const see = await T("computer_see").run({}, { signal: new AbortController().signal });
  t.check("see returns the numbered list", !see.is_error && see.output.includes('[1] button "Add one"'), see.output);
  t.check("a plain click runs without asking", (await T("computer_click").gate({ id: 1 })).rule === "auto");
  const g4 = await T("computer_click").gate({ id: 4 });
  t.check("a risky button (Buy now) asks, and says why", g4.rule === "ask" && /buys, sends, deletes/.test(g4.detail ?? ""), JSON.stringify(g4));
  const clk = await T("computer_click").run({ id: 1 }, { signal: new AbortController().signal });
  t.check("click result says the window changed and gives the new list", !clk.is_error && /Done: pressed "Add one"/.test(clk.output) && /window changed/.test(clk.output), clk.output);
  t.check("typing into a password field is refused", (await T("computer_type").gate({ id: 3, text: "x" })).rule === "deny");
  t.check("typing a card number asks", (await T("computer_type").gate({ id: 2, text: "4111 1111 1111 1111" })).rule === "ask");
  t.check("typing a search runs", (await T("computer_type").gate({ id: 2, text: "usb c hub" })).rule === "auto");
  const ty = await T("computer_type").run({ id: 2, text: "usb c hub" }, { signal: new AbortController().signal });
  t.check("type result says what the field holds", /The field now has: "usb c hub"/.test(ty.output), ty.output);
  t.check("cmd+q asks, cmd+t runs", (await T("computer_key").gate({ combo: "cmd+q" })).rule === "ask" && (await T("computer_key").gate({ combo: "cmd+t" })).rule === "auto");
  t.check("a risky menu item asks", (await T("computer_menu").gate({ path: "File > Delete" })).rule === "ask" && (await T("computer_menu").gate({ path: "File > New Window" })).rule === "auto");
  t.check("terminals and password managers are refused", (await T("computer_see").gate({ app: "Terminal" })).rule === "deny" && (await T("computer_see").gate({ app: "1Password" })).rule === "deny");
  store.setRule({ name: "Mail", bundle_id: "" }, "never");
  t.check("an app the person set to never is refused", (await T("computer_see").gate({ app: "Mail" })).rule === "deny");
  t.check("each confirmed step is reported for learning", steps.length === 2 && steps[0].step.verb === "press" && steps[0].step.args[0] === "Add one" && steps[1].step.verb === "type" && steps.every((s) => s.ok), JSON.stringify(steps));

  // ---- 4. learned replays ------------------------------------------------------------------------------------------------
  const rs = new H.ReplayStore(join(base, "replays"));
  t.check("a plain task is kept", rs.learn("Please add one item and search for USB hubs", steps));
  t.check("…found again by its words (politeness ignored)", !!rs.find("add one item and search for usb hubs"));
  t.check("a task with a failed or unconfirmed step is not kept", !rs.learn("try again thing", [{ step: steps[0].step, ok: false }]));
  t.check("a risky step is never kept", !rs.learn("buy the hub", [{ step: { verb: "press", app: "Shop", args: ["Buy now", "AXButton"] }, ok: true }]));
  t.check("cmd+q, quit and card numbers are never kept", !rs.learn("close up", [{ step: { verb: "key", args: ["cmd+q"] }, ok: true }]) && !rs.learn("quit shop", [{ step: { verb: "quit", args: ["Shop"] }, ok: true }]) && !rs.learn("pay it", [{ step: { verb: "type", app: "Shop", args: ["Card", "4111111111111111"] }, ok: true }]));
  t.check("'this/that' requests are never kept (they mean the screen right now)", !rs.learn("click that button", steps));
  const before = calls().length;
  const rp = await H.runReplay(hands, store, rs.find("add one item and search for usb hubs"));
  const used = calls().slice(before).map((c) => c.verb);
  t.check("replay runs the steps with no AI (press by name, find the field, type)", rp.ok && rp.done === 2 && used.includes("press-label") && used.includes("type"), JSON.stringify({ rp, used }));
  process.env.OPSCODE_FAKE_HANDS_STALE = "1";
  const stale = await H.runReplay(hands, store, rs.find("add one item and search for usb hubs"));
  delete process.env.OPSCODE_FAKE_HANDS_STALE;
  t.check("replay stops when nothing changes (the app changed since it was learned)", !stale.ok && stale.done === 0 && /Nothing changed/.test(stale.error ?? ""), JSON.stringify(stale));
  t.check("forget removes a learned task", rs.forget("add one item and search for usb hubs") && !rs.find("add one item and search for usb hubs"));
}

// ---- 5. a real runtime ----------------------------------------------------------------------------------------------------
const sse = (events) => events.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
const text = (s) => sse([{ type: "content_block_start", index: 0, content_block: { type: "text", text: "" } }, { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: s } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "end_turn" } }]);
const tool = (id, name, input) => sse([{ type: "content_block_start", index: 0, content_block: { type: "tool_use", id, name } }, { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: JSON.stringify(input) } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "tool_use" } }]);
const reqs = [];
const server = createServer((req, res) => {
  let body = "";
  req.on("data", (c) => (body += c));
  req.on("end", () => {
    const b = JSON.parse(body);
    reqs.push(b);
    const msgs = b.messages;
    const first = typeof msgs[0].content === "string" ? msgs[0].content : msgs[0].content.map((x) => x.text ?? "").join(" ");
    const n = msgs.filter((m) => m.role === "assistant").length;
    const reply = (s) => { res.writeHead(200, { "content-type": "text/event-stream" }); res.end(s); };
    if (/buy it/.test(first)) return reply(n === 0 ? tool("a1", "computer_see", {}) : n === 1 ? tool("a2", "computer_click", { id: 4 }) : text("Done."));
    if (/add one/.test(first)) return reply(n === 0 ? tool("b1", "computer_see", {}) : n === 1 ? tool("b2", "computer_click", { id: 1 }) : text("Added one."));
    reply(text("ok"));
  });
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const MOCK = `http://127.0.0.1:${server.address().port}`;
const env = { OPSCODE_HANDS_BIN: FAKE, OPSCODE_FAKE_HANDS_LOG: hlog, OPSCODE_COMPUTER_DRIVER: "mock", OPSCODE_COMPUTER_MOCK_LOG: join(base, "mock.log"), OPSCODE_COMPUTER_MOCK_FRONT: join(base, "front.txt") };
const rt = await startRuntime({ env });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
try {
  const C = await session(rt);
  const ok = async (m, p) => { const r = await C.call(m, p); if (r.error) throw new Error(`${m}: ${r.error.message}`); return r.result; };
  const proj = mkdtempSync(join(tmpdir(), "opscode-p59-proj-"));
  const wid = (await ok("workspace.add", { path: proj })).workspace.id;
  await ok("provider.set", { id: "anthropic", api_key: "sk-test-hands-5959", base_url: MOCK, model: "test-model" });
  const off = await ok("computer.instant", { text: "You... Open Chrome." });
  t.check("opening an app works even with computer use off (speech filler ignored)", off.handled && off.ok && off.say === "Opened Google Chrome.", JSON.stringify(off));
  await ok("computer.set_enabled", { enabled: true });
  const b0 = calls().length;
  const on = await ok("computer.instant", { text: "open chrome" });
  t.check("instant 'open chrome': done with no AI, says so", on.handled && on.ok && on.say === "Opened Google Chrome." && calls().slice(b0).some((c) => c.verb === "open" && c.rest[0] === "Google Chrome") && reqs.length === 0, JSON.stringify(on));
  t.check("not an instant command -> handled false (goes to the AI)", (await ok("computer.instant", { text: "find me a usb hub under 30 dollars" })).handled === false);
  t.check("quitting a terminal is refused", /can't control/.test((await ok("computer.instant", { text: "quit terminal" })).say));

  const chat = (await ok("chat.create", { workspace_id: wid, mode: "supervised" })).chat;
  await ok("turn.submit", { workspace_id: wid, chat_id: chat.id, text: "add one to the basket" });
  for (let i = 0; i < 80 && !C.find("turn.event", (p) => p.chat_id === chat.id && p.type === "completed").length; i++) await sleep(100);
  const evs = C.find("turn.event", (p) => p.chat_id === chat.id).map((m) => m.params);
  const toolNames = (reqs[0]?.tools ?? []).map((x) => x.name);
  t.check("a chat gets the new tools (and a screenshot), not click-by-position", toolNames.includes("computer_see") && toolNames.includes("computer_click") && toolNames.includes("computer_screenshot") && !toolNames.includes("computer_drag"), toolNames.filter((n) => n.startsWith("computer")).join(","));
  t.check("…even in a supervised chat, reading and a plain click run without an approval card", evs.some((e) => e.type === "completed") && !evs.some((e) => e.type === "approval_request"), evs.map((e) => e.type).join(","));
  t.check("the model got the click's result with the new list", reqs.some((r) => JSON.stringify(r.messages).includes("Done: pressed \\\"Add one\\\"")));

  const chat2 = (await ok("chat.create", { workspace_id: wid })).chat;
  await ok("turn.submit", { workspace_id: wid, chat_id: chat2.id, text: "buy it now" });
  let ask;
  for (let i = 0; i < 80 && !(ask = C.find("turn.event", (p) => p.chat_id === chat2.id && p.type === "approval_request")[0]); i++) await sleep(100);
  const card = ask ? C.find("turn.event", (p) => p.chat_id === chat2.id && p.type === "tool_start" && p.call_id === ask.params.call_id)[0]?.params : null;
  t.check("a risky click asks first, saying what and why", !!ask && /Buy now/.test(card?.summary ?? "") && /buys, sends, deletes/.test(card?.detail ?? ""), JSON.stringify(card));
  if (ask) await ok("turn.approve", { turn_id: ask.params.turn_id, call_id: ask.params.call_id, allow: false });

  const ra = await ok("computer.request_access", {});
  t.check("Allow… when Accessibility already works: says granted, changes nothing", ra.granted === true && !calls().some((c) => c.verb === "ask-access"), JSON.stringify(ra));
  t.check("the permission shown comes from the helper that clicks (not from osascript)", ra.status?.permissions?.accessibility === true && calls().some((c) => c.verb === "check"));
  t.check("replay list RPC answers", Array.isArray((await ok("computer.replays.list", {})).replays));
} finally {
  server.close();
  await rt.stop?.();
}

// ---- 6. no Accessibility: the older screenshot tools stay -----------------------------------------------------------------
{
  const reqs2 = reqs.length;
  const rt2 = await startRuntime({ env: { ...env, OPSCODE_FAKE_HANDS_AX: "0", OPSCODE_FAKE_HANDS_SCREEN: "0" } });
  try {
    const C = await session(rt2);
    const ok = async (m, p) => { const r = await C.call(m, p); if (r.error) throw new Error(`${m}: ${r.error.message}`); return r.result; };
    const proj = mkdtempSync(join(tmpdir(), "opscode-p59-proj2-"));
    const wid = (await ok("workspace.add", { path: proj })).workspace.id;
    const srv2 = createServer((req, res) => { let b = ""; req.on("data", (c) => (b += c)); req.on("end", () => { reqs.push(JSON.parse(b)); res.writeHead(200, { "content-type": "text/event-stream" }); res.end(text("ok")); }); });
    await new Promise((r) => srv2.listen(0, "127.0.0.1", r));
    await ok("provider.set", { id: "anthropic", api_key: "sk-test-hands-5960", base_url: `http://127.0.0.1:${srv2.address().port}`, model: "test-model" });
    await ok("computer.set_enabled", { enabled: true });
    const chat = (await ok("chat.create", { workspace_id: wid })).chat;
    await ok("turn.submit", { workspace_id: wid, chat_id: chat.id, text: "hello" });
    for (let i = 0; i < 60 && reqs.length === reqs2; i++) await sleep(100);
    const names = (reqs.at(-1)?.tools ?? []).map((x) => x.name);
    const ask = await ok("computer.request_access", {});
    const askScreen = await ok("computer.request_access", { pane: "screen" });
    t.check("Allow… for Screen Recording asks macOS (ask-screen) when it is not granted", askScreen.granted === false && calls().some((c) => c.verb === "ask-screen"), JSON.stringify(askScreen));
    t.check("Allow… when it does not work: asks macOS again (ask-access) and reports not granted yet", ask.granted === false && calls().some((c) => c.verb === "ask-access"), JSON.stringify(ask));
    t.check("without Accessibility a chat keeps the screenshot tools", names.includes("computer_screenshot") && names.includes("computer_click") && !names.includes("computer_see"), names.filter((n) => n.startsWith("computer")).join(","));
    srv2.close();
  } finally { await rt2.stop?.(); }
}
rmSync(base, { recursive: true, force: true });
process.exit(t.finish());
