// Slice B of docs/quality-fix-plan.md: question cards. An agent asks the person to choose (1-4 questions, 2-4 options,
// "Other" always possible) and waits in the same turn: Claude Code's AskUserQuestion, Codex's request_user_input,
// Opscode's ask_user tool (over the device MCP endpoint), and the "Questions:" block backup for agents without it.
// Workers and automations are answered at once; Stop closes an open question.
import { mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const ROOT = process.cwd();
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p63-")));
const proj = join(base, "app");
mkdirSync(proj, { recursive: true });
const agyHome = join(base, "agy-default");
const qoderHome = join(base, "qoder-default");
for (const d of [agyHome, qoderHome]) { mkdirSync(d, { recursive: true }); writeFileSync(join(d, "fake-auth.json"), "{}"); }
const logFile = join(base, "engines.log");
writeFileSync(logFile, "");
const stateDir = join(base, "state");
const env = {
  OPSCODE_CLAUDE_BIN: join(ROOT, "scripts/lib/fake-claude.mjs"),
  OPSCODE_CODEX_BIN: join(ROOT, "scripts/lib/fake-codex.mjs"),
  OPSCODE_AGY_BIN: join(ROOT, "scripts/lib/fake-acp.mjs"),
  OPSCODE_QODER_BIN: join(ROOT, "scripts/lib/fake-acp.mjs"),
  OPSCODE_FAKE_ENGINE_LOG: logFile,
  OPSCODE_FAKE_REAL_HOME: process.env.HOME ?? homedir(),
  OPSCODE_FAKE_DEFAULT_ACP_HOME: agyHome,
  OPSCODE_FAKE_DEFAULT_QODER_HOME: qoderHome,
};
const L = () => readFileSync(logFile, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));

// ---- unit checks ------------------------------------------------------------------------------------------------------
const A = await import(join(ROOT, "dist/runtime/ask.js"));
const { devicesNote } = await import(join(ROOT, "dist/runtime/engines/claude.js"));
let qs = A.normalizeQuestions([
  { question: " Deploy now? ", header: "Deploy", options: [{ label: "Yes (Recommended)", description: "go" }, "No", "Other", "No"], multiSelect: false },
  { question: "Only one option", options: ["A"] },
  { question: "", options: ["A", "B"] },
  { question: "Free text?", options: [] },
  { question: "Pick apps", options: ["Vendor", "Customer", "Dashboard", "Backend", "Extra"], multi: true },
  { question: "Fifth", options: ["A", "B"] },
]);
t.check("normalize: trims, drops 'Other' and duplicates, keeps descriptions", qs[0].question === "Deploy now?" && qs[0].options.map((o) => o.label).join("|") === "Yes (Recommended)|No" && qs[0].options[0].description === "go" && qs[0].header === "Deploy", JSON.stringify(qs[0]));
t.check("normalize: drops one-option and empty questions, keeps a free-text one, caps options at 4 and questions at 4", qs.length === 4 && qs[1].question === "Free text?" && qs[1].options.length === 0 && qs[2].options.length === 4 && qs[2].multi === true && qs[3].question === "Fifth", JSON.stringify(qs.map((q) => q.question)));
t.check("normalize: at most 4 questions are read", A.normalizeQuestions(Array.from({ length: 6 }, (_, i) => ({ question: `Q${i}`, options: ["a", "b"] }))).length === 4);
t.check("answers: an unknown option is refused", A.checkAnswers(qs, [{ id: qs[0].id, picks: ["Maybe"] }]) !== null);
t.check("answers: two picks on a one-answer question are refused", A.checkAnswers(qs, [{ id: qs[0].id, picks: ["Yes (Recommended)", "No"] }]) !== null);
t.check("answers: picks, multi picks and own words pass", A.checkAnswers(qs, [{ id: qs[0].id, picks: ["No"] }, { id: qs[2].id, picks: ["Vendor", "Customer"] }, { id: qs[1].id, picks: [], other: "use blue" }]) === null);
const claude = A.claudeAnswers([{ question: " Deploy now? " }, { question: "Pick apps" }], qs, [{ id: qs[0].id, picks: ["No"] }, { id: qs[2].id, picks: ["Vendor"], other: "and web" }]);
t.check("Claude answers are keyed by its own question text; several picks are a list", claude[" Deploy now? "] === "No" && JSON.stringify(claude["Pick apps"]) === JSON.stringify(["Vendor", "and web"]), JSON.stringify(claude));
const block = A.parseQuestionBlock("Here are two ways.\n\nQuestions:\n1. Where? [Profile (Recommended) | Home]\n2. Which apps? [Vendor | Customer] (pick any)");
t.check("backup block: numbered questions with options become a card", block.length === 2 && block[0].options.length === 2 && block[1].multi === true, JSON.stringify(block));
t.check("backup block: ordinary text is not a card", A.parseQuestionBlock("Question: blue or green? I recommend blue.").length === 0 && A.parseQuestionBlock("Questions:\nwhat do you think?").length === 0);
t.check("the note is told to every engine that has ask_user", devicesNote(["ask_user"]).includes("ask_user tool (in Claude Code: AskUserQuestion)") && !devicesNote(["browser_navigate"]).includes("ask_user"));
t.check("the note stays short (about 90 words)", A.QUESTION_NOTE.split(/\s+/).length <= 110, String(A.QUESTION_NOTE.split(/\s+/).length));

