// Evaluates one lead against a rubric, all-pass: the lead scores 1 only if every criterion passed (docs/lead-intelligence-design.md §1).
// Order per criterion: missing input -> fail without asking anyone; a rule with a sure answer -> that answer; otherwise the judge.
// An optional audit asks a second (stronger) judge about a deterministic sample of leads and records every disagreement; it never
// changes the verdict, it measures whether the cheap judge can be trusted.

import { createHash } from "node:crypto";
import type { LeadCase } from "./case";
import { has, rubricFor } from "./criteria";
import type { Criterion } from "./criteria";
import { askJudge } from "./judge";
import type { Judge } from "./judge";
import type { IndustryPack } from "../ontology";

export interface CriterionResult { id: string; text: string; how: "missing" | "rule" | "judge" | "not_run"; pass: boolean; reason: string; error?: boolean }
export interface Audit { judge: string; disagreements: { id: string; primary: boolean; audit: boolean; reason: string }[]; calls: number }
export interface LeadVerdict {
  lead_id: string;
  /** 1 or 0; null when the lead could not be fully judged (no judge was given for a model criterion). */
  score: 0 | 1 | null; complete: boolean;
  criteria: CriterionResult[]; judge_calls: number; judge_errors: number; audit?: Audit;
}
export interface EvalOpts {
  pack?: IndustryPack; rubric?: Criterion[]; judge?: Judge;
  audit?: { judge: Judge; rate: number; seed?: string };
  signalMs?: number;
}

/** Same lead and seed always give the same sample. */
export function inAuditSample(leadId: string, rate: number, seed = ""): boolean {
  if (rate <= 0) return false;
  if (rate >= 1) return true;
  const h = createHash("sha256").update(`${seed}|${leadId}`).digest();
  return h.readUInt32BE(0) / 0xffffffff < rate;
}

export async function evaluateLead(c: LeadCase, o: EvalOpts = {}): Promise<LeadVerdict> {
  const rubric = o.rubric ?? rubricFor(o.pack);
  const have = has(c);
  let calls = 0, errors = 0;
  const results: CriterionResult[] = await Promise.all(rubric.map(async (cr): Promise<CriterionResult> => {
    const base = { id: cr.id, text: cr.text };
    const miss = cr.requires.filter((n) => !have[n]);
    if (miss.length) return { ...base, how: "missing", pass: false, reason: `missing: ${miss.join(", ")}` };
    const r = cr.rule?.(c);
    if (r && (!r.pass || !cr.scope)) return { ...base, how: "rule", pass: r.pass, reason: r.reason };
    if (!cr.scope) return { ...base, how: "rule", pass: false, reason: "no rule and no judge for this criterion" };
    if (!o.judge) return { ...base, how: "not_run", pass: false, reason: "needs a model judge and none was given" };
    calls++;
    const v = await askJudge(o.judge, cr, cr.scope(c), o.signalMs);
    if (v.error) errors++;
    return { ...base, how: "judge", pass: v.pass, reason: v.reason, ...(v.error ? { error: true } : {}) };
  }));
  const complete = results.every((x) => x.how !== "not_run");
  const verdict: LeadVerdict = { lead_id: c.id, score: complete ? (results.every((x) => x.pass) ? 1 : 0) : (results.some((x) => !x.pass && x.how !== "not_run") ? 0 : null), complete, criteria: results, judge_calls: calls, judge_errors: errors };

  if (o.audit && o.judge && inAuditSample(c.id, o.audit.rate, o.audit.seed)) {
    const audit: Audit = { judge: o.audit.judge.id, disagreements: [], calls: 0 };
    await Promise.all(rubric.map(async (cr) => {
      const res = results.find((x) => x.id === cr.id)!;
      if (res.how !== "judge" || !cr.scope) return;
      audit.calls++;
      const v = await askJudge(o.audit!.judge, cr, cr.scope(c), o.signalMs);
      if (v.pass !== res.pass) audit.disagreements.push({ id: cr.id, primary: res.pass, audit: v.pass, reason: v.reason });
    }));
    verdict.audit = audit;
  }
  return verdict;
}
