// Phase 58: opscode-hands, the native computer-use helper (native/opscode-hands). Always: its selftest (the map, labels,
// lookup, change detection, keys and menus on an in-memory window), the permission check and its refusals. With the
// Accessibility permission for the process running this test: a real test app (native/opscode-hands/fixture.swift) is
// read and driven — click, type, a password field refused, a menu item, a risky button marked — and the person's front
// app and pointer must not move. Without the permission those checks are listed as SKIPPED, never as passed.
import { execFileSync, spawn } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, sleep } from "./lib/harness.mjs";

const t = reporter();
const ROOT = new URL("..", import.meta.url).pathname;
const HANDS = join(ROOT, "dist/native/opscode-hands");
if (process.platform !== "darwin") { console.log("SKIPPED  phase 58 runs on macOS only"); process.exit(0); }
if (!existsSync(HANDS)) execFileSync("node", [join(ROOT, "scripts/build-native.mjs")], { stdio: "inherit" });
t.check("the helper is built", existsSync(HANDS));

const scratch = mkdtempSync(join(tmpdir(), "opscode-p58-"));
const state = join(scratch, "state.json");
const hands = (...args) => {
  try { return JSON.parse(execFileSync(HANDS, ["--state", state, ...args], { encoding: "utf8", timeout: 20000 }).trim()); }
  catch (e) { try { return JSON.parse(String(e.stdout).trim()); } catch { return { ok: false, error: String(e.message) } } }
};

// ---- always ------------------------------------------------------------------------------------------------------------
const self = hands("selftest");
t.check(`selftest: map, labels, lookup, change detection, keys, menus (${self.passed ?? 0} checks)`, self.ok === true && self.failed === 0 && self.passed >= 27, JSON.stringify(self.failures ?? self));
const chk = hands("check");
t.check("check reports the Accessibility permission and the background input path", chk.ok === true && typeof chk.accessibility === "boolean" && chk.skylight === true, JSON.stringify(chk));
t.check("apps lists running apps and which is in front", (() => { const a = hands("apps"); return a.ok && a.apps.some((x) => x.name === "Finder") && a.apps.filter((x) => x.front).length <= 1; })());
t.check("an unknown command is refused", hands("format-disk").ok === false);
t.check("open: an app that does not exist is refused, nothing opened", /No app called/.test(hands("open", "No Such App 12345").error ?? ""));
if (!chk.accessibility) {
  const see = hands("see", "Finder");
  t.check("without the permission, reading an app says exactly what to allow", see.ok === false && /Accessibility/.test(see.error ?? ""), JSON.stringify(see));
}

// ---- live, with the permission -------------------------------------------------------------------------------------------
const LIVE = ["reads the test app as a numbered list", "click: the button really pressed (app log) and the change is reported", "type: the text is in the field", "a password field is never typed into", "a risky button is marked (risky)", "menu: a menu item chosen", "the person's front app did not change", "the pointer did not move", "a number from an old look is not guessed"];
if (!chk.accessibility) {
  for (const name of LIVE) console.log(`SKIPPED  ${name}  (no Accessibility permission for the app running this test: allow it in System Settings → Privacy & Security → Accessibility, then run again)`);
} else {
  const fixture = join(scratch, "HandsFixture");
  execFileSync("xcrun", ["swiftc", "-O", "-swift-version", "5", "-target", "arm64-apple-macos13.0", join(ROOT, "native/opscode-hands/fixture.swift"), "-o", fixture], { stdio: "inherit" });
  const flog = join(scratch, "fixture.log");
  const events = () => (existsSync(flog) ? readFileSync(flog, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
  const pointer = () => execFileSync("osascript", ["-l", "JavaScript", "-e", "ObjC.import('AppKit'); var p = $.NSEvent.mouseLocation; Math.round(p.x) + ',' + Math.round(p.y)"], { encoding: "utf8" }).trim();
  const front = () => hands("apps").apps?.find((a) => a.front)?.name ?? "";
  const frontBefore = front();
  const pointerBefore = pointer();
  const child = spawn(fixture, [], { env: { ...process.env, OPSCODE_FIXTURE_LOG: flog }, stdio: "ignore", detached: false });
  try {
    for (let i = 0; i < 60 && !events().some((e) => e.ev === "ready"); i++) await sleep(100);
    const pid = String(events().find((e) => e.ev === "ready")?.pid ?? child.pid);
    await sleep(400);
    const see = hands("see", pid);
    const id = (label, role = "button") => { const m = new RegExp(`\\[(\\d+)\\] ${role} "${label}"`).exec(see.map ?? ""); return m ? m[1] : null; };
    t.check(LIVE[0], see.ok && !!id("Add one") && !!id("Name", "text field") && /Count: 0/.test(see.map), see.map ?? see.error);
    const c = hands("click", id("Add one"));
    t.check(LIVE[1], c.ok && c.changed === true && events().some((e) => e.ev === "add" && e.count === 1), JSON.stringify(c).slice(0, 400));
    const ty = hands("type", id("Name", "text field"), "Sayan from Opscode");
    t.check(LIVE[2], ty.ok && /Sayan from Opscode/.test(ty.field_has ?? "") , JSON.stringify(ty).slice(0, 400));
    const pw = hands("type", id("Password", "text field"), "secret123");
    t.check(LIVE[3], pw.ok === false && /password/i.test(pw.error ?? ""), JSON.stringify(pw));
    t.check(LIVE[4], /button "Buy now" \(risky\)/.test(hands("see", pid).map ?? ""));
    let m = hands("menu", "HandsFixture > Say Hello", pid);
    if (!m.ok) m = hands("menu", "Fixture > Say Hello", pid);
    t.check(LIVE[5], m.ok && events().some((e) => e.ev === "hello"), JSON.stringify(m).slice(0, 300));
    t.check(LIVE[6], front() === frontBefore, `${frontBefore} -> ${front()}`);
    t.check(LIVE[7], pointer() === pointerBefore, `${pointerBefore} -> ${pointer()}`);
    t.check(LIVE[8], /not there any more|no \[999\]/i.test(hands("click", "999").error ?? ""), JSON.stringify(hands("click", "999")));
  } finally {
    child.kill();
  }
}
rmSync(scratch, { recursive: true, force: true });
process.exit(t.finish());
