// Vendors assistant-ui elements (MIT) into src/islands/aui: fetches each registry item
// and its registry dependencies, writes their files, and lists the npm packages they need.
// Usage: node scripts/tools/aui-fetch.mjs [--dry] name [name...]   (names like subagent-list)
import { mkdirSync, writeFileSync, existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
const args = process.argv.slice(2);
const dry = args.includes("--dry");
const names = args.filter((a) => !a.startsWith("--"));
const OUT = join(process.cwd(), "src/islands/aui");
const seen = new Map();
const npm = new Set();
const url = (n) => (n.startsWith("http") ? n : /^[a-z0-9-]+$/.test(n) && !n.startsWith("elements-") ? `https://ui.shadcn.com/r/styles/new-york-v4/${n}.json` : `https://r.assistant-ui.com/${n.startsWith("elements-") ? n : `elements-${n}`}.json`);
async function get(n) {
  const u = url(n);
  if (seen.has(u)) return;
  seen.set(u, null);
  const r = await fetch(u);
  if (!r.ok) throw new Error(`${u}: ${r.status}`);
  const item = await r.json();
  seen.set(u, item);
  for (const d of item.dependencies ?? []) npm.add(d);
  for (const d of item.registryDependencies ?? []) await get(d);
}
for (const n of names) await get(n.startsWith("elements-") ? n : `elements-${n}`);
const files = [];
for (const [u, item] of seen) for (const f of item?.files ?? []) {
  const rel = (f.target || f.path).replace(/^(registry\/[^/]+\/|src\/)/, "");
  files.push({ from: u, rel, type: f.type, bytes: f.content?.length ?? 0 });
  if (!dry && f.content) {
    const dst = join(OUT, rel);
    // Files Opscode changed (marked "Opscode:") are never overwritten; merge upstream changes by hand.
    if (existsSync(dst) && readFileSync(dst, "utf8").includes("Opscode:")) { console.error(`kept (Opscode changes): ${rel}`); continue; }
    mkdirSync(dirname(dst), { recursive: true }); writeFileSync(dst, f.content);
  }
}
console.log(JSON.stringify({ items: [...seen.keys()].map((u) => u.replace(/^https:\/\//, "")), files, npm: [...npm].sort() }, null, 1));
