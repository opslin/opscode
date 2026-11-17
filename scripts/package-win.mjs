// Builds Opscode for Windows (x64) from a Mac or any computer, with no Windows machine and no Wine:
//   node scripts/package-win.mjs                 app folder + portable zip + installer (.exe)
//   node scripts/package-win.mjs --no-installer  app folder + portable zip only
//   node scripts/package-win.mjs --no-build      reuse dist/ (skip `npm run build`)
//
// It takes Electron's Windows build (checked against its published checksum), renames it to Opscode.exe and gives it the
// Opscode icon and version (resedit, in JavaScript), copies the app and its production packages into resources/app, swaps
// the Mac-only native pieces for the Windows ones (node-pty's Windows prebuilds, sherpa-onnx-win-x64), drops the Mac
// helpers, and wraps it in an NSIS installer with electron-builder (which brings its own makensis).
// The result is NOT code-signed: Windows SmartScreen shows "Unknown publisher" the first time (More info -> Run anyway).

import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import * as ResEdit from "resedit";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const flag = (f) => process.argv.includes(f);
const APP = "Opscode";
const out = join(root, "out");
const cache = join(out, "cache");
const dir = join(out, "win", `${APP}-win32-x64`);
const pkg = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
const electronVersion = JSON.parse(readFileSync(join(root, "node_modules/electron/package.json"), "utf8")).version;
const sherpaVersion = JSON.parse(readFileSync(join(root, "node_modules/sherpa-onnx-node/package.json"), "utf8")).version;
const run = (cmd, args, opts = {}) => execFileSync(cmd, args, { stdio: ["ignore", "pipe", "inherit"], ...opts })?.toString() ?? "";
const sha256 = (file) => createHash("sha256").update(readFileSync(file)).digest("hex");
const mb = (f) => `${(statSync(f).size / 1e6).toFixed(0)} MB`;

mkdirSync(cache, { recursive: true });
const fetchTo = (url, file) => { if (!existsSync(file)) { console.log(`   downloading ${url.split("/").pop()}`); run("curl", ["-fsSL", "--retry", "3", "-o", `${file}.part`, url]); renameSync(`${file}.part`, file); } return file; };

if (!flag("--no-build")) { console.log("1/7 build"); run("npm", ["run", "build"], { cwd: root, stdio: "inherit" }); } else console.log("1/7 build skipped");

console.log(`2/7 Electron ${electronVersion} for Windows`);
const zipName = `electron-v${electronVersion}-win32-x64.zip`;
const zip = fetchTo(`https://github.com/electron/electron/releases/download/v${electronVersion}/${zipName}`, join(cache, zipName));
const sums = fetchTo(`https://github.com/electron/electron/releases/download/v${electronVersion}/SHASUMS256.txt`, join(cache, `electron-${electronVersion}-SHASUMS256.txt`));
const want = readFileSync(sums, "utf8").split("\n").map((l) => l.trim().split(/\s+/)).find((p) => (p[1] ?? "").replace(/^\*/, "") === zipName)?.[0];
if (!want || sha256(zip) !== want) { rmSync(zip, { force: true }); throw new Error(`the Electron download does not match its checksum (${zipName})`); }
console.log(`   checksum ok (${mb(zip)})`);
rmSync(join(out, "win"), { recursive: true, force: true });
mkdirSync(dir, { recursive: true });
run("unzip", ["-q", zip, "-d", dir]);

console.log("3/7 rename to Opscode.exe, icon and version");
const exePath = join(dir, `${APP}.exe`);
renameSync(join(dir, "electron.exe"), exePath);
rmSync(join(dir, "resources", "default_app.asar"), { force: true });
// Chromium's language files: English only (the app is in English); the rest is about 35 MB.
for (const f of readdirSync(join(dir, "locales"))) if (f !== "en-US.pak") rmSync(join(dir, "locales", f), { force: true });
{
  const exe = ResEdit.NtExecutable.from(readFileSync(exePath));
  const res = ResEdit.NtExecutableResource.from(exe);
  const ico = ResEdit.Data.IconFile.from(readFileSync(join(root, "assets/brand/logo/opscode.ico")));
  ResEdit.Resource.IconGroupEntry.replaceIconsForResource(res.entries, 1, 1033, ico.icons.map((i) => i.data));
  const vi = ResEdit.Resource.VersionInfo.fromEntries(res.entries)[0];
  const [a = 0, b = 0, c = 0] = pkg.version.split(".").map(Number);
  vi.setFileVersion(a, b, c, 0, 1033);
  vi.setProductVersion(a, b, c, 0, 1033);
  vi.setStringValues({ lang: 1033, codepage: 1200 }, { FileDescription: APP, ProductName: APP, CompanyName: APP, LegalCopyright: APP, OriginalFilename: `${APP}.exe`, InternalName: APP, FileVersion: pkg.version, ProductVersion: pkg.version });
  vi.outputToResourceEntries(res.entries);
  res.outputResource(exe);
  writeFileSync(exePath, Buffer.from(exe.generate()));
}

