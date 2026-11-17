// Search over an app's features and files, and "context for a query": the files a
// worker should start from. Deterministic scoring, no model.

import { synonymsOf, tokens } from "./names";
import type { Feature, Model } from "./model";

export interface Hit { app_id: string; app: string; feature: string; name: string; score: number; layers: { layer: string; package: string; files: number }[]; why: string[]; routes: number; tables: number }

const W = { name: 6, route: 3, table: 3, symbol: 2, path: 1, pkg: 0.4 };

interface Doc { f: Feature; fields: Map<string, { w: number; ev: string }[]> }

function docOf(f: Feature): Doc {
  const fields = new Map<string, { w: number; ev: string }[]>();
  const add = (text: string, w: number, ev: string): void => { for (const t of new Set(tokens(text))) (fields.get(t) ?? fields.set(t, []).get(t)!).push({ w, ev }); };
  add(f.name, W.name, "name");
  for (const r of f.routes.slice(0, 40)) add(r.path, W.route, `route ${r.method} ${r.path}`);
  for (const t of f.tables) add(t.name, W.table, `table ${t.name}`);
  for (const s of f.symbols) add(s, W.symbol, `symbol ${s}`);
  for (const l of f.layers) { add(l.package, W.pkg, `package ${l.package}`); for (const p of l.files.slice(0, 40)) add(p, W.path, `file ${p}`); }
  return { f, fields };
}

export interface Corpus { app_id: string; app: string; model: Model; docs: Doc[] }
export const corpusOf = (app_id: string, app: string, model: Model): Corpus => ({ app_id, app, model, docs: model.features.map((f) => docOf(f)) });

export function search(corpora: Corpus[], query: string, limit = 12): Hit[] {
  const base = [...new Set(tokens(query))];
  if (!base.length) return [];
  const terms: { t: string; w: number }[] = [];
  for (const t of base) { terms.push({ t, w: 1 }); for (const s of synonymsOf(t)) if (!base.includes(s)) terms.push({ t: s, w: 0.55 }); }
  const all = corpora.flatMap((c) => c.docs.map((d) => ({ c, d })));
  const N = all.length || 1;
  const df = new Map<string, number>();
  for (const { d } of all) for (const { t } of terms) if (d.fields.has(t)) df.set(t, (df.get(t) ?? 0) + 1);
  const hits: Hit[] = [];
  for (const { c, d } of all) {
    let score = 0;
    const why: string[] = [];
    for (const { t, w } of terms) {
      const ev = d.fields.get(t);
      if (!ev) continue;
      const idf = Math.log(1 + (N - (df.get(t) ?? 0) + 0.5) / ((df.get(t) ?? 0) + 0.5));
      const best = Math.max(...ev.map((e) => e.w));
      score += w * idf * (best + Math.min(2, ev.length - 1) * 0.3);
      const top = ev.sort((a, b) => b.w - a.w)[0];
      if (!why.includes(top.ev) && why.length < 4) why.push(top.ev);
    }
    // Every query word found (directly) is worth a bonus: "loyalty points" should beat a feature that only has one.
    const direct = base.filter((t) => d.fields.has(t)).length;
    if (direct === base.length && base.length > 1) score *= 1.4;
    if (score > 0) hits.push({ app_id: c.app_id, app: c.app, feature: d.f.id, name: d.f.name, score: Math.round(score * 100) / 100, layers: d.f.layers.map((l) => ({ layer: l.layer, package: l.package, files: l.file_count })), why, routes: d.f.routes.length, tables: d.f.tables.length });
  }
  return hits.sort((a, b) => b.score - a.score).slice(0, limit);
}

const ENTRY = /(controller|service|route|handler|repository|screen|page|index|model|entity|schema|provider|bloc|cubit|main)/i;

export interface ContextFile { path: string; why: string; lines: number; score: number }
/** The files to start from for a query: the best features' files first, then their graph neighbours. */
export function context(c: Corpus, query: string, maxFiles = 15): { features: string[]; files: ContextFile[] } {
  const top = search([c], query, 3).filter((h) => h.score > 0);
  const m = c.model;
  const qt = new Set(tokens(query));
  const scored = new Map<string, ContextFile>();
  const put = (path: string, why: string, score: number): void => {
    const f = m.files.get(path);
    if (!f) return;
    const prev = scored.get(path);
    if (!prev || prev.score < score) scored.set(path, { path, why, lines: f.f.n, score });
  };
  for (const [rank, h] of top.entries()) {
    const feat = m.features.find((x) => x.id === h.feature);
    if (!feat) continue;
    for (const l of feat.layers) for (const p of l.files) {
      const f = m.files.get(p);
      let s = 10 - rank * 2;
      if (ENTRY.test(p.split("/").pop() ?? "")) s += 2;
      for (const d of f?.f.d ?? []) if (tokens(d).some((t) => qt.has(t))) { s += 1.5; break; }
      if (/\.(test|spec)\.|_test\./.test(p)) s -= 4;
      put(p, `${feat.name} (${l.layer}, ${l.package})`, s);
    }
  }
  // One hop in the import graph: what the best files use, and what uses them.
  const seeds = [...scored.values()].sort((a, b) => b.score - a.score).slice(0, 8);
  for (const s of seeds) {
    for (const n of m.out.get(s.path) ?? []) put(n, `used by ${s.path.split("/").pop()}`, s.score * 0.45);
    for (const n of (m.rev.get(s.path) ?? []).slice(0, 4)) put(n, `uses ${s.path.split("/").pop()}`, s.score * 0.35);
  }
  const files = [...scored.values()].sort((a, b) => b.score - a.score).slice(0, maxFiles);
  return { features: top.map((h) => h.name), files };
}
