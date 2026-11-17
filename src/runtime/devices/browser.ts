// Browser tools: the agent drives the project's Browser tab in Opscode's side
// panel (main attaches the Chrome DevTools Protocol to it). Reading is ref-first:
// browser_read / browser_find tag elements ref_N, and actions target a ref, or a
// point in the last screenshot. The same tools reach the built-in agent directly
// and Claude Code / Codex over the /mcp/devices endpoint.

import type { PermissionMode } from "../../shared/protocol";
import type { GateResult, Tool, ToolResult } from "../agent/tools";
import { policy } from "../agent/tools";
import type { DeviceBridge } from "./bridge";

export interface BrowserScope {
  workspaceId: string;
  chatId: string;
  mode(): PermissionMode;
}

/** What main answers for every browser op. */
interface HostResult {
  text: string;
  image?: { media_type: string; data: string };
}

const MAX_TEXT = 24_000;
const ACTIONS = ["click", "double_click", "right_click", "hover", "type", "fill", "key", "scroll", "scroll_to", "dialog", "wait"] as const;

/** Sites the user allowed per chat (origins). Local pages never ask. */
const allowedSites = new Map<string, Set<string>>();

export function isLocalUrl(u: URL): boolean {
  const h = u.hostname.toLowerCase().replace(/^\[|\]$/g, "");
  return h === "localhost" || h === "127.0.0.1" || h === "::1" || h === "0.0.0.0" || h.endsWith(".localhost") || h.endsWith(".test") || /^192\.168\.|^10\.|^172\.(1[6-9]|2\d|3[01])\./.test(h);
}

/** http(s) URL from what the model wrote ("localhost:3000" works too), or null. */
export function toUrl(raw: string): URL | null {
  const s = raw.trim();
  if (!s) return null;
  const withScheme = /^[a-z][a-z0-9+.-]*:/i.test(s) && !/^(localhost|[\w.-]+):\d+/i.test(s) ? s : `${/^(localhost|127\.|\[::1\]|[\w-]+\.localhost)/i.test(s) ? "http" : "https"}://${s}`;
  try {
    const u = new URL(withScheme);
    return u.protocol === "http:" || u.protocol === "https:" ? u : null;
  } catch {
    return null;
  }
}

const clipText = (s: string): string => (s.length > MAX_TEXT ? `${s.slice(0, MAX_TEXT)}\n… (cut at ${MAX_TEXT} characters; use ref_id or browser_find to look closer)` : s);

