// New git branches are the person's call: a command that creates one (checkout -b, switch -c, branch <name>,
// worktree add -b) gets its own card (create it / stay on the current branch), and either answer can be remembered
// as the project's branch rule (ask / current / allow). Other commands are untouched.
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const G = await import(join(process.cwd(), "dist/runtime/engines/branchGuard.js"));

const CREATES = [
  "git checkout -b feat/x", "git switch -c fix/y", "git checkout -B z", "git branch new-thing", "cd app && git checkout -b a/b && npm i",
  "git -C repo switch -c q", "git worktree add ../wt -b wt1", "git checkout --orphan gh-pages", "git checkout -b 'quoted-name'", "git switch --create long/form",
  "git checkout main && git checkout -b perf/public-read-cache",
];
const NOT = [
  "git checkout main", "git checkout -- file.txt", "git branch", "git branch -a", "git branch -d old", "git branch -D old", "git branch --show-current", "git branch -m renamed",
  "git switch main", "git log --oneline", "git status", "git checkout feature/x", "git branch --list 'feat/*'", "ssh host 'cd x && git checkout -b y'", "docker exec api git checkout -b z", "echo git checkout -b is a thing to avoid",
];
const badC = CREATES.filter((c) => G.branchCreations(c).length === 0);
const badN = NOT.filter((c) => G.branchCreations(c).length !== 0 && !c.startsWith("echo"));
t.check(`${CREATES.length} branch-creating commands are recognised`, !badC.length, badC.join(" | "));
t.check(`${NOT.length - 1} commands that do not create a branch are left alone (including remote shells)`, !badN.length, badN.join(" | "));
t.check("the branch names come out right", G.branchCreations("git checkout -b feat/x")[0] === "feat/x" && G.branchCreations("git checkout -b 'quoted-name'")[0] === "quoted-name" && G.branchCreations("git worktree add ../wt -b wt1")[0] === "wt1" && G.branchCreations("git branch new-thing")[0] === "new-thing");

