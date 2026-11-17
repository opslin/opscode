// Import: scanning Claude Code / Codex / Cursor files (a fake home folder), what is
// and is not copied, previews, dedupe, switched-off MCP servers, limits.

import { createHash } from "node:crypto";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, realpathSync, rmSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, waitFor } from "./lib/harness.mjs";

const t = reporter();
const E = { INVALID: -32602 };
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 220);
const MOCK_MCP = join(process.cwd(), "scripts/lib/mock-mcp.mjs");

const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p10-")));
const home = join(base, "home");
const outside = join(base, "outside");
mkdirSync(join(home, ".claude", "skills", "release-notes"), { recursive: true });
mkdirSync(join(home, ".claude", "skills", "Bad Name"), { recursive: true });
mkdirSync(join(home, ".claude", "skills", "no-desc"), { recursive: true });
mkdirSync(join(home, ".codex", "skills", "lint-fix"), { recursive: true });
mkdirSync(join(home, ".cursor"), { recursive: true });
mkdirSync(outside, { recursive: true });
const skillMd = (name, desc, body) => `---\nname: ${name}\ndescription: ${JSON.stringify(desc)}\n---\n\n${body}\n`;
writeFileSync(join(home, ".claude", "skills", "release-notes", "SKILL.md"), skillMd("release-notes", "Write release notes from commits", "1. List commits.\n2. Group by area."));
writeFileSync(join(home, ".claude", "skills", "release-notes", "helper.sh"), "echo hi");
writeFileSync(join(home, ".claude", "skills", "Bad Name", "SKILL.md"), skillMd("Bad Name", "x", "y"));
writeFileSync(join(home, ".claude", "skills", "no-desc", "SKILL.md"), "---\nname: no-desc\n---\n\nSteps only.\n");
mkdirSync(join(outside, "evil"), { recursive: true });
writeFileSync(join(outside, "evil", "SKILL.md"), skillMd("evil", "from outside", "nope"));
symlinkSync(join(outside, "evil"), join(home, ".claude", "skills", "evil"));
writeFileSync(join(home, ".codex", "skills", "lint-fix", "SKILL.md"), skillMd("lint-fix", "Fix lint errors", "Run the linter, fix, rerun."));

const SECRET = "sk-super-secret-value-123";
writeFileSync(
  join(home, ".claude.json"),
  JSON.stringify({
    projects: { "/x": { history: ["a".repeat(50)] } },
    mcpServers: {
      mocky: { type: "stdio", command: process.execPath, args: [MOCK_MCP], env: { API_TOKEN: SECRET } },
      remote: { type: "http", url: "https://example.com/mcp", headers: { Authorization: `Bearer ${SECRET}` } },
      tokenurl: { type: "http", url: `https://example.com/mcp?token=${SECRET}` },
      userinfo: { type: "http", url: `https://bob:${SECRET}@example.com/mcp` },
      badargs: { command: "x", args: [1, 2] },
      "bad\u0001name": { command: "x" },
    },
  }),
);
const longPara = "word ".repeat(1000); // 5000 chars, no blank lines
writeFileSync(join(home, ".claude", "CLAUDE.md"), `# Style\n\nUse tabs.\n\n## Testing\n\nRun tests first.\n\n## Long\n\n${longPara}\n`);
writeFileSync(
  join(home, ".codex", "config.toml"),
  `model = "x"\n\n[mcp_servers.alpha]\ncommand = "/usr/bin/env"\nargs = [\n  "node", # comment\n  "server.js",\n]\n\n[mcp_servers.alpha.env]\nSECRET_KEY = "${SECRET}"\n\n[mcp_servers."with.dot"]\nurl = "https://example.org/mcp"\n\n[plugins."foo@bar"]\nenabled = true\n`,
);
writeFileSync(join(home, ".codex", "AGENTS.md"), "Always answer briefly.\n");
writeFileSync(join(home, ".cursor", "mcp.json"), JSON.stringify({ mcpServers: { curs: { command: "npx", args: ["-y", "@acme/mcp"] } } }));

