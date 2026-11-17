// Which shell commands may run without asking. In "auto edits" a chat edits files on its own;
// this decides the commands: reading, searching, read-only queries, fetching and local tests run
// at once, and anything that deletes, writes to a live database or server, pushes, deploys,
// installs or that we do not recognise still asks the person. In "read only" the same check
// decides what may run at all (everything else is refused, not asked).
//
// Conservative by design: a command is "safe" only when every part of it is recognised as safe.

export type Verdict = "safe" | "ask";

const SAFE_PROGRAMS = new Set([
  "ls", "cat", "head", "tail", "wc", "grep", "egrep", "fgrep", "rg", "ag", "fd", "tree", "pwd", "echo", "printf", "which", "whereis", "type",
  "file", "stat", "du", "df", "date", "sort", "uniq", "cut", "tr", "awk", "jq", "yq", "diff", "cmp", "nl", "column", "basename", "dirname",
  "realpath", "readlink", "true", "false", "test", "[", "less", "more", "uname", "whoami", "id", "hostname", "uptime", "ps", "env", "printenv",
  "nproc", "free", "lsof", "netstat", "ss", "ping", "dig", "nslookup", "host", "md5", "md5sum", "shasum", "sha256sum", "base64", "xxd", "od",
  "strings", "zcat", "gzip", "unzip", "tar", "sleep", "cd", "seq", "comm", "paste", "fold", "expand", "tee",
]);
// Programs safe only with some sub-commands or without some flags.
const GIT_READ = new Set(["status", "log", "diff", "show", "branch", "remote", "ls-files", "blame", "rev-parse", "describe", "tag", "shortlog", "grep", "reflog", "stash", "config", "fetch"]);
const RUNNERS = new Set(["npm", "pnpm", "yarn", "bun", "npx"]);
const RUNNER_SAFE = new Set(["test", "run", "lint", "typecheck", "build", "start", "dev", "exec", "ls", "list", "outdated", "view", "why", "audit"]);
const RUNNER_SCRIPTS = /^(test|tests|lint|typecheck|type-check|check|build|dev|start|serve|preview|format:check|e2e|smoke|analyze)(:[\w-]+)?$/;
const TOOLS_SAFE: Record<string, RegExp> = {
  flutter: /^(test|analyze|build|run|doctor|devices|pub (get|deps|outdated))\b/,
  dart: /^(analyze|test|format --output=none|run)\b/,
  go: /^(test|build|vet|run|list|version|env)\b/,
  cargo: /^(test|build|check|clippy|run|tree)\b/,
  python: /^(-m (pytest|unittest|py_compile)|--version)\b/,
  python3: /^(-m (pytest|unittest|py_compile)|--version)\b/,
  node: /^(--version|-v|--check)\b/,
  tsc: /.*/,
  eslint: /.*/,
  vitest: /.*/,
  jest: /.*/,
  pytest: /.*/,
  playwright: /^test\b/,
  docker: /^(ps|logs|inspect|images|stats|top|version|info|compose (ps|logs|config))\b/,
  kubectl: /^(get|describe|logs|top)\b/,
  pm2: /^(ls|list|logs|status|show|describe)\b/,
  systemctl: /^(status|is-active|list-units)\b/,
  journalctl: /.*/,
  xcrun: /^simctl (list|io \S+ screenshot)\b/,
};
const SQL_WRITE = /\b(insert|update|delete|drop|alter|truncate|create|grant|revoke|vacuum|reindex|copy|merge|call|do|comment\s+on|refresh|cluster|lock)\b/i;
const SQL_READ = /^\s*(select|with|explain|show|table|values|\\d|\\l|\\dt|\\x)/i;

/** Splits on ; && || | and newlines, outside quotes. */
function parts(cmd: string): string[] {
  const out: string[] = [];
  let cur = "";
  let q: string | null = null;
  for (let i = 0; i < cmd.length; i++) {
    const c = cmd[i]!;
    if (q) { cur += c; if (c === q && cmd[i - 1] !== "\\") q = null; continue; }
    if (c === "'" || c === '"') { q = c; cur += c; continue; }
    if (c === "\n" || c === ";" || (c === "&" && cmd[i + 1] === "&") || c === "|") {
      if (cur.trim()) out.push(cur.trim());
      cur = "";
      if ((c === "&" || c === "|") && cmd[i + 1] === c) i++;
      continue;
    }
    cur += c;
  }
  if (cur.trim()) out.push(cur.trim());
  return out;
}

