// The Manager page (internally Chief; the word lives in names.js): the Chief's own chat (a welcome until you write to it),
// a Work panel beside it (List, Board, Library), and a Chief settings dialog.

import { h, append } from "./dom.js";
import { icon } from "./icons.js";
import { state, toast } from "./store.js";
import { createChat } from "./chat.js";
import { confirmDialog, showDialog, closeDialog } from "./dialogs.js";
import { MODE_INFO, modeCharacter, modeEmblem } from "./conductor.js";
import { CHIEF_NAME, chiefLabel } from "./names.js";
import { openMenu } from "./popover.js";
import { openModelPicker, engineMark, modelName, effortName } from "./modelpicker.js";
import { accountTitle, accountsOf, planName, signedIn } from "./accounts.js";
import { createCrewDock } from "./crew.js";
import { mountPipeline } from "./islands.js";

const put = (el, ...kids) => { el.replaceChildren(); append(el, kids); };
const isMac = /mac/i.test(navigator.platform);

/** Opscode's own pixel mascots (assets/brand/mascots), served at mascots/<id>.svg. */
export const MASCOTS = ["engineer", "hacker", "wizard", "robot", "fox", "cat", "penguin", "octopus", "raccoon", "frog", "axolotl", "crab", "panda", "capybara", "duck", "hedgehog"];
export const mascotOf = (chief, i = 0) => chief?.avatar && MASCOTS.includes(chief.avatar) ? chief.avatar : MASCOTS[i % MASCOTS.length];
export const mascot = (id, cls = "mascot") => h("img", { class: cls, src: `mascots/${id}.svg`, alt: "", draggable: false });

const STATE = {
  needs_you: ["Needs you", "warn"], proposed: ["Suggested", "warn"], running: ["Running", "run"], waiting: ["Waiting", "muted"],
  review: ["Ready for review", "ok"], queued: ["Queued", "muted"], done: ["Done", "ok"], failed: ["Failed", "bad"], dropped: ["Dropped", "muted"],
};
const LIST_GROUPS = [["needs_you", "Needs you"], ["proposed", "Suggested"], ["running", "Working"], ["review", "Ready for review"], ["queued", "Queued"]];
const BOARD_COLS = [["queued", "Queued", ["queued", "proposed"]], ["running", "Running", ["running", "waiting"]], ["needs_you", "Needs you", ["needs_you"]], ["review", "Review", ["review"]], ["done", "Done", ["done"]]];
const ENGINE = { "claude-code": "Claude Code", codex: "Codex", api: "API key" };
const AUTONOMY = ["Ask", "Start", "Manage"];
const AUTONOMY_HELP = [
  "Starts work only when sure of the project; suggests the rest for you to start.",
  "Starts chats itself and answers their questions from your notes and soul; asks you the rest.",
  "Runs the work: starts, answers and decides, then tells you in one line.",
];
const UPDATES = [["results", "Results"], ["milestones", "Milestones"], ["everything", "Everything"]];
const UPDATES_HELP = ["Only what a chat found or finished.", "Results, plus when work starts and moves on.", "Every step the chats take."];
const EFFORTS = [["low", "Low"], ["medium", "Medium"], ["high", "High"], ["xhigh", "Extra high"], ["max", "Max"]];
const MODELS = [["haiku", "Claude Haiku"], ["sonnet", "Claude Sonnet"], ["opus", "Claude Opus"]];

/** A 3-stop slider like a segmented track, with the chosen label on the right. */
function stops(value, labels, onChange, label) {
  const track = h("div", { class: "cf-slider", role: "slider", tabindex: 0, "aria-label": label, "aria-valuemin": 0, "aria-valuemax": labels.length - 1, "aria-valuenow": value, "aria-valuetext": labels[value] });
  const knob = h("span", { class: "cf-knob" });
  track.style.setProperty("--pos", String(value / (labels.length - 1)));
  append(track, [...labels.map((_, i) => h("span", { class: "cf-stop", style: `--at:${i / (labels.length - 1)}` })), knob]);
  const pick = (x) => { const r = track.getBoundingClientRect(); const v = Math.round(((x - r.left) / r.width) * (labels.length - 1)); onChange(Math.max(0, Math.min(labels.length - 1, v))); };
  track.addEventListener("click", (e) => pick(e.clientX));
  track.addEventListener("keydown", (e) => { if (e.key === "ArrowRight" || e.key === "ArrowUp") onChange(Math.min(labels.length - 1, value + 1)); if (e.key === "ArrowLeft" || e.key === "ArrowDown") onChange(Math.max(0, value - 1)); });
  return h("div", { class: "cf-slider-row" }, track, h("span", { class: "cf-slider-label" }, labels[value]));
}

