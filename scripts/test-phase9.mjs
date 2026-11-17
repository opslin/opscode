// Computer use: the on/off switch, per-app rules, the denylist, approvals, the
// "app changed after you asked" check, screenshots reaching the model, and
// persistence. Uses the mock driver (no real mouse, keyboard or screen is touched).

import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, statSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, waitFor } from "./lib/harness.mjs";

const t = reporter();
const E = { INVALID: -32602, NOT_FOUND: -32004 };
const code = (res) => res.error?.code;
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 240);

// ---- mock Anthropic + OpenAI ---------------------------------------------------------
const llm = { requests: [], script: [] };
const sse = (evs) => evs.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
const textEv = (s) => [{ type: "content_block_start", index: 0, content_block: { type: "text", text: "" } }, { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: s } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "end_turn" } }];
const toolEv = (id, name, input) => [{ type: "content_block_start", index: 0, content_block: { type: "tool_use", id, name } }, { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: JSON.stringify(input) } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "tool_use" } }];
const oaiTool = (id, name, args) => `data: ${JSON.stringify({ choices: [{ delta: { tool_calls: [{ index: 0, id, function: { name, arguments: JSON.stringify(args) } }] }, finish_reason: "tool_calls" }] })}\n\ndata: [DONE]\n\n`;
const oaiText = (s) => `data: ${JSON.stringify({ choices: [{ delta: { content: s }, finish_reason: "stop" }] })}\n\ndata: [DONE]\n\n`;
const llmServer = createServer((req, res) => {
  let b = "";
  req.on("data", (c) => (b += c));
  req.on("end", () => {
    const body = JSON.parse(b);
    llm.requests.push({ ...body, __path: req.url });
    const step = llm.script.shift();
    res.writeHead(200, { "content-type": "text/event-stream" }).end(step ?? (req.url.includes("chat/completions") ? oaiText("ok") : sse(textEv("ok"))));
  });
});
await new Promise((r) => llmServer.listen(0, "127.0.0.1", r));
const step = (evs) => llm.script.push(sse(evs));
const stepRaw = (s) => llm.script.push(s);

