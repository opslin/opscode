// Usage → "Where tokens go": what your Claude Code and Codex sessions cost in
// tokens, what burns them, and which sessions are the heavy ones. Everything is
// read from the session logs on this computer; nothing leaves it.
// Dollar figures are API list prices (what the tokens would cost through the API),
// useful for comparing habits and models. They are not what your plan charges.

import { h, append } from "./dom.js";
import { icon } from "./icons.js";
import { state, toast, activeWorkspace } from "./store.js";

const put = (el, ...kids) => { el.replaceChildren(); append(el, kids); };
const usd = (n) => (n >= 100 ? `$${Math.round(n).toLocaleString()}` : n >= 1 ? `$${n.toFixed(1)}` : n > 0 ? `$${n.toFixed(2)}` : "$0");
const kt = (n) => (n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1000 ? `${Math.round(n / 1000)}k` : String(Math.round(n)));
const gb = (n) => (n >= 1e9 ? `${(n / 1e9).toFixed(1)} GB` : `${Math.round(n / 1e6)} MB`);
const pct = (a, b) => (b > 0 ? Math.round((a / b) * 100) : 0);
const day = (t) => new Date(t).toLocaleDateString([], { month: "short", day: "numeric" });
const MODEL_NAME = (m) => m.replace(/^claude-/, "").replace(/-(\d)-(\d)$/, " $1.$2").replace(/-/g, " ");
const SEGS = [
  ["read", "Re-reading the chat so far", "Every message sends the whole conversation again. Cached, so cheaper, but it adds up.", "#e8977a"],
  ["write", "Saving the chat to the cache", "Paid again whenever the cache is rebuilt.", "#f0a040"],
  ["out", "Writing answers and code", "The part you actually asked for.", "#9db4ff"],
  ["inp", "New input", "Your new messages.", "#7dd3a0"],
];

function bar(parts) {
  const total = parts.reduce((n, p) => n + p.value, 0) || 1;
  const cells = 48;
  const el = h("div", { class: "ut-bar", role: "img", "aria-label": parts.map((p) => `${p.label} ${pct(p.value, total)}%`).join(", ") });
  let used = 0;
  parts.forEach((p, k) => {
    const n = k === parts.length - 1 ? cells - used : Math.round((p.value / total) * cells);
    for (let i = 0; i < n; i++) el.append(h("i", { style: `--c:${p.color};--i:${used + i}` }));
    used += n;
  });
  return el;
}
const meter = (value, max, color = "var(--c, #e8977a)") => h("span", { class: "ut-mini" }, h("i", { style: `width:${Math.max(2, pct(value, max))}%;background:${color}` }));