export function createChiefPage({ openChat, onHeader }) {
  const chatHost = h("div", { class: "cf-chat" });
  const work = h("aside", { class: "cf-work", "aria-label": "Work" });
  const root = h("div", { class: "cf-page pane-surface" }, h("div", { class: "cf-body" }, chatHost, work));
  let chiefId = null;
  let view = null; // { chief, items, queued_notes, running }
  let chat = null;
  let workOpen = true;
  let workView = "list";
  let showUpdates = true;
  let modelChip = null;
  let effortChip = null;
  let dock = null;
  const open = new Set();

  /** "Manager settings" (or "Mode chat settings" for GODMODE / WARLORD / SHINOBI). */
  const noun = () => (view?.chief.mode ? "Mode chat" : CHIEF_NAME.one);
  async function act(fn) { try { return await fn(); } catch (e) { toast(e.message); return undefined; } }
  const save = (patch) => act(() => state.client.call("chief.update", { chief_id: chiefId, ...patch }));
  const projects = () => { const c = view.chief; return c.project_ids.length ? state.workspaces.filter((w) => c.project_ids.includes(w.id)) : state.workspaces; };
  const projectName = (id) => state.workspaces.find((w) => w.id === id)?.name ?? "a removed project";

  async function show(id) {
    if (id !== chiefId) { chiefId = id; chat?.el.remove(); chat = null; view = null; workView = "list"; }
    const v = await act(() => state.client.call("chief.get", { chief_id: id }));
    if (!v) return;
    view = v;
    if (!chat) {
      const c = view.chief;
      const settingsBtn = h("button", { class: "cmp-icon", type: "button", "aria-label": `${noun()} settings`, title: `${noun()} settings`, onclick: () => openSettings() }, icon("sliders"));
      modelChip = h("button", { class: "cmp-model", type: "button", "aria-label": `${noun()} model`, title: `What this ${noun().toLowerCase()} thinks and replies with`, onclick: (e) => modelMenu(e.currentTarget) });
      effortChip = h("button", { class: "cmp-effort", type: "button", "aria-label": `${noun()} effort`, title: "How hard it thinks", onclick: (e) => effortMenu(e.currentTarget) });
      dock = c.mode ? createCrewDock({ openChat }) : null;
      chat = createChat({ id: `chief:${c.id}`, name: c.name, path: "" }, {
        chatId: c.chat_id,
        mode: "read",
        meta: state.chats.find((x) => x.id === c.chat_id),
        chief: { above: dock?.el, welcome: welcome(), placeholder: c.mode ? `Tell ${c.name} what to build` : undefined, left: [settingsBtn], right: [modelChip, effortChip], send: (text, attachments = []) => state.client.call("chief.note", { chief_id: c.id, text, ...(attachments.length ? { attachments } : {}) }) },
      });
      chatHost.replaceChildren(chat.el);
      chat.loadedOnce = true;
      void chat.loadHistory();
    }
    render();
  }

  // ---- header (drawn into the window's pane header) ---------------------------------------------
  function header() {
    const c = view.chief;
    const ps = c.project_ids.length;
    return [
      c.mode ? modeEmblem(c.mode, 24, "mode-emblem mode-emblem-hd") : mascot(mascotOf(c), "mascot mascot-hd"),
      h("span", { class: "cf-name" }, chiefLabel(c)),
      c.mode ? h("span", { class: "cf-conductor", title: MODE_INFO[c.mode]?.line }, "Conductor") : null,
      h("button", { class: "cf-scope no-drag", type: "button", title: "Projects it works in", onclick: () => openSettings("projects") }, icon("folder"), c.mode && ps === 1 ? (state.workspaces.find((w) => w.id === c.project_ids[0])?.name ?? "1 project") : ps ? `${ps} project${ps === 1 ? "" : "s"}` : "All projects"),
      view.running ? h("span", { class: "spin", title: "Thinking…" }) : null,
      h("span", { class: "pane-grow" }),
      h("button", { class: "cf-hbtn no-drag", type: "button", title: `${noun()} settings`, "aria-label": `${noun()} settings`, onclick: () => openSettings() }, icon("sliders")),
      h("button", { class: "cf-hbtn no-drag", type: "button", "aria-pressed": String(showUpdates), title: showUpdates ? "Hide updates from chats" : "Show updates from chats", "aria-label": "Show updates from chats", onclick: () => { showUpdates = !showUpdates; root.classList.toggle("cf-hide-updates", !showUpdates); render(); } }, icon("eye")),
      h("button", { class: "cf-hbtn no-drag", type: "button", "aria-pressed": String(workOpen), title: workOpen ? "Hide work" : "Show work", "aria-label": "Work panel", onclick: () => { workOpen = !workOpen; render(); } }, icon("panel-right")),
    ].filter(Boolean);
  }
  /** A short place for a project: its parent folder and its own name. */
  const shortPath = (p) => p.split("/").filter(Boolean).slice(-2).join("/");

  // ---- welcome (until the first note) -----------------------------------------------------------
  function welcome() {
    const box = h("article", { class: "cf-welcome", "aria-label": `${noun()} says hello` });
    const fill = (text) => { chat?.setDraft(text); };
    const row = ({ ic, title, sub, end, tone = "", onclick }) => h("button", { class: "cf-row", type: "button", onclick },
      h("span", { class: "cf-row-ic" }, ic), h("span", { class: "cf-row-title" }, title), sub ? h("span", { class: "cf-row-sub" }, sub) : null, h("span", { class: "grow" }), end ? h("span", { class: `cf-row-end ${tone}` }, end) : null);
    const card = (label, action, ...rows) => h("section", { class: "cf-card" }, h("div", { class: "cf-card-head" }, h("span", { class: "grow" }, label), action ? h("button", { class: "cf-card-act", type: "button", title: action.title ?? "", onclick: action.onclick }, action.text) : null), ...rows);
    const paint = () => {
      if (!view) return;
      const c = view.chief;
      const ps = projects();
      const first = ps[0]?.name;
      const inP = first ? ` in ${first}` : "";
      const counts = (w) => {
        const items = view.items.filter((i) => i.project_ids.includes(w.id));
        const needs = items.filter((i) => i.state === "needs_you").length;
        const going = items.filter((i) => i.state === "running" || i.state === "waiting").length;
        return needs ? [`${needs} ${needs === 1 ? "needs" : "need"} you`, "warn"] : going ? [`${going} going`, ""] : state.chats.some((x) => x.workspace_id === w.id) ? ["Nothing going", "subtle"] : ["No chats yet", "subtle"];
      };
      put(box,
        h("header", { class: "cf-hello" },
          c.mode ? modeCharacter(c.mode, 5, "mode-char mode-char-hello") : mascot(mascotOf(c), "mascot mascot-xl"),
          h("div", { class: "cf-namepill" }, c.name),
          h("p", { class: "cf-tagline" }, c.mode ? MODE_INFO[c.mode]?.line ?? "" : "I run your chats for you."),
          h("p", { class: "cf-sub" }, c.mode ? "Tell me what to build. I plan it, start short workers for each task, and come to you only for an approval or a decision." : "Say what needs doing. I start the chats, keep them moving and only come to you when one needs you.")),
        card("What I can do", { text: "Teach me", title: "My soul: the rules I keep", onclick: () => openSettings("soul") },
          row({ ic: icon("users"), title: "Start the chats", sub: `“fix the flaky login test${inP}”`, end: "Running", onclick: () => fill(`fix the flaky login test${inP}`) }),
          row({ ic: icon("compose"), title: "Steer a chat that's going", sub: "“tell the login chat to add a test too”", end: "Running", onclick: () => fill("tell the login chat to add a test too") }),
          row({ ic: icon("file"), title: "Remember it for every chat", sub: `“remember:${inP} we never push straight to main”`, end: "Every new chat", onclick: () => fill(`remember:${inP} we never push straight to main`) }),
          row({ ic: icon("zap"), title: "Hold it for later", sub: `“tomorrow 9am: re-run the tests${inP}”`, end: "Queue", onclick: () => fill(`tomorrow 9am: re-run the tests${inP}`) })),
        h("p", { class: "cf-lead" }, ps.length === 0 ? "I work in the projects you add here. There are none yet:" : c.project_ids.length ? `I work in ${ps.length === 1 ? "this project" : `these ${ps.length} projects`}. Click one to write it a note:` : "I work in every project you add here. Click one to write it a note:"),
        card(c.project_ids.length ? "My projects" : "Every project", ps.length ? { text: c.project_ids.length ? "Edit" : "Keep me to a few", onclick: () => openSettings("projects") } : null,
          ...(ps.length ? ps.slice(0, 3).map((w) => { const [end, tone] = counts(w); return row({ ic: icon("folder"), title: w.name, sub: shortPath(w.path), end, tone, onclick: () => fill(`In ${w.name}: `) }); }) : [row({ ic: icon("folder"), title: "No projects yet", sub: "A folder on this computer", end: "Add one", onclick: () => toast("Add a project from the sidebar first.") })]),
          ps.length > 3 ? h("button", { class: "cf-more", type: "button", onclick: () => openSettings("projects") }, `and ${ps.length - 3} more`) : null));
    };
    box.paint = paint;
    queueMicrotask(paint);
    return box;
  }

  // ---- Work panel ------------------------------------------------------------------------------------
  function itemRow(it, compact = false) {
    const [label, tone] = STATE[it.state] ?? [it.state, ""];
    const expanded = !compact && (open.has(it.id) || it.state === "needs_you" || it.state === "proposed");
    const answer = h("input", { class: "input", placeholder: "Your answer", "aria-label": `Answer for #${it.ref}` });
    const send = (text) => act(async () => { await state.client.call("chief.items.answer", { item_id: it.id, text }); toast(`Sent to the ${noun().toLowerCase()}`); });
    answer.addEventListener("keydown", (e) => { if (e.key === "Enter" && answer.value.trim()) send(answer.value.trim()); });
    return h("div", { class: "cf-item", dataset: { item: it.id, state: it.state } },
      h("button", { class: "cf-item-head", type: "button", "aria-expanded": String(expanded), onclick: () => { if (open.has(it.id)) open.delete(it.id); else open.add(it.id); if (compact) { workView = "list"; open.add(it.id); } render(); } },
        h("span", { class: `cf-state-dot ${tone}` }), h("span", { class: "cf-ref" }, `#${it.ref}`), h("span", { class: "grow cf-item-title" }, it.title),
        it.pinned ? h("span", { class: "cf-tag", title: "Pinned: it stays where you put it" }, "Pinned") : null, compact ? null : h("span", { class: `cf-tag ${tone}` }, label)),
      expanded ? h("div", { class: "cf-item-body" },
        it.project_ids.length ? h("div", { class: "cf-meta" }, icon("folder"), it.project_ids.map(projectName).join(", "), it.guess ? " · a guess" : "") : null,
        it.detail ? h("div", { class: "cf-detail" }, it.detail) : null,
        it.ask ? h("div", { class: "cf-ask" },
          h("div", { class: "cf-ask-q" }, it.ask.question),
          h("div", { class: "cf-meta" }, `Recommended: ${it.ask.recommended}${it.ask.go_ahead_at ? ` · goes ahead at ${new Date(it.ask.go_ahead_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}` : it.ask.must_wait ? " · waits for you" : ""}`),
          h("div", { class: "cf-ask-row" }, answer,
            h("button", { class: "btn btn-sm", type: "button", onclick: () => answer.value.trim() && send(answer.value.trim()) }, "Answer"),
            h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: () => send(`Go with your recommendation: ${it.ask.recommended}`) }, "Use recommendation"))) : null,
        it.state === "proposed" ? h("div", { class: "cf-ask-row" },
          h("span", { class: "cf-meta grow" }, `${it.pending?.length ?? 1} chat${(it.pending?.length ?? 1) === 1 ? "" : "s"} ready${it.pending?.length ? `: ${it.pending.map((p) => `${ENGINE[p.engine] ?? p.engine} ${p.role}`).join(", ")}` : ""}`),
          h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: () => act(() => state.client.call("chief.items.start", { item_id: it.id })) }, "Start")) : null,
        it.automation ? h("div", { class: "cf-chatrow" }, icon("zap"), h("span", { class: "grow" }, `Automation ${it.automation.name}`), h("span", { class: "cf-tag" }, it.automation.status)) : null,
        ...it.chats.map((c) => h("div", { class: "cf-chatrow" },
          h("span", { class: `cf-state-dot ${c.state === "running" ? "run" : c.state === "needs_you" ? "warn" : c.state === "failed" ? "bad" : "muted"}` }),
          h("span", { class: "grow" }, h("span", {}, `${ENGINE[c.engine] ?? c.engine} · ${c.role}`), c.status ? h("span", { class: "cf-meta-inline" }, ` · ${c.status}`) : null, c.report ? h("div", { class: "cf-report" }, c.report) : null),
          h("button", { class: "btn btn-ghost btn-sm", type: "button", onclick: () => openChat(c.workspace_id, null, c.chat_id) }, "Open chat"))),
        h("div", { class: "cf-item-foot" },
          h("span", { class: "grow cf-meta" }, `Updated ${new Date(it.updated_at).toLocaleString([], { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" })}`),
          h("button", { class: "icon-btn", type: "button", "aria-label": `More for #${it.ref}`, onclick: (e) => openMenu(e.currentTarget, [
            { label: it.pinned ? "Unpin" : "Pin it here", onSelect: () => act(() => state.client.call("chief.items.update", { item_id: it.id, pinned: !it.pinned })) },
            ...(it.state !== "queued" ? [{ label: "Queue", onSelect: () => act(() => state.client.call("chief.items.update", { item_id: it.id, state: "queued" })) }] : []),
            ...(it.state !== "done" ? [{ label: "Mark done", icon: "check", onSelect: () => act(() => state.client.call("chief.items.update", { item_id: it.id, state: "done" })) }] : []),
            { separator: true },
            { label: "Drop", icon: "trash", danger: true, onSelect: () => act(() => state.client.call("chief.items.update", { item_id: it.id, state: "dropped" })) },
          ], { up: false, width: 200 }) }, icon("more")))) : null);
  }

  // ---- pipelines: the stage strip, each stage's mode, and the gate only you can open ------------------
  const STAGE_NAME = { spec: "Spec", gap: "Gap", plan: "Plan", ui: "UI & assets", build: "Build", test: "Test", review: "Review", deliver: "Deliver" };
  const galleries = new Map(); // pipeline id -> { key, data }
  /** The images a pipeline made, shown at its gate; fetched once per change of the pipeline. */
  function gallery(pl) {
    const box = h("div", { class: "cf-gallery", "aria-label": "Images this pipeline made" });
    const key = `${pl.id}:${pl.updated_at}`;
    const paint = (g) => {
      if (!g?.images?.length) { box.hidden = true; return; }
      box.hidden = false;
      put(box, ...g.images.map((im) => h("button", { class: "cf-thumb", type: "button", title: im.path, onclick: () => showImage(im) }, h("img", { src: im.data_url, alt: im.path.split("/").pop(), loading: "lazy", draggable: false }))),
        g.more ? h("span", { class: "cf-meta" }, `and ${g.more} more in ${g.folder}/`) : null);
    };
    const have = galleries.get(pl.id);
    if (have?.key === key) paint(have.data);
    else { box.hidden = true; void state.client.call("chief.pipeline.gallery", { pipeline_id: pl.id }).then((g) => { galleries.set(pl.id, { key, data: g }); paint(g); }).catch(() => {}); }
    return box;
  }
  function showImage(im) {
    const el = h("div", { class: "dialog cf-image-dialog", role: "dialog", "aria-label": im.path },
      h("div", { class: "dialog-head" }, h("h2", {}, im.path.split("/").pop()), h("button", { class: "icon-btn", type: "button", "aria-label": "Close", onclick: closeDialog }, icon("x"))),
      h("img", { class: "cf-image-big", src: im.data_url, alt: im.path }),
      h("div", { class: "cf-meta" }, `${im.path} · ${Math.round(im.bytes / 1024)} KB`));
    showDialog(el);
  }
  const jobs = new Map(); // pipeline id -> { el, island } (kept across renders so the animation is not reset)
  /** The pipeline's progress as assistant-ui's Job progress (weighted stages, estimate, stop). */
  function jobOf(pl) {
    let j = jobs.get(pl.id);
    if (!j) {
      const el = h("div", { class: "cf-job" });
      j = { el, island: mountPipeline(el, { stop: (id) => act(async () => { if (await confirmDialog({ title: `Stop "${pl.title}"?`, body: "The running stage is dropped. Files it wrote stay.", confirm: "Stop", danger: true })) await state.client.call("chief.pipeline.stop", { pipeline_id: id }); }) }) };
      jobs.set(pl.id, j);
    }
    const cur = pl.stages[pl.current];
    const item = cur?.item_id ? view.items.find((i) => i.id === cur.item_id) : undefined;
    const chats = item?.chats ?? [];
    const running = chats.filter((c) => c.state === "running").length;
    const finished = chats.filter((c) => c.state === "idle" || c.state === "stopped").length;
    const stageProgress = pl.state === "gate" ? 1 : chats.length ? Math.min(0.9, 0.15 + (0.75 * finished) / chats.length) : 0.05;
    const now = pl.state === "gate" ? "Waits for your OK" : running ? `${running} ${running === 1 ? "worker" : "workers"} on it` : chats.length ? "Checking the work" : "Starting";
    j.island.render({ id: pl.id, title: pl.title, state: pl.state, stages: pl.stages.map((s) => ({ id: s.id, name: STAGE_NAME[s.id], state: s.state })), current: pl.current, createdAt: Date.parse(pl.created_at), updatedAt: Date.parse(pl.updated_at), stageProgress, now });
    return j.el;
  }

  function pipelineCard(pl) {
    const cur = pl.stages[pl.current];
    const stage = (s) => {
      const tone = s.state === "done" ? "ok" : s.state === "gate" ? "warn" : s.state === "running" ? "run" : "muted";
      const editable = s.state !== "done" && s.state !== "skipped";
      return h("button", { class: `cf-stage ${tone}${s.state === "skipped" ? " skipped" : ""}`, type: "button", dataset: { stage: s.id, state: s.state }, disabled: !editable,
        title: s.state === "skipped" ? `${STAGE_NAME[s.id]}: skipped` : `${STAGE_NAME[s.id]} on ${MODE_INFO[s.mode]?.name ?? s.mode}${editable ? " (click to change)" : ""}`,
        onclick: (e) => editable && openMenu(e.currentTarget, Object.entries(MODE_INFO).map(([id, m]) => ({ label: m.name, ...(id === s.mode ? { icon: "check" } : {}), onSelect: () => act(() => state.client.call("chief.pipeline.mode", { pipeline_id: pl.id, stage: s.id, mode: id })) })), { up: false, width: 180 }) },
        s.state !== "skipped" ? modeEmblem(s.mode, 14) : null, h("span", {}, STAGE_NAME[s.id]), s.gate && s.state !== "skipped" ? icon("key") : null);
    };
    return h("section", { class: "cf-pipeline", dataset: { pipeline: pl.id, state: pl.state } },
      h("div", { class: "cf-pl-head" }, h("span", { class: "grow" }),
        h("span", { class: `cf-tag ${pl.state === "gate" ? "warn" : pl.state === "done" ? "ok" : "run"}` }, pl.state === "gate" ? "Needs your OK" : pl.state === "done" ? "Done" : `${STAGE_NAME[cur?.id] ?? ""} running`),
        pl.state !== "done" ? h("button", { class: "icon-btn", type: "button", "aria-label": `More for ${pl.title}`, onclick: (e) => openMenu(e.currentTarget, [
          { label: "Stop this pipeline", icon: "trash", danger: true, onSelect: () => act(async () => { if (await confirmDialog({ title: `Stop "${pl.title}"?`, body: "The running stage is dropped. Files it wrote stay.", confirm: "Stop", danger: true })) await state.client.call("chief.pipeline.stop", { pipeline_id: pl.id }); }) },
        ], { up: false, width: 200 }) }, icon("more")) : null),
      jobOf(pl),
      h("div", { class: "cf-stages" }, ...pl.stages.map(stage)),
      pl.state === "gate" && cur ? gateBox(pl) : null);
  }

  /** What waits for the person at a gate: the stage's summary, its images, what to change, Send back, Approve. In the chat it also names the pipeline. */
  function gateBox(pl, inChat = false) {
    const cur = pl.stages[pl.current];
    const why = h("input", { class: "input", placeholder: "What should change? (for Send back)", "aria-label": "What should change" });
    const back = () => why.value.trim() ? act(async () => { await state.client.call("chief.pipeline.reject", { pipeline_id: pl.id, text: why.value.trim() }); toast("Sent back to the Conductor"); }) : why.focus();
    why.addEventListener("keydown", (e) => { if (e.key === "Enter") back(); });
    return h("div", { class: `cf-gate${inChat ? " cf-gate-chat" : ""}`, dataset: { pipeline: pl.id } },
      inChat ? h("div", { class: "cf-gate-head" }, icon("key"), h("strong", {}, `${STAGE_NAME[cur.id]} of "${pl.title}" needs your OK`), modeEmblem(cur.mode, 16)) : h("div", { class: "cf-ask-q" }, `${STAGE_NAME[cur.id]} is ready for you.`),
      cur.summary ? h("div", { class: "cf-meta" }, cur.summary) : null,
      h("div", { class: "cf-meta" }, `Files: ${pl.folder}/`),
      gallery(pl),
      h("div", { class: "cf-ask-row" }, why,
        h("button", { class: "btn btn-sm", type: "button", onclick: back }, "Send back"),
        h("button", { class: "btn btn-primary btn-sm", type: "button", onclick: () => act(async () => { await state.client.call("chief.pipeline.approve", { pipeline_id: pl.id }); toast(`${STAGE_NAME[cur.id]} approved`); }) }, "Approve")));
  }

  function renderWork() {
    work.hidden = !workOpen;
    if (!workOpen) return;
    const tabs = h("div", { class: "cf-views", role: "radiogroup", "aria-label": "Show the work as" }, ...[["list", "List"], ["board", "Board"], ["library", "Done"]].map(([id, label]) =>
      h("button", { type: "button", role: "radio", "aria-checked": String(workView === id), onclick: () => { workView = id; render(); } }, label)));
    const head = h("div", { class: "cf-work-head" }, h("span", { class: "cf-work-tab" }, icon("check"), "Work"), h("span", { class: "grow" }), tabs);
    const items = view.items;
    const live = items.filter((i) => !["done", "failed", "dropped"].includes(i.state));
    const empty = (title, text) => h("div", { class: "cf-empty" }, icon("users"), h("strong", {}, title), h("span", {}, text));
    let body;
    if (workView === "library") {
      const lib = items.filter((i) => i.state === "done" || i.state === "failed").sort((a, b) => b.updated_at.localeCompare(a.updated_at));
      body = lib.length ? h("div", { class: "cf-list" }, ...lib.map((i) => itemRow(i))) : empty("Nothing finished yet", "Finished work collects here with what each chat found.");
    } else if (!live.length && workView === "list") {
      body = empty("Nothing on the board", `Tell ${view.chief.name} what needs doing. Each piece of work shows here, with the chats doing it.`);
    } else if (workView === "board") {
      body = h("div", { class: "cf-columns" }, ...BOARD_COLS.map(([id, title, states]) => {
        const col = items.filter((i) => states.includes(i.state)).sort((a, b) => b.updated_at.localeCompare(a.updated_at));
        return h("section", { class: "cf-col", dataset: { col: id } }, h("div", { class: "cf-col-head" }, h("span", { class: "grow" }, title), h("span", { class: "cf-count" }, String(col.length))), h("div", { class: "cf-col-body" }, ...col.slice(0, 30).map((i) => itemRow(i, true))));
      }));
    } else {
      body = h("div", { class: "cf-list" }, ...LIST_GROUPS.map(([st, title]) => {
        const list = live.filter((i) => (st === "running" ? i.state === "running" || i.state === "waiting" : i.state === st)).sort((a, b) => Number(!!b.pinned) - Number(!!a.pinned) || b.updated_at.localeCompare(a.updated_at));
        return list.length ? h("section", { class: "cf-group" }, h("div", { class: "cf-group-head" }, h("span", { class: "grow" }, title), h("span", { class: "cf-count" }, String(list.length))), ...list.map((i) => itemRow(i))) : null;
      }));
    }
    const pipes = workView === "library" ? [] : (view.pipelines ?? []).filter((p) => p.state !== "done" || Date.now() - Date.parse(p.updated_at) < 86_400_000);
    if (pipes.length && !live.length && workView === "list") body = null;
    put(work, head, h("div", { class: "cf-work-body" }, ...pipes.map(pipelineCard), body));
  }

  // ---- composer chips (model + effort of the Chief itself) ----------------------------------------------
  function renderChips() {
    if (!modelChip) return;
    paintBrainChip(modelChip);
    effortChip.hidden = true;
  }
  const mascotMark = () => icon("mark");
  function modelMenu(anchor) {
    const b = view.chief.brain;
    openModelPicker(anchor, {
      engines: ["claude-code", "api"],
      value: { engine: b.engine, model: b.model, effort: b.effort },
      onChange: (v) => {
        if (v.engine === "api" && v.provider) void state.client.call("provider.select", { id: v.provider }).catch(() => {});
        void save({ brain: { engine: v.engine === "api" ? "api" : "claude-code", ...(v.engine !== "api" && v.model ? { model: v.model } : {}), ...(v.engine !== "api" && v.effort ? { effort: v.effort } : {}) } });
      },
    });
  }
  function effortMenu(anchor) { modelMenu(anchor); }
  /** The one chip: mark, model name, effort, caret. */
  function paintBrainChip(chip) {
    const b = view.chief.brain;
    put(chip, engineMark(b.engine, "icon em"), h("span", {}, modelName({ engine: b.engine, model: b.model })), b.engine === "api" ? null : h("span", { class: "cmp-effort-in" }, effortName(b.effort ?? "medium")), icon("chevron-down", "icon chip-caret"));
    chip.dataset.engine = b.engine;
  }

  // ---- Chief settings dialog ------------------------------------------------------------------------------
  function openSettings(focus) {
    const c = view.chief;
    const soul = h("textarea", { class: "cf-soul", spellcheck: false, "aria-label": "Soul" }, c.soul);
    const soulMsg = h("span", { "aria-live": "polite" }, `${isMac ? "⌘" : "Ctrl+"}S saves now`);
    const saveSoul = async () => { if (soul.value === view.chief.soul) return; soulMsg.textContent = "Saving…"; const r = await save({ soul: soul.value }); soulMsg.textContent = r ? "Saved" : "Couldn't save"; setTimeout(() => (soulMsg.textContent = `${isMac ? "⌘" : "Ctrl+"}S saves now`), 1600); };
    soul.addEventListener("keydown", (e) => { if ((isMac ? e.metaKey : e.ctrlKey) && e.key.toLowerCase() === "s") { e.preventDefault(); void saveSoul(); } });
    soul.addEventListener("blur", () => void saveSoul());
    const name = h("input", { class: "input cf-name-input", value: c.name, maxLength: 40, "aria-label": "Name" });
    name.addEventListener("change", () => name.value.trim() && save({ name: name.value.trim() }));
    const access = h("select", { class: "input select", "aria-label": "Permissions for the chats it starts", onchange: (e) => save({ worker_access: e.target.value }) },
      ...[["read", "Read only"], ["edit", "Edit files (asks before commands)"], ["full", "Full access"]].map(([v, t]) => h("option", { value: v, selected: c.worker_access === v }, t)));
    const workers = h("select", { class: "input select", "aria-label": "Workers run on", onchange: (e) => save({ worker_engine: e.target.value }) },
      ...[["claude-code", "Claude Code"], ["codex", "Codex"], ["api", "API key"]].map(([v, t]) => h("option", { value: v, selected: c.worker_engine === v, disabled: v !== "api" && !(state.engines ?? []).find((e) => e.id === v)?.found }, t)));
    const num = (label, key, min, max) => { const el = h("input", { class: "input cf-num", type: "number", min, max, value: c[key], "aria-label": label }); el.addEventListener("change", () => { const n = Math.round(Number(el.value)); if (n >= min && n <= max) save({ [key]: n }); else toast(`${label}: ${min} to ${max}`); }); return el; };
    const srow = (title, help, control) => h("div", { class: "cfs-row" }, h("div", { class: "cfs-text" }, h("div", { class: "cfs-title" }, title), help ? h("div", { class: "cfs-help" }, help) : null), control);
    const modelBtn = h("button", { class: "cmp-model", type: "button", onclick: (e) => modelMenu(e.currentTarget) });
    const effortBtn = h("button", { class: "cmp-effort", type: "button", onclick: (e) => effortMenu(e.currentTarget) });
    const paintModel = () => { paintBrainChip(modelBtn); effortBtn.hidden = true; };
    paintModel();
    const autRow = h("div");
    const updRow = h("div");
    const paintSliders = () => {
      const cc = view.chief;
      put(autRow, srow("Autonomy", AUTONOMY_HELP[cc.autonomy - 1], stops(cc.autonomy - 1, AUTONOMY, (v) => save({ autonomy: v + 1 }), "Autonomy")));
      const u = UPDATES.findIndex(([id]) => id === cc.updates);
      put(updRow, srow("Updates", UPDATES_HELP[Math.max(0, u)], stops(Math.max(0, u), UPDATES.map(([, t]) => t), (v) => save({ updates: UPDATES[v][0] }), "Updates")));
    };
    paintSliders();
    // Which Claude Code / Codex account this Chief's own chat and its workers run on (only when there is a choice).
    const accRows = h("div");
    const paintAccounts = () => {
      const rows = [["claude-code", "Claude Code"], ["codex", "Codex"]].filter(([e]) => accountsOf(e).filter(signedIn).length > 1 || view.chief.accounts?.[e]).map(([e, label]) => {
        const cur = view.chief.accounts?.[e] ?? "";
        const sel = h("select", { class: "input select", "aria-label": `${label} account`, onchange: (ev) => save({ accounts: { [e]: ev.target.value } }) },
          h("option", { value: "", selected: !cur }, "Whichever new chats use"),
          ...accountsOf(e).filter((a) => signedIn(a) || a.id === cur).map((a) => h("option", { value: a.id, selected: a.id === cur }, `${accountTitle(a)}${a.status?.plan ? ` · ${planName(a.status.plan)}` : ""}`)));
        return srow(`${label} account`, "Its chats and workers run on this account, and its plan limits decide where work goes.", sel);
      });
      put(accRows, ...rows);
    };
    paintAccounts();
    const projBox = h("div", { class: "cfs-card" });
    const paintProjects = () => {
      const cc = view.chief;
      const mine = state.workspaces.filter((w) => cc.project_ids.includes(w.id));
      const others = state.workspaces.filter((w) => !cc.project_ids.includes(w.id));
      put(projBox,
        mine.length ? null : h("div", { class: "cfs-proj" }, icon("folder"), h("div", { class: "cfs-text" }, h("div", { class: "cfs-title" }, "Every project"), h("div", { class: "cfs-help" }, `It works in ${state.workspaces.length === 1 ? "your one project" : `all ${state.workspaces.length} of your projects`}, and in any you add later. Add one to keep it to a few.`))),
        ...mine.map((w) => h("div", { class: "cfs-proj" }, icon("folder"), h("div", { class: "cfs-text" }, h("div", { class: "cfs-title" }, w.name), h("div", { class: "cfs-help" }, w.path.replace(/^\/Users\/[^/]+/, "~"))),
          h("button", { class: "icon-btn", type: "button", "aria-label": `Remove ${w.name}`, onclick: () => save({ project_ids: cc.project_ids.filter((x) => x !== w.id) }) }, icon("x")))),
        others.length ? h("button", { class: "cfs-proj cfs-add", type: "button", onclick: (e) => openMenu(e.currentTarget, others.map((w) => ({ label: w.name, icon: "folder", onSelect: () => save({ project_ids: [...cc.project_ids, w.id] }) })), { up: false, width: 260 }) }, h("span", { class: "cfs-plus" }, icon("plus")), h("span", { class: "cfs-title" }, "Add project")) : null);
    };
    paintProjects();
    const avatars = h("div", { class: "cf-avatars" });
    const paintAvatars = () => put(avatars, ...MASCOTS.map((m) => h("button", { class: "cf-avatar", type: "button", "aria-pressed": String(mascotOf(view.chief) === m), title: m, "aria-label": `Picture ${m}`, onclick: () => save({ avatar: m }) }, mascot(m, "mascot"))));
    paintAvatars();
    const sec = (title, help, ...kids) => h("section", { class: "cfs-sec" }, title ? h("h3", {}, title) : null, help ? h("p", { class: "cfs-sechelp" }, help) : null, ...kids);
    const dlg = h("div", { class: "dialog cfs", role: "dialog", "aria-modal": "true", "aria-label": `${noun()} settings` },
      h("div", { class: "cfs-head" }, h("h2", {}, `${noun()} settings`), h("span", { class: "grow" }), h("button", { class: "icon-btn", type: "button", "aria-label": "Close", onclick: closeDialog }, icon("x"))),
      h("div", { class: "cfs-body" },
        sec(null, null, h("div", { class: "cfs-card" },
          srow("Name", null, name),
          srow("Picture", null, avatars),
          srow("Model", "What it thinks and replies with.", h("div", { class: "cfs-inline" }, modelBtn, effortBtn)),
          srow("Permissions", "What the chats it starts may do without asking.", access))),
        sec("Working with you", null, h("div", { class: "cfs-card" }, autRow, updRow)),
        sec("Projects", "It sees the chats and folders in these, and starts chats only here.", projBox),
        sec("Workers", "Your crew rules in the soul say which engine does what; this is the default.", h("div", { class: "cfs-card" },
          srow("Workers run on", null, workers),
          accRows,
          srow("Chats at once", "More wait for a free slot.", num("Chats at once", "max_parallel", 1, 8)),
          srow("Chats per day", "A safety limit.", num("Chats per day", "daily_chats", 1, 200)),
          srow("Go ahead after", "Minutes before an unanswered question goes ahead with its recommendation (Start level). 0 waits for you.", num("Go ahead after", "ask_wait_minutes", 0, 1440)))),
        sec("Soul", "Who it is and what it always keeps in mind. A ## Crew rules section goes to every chat it starts.", h("div", { class: "cfs-soul" }, soul, h("div", { class: "cfs-soul-foot" }, h("span", {}, "Markdown"), soulMsg))),
        h("div", { class: "cfs-danger" }, h("button", { class: "btn btn-ghost btn-sm danger", type: "button", onclick: async () => {
          const mode = !!view.chief.mode;
          if (!(await confirmDialog({ title: `${mode ? "Delete" : "Remove"} ${chiefLabel(view.chief)}?`, body: "Its board and its own chat are removed. Worker chats it started stay in their projects.", confirm: mode ? "Delete chat" : `Remove ${CHIEF_NAME.one}`, danger: true }))) return;
          await act(() => state.client.call("chief.remove", { chief_id: chiefId }));
        } }, view.chief.mode ? "Delete this chat" : `Remove this ${CHIEF_NAME.one}`))));
    dlg.refresh = () => { paintModel(); paintSliders(); paintProjects(); paintAvatars(); paintAccounts(); };
    showDialog(dlg);
    settingsDlg = dlg;
    if (focus === "soul") { soul.focus(); soul.scrollIntoView({ block: "center" }); }
    if (focus === "projects") projBox.scrollIntoView({ block: "center" });
  }
  let settingsDlg = null;

  function render() {
    if (!view) return;
    onHeader?.(header());
    renderChips();
    renderWork();
    dock?.setView(view);
    chat?.el.querySelector(".chief-welcome")?.firstChild?.paint?.();
    if (settingsDlg?.isConnected) settingsDlg.refresh();
  }

  return {
    el: root,
    /** Accounts changed: the account choices in an open Chief settings dialog follow. */
    accountsChanged() { if (settingsDlg?.isConnected) settingsDlg.refresh(); },
    show,
    header: () => (view ? header() : []),
    get chiefId() { return chiefId; },
    /** Sends the first message from a new-chat box that was in a mode (after show()). */
    sendFirst: (text, files) => chat?.sendNow(text, files),
    owns: (chatId) => !!view && view.chief.chat_id === chatId,
    onEvent: (ev) => chat?.onEvent(ev),
    /** Every turn event in Opscode: the dock keeps the ones from this Conductor's workers. */
    onWorkerEvent: (ev) => dock?.onEvent(ev),
    onChanged: (p) => {
      if (p.chief_id !== chiefId || p.removed) return;
      view = { chief: p.chief, items: p.items, pipelines: p.pipelines ?? [], queued_notes: p.queued_notes, running: p.running };
      render();
    },
  };
}