// ---- fixtures --------------------------------------------------------------------------
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p9-")));
const proj = join(base, "project");
mkdirSync(proj);
const logFile = join(base, "computer.log");
const frontFile = join(base, "front.txt");
const front = (name, bundle = "") => writeFileSync(frontFile, `${name}|${bundle}`);
const actions = () => (existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const clearLog = () => writeFileSync(logFile, "");
front("Notes", "com.apple.Notes");
clearLog();

const env = { OPSCODE_COMPUTER_DRIVER: "mock", OPSCODE_COMPUTER_MOCK_LOG: logFile, OPSCODE_COMPUTER_MOCK_FRONT: frontFile };
const stateDir = join(base, "state");
let rt = await startRuntime({ env, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  let C = await session(rt);
  const evs = (turn) => C.find("turn.event", (p) => p.turn_id === turn).map((n) => n.params);
  const finished = (turn) => evs(turn).some((e) => ["completed", "failed", "interrupted"].includes(e.type));
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  await C.call("provider.set", { id: "anthropic", api_key: "sk-test-1234", base_url: `http://127.0.0.1:${llmServer.address().port}`, model: "m" });
  const mkChat = async (mode) => (await C.call("chat.create", { workspace_id: wid, mode })).result.chat;
  const submit = async (chatId, text) => (await C.call("turn.submit", { workspace_id: wid, chat_id: chatId, text })).result.turn_id;
  const hasTool = (name) => llm.requests.at(-1).tools?.some((x) => x.name === name);
  const approve = (turn, call, allow) => C.call("turn.approve", { turn_id: turn, call_id: call, allow });
  const awaitApproval = (turn) => waitFor(() => evs(turn).some((e) => e.type === "approval_request"), 6000);
  const end = (turn, call) => evs(turn).find((e) => e.type === "tool_end" && e.call_id === call);
  const run = async (chat, text) => { const turn = await submit(chat.id, text); return turn; };

  // ---- status, switch ---------------------------------------------------------------------
  let res = await C.call("computer.status");
  let st = res.result?.status;
  t.check("status reports a supported (mock) driver, off by default", st?.supported === true && st.driver === "mock" && st.enabled === false, why(res));
  t.check("status lists permissions and the off-limits apps", st.permissions.accessibility === true && Array.isArray(st.denied) && st.denied.length >= 3);

  const chat = await mkChat("supervised");
  step(textEv("hi"));
  let turn = await run(chat, "hello");
  await waitFor(() => finished(turn), 8000);
  t.check("while off, no computer tool is offered", !hasTool("computer_screenshot") && !hasTool("computer_click"));
  t.check("…and the prompt doesn't mention it", !llm.requests.at(-1).system.includes("computer_*"));

  res = await C.call("computer.set_enabled", { enabled: true });
  t.check("computer.set_enabled(true)", res.result?.status?.enabled === true, why(res));
  t.check("computer.changed is broadcast", C.find("computer.changed", (p) => p.status.enabled === true).length === 1);
  res = await C.call("computer.set_enabled", { enabled: "yes" });
  t.check("bad param -> invalid", code(res) === E.INVALID, why(res));

  step(textEv("hi"));
  turn = await run(chat, "hello again");
  await waitFor(() => finished(turn), 8000);
  const names = llm.requests.at(-1).tools.map((x) => x.name);
  t.check("when on, all computer tools are offered", ["computer_screenshot", "computer_click", "computer_drag", "computer_scroll", "computer_type", "computer_key", "computer_list_apps", "computer_open_app"].every((n) => names.includes(n)), names.join(","));
  t.check("…and the prompt explains the rules", llm.requests.at(-1).system.includes("computer_*") && /password/i.test(llm.requests.at(-1).system));

  const readChat = await mkChat("read");
  step(textEv("hi"));
  turn = await run(readChat, "look");
  await waitFor(() => finished(turn), 8000);
  t.check("a read-only chat never gets computer tools", !hasTool("computer_screenshot") && !hasTool("computer_list_apps"));

  // ---- screenshot: asks, runs, the model gets the image --------------------------------------
  step(toolEv("s1", "computer_screenshot", {}));
  step(textEv("seen"));
  turn = await run(chat, "take a screenshot");
  t.check("a screenshot asks first and names the app", (await awaitApproval(turn)) && /in Notes/.test(evs(turn).find((e) => e.type === "tool_start")?.summary ?? ""), evs(turn).find((e) => e.type === "tool_start")?.summary);
  t.check("nothing ran before approval", actions().length === 0);
  await approve(turn, "s1", true);
  await waitFor(() => finished(turn), 8000);
  t.check("after approval the screenshot runs", actions().length === 1 && actions()[0].a === "screenshot");
  const followUp = llm.requests.at(-1);
  const resultBlock = followUp.messages.at(-1).content.find((b) => b.type === "tool_result");
  t.check("the model receives the screenshot as an image block", Array.isArray(resultBlock?.content) && resultBlock.content.some((b) => b.type === "image" && b.source?.media_type === "image/jpeg" && b.source.data.length > 20), JSON.stringify(resultBlock)?.slice(0, 200));
  t.check("the transcript never stores image data", !JSON.stringify((await C.call("turn.history", { chat_id: chat.id })).result.messages).includes("base64"));

  // ---- deny ------------------------------------------------------------------------------------
  clearLog();
  step(toolEv("d1", "computer_screenshot", {}));
  step(textEv("ok"));
  turn = await run(chat, "again");
  await awaitApproval(turn);
  await approve(turn, "d1", false);
  await waitFor(() => finished(turn), 8000);
  t.check("a denied action does nothing", actions().length === 0 && end(turn, "d1")?.is_error === true);

  // ---- needs a screenshot first; bounds ----------------------------------------------------------
  const chat2 = await mkChat("supervised"); // fresh chat -> fresh turn state
  step(toolEv("c0", "computer_click", { x: 10, y: 10 }));
  step(textEv("ok"));
  turn = await run(chat2, "click");
  await awaitApproval(turn);
  await approve(turn, "c0", true);
  await waitFor(() => finished(turn), 8000);
  t.check("clicking before any screenshot is refused", /screenshot first/i.test(end(turn, "c0")?.output ?? "") && actions().length === 0, end(turn, "c0")?.output);

  clearLog();
  step(toolEv("a1", "computer_screenshot", {}));
  step(toolEv("a2", "computer_click", { x: 5000, y: 10 }));
  step(toolEv("a3", "computer_click", { x: 640, y: 400, double: true }));
  step(textEv("done"));
  turn = await run(chat, "click things");
  for (const id of ["a1", "a2", "a3"]) { await waitFor(() => evs(turn).some((e) => e.type === "approval_request" && e.call_id === id), 6000); await approve(turn, id, true); }
  await waitFor(() => finished(turn), 8000);
  t.check("a click outside the screenshot is refused", /outside/.test(end(turn, "a2")?.output ?? ""), end(turn, "a2")?.output);
  const log = actions();
  t.check("a valid double-click reaches the driver once", log.filter((a) => a.a === "click").length === 1 && log.find((a) => a.a === "click").count === 2 && log.find((a) => a.a === "click").x === 640, JSON.stringify(log));

  // ---- other actions + validation ----------------------------------------------------------------
  clearLog();
  const many = [["k1", "computer_key", { keys: "cmd+shift+t" }], ["k2", "computer_key", { keys: "cmd+F13" }], ["t1", "computer_type", { text: "hello" }], ["t2", "computer_type", { text: "x".repeat(2001) }], ["sc", "computer_scroll", { x: 100, y: 100, dy: 5 }], ["dr", "computer_drag", { from_x: 1, from_y: 1, to_x: 50, to_y: 50 }]];
  step(toolEv("m0", "computer_screenshot", {}));
  for (const [id, name, input] of many) step(toolEv(id, name, input));
  step(textEv("done"));
  turn = await run(chat, "do many");
  for (const id of ["m0", ...many.map((m) => m[0])]) {
    await waitFor(() => evs(turn).some((e) => e.type === "approval_request" && e.call_id === id) || finished(turn), 6000);
    await approve(turn, id, true);
  }
  await waitFor(() => finished(turn), 10000);
  const acts = actions();
  t.check("key combo, type, scroll and drag reach the driver", acts.some((a) => a.a === "key" && a.combo === "cmd+shift+t") && acts.some((a) => a.a === "type" && a.text === "hello") && acts.some((a) => a.a === "scroll" && a.dy === 5) && acts.some((a) => a.a === "drag" && a.x2 === 50), JSON.stringify(acts));
  t.check("an unknown key is refused", end(turn, "k2")?.is_error === true && /unknown key/.test(end(turn, "k2")?.output ?? ""), end(turn, "k2")?.output);
  t.check("overlong text is refused", /2000/.test(end(turn, "t2")?.output ?? "") && !acts.some((a) => a.a === "type" && a.text.length > 100));

  // ---- the denylist: refused without even asking -----------------------------------------------------
  clearLog();
  front("Terminal", "com.apple.Terminal");
  step(toolEv("x1", "computer_screenshot", {}));
  step(textEv("ok"));
  turn = await run(chat, "screenshot the terminal");
  await waitFor(() => finished(turn), 8000);
  t.check("an off-limits app is refused with no approval card", !evs(turn).some((e) => e.type === "approval_request") && end(turn, "x1")?.is_error === true && /never controlled/.test(end(turn, "x1")?.output ?? ""), end(turn, "x1")?.output);
  t.check("…and nothing reaches the driver", actions().length === 0);
  for (const [n, b] of [["1Password", "com.1password.1password"], ["Keychain Access", "com.apple.keychainaccess"], ["Opscode", "com.opscode.app"], ["SomethingElse", "com.agilebits.onepassword7"]]) {
    front(n, b);
    step(toolEv("x2", "computer_key", { keys: "return" }));
    step(textEv("ok"));
    turn = await run(chat, `try ${n}`);
    await waitFor(() => finished(turn), 8000);
    t.check(`${n} is refused`, end(turn, "x2")?.is_error === true && actions().length === 0, end(turn, "x2")?.output);
  }
  res = await C.call("computer.rule.set", { name: "Terminal", bundle_id: "com.apple.Terminal", rule: "always" });
  t.check("an off-limits app cannot be allowed", code(res) === E.INVALID && /never be controlled/.test(res.error?.message ?? ""), why(res));

  // ---- rules --------------------------------------------------------------------------------------------
  front("Notes", "com.apple.Notes");
  res = await C.call("computer.rule.set", { name: "Notes", bundle_id: "com.apple.Notes", rule: "always" });
  t.check("computer.rule.set(always)", res.result?.status?.rules?.some((r) => r.name === "Notes" && r.rule === "always"), why(res));
  clearLog();
  step(toolEv("r1", "computer_screenshot", {}));
  step(textEv("ok"));
  turn = await run(chat, "screenshot");
  await waitFor(() => finished(turn), 8000);
  t.check("an always-allowed app runs without asking", !evs(turn).some((e) => e.type === "approval_request") && actions().length === 1 && end(turn, "r1")?.is_error === false);

  await C.call("chat.set_mode", { chat_id: chat.id, mode: "full" });
  front("Safari", "com.apple.Safari");
  step(toolEv("r2", "computer_screenshot", {}));
  step(textEv("ok"));
  turn = await run(chat, "screenshot in full mode");
  t.check("Full access still asks for an app without a rule", await awaitApproval(turn));
  await approve(turn, "r2", false);
  await waitFor(() => finished(turn), 8000);
  await C.call("chat.set_mode", { chat_id: chat.id, mode: "supervised" });

  res = await C.call("computer.rule.set", { name: "Safari", bundle_id: "com.apple.Safari", rule: "never" });
  t.check("computer.rule.set(never)", res.result?.status?.rules?.find((r) => r.name === "Safari")?.rule === "never", why(res));
  clearLog();
  step(toolEv("r3", "computer_screenshot", {}));
  step(textEv("ok"));
  turn = await run(chat, "screenshot safari");
  await waitFor(() => finished(turn), 8000);
  t.check("a blocked app is refused without asking", !evs(turn).some((e) => e.type === "approval_request") && /blocked/.test(end(turn, "r3")?.output ?? "") && actions().length === 0, end(turn, "r3")?.output);
  res = await C.call("computer.rule.set", { name: "Safari", bundle_id: "com.apple.Safari", rule: "always" });
  t.check("changing a rule updates it in place (no duplicate)", res.result?.status?.rules?.filter((r) => r.name === "Safari").length === 1 && res.result.status.rules.find((r) => r.name === "Safari").rule === "always", why(res));
  res = await C.call("computer.rule.set", { name: "", rule: "always" });
  t.check("empty app name -> invalid", code(res) === E.INVALID, why(res));
  res = await C.call("computer.rule.set", { name: "X", rule: "sometimes" });
  t.check("unknown rule value -> invalid", code(res) === E.INVALID, why(res));
  res = await C.call("computer.rule.remove", { id: "com.apple.safari" });
  t.check("computer.rule.remove", res.result?.status?.rules?.every((r) => r.name !== "Safari"), why(res));
  res = await C.call("computer.rule.remove", { id: "com.apple.safari" });
  t.check("remove twice -> not found", code(res) === E.NOT_FOUND, why(res));
  res = await C.call("computer.apps");
  t.check("computer.apps flags off-limits apps and shows rules", res.result?.apps?.find((a) => a.name === "Terminal")?.denied === true && res.result.apps.find((a) => a.name === "Notes")?.rule === "always", why(res));

  // ---- the app changes while the approval is pending ----------------------------------------------------
  await C.call("computer.rule.remove", { id: "com.apple.notes" });
  front("Notes", "com.apple.Notes");
  clearLog();
  step(toolEv("sw", "computer_screenshot", {}));
  step(textEv("ok"));
  turn = await run(chat, "screenshot, but the app changes");
  await awaitApproval(turn);
  front("Safari", "com.apple.Safari"); // the user (or something else) switched apps while the card was open
  await approve(turn, "sw", true);
  await waitFor(() => finished(turn), 8000);
  t.check("approval for one app is not used on another", /changed/.test(end(turn, "sw")?.output ?? "") && actions().length === 0, end(turn, "sw")?.output);
  front("Notes", "com.apple.Notes");

  // ---- list apps / open app --------------------------------------------------------------------------------
  step(toolEv("l1", "computer_list_apps", {}));
  step(textEv("ok"));
  turn = await run(chat, "what is running");
  await waitFor(() => finished(turn), 8000);
  const listed = end(turn, "l1")?.output ?? "";
  t.check("list_apps runs without asking and hides off-limits apps", !evs(turn).some((e) => e.type === "approval_request") && listed.includes("Safari") && !listed.includes("Terminal"), listed);

  clearLog();
  for (const [id, name] of [["o1", "Safari"], ["o2", "-a evil"], ["o3", "Terminal"], ["o4", "x; rm -rf ~"]]) {
    step(toolEv(id, "computer_open_app", { name }));
    step(textEv("ok"));
    turn = await run(chat, `open ${name}`);
    await waitFor(() => evs(turn).some((e) => e.type === "approval_request") || finished(turn), 6000);
    if (evs(turn).some((e) => e.type === "approval_request")) await approve(turn, id, true);
    await waitFor(() => finished(turn), 8000);
    if (id === "o1") t.check("open_app asks, then opens", end(turn, id)?.is_error === false && actions().some((a) => a.a === "open" && a.name === "Safari"), end(turn, id)?.output);
    else t.check(`open_app refuses “${name}”`, end(turn, id)?.is_error === true && !actions().some((a) => a.name === name), end(turn, id)?.output);
  }

  // ---- old screenshots are dropped from what is re-sent ------------------------------------------------------
  await C.call("computer.rule.set", { name: "Notes", bundle_id: "com.apple.Notes", rule: "always" });
  for (let i = 0; i < 4; i++) step(toolEv(`p${i}`, "computer_screenshot", {}));
  step(textEv("done"));
  turn = await run(chat, "four screenshots");
  await waitFor(() => finished(turn), 10000);
  const last = llm.requests.at(-1);
  const imgs = last.messages.flatMap((m) => (Array.isArray(m.content) ? m.content : [])).flatMap((b) => (b.type === "tool_result" && Array.isArray(b.content) ? b.content : [])).filter((b) => b.type === "image");
  t.check("only the newest two screenshots are re-sent", imgs.length === 2, `${imgs.length} images`);

  // ---- OpenAI-compatible providers get the image as a user message ----------------------------------------------
  await C.call("provider.set", { id: "openai", api_key: "sk-test-5678", base_url: `http://127.0.0.1:${llmServer.address().port}`, model: "m" });
  await C.call("provider.select", { id: "openai" });
  stepRaw(oaiTool("oc1", "computer_screenshot", {}));
  stepRaw(oaiText("seen"));
  turn = await run(chat, "openai screenshot");
  await waitFor(() => finished(turn), 8000);
  const oreq = llm.requests.at(-1);
  const imgMsg = oreq.messages.find((m) => m.role === "user" && Array.isArray(m.content) && m.content.some((p) => p.type === "image_url"));
  t.check("openai: tool message is text and the image follows as a user message", oreq.messages.some((m) => m.role === "tool" && typeof m.content === "string") && imgMsg?.content.find((p) => p.type === "image_url").image_url.url.startsWith("data:image/jpeg;base64,"), JSON.stringify(oreq.messages.at(-1))?.slice(0, 160));
  await C.call("provider.select", { id: "anthropic" });

  // ---- persistence + file permissions ------------------------------------------------------------------------------
  t.check("computer.json is private (0600)", (statSync(join(stateDir, "computer.json")).mode & 0o777) === 0o600);
  C.close();
  await rt.stop();
  rt = await startRuntime({ env, stateDir, keepState: true });
  C = await session(rt);
  res = await C.call("computer.status");
  t.check("the switch and rules survive a restart", res.result?.status?.enabled === true && res.result.status.rules.some((r) => r.name === "Notes" && r.rule === "always"), why(res));
  await C.call("computer.set_enabled", { enabled: false });
  res = await C.call("computer.status");
  t.check("computer.set_enabled(false)", res.result?.status?.enabled === false);
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  llmServer.close();
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