export function browserTools(bridge: DeviceBridge, scope: BrowserScope): Tool[] {
  const call = async (op: string, args: Record<string, unknown>): Promise<ToolResult> => {
    const r = await bridge.request<HostResult>("browser", op, { workspace_id: scope.workspaceId, chat_id: scope.chatId, ...args });
    return { output: clipText(String(r?.text ?? "")), is_error: false, ...(r?.image ? { image: r.image } : {}) };
  };

  // Navigation to a site outside this computer asks once per site per chat (Full access does not ask).
  const siteGate = (raw: unknown, fallback: Tool["kind"]): GateResult => {
    const rule = policy(scope.mode(), fallback);
    const summary = `Open ${String(raw ?? "")}`.slice(0, 120);
    if (typeof raw !== "string" || ["back", "forward", "reload"].includes(raw)) return { rule: rule === "hide" ? "deny" : rule, summary, ...(rule === "hide" ? { reason: "Not available in this mode." } : {}) };
    const u = toUrl(raw);
    if (!u) return { rule: "deny", summary, reason: "Only http and https addresses open in the browser." };
    if (isLocalUrl(u) || scope.mode() === "full" || allowedSites.get(scope.chatId)?.has(u.origin)) return { rule: rule === "hide" ? "deny" : rule, summary: `Open ${u.href}`.slice(0, 120) };
    return { rule: "ask", summary: `Open ${u.origin} (a site outside this computer)`, detail: u.href };
  };
  const allowSite = (raw: unknown): void => {
    const u = typeof raw === "string" ? toUrl(raw) : null;
    if (!u || isLocalUrl(u)) return;
    const set = allowedSites.get(scope.chatId) ?? new Set<string>();
    set.add(u.origin);
    allowedSites.set(scope.chatId, set);
  };

  const navigate: Tool = {
    def: {
      name: "browser_navigate",
      description: "Open a page in this project's Browser tab (Opscode's side panel; the user sees it). url: an http(s) address such as http://localhost:3000, or \"back\", \"forward\", \"reload\". Waits for the load and returns the page's buttons, links and fields with [ref_N], plus any console errors or failed requests.",
      schema: { type: "object", properties: { url: { type: "string" }, new_tab: { type: "boolean", description: "Open in a new tab instead of the current one." } }, required: ["url"], additionalProperties: false },
    },
    kind: "read",
    describe: (i) => ({ summary: `Open ${String(i.url ?? "")}`.slice(0, 120) }),
    gate: async (i) => siteGate(i.url, "read"),
    run: async (i) => {
      const raw = String(i.url ?? "");
      const nav = ["back", "forward", "reload"].includes(raw) ? raw : toUrl(raw)?.href;
      if (!nav) return { output: "Only http and https addresses open in the browser.", is_error: true };
      allowSite(raw);
      return call("navigate", { url: nav, new_tab: i.new_tab === true });
    },
  };

  const read: Tool = {
    def: {
      name: "browser_read",
      description: "Read the open page as text. mode \"interactive\" (default): buttons, links, inputs with their [ref_N]. \"all\": the whole outline. \"text\": the page's visible text. ref_id limits the outline to one element. Prefer this over screenshots.",
      schema: { type: "object", properties: { mode: { type: "string", enum: ["interactive", "all", "text"] }, ref_id: { type: "string" }, max_chars: { type: "number" } }, additionalProperties: false },
    },
    kind: "read",
    describe: (i) => ({ summary: i.mode === "text" ? "Read the page text" : "Read the page" }),
    run: (i) => call("read", { mode: ["all", "text"].includes(String(i.mode)) ? i.mode : "interactive", ...(typeof i.ref_id === "string" ? { ref_id: i.ref_id } : {}), max_chars: Math.min(Math.max(Number(i.max_chars) || 12_000, 1000), MAX_TEXT) }),
  };

  const find: Tool = {
    def: {
      name: "browser_find",
      description: "Find elements on the open page whose role, label or text contains the query (case-insensitive). Returns up to 20 matches with [ref_N].",
      schema: { type: "object", properties: { query: { type: "string" } }, required: ["query"], additionalProperties: false },
    },
    kind: "read",
    describe: (i) => ({ summary: `Find "${String(i.query ?? "")}" on the page`.slice(0, 120) }),
    run: (i) => call("find", { query: String(i.query ?? "").slice(0, 200) }),
  };

  const act: Tool = {
    def: {
      name: "browser_act",
      description: [
        "Act on the open page with real mouse and keyboard input. Target an element with ref (from browser_read/browser_find), or x,y in the last screenshot's pixels.",
        "The result says what changed (elements that appeared, changed or went away, new text, console errors, failed requests), so you rarely need to read the page again.",
        "click / double_click / right_click / hover: ref or x,y.",
        "type: text into the focused field (or ref first gets focus); submit:true presses Enter after.",
        "fill: set a field's whole value: inputs and textareas get value (string), selects pick the option by value or label, checkboxes and radios take true/false.",
        "key: keys like \"Enter\", \"Escape\", \"Tab\", \"ArrowDown\", \"cmd+a\" (several separated by spaces).",
        "scroll: direction up/down/left/right, amount in wheel ticks (default 3), at ref or x,y or the page centre. scroll_to: bring ref into view.",
        "dialog: answer an open alert/confirm/prompt (accept true/false, text for prompts). wait: seconds (max 10), or until text appears.",
      ].join(" "),
      schema: {
        type: "object",
        properties: {
          action: { type: "string", enum: [...ACTIONS] },
          ref: { type: "string" }, x: { type: "number" }, y: { type: "number" },
          text: { type: "string" }, value: { type: ["string", "boolean", "number"] }, submit: { type: "boolean" },
          keys: { type: "string" }, direction: { type: "string", enum: ["up", "down", "left", "right"] }, amount: { type: "number" },
          accept: { type: "boolean" }, seconds: { type: "number" },
        },
        required: ["action"],
        additionalProperties: false,
      },
    },
    kind: "browser",
    describe: (i) => {
      const a = String(i.action ?? "act");
      const target = typeof i.ref === "string" ? ` ${i.ref}` : typeof i.x === "number" ? ` at ${i.x},${i.y}` : "";
      const what = a === "type" ? ` "${String(i.text ?? "").slice(0, 40)}"` : a === "key" ? ` ${String(i.keys ?? "")}` : a === "fill" ? ` = ${JSON.stringify(i.value ?? "").slice(0, 40)}` : "";
      return { summary: `Browser: ${a.replace("_", " ")}${target}${what}`.slice(0, 120) };
    },
    run: async (i) => {
      const action = String(i.action ?? "");
      if (!(ACTIONS as readonly string[]).includes(action)) return { output: `Unknown action "${action}". Use one of: ${ACTIONS.join(", ")}.`, is_error: true };
      return call("act", { ...i, action });
    },
  };

  const screenshot: Tool = {
    def: {
      name: "browser_screenshot",
      description: "A picture of the open page's viewport (or of one element with ref). Use it to check how things look; read text with browser_read instead. Coordinates for browser_act are this picture's pixels.",
      schema: { type: "object", properties: { ref: { type: "string" } }, additionalProperties: false },
    },
    kind: "read",
    describe: () => ({ summary: "Screenshot the page" }),
    run: (i) => call("screenshot", typeof i.ref === "string" ? { ref: i.ref } : {}),
  };

  const logs: Tool = {
    def: {
      name: "browser_logs",
      description: "The open tab's recent console messages and network requests (kind \"console\" or \"network\" for one of them), newest last. Filter with only_errors, pattern (substring). Errors already show up in navigate/act results.",
      schema: { type: "object", properties: { kind: { type: "string", enum: ["console", "network", "all"] }, only_errors: { type: "boolean" }, pattern: { type: "string" }, limit: { type: "number" } }, additionalProperties: false },
    },
    kind: "read",
    describe: (i) => ({ summary: `Read the page's ${i.kind === "network" ? "network requests" : i.kind === "console" ? "console" : "console and network"}` }),
    run: (i) => call("logs", { kind: i.kind === "network" || i.kind === "console" ? i.kind : "all", only_errors: i.only_errors === true, pattern: typeof i.pattern === "string" ? i.pattern.slice(0, 200) : "", limit: Math.min(Math.max(Number(i.limit) || 50, 1), 200) }),
  };

  const evaluate: Tool = {
    def: {
      name: "browser_eval",
      description: "Run JavaScript in the open page and get the JSON result (await works; up to 16 KB back). For debugging and checks; act with browser_act instead.",
      schema: { type: "object", properties: { code: { type: "string" } }, required: ["code"], additionalProperties: false },
    },
    kind: "browser",
    describe: (i) => ({ summary: "Run JavaScript in the page", detail: String(i.code ?? "").slice(0, 2000) }),
    run: (i) => call("eval", { code: String(i.code ?? "").slice(0, 20_000) }),
  };

  const tabs: Tool = {
    def: {
      name: "browser_tabs",
      description: "This project's browser tabs. action list | new (optional url) | select tab_id | close tab_id | resize (preset mobile 375x812, tablet 768x1024, desktop; or width+height).",
      schema: { type: "object", properties: { action: { type: "string", enum: ["list", "new", "select", "close", "resize"] }, tab_id: { type: "string" }, url: { type: "string" }, preset: { type: "string", enum: ["mobile", "tablet", "desktop"] }, width: { type: "number" }, height: { type: "number" } }, required: ["action"], additionalProperties: false },
    },
    kind: "read",
    describe: (i) => ({ summary: `Browser tabs: ${String(i.action ?? "list")}` }),
    gate: async (i) => (i.action === "new" && typeof i.url === "string" ? siteGate(i.url, "read") : { rule: policy(scope.mode(), "read") === "hide" ? "deny" : "auto", summary: `Browser tabs: ${String(i.action ?? "list")}` }),
    run: async (i) => {
      if (i.action === "new" && typeof i.url === "string") {
        const u = toUrl(i.url);
        if (!u) return { output: "Only http and https addresses open in the browser.", is_error: true };
        allowSite(i.url);
        return call("tabs", { ...i, url: u.href });
      }
      return call("tabs", i);
    },
  };

  const one = [navigate, read, find, act, screenshot, logs, evaluate, tabs];

  const batch: Tool = {
    def: {
      name: "browser_batch",
      description: "Run several browser steps in one call, in order, stopping at the first error: actions = [{tool, input}] with tool one of browser_navigate, browser_read, browser_find, browser_act, browser_screenshot, browser_logs (max 20). Use it when you can predict the next steps.",
      schema: { type: "object", properties: { actions: { type: "array", items: { type: "object", properties: { tool: { type: "string" }, input: { type: "object" } }, required: ["tool", "input"] } } }, required: ["actions"], additionalProperties: false },
    },
    kind: "browser",
    describe: (i) => ({ summary: `Browser: ${Array.isArray(i.actions) ? i.actions.length : 0} steps`, detail: JSON.stringify(i.actions ?? [], null, 2).slice(0, 2000) }),
    run: async (i, ctx) => {
      const steps = Array.isArray(i.actions) ? (i.actions as { tool?: unknown; input?: unknown }[]).slice(0, 20) : [];
      if (!steps.length) return { output: "actions is empty.", is_error: true };
      const out: string[] = [];
      let image: ToolResult["image"];
      for (const [n, s] of steps.entries()) {
        const t = one.find((x) => x.def.name === s.tool && x.def.name !== "browser_eval" && x.def.name !== "browser_tabs");
        const input = (s.input && typeof s.input === "object" ? s.input : {}) as Record<string, unknown>;
        if (!t) { out.push(`${n + 1}. ${String(s.tool)}: not allowed in a batch.`); return { output: out.join("\n"), is_error: true, ...(image ? { image } : {}) }; }
        if (t === navigate) {
          const g = siteGate(input.url, "read");
          if (g.rule !== "auto" && g.rule !== "ask") { out.push(`${n + 1}. ${g.reason ?? "not allowed"}`); return { output: out.join("\n"), is_error: true }; }
          const u = typeof input.url === "string" ? toUrl(input.url) : null;
          if (u && !isLocalUrl(u) && scope.mode() !== "full" && !allowedSites.get(scope.chatId)?.has(u.origin)) {
            out.push(`${n + 1}. ${u.origin} is outside this computer: open it with browser_navigate on its own first (the user is asked once).`);
            return { output: out.join("\n"), is_error: true };
          }
        }
        try {
          const r = await t.run(input, ctx);
          out.push(`${n + 1}. ${t.def.name}: ${r.output}`);
          if (r.image) image = r.image;
          if (r.is_error) return { output: out.join("\n"), is_error: true, ...(image ? { image } : {}) };
        } catch (e) {
          out.push(`${n + 1}. ${t.def.name}: ${e instanceof Error ? e.message : String(e)}`);
          return { output: out.join("\n"), is_error: true, ...(image ? { image } : {}) };
        }
      }
      return { output: clipText(out.join("\n")), is_error: false, ...(image ? { image } : {}) };
    },
  };

  return [...one, batch];
}

/** Forget a chat's site approvals (chat removed). */
export function forgetBrowserChat(chatId: string): void {
  allowedSites.delete(chatId);
}
