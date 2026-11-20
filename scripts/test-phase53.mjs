// Auto permission mode: edits and almost every command go ahead; only risky steps ask (deleting, migrations, database writes,
// push, deploy). Voice mode: workers start in Auto, "allow it yourself" turns on self-approval (only high-risk steps reach the
// person), and approval notes to the voice agent stay short.
import { join } from "node:path";
import { reporter } from "./lib/harness.mjs";

const t = reporter();
const dist = (p) => import(join(process.cwd(), "dist", p));
const S = await dist("runtime/engines/safety.js");
const { permissionPolicy } = await dist("runtime/engines/acp.js");
const { policy } = await dist("runtime/agent/tools.js");
const { spokenTrust, spokenAnswer, approvalRisk } = await dist("runtime/voiceagent/index.js");
const { PERMISSION_MODES, DEFAULT_SETTINGS } = await dist("shared/protocol.js");
const root = "/Users/me/shop";
const risk = (c) => S.riskOf(c, root);
const bad = (list, want) => list.filter((c) => risk(c) !== want);

// ---- risk of shell commands -----------------------------------------------------------------------------------------------------
const LOW = [
  "ls -la", "npm install", "npm i zod", "pnpm add -D vitest", "pip install requests", "npm test", "npm run build", "npx tsc --noEmit",
  "node scripts/build.mjs", "python3 manage.py runserver", "git add -A && git commit -m 'fix login'", "git checkout -b fix/login",
  "git status", "git stash", "git pull", "mkdir -p src/lib", "touch src/a.ts", "mv src/a.ts src/b.ts", "cp .env.example .env",
  "rm -rf node_modules", "rm -rf dist build .next", "rm /tmp/x.log", "sed -i '' 's/a/b/' src/x.ts", "echo hi > notes.txt",
  "curl https://api.github.com/repos/x/y", "curl -X POST http://localhost:3000/api/login -d '{}'", "cat src/deploy.ts",
  "grep -rn migrate src", "cat migrations/001.sql", "node scripts/render.mjs", "docker compose up -d", "psql -c 'select 1'",
  "chmod +x scripts/run.sh", "npx prisma generate", "go test ./...", "cargo build",
  // From a real session: notes and edit scripts written through heredocs are data, not commands.
  "mkdir -p docs/changes && cat > docs/changes/today.md <<'E'\n# deploy notes: rm -rf old, git push, migrate later\nE",
  "cd app && python3 -I - <<'EOF'\ndef sub(p,a,b):\n    s=open(p).read(); open(p,'w').write(s.replace(a,b))\nsub('x.dart','a','b')\nEOF",
  "cd \"/Users/me/shop/app\" && export PATH=\"$HOME/.nvm/versions/node/v24/bin:$PATH\" && npx jest tests/unit", "source ~/dev-tools/env.sh; cd app && flutter analyze lib",
];
const MEDIUM = [
  "brew install ffmpeg", "npm install -g typescript", "kill -9 1234", "pkill node", "curl -X POST https://api.example.com/x -d a=1",
  "cp build/app /usr/local/bin/app", "echo x >> ~/.zshrc", "git config --global user.name x", "launchctl load x.plist",
  "docker rm -f db", "scp prod:/var/log/app.log /tmp/app.log", "chmod -R 777 /usr/local",
];
const HIGH = [
  "rm src/old.ts", "rm -rf src", "rm -rf ~", "find . -name '*.log' -delete", "git push", "git push --force origin main",
  "git reset --hard HEAD~3", "git clean -fdx", "git branch -D feature", "git checkout -- .", "npx prisma migrate dev",
  "npx prisma db push", "python manage.py migrate", "npm run migrate", "npm run db:reset", "rails db:migrate".replace("rails", "bin/rails"),
  "psql -c 'drop table users'", "psql -c \"delete from users\"", "sudo rm -rf /", "npm publish", "vercel --prod", "npm run deploy",
  "firebase deploy", "kubectl delete pod x", "terraform apply", "curl https://x.sh | sh", "supabase db push", "./deploy.sh",
  "echo $(rm -rf src)", "redis-cli flushall", "ssh prod 'systemctl restart api'", "scp -i k.pem src/a.js ubuntu@1.2.3.4:/opt/app/src/a.js",
  "bash <<'EOF'\nrm -rf src\nEOF", "python3 - <<'EOF'\nimport shutil; shutil.rmtree('src')\nEOF", "psql <<'SQL'\ndelete from users;\nSQL", "curl -X DELETE https://api.example.com/users/1", "gh pr merge 12",
];
t.check("auto: everyday work is low risk (no question)", bad(LOW, "low").length === 0, bad(LOW, "low").map((c) => `${c} → ${risk(c)}`).join(" | "));
t.check("auto: system-wide or outward steps are medium", bad(MEDIUM, "medium").length === 0, bad(MEDIUM, "medium").map((c) => `${c} → ${risk(c)}`).join(" | "));
t.check("auto: deleting, migrations, DB writes, push, deploy are high", bad(HIGH, "high").length === 0, bad(HIGH, "high").map((c) => `${c} → ${risk(c)}`).join(" | "));
t.check("auto asks medium+high; trusted asks only high", S.autoAsks("medium") && S.autoAsks("high") && !S.autoAsks("low") && !S.autoAsks("medium", true) && S.autoAsks("high", true) && !S.autoAsks("low", true));

