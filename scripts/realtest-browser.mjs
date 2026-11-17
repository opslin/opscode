// Real-model browser test: launches Opscode (throwaway profile) and asks a real Claude Code
// chat to test a small shop through Opscode's browser tools. Spends real Claude usage.
//   node scripts/realtest-browser.mjs [--out <dir>] [--model <id>] [--mode full|auto_edits|supervised]
import { spawn } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const arg = (n) => (process.argv.indexOf(n) > 0 ? process.argv[process.argv.indexOf(n) + 1] : undefined);
const out = resolve(arg("--out") ?? join(root, "testing/runs", new Date().toISOString().replace(/[:.]/g, "-")));
mkdirSync(out, { recursive: true });
const profile = mkdtempSync(join(tmpdir(), "opscode-realtest-profile-"));
const child = spawn(join(root, "node_modules/.bin/electron"), ["."], {
  cwd: root,
  env: { ...process.env, OPSCODE_REALTEST: "1", OPSCODE_SMOKE_PROFILE: profile, OPSCODE_REALTEST_OUT: out, ...(arg("--model") ? { OPSCODE_REALTEST_MODEL: arg("--model") } : {}), ...(arg("--mode") ? { OPSCODE_REALTEST_MODE: arg("--mode") } : {}), OPSCODE_XCRUN: "none" },
  stdio: ["ignore", "pipe", "pipe"],
});
for (const s of [child.stdout, child.stderr]) {
  s.setEncoding("utf8");
  s.on("data", (d) => { for (const l of d.split("\n")) if (/OPSCODE_REALTEST|runtime: (started|stopped)/.test(l)) console.log(l); });
}
child.on("exit", (code) => { rmSync(profile, { recursive: true, force: true }); console.log(`results: ${out}`); process.exit(code ?? 1); });
