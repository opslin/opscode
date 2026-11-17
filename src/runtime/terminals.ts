// Terminal sessions backed by real PTYs (node-pty). A terminal belongs to a
// workspace, keeps running when a window disconnects, and keeps a bounded
// scrollback so a reconnecting window can re-attach and redraw.
//
// Output goes only to attached sessions (`term.output`), batched every few ms
// to avoid one frame per tiny write; `term.exit` reports the process exit.

import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { basename, isAbsolute, join } from "node:path";
import { spawn as spawnPty, type IPty } from "node-pty";
import { LIMITS, type RpcNotification } from "../shared/protocol";
import { fail } from "./rpc";

const FLUSH_MS = 8;

export interface TerminalInfo {
  terminal_id: string;
  workspace_id: string;
  /** OS pid of the shell process (useful for diagnostics and process lists). */
  pid: number;
  title: string;
  cols: number;
  rows: number;
  running: boolean;
  exit_code: number | null;
  /** Set when the terminal was opened to run one command (an action). */
  command?: string;
  created_at: string;
  exited_at?: string;
}

interface Terminal {
  command?: string;
  createdAt: string;
  exitedAt?: string;
  id: string;
  workspaceId: string;
  title: string;
  pty: IPty;
  cols: number;
  rows: number;
  attached: Set<string>;
  scrollback: string;
  pending: string;
  flushTimer: NodeJS.Timeout | undefined;
  exited: { exit_code: number; signal: number | null } | undefined;
  closing: boolean;
}

export interface TerminalDeps {
  notify(sessionId: string, n: RpcNotification): void;
  log(line: string): void;
}

