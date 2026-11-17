// The speech model for computers without Apple's recognizer (Windows, Linux): Kroko's streaming English model (CC-BY-SA,
// 57 MB) and the Silero voice-activity model (0.6 MB), both from the sherpa-onnx releases on GitHub. Downloaded once,
// on first use, with progress; size and checksum are verified and the archive is listed before it is unpacked.

import { spawn } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { createWriteStream, existsSync, mkdirSync, renameSync, rmSync, statSync } from "node:fs";
import http from "node:http";
import https from "node:https";
import { join } from "node:path";

const BASE = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models";
export const KROKO = {
  url: `${BASE}/sherpa-onnx-streaming-zipformer-en-kroko-2025-08-06.tar.bz2`,
  bytes: 57_267_600,
  sha256: "c8676e5ff9ac2a85296e53ee0fd4d5fb1db6770e7a7647166eeafe349ade6834",
  folder: "sherpa-onnx-streaming-zipformer-en-kroko-2025-08-06",
  files: ["encoder.onnx", "decoder.onnx", "joiner.onnx", "tokens.txt"],
};
export const SILERO = {
  url: `${BASE}/silero_vad.onnx`,
  bytes: 643_854,
  sha256: "9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6",
};

export interface SpeechFiles { encoder: string; decoder: string; joiner: string; tokens: string; vad: string }

/** Where the files of an installed speech model are (dir = the app's voice folder). */
export function speechFiles(dir: string): SpeechFiles {
  const k = join(dir, "kroko");
  return { encoder: join(k, "encoder.onnx"), decoder: join(k, "decoder.onnx"), joiner: join(k, "joiner.onnx"), tokens: join(k, "tokens.txt"), vad: join(dir, "silero_vad.onnx") };
}

export function speechInstalled(dir: string): boolean {
  try {
    const f = speechFiles(dir);
    return [f.encoder, f.decoder, f.joiner, f.tokens, f.vad].every((p) => statSync(p).isFile());
  } catch { return false; }
}

const HOSTS = [/^github\.com$/, /(^|\.)githubusercontent\.com$/];
const hostOk = (h: string): boolean => HOSTS.some((r) => r.test(h));

/** https download with redirects to GitHub's own hosts only; streams to a file and hashes as it goes. */
function download(url: string, dest: string, onBytes: (n: number) => void, hops = 0): Promise<{ bytes: number; sha256: string }> {
  return new Promise((resolve, reject) => {
    if (hops > 5) return reject(new Error("too many redirects"));
    let u: URL;
    try { u = new URL(url); } catch { return reject(new Error("bad download address")); }
    const test = process.env.OPSCODE_VOICE_TEST_HTTP === "1" && (u.hostname === "127.0.0.1" || u.hostname === "localhost");
    if (!test && (u.protocol !== "https:" || !hostOk(u.hostname))) return reject(new Error(`will not download from ${u.hostname}`));
    const get = u.protocol === "http:" ? http.get : https.get;
    const req = get(u, { headers: { "User-Agent": "Opscode" } }, (res) => {
      const code = res.statusCode ?? 0;
      if ([301, 302, 303, 307, 308].includes(code) && res.headers.location) { res.resume(); return resolve(download(new URL(res.headers.location, u).toString(), dest, onBytes, hops + 1)); }
      if (code !== 200) { res.resume(); return reject(new Error(`the download server answered ${code}`)); }
      const total = Number(res.headers["content-length"] ?? 0);
      const hash = createHash("sha256");
      const out = createWriteStream(dest, { mode: 0o600 });
      let bytes = 0;
      res.on("data", (d: Buffer) => { bytes += d.length; hash.update(d); onBytes(d.length); });
      res.pipe(out);
      out.on("finish", () => (total && bytes !== total ? reject(new Error("the download was cut short")) : resolve({ bytes, sha256: hash.digest("hex") })));
      out.on("error", reject);
      res.on("error", reject);
    });
    req.on("error", reject);
    req.setTimeout(30_000, () => req.destroy(new Error("the download stalled")));
  });
}

