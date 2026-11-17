// Builds the app's model from its per-file facts: packages and their stacks, the
// import graph, and features found by naming convention. Pure functions: no disk.

import { normalize, words } from "./names";
import type { FileFact, Manifest } from "./scan";

export type Layer = "backend" | "app" | "web" | "db" | "other";
export interface Pkg { root: string; name: string; kind: Manifest["kind"]; stack: string[]; layer: Layer; files: number }
export interface FeatureLayer { package: string; layer: Layer; dir: string; files: string[]; file_count: number; reason: string }
export interface Feature {
  id: string; name: string; layers: FeatureLayer[];
  routes: { method: string; path: string; file: string; reason: string }[];
  tables: { name: string; file: string; reason: string }[];
  symbols: string[]; file_count: number;
}
export interface Coverage { relative: number; resolved: number; unresolved: number; unresolved_sample: string[]; external: number }
export interface Model {
  files: Map<string, FileFact>;
  packages: Pkg[];
  features: Feature[];
  out: Map<string, string[]>;
  rev: Map<string, string[]>;
  coverage: Coverage;
  orphans: { routes: number; tables: number };
  fileFeature: Map<string, string>;
}

const STACK_TAGS: [string, string][] = [
  ["@nestjs/core", "NestJS"], ["fastify", "Fastify"], ["express", "Express"], ["koa", "Koa"], ["hono", "Hono"], ["next", "Next.js"], ["react-native", "React Native"], ["expo", "Expo"], ["react", "React"], ["vue", "Vue"], ["svelte", "Svelte"], ["vite", "Vite"], ["electron", "Electron"],
  ["drizzle-orm", "Drizzle"], ["@prisma/client", "Prisma"], ["typeorm", "TypeORM"], ["knex", "Knex"], ["sequelize", "Sequelize"], ["mongoose", "Mongoose"], ["pg", "Postgres"], ["mysql2", "MySQL"], ["firebase", "Firebase"], ["firebase-admin", "Firebase Admin"], ["@supabase/supabase-js", "Supabase"], ["bullmq", "BullMQ"], ["redis", "Redis"], ["ioredis", "Redis"], ["tailwindcss", "Tailwind"], ["zod", "Zod"], ["stripe", "Stripe"], ["razorpay", "Razorpay"],
  ["flutter", "Flutter"], ["flutter_riverpod", "Riverpod"], ["riverpod", "Riverpod"], ["flutter_bloc", "Bloc"], ["provider", "Provider"], ["get", "GetX"], ["go_router", "go_router"], ["dio", "Dio"], ["firebase_core", "Firebase"], ["drift", "Drift"], ["hive", "Hive"],
  ["github.com/gin-gonic/gin", "Gin"], ["github.com/labstack/echo", "Echo"], ["github.com/go-chi/chi", "chi"], ["github.com/gofiber/fiber", "Fiber"], ["gorm.io/gorm", "GORM"], ["github.com/jackc/pgx", "pgx"],
  ["flask", "Flask"], ["fastapi", "FastAPI"], ["django", "Django"], ["sqlalchemy", "SQLAlchemy"], ["laravel/framework", "Laravel"],
];

function layerOf(m: Manifest, stack: string[], hasRoutes: boolean): Layer {
  if (m.kind === "flutter") return "app";
  if (m.kind === "go" || m.kind === "python" || m.kind === "php") return "backend";
  const has = (s: string): boolean => stack.includes(s);
  if (has("React Native") || has("Expo")) return "app";
  if (has("Next.js") || has("React") || has("Vue") || has("Svelte") || has("Vite")) return has("NestJS") || has("Express") || has("Fastify") ? "backend" : "web";
  if (has("NestJS") || has("Fastify") || has("Express") || has("Koa") || has("Hono") || has("Drizzle") || has("Prisma") || hasRoutes) return "backend";
  return "other";
}

const dirOf = (p: string): string => { const i = p.lastIndexOf("/"); return i < 0 ? "" : p.slice(0, i); };
const join = (a: string, b: string): string => {
  const parts = (a ? a.split("/") : []).concat(b.split("/"));
  const out: string[] = [];
  for (const s of parts) { if (s === "." || s === "") continue; if (s === "..") out.pop(); else out.push(s); }
  return out.join("/");
};

