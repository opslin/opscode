// Builds Opscode.app for macOS from the Electron runtime in node_modules and
// installs it (default: /Applications). The first build provisions the local voice runtime with uv.
//   node scripts/package-mac.mjs            build into ./out and install
//   node scripts/package-mac.mjs --no-install
//
// What it does: copies Electron.app, renames it (and its helper processes) to
// Opscode, swaps the icon and bundle info, puts the project's production files
// in Contents/Resources/app, and signs it ad hoc so macOS will run it.
// Your chats and settings live in ~/Library/Application Support/Opscode, so
// the installed app and `npm start` share them.

import { execFileSync } from "node:child_process";
import { chmodSync, cpSync, existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { prepareLocalVoice } from "./build-local-voice.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const install = !process.argv.includes("--no-install");
const APP = "Opscode";
const BUNDLE_ID = "com.opscode.app";
const out = join(root, "out");
const app = join(out, `${APP}.app`);
const run = (cmd, args, opts = {}) => execFileSync(cmd, args, { stdio: ["ignore", "pipe", "inherit"], ...opts })?.toString() ?? "";
const plist = (file, key, value, type = "string") => {
  const pb = "/usr/libexec/PlistBuddy";
  try { run(pb, ["-c", `Set :${key} ${value}`, file]); } catch { run(pb, ["-c", `Add :${key} ${type} ${value}`, file]); }
};
const plistDelete = (file, key) => { try { run("/usr/libexec/PlistBuddy", ["-c", `Delete :${key}`, file]); } catch { /* not there */ } };

if (process.platform !== "darwin") throw new Error("package-mac.mjs builds the macOS app");
const pkg = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
const icns = join(root, "build/icon/opscode.icns");
if (!existsSync(icns)) throw new Error(`missing ${icns}`);

console.log("1/6 build");
run("npm", ["run", "build"], { cwd: root, stdio: "inherit" });

const voiceRuntime = prepareLocalVoice();

console.log("2/6 copy Electron");
rmSync(app, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const electronApp = join(root, "node_modules/electron/dist/Electron.app");
run("ditto", [electronApp, app]);

console.log("3/6 rename to " + APP);
const macos = join(app, "Contents/MacOS");
renameSync(join(macos, "Electron"), join(macos, APP));
const info = join(app, "Contents/Info.plist");
plist(info, "CFBundleName", APP);
plist(info, "CFBundleDisplayName", APP);
plist(info, "CFBundleExecutable", APP);
plist(info, "CFBundleIdentifier", BUNDLE_ID);
plist(info, "CFBundleIconFile", "opscode.icns");
plist(info, "CFBundleShortVersionString", pkg.version);
plist(info, "CFBundleVersion", pkg.version);
plist(info, "NSHumanReadableCopyright", "Opscode");
// macOS shows this when Opscode first requests microphone access.
plist(info, "NSMicrophoneUsageDescription", "Opscode uses the microphone when you dictate a message or record a voice note. Speech is turned into text on this Mac.");
plistDelete(info, "ElectronAsarIntegrity");
rmSync(join(app, "Contents/Resources/electron.icns"), { force: true });
cpSync(icns, join(app, "Contents/Resources/opscode.icns"));
rmSync(join(app, "Contents/Resources/default_app.asar"), { force: true });
// Helper processes: "Electron Helper (GPU)" -> "Opscode Helper (GPU)", etc.
const frameworks = join(app, "Contents/Frameworks");
for (const name of readdirSync(frameworks)) {
  const m = /^Electron Helper(.*)\.app$/.exec(name);
  if (!m) continue;
  const suffix = m[1]; // "", " (GPU)", " (Renderer)", " (Plugin)"
  const newName = `${APP} Helper${suffix}`;
  const dir = join(frameworks, name);
  renameSync(join(dir, "Contents/MacOS", `Electron Helper${suffix}`), join(dir, "Contents/MacOS", newName));
  const hp = join(dir, "Contents/Info.plist");
  plist(hp, "CFBundleName", newName);
  plist(hp, "CFBundleDisplayName", newName);
  plist(hp, "CFBundleExecutable", newName);
  plist(hp, "CFBundleIdentifier", `${BUNDLE_ID}.helper${suffix ? "." + suffix.replace(/[^A-Za-z]/g, "") : ""}`);
  renameSync(dir, join(frameworks, `${newName}.app`));
}

console.log("4/6 copy the app");
const resources = join(app, "Contents/Resources/app");
mkdirSync(resources, { recursive: true });
cpSync(voiceRuntime, join(resources, "voice-runtime"), { recursive: true, verbatimSymlinks: true });
const slim = { name: pkg.name, productName: pkg.productName ?? APP, version: pkg.version, main: pkg.main, type: pkg.type, dependencies: pkg.dependencies };
writeFileSync(join(resources, "package.json"), JSON.stringify(slim, null, 2));
cpSync(join(root, "dist"), join(resources, "dist"), {
  recursive: true,
  filter: (source) => source !== join(root, "dist/native/opscode-voice"),
});
cpSync(join(root, "assets/brand"), join(resources, "assets/brand"), { recursive: true });
// Production dependencies only (and what they need), found by npm itself.
const prod = run("npm", ["ls", "--omit=dev", "--all", "--parseable"], { cwd: root }).split("\n").map((s) => s.trim()).filter((p) => p && p !== root && p.startsWith(join(root, "node_modules")));
for (const dir of prod) {
  const rel = dir.slice(root.length + 1);
  cpSync(dir, join(resources, rel), { recursive: true, dereference: false });
}
console.log(`   ${prod.length} production packages`);
// node-pty's spawn-helper must stay executable.
for (const arch of ["darwin-arm64", "darwin-x64"]) {
  const h = join(resources, "node_modules/node-pty/prebuilds", arch, "spawn-helper");
  if (existsSync(h)) chmodSync(h, 0o755);
}

// Computer use: the hands helper goes beside the app's own program, so macOS treats it as part of Opscode and applies the
// person's Accessibility permission for Opscode to it (a helper left in Resources would need a permission of its own).
const handsSrc = join(root, "dist/native/opscode-hands");
const handsDest = join(app, "Contents/MacOS/opscode-hands");
if (existsSync(handsSrc)) { cpSync(handsSrc, handsDest); chmodSync(handsDest, 0o755); }

// Signing. With the person's own "Opscode Local Signing" certificate (in the login keychain) every build has the same identity,
// so macOS keeps the Accessibility / Screen Recording / Microphone permissions across reinstalls. Ad hoc signing would make
// each build a new app to macOS (its identity is the exact build fingerprint) and the permissions silently stop applying.
// OPSCODE_SIGN_IDENTITY picks another identity; "-" forces ad hoc.
const IDENTITY = process.env.OPSCODE_SIGN_IDENTITY ?? "Opscode Local Signing";
let signWith = "-";
if (IDENTITY !== "-") {
  try { if (run("security", ["find-identity", "-p", "codesigning"]).includes(`"${IDENTITY}"`)) signWith = IDENTITY; } catch { /* no keychain access */ }
}
console.log(`5/6 sign (${signWith === "-" ? "ad hoc: permissions are forgotten on each reinstall" : signWith})`);
run("xattr", ["-cr", app]);
run("codesign", ["--force", "--deep", "--sign", signWith, app]);
if (existsSync(handsDest)) {
  // Signed as the app itself (same identifier, so the same designated requirement), then the app is sealed again to include it.
  run("codesign", ["--force", "--sign", signWith, "--identifier", "com.opscode.app", handsDest]);
  run("codesign", ["--force", "--sign", signWith, app]);
}
run("codesign", ["--verify", "--deep", "--strict", app]);
if (existsSync(handsDest)) console.log(`   helper: ${run("codesign", ["-dr", "-", handsDest], { stdio: ["ignore", "pipe", "pipe"] }).trim().split("\n").pop()}`);
if (signWith !== "-") console.log(`   ${run("codesign", ["-dr", "-", app], { stdio: ["ignore", "pipe", "pipe"] }).trim().split("\n").pop()}`);

if (!install) { console.log(`6/6 done: ${app}`); process.exit(0); }
console.log("6/6 install to /Applications");
const dest = `/Applications/${APP}.app`;
rmSync(dest, { recursive: true, force: true });
run("ditto", [app, dest]);
// Make Finder and the Dock pick up the new icon.
try { run("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister", ["-f", dest]); } catch { /* optional */ }
run("touch", [dest]);
console.log(`installed ${dest}`);
