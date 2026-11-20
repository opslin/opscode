// fs.* operations, always through paths.ts so they stay inside the project.

import { randomBytes } from "node:crypto";
import {
  closeSync,
  constants,
  fchmodSync,
  fstatSync,
  fsyncSync,
  lstatSync,
  openSync,
  readSync,
  readdirSync,
  renameSync,
  statSync,
  unlinkSync,
  writeSync,
} from "node:fs";
import { join } from "node:path";
import { LIMITS, type FsEntry, type FsEntryKind } from "../shared/protocol";
import { fail, RpcFailure } from "./rpc";
import { ioFailure, resolveExisting, resolveForWrite } from "./paths";

/** Keep protocol failures as they are; map anything else from fs. */
const rethrow = (e: unknown, what: string): Error => (e instanceof RpcFailure ? e : ioFailure(e, what));

export function listDir(root: string, rel: string): { path: string; entries: FsEntry[]; truncated: boolean } {
  const target = resolveExisting(root, rel);
  let names: string[];
  try {
    if (!statSync(target.abs).isDirectory()) throw fail.invalid("path is not a directory");
    names = readdirSync(target.abs);
  } catch (e) {
    throw rethrow(e, target.rel);
  }

  const truncated = names.length > LIMITS.FS_LIST_MAX_ENTRIES;
  const entries: FsEntry[] = [];
  for (const name of names.slice(0, LIMITS.FS_LIST_MAX_ENTRIES)) {
    try {
      // lstat: report symlinks as symlinks; listing never follows them.
      const st = lstatSync(join(target.abs, name));
      const kind: FsEntryKind = st.isSymbolicLink() ? "symlink" : st.isDirectory() ? "dir" : st.isFile() ? "file" : "other";
      entries.push({ name, kind, size: st.isFile() ? st.size : 0, mtime: st.mtime.toISOString() });
    } catch {
      /* vanished between readdir and lstat */
    }
  }
  entries.sort((a, b) => (a.kind === "dir") === (b.kind === "dir") ? a.name.localeCompare(b.name) : a.kind === "dir" ? -1 : 1);
  return { path: target.rel, entries, truncated };
}

export interface ReadResult {
  path: string;
  size: number;
  truncated: boolean;
  encoding: "utf8" | "base64";
  content: string;
}

/** A binary slice with a file revision so transfers do not mix bytes from different versions. */
export function readFileChunk(root: string, rel: string, offset: number, maxBytes: number, expected?: string) {
  const target = resolveExisting(root, rel);
  let fd: number;
  try { fd = openSync(target.abs, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK); }
  catch (error) { throw ioFailure(error, target.rel); }
  try {
    const stat = fstatSync(fd);
    if (!stat.isFile()) throw fail.invalid("path is not a regular file");
    const revisionOf = (s: typeof stat) => [s.dev, s.ino, s.size, s.mtimeMs, s.ctimeMs].join(":");
    const revision = revisionOf(stat);
    if (expected !== undefined && revision !== expected) throw fail.conflict("The file changed during transfer.");
    if (offset > stat.size) throw fail.invalid("The file is shorter than expected.");
    const bytes = Buffer.alloc(Math.min(maxBytes, stat.size - offset));
    let read = 0;
    while (read < bytes.length) {
      const count = readSync(fd, bytes, read, bytes.length - read, offset + read);
      if (!count) break;
      read += count;
    }
    if (read !== bytes.length || (read > 0 && revisionOf(fstatSync(fd)) !== revision)) {
      throw fail.conflict("The file changed during transfer.");
    }
    return { size: stat.size, offset: offset + read, revision, data: bytes.toString("base64") };
  } catch (error) { throw rethrow(error, target.rel); }
  finally { closeSync(fd); }
}

export function readFile(root: string, rel: string, maxBytes: number = LIMITS.FS_IO_MAX_BYTES): ReadResult {
  const target = resolveExisting(root, rel);
  let fd: number;
  try {
    fd = openSync(target.abs, constants.O_RDONLY | constants.O_NOFOLLOW);
  } catch (e) {
    throw ioFailure(e, target.rel);
  }
  try {
    const st = fstatSync(fd);
    if (!st.isFile()) throw fail.invalid("path is not a regular file");
    const want = Math.min(st.size, maxBytes);
    const buf = Buffer.alloc(want);
    let got = 0;
    while (got < want) {
      const n = readSync(fd, buf, got, want - got, got);
      if (n === 0) break;
      got += n;
    }
    const bytes = buf.subarray(0, got);
    const truncated = st.size > got;

    // Text if it has no NUL in the first 8 KiB and decodes as UTF-8
    // (a multi-byte character cut off by truncation is tolerated).
    let text: string | undefined;
    if (!bytes.subarray(0, 8192).includes(0)) {
      try {
        text = new TextDecoder("utf-8", { fatal: true }).decode(bytes, { stream: truncated });
      } catch {
        text = undefined;
      }
    }
    return text === undefined
      ? { path: target.rel, size: st.size, truncated, encoding: "base64", content: bytes.toString("base64") }
      : { path: target.rel, size: st.size, truncated, encoding: "utf8", content: text };
  } catch (e) {
    throw rethrow(e, target.rel);
  } finally {
    closeSync(fd);
  }
}

/**
 * Atomic write: a temp file is created exclusively (O_EXCL|O_NOFOLLOW) in the
 * verified directory, then renamed over the target. An existing file keeps its
 * permission bits.
 */
export function writeFile(root: string, rel: string, content: Buffer, createDirs: boolean): { path: string; size: number } {
  if (content.length > LIMITS.FS_IO_MAX_BYTES) throw fail.limit(`content exceeds ${LIMITS.FS_IO_MAX_BYTES} bytes`);
  const target = resolveForWrite(root, rel, createDirs);
  const finalPath = join(target.dir, target.name);

  let mode = 0o644;
  try {
    const existing = statSync(finalPath);
    if (!existing.isFile()) throw fail.invalid("path is not a regular file");
    mode = existing.mode & 0o7777;
  } catch (e) {
    if (e instanceof RpcFailure) throw e; // e.g. target is a FIFO/device
    // otherwise: no existing file, keep the default mode
  }

  const tmp = join(target.dir, `.${target.name}.opscode-${randomBytes(6).toString("hex")}.tmp`);
  let fd: number | undefined;
  try {
    fd = openSync(tmp, constants.O_WRONLY | constants.O_CREAT | constants.O_EXCL | constants.O_NOFOLLOW, 0o600);
    let off = 0;
    while (off < content.length) off += writeSync(fd, content, off, content.length - off);
    fchmodSync(fd, mode);
    fsyncSync(fd);
    closeSync(fd);
    fd = undefined;
    renameSync(tmp, finalPath);
  } catch (e) {
    if (fd !== undefined) closeSync(fd);
    try {
      unlinkSync(tmp);
    } catch {
      /* not created */
    }
    throw ioFailure(e, target.rel);
  }
  return { path: target.rel, size: content.length };
}
