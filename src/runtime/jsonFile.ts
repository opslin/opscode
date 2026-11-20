// Private-state helpers: a 0700 directory and atomic 0600 JSON files.

import { randomBytes } from "node:crypto";
import { chmodSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";

export function ensurePrivateDir(dir: string): void {
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  chmodSync(dir, 0o700);
}

/** Parsed JSON, or undefined if the file is missing or unreadable. */
export function readJson(file: string): unknown {
  try {
    return JSON.parse(readFileSync(file, "utf8"));
  } catch {
    return undefined;
  }
}

/** Writes via a temp file + rename, so readers never see a half-written file. */
export function writeJsonAtomic(file: string, data: unknown): void {
  const tmp = `${file}.${process.pid}.${randomBytes(4).toString("hex")}.tmp`;
  try {
    writeFileSync(tmp, JSON.stringify(data, null, 2) + "\n", { mode: 0o600 });
  } catch (e) {
    // A full disk leaves a cut-off temp file behind: remove it, so failed saves do not pile up.
    try { rmSync(tmp, { force: true }); } catch { /* nothing to remove */ }
    throw e;
  }
  // Windows: renaming over a file another program has open (a virus scanner, a search indexer) fails for a moment.
  for (let i = 0; ; i++) {
    try { renameSync(tmp, file); return; } catch (e) {
      const code = (e as NodeJS.ErrnoException).code;
      if (process.platform === "win32" && (code === "EPERM" || code === "EBUSY" || code === "EACCES") && i < 10) { Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 20 * (i + 1)); continue; }
      throw e;
    }
  }
}