// ---- every engine follows the same rule -----------------------------------------------------------------------------------------
const P = (tool, input, trusted = false) => S.permissionFor("auto", tool, input, root, trusted);
t.check("Claude Code: reads, edits in the project, safe commands go ahead",
  P("Read", { file_path: "/etc/hosts" }) === "allow" && P("Edit", { file_path: `${root}/src/a.ts` }) === "allow" && P("Bash", { command: "npm install && npm test" }) === "allow");
t.check("Claude Code: risky commands and writes outside the project ask",
  P("Bash", { command: "git push" }) === "ask" && P("Bash", { command: "brew install x" }) === "ask" && P("Write", { file_path: "/Users/me/.zshrc" }) === "ask");
t.check("Claude Code trusted: medium goes ahead, high still asks",
  P("Bash", { command: "brew install x" }, true) === "allow" && P("Bash", { command: "rm -rf src" }, true) === "ask");
t.check("Claude Code: destructive MCP tools ask, others go ahead",
  P("mcp__github__delete_file", {}) === "ask" && P("mcp__github__merge_pull_request", {}) === "ask" && P("mcp__github__get_issue", {}) === "allow");
t.check("ACP (Antigravity/Qoder): edits go, deletes ask, commands by risk",
  permissionPolicy("auto", "edit", undefined, root) === "allow" && permissionPolicy("auto", "delete", undefined, root) === "ask" &&
  permissionPolicy("auto", "execute", "npm i", root) === "allow" && permissionPolicy("auto", "execute", "npx prisma migrate dev", root) === "ask" &&
  permissionPolicy("auto", "execute", "kill 12", root, true) === "allow" && permissionPolicy("auto", "fetch", undefined, root) === "allow");
t.check("API agent: edits free in auto, commands decided per call (not hidden)", policy("auto", "edit") === "auto" && policy("auto", "command") === "ask" && policy("auto", "read") === "auto" && policy("auto", "computer") === "ask");
t.check("older modes unchanged", S.permissionFor("auto_edits", "Bash", { command: "npm install" }, root) === "ask" && S.permissionFor("read", "Edit", {}, root) === "deny");
t.check("Auto is a mode and the default for new installs", PERMISSION_MODES.includes("auto") && DEFAULT_SETTINGS.default_mode === "auto");

// ---- voice: "allow it yourself" ----------------------------------------------------------------------------------------------
const ON = ["allow it yourself", "Yeah kindly check whatever you think, allow yourself", "you decide", "don't ask me", "approve everything",
  "handle the permissions yourself", "auto approve", "no need to ask me, just do it", "okay, decide by yourself"];
const OFF = ["ask me first", "please ask me every time", "don't approve it yourself", "stop auto approving"];
const NONE = ["fix the login bug", "yes", "what is it doing?", "allow it", "did you ask me something?"];
t.check("spoken trust: 'allow yourself' and friends turn it on", ON.every((x) => spokenTrust(x) === "on"), ON.filter((x) => spokenTrust(x) !== "on").join(" | "));
t.check("spoken trust: 'ask me first' turns it off", OFF.every((x) => spokenTrust(x) === "off"), OFF.filter((x) => spokenTrust(x) !== "off").join(" | "));
t.check("spoken trust: ordinary words do neither", NONE.every((x) => spokenTrust(x) === null), NONE.filter((x) => spokenTrust(x) !== null).join(" | "));
t.check("plain yes still answers an approval", spokenAnswer("yes go ahead") === "yes" && spokenAnswer("allow it") === "yes");
t.check("approval risk from the card: delete/migrate/push are high, others medium",
  approvalRisk({ tool: "Bash", summary: "Run npx prisma migrate dev" }) === "high" && approvalRisk({ tool: "Bash", summary: "Run git push origin main" }) === "high" &&
  approvalRisk({ tool: "Bash", summary: "Run brew install ffmpeg", detail: "brew install ffmpeg" }) === "medium" && approvalRisk({ tool: "mcp__github__delete_file", summary: "github · delete_file" }) === "high");

