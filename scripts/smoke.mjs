// Runs the headless end-to-end smoke (OPSCODE_SMOKE=1) with a throwaway
// profile directory that this wrapper owns: it is created here and removed
// only after Electron has fully exited (Chromium writes profile files during
// its own shutdown, so the app cannot reliably clean them up itself).

import { execFileSync, spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { writeFixture } from "./lib/usage-fixture.mjs";
import { writeLibraryFixture } from "./lib/library-fixture.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const profile = mkdtempSync(join(tmpdir(), "opscode-smoke-profile-"));
// Import page reads a fixture home, never the real one.
const home = mkdtempSync(join(tmpdir(), "opscode-smoke-home-"));
mkdirSync(join(home, ".claude", "skills", "smoke-import"), { recursive: true });
writeFileSync(join(home, ".claude", "skills", "smoke-import", "SKILL.md"), '---\nname: smoke-import\ndescription: "Imported by the smoke test"\n---\n\nDo the thing.\n');
writeFileSync(join(home, ".claude.json"), JSON.stringify({ mcpServers: { smokesrv: { command: "echo", args: ["hi"], env: { TOKEN: "x" } } } }));
// `node scripts/smoke.mjs --app <Opscode.app>` runs the same test against a packaged app.
const appArg = process.argv.indexOf("--app") > 0 ? resolve(process.argv[process.argv.indexOf("--app") + 1]) : null;
// Usage page reads fixture session logs, never the real ones.
const logs = mkdtempSync(join(tmpdir(), "opscode-smoke-logs-"));
const fixture = writeFixture(logs);
// The Library suggests (and indexes) a fixture app, never the real Documents folder.
const appsDir = mkdtempSync(join(tmpdir(), "opscode-smoke-apps-"));
writeLibraryFixture(appsDir);
// Read aloud downloads its voice once; the smoke serves a tiny stand-in archive from here (and uses a stand-in worker),
// so no 98 MB download and no real model.
const ttsDir = mkdtempSync(join(tmpdir(), "opscode-smoke-tts-"));
const ttsFolder = "sherpa-onnx-pocket-tts-int8-2026-01-26";
for (const f of ["vocab.json", "test_wavs/bria.wav", "test_wavs/loona.wav"]) { mkdirSync(join(ttsDir, "src", ttsFolder, f, ".."), { recursive: true }); writeFileSync(join(ttsDir, "src", ttsFolder, f), `fake ${f}`); }
execFileSync("/usr/bin/tar", ["-cjf", join(ttsDir, "voice.tar.bz2"), "-C", join(ttsDir, "src"), ttsFolder]);
const ttsBytes = readFileSync(join(ttsDir, "voice.tar.bz2"));
const ttsServer = createServer((_req, res) => res.writeHead(200, { "content-length": ttsBytes.length }).end(ttsBytes));
await new Promise((r) => ttsServer.listen(0, "127.0.0.1", r));
// Accounts (Settings -> Models & keys): the fake claude and codex keep their sign-in in these folders, already signed in.
const acct = mkdtempSync(join(tmpdir(), "opscode-smoke-acct-"));
// Antigravity (`agy`) starts signed in, Qoder signed out: stand-ins that speak ACP (scripts/lib/fake-acp.mjs).
mkdirSync(join(acct, "agy"), { recursive: true });
mkdirSync(join(acct, "qoder"), { recursive: true });
writeFileSync(join(acct, "agy", "fake-auth.json"), "{}");
for (const [dir, who] of [["claude", { email: "sayan@claude.example", plan: "max", org: "Sayan Org" }], ["codex", { email: "sayan@chatgpt.example", plan: "team", workspace: "Shotlin" }]]) {
  mkdirSync(join(acct, dir), { recursive: true });
  writeFileSync(join(acct, dir, "fake-auth.json"), JSON.stringify(who));
}
const electron = appArg ? join(appArg, "Contents/MacOS/Opscode") : join(root, "node_modules/.bin/electron");

const child = spawn(electron, appArg ? [] : ["."], {
  cwd: root,
  env: { ...process.env, OPSCODE_SMOKE: "1", OPSCODE_SMOKE_PROFILE: profile, OPSCODE_IMPORT_HOME: home, OPSCODE_LIBRARY_SUGGEST_ROOT: appsDir, OPSCODE_CLAUDE_LOGS: fixture.claudeRoot, OPSCODE_CODEX_LOGS: fixture.codexRoot, OPSCODE_CLAUDE_BIN: join(root, "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(root, "scripts/lib/fake-codex.mjs"), OPSCODE_XCRUN: join(root, "scripts/lib/fake-xcrun.mjs"), OPSCODE_SIM_HELPER: join(root, "scripts/lib/fake-simhelper.mjs"), OPSCODE_FAKE_SIM_STATE: join(profile, "fake-sim.json"), OPSCODE_VOICE_HELPER: join(root, "scripts/lib/fake-voice.mjs"), OPSCODE_TTS_URL: `http://127.0.0.1:${ttsServer.address().port}/voice.tar.bz2`, OPSCODE_TTS_SHA256: createHash("sha256").update(ttsBytes).digest("hex"), OPSCODE_TTS_FILES: "vocab.json,test_wavs/bria.wav,test_wavs/loona.wav", OPSCODE_TTS_WORKER: join(root, "scripts/lib/fake-tts-worker.mjs"), OPSCODE_FAKE_TTS_MAX: "96000", OPSCODE_FAKE_TTS_SCALE: "6", OPSCODE_FAKE_DEFAULT_HOME: join(acct, "claude"), OPSCODE_AGY_BIN: join(root, "scripts/lib/fake-acp.mjs"), OPSCODE_QODER_BIN: join(root, "scripts/lib/fake-acp.mjs"), OPSCODE_FAKE_REAL_HOME: process.env.HOME ?? "", OPSCODE_FAKE_DEFAULT_ACP_HOME: join(acct, "agy"), OPSCODE_FAKE_DEFAULT_QODER_HOME: join(acct, "qoder"), OPSCODE_FAKE_DEFAULT_CODEX_HOME: join(acct, "codex"), OPSCODE_CLAUDE_HOME: join(acct, "shared-claude"), OPSCODE_CODEX_HOME: join(acct, "shared-codex"), OPSCODE_OPEN_BIN: join(root, "scripts/lib/fake-open.mjs"), OPSCODE_FAKE_LOGIN_AUTOCOMPLETE_MS: "2500", OPSCODE_FAKE_LOGIN_EMAIL: "work@claude.example", ...(process.env.OPSCODE_SMOKE_FOCUS === "voice-settings" ? { OPSCODE_VOICE_HELPER: "", OPSCODE_TTS_URL: "", OPSCODE_TTS_WORKER: "" } : {}) },
  stdio: ["ignore", "pipe", "pipe"],
});

// Show the smoke lines and runtime lifecycle; hide Chromium/GPU noise.
const keep = /OPSCODE_SMOKE|runtime: (started|exited|restarting|stopped)/;
for (const stream of [child.stdout, child.stderr]) {
  let buf = "";
  stream.setEncoding("utf8");
  stream.on("data", (chunk) => {
    buf += chunk;
    const lines = buf.split("\n");
    buf = lines.pop();
    for (const line of lines) if (keep.test(line)) console.log(line);
  });
}

child.on("exit", (code, signal) => {
  rmSync(profile, { recursive: true, force: true });
  rmSync(home, { recursive: true, force: true });
  rmSync(logs, { recursive: true, force: true });
  rmSync(acct, { recursive: true, force: true });
  rmSync(appsDir, { recursive: true, force: true });
  rmSync(ttsDir, { recursive: true, force: true });
  ttsServer.close();
  process.exit(code ?? (signal ? 1 : 0));
});
