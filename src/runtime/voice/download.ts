import { createHash } from "node:crypto";
import { createWriteStream } from "node:fs";
import { mkdir, mkdtemp, rename, rm } from "node:fs/promises";
import { get } from "node:https";
import { dirname, join } from "node:path";
import { Transform } from "node:stream";
import { pipeline } from "node:stream/promises";

export interface ModelFile { name: string; url: string; bytes: number; sha256: string }

const hosts = ["huggingface.co", "hf.co", "huggingfaceusercontent.com", "github.com", "githubusercontent.com"];

function response(url: URL, redirects = 0): Promise<import("node:http").IncomingMessage> {
  return new Promise((resolve, reject) => {
    if (redirects > 8 || url.protocol !== "https:" || !hosts.some((host) => url.hostname === host || url.hostname.endsWith(`.${host}`))) {
      reject(new Error(`Unexpected model download host: ${url.hostname}`));
      return;
    }
    const req = get(url, { headers: { "User-Agent": "Opscode" } }, (res) => {
      if (res.statusCode === 200) { resolve(res); return; }
      res.resume();
      if ([301, 302, 303, 307, 308].includes(res.statusCode ?? 0) && res.headers.location) {
        resolve(response(new URL(res.headers.location, url), redirects + 1));
      } else reject(new Error(`The model server answered HTTP ${res.statusCode}`));
    });
    req.on("error", reject);
    req.setTimeout(30_000, () => req.destroy(new Error("The model download stalled")));
  });
}

/** Downloads a pinned bundle into a temporary folder. Only verified files become available to the engines. */
export async function downloadModels(target: string, files: ModelFile[], progress: (bytes: number) => void): Promise<void> {
  const parent = dirname(target);
  await mkdir(parent, { recursive: true, mode: 0o700 });
  const tmp = await mkdtemp(join(parent, ".models-"));
  let total = 0;
  try {
    for (const file of files) {
      const path = join(tmp, file.name);
      await mkdir(dirname(path), { recursive: true, mode: 0o700 });
      const hash = createHash("sha256");
      let size = 0;
      const verify = new Transform({
        transform(chunk: Buffer, _encoding, cb) {
          size += chunk.length;
          if (size > file.bytes) { cb(new Error(`${file.name} exceeds its expected size`)); return; }
          hash.update(chunk);
          total += chunk.length;
          progress(total);
          cb(null, chunk);
        },
      });
      await pipeline(await response(new URL(file.url)), verify, createWriteStream(path, { mode: 0o600 }));
      if (size !== file.bytes || hash.digest("hex") !== file.sha256) throw new Error(`${file.name} did not match its checksum`);
    }
    await rm(target, { recursive: true, force: true });
    await rename(tmp, target);
  } finally {
    await rm(tmp, { recursive: true, force: true });
  }
}
