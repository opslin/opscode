// Resolves client-supplied paths inside a workspace root. This is the only
// place that turns a request path into a filesystem path, and it guarantees the
// result — after following symlinks — stays inside the project:
//
//   * client paths must be relative (no absolute / drive paths) and NUL-free;
//   * the lexical join must stay inside the root (blocks "../");
//   * the realpath must stay inside the root (blocks symlinks pointing out);
//   * writes are refused under any ".git" segment and onto broken symlinks.
//
// Residual risk: a process that can rename directories inside the project
// between our check and the write could race us; writes land via
// temp-file + rename in the verified directory to narrow that window.

import { lstatSync, mkdirSync, realpathSync } from "node:fs";
import { basename, dirname, isAbsolute, join, relative, resolve, sep, win32 } from "node:path";
import type { Workspace } from "../shared/protocol";
import { LIMITS } from "../shared/protocol";
import { fail } from "./rpc";

const errno = (e: unknown): string | undefined =>
  typeof e === "object" && e !== null && "code" in e ? String((e as { code: unknown }).code) : undefined;

export const isInside = (root: string, p: string): boolean => p === root || p.startsWith(root + sep);

/** Workspace-relative POSIX path ("." for the root). */
export const toRel = (root: string, abs: string): string => relative(root, abs).split(sep).join("/") || ".";

/** The workspace root, refusing if the folder vanished or was swapped for a link. */
export function rootOf(workspace: Workspace): string {
  let real: string;
  try {
    real = realpathSync(workspace.path);
  } catch {
    throw fail.notFound("the project folder no longer exists");
  }
  if (real !== workspace.path) throw fail.forbidden("the project folder was moved or replaced");
  return real;
}

function checkClientPath(rel: string): void {
  if (rel.length > LIMITS.PATH_MAX_CHARS) throw fail.invalid("path is too long");
  if (rel.includes("\0")) throw fail.invalid("path must not contain NUL");
  if (isAbsolute(rel) || win32.isAbsolute(rel)) throw fail.invalid("path must be relative to the project");
}

/** Maps fs errors to protocol failures. */
export function ioFailure(e: unknown, what: string): Error {
  const code = errno(e);
  if (code === "ENOENT" || code === "ENOTDIR") return fail.notFound(`${what}: no such file or directory`);
  if (code === "EACCES" || code === "EPERM") return fail.io(`${what}: permission denied`, code);
  if (code === "EISDIR") return fail.invalid(`${what}: is a directory`);
  return fail.io(`${what}: ${code ?? "I/O error"}`, code);
}

/** An existing path inside the root (symlinks followed and re-checked). */
export function resolveExisting(root: string, rel: string): { abs: string; rel: string } {
  checkClientPath(rel);
  const lexical = resolve(root, rel === "" ? "." : rel);
  if (!isInside(root, lexical)) throw fail.forbidden("path is outside the project");
  let real: string;
  try {
    real = realpathSync(lexical);
  } catch (e) {
    throw ioFailure(e, rel || ".");
  }
  if (!isInside(root, real)) throw fail.forbidden("path resolves outside the project (symlink)");
  return { abs: real, rel: toRel(root, real) };
}

const hasGitSegment = (root: string, abs: string): boolean => relative(root, abs).split(sep).includes(".git");

/**
 * Target for a write: the verified real directory plus the leaf name.
 * An existing leaf symlink is written *through* only if its target is inside.
 */
export function resolveForWrite(
  root: string,
  rel: string,
  createDirs: boolean,
): { dir: string; name: string; rel: string } {
  checkClientPath(rel);
  const lexical = resolve(root, rel);
  if (!isInside(root, lexical) || lexical === root) throw fail.forbidden("path is outside the project");
  if (hasGitSegment(root, lexical)) throw fail.forbidden("writing inside .git is not allowed");

  // Existing leaf: must be a file (or a symlink that resolves inside the project).
  let leaf: { dir: string; name: string } | undefined;
  let leafStat: ReturnType<typeof lstatSync> | undefined;
  try {
    leafStat = lstatSync(lexical);
  } catch (e) {
    if (errno(e) !== "ENOENT") throw ioFailure(e, rel);
  }
  if (leafStat?.isDirectory()) throw fail.invalid("path is a directory");
  if (leafStat?.isSymbolicLink()) {
    let target: string;
    try {
      target = realpathSync(lexical);
    } catch {
      throw fail.forbidden("path is a broken symlink");
    }
    if (!isInside(root, target)) throw fail.forbidden("path resolves outside the project (symlink)");
    if (hasGitSegment(root, target)) throw fail.forbidden("writing inside .git is not allowed");
    leaf = { dir: dirname(target), name: basename(target) };
  }

  // Parent directory: nearest existing ancestor must resolve inside the root.
  const parentLexical = dirname(lexical);
  let ancestor = parentLexical;
  let ancestorReal: string | undefined;
  for (;;) {
    try {
      ancestorReal = realpathSync(ancestor);
      break;
    } catch (e) {
      if (errno(e) !== "ENOENT") throw ioFailure(e, rel);
      if (ancestor === root || !isInside(root, ancestor)) break;
      ancestor = dirname(ancestor);
    }
  }
  if (ancestorReal === undefined || !isInside(root, ancestorReal)) {
    throw fail.forbidden("path resolves outside the project (symlink)");
  }
  if (ancestor !== parentLexical) {
    if (!createDirs) throw fail.notFound("parent folder does not exist (pass create_dirs: true)");
    try {
      mkdirSync(join(ancestorReal, relative(ancestor, parentLexical)), { recursive: true });
    } catch (e) {
      throw ioFailure(e, rel);
    }
  }

  const dirReal = leaf?.dir ?? realpathSync(parentLexical);
  if (!isInside(root, dirReal)) throw fail.forbidden("path resolves outside the project (symlink)");
  if (hasGitSegment(root, dirReal)) throw fail.forbidden("writing inside .git is not allowed");
  const name = leaf?.name ?? basename(lexical);
  return { dir: dirReal, name, rel: toRel(root, join(dirReal, name)) };
}
