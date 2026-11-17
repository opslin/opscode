// Summarizes a real browser test run: node testing/summarize.mjs <run dir> [--full]
import { readFileSync } from "node:fs";

const dir = process.argv[2];
const r = JSON.parse(readFileSync(`${dir}/result.json`, "utf8"));
// API list prices per million tokens [input, cache read, output] (src/runtime/usage/pricing.ts).
const P = { fable: [10, 0.25, 50], opus: [4, 0.2, 20], sonnet: [2, 0.1, 10], haiku: [0.1, 0.01, 0.5] };
const m = r.usage?.model ?? r.steps[0]?.model ?? "";
const p = P[Object.keys(P).find((k) => m.includes(k))] ?? [0, 0, 0];
const t = r.steps.reduce((a, s) => ({ i: a.i + s.input, cr: a.cr + s.cache_read, cw: a.cw + s.cache_write, o: a.o + s.output }), { i: 0, cr: 0, cw: 0, o: 0 });
const cost = (t.i * p[0] + t.cr * p[1] + t.cw * p[0] * 1.25 + t.o * p[2]) / 1e6;
const browser = r.tools.filter((x) => /opscode_devices/.test(x.tool));
const errs = r.tools.filter((x) => x.status !== "done");
console.log(`${dir}: model ${m}, ${r.seconds}s, ${r.steps.length} requests, ${r.tools.length} tool calls (${browser.length} browser), ${errs.length} errors, orders ${r.orders.length} ${JSON.stringify(r.orders.map((o) => o.items))}`);
console.log(`  tokens: input ${t.i}, cache read ${t.cr}, cache write ${t.cw}, output ${t.o} -> ~$${cost.toFixed(3)} at API list price`);
const count = {};
for (const x of r.tools) { const k = x.tool.replace("mcp__opscode_devices__", ""); count[k] = (count[k] ?? 0) + 1; }
console.log("  calls:", JSON.stringify(count));
for (const e of errs) console.log(`  ERROR ${e.tool} | ${e.summary} | ${e.output.slice(0, 300).replace(/\n/g, " ")}`);
const bugs = { total: /3549|₹84|concaten|as a string|string/i, nan: /NaN/, image: /404|bag-missing|broken image/i, console: /qty|TypeError/ };
console.log("  bugs found:", Object.entries(bugs).map(([k, re]) => `${k}=${re.test(r.reply) ? "yes" : "NO"}`).join(", "));
if (process.argv.includes("--full")) {
  for (const x of r.tools) console.log(`  - ${x.tool.replace("mcp__opscode_devices__", "")} | ${x.summary} | ${x.status} | ${x.out_chars}c :: ${x.detail.slice(0, 220).replace(/\n/g, " ")}`);
  console.log(r.reply);
}
