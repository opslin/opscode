// File links in chat replies (a PDF, an Excel sheet or an APK an engine made): open them, show them in
// Finder, or look them up. Only the person's own click reaches here, never a model. Programs, scripts,
// installers and anything executable are never launched from a link: "open" shows them in Finder instead.

import { lstatSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { extname, isAbsolute, normalize } from "node:path";

/** Things macOS would run (or install) when opened. */
const RUNNABLE = new Set([
  ".app", ".command", ".sh", ".bash", ".zsh", ".csh", ".ksh", ".fish", ".tool", ".terminal", ".pkg", ".mpkg", ".dmg",
  ".workflow", ".action", ".scpt", ".scptd", ".applescript", ".osascript", ".jar", ".jnlp", ".py", ".pyw", ".pl", ".rb",
  ".lua", ".php", ".fileloc", ".webloc", ".inetloc", ".url", ".desktop", ".exe", ".bat", ".cmd", ".msi", ".vbs", ".ps1",
  ".prefpane", ".kext", ".plugin", ".bundle", ".framework", ".dylib", ".so", ".car", ".mobileconfig", ".shortcut",
  // Windows: programs, scripts, installers, shortcuts and anything the shell would run when opened.
  ".com", ".scr", ".pif", ".lnk", ".msp", ".msix", ".appx", ".appxbundle", ".vbe", ".wsf", ".wsh", ".js", ".jse", ".hta", ".reg", ".cpl", ".ps1xml", ".psm1", ".gadget", ".application", ".settingcontent-ms", ".library-ms", ".chm", ".iso", ".dll",
]);

export interface FileInfo { exists: boolean; dir: boolean; runnable: boolean; path: string }

/** "~/x", "/x" and (on Windows) "C:\\x" only; ":12" line suffixes and "#L12" anchors are dropped. Undefined for anything else. */
export function cleanPath(raw: unknown): string | undefined {
  if (typeof raw !== "string" || !raw || raw.length > 4096 || raw.includes("\0")) return undefined;
  let p = raw.trim().replace(/^file:\/\//, "");
  try { if (/%[0-9a-f]{2}/i.test(p)) p = decodeURIComponent(p); } catch { /* keep as is */ }
  p = p.replace(/#L?\d+(-L?\d+)?$/, "");
  if (p.startsWith("~/") || p.startsWith("~\\")) p = homedir() + p.slice(1);
  if (!isAbsolute(p)) return undefined;
  const noLine = p.replace(/(?<!^[A-Za-z]):\d+(:\d+)?$/, ""); // (not the "C:" of a drive)
  try { lstatSync(noLine); p = noLine; } catch { /* the colon may be part of the name */ }
  return normalize(p);
}

export function fileInfo(path: string): FileInfo {
  let exists = false;
  let dir = false;
  let exec = false;
  try { const s = statSync(path); exists = true; dir = s.isDirectory(); exec = s.isFile() && (s.mode & 0o111) !== 0; } catch { /* missing */ }
  const runnable = exec || RUNNABLE.has(extname(path).toLowerCase());
  return { exists, dir, runnable, path };
}

/** op: "info" | "open" (default app; folders in Finder; runnable things only revealed) | "reveal". */
export async function fileAction(op: unknown, raw: unknown): Promise<FileInfo & { ok: boolean; revealed?: boolean; error?: string }> {
  const path = cleanPath(raw);
  if (!path) return { ok: false, exists: false, dir: false, runnable: false, path: String(raw ?? ""), error: "Not a file path" };
  const info = fileInfo(path);
  if (op === "info") return { ok: true, ...info };
  if (!info.exists) return { ok: false, ...info, error: "That file is not there any more" };
  // Loaded here, so the path rules above can be tested without Electron.
  const { shell } = await import("electron");
  if (op === "reveal" || (op === "open" && info.runnable)) {
    shell.showItemInFolder(path);
    return { ok: true, ...info, revealed: true };
  }
  if (op === "open") {
    const err = await shell.openPath(path);
    return err ? { ok: false, ...info, error: err } : { ok: true, ...info };
  }
  return { ok: false, ...info, error: "Unknown action" };
}
