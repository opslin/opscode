// Side panel runtime: workspace.env, changes.diff (git), fs.search, local servers,
// actions (project file, personal, package.json suggestions), terminal run info,
// computer.preview. Git calls must not run programs from the repository's config.

import { execFileSync, spawn } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, realpathSync, rmSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, waitFor, sleep } from "./lib/harness.mjs";

const t = reporter();
const E = { INVALID: -32602, NOT_FOUND: -32004, FORBIDDEN: -32005 };
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 260);

const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p12-")));
const proj = join(base, "project");
const plain = join(base, "plain");
const outside = join(base, "outside");
for (const d of [proj, plain, outside]) mkdirSync(d);
const git = (args, cwd = proj) => execFileSync("git", ["-c", "user.name=t", "-c", "user.email=t@example.invalid", ...args], { cwd, stdio: "pipe" }).toString();
writeFileSync(join(proj, "a.txt"), "one\ntwo\n");
writeFileSync(join(proj, "gone.txt"), "bye\n");
writeFileSync(join(proj, "old-name.txt"), "rename me\nline\nline\n");
mkdirSync(join(proj, "src", "deep"), { recursive: true });
writeFileSync(join(proj, "src", "deep", "widget.ts"), "export const w = 1;\n");
mkdirSync(join(proj, "node_modules", "pkg"), { recursive: true });
writeFileSync(join(proj, "node_modules", "pkg", "widget.js"), "x");
symlinkSync(outside, join(proj, "link-out"));
writeFileSync(join(outside, "widget-secret.txt"), "no");
writeFileSync(join(proj, "package.json"), JSON.stringify({ name: "p", scripts: { dev: "vite", test: "vitest", pretest: "echo pre", postinstall: "echo x", build: "tsc", prepare: "husky" }, packageManager: "pnpm@9.0.0" }));
mkdirSync(join(proj, ".opscode"));
writeFileSync(join(proj, ".opscode", "actions.toml"), `[lint]\ncommand = "npm run lint"\nicon = "lint"\n\n[deploy-preview]\nname = "Deploy preview"\ncommand = "./deploy.sh staging"\n`);
git(["init", "-q", "-b", "main"]);
git(["add", "."]);
git(["commit", "-q", "-m", "first"]);
// Working tree changes: modify, delete, rename (staged), untracked.
writeFileSync(join(proj, "a.txt"), "one\nTWO\nthree\n");
rmSync(join(proj, "gone.txt"));
git(["mv", "old-name.txt", "new-name.txt"]);
writeFileSync(join(proj, "fresh.txt"), "f1\nf2\n");
// A hostile repo config (set last, so no git call in this test triggers it): if Opscode's git ran it, this file would appear.
const pwned = join(base, "PWNED");
writeFileSync(join(base, "evil.sh"), `#!/bin/sh\ntouch ${pwned}\n`, { mode: 0o755 });
git(["config", "core.fsmonitor", join(base, "evil.sh")]);
git(["config", "diff.external", join(base, "evil.sh")]);
git(["config", "core.pager", join(base, "evil.sh")]);