// ---- features by naming convention ----
const CONTAINERS_DIR = new Set(["modules", "module", "features", "feature", "domains", "domain"]);
const CONTAINERS_FLAT = new Set(["controllers", "services", "routes", "handlers", "models", "entities", "repositories", "screens", "pages", "views", "resolvers", "schemas", "dtos", "providers", "blocs", "cubits", "notifiers"]);
const IGNORE = new Set(["server", "client", "cli", "bin", "scripts", "tools", "docs", "backend", "frontend", "web", "mobile", "v1", "v2", "v3", "v4", "index", "common", "shared", "core", "util", "utils", "helper", "helpers", "lib", "type", "types", "config", "configs", "component", "components", "widget", "widgets", "hook", "hooks", "middleware", "middlewares", "constant", "constants", "base", "app", "main", "test", "tests", "mock", "mocks", "generated", "api", "src", "internal", "pkg", "cmd", "layout", "theme", "design", "l10n", "assets", "style", "styles", "public", "private", "interface", "interfaces", "model", "service", "controller", "route", "handler", "screen", "page", "view", "repository", "provider", "bloc", "cubit", "notifier", "schema", "dto", "entity", "resolver"]);
const SUFFIX = /([._-](controller|service|routes?|handler|model|entity|repository|repo|screen|page|view|resolver|schema|dto|provider|bloc|cubit|notifier|state|event|widget|test|spec|module|store|slice|query|queries|api|dart|ts|tsx|js|jsx)s?)+$/i;
const stem = (file: string): string => file.replace(/\.[a-z0-9]+$/i, "").replace(SUFFIX, "").replace(/(Controller|Service|Routes?|Handler|Model|Entity|Repository|Screen|Page|View|Resolver|Schema|Dto|Provider|Bloc|Cubit|Notifier|Test|Spec)$/, "");
const clean = (s: string): string => { const n = normalize(s.replace(/[\[\]()@:$]/g, " ")); return /^v\d+$/.test(n) ? "" : n; };

/** The feature a file belongs to, by where it sits: { name, dir } or null. */
function featureOf(path: string, lang: string, nextPkg: boolean): { name: string; dir: string; rule: string } | null {
  const segs = path.split("/");
  const file = segs[segs.length - 1];
  const ok = (n: string): boolean => { const k = clean(n); return !!k && !IGNORE.has(k) && !IGNORE.has(n.toLowerCase()) && k.length > 1; };
  for (let i = 0; i < segs.length - 1; i++) {
    const s = segs[i].toLowerCase();
    if (CONTAINERS_DIR.has(s)) {
      const nxt = segs[i + 1];
      if (i + 1 < segs.length - 1) { if (ok(nxt)) return { name: nxt, dir: segs.slice(0, i + 2).join("/"), rule: `folder ${segs[i]}/${nxt}` }; }
      else if (ok(stem(file))) return { name: stem(file), dir: segs.slice(0, i + 1).join("/"), rule: `file in ${segs[i]}/` };
    }
    if (lang === "go" && (s === "internal" || s === "pkg") && i + 1 < segs.length - 1 && ok(segs[i + 1])) return { name: segs[i + 1], dir: segs.slice(0, i + 2).join("/"), rule: `Go package ${s}/${segs[i + 1]}` };
  }
  for (let i = 0; i < segs.length - 1; i++) {
    const s = segs[i].toLowerCase();
    if (CONTAINERS_FLAT.has(s)) {
      if (i + 1 < segs.length - 1) { if (ok(segs[i + 1])) return { name: segs[i + 1], dir: segs.slice(0, i + 2).join("/"), rule: `folder ${segs[i]}/${segs[i + 1]}` }; }
      else if (ok(stem(file))) return { name: stem(file), dir: segs.slice(0, i + 1).join("/"), rule: `file in ${segs[i]}/` };
    }
  }
  if (nextPkg) {
    const at = segs.findIndex((s) => s === "app" || s === "pages");
    if (at >= 0) {
      const rest = segs.slice(at + 1, -1).filter((s) => !/^\(.*\)$/.test(s) && !/^\[.*\]$/.test(s) && s !== "api");
      if (rest[0] && ok(rest[0])) return { name: rest[0], dir: segs.slice(0, at + 2).join("/"), rule: `Next.js route ${segs[at]}/${rest[0]}` };
    }
  }
  return null;
}

