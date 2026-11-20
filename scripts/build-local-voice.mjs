// Prepare a relocatable inference runtime for Opscode's desktop packages.
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const source = join(root, "native/local-voice");
const cache = join(root, "out/cache/voice-runtime");
const pythonVersion = "3.12.14";
const release = "20260901";
const sdk = "kittenml==0.9.8";
const platforms = {
  "darwin-arm64": {
    triple: "aarch64-apple-darwin", uv: "aarch64-apple-darwin",
    sha: "81a359f1cfadd4da11766534c5913791cea55f26e1bb902cacd2a531bb1e4b2b",
  },
  "win32-x64": {
    triple: "x86_64-pc-windows-msvc", uv: "x86_64-pc-windows-msvc",
    sha: "7c45c9622400d578709a9b2cddbe8124cc21d382409d9f13406d706d28e31b14",
  },
};
const hash = (data) => createHash("sha256").update(data).digest("hex");
const run = (exe, args) => execFileSync(exe, args, { stdio: "inherit", cwd: root, windowsHide: true });

export function prepareLocalVoice(target = `${process.platform}-${process.arch}`) {
  const platform = platforms[target];
  if (!platform) throw new Error(`The bundled local voice runtime is unavailable for ${target}.`);
  const requirements = join(source, "requirements.txt");
  const pythonPath = target.startsWith("win") ? "python/python.exe" : "python/bin/python3.12";
  const version = hash(Buffer.concat([readFileSync(requirements), Buffer.from(platform.sha + sdk)]));
  const dest = join(cache, target);
  const marker = join(dest, ".version");
  if (!existsSync(marker) || readFileSync(marker, "utf8") !== version || !existsSync(join(dest, pythonPath))) {
    try { run("uv", ["--version"]); }
    catch { throw new Error("Install uv to prepare the bundled Opscode voice runtime."); }
    mkdirSync(cache, { recursive: true });
    const work = mkdtempSync(join(cache, ".build-"));
    const pack = join(cache, `python-${pythonVersion}-${platform.triple}.tar.gz`);
    try {
      if (!existsSync(pack)) {
        const tmp = join(work, "python.tar.gz");
        const url = `https://releases.astral.sh/github/python-build-standalone/releases/download/${release}/cpython-${pythonVersion}%2B${release}-${platform.triple}-install_only_stripped.tar.gz`;
        run("curl", ["-fsSL", "--retry", "2", "-o", tmp, url]);
        if (hash(readFileSync(tmp)) !== platform.sha) throw new Error("The Python runtime checksum did not match.");
        renameSync(tmp, pack);
      }
      if (hash(readFileSync(pack)) !== platform.sha) throw new Error(`The cached Python runtime checksum did not match: ${pack}`);
      run("tar", ["-xzf", pack, "-C", work]);
      const install = ["pip", "install", "--target", join(work, "packages"), "--python-platform", platform.uv, "--python-version", "3.12"];
      run("uv", [...install, "-r", requirements]);
      // The Kitten SDK also declares dependencies for its larger PyTorch and voice-cloning models.
      run("uv", [...install, "--no-deps", sdk]);
      writeFileSync(join(work, ".version"), version);
      rmSync(dest, { recursive: true, force: true });
      renameSync(work, dest);
    } finally {
      rmSync(work, { recursive: true, force: true });
    }
  }
  cpSync(join(source, "worker.py"), join(dest, "worker.py"));
  return dest;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  console.log(prepareLocalVoice(process.argv[2]));
}
