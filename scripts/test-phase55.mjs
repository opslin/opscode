// Installing a skill from chat asks WHERE: all projects (works as /name everywhere), this project (only here), or just this task.
// skills.sh and GitHub are played by a local server; the engine is the fake Claude Code.
import { existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, symlinkSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p55-")));
const projA = join(base, "shop"); const projB = join(base, "blog"); const projC = join(base, "linked");
for (const p of [projA, projB, projC]) { mkdirSync(p, { recursive: true }); writeFileSync(join(p, "package.json"), "{}"); }
const logFile = join(base, "engines.log");
writeFileSync(logFile, "");
const stateDir = join(base, "state");

const GH = `---\nname: github\ndescription: "Work with GitHub: pull requests, issues, releases"\n---\n\n1. Use the gh CLI for pull requests.\n2. Read forms.md for the long list.`;
const PDF = `---\nname: pdf-forms\ndescription: "Fill and read PDF forms"\n---\n\n1. Use pypdf.`;
const web = createServer((req, res) => {
  const u = new URL(req.url, "http://x");
  const send = (code, body, type = "application/json") => res.writeHead(code, { "content-type": type }).end(body);
  if (u.pathname === "/api/search") return send(200, JSON.stringify({ skills: [{ source: "acme/skills", skillId: "github", installs: 900 }, { source: "acme/skills", skillId: "pdf-forms", installs: 90 }] }));
  if (u.pathname === "/raw/acme/skills/main/skills/github/SKILL.md") return send(200, GH, "text/plain");
  if (u.pathname === "/raw/acme/skills/main/skills/github/forms.md") return send(200, "# Long list", "text/plain");
  if (u.pathname === "/raw/acme/skills/main/skills/pdf-forms/SKILL.md") return send(200, PDF, "text/plain");
  send(404, "nope", "text/plain");
});
await new Promise((r) => web.listen(0, "127.0.0.1", r));
const W = `http://127.0.0.1:${web.address().port}`;
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile, OPSCODE_SKILLS_API: `${W}/api/search`, OPSCODE_SKILLS_RAW: `${W}/raw`, OPSCODE_SKILLS_TREE: `${W}/tree` };
const logLines = () => readFileSync(logFile, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const dev = (name) => logLines().filter((l) => l.device_tool === name);

const rt = await startRuntime({ env, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);
try {
  const C = await session(rt);
  const wa = (await C.call("workspace.add", { path: projA })).result.workspace.id;
  const wb = (await C.call("workspace.add", { path: projB })).result.workspace.id;
  const wc = (await C.call("workspace.add", { path: projC })).result.workspace.id;
  const waitFor = async (fn, ms = 15000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(50)) { const v = await fn(); if (v) return v; } return null; };
  const events = (turnId) => C.find("turn.event", (p) => p.turn_id === turnId).map((n) => n.params);
  const finished = (turnId) => waitFor(() => events(turnId).some((e) => ["completed", "failed", "interrupted"].includes(e.type)));
  const askOf = (turnId) => waitFor(() => events(turnId).find((e) => e.type === "approval_request" && /Install skill/.test(e.summary ?? "")));
  const lines = (...calls) => calls.map(([n, a]) => `FAKE_DEVICE ${n} ${JSON.stringify(a)}`).join("\n");
  const list = async (wid) => (await C.call("skill.list", wid ? { workspace_id: wid } : {})).result.skills;
  const mk = async (wid) => (await C.call("chat.create", { workspace_id: wid, engine: "claude-code", mode: "supervised" })).result.chat;
  const run = async (wid, chat, text) => { writeFileSync(logFile, ""); return (await C.call("turn.submit", { workspace_id: wid, chat_id: chat.id, text })).result.turn_id; };
  const install = (extra = {}) => lines(["skill_install", { source: "acme/skills", skill: "github", ...extra }]);

  // ---- all projects ---------------------------------------------------------------------------------------------------
  let chat = await mk(wa);
  let id = await run(wa, chat, `install the github skill\n${install()}`);
  let ask = await askOf(id);
  t.check("installing asks where: all projects, this project, or just this task", JSON.stringify(ask?.choices?.map((c) => c.id)) === JSON.stringify(["global", "project", "temp"]) && ask.choices[0].label === "All projects" && ask.choices[1].label === "This project", JSON.stringify(ask?.choices));
  t.check("each choice says what it means (slash command everywhere / only this project / removed later)", /\/github command/.test(ask.choices[0].hint) && /Only chats in this project/.test(ask.choices[1].hint) && /Removed/.test(ask.choices[2].hint), JSON.stringify(ask.choices.map((c) => c.hint)));
  let r = await C.call("turn.approve", { turn_id: id, call_id: ask.call_id, allow: true, choice: "bogus" });
  t.check("a choice the card did not offer is refused, and the question stays open", !!r.error && /offers: global, project, temp/.test(r.error.message) && !events(id).some((e) => e.type === "approval_resolved"), JSON.stringify(r.error));
  const n0 = C.find("skill.changed").length;
  r = await C.call("turn.approve", { turn_id: id, call_id: ask.call_id, allow: true, choice: "global" });
  await finished(id);
  const out = dev("skill_install")[0]?.result ?? "";
  t.check("all projects: the answer to the chat says so, and that /github works everywhere", /installed for all projects/.test(out) && /\/github command in every project/.test(out) && /gh CLI for pull requests/.test(out), out.slice(0, 200));
  t.check("it is saved in the person's own skills, with the notes it points to", existsSync(join(stateDir, "skills", "github", "SKILL.md")) && existsSync(join(stateDir, "skills", "github", "forms.md")));
  t.check("the skill list changed event fired (so the / menu updates)", C.find("skill.changed").length > n0);
  t.check("it shows in every project's list as the person's own skill", (await list(wa)).find((s) => s.name === "github")?.scope === "user" && (await list(wb)).find((s) => s.name === "github")?.scope === "user" && (await list()).some((s) => s.name === "github"));
  await C.call("chat.delete", { chat_id: chat.id });
  t.check("and it stays when the chat that installed it is deleted", existsSync(join(stateDir, "skills", "github", "SKILL.md")) && (await list(wb)).some((s) => s.name === "github"));
  // asking again for a skill you already have for all projects does not overwrite or ask twice
  chat = await mk(wb);
  id = await run(wb, chat, `again\n${install()}`);
  ask = await askOf(id);
  await C.call("turn.approve", { turn_id: id, call_id: ask.call_id, allow: true, choice: "project" });
  await finished(id);
  t.check("a skill you already have for all projects is not installed a second time", /already have a skill named "github" \(for all projects\)/.test(dev("skill_install")[0]?.result ?? "") && !existsSync(join(projB, ".opscode", "skills", "github")), dev("skill_install")[0]?.result?.slice(0, 120));
  await C.call("chat.delete", { chat_id: chat.id });
  await C.call("skill.delete", { scope: "user", name: "github" });

  // ---- this project ----------------------------------------------------------------------------------------------------
  chat = await mk(wa);
  id = await run(wa, chat, `install it here\n${install()}`);
  ask = await askOf(id);
  await C.call("turn.approve", { turn_id: id, call_id: ask.call_id, allow: true, choice: "project" });
  await finished(id);
  const pout = dev("skill_install")[0]?.result ?? "";
  t.check("this project: the answer says it is in this project only", /installed in this project only/.test(pout) && pout.includes(join(projA, ".opscode", "skills", "github")), pout.slice(0, 260));
  t.check("it is written in the project's .opscode/skills (with its notes), not in the person's own skills", existsSync(join(projA, ".opscode", "skills", "github", "SKILL.md")) && existsSync(join(projA, ".opscode", "skills", "github", "forms.md")) && !existsSync(join(stateDir, "skills", "github")));
  t.check("this project sees it as a project skill; another project and the plain list do not", (await list(wa)).find((s) => s.name === "github")?.scope === "project" && !(await list(wb)).some((s) => s.name === "github") && !(await list()).some((s) => s.name === "github"));
  t.check("the /name command and skill body are readable in this project", /gh CLI/.test((await C.call("skill.read", { workspace_id: wa, name: "github" })).result?.skill?.body ?? JSON.stringify((await C.call("skill.read", { workspace_id: wa, name: "github" })).result)));
  await C.call("chat.delete", { chat_id: chat.id });
  t.check("it stays after the chat is deleted (project skills are not temporary)", existsSync(join(projA, ".opscode", "skills", "github", "SKILL.md")));
  chat = await mk(wa);
  id = await run(wa, chat, `once more\n${install()}`);
  ask = await askOf(id);
  await C.call("turn.approve", { turn_id: id, call_id: ask.call_id, allow: true, choice: "project" });
  await finished(id);
  t.check("installing it again in the same project says you already have it", /already have a skill named "github" \(in this project\)/.test(dev("skill_install")[0]?.result ?? ""));
  await C.call("chat.delete", { chat_id: chat.id });
  await C.call("skill.delete", { scope: "project", workspace_id: wa, name: "github" });

  // ---- just this task, and the default when no choice is sent -----------------------------------------------------------------
  chat = await mk(wa);
  id = await run(wa, chat, `temp\n${lines(["skill_install", { source: "acme/skills", skill: "pdf-forms" }])}`);
  ask = await askOf(id);
  await C.call("turn.approve", { turn_id: id, call_id: ask.call_id, allow: true, choice: "temp" });
  await finished(id);
  t.check("just this task: temporary, in the person's skills until the chat goes", /temporary/.test(dev("skill_install")[0]?.result ?? "") && existsSync(join(stateDir, "skills", "pdf-forms", "SKILL.md")));
  // it proved useful: ask again with keep → "all projects" makes it permanent in the same place
  id = await run(wa, chat, `keep it\n${lines(["skill_install", { source: "acme/skills", skill: "pdf-forms", keep: true }])}`);
  ask = await askOf(id);
  t.check("asking again to keep it offers only lasting places (no 'just this task')", JSON.stringify(ask?.choices?.map((c) => c.id)) === JSON.stringify(["global", "project"]), JSON.stringify(ask?.choices));
  await C.call("turn.approve", { turn_id: id, call_id: ask.call_id, allow: true, choice: "global" });
  await finished(id);
  await C.call("chat.delete", { chat_id: chat.id });
  t.check("choosing all projects for a temporary skill makes it stay after its chat is deleted", existsSync(join(stateDir, "skills", "pdf-forms", "SKILL.md")) && (await list(wb)).some((s) => s.name === "pdf-forms"));
  await C.call("skill.delete", { scope: "user", name: "pdf-forms" });

  chat = await mk(wa);
  id = await run(wa, chat, `no choice\n${lines(["skill_install", { source: "acme/skills", skill: "pdf-forms" }])}`);
  ask = await askOf(id);
  await C.call("turn.approve", { turn_id: id, call_id: ask.call_id, allow: true });
  await finished(id);
  await C.call("chat.delete", { chat_id: chat.id });
  t.check("a yes with no choice picked takes the narrowest one (just this task)", !existsSync(join(stateDir, "skills", "pdf-forms")));

  // ---- no ------------------------------------------------------------------------------------------------------------------------
  chat = await mk(wa);
  id = await run(wa, chat, `no\n${install()}`);
  ask = await askOf(id);
  await C.call("turn.approve", { turn_id: id, call_id: ask.call_id, allow: false });
  await finished(id);
  t.check("no: nothing is installed anywhere and the chat is told", /denied/.test(dev("skill_install")[0]?.result ?? "") && !existsSync(join(stateDir, "skills", "github")) && !existsSync(join(projA, ".opscode", "skills", "github")));
  await C.call("chat.delete", { chat_id: chat.id });

  // ---- a project whose .opscode is a link cannot get project skills ---------------------------------------------------------------------
  const elsewhere = join(base, "elsewhere"); mkdirSync(elsewhere);
  symlinkSync(elsewhere, join(projC, ".opscode"));
  chat = await mk(wc);
  id = await run(wc, chat, `linked\n${install()}`);
  ask = await askOf(id);
  t.check("when the project's .opscode is a link, 'This project' is not offered", !!ask && !ask.choices.some((c) => c.id === "project") && ask.choices.some((c) => c.id === "global"), JSON.stringify(ask?.choices?.map((c) => c.id)));
  await C.call("turn.approve", { turn_id: id, call_id: ask.call_id, allow: false });
  await finished(id);
  t.check("nothing was written through the link", lstatSync(join(projC, ".opscode")).isSymbolicLink() && !existsSync(join(elsewhere, "skills")));
  await C.call("chat.delete", { chat_id: chat.id });
} finally {
  web.close();
  const exit = await rt.stop();
  t.check("runtime stops cleanly", exit === "code=0 signal=null", exit);
}
process.exit(t.finish());