/** The user's login shell (absolute $SHELL), else a platform default. */
function userShell(): string {
  if (process.platform === "win32") {
    // PowerShell 7 if it is installed, else the one that ships with Windows; cmd.exe as the last resort.
    const pf = process.env.ProgramFiles || "C:\\Program Files";
    const sys = join(process.env.SystemRoot || "C:\\Windows", "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
    for (const c of [join(pf, "PowerShell", "7", "pwsh.exe"), sys]) if (existsSync(c)) return c;
    return process.env.ComSpec || "cmd.exe";
  }
  const s = process.env.SHELL;
  if (s && isAbsolute(s)) return s;
  return process.platform === "darwin" ? "/bin/zsh" : "/bin/bash";
}

/** How to start the shell: interactive (a login shell) or to run one command. PowerShell and cmd.exe have their own flags. */
export function shellArgs(shell: string, command?: string): string[] {
  const name = (shell.split(/[\\/]/).pop() ?? shell).toLowerCase();
  if (name === "cmd.exe" || name === "cmd") return command === undefined ? [] : ["/d", "/s", "/c", command];
  if (name.startsWith("powershell") || name.startsWith("pwsh")) return command === undefined ? ["-NoLogo"] : ["-NoLogo", "-NoProfile", "-Command", command];
  return command === undefined ? ["-l"] : ["-lc", command];
}

/** Environment for terminals: ours minus anything that must not leak in. */
function terminalEnv(): Record<string, string> {
  const env: Record<string, string> = {};
  for (const [k, v] of Object.entries(process.env)) if (v !== undefined) env[k] = v;
  // The runtime itself runs as ELECTRON_RUN_AS_NODE; any Electron app started
  // from the terminal would silently turn into plain Node if this leaked.
  delete env.ELECTRON_RUN_AS_NODE;
  env.TERM = "xterm-256color";
  env.COLORTERM = "truecolor";
  env.TERM_PROGRAM = "Opscode";
  return env;
}

export class TerminalManager {
  private readonly terms = new Map<string, Terminal>();

  constructor(private readonly deps: TerminalDeps) {}

  open(o: { workspaceId: string; cwd: string; cols: number; rows: number; command?: string; sessionId: string }): TerminalInfo {
    const live = [...this.terms.values()].filter((t) => !t.closing).length;
    if (live >= LIMITS.TERM_MAX_OPEN) throw fail.limit(`at most ${LIMITS.TERM_MAX_OPEN} terminals can be open`);

    const shell = userShell();
    const args = shellArgs(shell, o.command);
    let pty: IPty;
    try {
      pty = spawnPty(shell, args, { name: "xterm-256color", cols: o.cols, rows: o.rows, cwd: o.cwd, env: terminalEnv() });
    } catch (e) {
      throw fail.io(`could not start a terminal: ${e instanceof Error ? e.message : String(e)}`);
    }

    const t: Terminal = {
      id: randomUUID(),
      workspaceId: o.workspaceId,
      title: o.command ?? basename(shell),
      ...(o.command !== undefined ? { command: o.command } : {}),
      createdAt: new Date().toISOString(),
      pty,
      cols: o.cols,
      rows: o.rows,
      attached: new Set([o.sessionId]),
      scrollback: "",
      pending: "",
      flushTimer: undefined,
      exited: undefined,
      closing: false,
    };
    this.terms.set(t.id, t);

    pty.onData((data) => {
      t.pending += data;
      t.flushTimer ??= setTimeout(() => this.flush(t), FLUSH_MS);
    });
    pty.onExit(({ exitCode, signal }) => {
      this.flush(t);
      t.exited = { exit_code: exitCode, signal: signal ?? null };
      t.exitedAt = new Date().toISOString();
      for (const s of t.attached) {
        this.deps.notify(s, { method: "term.exit", params: { terminal_id: t.id, exit_code: exitCode, signal: signal ?? null } });
      }
      if (t.closing) this.terms.delete(t.id);
    });

    this.deps.log(`terminal ${t.id} opened: ${t.title} (pid ${pty.pid})`);
    return this.info(t);
  }

  write(id: string, data: string): void {
    const t = this.live(id);
    if (t.exited) throw fail.conflict("the terminal process has exited");
    t.pty.write(data);
  }

  resize(id: string, cols: number, rows: number): TerminalInfo {
    const t = this.live(id);
    if (!t.exited) t.pty.resize(cols, rows);
    t.cols = cols;
    t.rows = rows;
    return this.info(t);
  }

  /** Attach a session: it receives future output and gets the scrollback now. */
  attach(id: string, sessionId: string): TerminalInfo & { scrollback: string } {
    const t = this.live(id);
    this.flush(t);
    t.attached.add(sessionId);
    return { ...this.info(t), scrollback: t.scrollback };
  }

  detach(id: string, sessionId: string): void {
    this.live(id).attached.delete(sessionId);
  }

  /** Kills the process (if running) and forgets the terminal. */
  close(id: string): void {
    const t = this.live(id);
    t.closing = true;
    if (t.exited) this.terms.delete(id);
    else t.pty.kill();
  }

  list(workspaceId?: string): TerminalInfo[] {
    return [...this.terms.values()]
      .filter((t) => !t.closing && (workspaceId === undefined || t.workspaceId === workspaceId))
      .map((t) => this.info(t));
  }

  /** A window went away: stop sending it output (terminals keep running). */
  sessionClosed(sessionId: string): void {
    for (const t of this.terms.values()) t.attached.delete(sessionId);
  }

  closeWorkspace(workspaceId: string): void {
    for (const t of this.terms.values()) if (t.workspaceId === workspaceId && !t.closing) this.close(t.id);
  }

  closeAll(): void {
    for (const t of this.terms.values()) {
      t.closing = true;
      if (!t.exited) t.pty.kill();
    }
    this.terms.clear();
  }

  private live(id: string): Terminal {
    const t = this.terms.get(id);
    if (!t || t.closing) throw fail.notFound("no such terminal");
    return t;
  }

  private flush(t: Terminal): void {
    if (t.flushTimer) clearTimeout(t.flushTimer);
    t.flushTimer = undefined;
    if (!t.pending) return;
    const data = t.pending;
    t.pending = "";
    t.scrollback += data;
    if (t.scrollback.length > LIMITS.TERM_SCROLLBACK_CHARS * 1.25) {
      t.scrollback = t.scrollback.slice(-LIMITS.TERM_SCROLLBACK_CHARS);
    }
    for (const s of t.attached) this.deps.notify(s, { method: "term.output", params: { terminal_id: t.id, data } });
  }

  private info(t: Terminal): TerminalInfo {
    return {
      terminal_id: t.id,
      workspace_id: t.workspaceId,
      pid: t.pty.pid,
      title: t.title,
      cols: t.cols,
      rows: t.rows,
      running: t.exited === undefined,
      exit_code: t.exited?.exit_code ?? null,
      ...(t.command !== undefined ? { command: t.command } : {}),
      created_at: t.createdAt,
      ...(t.exitedAt ? { exited_at: t.exitedAt } : {}),
    };
  }
}
