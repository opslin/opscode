// Builds the native helpers into dist/native (macOS only; needs Xcode's command-line tools).
// opscode-sim: touches/keys/buttons for the iOS Simulator (see native/opscode-sim/main.m).
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, statSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;
if (process.platform !== "darwin") { console.log("native: skipped (not macOS)"); process.exit(0); }
// opscode-voice: microphone + Apple's on-device speech recognition (native/opscode-voice/main.swift).
{
  const vsrc = join(root, "native/opscode-voice/main.swift");
  const vout = join(root, "dist/native/opscode-voice");
  mkdirSync(join(root, "dist/native"), { recursive: true });
  if (existsSync(vout) && statSync(vout).mtimeMs > statSync(vsrc).mtimeMs) console.log("native: opscode-voice up to date");
  else {
    try {
      execFileSync("xcrun", ["swiftc", "-O", "-swift-version", "5", "-target", "arm64-apple-macos13.0", vsrc, "-o", vout], { stdio: "inherit" });
      execFileSync("codesign", ["--force", "--sign", "-", vout], { stdio: "inherit" });
      console.log("native: built dist/native/opscode-voice");
    } catch (e) {
      // Not fatal: the mic button then says voice input is unavailable.
      console.warn(`native: opscode-voice not built (${e.message}); voice input will be unavailable`);
    }
  }
}
const src = join(root, "native/opscode-sim/main.m");
const out = join(root, "dist/native/opscode-sim");
mkdirSync(join(root, "dist/native"), { recursive: true });
if (existsSync(out) && statSync(out).mtimeMs > statSync(src).mtimeMs) { console.log("native: opscode-sim up to date"); process.exit(0); }
try {
  execFileSync("xcrun", ["clang", "-fobjc-arc", "-O2", "-mmacosx-version-min=13.0", "-arch", "arm64", "-arch", "x86_64", "-framework", "Foundation", "-framework", "CoreGraphics", src, "-o", out], { stdio: "inherit" });
  execFileSync("codesign", ["--force", "--sign", "-", out], { stdio: "inherit" });
  console.log("native: built dist/native/opscode-sim");
} catch (e) {
  // Not fatal: Opscode works without it; the iOS tools then say touch input is unavailable.
  console.warn(`native: opscode-sim not built (${e.message}); iOS touch input will be unavailable`);
}
