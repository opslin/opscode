// The voice agent's own hands on Opscode's Browser panel: open a site, search, read, find, click and type, screenshot,
// tabs. The same tools the worker uses (devices/browser.ts), so the person sees every step in the panel, with the voice
// mode's own rules on top:
//   - a site outside this computer opens only with confirmed:true, which the agent may set when the person named that
//     site or asked to open / search it, or said yes when asked. Search pages are allowed (searching is what was asked).
//   - no page JavaScript (browser_eval) and no developer logs: the voice agent browses, it does not debug.
// The tools are kind "chief": they run from the agent's hidden chat, where no approval card could be seen.

import type { Tool, ToolResult } from "../agent/tools";
import { isLocalUrl, toUrl } from "../devices/browser";

const KEEP = ["browser_navigate", "browser_read", "browser_find", "browser_act", "browser_screenshot", "browser_tabs", "browser_batch"];
const SEARCH = "https://www.google.com/search?q=";
const SEARCH_ORIGINS = new Set(["https://www.google.com", "https://google.com"]);

/** `base` = browserTools(bridge, { …, mode: () => "full" }). Returns the voice agent's browser tools, or [] without a browser. */
export function voiceBrowserTools(base: Tool[], onUse: (tool: string, what: string) => void = () => {}): Tool[] {
  const by = new Map(base.map((t) => [t.def.name, t]));
  if (!by.has("browser_navigate")) return [];
  const allowed = new Set<string>(SEARCH_ORIGINS);
  const ctx = { root: "", signal: new AbortController().signal, saveNote: () => { throw new Error("not available"); }, readSkill: () => undefined } as Parameters<Tool["run"]>[1];
  const fail = (output: string): ToolResult => ({ output, is_error: true });

  /** null = may open; otherwise the reason to give the agent. */
  const check = (raw: unknown, confirmed: boolean): string | null => {
    if (typeof raw !== "string") return "url is required.";
    if (["back", "forward", "reload"].includes(raw)) return null;
    const u = toUrl(raw);
    if (!u) return "Only http and https addresses open in the browser.";
    if (isLocalUrl(u) || allowed.has(u.origin)) return null;
    if (confirmed) { allowed.add(u.origin); return null; }
    return `Not opened: ${u.host} is a site outside this computer. Open it only if the person named it or asked you to open or search it (then call again with confirmed: true), or ask them in one short question: "Shall I open ${u.host.replace(/^www\./, "")}?"`;
  };

  const wrap = (t: Tool, over: Partial<Tool> = {}): Tool => ({ ...t, kind: "chief", gate: undefined, ...over });
  const out: Tool[] = [];
  for (const name of KEEP) {
    const t = by.get(name);
    if (!t) continue;
    if (name === "browser_navigate") {
      const schema = t.def.schema as { properties: Record<string, unknown>; required?: string[] };
      out.push(wrap(t, {
        def: {
          name,
          description: `${t.def.description} A site outside this computer needs confirmed: true (the person named it, asked for it, or said yes).`,
          schema: { ...schema, properties: { ...schema.properties, confirmed: { type: "boolean", description: "The person named this site, asked you to open it, or said yes to opening it." } } },
        },
        run: async (i) => { const why = check(i.url, i.confirmed === true); return why ? fail(why) : t.run({ url: i.url, new_tab: i.new_tab === true }, ctx); },
      }));
    } else if (name === "browser_tabs") {
      out.push(wrap(t, { run: async (i) => { if (i.action === "new" && typeof i.url === "string") { const why = check(i.url, i.confirmed === true); if (why) return fail(why); } return t.run(i, ctx); } }));
    } else if (name === "browser_batch") {
      out.push(wrap(t, {
        run: async (i) => {
          const steps = Array.isArray(i.actions) ? (i.actions as { tool?: unknown; input?: Record<string, unknown> }[]) : [];
          for (const s of steps) {
            if (!KEEP.includes(String(s?.tool))) return fail(`${String(s?.tool)} is not available here.`);
            if (s.tool === "browser_navigate") { const why = check(s.input?.url, s.input?.confirmed === true); if (why) return fail(why); }
          }
          return t.run(i, ctx);
        },
      }));
    } else out.push(wrap(t, { run: (i) => t.run(i, ctx) }));
  }
  const nav = by.get("browser_navigate")!;
  out.unshift({
    def: {
      name: "browser_search",
      description: "Search the web in the Browser panel (the person sees it). Returns the results page's links with [ref_N]; open one with browser_act click or browser_navigate.",
      schema: { type: "object", properties: { query: { type: "string", description: "What to search for." } }, required: ["query"], additionalProperties: false },
    },
    kind: "chief",
    describe: (i) => ({ summary: `Search: ${String(i.query ?? "").slice(0, 80)}` }),
    run: async (i) => {
      const q = typeof i.query === "string" ? i.query.trim().slice(0, 300) : "";
      if (!q) return fail("query is required.");
      return nav.run({ url: SEARCH + encodeURIComponent(q) }, ctx);
    },
  });
  // Every use is told to the window (the agent's character goes into the browser).
  return out.map((t) => ({ ...t, run: async (i, c) => {
    const what = t.def.name === "browser_search" ? String(i.query ?? "") : t.def.name === "browser_navigate" ? (toUrl(String(i.url ?? ""))?.host ?? String(i.url ?? "")) : "";
    try { onUse(t.def.name, what.slice(0, 80)); } catch { /* the window is gone */ }
    return t.run(i, c);
  } }));
}
