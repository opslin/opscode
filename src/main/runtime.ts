// Supervises the runtime child process: picks a free loopback port and a
// per-launch token, spawns the runtime, hands it the bootstrap on fd 3,
// waits for its READY line, restarts it with backoff if it crashes, and
// stops the whole process group on quit.

import { spawn, type ChildProcess } from "node:child_process";
import { randomBytes } from "node:crypto";
import { createServer } from "node:net";
import type { Writable } from "node:stream";
import { READY_LINE, SESSION_PATH, type Bootstrap } from "../shared/protocol";

const HOST = "127.0.0.1";
const WINDOWS = process.platform === "win32";
const MAX_CRASHES_PER_MINUTE = 5;

export interface Endpoint {
  url: string;
  token: string;
}

export interface SupervisorOptions {
  command: string;
  args: string[];
  env: NodeJS.ProcessEnv;
  stateDir: string;
  appVersion: string;
  log(line: string): void;
}

function freePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const server = createServer();
    server.unref();
    server.on("error", reject);
    server.listen(0, HOST, () => {
      const address = server.address();
      const port = typeof address === "object" && address ? address.port : 0;
      server.close(() => resolve(port));
    });
  });
}

export class RuntimeSupervisor {
  readonly endpoint: Endpoint;
  private child: ChildProcess | undefined;
  private ready = false;
  private failed: Error | undefined;
  private stopping = false;
  private crashes: number[] = [];
  private waiters = new Set<{ resolve(): void; reject(err: Error): void }>();

  private constructor(
    private readonly options: SupervisorOptions,
    private readonly port: number,
    private readonly token: string,
  ) {
    this.endpoint = { url: `ws://${HOST}:${port}${SESSION_PATH}`, token };
  }

  static async create(options: SupervisorOptions): Promise<RuntimeSupervisor> {
    return new RuntimeSupervisor(options, await freePort(), randomBytes(32).toString("hex"));
  }

  get pid(): number | undefined {
    return this.child?.pid;
  }

  start(): void {
    if (this.stopping) return;
    const { command, args, env, log } = this.options;
    const child = spawn(command, args, {
      env,
      stdio: ["ignore", "pipe", "pipe", "pipe"],
      detached: !WINDOWS, // own process group, so stop() can signal the whole tree
      windowsHide: true,
    });
    this.child = child;
    this.ready = false;
    log(`runtime: started pid=${child.pid}`);

    const boot: Bootstrap = {
      host: HOST,
      port: this.port,
      token: this.token,
      stateDir: this.options.stateDir,
      appVersion: this.options.appVersion,
      parentPid: process.pid,
    };
    const fd3 = child.stdio[3] as Writable | null;
    fd3?.on("error", () => undefined);
    fd3?.end(JSON.stringify(boot) + "\n");

    child.stdout?.setEncoding("utf8");
    child.stdout?.on("data", (chunk: string) => {
      for (const line of chunk.split("\n")) {
        if (!line.trim()) continue;
        if (line.startsWith(READY_LINE)) this.markReady();
        else log(line);
      }
    });
    child.stderr?.setEncoding("utf8");
    child.stderr?.on("data", (chunk: string) => {
      for (const line of chunk.split("\n")) if (line.trim()) log(`runtime(stderr): ${line}`);
    });

    child.on("error", (err) => log(`runtime: spawn error ${err.message}`));
    child.on("exit", (code, signal) => this.onExit(child, code, signal));
  }

  /** Resolves once the runtime is listening; rejects on timeout or if it gave up. */
  waitReady(timeoutMs: number): Promise<void> {
    if (this.ready) return Promise.resolve();
    if (this.failed) return Promise.reject(this.failed);
    return new Promise((resolve, reject) => {
      const waiter = {
        resolve: () => {
          clearTimeout(timer);
          resolve();
        },
        reject: (err: Error) => {
          clearTimeout(timer);
          reject(err);
        },
      };
      const timer = setTimeout(() => {
        this.waiters.delete(waiter);
        reject(new Error(`runtime not ready after ${timeoutMs} ms`));
      }, timeoutMs);
      this.waiters.add(waiter);
    });
  }

  /** SIGTERM the process group, then SIGKILL after 3 s. */
  async stop(): Promise<void> {
    this.stopping = true;
    const child = this.child;
    if (!child || child.exitCode !== null || child.signalCode !== null) return;
    await new Promise<void>((resolve) => {
      const kill = setTimeout(() => this.signal(child, "SIGKILL"), 3000);
      child.once("exit", () => {
        clearTimeout(kill);
        resolve();
      });
      this.signal(child, "SIGTERM");
    });
  }

  private markReady(): void {
    this.ready = true;
    this.options.log(`runtime: ready at ${this.endpoint.url}`);
    for (const w of this.waiters) w.resolve();
    this.waiters.clear();
  }

  private onExit(child: ChildProcess, code: number | null, signal: NodeJS.Signals | null): void {
    if (this.child === child) this.child = undefined;
    this.ready = false;
    if (this.stopping) {
      this.options.log(`runtime: stopped code=${code} signal=${signal}`);
      return;
    }
    this.options.log(`runtime: exited unexpectedly code=${code} signal=${signal}`);

    const now = Date.now();
    this.crashes = this.crashes.filter((t) => now - t < 60_000);
    this.crashes.push(now);
    if (this.crashes.length > MAX_CRASHES_PER_MINUTE) {
      this.failed = new Error("runtime keeps crashing; not restarting");
      this.options.log(`runtime: ${this.failed.message}`);
      for (const w of this.waiters) w.reject(this.failed);
      this.waiters.clear();
      return;
    }
    const delay = Math.min(500 * 2 ** (this.crashes.length - 1), 10_000);
    this.options.log(`runtime: restarting in ${delay} ms`);
    setTimeout(() => this.start(), delay);
  }

  private signal(child: ChildProcess, sig: NodeJS.Signals): void {
    const pid = child.pid;
    if (pid === undefined) return;
    try {
      if (WINDOWS) child.kill(sig);
      else process.kill(-pid, sig);
    } catch {
      try {
        child.kill(sig);
      } catch {
        /* already gone */
      }
    }
  }
}