const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p32-")));
const proj = join(base, "shop");
mkdirSync(proj, { recursive: true });
writeFileSync(join(proj, "package.json"), "{}");
const git = (...a) => execFileSync("git", ["-C", proj, ...a], { encoding: "utf8" });
git("init", "-b", "main"); git("config", "user.email", "t@t.t"); git("config", "user.name", "t"); git("add", "."); git("commit", "-m", "init");
const logFile = join(base, "engines.log");
const stateDir = join(base, "state");
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile };
const entries = () => (existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const rt = await startRuntime({ env, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  const waitFor = async (fn, ms = 15000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(50)) { const v = await fn(); if (v) return v; } return null; };
  const events = (id) => C.find("turn.event", (p) => p.turn_id === id).map((n) => n.params);
  const finished = (id) => waitFor(() => events(id).some((e) => ["completed", "failed", "interrupted"].includes(e.type)));
  const rule = async () => (await C.call("branch.rule", { workspace_id: wid })).result?.rule;
  const mk = async (engine) => (await C.call("chat.create", { workspace_id: wid, engine, mode: "auto_edits" })).result.chat;
  const go = async (chat, text) => { writeFileSync(logFile, ""); const r = (await C.call("turn.submit", { workspace_id: wid, chat_id: chat.id, text })).result; return r.turn_id; };
  const ask = (id) => waitFor(() => events(id).find((e) => e.type === "approval_request"));
  const answer = (id, ev, allow, remember) => C.call("turn.approve", { turn_id: id, call_id: ev.call_id, allow, ...(remember ? { remember } : {}) });
  const bash = (cmd) => `go\nFAKE_BASH=«${cmd}»`;
  const decided = () => entries().find((e) => e.bash)?.behavior;
  const message = () => entries().find((e) => e.bash)?.message ?? "";

  t.check("a project starts with the rule 'ask'", (await rule()) === "ask");
  t.check("rules are validated", !!(await C.call("branch.rule.set", { workspace_id: wid, rule: "sometimes" })).error);

  // ---- Claude Code: the card ------------------------------------------------------------------------------
  const cc = await mk("claude-code");
  let id = await go(cc, bash("git checkout -b perf/public-read-cache"));
  let ev = await ask(id);
  t.check("creating a branch asks with the branch card: the name and the branch it is on now", ev?.branch?.names?.[0] === "perf/public-read-cache" && ev.branch.current === "main" && /Create branch/.test(ev.summary ?? ""), JSON.stringify(ev));
  await answer(id, ev, false);
  await finished(id);
  t.check("'Stay on main': the branch is not created and the agent is told to keep working on main", decided() === "deny" && /current branch \(main\)/.test(message()) && /do not create a new branch/.test(message()), message());
  t.check("a plain answer remembers nothing", (await rule()) === "ask");

  id = await go(cc, bash("git checkout -b perf/public-read-cache"));
  ev = await ask(id);
  await answer(id, ev, true);
  await finished(id);
  t.check("'Create branch': allowed", decided() === "allow");
  t.check("and still asks next time", (await rule()) === "ask");

  // ---- remember: stay on the current branch ------------------------------------------------------------------
  id = await go(cc, bash("git switch -c other/idea"));
  ev = await ask(id);
  await answer(id, ev, false, "current");
  await finished(id);
  t.check("'Always stay on main in this project' is saved as the rule", (await rule()) === "current" && decided() === "deny");
  id = await go(cc, bash("git checkout -b another/one"));
  await finished(id);
  t.check("with that rule nothing is asked: the agent is told to stay on the current branch", !events(id).some((e) => e.type === "approval_request") && decided() === "deny" && /current branch \(main\)/.test(message()));
  t.check("the rule is written to disk (it survives a restart)", /"current"/.test(readFileSync(join(stateDir, "branch-rules.json"), "utf8")));

  // ---- remember: allow ------------------------------------------------------------------------------------------
  await C.call("branch.rule.set", { workspace_id: wid, rule: "ask" });
  id = await go(cc, bash("git checkout -b feat/auto"));
  ev = await ask(id);
  await answer(id, ev, true, "allow");
  await finished(id);
  t.check("'Always allow here' is saved as the rule", (await rule()) === "allow" && decided() === "allow");
  id = await go(cc, bash("git checkout -b feat/auto-2"));
  await finished(id);
  t.check("with that rule new branches go ahead without a question", !events(id).some((e) => e.type === "approval_request") && decided() === "allow");

  // ---- other commands are untouched ---------------------------------------------------------------------------
  await C.call("branch.rule.set", { workspace_id: wid, rule: "current" });
  id = await go(cc, bash("git checkout main"));
  const plain = await ask(id);
  t.check("a command that does not create a branch gets the normal card (no branch card), whatever the rule", plain && !plain.branch, JSON.stringify(plain));
  await answer(id, plain, true);
  await finished(id);
  id = await go(cc, bash("git status"));
  await finished(id);
  t.check("and read-only git needs no question at all", !events(id).some((e) => e.type === "approval_request") && decided() === "allow");

  // ---- Codex: the same ---------------------------------------------------------------------------------------------
  await C.call("branch.rule.set", { workspace_id: wid, rule: "ask" });
  const cx = await mk("codex");
  id = await go(cx, "FAKE_CMD=«git checkout -b codex/idea»");
  ev = await ask(id);
  t.check("Codex's command asks with the same branch card", ev?.branch?.names?.[0] === "codex/idea" && ev.branch.current === "main", JSON.stringify(ev));
  await answer(id, ev, false, "current");
  await finished(id);
  t.check("declined: Codex is told no, and the rule is saved", entries().find((e) => e.cmd)?.decision === "decline" && (await rule()) === "current");
  id = await go(cx, "FAKE_CMD=«git switch -c codex/again»");
  await finished(id);
  t.check("with the rule, Codex is declined without asking", entries().find((e) => e.cmd)?.decision === "decline" && !events(id).some((e) => e.type === "approval_request"));
  await C.call("branch.rule.set", { workspace_id: wid, rule: "allow" });
  id = await go(cx, "FAKE_CMD=«git checkout -b codex/ok»");
  await finished(id);
  t.check("with 'allow', Codex's branch command is accepted without asking", entries().find((e) => e.cmd)?.decision === "accept" && !events(id).some((e) => e.type === "approval_request"));

  // ---- the rule belongs to the project ------------------------------------------------------------------------------
  const other = join(base, "other"); mkdirSync(other);
  const wid2 = (await C.call("workspace.add", { path: other })).result.workspace.id;
  t.check("another project is not affected", (await C.call("branch.rule", { workspace_id: wid2 })).result?.rule === "ask");
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
}
process.exit(t.finish());