console.log("4/7 copy the app");
const app = join(dir, "resources", "app");
mkdirSync(app, { recursive: true });
const slim = { name: pkg.name, productName: pkg.productName ?? APP, version: pkg.version, main: pkg.main, type: pkg.type, dependencies: pkg.dependencies };
writeFileSync(join(app, "package.json"), JSON.stringify(slim, null, 2));
cpSync(join(root, "dist"), join(app, "dist"), { recursive: true, filter: (src) => !src.includes(`${join("dist", "native")}`) }); // the Swift / Objective-C helpers are Mac-only
cpSync(join(root, "assets/brand"), join(app, "assets/brand"), { recursive: true });
for (const f of ["THIRD_PARTY_NOTICES.md", "README.md"]) if (existsSync(join(root, f))) cpSync(join(root, f), join(app, f));
const NOT_WINDOWS = /^node_modules\/(sherpa-onnx-(darwin|linux)-\w+|@esbuild|esbuild)(\/|$)/;
const prod = run("npm", ["ls", "--omit=dev", "--all", "--parseable"], { cwd: root }).split("\n").map((s) => s.trim()).filter((p) => p && p !== root && p.startsWith(join(root, "node_modules")));
let n = 0;
for (const d of prod) {
  const rel = d.slice(root.length + 1);
  if (NOT_WINDOWS.test(rel)) continue;
  cpSync(d, join(app, rel), { recursive: true, dereference: false });
  n++;
}
console.log(`   ${n} production packages`);

console.log("5/7 the Windows native pieces");
// node-pty: keep only the Windows prebuilds (ConPTY).
const pty = join(app, "node_modules", "node-pty");
for (const sub of ["prebuilds/darwin-arm64", "prebuilds/darwin-x64", "prebuilds/win32-arm64", "build"]) rmSync(join(pty, sub), { recursive: true, force: true });
if (!existsSync(join(pty, "prebuilds/win32-x64/conpty.node"))) throw new Error("node-pty has no Windows prebuild");
// sherpa-onnx: the Windows package (speech recognition and the Pocket TTS voice).
const tgz = fetchTo(`https://registry.npmjs.org/sherpa-onnx-win-x64/-/sherpa-onnx-win-x64-${sherpaVersion}.tgz`, join(cache, `sherpa-onnx-win-x64-${sherpaVersion}.tgz`));
const tmp = join(cache, "sherpa-win");
rmSync(tmp, { recursive: true, force: true });
mkdirSync(tmp, { recursive: true });
run("tar", ["-xzf", tgz, "-C", tmp]);
cpSync(join(tmp, "package"), join(app, "node_modules", "sherpa-onnx-win-x64"), { recursive: true });
for (const f of ["sherpa-onnx.node", "onnxruntime.dll", "sherpa-onnx-c-api.dll"]) if (!existsSync(join(app, "node_modules", "sherpa-onnx-win-x64", f))) throw new Error(`sherpa-onnx-win-x64 lacks ${f}`);
if (existsSync(join(app, "dist", "native"))) throw new Error("Mac helpers leaked into the Windows app");

console.log("6/7 portable zip");
const zipOut = join(out, `${APP}-${pkg.version}-win-x64-portable.zip`);
rmSync(zipOut, { force: true });
run("zip", ["-qr", zipOut, `${APP}-win32-x64`], { cwd: join(out, "win") });
console.log(`   ${zipOut} (${mb(zipOut)})`);

if (flag("--no-installer")) { console.log("7/7 installer skipped"); process.exit(0); }
console.log("7/7 installer (NSIS)");
rmSync(join(out, "win-installer"), { recursive: true, force: true });
run("npx", ["electron-builder", "--win", "nsis", "--x64", "--prepackaged", dir, "--config", join(root, "build/win/electron-builder.json"), "-p", "never"], { cwd: root, stdio: "inherit" });
const installer = readdirSync(join(out, "win-installer")).find((f) => f.endsWith(".exe"));
if (!installer) throw new Error("the installer was not made");
console.log(`done: ${join(out, "win-installer", installer)} (${mb(join(out, "win-installer", installer))})`);
