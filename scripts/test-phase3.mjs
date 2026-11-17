// Phase 3 tests: workspaces, sandboxed file access (incl. symlink escapes and
// .git protection), real PTY terminals, and streamed chat turns.

import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, statSync, symlinkSync, writeFileSync, chmodSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, sleep, startRuntime, waitFor } from "./lib/harness.mjs";

const t = reporter();
const E = { INVALID: -32602, NOT_FOUND: -32004, FORBIDDEN: -32005, CONFLICT: -32009 };
const code = (res) => res.error?.code;
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 160);

// ---- fixture: a project folder plus a separate "outside" folder ------------
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p3-")));
const ws = join(base, "project");
const outside = join(base, "outside");
mkdirSync(join(ws, "src"), { recursive: true });
mkdirSync(join(ws, ".git"), { recursive: true });
mkdirSync(outside);
writeFileSync(join(ws, "README.md"), "hello opscode\n");
writeFileSync(join(ws, "src/app.ts"), "export const answer = 42;\n");
writeFileSync(join(ws, "data.bin"), Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x00, 0x01, 0xff]));
writeFileSync(join(ws, "big.txt"), "x".repeat(300_000));
writeFileSync(join(ws, ".git/config"), "[core]\n");
writeFileSync(join(outside, "secret.txt"), "TOP SECRET\n");
symlinkSync(outside, join(ws, "link-out")); // dir symlink pointing outside
symlinkSync(join(ws, "src"), join(ws, "link-in")); // dir symlink pointing inside
symlinkSync(join(outside, "secret.txt"), join(ws, "evil.txt")); // leaf symlink pointing outside
symlinkSync(join(outside, "nope.txt"), join(ws, "dangling")); // broken symlink
writeFileSync(join(base, "not-a-dir.txt"), "x");

