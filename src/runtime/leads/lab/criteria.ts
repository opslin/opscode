// The rubric. Each criterion is pass/fail and is decided one of two ways:
//   rule  : a plain check on the case (country, buying power, freshness, a reachable address). No model, no cost, same answer every time.
//   judge : a question for a model about meaning (does this quote really show the need?). Each is asked on its own, with only the
//           facts that criterion needs, so one wrong answer cannot colour the others.
// A criterion can have both: the rule gives a sure "no" first (a web agency is a competitor), and only the unsure cases reach the model.
// A criterion whose input is missing (no need, no person) fails at once without asking anyone, as Harvey LAB fails a missing deliverable.

import { INJECTION } from "../scout/llm";
import type { IndustryPack } from "../ontology";
import { CORE_RUBRIC } from "../packs";
import type { LeadCase } from "./case";

export type Needs = "need" | "person" | "evidence" | "email";
export interface RuleResult { pass: boolean; reason: string }
export interface Criterion {
  id: string; text: string;
  /** Inputs that must exist; if one does not, the criterion fails without a rule or a model call. */
  requires: Needs[];
  /** A sure answer, or undefined to leave the decision to the judge (when there is one). */
  rule?: (c: LeadCase) => RuleResult | undefined;
  /** What the judge may see for this criterion, as plain text. Absent means the criterion is rule-only. */
  scope?: (c: LeadCase) => string;
  origin: "core" | "pack";
}

/** Company types that sell what the user sells. Also listed in the packs' own "exclude" notes. */
export const COMPETITOR_DEFINITIONS = ["software development agency", "web design agency", "digital marketing agency", "it consulting", "app development company", "software company"];
const BUYING_FUNCTION = /\b(operations|operating|marketing|digital|technology|it|sales|e-?commerce|growth|product)\b/i;

const quoteLines = (c: LeadCase, only: (e: LeadCase["evidence"][number]) => boolean): string =>
  c.evidence.filter(only).map((e) => `- "${e.quote}" (${e.url}, seen ${e.seen_at.slice(0, 10)}, found by ${e.extractor}${e.signal_type ? `, signal ${e.signal_type}` : ""})`).join("\n");
const org = (c: LeadCase): string => [
  `Name: ${c.organization.name}`, c.organization.domain ? `Website: ${c.organization.domain}` : "", c.organization.definition ? `Company type: ${c.organization.definition}` : "",
  c.organization.description ? `Description: ${c.organization.description}` : "", c.organization.hq_country ? `Headquarters country: ${c.organization.hq_country}` : "",
  `Locations on record: ${c.organization.locations}`, c.organization.tech.length ? `Tools seen on the site: ${c.organization.tech.join(", ")}` : "",
].filter(Boolean).join("\n");

const CORE: Record<string, Omit<Criterion, "id" | "text" | "origin">> = {
  "evidence-supports-need": {
    requires: ["need", "evidence"],
    rule: (c) => {
      const sup = c.evidence.filter((e) => e.supports_need);
      // Quotes that only give orders to a reader are not evidence of a need.
      if (sup.length > 0 && sup.every((e) => INJECTION.test(e.quote))) return { pass: false, reason: "every supporting quote is an instruction to the reader, not evidence" };
      return undefined;
    },
    scope: (c) => `Need being claimed: ${c.need!.label}. ${c.need!.description}\nQuestion: do the quotes below, taken from the company's own pages, show that this company has this need (does it by hand, lacks it, or is working on it)? A quote showing they already have a good solution is a NO.\nQuotes:\n${quoteLines(c, (e) => e.supports_need)}`,
  },
  "need-is-current": {
    requires: ["need"],
    rule: (c) => {
      const live = c.signals.filter((s) => s.live);
      if (c.need!.status === "solved") return { pass: false, reason: "the need is marked solved" };
      if (!c.need!.live || live.length === 0) return { pass: false, reason: "no supporting signal is recent enough to still count" };
      return { pass: true, reason: `${live.length} live signal${live.length === 1 ? "" : "s"}, newest from ${live.map((s) => s.date).sort().at(-1)!.slice(0, 10)}` };
    },
  },
  "person-can-buy": {
    requires: ["person"],
    rule: (c) => {
      const p = c.person!;
      if (p.buyer_power === "decides") return { pass: true, reason: `${p.title_raw}: decides` };
      if (p.buyer_power === "influences" && BUYING_FUNCTION.test(p.title_raw)) return { pass: true, reason: `${p.title_raw}: leads a function that buys this` };
      return { pass: false, reason: `${p.title_raw} does not decide or lead a buying function` };
    },
  },
  "geo-matches": {
    requires: [],
    rule: (c) => {
      const g = c.organization.hq_country;
      if (!g) return { pass: false, reason: "the company's headquarters country is not known" };
      return c.campaign.geos.includes(g.toUpperCase()) ? { pass: true, reason: `HQ ${g} is a target country` } : { pass: false, reason: `HQ ${g} is not in ${c.campaign.geos.join(", ")}` };
    },
  },
  "not-a-competitor": {
    requires: [],
    rule: (c) => {
      const d = c.organization.definition?.toLowerCase();
      return d && COMPETITOR_DEFINITIONS.includes(d) ? { pass: false, reason: `a ${d} sells what we sell` } : undefined;
    },
    scope: (c) => `The user sells: ${c.campaign.offering.name}. ${c.campaign.offering.summary}\nCompany:\n${org(c)}\nQuestion: does this company itself sell the same kind of service (building apps, websites or software for other businesses)? If yes, it is a competitor and the answer is NO. A restaurant, shop or clinic that merely uses software is not a competitor.`,
  },
  reachable: {
    requires: [],
    rule: (c) => (c.emails.length > 0 ? { pass: true, reason: `${c.emails.length} business email${c.emails.length === 1 ? "" : "s"} on record` } : { pass: false, reason: "no business email on record" }),
  },
};

/** The core rubric from the pack file's shared list, plus the pack's own criteria (all judged by a model). */
export function rubricFor(pack: IndustryPack | undefined): Criterion[] {
  const core: Criterion[] = CORE_RUBRIC.map((c) => ({ id: c.id, text: c.text, origin: "core" as const, ...CORE[c.id]! }));
  // "It is not a franchise outlet" is met unless something shows otherwise; "has more than one location" is met only if something shows it.
  const own: Criterion[] = (pack?.rubric ?? []).map((r) => {
    const negative = /\b(is not|are not|does not|do not|has no|have no|never)\b/i.test(r.text);
    const rule = negative ? "Answer YES unless the facts show the opposite; saying nothing is not a reason for NO." : "Answer YES only if the facts above show it; if they do not say, the answer is NO.";
    return {
      id: r.id, text: r.text, origin: "pack" as const, requires: [],
      scope: (c: LeadCase) => `Company:\n${org(c)}\nQuotes from its pages:\n${quoteLines(c, () => true) || "(none)"}\nCriterion: ${r.text}\nQuestion: is this criterion met? ${rule}`,
    };
  });
  return [...core, ...own];
}

/** Which inputs does this case have? */
export function has(c: LeadCase): Record<Needs, boolean> {
  return { need: !!c.need, person: !!c.person, evidence: c.evidence.some((e) => e.supports_need), email: c.emails.length > 0 };
}
