// Hand-off slice H4: when Claude Code or Codex runs out of its plan limit, a chat continues on the other
// one (opt-in: Settings -> Models & keys -> "When one runs out, continue in the other").
//   before a turn - the chat's engine is at its limit (a fresh reading): the turn starts on the other engine.
//   during a turn - it fails with a limit error: the chat moves to the other engine and Opscode sends
//                   "Continue the task from where it stopped." (the H3 hand-off carries the work over).
// Only Normal chats (a Chief routes its own workers by limits, chief/route.ts). At most one automatic
// switch per message; never to an engine that is also at its limit or not installed.

import type { ChatMeta } from "../shared/protocol";
import type { EngineLimits } from "./engines/limits";
import { usageOf } from "./chief/route";
import type { LedgerView } from "./ledger";

export type SwitchEngine = "claude-code" | "codex";

/** Plan-limit errors from Claude Code and Codex (not ordinary failures). */
const LIMIT_RE = /usage limit|hit your (?:usage )?limit|limit reached|limit has been reached|out of (?:extra )?(?:usage|credits)|credits? (?:are |is |have been )?(?:depleted|exhausted)|(?:5-hour|five[- ]hour|weekly|session) limit|usage_limit|rate[ _-]?limit(?:ed| reached| exceeded| error)|quota exceeded|too many requests/i;
export const isLimitError = (msg: string | undefined): boolean => !!msg && LIMIT_RE.test(msg);

export const otherEngine = (e: SwitchEngine): SwitchEngine => (e === "claude-code" ? "codex" : "claude-code");
export const engineLabel = (e: string): string => (e === "codex" ? "Codex" : e === "claude-code" ? "Claude Code" : e);

/** At its limit right now: a fresh reading at 100%, or the engine said a limit stopped work. */
export function exhausted(l: EngineLimits | undefined, now = Date.now()): boolean {
  const u = usageOf(l, now);
  return !!u && u.fresh && u.pct >= 100;
}

/** Chats this applies to: Normal chats on Claude Code or Codex. */
export function eligible(c: ChatMeta | undefined): c is ChatMeta & { engine: SwitchEngine } {
  return !!c && (c.engine === "claude-code" || c.engine === "codex") && !c.chief && !c.origin;
}

/** The model this chat last used on that engine (so coming back keeps the person's choice); none = the engine's default. */
export function lastModelOn(l: LedgerView | undefined, engine: SwitchEngine): string | undefined {
  return l?.turns.filter((t) => t.engine === engine && t.model).at(-1)?.model;
}

export interface SwitchDeps {
  enabled(): boolean;
  installed(e: SwitchEngine): boolean;
  limits(): EngineLimits[];
  /** The numbers for one account (the chat's own, or the one new chats use on the other engine). */
  limitsFor?(e: SwitchEngine, accountId?: string): EngineLimits | undefined;
  /** The account a chat runs on for an engine. */
  accountOf?(e: SwitchEngine, chat?: ChatMeta): string;
}

export class AutoSwitch {
  constructor(private readonly d: SwitchDeps) {}

  private limitsOf(e: SwitchEngine, chat?: ChatMeta): EngineLimits | undefined {
    if (this.d.limitsFor && this.d.accountOf) return this.d.limitsFor(e, this.d.accountOf(e, chat));
    return this.d.limits().find((l) => l.engine === e);
  }

  /** The other engine, if a switch away from `from` is possible now. */
  private target(from: SwitchEngine, c: ChatMeta): SwitchEngine | null {
    const to = otherEngine(from);
    // The other engine is judged on the account this chat would use there (its own if it ran there before, else the active one).
    return this.d.installed(to) && !exhausted(this.limitsOf(to, c)) ? to : null;
  }

  /** Before a person's turn: switch when the chat's engine is already at its limit. */
  beforeTurn(c: ChatMeta | undefined): SwitchEngine | null {
    if (!this.d.enabled() || !eligible(c) || !exhausted(this.limitsOf(c.engine, c))) return null;
    return this.target(c.engine, c);
  }

  /** After a failed turn: switch when it failed on a plan limit (and it was not already an automatic continue). */
  afterFailure(c: ChatMeta | undefined, error: string | undefined, wasAuto: boolean): SwitchEngine | null {
    if (wasAuto || !this.d.enabled() || !eligible(c)) return null;
    if (!isLimitError(error) && !exhausted(this.limitsOf(c.engine, c))) return null;
    return this.target(c.engine, c);
  }
}
