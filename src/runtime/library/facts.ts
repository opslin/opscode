// Per-file facts, at regex level (this is an index, not a compiler): what a file
// imports, what it declares, which routes it registers, which database tables it
// defines. Only names, paths and route strings are kept, never file contents.

export interface Facts {
  /** Raw import specifiers. */
  i?: string[];
  /** Top-level declarations (functions, classes, types, widgets). */
  d?: string[];
  /** Routes as [METHOD, path]. */
  r?: [string, string][];
  /** Database tables this file defines. */
  t?: string[];
  /** Lines in the file. */
  n: number;
  /** Go package / Dart library name, when the file states one. */
  pk?: string;
}

const uniq = <T>(a: T[], max: number): T[] => [...new Set(a)].slice(0, max);
const all = (re: RegExp, text: string, group = 1): string[] => { const out: string[] = []; for (const m of text.matchAll(re)) if (m[group]) out.push(m[group]); return out; };
const METHODS = "get|post|put|patch|delete|all|head|options";
const lineCount = (t: string): number => { let n = 1; for (let i = 0; i < t.length; i++) if (t.charCodeAt(i) === 10) n++; return n; };

function jsLike(text: string, path: string): Facts {
  const imports = [
    ...all(/\b(?:import|export)\b[^'"`;]*?\bfrom\s*['"`]([^'"`]+)['"`]/g, text),
    // A side-effect import is a statement: it must start the line (the word "import" inside a string is not one).
    ...all(/^[ \t]*import\s*['"`]([^'"`\n]+)['"`]/gm, text),
    ...all(/\brequire\(\s*['"`]([^'"`\n]+)['"`]\s*\)/g, text),
    ...all(/\bimport\(\s*['"`]([^'"`\n]+)['"`]\s*\)/g, text),
  ];
  const decls = [
    ...all(/\bexport\s+(?:default\s+)?(?:declare\s+)?(?:abstract\s+)?(?:async\s+)?(?:function\*?|class|const|let|var|enum|interface|type)\s+([A-Za-z_$][\w$]*)/g, text),
    ...all(/^(?:async\s+)?function\s+([A-Za-z_$][\w$]*)/gm, text),
    ...all(/^class\s+([A-Za-z_$][\w$]*)/gm, text),
  ];
  const routes: [string, string][] = [];
  for (const m of text.matchAll(new RegExp(`\\b[\\w$.]*\\.(${METHODS})\\(\\s*['"\`](/[^'"\`]*|\\*)['"\`]`, "gi"))) routes.push([m[1].toUpperCase(), m[2]]);
  // NestJS: @Controller('prefix') with @Get('sub') ...
  const prefix = /@Controller\(\s*(?:['"`]([^'"`]*)['"`])?/.exec(text)?.[1];
  if (prefix !== undefined) for (const m of text.matchAll(/@(Get|Post|Put|Patch|Delete|All)\(\s*(?:['"`]([^'"`]*)['"`])?\s*\)/g)) routes.push([m[1].toUpperCase(), `/${[prefix, m[2] ?? ""].filter(Boolean).join("/").replace(/\/+/g, "/").replace(/^\//, "")}`]);
  // Next.js: the route is the file's place in app/ or pages/api/.
  const next = /(?:^|\/)app\/(.*)\/route\.[tj]sx?$/.exec(path)?.[1] ?? /(?:^|\/)pages\/api\/(.*)\.[tj]sx?$/.exec(path)?.[1];
  if (next !== undefined) routes.push(["ANY", `/${/pages\/api\//.test(path) ? "api/" : ""}${next.replace(/\(.*?\)\/?/g, "").replace(/\/index$/, "")}`.replace(/\/+$/, "") || "/"]);
  const tables = [
    ...all(/\b(?:pgTable|mysqlTable|sqliteTable)\(\s*['"`]([\w.]+)['"`]/g, text),
    ...all(/\bcreateTable\(\s*['"`]([\w.]+)['"`]/g, text),
    ...all(/@Entity\(\s*['"`]([\w.]+)['"`]/g, text),
    ...all(/\bsequelize\.define\(\s*['"`](\w+)['"`]/g, text),
  ];
  return { n: lineCount(text), ...(imports.length ? { i: uniq(imports, 120) } : {}), ...(decls.length ? { d: uniq(decls, 60) } : {}), ...(routes.length ? { r: routes.slice(0, 60) } : {}), ...(tables.length ? { t: uniq(tables, 20) } : {}) };
}

function dart(text: string): Facts {
  const imports = all(/^\s*(?:import|export|part)\s+['"]([^'"]+)['"]/gm, text);
  const decls = all(/^\s*(?:abstract\s+|final\s+|base\s+|sealed\s+)*(?:class|mixin|enum|extension)\s+([A-Za-z_]\w*)/gm, text);
  const routes: [string, string][] = [];
  for (const m of text.matchAll(/\b(?:GoRoute|Route)\(\s*(?:[^)]*?\s)?path:\s*['"]([^'"]+)['"]/g)) routes.push(["SCREEN", m[1]]);
  for (const m of text.matchAll(/['"](\/[\w\-/:]*)['"]\s*:\s*\(\s*(?:context|_|ctx)/g)) routes.push(["SCREEN", m[1]]);
  return { n: lineCount(text), ...(imports.length ? { i: uniq(imports, 120) } : {}), ...(decls.length ? { d: uniq(decls, 60) } : {}), ...(routes.length ? { r: routes.slice(0, 60) } : {}) };
}

function go(text: string): Facts {
  const pk = /^package\s+(\w+)/m.exec(text)?.[1];
  const imports = [...all(/^\s*import\s+(?:\w+\s+)?"([^"]+)"/gm, text)];
  const block = /^import\s*\(([\s\S]*?)\)/m.exec(text)?.[1];
  if (block) imports.push(...all(/(?:\w+\s+)?"([^"]+)"/g, block));
  const decls = [...all(/^func\s+([A-Za-z_]\w*)/gm, text), ...all(/^func\s+\(\w+\s+\*?(\w+)\)\s+(\w+)/gm, text, 2).map(String), ...all(/^type\s+(\w+)\s+(?:struct|interface)/gm, text)];
  const routes: [string, string][] = [];
  for (const m of text.matchAll(/\.(GET|POST|PUT|PATCH|DELETE|Get|Post|Put|Patch|Delete|Handle|HandleFunc|Any)\(\s*"(\/[^"]*)"/g)) routes.push([m[1].toUpperCase().replace("HANDLEFUNC", "ANY").replace("HANDLE", "ANY"), m[2]]);
  return { n: lineCount(text), ...(pk ? { pk } : {}), ...(imports.length ? { i: uniq(imports, 120) } : {}), ...(decls.length ? { d: uniq(decls, 60) } : {}), ...(routes.length ? { r: routes.slice(0, 60) } : {}) };
}

function sql(text: string): Facts {
  const tables = all(/\bCREATE\s+(?:UNLOGGED\s+|TEMP(?:ORARY)?\s+)?TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?"?([\w.]+)"?/gi, text).map((t) => t.replace(/^.*\./, ""));
  return { n: lineCount(text), ...(tables.length ? { t: uniq(tables, 40) } : {}) };
}

function python(text: string): Facts {
  const imports = [...all(/^from\s+([\w.]+)\s+import/gm, text), ...all(/^import\s+([\w.]+)/gm, text)];
  const decls = all(/^(?:async\s+)?(?:def|class)\s+(\w+)/gm, text);
  const routes: [string, string][] = [];
  for (const m of text.matchAll(/@\w+\.(route|get|post|put|patch|delete)\(\s*['"]([^'"]+)['"]/g)) routes.push([m[1] === "route" ? "ANY" : m[1].toUpperCase(), m[2]]);
  return { n: lineCount(text), ...(imports.length ? { i: uniq(imports, 80) } : {}), ...(decls.length ? { d: uniq(decls, 60) } : {}), ...(routes.length ? { r: routes.slice(0, 60) } : {}) };
}

function prisma(text: string): Facts {
  const tables = all(/^model\s+(\w+)\s*\{/gm, text);
  return { n: lineCount(text), ...(tables.length ? { t: tables } : {}) };
}

function generic(text: string): Facts {
  const decls = all(/\b(?:class|interface|object|enum|struct|protocol)\s+([A-Z]\w*)/g, text);
  return { n: lineCount(text), ...(decls.length ? { d: uniq(decls, 40) } : {}) };
}

/** Language by extension, or null for files that are not indexed. */
export function languageOf(name: string): string | null {
  const dot = name.lastIndexOf(".");
  const ext = dot >= 0 ? name.slice(dot).toLowerCase() : "";
  switch (ext) {
    case ".ts": case ".tsx": case ".mts": case ".cts": return "ts";
    case ".js": case ".jsx": case ".mjs": case ".cjs": case ".vue": case ".svelte": return "js";
    case ".dart": return "dart";
    case ".go": return "go";
    case ".sql": return "sql";
    case ".py": return "py";
    case ".prisma": return "prisma";
    case ".kt": case ".java": case ".swift": case ".php": case ".rb": case ".cs": case ".rs": return "other";
    default: return null;
  }
}

/** Whatever a pattern captured, only short single-line names, paths and routes are kept: never a piece of source. */
const keep = (v: string): boolean => v.length > 0 && v.length <= 200 && !/[\n\r]/.test(v);
function tidy(f: Facts): Facts {
  const out: Facts = { n: f.n };
  if (f.pk && keep(f.pk)) out.pk = f.pk;
  for (const k of ["i", "d", "t"] as const) { const v = f[k]?.filter(keep); if (v?.length) out[k] = v; }
  const r = f.r?.filter(([m, p]) => keep(m) && keep(p));
  if (r?.length) out.r = r;
  return out;
}

export function extract(lang: string, text: string, path: string): Facts {
  return tidy(extractRaw(lang, text, path));
}

function extractRaw(lang: string, text: string, path: string): Facts {
  switch (lang) {
    case "ts": case "js": return jsLike(text, path);
    case "dart": return dart(text);
    case "go": return go(text);
    case "sql": return sql(text);
    case "py": return python(text);
    case "prisma": return prisma(text);
    default: return generic(text);
  }
}
