// The Conductor's live dock, inside the composer box above the input. This file follows the
// turn events Opscode already broadcasts (no model tokens) and turns them into a snapshot; the
// drawing is a React island built from assistant-ui elements (src/islands/dock.tsx): gates as
// Approval cards with the stage's images and a feedback box, an Agent status pill per running
// worker, a Task card per worker with its Tool timeline and the images it is making.
// Patterns: ChatGPT's Codex view, Caveman, assistant-ui (docs/live-activity-research.md, docs/ui-elements-plan.md).

import { h } from "./dom.js";
import { icon } from "./icons.js";
import { state, toast } from "./store.js";
import { modelName } from "./modelpicker.js";
import { MODE_INFO } from "./conductor.js";
import { emblemUrl } from "./conductorart.js";
import { mountDock } from "./islands.js";

// Tool -> [live verb, past verb]; the detail is the rest of the tool's one-line summary.
const VERBS = {
  Read: ["Reading", "Read"], Write: ["Writing", "Wrote"], Edit: ["Editing", "Edited"], MultiEdit: ["Editing", "Edited"], NotebookEdit: ["Editing", "Edited"],
  Bash: ["Running", "Ran"], Grep: ["Searching", "Searched"], Glob: ["Finding files", "Found files"], WebSearch: ["Searching the web", "Searched the web"], WebFetch: ["Reading the web", "Read the web"],
  Task: ["Delegating", "Delegated"], TodoWrite: ["Planning", "Planned"],
  run_command: ["Running", "Ran"], write_file: ["Editing", "Edited"], web_search: ["Searching the web", "Searched the web"], mcp: ["Calling a tool", "Called a tool"], image_generation: ["Creating image", "Created image"],
};
const EDITS = new Set(["Write", "Edit", "MultiEdit", "NotebookEdit", "write_file"]);
const KIND_LABEL = { fix: "Fix", feature: "Build", chore: "Chore", plan: "Plan", brand: "Brand kit", art: "Art direction", asset: "Assets", ui: "Screens", visual: "Visual review" };
const STAGE_NAME = { spec: "Spec", gap: "Gap report", plan: "Plan", ui: "UI & assets", build: "Build", test: "Test", review: "Review", deliver: "Deliver" };
const KEEP_MS = 90_000; // a finished worker's card stays this long
const fileOf = (summary) => summary.replace(/^(Read|Write|Edit|Run|Search the web:)\s+/, "").trim();
const svgOf = (engine) => icon(engine === "claude-code" ? "engine-claude" : engine === "codex" ? "engine-codex" : "key").outerHTML;

const emblems = new Map(); // mode -> data url
function emblem(mode, then) {
  if (!mode || !MODE_INFO[mode]) return undefined;
  if (emblems.has(mode)) return emblems.get(mode);
  emblems.set(mode, undefined);
  void emblemUrl(mode, 32).then((u) => { emblems.set(mode, u); then(); }).catch(() => {});
  return undefined;
}