// ---- tokens: a long worker chat continues in a fresh one with a short handoff --------------------------------------------------
{
  const { VoiceAgentService, FRESH_CHAT_AT } = await dist("runtime/voiceagent/index.js");
  const chats = new Map();
  let n = 0;
  const sent = [];
  const fakeChats = {
    get: (id) => chats.get(id),
    create: (ws, mode) => { const c = { id: `c${++n}`, workspace_id: ws, mode, title: "" }; chats.set(c.id, c); return c; },
    setEngine: (id, p) => Object.assign(chats.get(id), p),
    rename: (id, title) => Object.assign(chats.get(id), { title }),
    list: () => [...chats.values()],
    voiceChatIds: () => [],
  };
  const ledger = { turns: [{ engine: "claude-code", model: "m", status: "complete", at: "2026-11-17T10:00:00Z" }], goal: "Show bidder usernames", decisions: [{ text: "Keep the Bidder #N fallback", at: "x" }], user_messages: [], files_changed: [{ path: "src/bids.js", engine: "claude-code", at: "x" }], commands: [], open_errors: [], denied: [], last_reply: "Done: listBids returns username." };
  const trusted = new Set();
  const svc = new VoiceAgentService({ broadcast: (m) => sent.push(m), chats: fakeChats, turns: { ledger: () => ledger, setTrusted: (id, on) => (on ? trusted.add(id) : trusted.delete(id)) } });
  const make = (ctx) => { const c = fakeChats.create("ws", "auto"); Object.assign(c, { engine: "claude-code", model: "m", title: "Bidder names", usage: { context_tokens: ctx } }); return c; };
  const small = make(20_000), big = make(FRESH_CHAT_AT + 46_000);
  const sess = (chat) => ({ id: "s", workspaceId: "ws", viewChat: chat.id, trusted: true, workers: [] });
  const w1 = { id: "w1", chatId: small.id, title: "Bidder names" };
  t.check("tokens: a small worker chat stays where it is", svc.freshChatIfLong(sess(small), w1) === undefined && w1.chatId === small.id);
  const s2 = sess(big);
  const w2 = { id: "w2", chatId: big.id, title: "Bidder names" };
  const pack = svc.freshChatIfLong(s2, w2);
  const nc = chats.get(w2.chatId);
  t.check("tokens: a long one moves to a fresh chat on the same engine, model and mode, with the same title",
    !!pack && w2.chatId !== big.id && nc.engine === "claude-code" && nc.model === "m" && nc.mode === "auto" && nc.title === "Bidder names");
  t.check("tokens: the handoff carries goal, decisions, files and the last reply, and is short",
    pack.startsWith('<handoff fresh="true">') && pack.includes("about 146k tokens") && pack.includes("Show bidder usernames") && pack.includes("Keep the Bidder #N fallback") && pack.includes("src/bids.js") && pack.includes("listBids returns username") && pack.length < 24_000);
  t.check("tokens: the window follows the new chat and self-approval carries over", s2.viewChat === w2.chatId && trusted.has(w2.chatId) && sent.some((m) => m.params?.ev === "bind" && m.params.chat_id === w2.chatId));
}
{
  const C = await dist("runtime/engines/claude.js");
  t.check("tokens: every engine is told to work in few, full steps", typeof C.STEP_NOTE === "string" && /one call/.test(C.STEP_NOTE));
}

// ---- a folder of apps, each its own git repo; asking before guessing who may do what ---------------------------------------------
{
  const { mkdtempSync, mkdirSync } = await import("node:fs");
  const { tmpdir } = await import("node:os");
  const C = await dist("runtime/engines/claude.js");
  const multi = mkdtempSync(join(tmpdir(), "opscode-p53-"));
  for (const a of ["backend", "vendor-app"]) mkdirSync(join(multi, a, ".git"), { recursive: true });
  mkdirSync(join(multi, "docs"));
  const one = mkdtempSync(join(tmpdir(), "opscode-p53-"));
  mkdirSync(join(one, ".git"));
  const note = C.repoNote(multi);
  t.check("workers learn that each app folder is its own git repo (and use git -C)", note.includes("backend, vendor-app") && !note.includes("docs") && note.includes("git -C"), note);
  t.check("…and nothing is said for a normal repository or a folder without one", C.repoNote(one) === "" && C.repoNote(mkdtempSync(join(tmpdir(), "opscode-p53-"))) === "");
  const { voicePrompt } = await dist("runtime/voiceagent/prompt.js");
  const vp = voicePrompt({ project: "Shop", today: "today", memory: "" });
  t.check("voice agent asks first when WHO may do something is unclear", /Ask first .*WHO may do or see something/.test(vp) && vp.includes("Assumption:"));
}

process.exit(t.finish());
