// Permissions by command: in auto edits, reading, searching, read-only queries, fetches and local
// tests run without asking; deleting, writing to a live database or server, pushing, deploying
// and installing ask. In read only, only the safe ones may run at all (nothing is written).
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";
const t = reporter();
const S = await import(join(process.cwd(), "dist/runtime/engines/safety.js"));
const root = "/Users/me/shop";
const auto = (c) => S.classifyCommand(c, root, true);
const ro = (c) => S.classifyCommand(c, root, false);
const SAFE = [
  "ls -la src", "grep -rn exchange dealker-app/lib | head -40", "cat package.json", "find . -name '*.dart' -not -path '*/build/*'",
  "sed -n 150,205p src/x.js", "git status && git log --oneline -5", "git diff --stat", "rg -l TODO",
  "npm test", "npm run test:unit", "npm run build", "flutter analyze", "flutter test test/cart_test.dart", "npx tsc --noEmit",
  "curl -s https://api.dealker.agnixstudio.in/api/v1/exchange-requests/for-product/abc", "curl -sS -H 'Authorization: Bearer x' https://api.x/y | jq .",
  `psql -U dealker_user -d dealker_db -c "SELECT category, count(*) FROM sell_device_models GROUP BY 1"`,
  `ssh -i ~/.ssh/k.pem ubuntu@52.63.86.195 "docker exec api psql -U u -d db -c 'SELECT count(*) FROM exchange_programs'"`,
  `ssh -i k.pem ubuntu@host "docker ps && docker logs --tail 50 api"`, "wc -l src/*.ts > /tmp/count.txt", "echo hi 2>/dev/null",
];
const ASK = [
  "rm -rf build", "git push origin main", "git reset --hard HEAD~1", "git branch -D old", "npm install lodash", "npm i", "pip install x", "brew install x",
  `psql -c "UPDATE products SET price = 1"`, `psql -c "DELETE FROM orders"`, `psql -d db -f migrate.sql`, "psql",
  `ssh host "docker restart api"`, `ssh host "rm -rf /var/www"`, `ssh host "echo x > /etc/app.conf"`, `ssh host "echo x > notes.txt"`, "ssh host",
  `ssh host "docker exec api node scripts/seed-exchange-catalogue.mjs"`, "curl -X POST https://api.x/orders -d '{}'", "curl --data a=1 https://x",
  "sudo ls", "sed -i 's/a/b/' x.js", "find . -name '*.log' -delete", "echo $(cat /etc/passwd)", "node scripts/seed.js", "vercel --prod",
  "docker compose up -d", "kill -9 123", "chmod -R 777 .", "echo x > /etc/hosts", "cat a | ssh host 'cat > /tmp/x && mv /tmp/x /app/x'",
];
const badSafe = SAFE.filter((c) => auto(c) !== "safe");
const badAsk = ASK.filter((c) => auto(c) !== "ask");
t.check(`${SAFE.length} reading/searching/testing commands run without asking in auto edits`, !badSafe.length, badSafe.join(" | "));
t.check(`${ASK.length} deleting/writing/pushing/deploying/installing commands still ask`, !badAsk.length, badAsk.join(" | "));
t.check("writing a project file with > is an edit in auto edits (allowed)", auto("echo x > notes.txt") === "safe");
t.check("but not in read only", ro("echo x > notes.txt") === "ask");
t.check("read only refuses builds and dev servers (they write output)", ro("npm run build") === "ask" && ro("npm run dev") === "ask" && ro("npm test") === "safe");
t.check("a remote command never writes files, even relative ones", auto(`ssh h "echo x > a.txt"`) === "ask" && auto(`ssh h "cat a.txt"`) === "safe");
t.check("unknown programs ask", auto("frobnicate --all") === "ask" && auto("") === "ask");
t.check("quoted separators do not split a command", auto(`grep -n "a && rm -rf b" x.txt`) === "safe");
const P = (mode, tool, input) => S.permissionFor(mode, tool, input, root);
t.check("auto edits: file edits and read tools run, safe Bash runs, unsafe Bash asks", P("auto_edits", "Edit", {}) === "allow" && P("auto_edits", "Read", {}) === "allow" && P("auto_edits", "Bash", { command: "grep x ." }) === "allow" && P("auto_edits", "Bash", { command: "rm -rf x" }) === "ask");
t.check("read only: edits and unsafe Bash are refused outright, reads run", P("read", "Write", {}) === "deny" && P("read", "Bash", { command: "rm x" }) === "deny" && P("read", "Bash", { command: "git log" }) === "allow" && P("read", "Grep", {}) === "allow");
t.check("supervised still asks for everything", P("supervised", "Bash", { command: "ls" }) === "ask" && P("supervised", "Edit", {}) === "ask");
t.check("other tools (MCP, unknown) ask in auto edits", P("auto_edits", "mcp__x__send_email", {}) === "ask");