/** The dock: mount it in the composer box, feed it the Chief view and every turn event. */
export function createCrewDock({ openChat }) {
  const root = h("div", { class: "cw-dock", "aria-live": "polite", "aria-label": "Live work" });
  let view = null;
  let island = null;
  const live = new Map(); // chat_id -> worker state from its events
  const galleries = new Map(); // pipeline id -> { key, images }
  const act = async (fn, ok) => { try { await fn(); if (ok) toast(ok); } catch (e) { toast(e.message); } };
  const handlers = {
    approve: (id) => act(() => state.client.call("chief.pipeline.approve", { pipeline_id: id }), "Approved"),
    sendBack: (id, text) => act(() => state.client.call("chief.pipeline.reject", { pipeline_id: id, text }), "Sent back to the Conductor"),
    openChat: (chatId) => { const c = state.chats.find((x) => x.id === chatId); if (c) openChat(c.workspace_id, null, chatId); },
  };

  function worker(chatId) {
    let w = live.get(chatId);
    if (!w) {
      w = { chatId, verb: "Starting", detail: "", running: true, started: Date.now(), ended: 0, tools: new Map(), steps: [], files: new Set(), images: new Map(), writing: false, waiting: false };
      live.set(chatId, w);
    }
    return w;
  }
  const itemChat = (chatId) => {
    for (const it of view?.items ?? []) { const c = it.chats.find((x) => x.chat_id === chatId); if (c) return { item: it, chat: c }; }
    return null;
  };

  function onEvent(ev) {
    if (!view || !itemChat(ev.chat_id)) return;
    const w = worker(ev.chat_id);
    if (ev.type === "started") { w.running = true; w.ended = 0; w.verb = "Thinking"; w.detail = ""; w.waiting = false; }
    else if (ev.type === "tool_start") {
      const [now] = VERBS[ev.tool] ?? ["Using a tool", "Used a tool"];
      const target = ev.tool === "image_generation" ? (ev.summary ?? "").replace(/^Generate image:?\s*/, "") : fileOf(ev.summary ?? "");
      w.tools.set(ev.call_id, { tool: ev.tool, summary: ev.summary ?? "" });
      w.steps.push({ id: ev.call_id, tool: ev.tool, verb: now, chip: target.slice(0, 60) || ev.tool });
      if (w.steps.length > 40) w.steps.shift();
      w.writing = false; w.waiting = false;
      if (ev.tool === "image_generation") {
        w.images.set(ev.call_id, { id: ev.call_id, prompt: target, generating: true, src: undefined, failed: false });
        w.verb = "Making images"; w.detail = `${[...w.images.values()].filter((x) => x.generating).length} in progress`;
      } else { w.verb = now; w.detail = target; }
      if (EDITS.has(ev.tool)) w.files.add(target.split(", ")[0]);
    } else if (ev.type === "tool_end") {
      const t = w.tools.get(ev.call_id);
      const step = w.steps.find((s) => s.id === ev.call_id);
      if (step && t) step.verb = (VERBS[t.tool] ?? ["", "Used"])[1];
      if (t?.tool === "image_generation") {
        const im = w.images.get(ev.call_id);
        if (im) {
          const path = (ev.output ?? "").trim();
          if (ev.is_error || !/\.(png|jpe?g|webp|gif)$/i.test(path)) { im.generating = false; im.failed = !!ev.is_error; }
          else void state.client.call("chief.worker_image", { chat_id: ev.chat_id, path }).then((r) => { im.src = r.data_url; im.generating = false; paint(); }).catch(() => { im.generating = false; paint(); });
        }
      }
      if (t && EDITS.has(t.tool)) for (const f of fileOf(t.summary).split(", ")) if (f) w.files.add(f);
      w.verb = "Thinking"; w.detail = "";
    } else if (ev.type === "delta") { if (w.writing) return; w.writing = true; w.verb = "Writing"; w.detail = "the report"; }
    else if (ev.type === "approval_request") { w.waiting = true; w.verb = "Waiting for your OK"; w.detail = ev.summary ?? ""; }
    else if (ev.type === "approval_resolved") { w.waiting = false; }
    else if (ev.type === "completed" || ev.type === "failed" || ev.type === "interrupted") { w.running = false; w.ended = Date.now(); w.failed = ev.type === "failed"; w.waiting = false; }
    paint();
  }

  function setView(v) {
    view = v;
    // Workers running now whose events we missed (the page opened late) still show.
    for (const it of v.items) for (const c of it.chats) if (c.state === "running" && !live.has(c.chat_id)) { const w = worker(c.chat_id); w.started = Date.parse(c.started_at) || Date.now(); w.verb = "Working"; }
    paint();
  }

  /** A gate's images: fetched once per change of its pipeline. */
  function galleryOf(pl) {
    const key = `${pl.id}:${pl.updated_at}`;
    const have = galleries.get(pl.id);
    if (have?.key === key) return have.images;
    galleries.set(pl.id, { key, images: have?.images ?? [] });
    void state.client.call("chief.pipeline.gallery", { pipeline_id: pl.id }).then((g) => {
      galleries.set(pl.id, { key, images: g.images.map((im) => ({ id: im.path, src: im.data_url, alt: im.path.split("/").pop(), caption: im.path.split("/").pop() })) });
      paint();
    }).catch(() => {});
    return have?.images ?? [];
  }

  function reportLine(report, key) {
    return new RegExp(`(?:^|· )${key}: (.*?)(?= · [A-Z][a-z]+: |$)`).exec(report ?? "")?.[1];
  }

  function snapshot() {
    const now = Date.now();
    for (const [id, w] of live) if (!w.running && w.ended && now - w.ended > KEEP_MS) live.delete(id);
    const gates = (view.pipelines ?? []).filter((p) => p.state === "gate").map((pl) => {
      const cur = pl.stages[pl.current];
      return { id: pl.id, title: pl.title, stage: STAGE_NAME[cur.id] ?? cur.id, ...(cur.summary ? { summary: cur.summary } : {}), folder: pl.folder, modeName: MODE_INFO[cur.mode]?.name ?? cur.mode, images: galleryOf(pl) };
    });
    const workers = [...live.values()].map((w) => {
      const ic = itemChat(w.chatId);
      if (!ic) return null;
      const meta = state.chats.find((x) => x.id === w.chatId) ?? {};
      const mode = ic.item.mode ?? view.chief.mode;
      const kind = ic.chat.role === "review" ? (ic.chat.kind === "visual" ? "Visual review" : "Review") : KIND_LABEL[ic.chat.kind];
      const found = reportLine(ic.chat.report, "Found");
      const check = reportLine(ic.chat.report, "Check");
      const em = emblem(mode, paint);
      return {
        chatId: w.chatId, title: meta.title || ic.item.title, engine: ic.chat.engine, engineSvg: svgOf(ic.chat.engine), model: modelName({ engine: ic.chat.engine, model: meta.model }),
        ...(kind ? { kind } : {}), ...(mode && MODE_INFO[mode] ? { modeName: MODE_INFO[mode].name } : {}), ...(em ? { emblem: em } : {}),
        state: w.running ? (w.waiting ? "waiting" : "working") : w.failed ? "failed" : "done", started: w.started, ...(w.ended ? { ended: w.ended } : {}),
        verb: w.verb, detail: w.detail, steps: w.steps.map((s) => ({ ...s })), files: [...w.files].filter(Boolean), images: [...w.images.values()].map((x) => ({ ...x })),
        ...(found ? { found } : {}), ...(check ? { check } : {}),
      };
    }).filter(Boolean).sort((a, b) => Number(b.state === "working" || b.state === "waiting") - Number(a.state === "working" || a.state === "waiting") || b.started - a.started);
    // A worker whose chat grew too big, replaced by a fresh one (shown for a few minutes).
    const handoffs = [];
    for (const it of view.items) for (const c of it.chats) {
      if (!c.handoff || now - Date.parse(c.handoff.at) > 5 * 60_000) continue;
      const old = state.chats.find((x) => x.id === c.chat_id) ?? {};
      const next = c.handed_to ? state.chats.find((x) => x.id === c.handed_to) ?? {} : null;
      handoffs.push({
        id: c.chat_id,
        from: `${modelName({ engine: c.engine, model: old.model })} · ${Math.round(c.handoff.tokens / 1000)}k tokens`,
        to: next ? `Fresh ${modelName({ engine: c.engine, model: next.model })}` : "Fresh worker (waits for a slot)",
        reason: `Its chat passed ${Math.round(c.handoff.limit / 1000)}k tokens, so a fresh worker continues "${old.title ?? it.title}" with a short brief instead of the whole history.`,
        carried: ["Its last report", "Your message", "Changes already on disk"],
        settled: !!c.handed_to,
      });
    }
    return { gates, workers, handoffs };
  }

  let queued = false;
  function paint() {
    if (!view || queued) return;
    queued = true;
    queueMicrotask(() => {
      queued = false;
      if (!island) island = mountDock(root, handlers);
      island.render(snapshot());
    });
  }

  // Finished cards leave on their own.
  setInterval(() => { if ([...live.values()].some((w) => !w.running)) paint(); }, 15_000);
  return { el: root, onEvent, setView, paint };
}