// ---- end to end ---------------------------------------------------------------------------------------------------------
const rt = await startRuntime({ env, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const waitFor = async (fn, ms = 8000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(40)) { const v = await fn(); if (v) return v; } return null; };
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  const events = (turnId) => C.find("turn.event", (p) => p.turn_id === turnId).map((n) => n.params);
  const text = (turnId) => events(turnId).filter((e) => e.type === "delta").map((e) => e.text).join("");
  const ended = (turnId) => events(turnId).find((e) => ["completed", "failed", "interrupted"].includes(e.type));
  const submit = async (chatId, txt) => (await C.call("turn.submit", { workspace_id: wid, chat_id: chatId, text: txt })).result.turn_id;
  const question = (turnId, ms = 10000) => waitFor(() => events(turnId).find((e) => e.type === "question"), ms);
  const newChat = async (engine) => (await C.call("chat.create", { workspace_id: wid, engine })).result.chat;
  const history = async (chatId) => (await C.call("turn.history", { chat_id: chatId })).result.messages;

  // Claude Code's AskUserQuestion -------------------------------------------------------------------------------------------
  const cc = await newChat("claude-code");
  let turn = await submit(cc.id, "FAKE_ASK");
  let q = await question(turn);
  t.check("Claude: its question shows as a card with both questions and the options", q?.questions?.length === 2 && q.questions[0].options[0].label === "Yes, deploy now (Recommended)" && q.questions[1].multi === true, JSON.stringify(q?.questions));
  t.check("Claude: the turn waits (still running)", !ended(turn));
  const hist0 = await history(cc.id);
  t.check("Claude: the waiting card is saved in the chat (it comes back after a reload)", hist0.at(-1)?.parts?.some((p) => p.status === "awaiting_answer" && p.questions?.length === 2), JSON.stringify(hist0.at(-1)?.parts));
  let res = await C.call("turn.answer", { turn_id: turn, call_id: q.call_id, answers: [{ id: q.questions[0].id, picks: ["Maybe"] }] });
  t.check("an option that is not on the card is refused", !!res.error, JSON.stringify(res));
  res = await C.call("turn.answer", { turn_id: turn, call_id: q.call_id, answers: [{ id: q.questions[0].id, picks: ["Yes, deploy now (Recommended)"] }, { id: q.questions[1].id, picks: ["Vendor app"], other: "and the web build" }] });
  t.check("turn.answer resolves the card", res.result?.resolved === true, JSON.stringify(res));
  await waitFor(() => ended(turn));
  const ask = L().find((l) => l.bin === "claude" && "ask" in l);
  t.check("Claude gets the answers keyed by its question text (several picks as a list)", ask?.ask === "allow" && ask.answers["Deploy the backend now?"] === "Yes, deploy now (Recommended)" && JSON.stringify(ask.answers["Which apps get a new APK?"]) === JSON.stringify(["Vendor app", "and the web build"]), JSON.stringify(ask));
  t.check("Claude goes on in the same turn", ended(turn)?.type === "completed" && text(turn).includes("Going on with:"), text(turn));
  t.check("a question_answered event carries the answers", events(turn).some((e) => e.type === "question_answered" && e.answers?.length === 2));
  const hist1 = await history(cc.id);
  t.check("the chat keeps what you chose", hist1.at(-1)?.parts?.some((p) => p.questions && p.answers?.length === 2 && p.status !== "awaiting_answer"), JSON.stringify(hist1.at(-1)?.parts?.filter((p) => p.questions)));

  writeFileSync(logFile, "");
  turn = await submit(cc.id, "FAKE_ASK");
  q = await question(turn);
  await C.call("turn.answer", { turn_id: turn, call_id: q.call_id, skip: true });
  await waitFor(() => ended(turn));
  const skipped = L().find((l) => l.bin === "claude" && "ask" in l);
  t.check("Skip: Claude is told to use its own judgment and say what it assumed", skipped?.ask === "deny" && /skipped/i.test(skipped.message) && /best judgment/.test(skipped.message), JSON.stringify(skipped));
  t.check("Skip: the turn still completes", ended(turn)?.type === "completed" && text(turn).includes("Deciding myself"));

  turn = await submit(cc.id, "FAKE_ASK");
  q = await question(turn);
  await C.call("turn.interrupt", { turn_id: turn });
  t.check("Stop closes an open question and ends the turn", !!(await waitFor(() => ended(turn)?.type === "interrupted", 5000)));
  res = await C.call("turn.answer", { turn_id: turn, call_id: q.call_id, skip: true });
  t.check("an answer after Stop resolves nothing", res.result?.resolved === false, JSON.stringify(res));

  // Opscode's ask_user tool over the device MCP endpoint (Codex, Antigravity, Qoder, and Claude when it uses it) ---------------
  const cx = await newChat("codex");
  writeFileSync(logFile, "");
  turn = await submit(cx.id, 'FAKE_DEVICE ask_user {"questions":[{"question":"Which layout?","header":"Layout","options":[{"label":"Cards (Recommended)","description":"Big tiles"},{"label":"List"}]}]}');
  q = await question(turn);
  t.check("Codex: ask_user shows the same card", q?.questions?.[0]?.question === "Which layout?" && q.questions[0].options.length === 2, JSON.stringify(q));
  await C.call("turn.answer", { turn_id: turn, call_id: q.call_id, answers: [{ id: q.questions[0].id, picks: [], other: "a grid with 2 columns" }] });
  await waitFor(() => ended(turn));
  const dt = L().find((l) => l.bin === "codex" && l.device_tool === "ask_user");
  t.check("Codex: the tool returns the answer in words (own words included)", /The user answered:/.test(dt?.result ?? "") && /Which layout\? -> a grid with 2 columns/.test(dt.result) && dt.is_error === false, JSON.stringify(dt));
  t.check("Codex: the turn completes after the answer", ended(turn)?.type === "completed");

  // Codex's own request_user_input ------------------------------------------------------------------------------------------
  writeFileSync(logFile, "");
  turn = await submit(cx.id, "FAKE_CODEX_ASK");
  q = await question(turn);
  t.check("Codex: request_user_input shows the card", q?.questions?.[0]?.id === "color" && q.questions[0].options[0].label === "Blue (Recommended)", JSON.stringify(q));
  await C.call("turn.answer", { turn_id: turn, call_id: q.call_id, answers: [{ id: "color", picks: ["Green"] }] });
  await waitFor(() => ended(turn));
  const ui = L().find((l) => l.bin === "codex" && l.user_input);
  t.check("Codex gets {answers: {color: {answers: [Green]}}} and goes on", JSON.stringify(ui?.user_input) === JSON.stringify({ answers: { color: { answers: ["Green"] } } }) && text(turn).includes("Using Green."), JSON.stringify(ui));

  // Backup: a "Questions:" block from an agent without Opscode's tools ------------------------------------------------------------
  const agy = await newChat("antigravity");
  turn = await submit(agy.id, "FAKE_ASK_BLOCK");
  await waitFor(() => ended(turn), 15000);
  q = await question(turn, 3000);
  t.check("Backup: the block becomes a card after the reply ends", ended(turn)?.type === "completed" && q?.questions?.length === 2 && q.questions[1].multi === true, JSON.stringify(q));
  writeFileSync(logFile, "");
  res = await C.call("turn.answer", { turn_id: turn, call_id: q.call_id, answers: [{ id: q.questions[0].id, picks: ["Profile tab (Recommended)"] }, { id: q.questions[1].id, picks: ["Vendor", "Customer"] }] });
  t.check("Backup: the answer is sent as the next message", typeof res.result?.turn_id === "string" && /My answers:/.test(res.result.text), JSON.stringify(res));
  const next = res.result?.turn_id;
  await waitFor(() => next && ended(next), 15000);
  const promptLog = L().filter((l) => l.ev === "prompt").at(-1);
  t.check("Backup: the agent receives your answers", JSON.stringify(promptLog ?? {}).includes("Where should the returns section go? -> Profile tab (Recommended)") && JSON.stringify(promptLog).includes("Vendor, Customer"), JSON.stringify(promptLog).slice(0, 400));
  const hist2 = await history(agy.id);
  t.check("Backup: the card is marked answered in the chat", hist2.some((m) => m.parts?.some((p) => p.questions && p.answers?.length === 2 && p.status === "done")));

  // Nobody watching: a Manager's worker and an automation step are answered at once -----------------------------------------------
  const meta = JSON.parse(readFileSync(join(stateDir, "chats.json"), "utf8"));
  t.check("(test setup) chats.json is readable", Array.isArray(meta) || typeof meta === "object");
  C.close();
} finally {
  await rt.stop();
}

