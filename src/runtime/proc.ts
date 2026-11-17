// Starting other programs the same way on every system. The one real difference is Windows, where tools installed with npm
// (Claude Code, Codex, MCP servers started with npx) are `.cmd` shims: they cannot be started directly, and going through
// cmd.exe breaks long or multi-line arguments (a system prompt). So a shim is read to find what it really runs (a Node script,
// started with Electron-as-Node, or a program) and that is started directly.

import { execFile, spawn, type ChildProcess, type ChildProcessWithoutNullStreams, type ExecFileOptions, type SpawnOptions } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { delimiter, dirname, extname, isAbsolute, join, resolve } from "node:path";

const WIN = process.platform === "win32";

export interface Launch { file: string; args: string[]; env: Record<string, string>; verbatim: boolean }

/** What a `.cmd` shim from npm / pnpm / yarn runs: its Node script or its own program, relative to the shim. */
export function shimTarget(shim: string): { js?: string; exe?: string } | null {
  let text: string;
  try { text = readFileSync(shim, "utf8"); } catch { return null; }
  const dir = dirname(shim);
  const at = (rel: string): string => resolve(dir, rel.replace(/^%~?dp0%?[\\/]*/i, "").replace(/\\/g, "/"));
  // npm: ... "%_prog%"  "%dp0%\node_modules\pkg\bin\tool.js" %*
  const js = [...text.matchAll(/"((?:%~?dp0%?|%dp0%)[\\/][^"]+\.(?:c|m)?js)"/gi)].pop();
  if (js) { const p = at(js[1]!); if (existsSync(p)) return { js: p }; }
  const exe = [...text.matchAll(/"((?:%~?dp0%?|%dp0%)[\\/][^"]+\.exe)"/gi)].pop();
  if (exe) { const p = at(exe[1]!); if (existsSync(p)) return { exe: p }; }
  return null;
}

/** cmd.exe quoting for the last resort (a shim that could not be read). */
const cmdQuote = (s: string): string => `"${s.replace(/"/g, '""').replace(/%/g, "%%")}"`;

export function launch(bin: string, args: string[], win = WIN): Launch {
  const none: Launch = { file: bin, args, env: {}, verbatim: false };
  if (!win) return none;
  const ext = extname(bin).toLowerCase();
  if (ext === ".cmd" || ext === ".bat") {
    const t = shimTarget(bin);
    if (t?.js) return { file: process.execPath, args: [t.js, ...args], env: { ELECTRON_RUN_AS_NODE: "1" }, verbatim: false };
    if (t?.exe) return { file: t.exe, args, env: {}, verbatim: false };
    return { file: process.env.ComSpec || "cmd.exe", args: ["/d", "/s", "/c", `"${[bin, ...args].map(cmdQuote).join(" ")}"`], env: {}, verbatim: true };
  }
  if (ext === ".js" || ext === ".mjs" || ext === ".cjs") return { file: process.execPath, args: [bin, ...args], env: { ELECTRON_RUN_AS_NODE: "1" }, verbatim: false };
  return none;
}

/** spawn() for an engine or tool program (Windows shims handled; Electron's run-as-node switch never leaks into the program). */
export function spawnProgram(bin: string, args: string[], opts: SpawnOptions = {}): ChildProcessWithoutNullStreams {
  const l = launch(bin, args);
  const env = { ...(opts.env ?? process.env), ...l.env } as Record<string, string | undefined>;
  if (!l.env.ELECTRON_RUN_AS_NODE) delete env.ELECTRON_RUN_AS_NODE;
  return spawn(l.file, l.args, { ...opts, env: env as NodeJS.ProcessEnv, ...(WIN ? { windowsHide: true, windowsVerbatimArguments: l.verbatim } : {}) }) as ChildProcessWithoutNullStreams;
}

/** execFile() for a program (Windows shims handled). */
export function execProgram(bin: string, args: string[], opts: ExecFileOptions, cb: (err: Error | null, stdout: string, stderr: string) => void): ChildProcess {
  const l = launch(bin, args);
  const env = { ...(opts.env ?? process.env), ...l.env } as Record<string, string | undefined>;
  if (!l.env.ELECTRON_RUN_AS_NODE) delete env.ELECTRON_RUN_AS_NODE;
  return execFile(l.file, l.args, { ...opts, encoding: "utf8", env: env as NodeJS.ProcessEnv, ...(WIN ? { windowsHide: true, windowsVerbatimArguments: l.verbatim } : {}) }, (e, so, se) => cb(e, String(so), String(se)));
}

/** Stops a program and everything it started. */
export function killTree(pid: number | undefined, signal: NodeJS.Signals = "SIGKILL"): void {
  if (!pid) return;
  try {
    if (WIN) execFile("taskkill", ["/pid", String(pid), "/T", "/F"], { windowsHide: true }, () => {});
    else process.kill(-pid, signal);
  } catch { /* already gone */ }
}

/** The extensions a program may have on this system, best first (Windows: real programs before shims; never a bare sh script). */
export const programExts = (win: boolean): string[] => (win ? [".exe", ".com", ".cmd", ".bat"] : [""]);
export const PROGRAM_EXTS: string[] = programExts(WIN);

/** Folders where per-user tools live, for finding programs that are not on PATH (Windows: npm, scoop, Microsoft installers). */
export function userToolDirs(): string[] {
  const home = process.env.USERPROFILE || process.env.HOME || "";
  if (!WIN) return [];
  const a = process.env.APPDATA || join(home, "AppData", "Roaming");
  const l = process.env.LOCALAPPDATA || join(home, "AppData", "Local");
  const pf = process.env.ProgramFiles || "C:\\Program Files";
  return [join(a, "npm"), join(home, ".local", "bin"), join(l, "Microsoft", "WindowsApps"), join(home, "scoop", "shims"), join(l, "Programs"), join(pf, "nodejs"), join(home, ".bun", "bin"), join(home, ".npm-global")].filter((d) => isAbsolute(d));
}

export { delimiter };
