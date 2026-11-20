// Free disk space. A full disk breaks builds (Gradle, Flutter), saving chats and installing tools, and on 2026-11-19 it
// crashed the runtime: a chat now shows a short card when the disk where the project lives is nearly full.

import { readFileSync, statfsSync } from "node:fs";

/** Below this, a chat says the disk is low. */
export const LOW_DISK_BYTES = 5 * 1024 ** 3;
/** Below this, builds and saving are likely to fail. */
export const VERY_LOW_DISK_BYTES = 1024 ** 3;

/** Bytes free for this user on the disk holding `path`; null when it cannot be read. */
export function freeBytes(path: string): number | null {
  // Tests: OPSCODE_FAKE_FREE_BYTES_FILE names a file holding the number (read on every check, so a test can change it).
  const file = process.env.OPSCODE_FAKE_FREE_BYTES_FILE;
  if (file) {
    try { const n = Number(readFileSync(file, "utf8").trim()); if (Number.isFinite(n)) return n; } catch { /* no file: the real disk */ }
  }
  try {
    const s = statfsSync(path);
    return Number(s.bavail) * Number(s.bsize);
  } catch {
    return null;
  }
}

const gb = (n: number): string => `${(n / 1024 ** 3).toFixed(1)} GB`;

/** The card to show when free space is low, or null when there is enough. */
export function lowDiskCard(path: string): { summary: string; detail: string } | null {
  const free = freeBytes(path);
  if (free === null || free >= LOW_DISK_BYTES) return null;
  const very = free < VERY_LOW_DISK_BYTES;
  return {
    summary: `${very ? "Disk almost full" : "Low disk space"}: ${gb(free)} free`,
    detail: `Your disk has only ${gb(free)} free. ${very ? "Builds, installs and saving chats will likely fail." : "Builds (Gradle, Flutter, Xcode) and installs may fail."} Free some space (for example old build folders, caches or downloads), then try again.`,
  };
}