const stateDir = join(base, "state");
const rt = await startRuntime({ stateDir, keepState: true, env: { OPSCODE_COMPUTER_DRIVER: "mock", OPSCODE_COMPUTER_MOCK_LOG: join(base, "c.log"), OPSCODE_COMPUTER_MOCK_FRONT: join(base, "front.txt") } });
writeFileSync(join(base, "front.txt"), "Notes|com.apple.Notes");
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);
let server;
try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  const pid = (await C.call("workspace.add", { path: plain })).result.workspace.id;

  // ---- env ------------------------------------------------------------------------------------
  let res = await C.call("workspace.env", { workspace_id: wid });
  t.check("env: git repo, branch main", res.result?.env.git === true && res.result.env.branch === "main", why(res));
  res = await C.call("workspace.env", { workspace_id: pid });
  t.check("env: a plain folder has no git", res.result?.env.git === false && res.result.env.branch === null, why(res));
  res = await C.call("workspace.env", { workspace_id: "00000000-0000-4000-8000-000000000000" });
  t.check("env: unknown project is not-found", res.error?.code === E.NOT_FOUND, why(res));

  // ---- changes ------------------------------------------------------------------------------------
  res = await C.call("changes.diff", { workspace_id: wid });
  const ch = res.result;
  const f = (p) => ch?.files.find((x) => x.path === p);
  t.check("changes: modified file with counts", f("a.txt")?.status === "modified" && f("a.txt").added === 2 && f("a.txt").removed === 1, JSON.stringify(f("a.txt")));
  t.check("changes: deleted file", f("gone.txt")?.status === "deleted" && f("gone.txt").removed === 1, JSON.stringify(f("gone.txt")));
  t.check("changes: staged rename keeps the old path", f("new-name.txt")?.status === "renamed" && f("new-name.txt").old_path === "old-name.txt", JSON.stringify(ch?.files));
  t.check("changes: untracked file appears as all-added", f("fresh.txt")?.status === "untracked" && f("fresh.txt").added === 2 && ch.diff.includes("+++ b/fresh.txt") && ch.diff.includes("+f2"), JSON.stringify(f("fresh.txt")));
  t.check("changes: unified diff of tracked edits", ch?.diff.includes("-two") && ch.diff.includes("+TWO") && ch.branch === "main");
  t.check("git never ran the repository's fsmonitor or external diff program", !existsSync(pwned));
  res = await C.call("changes.diff", { workspace_id: pid });
  t.check("changes: a plain folder reports no git", res.result?.git === false && res.result.files.length === 0, why(res));

  // ---- search -------------------------------------------------------------------------------------
  res = await C.call("fs.search", { workspace_id: wid, query: "widget" });
  const paths = res.result?.results.map((r) => r.path) ?? [];
  t.check("search finds nested files by name", paths.includes("src/deep/widget.ts"), JSON.stringify(paths));
  t.check("search skips node_modules and does not follow links out of the project", !paths.some((p) => p.startsWith("node_modules") || p.startsWith("link-out")), JSON.stringify(paths));
  res = await C.call("fs.search", { workspace_id: wid, query: "", limit: 3 });
  t.check("search respects the limit", res.result?.results.length === 3, why(res));
  res = await C.call("fs.search", { workspace_id: wid, query: "x", limit: 99 });
  t.check("search rejects a limit over 50", res.error?.code === E.INVALID, why(res));

  // ---- actions --------------------------------------------------------------------------------------
  res = await C.call("actions.list", { workspace_id: wid });
  let acts = res.result;
  t.check("actions: project file read (name defaults from the id)", acts?.actions.some((a) => a.id === "lint" && a.name === "Lint" && a.icon === "lint" && a.source === "project") && acts.actions.some((a) => a.id === "deploy-preview" && a.name === "Deploy preview"), why(res));
  const sugg = acts?.suggestions.map((s) => s.command) ?? [];
  t.check("actions: package.json scripts suggested with the detected package manager", sugg.includes("pnpm run dev") && sugg.includes("pnpm run test") && sugg.includes("pnpm run build"), JSON.stringify(sugg));
  t.check("actions: install/publish hooks and pre/post hooks are not suggested", !sugg.some((s) => /postinstall|prepare|pretest/.test(s)), JSON.stringify(sugg));
  res = await C.call("actions.save", { workspace_id: wid, actions: [{ name: "Dev server", command: "pnpm run dev", icon: "play" }, { name: "Dev server", command: "echo two" }] });
  t.check("actions.save: personal actions get unique ids", res.result?.actions.map((a) => a.id).join() === "dev-server,dev-server-2" && res.result.actions.every((a) => a.source === "personal"), why(res));
  res = await C.call("actions.list", { workspace_id: wid });
  t.check("actions: a saved script is no longer suggested", !res.result.suggestions.some((s) => s.command === "pnpm run dev") && res.result.actions.length === 4, why(res));
  t.check("actions.json is private (0600)", (statSync(join(stateDir, "actions.json")).mode & 0o777) === 0o600);
  for (const [name, actions] of [["a line break", [{ name: "x", command: "a\nb" }]], ["an invisible character", [{ name: "x​", command: "ls" }]], ["a bad icon", [{ name: "x", command: "ls", icon: "rocket" }]], ["no command", [{ name: "x", command: "" }]], ["too many", Array.from({ length: 51 }, () => ({ name: "x", command: "ls" }))]]) {
    res = await C.call("actions.save", { workspace_id: wid, actions });
    t.check(`actions.save rejects ${name}`, res.error?.code === E.INVALID, why(res));
  }
  writeFileSync(join(proj, ".opscode", "actions.toml"), `[Bad Name]\ncommand = "x"\n`);
  res = await C.call("actions.list", { workspace_id: wid });
  t.check("actions: a broken project file is reported, personal actions still listed", typeof res.result?.error === "string" && res.result.actions.length === 2, why(res));
  writeFileSync(join(proj, ".opscode", "actions.toml"), `[lint]\ncommand = "npm run lint"\n`);
  res = await C.call("actions.save", { workspace_id: wid, actions: [] });
  t.check("actions.save with an empty list clears personal actions", res.result?.actions.length === 0, why(res));

  // ---- terminal run info --------------------------------------------------------------------------------
  const opened = (await C.call("term.open", { workspace_id: wid, command: "echo run-$((2*21))" })).result;
  t.check("term.open with a command records it and when it started", opened?.command === "echo run-$((2*21))" && typeof opened.created_at === "string", why({ result: opened }));
  await waitFor(() => C.find("term.exit", (p) => p.terminal_id === opened.terminal_id).length > 0, 8000);
  res = await C.call("term.list", { workspace_id: wid });
  const tinfo = res.result?.terminals.find((x) => x.terminal_id === opened.terminal_id);
  t.check("term.list shows the run finished with code 0 and when", tinfo && tinfo.running === false && tinfo.exit_code === 0 && typeof tinfo.exited_at === "string", JSON.stringify(tinfo));

  // ---- servers --------------------------------------------------------------------------------------------
  server = spawn(process.execPath, ["-e", "require('http').createServer((q,s)=>s.end('ok')).listen(0,'127.0.0.1',function(){console.log('PORT '+this.address().port)})"], { cwd: proj, stdio: ["ignore", "pipe", "ignore"] });
  const port = await new Promise((r) => server.stdout.on("data", (d) => { const m = /PORT (\d+)/.exec(String(d)); if (m) r(Number(m[1])); }));
  const outsider = spawn(process.execPath, ["-e", "require('http').createServer(()=>{}).listen(0,'127.0.0.1',function(){console.log('PORT '+this.address().port)})"], { cwd: outside, stdio: ["ignore", "pipe", "ignore"] });
  const outPort = await new Promise((r) => outsider.stdout.on("data", (d) => { const m = /PORT (\d+)/.exec(String(d)); if (m) r(Number(m[1])); }));
  res = await C.call("workspace.servers", { workspace_id: wid });
  const svs = res.result?.servers ?? [];
  t.check("servers: a server started in the project is found with its URL and process", svs.some((s) => s.port === port && s.url === `http://localhost:${port}` && s.pid === server.pid), why(res));
  t.check("servers: a server started elsewhere is not", !svs.some((s) => s.port === outPort), why(res));
  res = await C.call("workspace.servers.stop", { workspace_id: wid, pid: outsider.pid, port: outPort });
  t.check("servers.stop refuses a server that is not the project's", res.error?.code === E.NOT_FOUND && outsider.exitCode === null, why(res));
  res = await C.call("workspace.servers.stop", { workspace_id: wid, pid: server.pid, port });
  t.check("servers.stop stops the project's server", res.result?.stopped === true && (await waitFor(() => server.exitCode !== null || server.signalCode !== null, 4000)), why(res));
  outsider.kill();

  // ---- computer preview ------------------------------------------------------------------------------------
  res = await C.call("computer.preview");
  t.check("computer.preview refuses while computer use is off", res.error?.code === E.FORBIDDEN, why(res));
  await C.call("computer.set_enabled", { enabled: true });
  res = await C.call("computer.preview");
  t.check("computer.preview returns a JPEG data URL and the front app", res.result?.image?.startsWith("data:image/jpeg;base64,") && res.result.front === "Notes", why(res)?.slice(0, 120));

  // ---- removing the project forgets its personal actions -----------------------------------------------------
  await C.call("actions.save", { workspace_id: wid, actions: [{ name: "x", command: "ls" }] });
  await C.call("workspace.remove", { workspace_id: wid });
  const again = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  res = await C.call("actions.list", { workspace_id: again });
  t.check("removing a project forgets its personal actions", res.result?.actions.every((a) => a.source === "project"), why(res));
  C.close();
} finally {
  server?.kill();
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
