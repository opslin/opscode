// Scoring a judge against the gold set, and the gate that decides whether a judge may be used. The number that matters most is the
// FALSE PASS: a lead the judge passed that a careful person would not, because that lead gets an email.

import { evaluateLead } from "./run";
import type { LeadVerdict } from "./run";
import type { Judge } from "./judge";
import { rubricFor } from "./criteria";
import type { GoldCase } from "./gold";
import type { IndustryPack } from "../ontology";

export interface CriterionScore { id: string; n: number; agree: number; agreement: number; false_pass: number; false_fail: number; precision: number | null; recall: number | null }
export interface Mismatch { case_id: string; criterion: string; expected: boolean; got: boolean; how: string; reason: string }
export interface GoldReport {
  judge: string; cases: number; judge_calls: number; judge_errors: number;
  criteria: CriterionScore[];
  lead: { sendable_expected: number; sendable_got: number; true_pass: number; false_pass: string[]; false_fail: string[]; precision: number | null; recall: number | null };
  mismatches: Mismatch[]; audit?: { sampled: number; disagreements: number };
}

const ratio = (a: number, b: number): number | null => (b === 0 ? null : Math.round((a / b) * 1000) / 1000);

export function scoreGold(judge: string, gold: GoldCase[], verdicts: LeadVerdict[]): GoldReport {
  const byId = new Map(verdicts.map((v) => [v.lead_id, v]));
  const crit = new Map<string, { n: number; agree: number; fp: number; fn: number; tp: number }>();
  const mismatches: Mismatch[] = [];
  const falsePass: string[] = [], falseFail: string[] = [];
  let sendE = 0, sendG = 0, truePass = 0, calls = 0, errors = 0, sampled = 0, dis = 0;
  for (const g of gold) {
    const v = byId.get(g.case.id)!;
    calls += v.judge_calls; errors += v.judge_errors;
    if (v.audit) { sampled++; dis += v.audit.disagreements.length; }
    for (const r of v.criteria) {
      const exp = g.expected[r.id];
      if (exp === undefined) continue;
      const s = crit.get(r.id) ?? { n: 0, agree: 0, fp: 0, fn: 0, tp: 0 };
      s.n++;
      if (r.pass === exp) s.agree++;
      if (r.pass && exp) s.tp++;
      if (r.pass && !exp) s.fp++;
      if (!r.pass && exp) s.fn++;
      crit.set(r.id, s);
      if (r.pass !== exp) mismatches.push({ case_id: g.id, criterion: r.id, expected: exp, got: r.pass, how: r.how, reason: r.reason });
    }
    const expectSend = Object.values(g.expected).every(Boolean), gotSend = v.score === 1;
    if (expectSend) sendE++;
    if (gotSend) sendG++;
    if (expectSend && gotSend) truePass++;
    if (gotSend && !expectSend) falsePass.push(g.id);
    if (!gotSend && expectSend) falseFail.push(g.id);
  }
  return {
    judge, cases: gold.length, judge_calls: calls, judge_errors: errors,
    criteria: [...crit.entries()].map(([id, s]) => ({ id, n: s.n, agree: s.agree, agreement: ratio(s.agree, s.n) ?? 0, false_pass: s.fp, false_fail: s.fn, precision: ratio(s.tp, s.tp + s.fp), recall: ratio(s.tp, s.tp + s.fn) })),
    lead: { sendable_expected: sendE, sendable_got: sendG, true_pass: truePass, false_pass: falsePass, false_fail: falseFail, precision: ratio(truePass, sendG), recall: ratio(truePass, sendE) },
    mismatches, ...(sampled ? { audit: { sampled, disagreements: dis } } : {}),
  };
}

export interface GateRules { minLeadPrecision?: number; minCriterionAgreement?: number; maxJudgeErrors?: number }
/** May this judge be used on real leads? Strict about false passes, lenient about being too careful. */
export function gate(r: GoldReport, rules: GateRules = {}): { passed: boolean; failures: string[] } {
  const failures: string[] = [];
  const minP = rules.minLeadPrecision ?? 1, minA = rules.minCriterionAgreement ?? 0.85, maxE = rules.maxJudgeErrors ?? 0;
  if (r.lead.false_pass.length > 0 && (r.lead.precision ?? 0) < minP) failures.push(`${r.lead.false_pass.length} lead(s) passed that should not have: ${r.lead.false_pass.join(", ")}`);
  for (const c of r.criteria) if (c.agreement < minA) failures.push(`${c.id}: agrees with the gold labels on ${Math.round(c.agreement * 100)}% (needs ${Math.round(minA * 100)}%)`);
  if (r.judge_errors > maxE) failures.push(`${r.judge_errors} judge error(s) (allowed ${maxE})`);
  return { passed: failures.length === 0, failures };
}

export async function evaluateGold(judge: Judge, gold: GoldCase[], opts: { pack?: IndustryPack; audit?: { judge: Judge; rate: number; seed?: string }; concurrency?: number; signalMs?: number } = {}): Promise<{ report: GoldReport; verdicts: LeadVerdict[] }> {
  const rubric = rubricFor(opts.pack);
  const verdicts: LeadVerdict[] = new Array(gold.length);
  let next = 0;
  const worker = async (): Promise<void> => { for (;;) { const i = next++; if (i >= gold.length) return; verdicts[i] = await evaluateLead(gold[i]!.case, { rubric, judge, ...(opts.audit ? { audit: opts.audit } : {}), ...(opts.signalMs ? { signalMs: opts.signalMs } : {}) }); } };
  await Promise.all(Array.from({ length: Math.min(opts.concurrency ?? 4, gold.length) }, worker));
  return { report: scoreGold(judge.id, gold, verdicts), verdicts };
}

export function renderMarkdown(r: GoldReport, g?: { passed: boolean; failures: string[] }): string {
  const pct = (x: number | null): string => (x === null ? "n/a" : `${Math.round(x * 100)}%`);
  const lines = [
    `# Lead LAB report: ${r.judge}`, "",
    `${r.cases} gold leads, ${r.judge_calls} judge calls, ${r.judge_errors} judge errors.`, "",
    `**Lead level:** of ${r.lead.sendable_expected} leads a person would send, the judge passed ${r.lead.true_pass} (recall ${pct(r.lead.recall)}); of ${r.lead.sendable_got} it passed, ${r.lead.true_pass} were right (precision ${pct(r.lead.precision)}).`,
    r.lead.false_pass.length ? `**False passes (would be emailed, should not be):** ${r.lead.false_pass.join(", ")}` : "**False passes:** none",
    r.lead.false_fail.length ? `**False fails (good leads turned away):** ${r.lead.false_fail.join(", ")}` : "**False fails:** none", "",
    "| Criterion | Agreement | False pass | False fail |", "|---|---|---|---|",
    ...r.criteria.map((c) => `| ${c.id} | ${pct(c.agreement)} (${c.agree}/${c.n}) | ${c.false_pass} | ${c.false_fail} |`), "",
  ];
  if (r.mismatches.length) lines.push("## Disagreements with the gold labels", "", ...r.mismatches.map((m) => `- **${m.case_id}** / ${m.criterion}: expected ${m.expected ? "pass" : "fail"}, got ${m.got ? "pass" : "fail"} (${m.how}). ${m.reason}`), "");
  if (r.audit) lines.push(`Audit: ${r.audit.disagreements} disagreement(s) between the two judges over ${r.audit.sampled} sampled lead(s).`, "");
  if (g) lines.push(g.passed ? "**Gate: passed**" : `**Gate: failed**\n${g.failures.map((f) => `- ${f}`).join("\n")}`);
  return lines.join("\n");
}