const sums = () => {
  const h = createHash("sha256");
  const walk = (d) => { for (const n of readdirSync(d, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) { const p = join(d, n.name); if (n.isDirectory()) walk(p); else if (n.isFile()) h.update(p).update(readFileSync(p)); } };
  walk(home);
  return h.digest("hex");
};
const before = sums();

const stateDir = join(base, "state");
let rt = await startRuntime({ env: { OPSCODE_IMPORT_HOME: home }, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  let res = await C.call("import.scan");
  const raw = JSON.stringify(res.result);
  const items = res.result?.items ?? [];
  const by = (id) => items.find((i) => i.id === id);
  t.check("scan works and finds all three sources", res.result?.sources?.length === 3 && res.result.sources.every((s) => s.found), why(res));
  t.check("scan never returns a secret value", !raw.includes(SECRET));
  t.check("claude: stdio server found with its command", by("claude:mcp:mocky")?.detail.includes("mock-mcp.mjs"), why(res));
  t.check("claude: env key names are reported, values are not", by("claude:mcp:mocky")?.warn?.includes("API_TOKEN") && !by("claude:mcp:mocky").warn.includes(SECRET));
  t.check("claude: header names reported for a remote server", by("claude:mcp:remote")?.warn?.includes("Authorization"));
  t.check("a URL with a token or password is blocked", !!by("claude:mcp:tokenurl")?.blocked && !!by("claude:mcp:userinfo")?.blocked);
  t.check("bad args and control-character names are not offered", !by("claude:mcp:badargs") || !!by("claude:mcp:badargs").blocked, "");
  t.check("control-character server name is dropped", !items.some((i) => i.title.includes("\u0001")));
  t.check("claude: skill listed, extra files flagged", by("claude:skill:release-notes")?.warn?.includes("1 other file"), why(res));
  t.check("bad skill names and skills without a description are blocked", !!by("claude:skill:Bad Name")?.blocked && !!by("claude:skill:no-desc")?.blocked);
  t.check("a symlinked skill folder is ignored", !by("claude:skill:evil"));
  t.check("claude: CLAUDE.md becomes notes", by("claude:note:CLAUDE.md")?.detail.includes("notes"));
  t.check("codex: toml server with a multi-line args array", by("codex:mcp:alpha")?.detail === "/usr/bin/env node server.js", by("codex:mcp:alpha")?.detail);
  t.check("codex: env table keys flagged, quoted dotted name works", by("codex:mcp:alpha")?.warn?.includes("SECRET_KEY") && by("codex:mcp:with.dot")?.detail.startsWith("https://example.org"));
  t.check("codex: skills and AGENTS.md found", !!by("codex:skill:lint-fix") && !!by("codex:note:AGENTS.md"));
  t.check("cursor: mcp.json server found", by("cursor:mcp:curs")?.detail === "npx -y @acme/mcp");
  t.check("nothing is marked as already present yet", items.every((i) => i.exists === false));
  t.check("scanning does not change the other apps' files", sums() === before);

  // ---- validation -------------------------------------------------------------------------------
  for (const [name, params] of [["empty ids", { ids: [] }], ["non-string id", { ids: [1] }], ["too many", { ids: Array.from({ length: 301 }, (_, i) => `a${i}`) }], ["unknown key", { ids: ["a"], x: 1 }], ["missing", {}]]) {
    res = await C.call("import.run", params);
    t.check(`import.run rejects ${name}`, res.error?.code === E.INVALID, why(res));
  }

  // ---- run ----------------------------------------------------------------------------------------
  res = await C.call("import.run", { ids: ["claude:mcp:mocky", "claude:mcp:remote", "claude:mcp:tokenurl", "claude:skill:release-notes", "claude:skill:no-desc", "claude:note:CLAUDE.md", "codex:note:AGENTS.md", "codex:mcp:alpha", "cursor:mcp:curs", "claude:skill:ghost"] });
  const got = (id) => res.result?.imported.find((x) => x.id === id);
  const skip = (id) => res.result?.skipped.find((x) => x.id === id);
  t.check("selected items are imported", ["claude:mcp:mocky", "claude:mcp:remote", "claude:skill:release-notes", "claude:note:CLAUDE.md", "codex:note:AGENTS.md", "codex:mcp:alpha", "cursor:mcp:curs"].every((id) => got(id)), why(res));
  t.check("blocked items and unknown ids are skipped with a reason", skip("claude:mcp:tokenurl")?.reason && skip("claude:skill:no-desc")?.reason && skip("claude:skill:ghost")?.reason.includes("No longer"), why(res));

  const mcp = (await C.call("mcp.list")).result.servers;
  const mocky = mcp.find((s) => s.name === "mocky");
  t.check("imported MCP servers are added but switched off", mocky && mocky.enabled === false && mocky.state === "off" && mcp.filter((s) => ["mocky", "remote", "alpha", "curs"].includes(s.name)).every((s) => !s.enabled), JSON.stringify(mocky));
  t.check("no secret was written to mcp.json", !readFileSync(join(stateDir, "mcp.json"), "utf8").includes(SECRET) && !readFileSync(join(stateDir, "mcp.json"), "utf8").includes("API_TOKEN"));
  await C.call("mcp.set_enabled", { id: mocky.id, enabled: true });
  t.check("an imported server works once turned on", await waitFor(async () => false, 10) || (await (async () => { for (let i = 0; i < 100; i++) { const s = (await C.call("mcp.list")).result.servers.find((x) => x.id === mocky.id); if (s.state === "ready") return s.tools.length > 0; if (s.state === "error") return false; await new Promise((r) => setTimeout(r, 50)); } return false; })()));

  const skills = (await C.call("skill.list")).result.skills;
  t.check("imported skill is a personal skill", skills.some((s) => s.name === "release-notes" && s.scope === "user"), JSON.stringify(skills));
  t.check("only SKILL.md was copied", existsSync(join(stateDir, "skills", "release-notes", "SKILL.md")) && !existsSync(join(stateDir, "skills", "release-notes", "helper.sh")));
  const sk = await C.call("skill.read", { name: "release-notes" });
  t.check("skill body is intact", sk.result?.body.includes("Group by area"), why(sk));

  const notes = (await C.call("memory.list")).result.notes;
  const fromClaude = notes.filter((n) => n.title.startsWith("CLAUDE.md"));
  t.check("instructions became global kept notes", fromClaude.length >= 3 && notes.every((n) => n.scope === "global" && n.state === "kept"), `${notes.length} notes`);
  t.check("every note fits the note limit (long paragraph was split)", notes.every((n) => n.body.length <= 2000) && fromClaude.filter((n) => n.title.endsWith("Long")).length >= 3, JSON.stringify(notes.map((n) => [n.title, n.body.length])));
  t.check("note titles come from headings", fromClaude.some((n) => n.title === "CLAUDE.md: Testing" && n.body.includes("Run tests first")));
  t.check("AGENTS.md imported", notes.some((n) => n.title === "AGENTS.md" && n.body === "Always answer briefly."));

  // ---- again: nothing doubles ----------------------------------------------------------------------
  const ids = ["claude:mcp:mocky", "claude:skill:release-notes", "claude:note:CLAUDE.md", "codex:mcp:alpha"];
  res = await C.call("import.run", { ids });
  t.check("importing twice skips everything as already there", res.result?.imported.length === 0 && res.result.skipped.length === 4 && res.result.skipped.every((x) => x.reason.includes("Already")), why(res));
  t.check("no duplicates anywhere", (await C.call("mcp.list")).result.servers.filter((s) => s.name === "mocky").length === 1 && (await C.call("memory.list")).result.notes.length === notes.length && (await C.call("skill.list")).result.skills.filter((s) => s.name === "release-notes").length === 1);
  res = await C.call("import.scan");
  t.check("scan now marks them as already here", ["claude:mcp:mocky", "claude:skill:release-notes", "claude:note:CLAUDE.md", "codex:skill:lint-fix"].map((id) => res.result.items.find((i) => i.id === id)?.exists).join() === "true,true,true,false", why(res));
  t.check("import never changes the other apps' files", sums() === before);
  t.check("mcp.json stays private (0600)", (statSync(join(stateDir, "mcp.json")).mode & 0o777) === 0o600);
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
