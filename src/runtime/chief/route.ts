// Limits-aware engine choice for a Conductor's workers (docs/orchestration-architecture.md §3).
// Pure functions: the plan limits Opscode already reads for free go in, a decision comes
// out. The manager calls route() once per spec, with bands decided once per batch.
//
//   normal  (< 70%)   the mode table as is
//   soft    (70-90%)  build chores and tier-fast work move to Codex
//   hard    (>= 90%)  those still move; everything else that needs Claude parks until the reset
//
// Only a fresh "ok" reading may raise the band: missing, failed or stale data counts as
// normal (and the caller asks for a refresh), so an API-key sign-in is never parked.

import type { EngineLimits } from "../engines/limits";
import type { StartSpec } from "./store";

export type Band = "normal" | "soft" | "hard";
export const ENTER = { soft: 70, hard: 90 } as const;
export const LEAVE = { soft: 65, hard: 85 } as const;
const FRESH_MS = 5 * 60_000;

export interface Usage { pct: number; resets_at?: string; label: string; fresh: boolean }

/** The number that decides a band: the higher of the 5-hour and weekly windows. Model-scoped and monthly windows never count here. */
export function usageOf(l: EngineLimits | undefined, now = Date.now()): Usage | null {
  if (!l || l.state !== "ok") return null;
  const main = l.windows.filter((w) => (l.engine === "claude-code" ? w.id === "five_hour" || w.id === "seven_day" : w.id === "primary" || w.id === "secondary"));
  if (!main.length) return null;
  const top = main.reduce((a, b) => (b.used_percent > a.used_percent ? b : a));
  // A limit that already stopped work counts as full, whatever the last number said.
  const pct = l.reached ? 100 : top.used_percent;
  return { pct, label: top.label, ...(top.resets_at ? { resets_at: top.resets_at } : {}), fresh: now - Date.parse(l.checked_at) <= FRESH_MS };
}

/** The band for a reading, with hysteresis: rising needs ENTER, falling needs LEAVE. No fresh reading: normal. */
export function bandOf(u: Usage | null, prev: Band = "normal"): Band {
  if (!u || !u.fresh) return "normal";
  const p = u.pct;
  if (p >= ENTER.hard || (prev === "hard" && p >= LEAVE.hard)) return "hard";
  if (p >= ENTER.soft || ((prev === "soft" || prev === "hard") && p >= LEAVE.soft)) return "soft";
  return "normal";
}

/** True when the weekly Opus window is nearly full: Opus picks fall back to the mode's frontier tier. */
export function opusBlocked(l: EngineLimits | undefined, now = Date.now()): boolean {
  if (!l || l.state !== "ok" || now - Date.parse(l.checked_at) > FRESH_MS) return false;
  return l.windows.some((w) => w.id === "seven_day_opus" && w.used_percent >= ENTER.hard);
}

export interface Decision {
  action: "launch" | "park";
  engine: StartSpec["engine"];
  /** Set when the runtime moved the task off the engine the Conductor picked. */
  rerouted_from?: StartSpec["engine"];
  /** For a park: when to look again (the engine's reset time, if known). */
  until?: string;
  why?: string;
}

/** Work that may run on Codex instead of Claude: build chores and tier-fast building. Reviews and real logic never move. */
export const movable = (s: StartSpec): boolean => s.role === "build" && (s.tier === "fast" || s.kind === "chore");

/** Where one spec runs, given both engines' bands. */
export function route(s: StartSpec, claude: { band: Band; usage: Usage | null }, codex: { band: Band; usage: Usage | null }): Decision {
  if (s.engine === "api") return { action: "launch", engine: "api" };
  const parkOn = (e: "claude-code" | "codex", u: Usage | null): Decision => ({
    action: "park", engine: e, ...(u?.resets_at ? { until: u.resets_at } : {}),
    why: `${e === "claude-code" ? "Claude" : "Codex"} is at ${Math.round(u?.pct ?? 100)}% of its ${u?.label ?? "limit"}${u?.resets_at ? `; it starts by itself after the reset at ${hhmm(u.resets_at)}` : "; it starts by itself once there is room again"}.`,
  });
  if (s.engine === "codex") return codex.band === "hard" ? parkOn("codex", codex.usage) : { action: "launch", engine: "codex" };
  // claude-code from here on.
  if (claude.band === "normal") return { action: "launch", engine: "claude-code" };
  const canMove = !s.pin_engine && movable(s) && codex.band !== "hard";
  if (canMove) return { action: "launch", engine: "codex", rerouted_from: "claude-code", why: `Claude is at ${Math.round(claude.usage?.pct ?? 0)}%, so this chore runs on Codex.` };
  if (claude.band === "soft") return { action: "launch", engine: "claude-code" };
  return parkOn("claude-code", claude.usage);
}

/** The line the Conductor reads when Claude is getting full. Empty when all is normal. */
export function limitsLine(claude: { band: Band; usage: Usage | null }, codex: { band: Band; usage: Usage | null }): string {
  if (claude.band === "normal" && codex.band !== "hard") return "";
  const c = claude.usage;
  const parts: string[] = ["## Plan limits right now"];
  if (claude.band !== "normal" && c) parts.push(`Claude is at ${Math.round(c.pct)}% of its ${c.label}${c.resets_at ? `, resets ${hhmm(c.resets_at)}` : ""}.`);
  if (claude.band === "soft") parts.push("Prefer codex for UI, assets and mechanical work. Build chores and tier fast move to Codex by themselves. Keep logic, payments, data models and reviews on Claude.");
  if (claude.band === "hard") parts.push("New Claude chats for logic and reviews park and start by themselves after the reset; chores and tier fast run on Codex now. Tell the person in one line what waits, and until when. Do not split logic work into chores to get around this.");
  if (codex.band === "hard" && codex.usage) parts.push(`Codex is at ${Math.round(codex.usage.pct)}% too${codex.usage.resets_at ? `, resets ${hhmm(codex.usage.resets_at)}` : ""}: Codex work parks as well.`);
  return parts.join("\n");
}

function hhmm(iso: string): string {
  const d = new Date(iso);
  const sameDay = d.toDateString() === new Date().toDateString();
  const t = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  return sameDay ? t : `${d.toLocaleDateString("en-GB", { weekday: "short" })} ${t}`;
}