const routeKey = (path: string): string => { const seg = path.split("/").filter((s) => s && !/^v\d+$/i.test(s) && s.toLowerCase() !== "api" && !s.startsWith(":") && !s.startsWith("{") && !s.startsWith("[") && s !== "*")[0]; return seg ? clean(seg) : ""; };

export function buildModel(list: FileFact[]): Model {
  const files = new Map(list.map((f) => [f.p, f]));
  // ---- packages: every manifest (except tsconfig) is a package root; a file belongs to the nearest one ----
  const roots: { root: string; m: Manifest }[] = [];
  for (const f of list) if (f.k && f.k.kind !== "tsconfig") roots.push({ root: dirOf(f.p), m: f.k });
  roots.sort((a, b) => b.root.length - a.root.length);
  const pkgOf = (p: string): { root: string; m: Manifest } | undefined => roots.find((r) => r.root === "" || p === r.root || p.startsWith(`${r.root}/`));
  const stackOf = (m: Manifest): string[] => [...new Set(STACK_TAGS.filter(([d]) => m.deps.some((x) => x === d || x.startsWith(`${d}/`) && d.includes("/"))).map(([, t]) => t))];
  const routesIn = new Map<string, number>();
  for (const f of list) if (f.f.r?.length) { const r = pkgOf(f.p)?.root ?? "(root)"; routesIn.set(r, (routesIn.get(r) ?? 0) + f.f.r.length); }
  const count = new Map<string, number>();
  for (const f of list) { const r = pkgOf(f.p)?.root ?? "(root)"; count.set(r, (count.get(r) ?? 0) + 1); }
  const packages: Pkg[] = roots.map(({ root, m }) => { const stack = stackOf(m); return { root, name: m.name ?? (root.split("/").pop() || "app"), kind: m.kind, stack, layer: layerOf(m, stack, (routesIn.get(root) ?? 0) > 0), files: count.get(root) ?? 0 }; }).sort((a, b) => a.root.localeCompare(b.root));
  const pkgInfo = (p: string): Pkg | undefined => { const r = pkgOf(p); return r ? packages.find((x) => x.root === r.root && x.kind === r.m.kind) : undefined; };
  const layerFor = (f: FileFact, pkg?: Pkg): Layer => (f.l === "sql" || f.l === "prisma" ? "db" : pkg?.layer ?? (f.l === "dart" ? "app" : "other"));

  // ---- graph ----
  const out = new Map<string, string[]>();
  const rev = new Map<string, string[]>();
  const edge = (a: string, b: string): void => { if (a === b) return; (out.get(a) ?? out.set(a, []).get(a)!).push(b); (rev.get(b) ?? rev.set(b, []).get(b)!).push(a); };
  const EXTS = [".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".vue", ".svelte"];
  const tsconfigs = list.filter((f) => f.k?.kind === "tsconfig");
  const nearestTs = (p: string): FileFact | undefined => tsconfigs.filter((t) => dirOf(t.p) === "" || p.startsWith(`${dirOf(t.p)}/`)).sort((a, b) => b.p.length - a.p.length)[0];
  const tryJs = (base: string): string | undefined => {
    if (files.has(base)) return base;
    for (const e of EXTS) if (files.has(base + e)) return base + e;
    const noExt = base.replace(/\.(m|c)?js$/, "");
    if (noExt !== base) for (const e of [".ts", ".tsx"]) if (files.has(noExt + e)) return noExt + e;
    for (const e of EXTS) if (files.has(`${base}/index${e}`)) return `${base}/index${e}`;
    return undefined;
  };
  const dartPkgs = new Map(roots.filter((r) => r.m.kind === "flutter" && r.m.name).map((r) => [r.m.name as string, r.root]));
  const goMods = roots.filter((r) => r.m.kind === "go" && r.m.name).map((r) => ({ mod: r.m.name as string, root: r.root }));
  const goDirs = new Map<string, string[]>();
  for (const f of list) if (f.l === "go" && !f.p.endsWith("_test.go")) (goDirs.get(dirOf(f.p)) ?? goDirs.set(dirOf(f.p), []).get(dirOf(f.p))!).push(f.p);
  const cov: Coverage = { relative: 0, resolved: 0, unresolved: 0, unresolved_sample: [], external: 0 };
  const miss = (f: string, s: string): void => { cov.unresolved++; if (cov.unresolved_sample.length < 10) cov.unresolved_sample.push(`${f} → ${s}`); };
  for (const f of list) {
    for (const spec of f.f.i ?? []) {
      let target: string | undefined;
      let attempted = true;
      if (f.l === "ts" || f.l === "js") {
        if (spec.startsWith(".")) target = tryJs(join(dirOf(f.p), spec));
        else {
          const ts = nearestTs(f.p);
          const paths = ts?.k?.paths;
          attempted = false;
          if (paths) for (const [pat, tgts] of Object.entries(paths)) {
            const star = pat.indexOf("*");
            const hit = star < 0 ? spec === pat : spec.startsWith(pat.slice(0, star)) && spec.endsWith(pat.slice(star + 1));
            if (!hit) continue;
            attempted = true;
            const mid = star < 0 ? "" : spec.slice(star, spec.length - (pat.length - star - 1));
            for (const t of tgts) { target = tryJs(join(join(dirOf(ts!.p), ts?.k?.baseUrl ?? "."), t.replace("*", mid))); if (target) break; }
            break;
          }
        }
      } else if (f.l === "dart") {
        if (spec.startsWith("package:")) {
          const m = /^package:([^/]+)\/(.*)$/.exec(spec);
          const root = m ? dartPkgs.get(m[1]) : undefined;
          if (m && root !== undefined) target = files.has(join(root, `lib/${m[2]}`)) ? join(root, `lib/${m[2]}`) : undefined; else attempted = false;
        } else if (spec.startsWith("dart:")) attempted = false;
        else target = files.has(join(dirOf(f.p), spec)) ? join(dirOf(f.p), spec) : undefined;
      } else if (f.l === "go") {
        const gm = goMods.find((g) => spec === g.mod || spec.startsWith(`${g.mod}/`));
        if (gm) { for (const t of goDirs.get(join(gm.root, spec.slice(gm.mod.length))) ?? []) edge(f.p, t); cov.relative++; cov.resolved++; continue; }
        attempted = false;
      } else attempted = false;
      if (!attempted) { cov.external++; continue; }
      cov.relative++;
      if (target) { cov.resolved++; edge(f.p, target); } else miss(f.p, spec);
    }
  }

  // ---- features ----
  type Acc = { names: Map<string, number>; layers: Map<string, FeatureLayer & { _dirs: Set<string> }>; symbols: string[]; routes: Feature["routes"]; tables: Feature["tables"] };
  const accs = new Map<string, Acc>();
  const fileFeature = new Map<string, string>();
  const nextPkgRoots = new Set(packages.filter((p) => p.stack.includes("Next.js")).map((p) => p.root));
  for (const f of list) {
    if (f.l === "manifest") continue;
    const pkg = pkgInfo(f.p);
    const ft = featureOf(f.p, f.l, !!pkg && nextPkgRoots.has(pkg.root));
    if (!ft) continue;
    const key = clean(ft.name);
    const acc = accs.get(key) ?? accs.set(key, { names: new Map(), layers: new Map(), symbols: [], routes: [], tables: [] }).get(key)!;
    acc.names.set(ft.name, (acc.names.get(ft.name) ?? 0) + 1);
    const layer = layerFor(f, pkg);
    const lk = `${pkg?.root ?? "(root)"}|${layer}`;
    const l = acc.layers.get(lk) ?? acc.layers.set(lk, { package: pkg?.name ?? "(root)", layer, dir: ft.dir, files: [], file_count: 0, reason: `${ft.rule}`, _dirs: new Set() }).get(lk)!;
    l.file_count++; if (l.files.length < 200) l.files.push(f.p); l._dirs.add(ft.dir);
    fileFeature.set(f.p, key);
    for (const d of f.f.d ?? []) if (acc.symbols.length < 40) acc.symbols.push(d);
    for (const [method, path] of f.f.r ?? []) if (acc.routes.length < 60) acc.routes.push({ method, path, file: f.p, reason: "registered in the feature's files" });
  }
  const names = [...accs.keys()];
  const attachTable = (name: string, file: string): boolean => {
    const k = normalize(name);
    const own = fileFeature.get(file);
    if (own) { accs.get(own)!.tables.push({ name, file, reason: "defined in the feature's files" }); return true; }
    const exact = accs.get(k);
    if (exact) { exact.tables.push({ name, file, reason: "same name as the feature" }); return true; }
    const pre = names.filter((n) => k.startsWith(`${n}_`)).sort((a, b) => b.length - a.length)[0];
    if (pre) { accs.get(pre)!.tables.push({ name, file, reason: "table name starts with the feature name" }); return true; }
    return false;
  };
  let orphanTables = 0;
  let orphanRoutes = 0;
  for (const f of list) for (const t of f.f.t ?? []) if (!attachTable(t, f.p)) orphanTables++;
  for (const f of list) {
    if (fileFeature.has(f.p)) continue;
    for (const [method, path] of f.f.r ?? []) {
      const k = routeKey(path);
      const acc = k ? accs.get(k) : undefined;
      if (acc) acc.routes.push({ method, path, file: f.p, reason: "route prefix matches the feature name" }); else orphanRoutes++;
    }
  }
  // Tables and routes that belong to no module still count: they become "tables only" / "routes only" features,
  // so a search for "cart" finds a cart_items table even when no cart folder exists.
  const orphanT = new Map<string, { name: string; file: string }[]>();
  for (const f of list) for (const t of f.f.t ?? []) {
    const k = normalize(t);
    const attached = [...accs.values()].some((a) => a.tables.some((x) => x.name === t && x.file === f.p));
    if (attached) continue;
    const head = k.split("_")[0];
    if (!head || head.length < 3 || IGNORE.has(head)) continue;
    (orphanT.get(head) ?? orphanT.set(head, []).get(head)!).push({ name: t, file: f.p });
  }
  for (const [head, tabs] of orphanT) {
    if (accs.has(head)) continue;
    const acc: Acc = { names: new Map([[head, tabs.length]]), layers: new Map(), symbols: [], routes: [], tables: tabs.slice(0, 30).map((t) => ({ ...t, reason: "database tables only: no module folder with this name" })) };
    const filesOf = [...new Set(tabs.map((t) => t.file))];
    acc.layers.set("(db)|db", { package: "(database)", layer: "db", dir: "", files: filesOf.slice(0, 200), file_count: filesOf.length, reason: "tables only", _dirs: new Set() });
    accs.set(head, acc);
  }
  const orphanR = new Map<string, Feature["routes"]>();
  for (const f of list) {
    if (fileFeature.has(f.p)) continue;
    for (const [method, path] of f.f.r ?? []) {
      const k = routeKey(path);
      if (!k || accs.get(k)?.routes.some((r) => r.file === f.p && r.path === path)) continue;
      if (accs.has(k) && accs.get(k)!.layers.size) continue;
      (orphanR.get(k) ?? orphanR.set(k, []).get(k)!).push({ method, path, file: f.p, reason: "routes only: no module folder with this name" });
    }
  }
  for (const [k, rs] of orphanR) {
    if (accs.has(k) || k.length < 3 || IGNORE.has(k)) continue;
    const files2 = [...new Set(rs.map((r) => r.file))];
    const pkg = pkgInfo(files2[0]);
    const acc: Acc = { names: new Map([[k, rs.length]]), layers: new Map(), symbols: [], routes: rs.slice(0, 60), tables: [] };
    acc.layers.set(`${pkg?.root ?? "(root)"}|backend`, { package: pkg?.name ?? "(root)", layer: "backend", dir: "", files: files2.slice(0, 200), file_count: files2.length, reason: "routes only", _dirs: new Set() });
    accs.set(k, acc);
  }
  const features: Feature[] = [...accs].map(([key, acc]) => {
    const layers = [...acc.layers.values()].map(({ _dirs, ...l }) => ({ ...l, ...(_dirs.size > 1 ? { dir: [..._dirs].sort()[0] } : {}) })).sort((a, b) => a.layer.localeCompare(b.layer));
    const best = [...acc.names].sort((a, b) => b[1] - a[1])[0][0];
    const layerList = layers.length > 1 ? layers.map((l) => ({ ...l, reason: `${l.reason}; same name "${key}" as the other layers (case and plural ignored)` })) : layers;
    return { id: key, name: words(best).join(" ").replace(/^./, (c) => c.toUpperCase()), layers: layerList, routes: acc.routes.slice(0, 60), tables: acc.tables.slice(0, 30), symbols: [...new Set(acc.symbols)].slice(0, 30), file_count: layers.reduce((n, l) => n + l.file_count, 0) };
  }).sort((a, b) => b.file_count - a.file_count);
  return { files, packages, features, out, rev, coverage: cov, orphans: { routes: orphanRoutes, tables: orphanTables }, fileFeature };
}