// ---- live: the runtime with a fake Claude Code that asks to run commands ----------------------------
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p29-")));
writeFileSync(join(base, "package.json"), "{}");
const logFile = join(base, "engines.log");
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile };
const entries = () => (existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const rt = await startRuntime({ env, stateDir: join(base, "state"), keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: base })).result.workspace.id;
  const waitFor = async (fn, ms = 10000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(80)) { const v = fn(); if (v) return v; } return null; };
  const run = async (mode, cmd) => {
    const chat = (await C.call("chat.create", { workspace_id: wid, mode, engine: "claude-code", model: "claude-sonnet-5-5" })).result.chat;
    const r = await C.call("turn.submit", { workspace_id: wid, chat_id: chat.id, text: `do it FAKE_BASH=«${cmd}»` });
    const tid = r.result.turn_id;
    const asked = await waitFor(() => C.find("turn.event", (p) => p.turn_id === tid && p.type === "approval_request")[0], 2500);
    if (asked) await C.call("turn.approve", { turn_id: tid, call_id: asked.params.call_id, allow: false });
    await waitFor(() => C.find("turn.event", (p) => p.turn_id === tid && (p.type === "completed" || p.type === "failed"))[0]);
    return { asked: !!asked, log: entries().filter((e) => e.bash === cmd).at(-1), argv: entries().filter((e) => e.argv).at(-1)?.argv ?? [] };
  };
  const a1 = await run("auto_edits", "grep -rn exchange src | head -40");
  t.check("auto edits: a search runs without asking you", !a1.asked && a1.log?.behavior === "allow", JSON.stringify(a1.log));
  const a2 = await run("auto_edits", `ssh -i k.pem ubuntu@host "docker exec api psql -U u -d db -c 'SELECT count(*) FROM exchange_programs'"`);
  t.check("auto edits: a read-only query on the server over SSH runs without asking", !a2.asked && a2.log?.behavior === "allow", JSON.stringify(a2.log));
  const a3 = await run("auto_edits", "rm -rf build");
  t.check("auto edits: deleting still asks you (and your No is respected)", a3.asked && a3.log?.behavior === "deny", JSON.stringify(a3));
  const a4 = await run("auto_edits", `ssh host "docker exec api node scripts/seed-exchange-catalogue.mjs"`);
  t.check("auto edits: changing the server still asks you", a4.asked, JSON.stringify(a4.log));
  const r1 = await run("read", "rm -rf build");
  t.check("read only: deleting is refused outright, without a question", !r1.asked && r1.log?.behavior === "deny" && /read only/.test(r1.log?.message ?? ""), JSON.stringify(r1));
  const r2 = await run("read", "git log --oneline -5");
  t.check("read only: reading runs", !r2.asked && r2.log?.behavior === "allow");
  t.check("read only starts Claude Code in default mode with the writing tools switched off (no plan mode, so no plan file)", r2.argv.includes("--permission-mode") && r2.argv[r2.argv.indexOf("--permission-mode") + 1] === "default" && r2.argv.includes("--disallowedTools") && /Write,Edit,MultiEdit,NotebookEdit/.test(r2.argv[r2.argv.indexOf("--disallowedTools") + 1]), JSON.stringify(r2.argv).slice(0, 300));
  const s1 = await run("supervised", "ls");
  t.check("supervised still asks for everything", s1.asked);

  // ---- skills: three small built-ins, a project skill, listed one line each in every chat ----
  const userSkills = join(base, "state", "skills");
  t.check("the three built-in skills are written to your skills folder", ["fix-bug", "check-on-screen", "server-change"].every((n) => existsSync(join(userSkills, n, "SKILL.md"))));
  mkdirSync(join(base, ".opscode", "skills", "shop-project"), { recursive: true });
  writeFileSync(join(base, ".opscode", "skills", "shop-project", "SKILL.md"), "---\nname: shop-project\ndescription: How the shop runs\n---\nDetails here.\n");
  await run("auto_edits", "ls");
  const argv = entries().filter((e) => e.argv && e.argv.includes("--append-system-prompt")).at(-1)?.argv ?? [];
  const notes = argv[argv.indexOf("--append-system-prompt") + 1] ?? "";
  t.check("a Claude Code chat gets one line per skill with its file path", /Skills: short how-to files/.test(notes) && notes.includes(`fix-bug: Fixing a bug`) && notes.includes(join(userSkills, "fix-bug", "SKILL.md")) && notes.includes("server-change") && notes.includes("check-on-screen"), notes.slice(0, 300));
  t.check("the project's own skill is listed too", notes.includes("shop-project: How the shop runs") && notes.includes(join(base, ".opscode", "skills", "shop-project", "SKILL.md")));
  t.check("only names and one line are sent, not the skill text", !notes.includes("Go to the first error, not the last") && !notes.includes("Details here."));
  const cx = (await C.call("chat.create", { workspace_id: wid, mode: "auto_edits", engine: "codex" })).result.chat;
  const ct = (await C.call("turn.submit", { workspace_id: wid, chat_id: cx.id, text: "hello" })).result.turn_id;
  await waitFor(() => C.find("turn.event", (p) => p.turn_id === ct && (p.type === "completed" || p.type === "failed"))[0]);
  const start = entries().filter((e) => e.method === "thread/start").at(-1);
  t.check("a Codex chat gets the same skills list", /fix-bug/.test(start?.params?.developerInstructions ?? "") && /shop-project/.test(start?.params?.developerInstructions ?? ""), JSON.stringify(start ?? {}).slice(0, 200));
  writeFileSync(join(userSkills, "fix-bug", "SKILL.md"), "---\nname: fix-bug\ndescription: my own version\n---\nmine\n");
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
}
// A restart never overwrites a skill you edited.
const rt2 = await startRuntime({ env, stateDir: join(base, "state"), keepState: true });
await rt2.stop();
t.check("a restart keeps your edited skill", readFileSync(join(base, "state", "skills", "fix-bug", "SKILL.md"), "utf8").includes("my own version"));
process.exit(t.finish());
