// Sidebar rework, runtime side: a mode chat is named after its task, deleting it (and its worker chats), deleting one worker,
// and unlinking a project (its folder on disk stays; a Conductor that was only for it goes).

import { existsSync, mkdirSync, mkdtempSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const why = (res) => JSON.stringify(res?.error ?? res?.result)?.slice(0, 300);
const ROOT = process.cwd();

// ---- the label ---------------------------------------------------------------------------------------------------
const { shortTitle } = await import(join(ROOT, "dist/runtime/chief/title.js"));
const cases = [
  ["can you please build the login screen with google sign in", "Build the login screen"],
  ["I need you to fix the flaky checkout test. It fails on CI only.", "Fix the flaky checkout test"],
  ["Check: Exchange showcase page?", "Check: Exchange showcase page"],
  ["  \n\nadd dark mode to settings", "Add dark mode to settings"],
  ["hey, https://example.com/x make the logo bigger", "Make the logo bigger"],
  ["supercalifragilisticexpialidocious-and-then-some-more-letters", "Supercalifragilisticexpialidocio"],
  ["   ", ""],
];
for (const [input, want] of cases) { const got = shortTitle(input); t.check(`label: ${JSON.stringify(input.slice(0, 40))} -> ${JSON.stringify(want)}`, got === want, JSON.stringify(got)); }
t.check("label stays short (32 characters at most, 5 words at most)", shortTitle("one two three four five six seven eight nine ten").split(" ").length <= 5 && shortTitle("x".repeat(90)).length <= 32);

// ---- runtime ------------------------------------------------------------------------------------------------------
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p42-")));
const proj = join(base, "shop");
const proj2 = join(base, "blog");
mkdirSync(proj);
mkdirSync(proj2);
writeFileSync(join(proj, "keep.txt"), "mine");
const env = { OPSCODE_CLAUDE_BIN: join(ROOT, "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(ROOT, "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: join(base, "engines.log") };
const rt = await startRuntime({ env, stateDir: join(base, "state"), keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  const wid2 = (await C.call("workspace.add", { path: proj2 })).result.workspace.id;
  await C.call("engines.set", { default_engine: "claude-code" });
  const chats = async () => (await C.call("chat.list", {})).result.chats;
  const chiefs = async () => (await C.call("chief.list", {})).result.chiefs;
  const tool = (name, args) => `FAKE_TOOL ${name} ${JSON.stringify(args)}`;
  const worker = (title, text) => tool("chat_start", { title, brief: `Goal: ${title} FAKE_REPORT=done FAKE_CHECK`, quotes: [text], project_ids: [wid], engine: "claude-code", tier: "base" });
  const waitFor = async (fn, ms = 15000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(100)) { const v = await fn(); if (v) return v; } return null; };
  const make = async (mode, project = wid) => (await C.call("chief.create", { mode, project_id: project })).result.chief;
  const note = (id, text, lines = []) => C.call("chief.note", { chief_id: id, text: [text, ...lines].join("\n") });

  // naming
  const g = await make("godmode");
  t.check("a new mode chat has no label yet and its chat is named after the mode", !g.title && (await chats()).find((c) => c.id === g.chat_id)?.title === "GODMODE", why({ result: g }));
  const ask = "can you please build the exchange showcase page";
  await note(g.id, ask, [worker("Showcase hero", ask), worker("Check: Showcase links", ask)]);
  const g1 = await waitFor(async () => (await chiefs()).find((c) => c.id === g.id && c.title));
  t.check("the first thing asked becomes its label (short, plain)", g1?.title === "Build the exchange showcase page" && g1.name === "GODMODE", JSON.stringify(g1?.title));
  t.check("its own chat carries the label too (lists and the palette show it)", (await chats()).find((c) => c.id === g.chat_id)?.title === "Build the exchange showcase page");
  const two = await waitFor(async () => { const w = (await chats()).filter((c) => c.chief?.id === g.id && c.chief.role !== "home"); return w.length === 2 ? w : null; });
  t.check("two worker chats started under it, each named by its job and marked with the Conductor", !!two && two.some((c) => c.title === "Showcase hero") && two.some((c) => c.title === "Check: Showcase links") && two.every((c) => c.chief.item_id), JSON.stringify(two?.map((c) => c.title)));
  await note(g.id, "also add a footer");
  await sleep(600);
  t.check("a later note does not rename it", (await chiefs()).find((c) => c.id === g.id)?.title === "Build the exchange showcase page");
  let r = await C.call("chief.update", { chief_id: g.id, title: "Showcase" });
  t.check("the label can be set by hand", r.result?.chief.title === "Showcase" && (await chats()).find((c) => c.id === g.chat_id)?.title === "Showcase", why(r));

  // deleting one nested chat
  const hero = two.find((c) => c.title === "Showcase hero");
  r = await C.call("chat.delete", { chat_id: hero.id });
  t.check("deleting one worker chat removes it", !r.error && !(await chats()).some((c) => c.id === hero.id), why(r));
  const view = (await C.call("chief.get", { chief_id: g.id })).result;
  t.check("and it leaves the Conductor's board (the item with nothing left is dropped)", !view.items.some((i) => i.chats.some((c) => c.chat_id === hero.id)) && !view.items.some((i) => i.title === "Showcase hero"), JSON.stringify(view.items.map((i) => i.title)));
  t.check("the other worker and the Conductor stay", (await chats()).some((c) => c.title === "Check: Showcase links") && (await chiefs()).some((c) => c.id === g.id));

  // deleting the mode chat takes its workers
  r = await C.call("chief.remove", { chief_id: g.id, delete_workers: true });
  const after = await chats();
  t.check("deleting a mode chat with 'delete workers' removes it, its own chat and every worker chat", r.result?.removed === true && !(await chiefs()).some((c) => c.id === g.id) && !after.some((c) => c.id === g.chat_id) && !after.some((c) => c.chief?.id === g.id), why(r));

  // the generic chat.delete still refuses a mode chat's own chat (it goes through chief.remove)
  const w = await make("warlord");
  await note(w.id, "fix the flaky test", [worker("Flaky test", "fix the flaky test")]);
  await waitFor(async () => (await chats()).some((c) => c.chief?.id === w.id && c.chief.role !== "home"));
  r = await C.call("chat.delete", { chat_id: w.chat_id });
  t.check("chat.delete refuses a mode chat's own chat; it stays", !!r.error && (await chiefs()).some((c) => c.id === w.id), why(r));
  await C.call("chief.remove", { chief_id: w.id, delete_workers: true });

  // without 'delete workers' (the Manager settings dialog) the workers stay as ordinary chats
  const s = await make("shinobi");
  await note(s.id, "rename the footer", [worker("Footer rename", "rename the footer")]);
  const sw = await waitFor(async () => (await chats()).find((c) => c.chief?.id === s.id && c.chief.role !== "home"));
  await C.call("chief.remove", { chief_id: s.id });
  const kept = (await chats()).find((c) => c.id === sw?.id);
  t.check("removing without 'delete workers' leaves the worker as an ordinary chat (no Conductor mark)", !!kept && !kept.chief, JSON.stringify(kept?.chief));

  // unlink
  const u = await make("godmode", wid2);
  const other = await make("warlord", wid);
  await note(u.id, "write the about page");
  await waitFor(async () => (await chiefs()).find((c) => c.id === u.id && c.title));
  await C.call("chat.create", { workspace_id: wid2 }).catch(() => {});
  r = await C.call("workspace.remove", { workspace_id: wid2 });
  t.check("unlinking a project removes the link", !r.error && !(await C.call("workspace.list")).result.workspaces.some((x) => x.id === wid2), why(r));
  t.check("a mode chat that was only for that project goes with it, with its chats", !(await chiefs()).some((c) => c.id === u.id) && !(await chats()).some((c) => c.id === u.chat_id || c.workspace_id === wid2));
  t.check("a mode chat in another project is untouched", (await chiefs()).some((c) => c.id === other.id));
  t.check("the folder and its files are not touched", existsSync(proj2) && existsSync(join(proj, "keep.txt")));

  // a worker chat of a plain chat is unaffected by the new delete path
  const plain = (await C.call("chat.create", { workspace_id: wid })).result?.chat;
  if (plain) { r = await C.call("chat.delete", { chat_id: plain.id }); t.check("an ordinary chat still deletes as before", !r.error && !(await chats()).some((c) => c.id === plain.id), why(r)); }
  C.close();
} finally {
  await rt.stop?.();
}
process.exit(t.finish());