/** Words of one simple command, quotes removed (good enough for classification). */
function words(s: string): string[] {
  const out: string[] = [];
  const re = /"((?:\\.|[^"\\])*)"|'([^']*)'|(\S+)/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(s))) out.push(m[1] ?? m[2] ?? m[3] ?? "");
  return out;
}

/** True when writing to this redirect target is fine (scratch places; project files are edits, allowed in auto edits). */
interface Opts { root?: string | undefined; projectWrites: boolean }

function safeTarget(t: string, o: Opts): boolean {
  if (t === "/dev/null" || t.startsWith("/tmp/") || t.startsWith("/private/tmp/") || t.startsWith("&")) return true;
  if (!o.projectWrites) return false; // read only, or a remote machine: no writing files at all
  if (!t.startsWith("/") && !t.startsWith("~") && !t.includes("..")) return true; // relative: inside the project
  return !!o.root && t.startsWith(o.root + "/");
}

function sqlSafe(sql: string): boolean {
  const stmts = sql.split(";").map((x) => x.trim()).filter(Boolean);
  return stmts.length > 0 && stmts.every((s) => SQL_READ.test(s) && !SQL_WRITE.test(s.replace(/'[^']*'/g, "''")));
}

function simpleSafe(seg: string, o: Opts, depth: number): boolean {
  if (depth > 4) return false;
  if (/\$\(|`/.test(seg)) return false; // command substitution: cannot tell what runs
  // Redirects: writing to a file outside the project or scratch places is not a plain read.
  for (const m of seg.matchAll(/(?:^|\s)\d?>{1,2}\s*("([^"]*)"|'([^']*)'|(\S+))/g)) if (!safeTarget(m[2] ?? m[3] ?? m[4] ?? "", o)) return false;
  const clean = seg.replace(/(?:^|\s)\d?>{1,2}\s*("[^"]*"|'[^']*'|\S+)/g, " ").replace(/(?:^|\s)<\s*\S+/g, " ");
  let w = words(clean);
  while (w.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(w[0]!)) w = w.slice(1); // FOO=bar cmd
  if (!w.length) return true;
  const [prog, ...rest] = w;
  const p = prog!.split("/").pop()!;
  const argline = rest.join(" ");
  if (p === "sudo" || p === "su" || p === "doas") return false;
  if (p === "time" || p === "timeout" || p === "nice" || p === "nohup") return simpleSafe(rest.slice(p === "timeout" ? 1 : 0).join(" "), o, depth + 1);
  if (p === "bash" || p === "sh" || p === "zsh") { const i = rest.indexOf("-c"); return i >= 0 && rest[i + 1] !== undefined ? safe(rest[i + 1]!, o, depth + 1) === "safe" : false; }
  if (p === "sed") return !rest.some((a) => a === "-i" || a.startsWith("-i") || a === "--in-place");
  if (p === "find") return !rest.some((a) => ["-delete", "-exec", "-execdir", "-ok", "-fprint", "-fprintf"].includes(a));
  if (p === "tar") return /^-?t|--list/.test(rest[0] ?? "");
  if (p === "unzip") return rest.includes("-l") || rest.includes("-t");
  if (p === "gzip") return rest.includes("-l") || rest.includes("-t");
  if (p === "tee") return rest.filter((a) => !a.startsWith("-")).every((t) => safeTarget(t, o));
  if (SAFE_PROGRAMS.has(p)) return true;
  // Builds and dev servers write output into the project: fine in auto edits, not in read only.
  if (!o.projectWrites && /\b(build|dev|start|serve|run|preview)\b/.test(argline) && (RUNNERS.has(p) || p in TOOLS_SAFE)) return false;
  if (p === "git") return GIT_READ.has(rest[0] ?? "") && !/\s(--delete|-d|-D|--force|-f|drop|clear|pop|apply|--unset|--add|--replace-all|prune)\b/.test(` ${argline}`) && !(rest[0] === "stash" && rest[1] !== "list" && rest[1] !== "show") && !(rest[0] === "config" && !rest.includes("--get") && !rest.includes("--list") && !rest.includes("-l")) && !(rest[0] === "branch" && rest.length > 1 && !rest.every((a) => a.startsWith("-") && !/^-(d|D|m|M|c|C|f)$/.test(a))) && !(rest[0] === "tag" && rest.length > 1 && !rest.every((a) => a === "-l" || a === "--list" || a.startsWith("-n")));
  if (RUNNERS.has(p)) {
    if (p === "npx") return /^(tsc|eslint|vitest|jest|prettier --check|playwright test|tsx --version)\b/.test(argline);
    const sub = rest[0] ?? "";
    if (sub === "run" || sub === "run-script") return RUNNER_SCRIPTS.test(rest[1] ?? "");
    if (sub === "exec") return /^(tsc|eslint|vitest|jest)\b/.test(rest.slice(1).join(" "));
    return RUNNER_SAFE.has(sub) && sub !== "exec" && sub !== "run";
  }
  if (p === "curl" || p === "wget" || p === "http") {
    const a = ` ${argline} `;
    if (/\s-X\s*(POST|PUT|PATCH|DELETE)\b|--request\s+(POST|PUT|PATCH|DELETE)\b|\s(-d|--data\S*|-F|--form|-T|--upload-file|--json)\s/i.test(a)) return false;
    return !/\s-o\s+\/(?!tmp\/)|\s--output\s+\/(?!tmp\/)/.test(a);
  }
  if (p === "psql" || p === "mysql" || p === "sqlite3" || p === "mariadb") {
    const i = rest.findIndex((a) => a === "-c" || a === "--command" || a === "-e" || a === "--execute");
    if (i >= 0) return sqlSafe(rest[i + 1] ?? "");
    if (p === "sqlite3" && rest.length >= 2) return sqlSafe(rest[rest.length - 1]!);
    return false; // interactive or SQL from a file: cannot see it
  }
  if (p === "redis-cli") return /^(-\S+\s+\S+\s+)*(get|mget|keys|scan|ttl|type|info|dbsize|hget|hgetall|lrange|smembers|exists|ping)\b/i.test(argline);
  if (p === "ssh") {
    // ssh [options] host [command]: safe only when the remote command is.
    const opts1 = new Set(["-i", "-p", "-l", "-o", "-F", "-J", "-L", "-R", "-D", "-W", "-b", "-c", "-E", "-m", "-S"]);
    let k = 0;
    while (k < rest.length && rest[k]!.startsWith("-")) k += opts1.has(rest[k]!) ? 2 : 1;
    const remote = rest.slice(k + 1).join(" ");
    return remote.trim() ? safe(remote, { projectWrites: false }, depth + 1) === "safe" : false;
  }
  if (p === "docker" && rest[0] === "exec") {
    // docker exec [flags] container cmd...
    let k = 1;
    while (k < rest.length && rest[k]!.startsWith("-")) k += ["-e", "-u", "-w", "--env", "--user", "--workdir"].includes(rest[k]!) ? 2 : 1;
    return safe(rest.slice(k + 1).join(" "), { projectWrites: false }, depth + 1) === "safe";
  }
  const tool = TOOLS_SAFE[p];
  if (tool) return tool.test(argline);
  return false;
}

function safe(cmd: string, o: Opts, depth: number): Verdict {
  const segs = parts(cmd);
  if (!segs.length) return "ask";
  return segs.every((s) => simpleSafe(s, o, depth)) ? "safe" : "ask";
}

/** "safe": runs without asking in auto edits (and is allowed in read only); "ask": the person decides. */
export function classifyCommand(cmd: string, root?: string, projectWrites = true): Verdict {
  if (typeof cmd !== "string" || !cmd.trim() || cmd.length > 20_000) return "ask";
  return safe(cmd, { root, projectWrites }, 0);
}

/** Tools that only read or fetch, which need no question. */
export const READ_TOOLS = new Set(["Read", "Grep", "Glob", "LS", "WebFetch", "WebSearch", "TodoWrite", "BashOutput", "NotebookRead", "ToolSearch"]);
export const WRITE_TOOLS = ["Write", "Edit", "MultiEdit", "NotebookEdit"];

/**
 * What to do with one permission request from an engine, by the chat's mode:
 *  - read: read-only tools and safe commands run; everything else is refused (never asked).
 *  - auto_edits: read-only tools, file edits and safe commands run; the rest asks.
 *  - supervised: everything asks (as before). full: never reached (the engine skips permissions).
 */
export function permissionFor(mode: string, tool: string, input: Record<string, unknown>, root?: string): "allow" | "deny" | "ask" {
  const command = tool === "Bash" ? String(input.command ?? "") : null;
  if (mode === "read") {
    if (READ_TOOLS.has(tool)) return "allow";
    if (command !== null && classifyCommand(command, root, false) === "safe") return "allow";
    return "deny";
  }
  if (mode === "auto_edits") {
    if (READ_TOOLS.has(tool) || WRITE_TOOLS.includes(tool)) return "allow";
    if (command !== null) return classifyCommand(command, root) === "safe" ? "allow" : "ask";
    return "ask";
  }
  return "ask";
}
