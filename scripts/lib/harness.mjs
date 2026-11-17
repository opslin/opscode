// Shared test harness: spawns dist/runtime/index.js exactly like main does
// (bootstrap JSON on fd 3) and provides socket + client helpers.

import { spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import WebSocket from "ws";

export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
export const SUBPROTOCOL = "opscode.session.v1";
export const BEARER_PREFIX = "base64url.bearer.";

export function reporter() {
  let passed = 0;
  let failed = 0;
  return {
    check(name, ok, detail = "") {
      if (ok) passed++;
      else failed++;
      console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? `  (${detail})` : ""}`);
      return ok;
    },
    finish() {
      console.log(`\n${passed} passed, ${failed} failed`);
      return failed === 0 ? 0 : 1;
    },
  };
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export async function waitFor(pred, ms = 3000) {
  for (const end = Date.now() + ms; Date.now() < end; await sleep(20)) if (pred()) return true;
  return pred();
}

const freePort = () =>
  new Promise((res, rej) => {
    const s = createServer();
    s.on("error", rej);
    s.listen(0, "127.0.0.1", () => {
      const { port } = s.address();
      s.close(() => res(port));
    });
  });

/** Starts a runtime; returns its url/token/stateDir and stop(). */
export async function startRuntime({ env = {}, stateDir: given, keepState = false } = {}) {
  const stateDir = given ?? mkdtempSync(join(tmpdir(), "opscode-rt-"));
  const port = await freePort();
  const token = randomBytes(32).toString("hex");
  const child = spawn(process.execPath, [join(ROOT, "dist/runtime/index.js")], {
    stdio: ["ignore", "pipe", "pipe", "pipe"],
    // Tests never touch this machine's real Xcode simulators unless they pass a fake xcrun.
    env: { ...process.env, OPSCODE_XCRUN: "none", ...env },
  });
  child.stdio[3].end(
    JSON.stringify({ host: "127.0.0.1", port, token, stateDir, appVersion: "0.0.1-test", parentPid: process.pid }) + "\n",
  );
  let output = "";
  child.stderr.on("data", (c) => (output += c));
  child.stdout.on("data", (c) => (output += c));
  const ready = await new Promise((res) => {
    const t = setTimeout(() => res(false), 8000);
    child.stdout.on("data", (c) => {
      if (String(c).includes("OPSCODE_RUNTIME_READY")) {
        clearTimeout(t);
        res(true);
      }
    });
    child.on("exit", () => res(false));
  });
  return {
    ready,
    url: `ws://127.0.0.1:${port}/session/v1`,
    port,
    token,
    stateDir,
    child,
    output: () => output,
    async stop() {
      const exit = await new Promise((res) => {
        if (child.exitCode !== null) return res(`code=${child.exitCode} signal=${child.signalCode}`);
        const t = setTimeout(() => res("timeout"), 5000);
        child.once("exit", (code, signal) => {
          clearTimeout(t);
          res(`code=${code} signal=${signal}`);
        });
        child.kill("SIGTERM");
      });
      if (!keepState) rmSync(stateDir, { recursive: true, force: true });
      return exit;
    },
  };
}

/** Opens a socket; resolves {ws} on open or {status} if the upgrade was refused. */
export const dial = (url, protocols, options = {}) =>
  new Promise((res) => {
    const ws = new WebSocket(url, protocols, options);
    ws.once("open", () => res({ ws }));
    ws.once("unexpected-response", (req, r) => {
      req.destroy();
      res({ status: r.statusCode });
    });
    ws.once("error", (err) => res({ error: err.message }));
  });

/** Client over an open socket: call(), raw(), collected notifications. */
export function client(ws) {
  let nextId = 1;
  const pending = new Map();
  const notes = [];
  ws.on("message", (data) => {
    const msg = JSON.parse(data.toString());
    if (msg.id !== undefined && msg.id !== null && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
      pending.delete(msg.id);
    } else if (msg.method) notes.push(msg);
    else if (msg.id === null) pending.get("null")?.(msg);
  });
  return {
    notes,
    call: (method, params) =>
      new Promise((res) => {
        const id = nextId++;
        pending.set(id, res);
        ws.send(JSON.stringify({ id, method, params }));
      }),
    raw: (text) =>
      new Promise((res) => {
        pending.set("null", res);
        ws.send(text);
      }),
    /** Notifications matching method (and optional predicate on params). */
    find: (method, pred = () => true) => notes.filter((n) => n.method === method && pred(n.params)),
    close: () => ws.close(),
  };
}

/** Authenticated, hello'd client. */
export async function session(rt) {
  const { ws, status, error } = await dial(rt.url, [SUBPROTOCOL], { headers: { authorization: `Bearer ${rt.token}` } });
  if (!ws) throw new Error(`could not connect: ${status ?? error}`);
  const c = client(ws);
  const hello = await c.call("runtime.hello", { client_revision: 1 });
  if (hello.error) throw new Error(`hello failed: ${hello.error.message}`);
  return c;
}
