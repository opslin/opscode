// Chats and permission modes: several chats per project, persistence across a
// restart, per-chat events, and what each mode lets an agent do.

import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, statSync, writeFileSync, readdirSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, sleep, startRuntime, waitFor } from "./lib/harness.mjs";

const t = reporter();
const E = { INVALID: -32602, NOT_FOUND: -32004, CONFLICT: -32009 };
const code = (res) => res.error?.code;
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 200);

// ---- mock Anthropic --------------------------------------------------------------
const llm = { requests: [], script: [] };
const sse = (evs) => evs.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
const textEv = (s) => [{ type: "content_block_start", index: 0, content_block: { type: "text", text: "" } }, { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: s } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "end_turn" } }];
const toolEv = (id, name, input) => [{ type: "content_block_start", index: 0, content_block: { type: "tool_use", id, name } }, { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: JSON.stringify(input) } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "tool_use" } }];
const llmServer = createServer((req, res) => {
  let b = "";
  req.on("data", (c) => (b += c));
  req.on("end", () => {
    llm.requests.push(JSON.parse(b));
    const step = llm.script.shift();
    res.writeHead(200, { "content-type": "text/event-stream" }).end(step?.sse ?? sse(textEv("ok")));
  });
});
await new Promise((r) => llmServer.listen(0, "127.0.0.1", r));
const step = (evs) => llm.script.push({ sse: sse(evs) });

const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p7-")));
const projA = join(base, "a");
const projB = join(base, "b");
mkdirSync(projA);
mkdirSync(projB);
writeFileSync(join(projA, "README.md"), "readme\n");
const stateDir = join(base, "state");