export function createTokensView() {
  let days = 30;
  let account = ""; // "" = every account
  let heads = []; // a headline per account, when there is more than one
  let report = null;
  let loading = false;
  const head = h("div", { class: "ut-controls" });
  const body = h("div", { class: "ut-body" });
  const root = h("div", { class: "ut" }, head, body);

  const windowBtn = (d) => h("button", { class: "ut-seg", type: "button", "aria-pressed": String(days === d), onclick: () => { days = d; void load(false); } }, `${d} days`);
  /** Which account's logs: shown only when more than one account has been used. */
  function accountPick() {
    if (heads.length < 2) return null;
    const label = (id) => { const a = (state.accounts ?? []).find((x) => x.id === id && x.status?.email); return id === "default" ? `This Mac's own${a?.status?.email ? ` (${a.status.email})` : ""}` : a?.status?.email ?? "Removed account"; };
    return h("select", { class: "input select ut-acct", "aria-label": "Account", onchange: (e) => { account = e.target.value; void load(false); } },
      h("option", { value: "", selected: account === "" }, "All accounts"),
      ...heads.map((a) => h("option", { value: a.account, selected: account === a.account }, `${label(a.account)} · ${a.claude_sessions + a.codex_sessions} sessions`)));
  }
  function drawHead(extra) {
    put(head,
      h("div", { class: "ut-seg-group", role: "group", "aria-label": "Time window" }, windowBtn(7), windowBtn(30), windowBtn(90)),
      accountPick(),
      h("span", { class: "grow" }), extra ?? null,
      h("button", { class: "btn btn-sm", type: "button", disabled: loading, onclick: () => void load(true) }, icon("reload"), "Read the logs again"));
  }

  async function load(refresh) {
    loading = true;
    drawHead(h("span", { class: "ut-progress" }, h("span", { class: "ut-pulse" }), "Reading your session logs…"));
    if (!report) put(body, skeleton());
    try {
      const r = await state.client.call("usage.report", { days, refresh: !!refresh, wait: true, ...(account ? { account_id: account } : {}) });
      report = r.report;
      heads = r.accounts ?? [];
      if (account && !heads.some((a) => a.account === account)) account = "";
    } catch (e) {
      toast(`Couldn't read the logs: ${e.message}`);
    } finally {
      loading = false;
    }
    drawHead(report ? h("span", { class: "ut-note" }, `Read ${new Date(report.generated_at).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}`) : null);
    render();
  }
  const skeleton = () => h("div", { class: "us-skel" }, h("i"), h("i"), h("i"));

  function stat(label, value, hint) {
    return h("div", { class: "ut-stat" }, h("div", { class: "ut-stat-n" }, value), h("div", { class: "ut-stat-l" }, label), hint ? h("div", { class: "ut-stat-h" }, hint) : null);
  }

  // ---- Worker start-up size: what the logs show, the three levels, and a measure button ----------
  let measured = null;
  let measuring = false;
  const ENTRY = { "claude-desktop": "Claude desktop app", "sdk-ts": "Opscode and other SDK workers", "sdk-cli": "Opscode and other SDK workers", cli: "Terminal" };
  const LEVELS = [
    ["standard", "Standard", "Workers start like any Claude Code chat (minus MCP servers when lean mode is on)."],
    ["lean", "Lean", "Also leaves out skills and slash commands."],
    ["leanest", "Leanest", "Also ignores your user-level settings, plugins and CLAUDE.md; only the project's count."],
  ];
  function startCard(c) {
    const current = state.engineSettings?.worker_start ?? "lean";
    const evidence = c.start_by_entry.filter((e) => !e.entry.includes("sub-agent")).slice(0, 4);
    const levels = h("div", { class: "ut-levels", role: "radiogroup", "aria-label": "How lean a worker starts" }, ...LEVELS.map(([id, name, hint]) => h("button", { class: "ut-level", type: "button", role: "radio", "aria-checked": String(current === id), dataset: { level: id }, onclick: async () => {
      try { const r = await state.client.call("engines.set", { worker_start: id }); state.engineSettings = r.settings; render(); } catch (e) { toast(e.message); }
    } }, h("span", { class: "ut-level-n" }, name), h("span", { class: "ut-level-h" }, hint))));
    const table = measured ? h("table", { class: "ut-table ut-measure" }, h("tbody", {}, ...measured.map((m) => h("tr", { class: m.level === current ? "cur" : "", dataset: { level: m.level } }, h("td", {}, LEVELS.find((l) => l[0] === m.level)?.[1] ?? m.level), h("td", { class: "num" }, m.tokens ? `${kt(m.tokens)} tokens` : h("span", { class: "ut-err" }, m.error ?? "no answer")))))) : null;
    return h("section", { class: "ut-card", dataset: { card: "start" } },
      h("h3", {}, "How big a worker is before it starts"),
      h("p", { class: "ut-sub" }, "Every Claude Code chat starts with a system prompt, tool list and skills, and re-reads them on every call. Opscode's workers can start leaner; your Normal chats are never changed."),
      evidence.length ? h("ul", { class: "ut-evidence" }, ...evidence.map((e) => h("li", {}, h("span", {}, ENTRY[e.entry] ?? e.entry), h("b", {}, `${e.median_k}k`), h("span", { class: "ut-evidence-s" }, `${e.sessions} chat${e.sessions === 1 ? "" : "s"}, typical start`)))) : null,
      levels,
      h("div", { class: "ut-measure-row" },
        h("button", { class: "btn btn-sm", type: "button", disabled: measuring, onclick: async () => {
          measuring = true; render();
          try { measured = (await state.client.call("engines.measure_start", activeWorkspace() ? { workspace_id: activeWorkspace().id } : {})).results; } catch (e) { toast(e.message); }
          measuring = false; render();
        } }, measuring ? "Measuring…" : "Measure on this computer"),
        h("span", { class: "ut-sub" }, "Sends three tiny Haiku requests (about a cent at list price), one per level.")),
      table);
  }

  function claudeView(r) {
    const c = r.claude;
    const split = c.split;
    const total = split.read + split.write + split.out + split.inp || 1;
    const b = c.burners;
    const rewriteSum = b.rewrites.breaks + b.rewrites.switches + b.rewrites.other;
    const carry = b.tool_carry.reduce((n, t) => n + t.usd, 0);
    const tips = [
      { n: "Long chats", usd: b.long_chats, text: `${c.ctx_over_pct.k200}% of calls carried more than 200k tokens of history. Chats kept under 150k tokens would not pay for the rest.`, fix: "A fresh chat for each task, with a short hand-off." },
      { n: "A heavy starting prompt", usd: b.start_prompt, text: `Every chat starts with about ${b.start_prompt_median_k}k tokens (plugins, skills, tool lists), re-read on every call.`, fix: "Workers start lean, with only the tools the task needs." },
      { n: "Tool output kept in the chat", usd: carry, text: `${b.tool_carry.slice(0, 3).map((t) => `${t.tool} ${kt(t.chars / 4)} tokens`).join(", ")}${b.images ? ` and ${b.images.toLocaleString()} images` : ""} stay in the chat and are re-read afterwards.`, fix: "Logs go through a small model first; screenshots stay small." },
      { n: "Cache rebuilt from scratch", usd: rewriteSum, text: `${b.rewrite_count} rebuilds: ${usd(b.rewrites.breaks)} after a pause of over 5 minutes, ${usd(b.rewrites.switches)} after switching model inside a chat.`, fix: "One model per worker; no waiting on you mid-task." },
      { n: "Big models on small steps", usd: b.small_steps_on_big_models, text: "Opus or Fable doing steps that write under 300 tokens.", fix: "Small chores go to Haiku or Sonnet." },
    ].filter((t) => t.usd > 0.005).sort((a, z) => z.usd - a.usd);
    const maxTip = Math.max(...tips.map((t) => t.usd), 1);

    const sessionRows = c.top_sessions.slice(0, 10).map((s) => h("tr", { class: s.multi_day ? "multi" : "" },
      h("td", {}, h("div", { class: "ut-cell-main" }, s.label?.title || s.first || s.id), h("div", { class: "ut-cell-sub" }, `${s.proj} · ${day(s.start)}${day(s.start) !== day(s.end) ? ` – ${day(s.end)}` : ""}`)),
      h("td", { class: "num" }, s.calls.toLocaleString()),
      h("td", { class: "num" }, `${s.avg_ctx_k}k`),
      h("td", { class: "num" }, usd(s.usd)),
      h("td", {}, h("div", { class: "ut-tags" },
        s.multi_day ? h("span", { class: "ut-tag warn", title: "Ran across several days in one chat" }, "multi-day") : null,
        s.start_ctx_k >= 90 ? h("span", { class: "ut-tag", title: `Starts with ${s.start_ctx_k}k tokens before you type` }, `${s.start_ctx_k}k start`) : null,
        s.label ? h("span", { class: "ut-tag ok", title: s.label.mode ? `A ${s.label.mode.toUpperCase()} chat made in Opscode` : "A chat made in Opscode" }, s.label.mode ? s.label.mode.toUpperCase() : "Opscode") : null))));

    const topProj = c.projects.slice(0, 6);
    const maxP = Math.max(...topProj.map((p) => p.usd), 1);
    const models = c.models.slice(0, 5);
    const maxM = Math.max(...models.map((m) => m.usd), 1);

    return [
      h("div", { class: "ut-stats" },
        stat("Usage value", usd(c.usd), "at API list prices"),
        stat("Model calls", c.calls.toLocaleString(), `${c.sessions} sessions`),
        stat("Average chat size", `${kt(c.avg_context)}`, "tokens re-read per call"),
        stat("Days with work", String(c.active_days), `of ${r.window_days}`)),
      h("section", { class: "ut-card" },
        h("h3", {}, "Where the usage goes"),
        bar(SEGS.map(([k, label, , color]) => ({ label, value: split[k], color }))),
        h("ul", { class: "ut-legend" }, ...SEGS.map(([k, label, hint, color]) => h("li", {}, h("i", { style: `background:${color}` }), h("div", { class: "grow" }, h("div", { class: "ut-legend-t" }, label), h("div", { class: "ut-legend-h" }, hint)), h("div", { class: "ut-legend-v" }, usd(split[k]), h("span", {}, `${pct(split[k], total)}%`)))))),
      c.multi_day.sessions ? h("section", { class: "ut-callout" }, icon("zap"), h("div", {}, h("strong", {}, `${c.multi_day.sessions} chats ran across several days and made ${c.multi_day.usd_share}% of the usage.`), " One chat for days keeps growing, and every message re-reads all of it.")) : null,
      h("section", { class: "ut-card" },
        h("h3", {}, "What burns tokens, and what Opscode does about it"),
        h("p", { class: "ut-sub" }, "Each one is counted on its own, so they overlap. Don't add them up."),
        ...tips.map((t) => h("div", { class: "ut-tip" }, h("div", { class: "ut-tip-head" }, h("span", { class: "ut-tip-n" }, t.n), h("span", { class: "ut-tip-v" }, usd(t.usd))), meter(t.usd, maxTip), h("p", {}, t.text), h("p", { class: "ut-fix" }, icon("check"), t.fix)))),
      startCard(c),
      h("section", { class: "ut-card" },
        h("h3", {}, "The heaviest chats"),
        h("table", { class: "ut-table" }, h("thead", {}, h("tr", {}, h("th", {}, "Chat"), h("th", { class: "num" }, "Calls"), h("th", { class: "num" }, "Size"), h("th", { class: "num" }, "Value"), h("th", {}, ""))), h("tbody", {}, ...sessionRows)),
        c.opscode.sessions ? h("p", { class: "ut-sub" }, `${c.opscode.sessions} of these were made in Opscode (${usd(c.opscode.usd)}).`) : null),
      h("div", { class: "ut-two" },
        h("section", { class: "ut-card" }, h("h3", {}, "Projects"), ...topProj.map((p) => h("div", { class: "ut-line" }, h("span", { class: "ut-line-n" }, p.name), meter(p.usd, maxP), h("span", { class: "ut-line-v" }, usd(p.usd))))),
        h("section", { class: "ut-card" }, h("h3", {}, "Models"), ...models.map((m) => h("div", { class: "ut-line" }, h("span", { class: "ut-line-n" }, MODEL_NAME(m.model)), meter(m.usd, maxM, "#9db4ff"), h("span", { class: "ut-line-v" }, usd(m.usd)))))),
    ];
  }

  function codexView(r) {
    const x = r.codex;
    if (!x) return null;
    const topModel = Object.entries(x.models).sort((a, z) => z[1] - a[1]).slice(0, 4);
    return h("section", { class: "ut-card" },
      h("h3", {}, "Codex"),
      h("div", { class: "ut-stats ut-stats-sm" }, stat("Sessions", String(x.sessions)), stat("Read in", kt(x.input), `${pct(x.cached, x.input)}% from cache`), stat("Written out", kt(x.output)), x.weekly_used !== undefined ? stat("Weekly limit used", `${Math.round(x.weekly_used)}%`) : null),
      x.tiny_sessions > x.sessions / 2 ? h("p", { class: "ut-callout-inline" }, icon("zap"), `${x.tiny_sessions} of ${x.sessions} sessions wrote under 2k tokens (typically ${x.median_output}), but each one first reads its whole starting prompt. Many tiny sessions mostly pay the start-up cost. Opscode batches UI work into one ongoing Codex thread.`) : null,
      h("p", { class: "ut-sub" }, `Models: ${topModel.map(([m, n]) => `${m} (${n})`).join(", ")}.`));
  }

  function render() {
    if (!report) { put(body, h("div", { class: "ut-empty" }, "No session logs found yet. Use Claude Code or Codex, then read the logs again.")); return; }
    const r = report;
    put(body,
      h("p", { class: "ut-disclaimer" }, icon("shield"), "Read from the session logs on this computer; nothing is sent anywhere. Dollar figures are API list prices, for comparing habits and models. They are not what your plan charges."),
      r.claude ? claudeView(r) : h("div", { class: "ut-empty" }, `No Claude Code activity in the last ${r.window_days} days.`),
      codexView(r),
      h("section", { class: "ut-card ut-disk" }, h("h3", {}, "Disk"), h("p", { class: "ut-sub" }, `Claude Code keeps ${gb(r.logs.claude_bytes)} of session logs (${r.logs.claude_files} files) and Codex ${gb(r.logs.codex_bytes)} (${r.logs.codex_files} files). Opscode never deletes these: they are how a chat is resumed.`)));
  }

  return {
    el: root,
    show() { drawHead(); void load(false); },
    progress(p) { if (loading && p?.total) { const el = head.querySelector(".ut-progress"); if (el) el.lastChild.textContent = `Reading your session logs… ${p.done} of ${p.total}`; } },
    ready() { /* load() already awaits the scan */ },
  };
}