/** `tar` (Windows 10+ has its own in System32; it reads .tar.bz2 like macOS and Linux do). */
export function tarProgram(): string {
  if (process.platform === "win32") {
    const sys = join(process.env.SystemRoot ?? "C:\\Windows", "System32", "tar.exe");
    return existsSync(sys) ? sys : "tar";
  }
  return existsSync("/usr/bin/tar") ? "/usr/bin/tar" : "tar";
}

const run = (args: string[]): Promise<string> => new Promise((resolve, reject) => {
  const p = spawn(tarProgram(), args, { stdio: ["ignore", "pipe", "pipe"], windowsHide: true });
  let out = "", err = "";
  p.stdout.on("data", (d) => (out += d));
  p.stderr.on("data", (d) => (err += d));
  p.on("error", reject);
  p.on("exit", (c) => (c === 0 ? resolve(out) : reject(new Error(`tar failed: ${err.trim().slice(0, 200)}`))));
});

/** Every entry of the archive must be inside the model's folder (no absolute paths, no ".."). */
async function untarSafe(file: string, into: string, folder: string): Promise<void> {
  const list = await run(["-tjf", file]);
  for (const raw of list.split(/\r?\n/)) {
    const name = raw.trim().replace(/\\/g, "/");
    if (!name) continue;
    if (name.startsWith("/") || /^[a-zA-Z]:/.test(name) || name.split("/").includes("..") || !(name === `${folder}/` || name.startsWith(`${folder}/`))) throw new Error(`the archive holds an unexpected path: ${name.slice(0, 80)}`);
  }
  await run(["-xjf", file, "-C", into]);
}

/**
 * Makes sure the speech model is there (downloading it the first time). progress: 0..1 over both files.
 * Env OPSCODE_VOICE_MODEL_URL / _SHA256 / _VAD_URL let tests point at a local server (OPSCODE_VOICE_TEST_HTTP=1).
 */
export async function ensureSpeechModel(dir: string, progress: (p: number) => void): Promise<void> {
  if (speechInstalled(dir)) return;
  mkdirSync(dir, { recursive: true });
  const modelUrl = process.env.OPSCODE_VOICE_MODEL_URL || KROKO.url;
  const vadUrl = process.env.OPSCODE_VOICE_VAD_URL || SILERO.url;
  const test = !!process.env.OPSCODE_VOICE_MODEL_URL;
  const total = KROKO.bytes + SILERO.bytes;
  let done = 0;
  const tick = (n: number): void => { done += n; progress(Math.min(0.99, done / total)); };
  const tmp = join(dir, `.download-${randomBytes(4).toString("hex")}`);
  const work = join(dir, `.extract-${randomBytes(4).toString("hex")}`);
  try {
    if (!existsSync(speechFiles(dir).vad)) {
      const v = await download(vadUrl, `${tmp}.onnx`, tick);
      if (!test && (v.bytes !== SILERO.bytes || v.sha256 !== SILERO.sha256)) throw new Error("the voice-activity file does not match its checksum, so it was thrown away");
      renameSync(`${tmp}.onnx`, speechFiles(dir).vad);
    }
    const f = speechFiles(dir);
    if (![f.encoder, f.decoder, f.joiner, f.tokens].every((p) => existsSync(p))) {
      const m = await download(modelUrl, `${tmp}.tar.bz2`, tick);
      if (!test && (m.bytes !== KROKO.bytes || m.sha256 !== KROKO.sha256)) throw new Error("the speech model does not match its checksum, so it was thrown away");
      mkdirSync(work, { recursive: true });
      await untarSafe(`${tmp}.tar.bz2`, work, KROKO.folder);
      const unpacked = join(work, KROKO.folder);
      for (const name of KROKO.files) if (!existsSync(join(unpacked, name))) throw new Error(`${name} is missing from the speech model`);
      rmSync(join(dir, "kroko"), { recursive: true, force: true });
      renameSync(unpacked, join(dir, "kroko"));
    }
    progress(1);
  } finally {
    rmSync(`${tmp}.onnx`, { force: true });
    rmSync(`${tmp}.tar.bz2`, { force: true });
    rmSync(work, { recursive: true, force: true });
  }
}