// Run the runtime the way the app does: ELECTRON_RUN_AS_NODE set (must not
// leak into terminals). /bin/sh keeps shell startup quiet and deterministic.
const rt = await startRuntime({ env: { ELECTRON_RUN_AS_NODE: "1", SHELL: "/bin/sh" } });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const A = await session(rt);
  const B = await session(rt);

  // ---- workspaces -----------------------------------------------------------
  let res = await A.call("workspace.add", { path: "relative/dir" });
  t.check("workspace.add relative path -> invalid", code(res) === E.INVALID, why(res));
  res = await A.call("workspace.add", { path: join(base, "missing") });
  t.check("workspace.add missing dir -> not found", code(res) === E.NOT_FOUND, why(res));
  res = await A.call("workspace.add", { path: join(base, "not-a-dir.txt") });
  t.check("workspace.add a file -> invalid", code(res) === E.INVALID, why(res));
  res = await A.call("workspace.add", { path: "/" });
  t.check("workspace.add filesystem root -> invalid", code(res) === E.INVALID, why(res));
  res = await A.call("workspace.add", { path: ws, extra: 1 });
  t.check("unknown param rejected", code(res) === E.INVALID, why(res));

  res = await A.call("workspace.add", { path: ws });
  const W = res.result?.workspace;
  t.check("workspace.add -> created, name, real path", res.result?.created === true && W?.name === "project" && W?.path === ws, why(res));
  t.check("other session gets workspace.changed", await waitFor(() => B.find("workspace.changed", (p) => p.workspaces.some((w) => w.id === W.id)).length > 0));
  res = await A.call("workspace.add", { path: ws + "/./" });
  t.check("adding the same folder again is deduplicated", res.result?.created === false && res.result?.workspace?.id === W.id, why(res));
  res = await A.call("workspace.list", {});
  t.check("workspace.list includes it", res.result?.workspaces?.length === 1 && res.result.workspaces[0].id === W.id);
  const wsFile = join(rt.stateDir, "workspaces.json");
  t.check("workspaces persisted 0600", existsSync(wsFile) && (statSync(wsFile).mode & 0o777) === 0o600 && readFileSync(wsFile, "utf8").includes(W.id));
  const wid = W.id;

  // ---- fs.list --------------------------------------------------------------
  res = await A.call("fs.list", { workspace_id: wid });
  const names = res.result?.entries?.map((e) => `${e.kind}:${e.name}`) ?? [];
  t.check("fs.list root: dirs first, sorted", names[0] === "dir:.git" && names[1] === "dir:src", names.slice(0, 3).join(" "));
  t.check("fs.list reports symlinks without following", names.includes("symlink:link-out") && names.includes("symlink:evil.txt"));
  res = await A.call("fs.list", { workspace_id: wid, path: "src" });
  t.check("fs.list subfolder", res.result?.entries?.[0]?.name === "app.ts" && res.result.path === "src", why(res));
  res = await A.call("fs.list", { workspace_id: wid, path: "../" });
  t.check("fs.list ../ -> forbidden", code(res) === E.FORBIDDEN, why(res));
  res = await A.call("fs.list", { workspace_id: wid, path: "/etc" });
  t.check("fs.list absolute path -> invalid", code(res) === E.INVALID, why(res));
  res = await A.call("fs.list", { workspace_id: wid, path: "link-out" });
  t.check("fs.list through outside symlink -> forbidden", code(res) === E.FORBIDDEN, why(res));
  res = await A.call("fs.list", { workspace_id: wid, path: "link-in" });
  t.check("fs.list through inside symlink -> ok (real path reported)", res.result?.path === "src", why(res));
  res = await A.call("fs.list", { workspace_id: "nope" });
  t.check("unknown workspace -> not found", code(res) === E.NOT_FOUND, why(res));

  // ---- fs.read --------------------------------------------------------------
  res = await A.call("fs.read", { workspace_id: wid, path: "README.md" });
  t.check("fs.read text as utf8", res.result?.encoding === "utf8" && res.result.content === "hello opscode\n" && res.result.truncated === false, why(res));
  res = await A.call("fs.read", { workspace_id: wid, path: "data.bin" });
  t.check("fs.read binary as base64", res.result?.encoding === "base64" && Buffer.from(res.result.content, "base64").equals(readFileSync(join(ws, "data.bin"))), why(res));
  res = await A.call("fs.read", { workspace_id: wid, path: "big.txt", max_bytes: 1000 });
  t.check("fs.read max_bytes truncates", res.result?.truncated === true && res.result.content.length === 1000 && res.result.size === 300_000, why(res));
  res = await A.call("fs.read", { workspace_id: wid, path: "nope.txt" });
  t.check("fs.read missing -> not found", code(res) === E.NOT_FOUND, why(res));
  res = await A.call("fs.read", { workspace_id: wid, path: "src" });
  t.check("fs.read a directory -> invalid", code(res) === E.INVALID, why(res));
  res = await A.call("fs.read", { workspace_id: wid, path: "link-out/secret.txt" });
  t.check("fs.read via outside dir symlink -> forbidden", code(res) === E.FORBIDDEN, why(res));
  res = await A.call("fs.read", { workspace_id: wid, path: "evil.txt" });
  t.check("fs.read outside leaf symlink -> forbidden", code(res) === E.FORBIDDEN, why(res));
  res = await A.call("fs.read", { workspace_id: wid, path: "../outside/secret.txt" });
  t.check("fs.read ../ escape -> forbidden", code(res) === E.FORBIDDEN, why(res));

  // ---- fs.write -------------------------------------------------------------
  res = await A.call("fs.write", { workspace_id: wid, path: "notes/todo.md", content: "- ship\n" });
  t.check("fs.write into missing folder needs create_dirs", code(res) === E.NOT_FOUND, why(res));
  res = await A.call("fs.write", { workspace_id: wid, path: "notes/todo.md", content: "- ship\n", create_dirs: true });
  t.check("fs.write with create_dirs", res.result?.path === "notes/todo.md" && readFileSync(join(ws, "notes/todo.md"), "utf8") === "- ship\n", why(res));
  res = await A.call("fs.write", { workspace_id: wid, path: ".git/config", content: "pwned" });
  t.check("fs.write .git/config -> forbidden", code(res) === E.FORBIDDEN && readFileSync(join(ws, ".git/config"), "utf8") === "[core]\n", why(res));
  res = await A.call("fs.write", { workspace_id: wid, path: ".git/hooks/pre-commit", content: "x", create_dirs: true });
  t.check("fs.write .git/hooks -> forbidden (nothing created)", code(res) === E.FORBIDDEN && !existsSync(join(ws, ".git/hooks")), why(res));
  res = await A.call("fs.write", { workspace_id: wid, path: "evil.txt", content: "pwned" });
  t.check("fs.write outside leaf symlink -> forbidden, target intact", code(res) === E.FORBIDDEN && readFileSync(join(outside, "secret.txt"), "utf8") === "TOP SECRET\n", why(res));
  res = await A.call("fs.write", { workspace_id: wid, path: "link-out/pwned.txt", content: "x" });
  t.check("fs.write via outside dir symlink -> forbidden, nothing created", code(res) === E.FORBIDDEN && !existsSync(join(outside, "pwned.txt")), why(res));
  res = await A.call("fs.write", { workspace_id: wid, path: "link-out/deep/new.txt", content: "x", create_dirs: true });
  t.check("fs.write create_dirs via outside symlink -> forbidden, no dirs made", code(res) === E.FORBIDDEN && !existsSync(join(outside, "deep")), why(res));
  res = await A.call("fs.write", { workspace_id: wid, path: "dangling", content: "x" });
  t.check("fs.write broken symlink -> forbidden", code(res) === E.FORBIDDEN && !existsSync(join(outside, "nope.txt")), why(res));
  res = await A.call("fs.write", { workspace_id: wid, path: "../escape.txt", content: "x" });
  t.check("fs.write ../ escape -> forbidden", code(res) === E.FORBIDDEN && !existsSync(join(base, "escape.txt")), why(res));
  res = await A.call("fs.write", { workspace_id: wid, path: "link-in/app.ts", content: "export const answer = 43;\n" });
  t.check("fs.write through inside symlink updates the real file", res.result?.path === "src/app.ts" && readFileSync(join(ws, "src/app.ts"), "utf8").includes("43"), why(res));
  chmodSync(join(ws, "README.md"), 0o600);
  res = await A.call("fs.write", { workspace_id: wid, path: "README.md", content: "updated\n" });
  t.check("fs.write overwrite keeps file mode", res.result && (statSync(join(ws, "README.md")).mode & 0o777) === 0o600 && readFileSync(join(ws, "README.md"), "utf8") === "updated\n", why(res));
  const bin = Buffer.from([0, 1, 2, 250, 251, 252]);
  res = await A.call("fs.write", { workspace_id: wid, path: "out.bin", content: bin.toString("base64"), encoding: "base64" });
  t.check("fs.write base64 round-trips bytes", res.result?.size === 6 && readFileSync(join(ws, "out.bin")).equals(bin), why(res));
  res = await A.call("fs.write", { workspace_id: wid, path: "x.bin", content: "not base64!", encoding: "base64" });
  t.check("fs.write bad base64 -> invalid", code(res) === E.INVALID, why(res));
  res = await A.call("fs.write", { workspace_id: wid, path: "src", content: "x" });
  t.check("fs.write onto a directory -> invalid", code(res) === E.INVALID, why(res));
  t.check("no temp files left behind", !readFileSync(join(rt.stateDir, "workspaces.json"), "utf8").includes(".tmp") &&
    !(await A.call("fs.list", { workspace_id: wid })).result.entries.some((e) => e.name.includes(".opscode-")));

  // ---- terminals (real PTY) --------------------------------------------------
  const outputOf = (c, tid) => c.find("term.output", (p) => p.terminal_id === tid).map((n) => n.params.data).join("");
  const exitOf = (c, tid) => c.find("term.exit", (p) => p.terminal_id === tid)[0]?.params;

  res = await A.call("term.open", { workspace_id: wid, command: "echo opscode-$((40+2)); echo ERAN=${ELECTRON_RUN_AS_NODE:-unset}; test -t 1 && echo IS_TTY" });
  let tid = res.result?.terminal_id;
  t.check("term.open runs a command", !!tid && res.result.running === true, why(res));
  t.check("command exits with code 0", await waitFor(() => exitOf(A, tid)?.exit_code === 0, 8000), JSON.stringify(exitOf(A, tid)));
  const out1 = outputOf(A, tid);
  t.check("output streamed via term.output", out1.includes("opscode-42"), JSON.stringify(out1.slice(0, 120)));
  t.check("runs on a real TTY", out1.includes("IS_TTY"));
  t.check("ELECTRON_RUN_AS_NODE does not leak into terminals", out1.includes("ERAN=unset"), JSON.stringify(out1.slice(0, 160)));

  res = await A.call("term.open", { workspace_id: wid, cwd: "src", command: "pwd" });
  const tidPwd = res.result?.terminal_id;
  t.check("term.open cwd inside project", await waitFor(() => outputOf(A, tidPwd).includes(`${ws}/src`), 8000), JSON.stringify(outputOf(A, tidPwd)));
  res = await A.call("term.open", { workspace_id: wid, cwd: "../" });
  t.check("term.open cwd escape -> forbidden", code(res) === E.FORBIDDEN, why(res));
  res = await A.call("term.open", { workspace_id: wid, cwd: "link-out" });
  t.check("term.open cwd via outside symlink -> forbidden", code(res) === E.FORBIDDEN, why(res));
  res = await A.call("term.open", { workspace_id: wid, cols: 9999 });
  t.check("term.open bad cols -> invalid", code(res) === E.INVALID, why(res));

  // Interactive shell
  res = await A.call("term.open", { workspace_id: wid, cols: 100, rows: 30 });
  tid = res.result?.terminal_id;
  await sleep(300);
  res = await A.call("term.write", { terminal_id: tid, data: "echo hi-$((1+1))\r" });
  t.check("term.write to interactive shell", !res.error && (await waitFor(() => outputOf(A, tid).includes("hi-2"), 8000)), JSON.stringify(outputOf(A, tid).slice(-120)));
  res = await A.call("term.resize", { terminal_id: tid, cols: 120, rows: 40 });
  t.check("term.resize", res.result?.cols === 120 && res.result?.rows === 40, why(res));
  await A.call("term.write", { terminal_id: tid, data: "tput cols\r" });
  t.check("resize reaches the PTY", await waitFor(() => /\b120\b/.test(outputOf(A, tid)), 8000));

  res = await B.call("term.attach", { terminal_id: tid });
  t.check("term.attach from another window returns scrollback", res.result?.scrollback?.includes("hi-2"), why(res));
  await B.call("term.write", { terminal_id: tid, data: "echo from-b\r" });
  t.check("attached window receives live output", await waitFor(() => outputOf(B, tid).includes("from-b"), 8000));
  res = await A.call("term.list", { workspace_id: wid });
  t.check("term.list shows open terminals", res.result?.terminals?.some((x) => x.terminal_id === tid && x.running), why(res));

  res = await A.call("term.close", { terminal_id: tid });
  t.check("term.close", res.result?.closed === true && (await waitFor(() => !!exitOf(A, tid), 8000)), why(res));
  res = await A.call("term.write", { terminal_id: tid, data: "x" });
  t.check("write after close -> not found", code(res) === E.NOT_FOUND, why(res));
  res = await A.call("term.open", { workspace_id: "nope" });
  t.check("term.open unknown workspace -> not found", code(res) === E.NOT_FOUND, why(res));

  // ---- turns (stub engine) ---------------------------------------------------
  const events = (c, turn) => c.find("turn.event", (p) => p.turn_id === turn).map((n) => n.params);
  res = await A.call("turn.submit", { workspace_id: wid, text: "hello there" });
  const turn = res.result?.turn_id;
  t.check("turn.submit returns turn_id + engine", !!turn && res.result.engine === "echo", why(res));
  t.check("turn completes", await waitFor(() => events(B, turn).some((e) => e.type === "completed"), 8000));
  const evs = events(B, turn);
  const deltas = evs.filter((e) => e.type === "delta").map((e) => e.text).join("");
  const done = evs.find((e) => e.type === "completed");
  t.check("events ordered: started, deltas, completed", evs[0]?.type === "started" && evs.at(-1)?.type === "completed" && evs.every((e, i) => e.seq === i));
  t.check("deltas assemble the final text", deltas === done?.text && deltas.includes("hello there"), JSON.stringify(deltas.slice(0, 80)));
  res = await A.call("turn.history", { workspace_id: wid });
  const msgs = res.result?.messages ?? [];
  t.check("history has user + assistant", msgs.length === 2 && msgs[0].role === "user" && msgs[1].status === "complete" && msgs[1].text === deltas, why(res));

  res = await A.call("turn.submit", { workspace_id: wid, text: "word ".repeat(400) });
  const longTurn = res.result?.turn_id;
  res = await A.call("turn.submit", { workspace_id: wid, text: "second" });
  t.check("second turn while one runs -> conflict", code(res) === E.CONFLICT, why(res));
  await waitFor(() => events(A, longTurn).some((e) => e.type === "delta"), 4000);
  res = await A.call("turn.interrupt", { turn_id: longTurn });
  t.check("turn.interrupt", res.result?.interrupted === true, why(res));
  t.check("interrupted event", await waitFor(() => events(A, longTurn).some((e) => e.type === "interrupted"), 4000));
  res = await A.call("turn.history", { workspace_id: wid });
  t.check("history marks the reply interrupted", res.result?.messages?.at(-1)?.status === "interrupted");
  res = await A.call("turn.interrupt", { turn_id: longTurn });
  t.check("interrupting a finished turn -> interrupted:false", res.result?.interrupted === false, why(res));
  res = await A.call("turn.interrupt", { turn_id: "nope" });
  t.check("interrupt unknown turn -> not found", code(res) === E.NOT_FOUND, why(res));
  res = await A.call("turn.submit", { workspace_id: wid, text: "   " });
  t.check("blank text -> invalid", code(res) === E.INVALID, why(res));

  // ---- workspace.remove ------------------------------------------------------
  const keep = await A.call("term.open", { workspace_id: wid });
  res = await A.call("workspace.remove", { workspace_id: wid });
  t.check("workspace.remove", res.result?.removed === true, why(res));
  t.check("removing a project closes its terminals", await waitFor(() => !!exitOf(A, keep.result.terminal_id), 8000));
  res = await A.call("fs.list", { workspace_id: wid });
  t.check("removed workspace -> not found", code(res) === E.NOT_FOUND, why(res));
  res = await A.call("workspace.remove", { workspace_id: wid });
  t.check("remove twice -> not found", code(res) === E.NOT_FOUND, why(res));

  // Leave a long-running terminal open so shutdown has to kill it.
  const ws2 = await A.call("workspace.add", { path: join(ws, "src") });
  const lingering = await A.call("term.open", { workspace_id: ws2.result.workspace.id, command: "sleep 300" });
  globalThis.lingeringPid = lingering.result?.pid;
  t.check("term.open reports the shell pid", Number.isInteger(globalThis.lingeringPid), why(lingering));

  A.close();
  B.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  const pid = globalThis.lingeringPid;
  const alive = (p) => {
    try {
      process.kill(p, 0);
      return true;
    } catch {
      return false;
    }
  };
  t.check("shutdown kills still-running terminal processes", pid !== undefined && (await waitFor(() => !alive(pid), 3000)), `pid ${pid}`);
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}

process.exit(t.finish());
