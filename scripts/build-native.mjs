// Builds the native helpers into dist/native (macOS only; needs Xcode's command-line tools).
// opscode-sim: touches/keys/buttons for the iOS Simulator (see native/opscode-sim/main.m).
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, statSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;
if (process.platform !== "darwin") { console.log("native: skipped (not macOS)"); process.exit(0); }
{
  const source = join(root, "native/opscode-pair-qr/main.swift");
  const binary = join(root, "dist/native/opscode-pair-qr");
  mkdirSync(join(root, "dist/native"), { recursive: true });
  if (!existsSync(binary) || statSync(binary).mtimeMs < statSync(source).mtimeMs) {
    try {
      execFileSync("xcrun", ["swiftc", "-O", "-target", "arm64-apple-macos13.0", source, "-o", binary], { stdio: "inherit" });
      console.log("native: built dist/native/opscode-pair-qr");
    } catch (error) {
      console.warn(`native: phone pairing QR helper unavailable (${error.message})`);
    }
  }
}
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
// opscode-hands: computer use through Accessibility (native/opscode-hands/main.swift). The test app beside it is built by its test only.
{
  const hsrc = join(root, "native/opscode-hands/main.swift");
  const hout = join(root, "dist/native/opscode-hands");
  mkdirSync(join(root, "dist/native"), { recursive: true });
  if (existsSync(hout) && statSync(hout).mtimeMs > statSync(hsrc).mtimeMs) console.log("native: opscode-hands up to date");
  else {
    try {
      execFileSync("xcrun", ["swiftc", "-O", "-swift-version", "5", "-target", "arm64-apple-macos13.0", hsrc, "-o", hout], { stdio: "inherit" });
      execFileSync("codesign", ["--force", "--sign", "-", hout], { stdio: "inherit" });
      console.log("native: built dist/native/opscode-hands");
    } catch (e) {
      // Not fatal: computer use then falls back to screenshots and clicks by position.
      console.warn(`native: opscode-hands not built (${e.message}); computer use falls back to screenshots`);
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
