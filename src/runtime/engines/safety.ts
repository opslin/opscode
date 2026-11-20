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
export function permissionFor(mode: string, tool: string, input: Record<string, unknown>, root?: string, trusted = false): "allow" | "deny" | "ask" {
  const command = tool === "Bash" ? String(input.command ?? "") : null;
  if (mode === "auto") {
    if (READ_TOOLS.has(tool)) return "allow";
    if (command !== null) return autoAsks(riskOf(command, root), trusted) ? "ask" : "allow";
    if (WRITE_TOOLS.includes(tool)) {
      // Edits inside the project go ahead; writing somewhere else on the computer asks.
      const f = String(input.file_path ?? input.notebook_path ?? input.path ?? "");
      const inside = !f || !f.startsWith("/") || (!!root && (f === root || f.startsWith(root + "/"))) || /^\/(private\/)?tmp\//.test(f);
      return inside || trusted ? "allow" : "ask";
    }
    return autoAsks(toolRisk(tool), trusted) ? "ask" : "allow";
  }
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

// ---- Auto mode --------------------------------------------------------------------------------------------------------
// "auto": edits and nearly every command run without asking. Only what is hard to undo or reaches past this project asks:
//   high   - deleting files, database migrations and writes, git push / history rewrites, deploy / publish, sudo, disks
//   medium - system installs, killing processes, sending data to a server, writing outside the project, system settings
// A chat in "auto" asks for medium and high. In voice mode, once the person said "allow it yourself", only high asks.

export type Risk = "low" | "medium" | "high";

const GENERATED = /^(\.\/)?(node_modules|dist|build|out|\.next|\.nuxt|\.turbo|\.cache|coverage|target|__pycache__|\.pytest_cache|tmp|\.parcel-cache|\.svelte-kit)(\/|$)/;
const MIGRATE = /\b(migrat\w*|db:(push|reset|drop|seed|rollback|setup)|prisma\s+(migrate|db\s+(push|execute))|drizzle-kit\s+(push|migrate|drop)|alembic\s+(upgrade|downgrade)|manage\.py\s+(migrate|flush)|supabase\s+(db\s+(push|reset)|migration\s+up)|flyway|liquibase|knex\s+migrate|sequelize\s+db:)\b/i;
const DEPLOY_CMD = /^((vercel|netlify|fly|flyctl|heroku|firebase|wrangler|railway|surge)\b(?!\s+(--version|-v|login|whoami|status|logs?|list|ls|dev|help)\b)|(terraform|pulumi|cdk)\s+(apply|destroy|deploy|up)\b|kubectl\s+(apply|delete|replace|patch|scale|rollout|drain|cordon)\b|helm\s+(install|upgrade|uninstall|delete|rollback)\b|docker\s+(push|system\s+prune|volume\s+(rm|prune))\b|(aws|gcloud|az)\s+.*\b(delete|remove|rm|terminate|destroy|deploy|put|update|create)\b|gh\s+(release\s+(create|delete|upload|edit)|repo\s+(delete|archive|create|rename)|pr\s+(merge|close)|issue\s+(close|delete))\b)/i;
/** A script or target named like a release step (npm run deploy, make publish, ./release.sh). */
const DEPLOY_NAME = /(^|[\s/:])(deploy|publish|release|ship)[\w:.-]*(\s|$)/i;

function riskOne(seg: string, root: string | undefined, depth: number): Risk {
  if (depth > 4) return "medium";
  const w0 = words(seg.replace(/(?:^|\s)\d?>{1,2}\s*("[^"]*"|'[^']*'|\S+)/g, " "));
  let w = w0;
  while (w.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(w[0]!)) w = w.slice(1);
  if (!w.length) return "low";
  const p = w[0]!.split("/").pop()!;
  const rest = w.slice(1);
  const args = rest.join(" ");
  if (p === "time" || p === "timeout" || p === "nice" || p === "nohup" || p === "xargs") return riskOne(rest.slice(p === "timeout" ? 1 : 0).filter((a, i) => p !== "xargs" || !(i === 0 && a.startsWith("-"))).join(" "), root, depth + 1);
  if (p === "bash" || p === "sh" || p === "zsh") { const i = rest.indexOf("-c"); return i >= 0 && rest[i + 1] ? riskOf(rest[i + 1]!, root, depth + 1) : "medium"; }
  if (["sudo", "su", "doas", "mkfs", "dd", "diskutil", "fdisk", "shutdown", "reboot", "halt", "srm", "shred"].includes(p)) return "high";
  // Anything the read-only check already knows is harmless (reading, searching, tests, builds, read-only queries).
  if (classifyCommand(seg, root) === "safe") return "low";
  // Deleting. Generated folders and scratch places are fine; anything else is the person's call.
  if (p === "rm" || p === "rmdir" || p === "unlink" || p === "trash") {
    const targets = rest.filter((a) => !a.startsWith("-"));
    if (!targets.length) return "low";
    return targets.every((t) => GENERATED.test(t) || /^\/(private\/)?tmp\//.test(t) || (!!root && GENERATED.test(t.replace(root + "/", "")))) ? "low" : "high";
  }
  if (p === "find" && rest.some((a) => a === "-delete" || ((a === "-exec" || a === "-execdir") && /\brm\b/.test(args)))) return "high";
  if (p === "git") {
    const sub = rest[0] ?? "";
    if (sub === "push" || sub === "filter-branch" || sub === "filter-repo" || sub === "clean" || sub === "rm") return "high";
    if (sub === "reset" && /--hard|--merge|--keep/.test(args)) return "high";
    if ((sub === "checkout" || sub === "restore") && /(^|\s)(--\s+)?\.(\s|$)|--force|-f\b/.test(args.slice(sub.length))) return "high";
    if (sub === "branch" && /\s-(D|d|-delete)\b/.test(` ${args}`)) return "high";
    if (sub === "stash" && /\b(drop|clear)\b/.test(args)) return "high";
    if (sub === "tag" && /\s-d\b/.test(` ${args}`)) return "high";
    if (sub === "config" && /--global|--system/.test(args)) return "medium";
    return "low";
  }
  const line = `${p} ${args}`;
  if (MIGRATE.test(line)) return "high";
  if (DEPLOY_CMD.test(line)) return "high";
  if ((RUNNERS.has(p) || p === "make" || p === "just" || p === "task") && DEPLOY_NAME.test(args)) return "high";
  if (DEPLOY_NAME.test(` ${p} `) || /(^|\/)(deploy|publish|release)[\w.-]*\.(sh|js|mjs|ts|py)$/i.test(rest[0] ?? "")) return "high";
  if (/\b(npm|pnpm|yarn|bun)\s+(publish|unpublish|deprecate|owner|dist-tag|token|adduser|login)\b/.test(seg)) return "high";
  if (p === "psql" || p === "mysql" || p === "sqlite3" || p === "mariadb" || p === "mongosh" || p === "mongo") return classifyCommand(seg, root, false) === "safe" ? "low" : "high";
  if (p === "redis-cli") return /\b(flushall|flushdb|del|unlink|config\s+set|shutdown)\b/i.test(args) ? "high" : classifyCommand(seg, root, false) === "safe" ? "low" : "medium";
  // A server: copying files onto it or running something that changes it is a deploy (high); fetching from it is medium.
  if (p === "scp" || p === "rsync") {
    const targets = rest.filter((a) => !a.startsWith("-"));
    const dest = targets[targets.length - 1] ?? "";
    return /^[^/\s]*@?[\w.-]+:/.test(dest) ? "high" : "medium";
  }
  if (p === "ssh") return classifyCommand(seg, root) === "safe" ? "low" : "high";
  if (p === "chmod" || p === "chown") return /-R\b/.test(args) || rest.some((a) => a.startsWith("/") && !(root && a.startsWith(root + "/"))) ? "medium" : "low";
  if (["kill", "pkill", "killall", "launchctl", "systemctl", "service", "crontab", "defaults", "security", "networksetup", "scutil", "osascript", "csrutil", "spctl", "pmset"].includes(p)) {
    if (p === "systemctl" && /^(status|is-active|list-units)\b/.test(args)) return "low";
    if (p === "defaults" && /^read\b/.test(args)) return "low";
    return "medium";
  }
  // Installing for the whole computer (a project's own npm/pip install is fine).
  if (["brew", "port", "apt", "apt-get", "yum", "dnf", "pacman", "snap", "choco", "winget", "softwareupdate"].includes(p)) return /^(list|info|search|outdated|--version|doctor|config)\b/.test(args) ? "low" : "medium";
  if (RUNNERS.has(p) && /(^|\s)(-g|--global)\b/.test(args)) return "medium";
  if (p === "curl" || p === "wget" || p === "http") {
    const a = ` ${args} `;
    const sends = /\s-X\s*(POST|PUT|PATCH|DELETE)\b|--request\s+(POST|PUT|PATCH|DELETE)\b|\s(-d|--data\S*|-F|--form|-T|--upload-file|--json)\s/i.test(a);
    const local = /(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])/.test(a);
    if (sends && !local) return /-X\s*DELETE|--request\s+DELETE/i.test(a) ? "high" : "medium";
    return "low";
  }
  if (p === "docker" && /^(rm|rmi|kill|stop|volume|network\s+rm|system)\b/.test(args)) return "medium";
  // Moving or copying onto places outside the project.
  if (p === "mv" || p === "cp" || p === "ln" || p === "tee" || p === "touch" || p === "mkdir") {
    const outside = rest.filter((a) => !a.startsWith("-")).some((t) => (t.startsWith("/") || t.startsWith("~")) && !/^\/(private\/)?tmp\//.test(t) && !(root && t.startsWith(root + "/")));
    if (outside) return "medium";
    if (p === "mv" && rest.filter((a) => !a.startsWith("-")).length >= 2) return "low";
  }
  // Redirects that write outside the project.
  for (const m of seg.matchAll(/(?:^|\s)\d?>{1,2}\s*("([^"]*)"|'([^']*)'|(\S+))/g)) {
    const t = m[2] ?? m[3] ?? m[4] ?? "";
    if (!safeTarget(t, { root, projectWrites: true })) return "medium";
  }
  return "low";
}

const RANK = { low: 0, medium: 1, high: 2 } as const;
const worse = (a: Risk, b: Risk): Risk => (RANK[b] > RANK[a] ? b : a);

/**
 * Heredocs: the body is data (a file being written, a script fed to python), not shell commands. It is taken out of the command,
 * and judged on its own: fed to a shell it is commands; fed to python/node, deleting or spawning inside it counts.
 */
function splitHeredocs(cmd: string, root: string | undefined, depth: number): { shell: string; risk: Risk } {
  let risk: Risk = "low";
  const re = /<<-?\s*(['"]?)([A-Za-z_][\w-]*)\1[^\n]*\n([\s\S]*?)\n[ \t]*\2[ \t]*(?=\n|$)/g;
  const shell = cmd.replace(re, (whole, _q, _tag, body: string, off: number) => {
    const before = cmd.slice(Math.max(0, cmd.lastIndexOf("\n", off) + 1), off);
    const prog = (before.split(/&&|\|\||;|\|/).pop() ?? "").trim().split(/\s+/)[0]?.split("/").pop() ?? "";
    if (prog === "bash" || prog === "sh" || prog === "zsh") risk = worse(risk, riskOf(body, root, depth + 1));
    else if (/^(python\d?(\.\d+)?|node|ruby|perl|php|deno|bun|tsx)$/.test(prog)) {
      if (/\b(rmtree|os\.remove|os\.unlink|\.unlink\(|unlinkSync|rmSync|rmdirSync|fs\.rm\(|File\.delete|drop\s+table|truncate\s+table)/i.test(body)) risk = worse(risk, "high");
      else if (/\b(subprocess|os\.system|child_process|execSync|spawnSync|requests\.(post|put|delete|patch)|urlopen)\b/.test(body)) risk = worse(risk, "medium");
    } else if (/^(psql|mysql|sqlite3|mariadb|mongosh)$/.test(prog)) risk = worse(risk, /\b(insert|update|delete|drop|alter|truncate|create|grant)\b/i.test(body) ? "high" : "low");
    else if (prog === "ssh") risk = worse(risk, "high");
    return whole.slice(0, whole.indexOf("\n"));
  });
  // A heredoc that never closes (a cut-off command): the rest is its body, judged the same way.
  const open = /<<-?\s*(['"]?)[A-Za-z_][\w-]*\1[^\n]*\n/.exec(shell);
  if (open) {
    const rest = shell.slice(open.index + open[0].length);
    const head = shell.slice(0, open.index + open[0].length);
    const r = splitHeredocs(`${head}${rest}\n${(/<<-?\s*(['"]?)([A-Za-z_][\w-]*)/.exec(open[0]) ?? [])[2] ?? "EOF"}`, root, depth);
    return { shell: r.shell, risk: worse(risk, r.risk) };
  }
  return { shell, risk };
}

/** How risky a shell command is for auto mode. Every part counts; the riskiest one wins. Piping a download into a shell is high. */
export function riskOf(cmdIn: string, root?: string, depth = 0): Risk {
  if (typeof cmdIn !== "string" || !cmdIn.trim()) return "low";
  if (cmdIn.length > 20_000 || depth > 4) return "high";
  const hd = splitHeredocs(cmdIn, root, depth);
  const cmd = hd.shell;
  if (hd.risk === "high") return "high";
  if (/\b(curl|wget)\b[^|]*\|\s*(sudo\s+)?(ba|z)?sh\b/.test(cmd)) return "high";
  if (/:\(\)\s*\{.*\};\s*:/.test(cmd)) return "high"; // fork bomb
  let worst: Risk = hd.risk;
  // Command substitutions run too: check what is inside them as well.
  const inner = [...cmd.matchAll(/\$\(([^()]*)\)|`([^`]*)`/g)].map((m) => m[1] ?? m[2] ?? "");
  for (const seg of [...parts(cmd), ...inner.flatMap((x) => parts(x))]) {
    const r = riskOne(seg, root, depth);
    worst = worse(worst, r);
    if (worst === "high") break;
  }
  return worst;
}

/** Names of tools (MCP and others) that act on the outside world in ways that are hard to undo. */
const RISKY_TOOL = /(delete|remove|drop|destroy|truncate|purge|wipe|deploy|publish|merge|push|send|post|pay|charge|refund|transfer|migrat|revoke|archive|cancel|unsubscribe|invite|share)/i;

/** Auto mode for a non-shell tool, by its name: reads and ordinary actions go ahead; destructive or outward ones ask. */
export function toolRisk(name: string): Risk {
  return RISKY_TOOL.test(name.replace(/^mcp__[^_]+__/, "")) ? "high" : "low";
}

/** Auto mode: ask when a call's risk is at or above this level. */
export function autoAsks(risk: Risk, trusted = false): boolean {
  return trusted ? risk === "high" : risk !== "low";
}
