// Lead LAB: the rubric, the judge, the all-pass evaluator and the gold set (docs/lead-intelligence-design.md §1).
export { buildCase } from "./case";
export type { LeadCase, CaseRequest } from "./case";
export { rubricFor, COMPETITOR_DEFINITIONS } from "./criteria";
export type { Criterion } from "./criteria";
export { modelJudge, parseVerdict, buildJudgePrompt } from "./judge";
export type { Judge, Verdict } from "./judge";
export { evaluateLead, inAuditSample } from "./run";
export type { LeadVerdict, EvalOpts } from "./run";
export { GOLD } from "./gold";
export type { GoldCase } from "./gold";
export { evaluateGold, scoreGold, gate, renderMarkdown } from "./score";
export type { GoldReport, GateRules } from "./score";