let rt = await startRuntime({ stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  let C = await session(rt);
  const evs = (turn) => C.find("turn.event", (p) => p.turn_id === turn).map((n) => n.params);
  const finished = (turn) => evs(turn).some((e) => ["completed", "failed", "interrupted"].includes(e.type));
  const last = (turn) => evs(turn).at(-1);
  const wA = (await C.call("workspace.add", { path: projA })).result.workspace.id;
  const wB = (await C.call("workspace.add", { path: projB })).result.workspace.id;

  // ---- creating and listing -------------------------------------------------------------
  let res = await C.call("chat.list", { workspace_id: wA });
  t.check("no chats at first", res.result?.chats?.length === 0, why(res));
  res = await C.call("chat.create", { workspace_id: wA });
  const c1 = res.result?.chat;
  t.check("chat.create uses the default mode (supervised)", c1?.mode === "supervised" && c1.workspace_id === wA && c1.title === "", why(res));
  res = await C.call("chat.create", { workspace_id: wA, mode: "read" });
  const c2 = res.result?.chat;
  t.check("chat.create with a mode", c2?.mode === "read", why(res));
  res = await C.call("chat.create", { workspace_id: "nope" });
  t.check("chat for an unknown project -> not found", code(res) === E.NOT_FOUND, why(res));
  res = await C.call("chat.create", { workspace_id: wA, mode: "yolo" });
  t.check("unknown mode refused", code(res) === E.INVALID, why(res));
  t.check("chat.changed is broadcast", C.find("chat.changed", () => true).length >= 2);

  res = await C.call("settings.set", { patch: { default_mode: "auto_edits" } });
  t.check("default_mode setting", res.result?.settings?.default_mode === "auto_edits", why(res));
  res = await C.call("settings.set", { patch: { default_mode: "anything" } });
  t.check("bad default_mode refused", code(res) === E.INVALID, why(res));
  res = await C.call("chat.create", { workspace_id: wB });
  t.check("new chats follow default_mode", res.result?.chat?.mode === "auto_edits", why(res));
  const cB = res.result.chat;
  await C.call("settings.set", { patch: { default_mode: "supervised" } });

  // ---- turns per chat -----------------------------------------------------------------------
  res = await C.call("turn.submit", { workspace_id: wA, chat_id: c1.id, text: "first chat: " + "word ".repeat(300) });
  const t1 = res.result?.turn_id;
  t.check("turn.submit returns chat_id", res.result?.chat_id === c1.id, why(res));
  res = await C.call("turn.submit", { workspace_id: wA, chat_id: c1.id, text: "again" });
  t.check("second turn in the same chat -> conflict", code(res) === E.CONFLICT, why(res));
  res = await C.call("turn.submit", { workspace_id: wA, chat_id: c2.id, text: "second chat" });
  const t2 = res.result?.turn_id;
  t.check("another chat in the same project runs at the same time", !!t2, why(res));
  res = await C.call("chat.list", { workspace_id: wA });
  t.check("chat.list reports running chats", res.result?.running?.includes(c1.id), why(res));
  t.check("events carry chat_id", await waitFor(() => evs(t1).some((e) => e.type === "delta" && e.chat_id === c1.id), 4000));
  await C.call("turn.interrupt", { turn_id: t1 });
  t.check("first chat stops", await waitFor(() => finished(t1) && last(t1).type === "interrupted", 4000));
  t.check("second chat completes independently", await waitFor(() => finished(t2) && last(t2).type === "completed", 8000));
  res = await C.call("turn.history", { chat_id: c2.id });
  t.check("history is per chat", res.result?.messages?.length === 2 && res.result.messages[0].text === "second chat" && res.result.chat_id === c2.id, why(res));
  res = await C.call("turn.history", { chat_id: c2.id, workspace_id: wB });
  t.check("chat from another project -> not found", code(res) === E.NOT_FOUND, why(res));
  res = await C.call("turn.history", {});
  t.check("history needs chat_id or workspace_id", code(res) === E.INVALID, why(res));
  res = await C.call("turn.submit", { workspace_id: wB, chat_id: c1.id, text: "wrong project" });
  t.check("submitting to another project's chat -> not found", code(res) === E.NOT_FOUND, why(res));

  res = await C.call("chat.list", { workspace_id: wA });
  const titles = Object.fromEntries(res.result.chats.map((c) => [c.id, c.title]));
  t.check("chats are titled after their first message", titles[c1.id].startsWith("first chat:") && titles[c2.id] === "second chat", JSON.stringify(titles));
  res = await C.call("chat.rename", { chat_id: c2.id, title: "  Renamed  " });
  t.check("chat.rename trims", res.result?.chat?.title === "Renamed", why(res));
  res = await C.call("chat.set_mode", { chat_id: c2.id, mode: "full" });
  t.check("chat.set_mode", res.result?.chat?.mode === "full", why(res));
  res = await C.call("chat.set_mode", { chat_id: "nope", mode: "full" });
  t.check("set_mode on unknown chat -> not found", code(res) === E.NOT_FOUND, why(res));
  await C.call("chat.set_mode", { chat_id: c2.id, mode: "read" });

  // no chat_id -> most recent chat
  res = await C.call("turn.submit", { workspace_id: wA, text: "continues the latest" });
  const t3 = res.result?.turn_id;
  await waitFor(() => finished(t3), 8000);
  t.check("without chat_id the most recent chat continues", res.result?.chat_id === c2.id, why(res));
  res = await C.call("turn.submit", { workspace_id: wB, text: "first in B" });
  t.check("a project with no chat gets one on first submit", res.result?.chat_id && res.result.chat_id !== cB.id ? true : res.result?.chat_id === cB.id, why(res));
  await waitFor(() => finished(res.result.turn_id), 8000);

  // ---- persistence across restart -------------------------------------------------------------
  const before = (await C.call("chat.list", {})).result.chats.length;
  res = await C.call("turn.submit", { workspace_id: wA, chat_id: c1.id, text: "long one " + "word ".repeat(600) });
  const tLong = res.result.turn_id;
  await waitFor(() => evs(tLong).some((e) => e.type === "delta"), 4000);
  C.close();
  const exit = await rt.stop();
  t.check("runtime stops cleanly mid-turn", exit === "code=0 signal=null", exit);
  const files = readdirSync(join(stateDir, "chats"));
  t.check("transcripts are files in the private chats dir (0600)", files.length >= 2 && files.every((f) => (statSync(join(stateDir, "chats", f)).mode & 0o777) === 0o600), files.join(","));
  rt = await startRuntime({ stateDir, keepState: true });
  C = await session(rt);
  res = await C.call("chat.list", {});
  t.check("chats survive a restart", res.result.chats.length === before, `${res.result.chats.length} vs ${before}`);
  t.check("nothing is running after a restart", res.result.running.length === 0);
  res = await C.call("turn.history", { chat_id: c2.id });
  t.check("transcripts survive a restart", res.result?.messages?.[0]?.text === "second chat" && res.result.messages.length === 4, why(res));
  res = await C.call("turn.history", { chat_id: c1.id });
  t.check("a reply cut off by the restart loads as interrupted", res.result?.messages?.at(-1)?.status === "interrupted", why(res));
  res = await C.call("chat.list", { workspace_id: wA });
  t.check("title, mode and ordering survive", res.result.chats.find((c) => c.id === c2.id)?.title === "Renamed" && res.result.chats.find((c) => c.id === c2.id).mode === "read");

  // ---- permission modes ---------------------------------------------------------------------------
  const wsA = await C.call("workspace.list");
  const apiKey = "sk-test-1234";
  await C.call("provider.set", { id: "anthropic", api_key: apiKey, base_url: `http://127.0.0.1:${llmServer.address().port}`, model: "m" });
  const toolNames = () => llm.requests.at(-1).tools.map((x) => x.name).sort();
  const submit = async (chatId, text) => (await C.call("turn.submit", { workspace_id: wA, chat_id: chatId, text })).result.turn_id;

  // read: write/command tools are not even offered
  step(textEv("looking"));
  let turn = await submit(c2.id, "mode read");
  await waitFor(() => finished(turn), 8000);
  t.check("read mode offers only read tools (and run_agent, whose helpers are read-only there; skill_find only searches; task_checkpoint only saves the plan)", JSON.stringify(toolNames()) === JSON.stringify(["list_dir", "read_file", "run_agent", "save_note", "skill_find", "task_checkpoint", "use_skill"]), toolNames().join(","));
  step(toolEv("w1", "write_file", { path: "nope.txt", content: "x" }));
  step(textEv("ok"));
  turn = await submit(c2.id, "write anyway");
  await waitFor(() => finished(turn), 8000);
  const end = evs(turn).find((e) => e.type === "tool_end");
  t.check("read mode: a write call is refused, not run", !existsSync(join(projA, "nope.txt")) && !evs(turn).some((e) => e.type === "tool_start" && e.tool === "write_file"), JSON.stringify(end));
  t.check("read mode: the model is told", /read-only/.test(llm.requests.at(-1).messages.at(-1).content[0].content));

  // supervised: asks
  const c3 = (await C.call("chat.create", { workspace_id: wA, mode: "supervised" })).result.chat;
  step(toolEv("s1", "write_file", { path: "sup.txt", content: "x" }));
  step(textEv("ok"));
  turn = await submit(c3.id, "supervised write");
  t.check("supervised: asks before writing", await waitFor(() => evs(turn).some((e) => e.type === "approval_request"), 8000));
  await C.call("turn.approve", { turn_id: turn, call_id: "s1", allow: false });
  await waitFor(() => finished(turn), 8000);
  t.check("supervised: denied write does not happen", !existsSync(join(projA, "sup.txt")));

  // auto_edits: writes go ahead, commands ask
  await C.call("chat.set_mode", { chat_id: c3.id, mode: "auto_edits" });
  step(toolEv("a1", "write_file", { path: "auto.txt", content: "auto" }));
  step(toolEv("a2", "run_command", { command: "echo hi" }));
  step(textEv("ok"));
  turn = await submit(c3.id, "auto edits");
  t.check("auto_edits: command still asks", await waitFor(() => evs(turn).some((e) => e.type === "approval_request" && e.call_id === "a2"), 8000));
  t.check("auto_edits: write went ahead without asking", existsSync(join(projA, "auto.txt")) && !evs(turn).some((e) => e.type === "approval_request" && e.call_id === "a1"));
  await C.call("turn.approve", { turn_id: turn, call_id: "a2", allow: true });
  await waitFor(() => finished(turn), 8000);

  // full: nothing asks
  await C.call("chat.set_mode", { chat_id: c3.id, mode: "full" });
  step(toolEv("f1", "run_command", { command: "echo full-$((2+3))" }));
  step(textEv("ok"));
  turn = await submit(c3.id, "full access");
  await waitFor(() => finished(turn), 8000);
  t.check("full: command runs without asking", !evs(turn).some((e) => e.type === "approval_request") && /full-5/.test(evs(turn).find((e) => e.type === "tool_end")?.output ?? ""));
  step(toolEv("f2", "read_file", { path: "../outside.txt" }));
  step(textEv("ok"));
  turn = await submit(c3.id, "escape in full");
  await waitFor(() => finished(turn), 8000);
  t.check("full access still cannot leave the project", evs(turn).find((e) => e.type === "tool_end")?.is_error === true);

  // mode switch takes effect on the next step of a running turn
  await C.call("chat.set_mode", { chat_id: c3.id, mode: "supervised" });
  step(toolEv("m1", "read_file", { path: "README.md" }));
  step(textEv("ok"));
  turn = await submit(c3.id, "switch mid turn");
  await waitFor(() => finished(turn), 8000);
  t.check("mode changes apply to the next turn's tools", llm.requests.at(-2).tools.some((x) => x.name === "write_file"));

  // ---- deleting ---------------------------------------------------------------------------------------------
  res = await C.call("turn.submit", { workspace_id: wA, chat_id: c1.id, text: "to delete " + "word ".repeat(600) });
  const tDel = res.result.turn_id;
  await waitFor(() => evs(tDel).some((e) => e.type === "delta"), 4000);
  res = await C.call("chat.delete", { chat_id: c1.id });
  t.check("chat.delete stops its turn and removes it", res.result?.deleted === true && (await waitFor(() => finished(tDel), 4000)), why(res));
  res = await C.call("turn.history", { chat_id: c1.id });
  t.check("deleted chat -> not found", code(res) === E.NOT_FOUND, why(res));
  await sleep(300);
  t.check("its transcript file is gone", !existsSync(join(stateDir, "chats", `${c1.id}.json`)));
  res = await C.call("chat.delete", { chat_id: c1.id });
  t.check("delete twice -> not found", code(res) === E.NOT_FOUND, why(res));

  res = await C.call("workspace.remove", { workspace_id: wA });
  res = await C.call("chat.list", { workspace_id: wA });
  t.check("removing a project removes its chats", res.result?.chats?.length === 0, why(res));
  t.check("…and their transcript files", !existsSync(join(stateDir, "chats", `${c2.id}.json`)) && !existsSync(join(stateDir, "chats", `${c3.id}.json`)));

  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  llmServer.close();
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
