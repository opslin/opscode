// Real (not fake) check of image_generate against this Mac's real Codex accounts. Spends one image generation.
//   node scripts/realtest-imagegen.mjs status   - what each account can do now (free, no image)
//   node scripts/realtest-imagegen.mjs hop      - makes one image with a reference, trying the Mac's own account FIRST with its
//                                                 limits hidden, so a used-up account must fail for real and the next one must take over
//   node scripts/realtest-imagegen.mjs normal   - makes one image the way the app does (limits read, active account first)
// Needs the app built (npm run build). Reads ~/Library/Application Support/Opscode/runtime (accounts), writes only to a temp project.
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, statSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const ROOT = resolve(new URL("..", import.meta.url).pathname);
const imp = (p) => import(pathToFileURL(join(ROOT, "dist/runtime", p)).href);
const { EngineStore } = await imp("engines/detect.js");
const { AccountStore } = await imp("engines/accounts.js");
const { LimitsStore } = await imp("engines/limits.js");
const { ImageGen, imageTool } = await imp("imagegen.js");

const mode = process.argv[2] ?? "status";
const stateDir = process.env.OPSCODE_STATE_DIR ?? join(homedir(), "Library/Application Support/Opscode/runtime");
const engines = new EngineStore(stateDir);
const accounts = new AccountStore({ stateDir, engines, log: () => {}, notify: () => {}, busy: () => 0, removed: () => {} });
const limits = new LimitsStore(engines, accounts, () => {});
const log = (m) => console.log(`  [log] ${m}`);
console.log(`codex: ${engines.codexPath()}`);

const base = {
  codexPath: () => engines.codexPath(),
  accounts: () => accounts.records("codex").map((a, i) => ({ id: a.id, position: i + 1, active: accounts.active("codex") === a.id, env: accounts.env("codex", a.id) })),
  limitsFor: (id) => limits.forAccount("codex", id),
  refreshLimits: (id, force) => limits.refreshAccount("codex", id, force),
  log,
};
const show = (s) => { console.log(`\nstate: ${s.state}${s.next_at ? `  next_at: ${s.next_at}  (${Math.round(s.wait_ms / 60000)} min)` : ""}`); for (const a of s.accounts) console.log(`  account ${a.position}${a.active ? " (active)" : ""}: ${a.state}${a.used_percent !== undefined ? `, used ${a.used_percent}%` : ""}${a.until ? `, until ${a.until}` : ""}${a.why ? `  [${a.why.slice(0, 80)}]` : ""}`); console.log(`message: ${s.message}`); };

if (mode === "status") {
  show(await new ImageGen(base).statusFresh());
  process.exit(0);
}

const root = mkdtempSync(join(tmpdir(), "opscode-real-img-"));
mkdirSync(join(root, "refs"), { recursive: true });
const earlier = process.env.OPSCODE_REAL_REF;
if (mode === "hop" && earlier && existsSync(earlier)) copyFileSync(earlier, join(root, "refs", "icon.png"));
const hide = mode === "hop";
const gen = new ImageGen({
  ...base,
  // "hop": the Mac's own account first, with its limits hidden, so it is tried and fails for real.
  accounts: () => { const l = base.accounts(); return hide ? [...l.filter((a) => a.id === "default").map((a) => ({ ...a, active: true })), ...l.filter((a) => a.id !== "default").map((a) => ({ ...a, active: false }))] : l; },
  limitsFor: (id) => (hide && id === "default" ? undefined : base.limitsFor(id)),
  refreshLimits: async (id, force) => (hide && id === "default" ? undefined : base.refreshLimits(id, force)),
});
const tool = imageTool(gen);
const hasRef = existsSync(join(root, "refs", "icon.png"));
const input = hasRef
  ? { prompt: "The same app icon, but a deep blue (#1E3A8A) squircle background with the same white chevron. Flat, no text.", save_as: "assets/icon-blue.png", references: ["refs/icon.png"], size: "square" }
  : { prompt: "A flat orange (#FF6A00) square app icon with a white chevron prompt symbol. No text.", save_as: "assets/icon.png", size: "square" };
console.log(`\nmode ${mode}${hasRef ? " (with a reference image)" : ""}; project ${root}`);
const started = Date.now();
const r = await tool.run(input, { root, signal: new AbortController().signal, saveNote() {}, readSkill() {} });
console.log(`\n${r.is_error ? "ERROR" : "OK"} after ${Math.round((Date.now() - started) / 1000)}s:\n${r.output}`);
show(gen.status());
const dest = join(root, input.save_as);
if (!r.is_error) {
  const b = readFileSync(dest);
  console.log(`\nfile: ${dest}  ${statSync(dest).size} bytes  png=${b.subarray(1, 4).toString() === "PNG"}`);
  console.log(`(the real project file is left in ${root} for you to open)`);
}
process.exit(r.is_error ? 1 : 0);