// A worker chat (chief role "build"): the question is answered at once. Set the chat up on disk, then start again.
{
  const chatsFile = join(stateDir, "chats.json");
  const raw = JSON.parse(readFileSync(chatsFile, "utf8"));
  const list = Array.isArray(raw) ? raw : raw.chats;
  const worker = list.find((c) => c.engine === "claude-code");
  worker.chief = { id: "chief-x", role: "build" };
  writeFileSync(chatsFile, JSON.stringify(raw, null, 2));
  writeFileSync(logFile, "");
  const rt2 = await startRuntime({ env, stateDir, keepState: true });
  try {
    const C = await session(rt2);
    const waitFor = async (fn, ms = 8000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(40)) { const v = await fn(); if (v) return v; } return null; };
    const turnId = (await C.call("turn.submit", { workspace_id: worker.workspace_id, chat_id: worker.id, text: "FAKE_ASK" })).result?.turn_id;
    const events = () => C.find("turn.event", (p) => p.turn_id === turnId).map((n) => n.params);
    await waitFor(() => events().some((e) => ["completed", "failed", "interrupted"].includes(e.type)));
    const ask = L().find((l) => l.bin === "claude" && "ask" in l);
    t.check("a Manager's worker is answered at once (no card waits for nobody)", !events().some((e) => e.type === "question") && ask?.ask === "deny" && /Manager's worker/.test(ask.message), JSON.stringify(ask));
    t.check("the worker's turn completes", events().some((e) => e.type === "completed"));
    C.close();
  } finally {
    await rt2.stop();
    rmSync(base, { recursive: true, force: true });
  }
}
process.exit(t.finish());
