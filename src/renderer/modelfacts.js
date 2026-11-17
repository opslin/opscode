// What we know about a model at each effort: [intelligence score, US$ per task].
// Public benchmark figures (Artificial Analysis, Oct 20 2026). A model that is
// missing here shows "Not measured yet" and no bars or price.
//
// Bars: how many of 20/30/40/48/55 the score reaches (0-5).
// Price: $ plus one more for each of $0.10/$0.50/$2 a task it reaches ($-$$$$).

const FACTS = {
  "claude-opus-5-5": { runs: { low: [42, 0.55], medium: [51, 1.34], high: [54, 1.82], xhigh: [56, 3.46], max: [58, 5.98] }, context: 1_000_000 },
  "claude-sonnet-5-5": { runs: { low: [36, 0.35], medium: [41, 0.48], high: [47, 0.88], xhigh: [52, 2.01], max: [56, 5.46] }, context: 1_000_000 },
  "claude-haiku-5-5": { runs: { low: [29, 0.02], medium: [34, 0.05], high: [38, 0.08], xhigh: [41, 0.12], max: [43, 0.21] }, context: 1_000_000 },
  "claude-fable-5-1": { runs: { low: [47, 2.37], medium: [49, 2.98], high: [51, 3.91], xhigh: [53, 5.98], max: [53, 7.63] }, context: 1_000_000 },
  "gpt-6-1-sol": { runs: { low: [42, 0.13], medium: [48, 0.21], high: [50, 0.32], xhigh: [51, 0.39], max: [52, 0.72] }, context: 922_000 },
  "gpt-6-astra": { runs: { low: [46, 0.82], medium: [50, 1.54], high: [51, 1.73], xhigh: [52, 2.31], max: [53, 3.26] }, context: 922_000 },
  "gpt-6-luna": { runs: { none: [18, 0.01], low: [22, 0.0045], medium: [30, 0.02], high: [33, 0.03], xhigh: [35, 0.04], max: [38, 0.07] }, context: 922_000 },
  "gpt-5-6-terra": { runs: { none: [21, 0.14], low: [27, 0.14], medium: [30, 0.18], high: [34, 0.34], xhigh: [38, 0.63], max: [42, 1.4] }, context: 922_000 },
};
// Aliases Claude Code accepts.
const ALIAS = { opus: "claude-opus-5-5", sonnet: "claude-sonnet-5-5", haiku: "claude-haiku-5-5" };

export const FACTS_SOURCE = "Artificial Analysis, Oct 20";
const SMART = [20, 30, 40, 48, 55];
const PRICE = [0.1, 0.5, 2];

const key = (id) => {
  const k = String(id ?? "").toLowerCase().replace(/^(anthropic|openai)\//, "");
  return ALIAS[k] ?? k;
};
export const factsOf = (id) => FACTS[key(id)] ?? null;
/** [score, cost] at this effort (or the model's only run). */
export function runOf(id, effort) {
  const f = factsOf(id);
  if (!f) return null;
  return f.runs[effort ?? ""] ?? f.runs.medium ?? f.runs[""] ?? Object.values(f.runs)[0] ?? null;
}
export const barsFor = (score) => SMART.filter((t) => score >= t).length;
export const priceFor = (cost) => 1 + PRICE.filter((t) => cost >= t).length;
export const money = (c) => (c >= 1 ? `$${Number(c.toFixed(2))}` : `$${Number(c.toPrecision(2))}`);
export const contextOf = (id) => factsOf(id)?.context ?? null;

// Scatter geometry (216 x 120): x = log cost from $0.01 to $10, y = score 5..62.
export const PLOT = { w: 216, h: 120 };
const LO = 0.01;
const HI = 10;
export const px = (cost) => 10 + Math.min(1, Math.max(0, Math.log(cost / LO) / Math.log(HI / LO))) * 196;
export const py = (score) => 10 + (1 - (Math.min(62, Math.max(5, score)) - 5) / 57) * 100;
