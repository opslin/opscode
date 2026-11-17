// Chat surface: transcript + composer, streaming over `turn.event`.

import { h } from "./dom.js";
import { icon } from "./icons.js";
import { renderMarkdown } from "./markdown.js";
import { createMic } from "./voice.js";
import { createVoiceMode, voiceModeAvailable } from "./voicechat.js";
import { createSpeakControls } from "./speak.js";
import { state, toast, nav, activeWorkspace } from "./store.js";
import { openMenu, closeMenu } from "./popover.js";
import { confirmDialog } from "./dialogs.js";
import { MODES, modeInfo } from "./modes.js";
import { openModelPicker, engineMark, modelName, effortName, effortLevel } from "./modelpicker.js";
import { pixelBurst, pixelReveal, launchFx, endLaunch } from "./pixelfx.js";
import { mountMessage, mountStage } from "./islands.js";
import { attachmentTile, createAttachments, thumbLoader } from "./attach.js";
import { MODE_INFO, MODE_ORDER, modeCharacter, modeEmblem, crewTheme } from "./conductor.js";
import { accountForChat, accountMenuItems, accountShort, accountTitle, accountsOf, avatar, planName, signedIn } from "./accounts.js";

/**
 * A chat view. A "draft" has no chatId yet: the chat is created on the first
 * message. opts: { chatId?, mode?, onBind(chatId), onSelectProject(id) }
 */
export function createChat(workspace, opts = {}) {
  let chatId = opts.chatId ?? null;
  let mode = opts.mode ?? state.settings?.default_mode ?? "supervised";
  const conversation = h("div", { class: "conversation", tabindex: -1 });
  const jump = h("button", { class: "chat-jump", type: "button", hidden: true, "aria-label": "Jump to the latest", onclick: () => { conversation.scrollTo({ top: conversation.scrollHeight, behavior: "smooth" }); jump.hidden = true; } }, icon("arrow-down"), h("span", {}, "Latest"));
  const inner = h("div", { class: "conversation-inner" });
  conversation.append(inner);

  const emptyNote = h("p", { class: "empty-note" });
  const projectLink = h("button", { class: "empty-project", type: "button", title: "The project this chat works in" }, workspace.name);
  // New chat: an animated mascot in the middle, the composer at the bottom, a mode switch
  // (Normal / GODMODE / WARLORD / SHINOBI) that recolours the frame and the background.
  const canChooseCrew = !opts.chief && typeof opts.onStartMode === "function";
  let crew = "normal";
  const mascotBox = h("div", { class: "nc-mascot", "aria-hidden": "true" });
  const who = h("span", { class: "nc-who" }, "What should we");
  const crewLine = h("p", { class: "nc-crew-line" });
  const emptyHead = h(
    "div",
    { class: "empty empty-new" },
    mascotBox,
    h("h1", {}, who, " build in ", projectLink, "?"),
    crewLine,
    emptyNote,
  );
  const crewBtn = (id) => {
    const normal = id === "normal";
    return h("button", { class: "crew-opt", type: "button", role: "radio", dataset: { crew: id }, style: `--cc:${crewTheme(id).c1}`, title: normal ? "Normal chat: you and one model" : `${MODE_INFO[id].name}: ${MODE_INFO[id].line}`, onclick: () => setCrew(id) },
      normal ? h("img", { class: "mode-emblem", src: "brand/opscode-mark-128.png", alt: "", width: 16, height: 16, draggable: false }) : modeEmblem(id, 16),
      h("span", {}, normal ? "Normal" : MODE_INFO[id].name));
  };
  const crewSwitch = h("div", { class: "crew-switch", role: "radiogroup", "aria-label": "How to work", hidden: !canChooseCrew }, crewBtn("normal"), ...MODE_ORDER.map(crewBtn));
  const stageEl = h("div", { class: "nc-stage", "aria-hidden": "true" });
  const stage = opts.chief ? null : mountStage(stageEl);

  const textarea = h("textarea", { rows: 1, placeholder: "Describe a task, or @ to add files…", "aria-label": "Message" });
  const send = h("button", { class: "send", type: "button", "aria-label": "Send message", disabled: true }, icon("arrow-up"));
  const plusBtn = h("button", { class: "cmp-icon", type: "button", "aria-label": "Add files and more", title: "Add files and more" }, icon("plus"));
  const settingsBtn = h("button", { class: "cmp-icon", type: "button", "aria-label": "Chat settings", title: "Chat settings" }, icon("sliders"));
  const modeBadge = h("button", { class: "cmp-mode", type: "button", hidden: true, title: "Permissions" });
  const engineChip = h("button", { class: "cmp-model", type: "button", "aria-label": "Model", title: "Choose the engine and model" }, icon("mark"), h("span", {}), icon("chevron-down", "icon chip-caret"));
  // Which Claude Code / Codex account this chat runs on (hidden for an API key).
  const accountChip = h("button", { class: "cmp-account", type: "button", hidden: true, "aria-label": "Account" });
  const effortChip = h("button", { class: "cmp-effort", type: "button", "aria-label": "Effort", title: "How hard it thinks", hidden: true }, h("span", {}), icon("chevron-down", "icon chip-caret"));
  // This chat's engine choice (a draft keeps it until the chat is created on the first message).
  let pick = { engine: opts.meta?.engine ?? null, model: opts.meta?.model ?? null, effort: opts.meta?.effort ?? null, account: null };
  // The account each engine runs on in this chat (set by the first message) and whether the engine has a session here already.
  let pins = opts.meta?.accounts ?? {};
  let hasSession = !!opts.meta?.engine_session;
  let usage = opts.meta?.usage ?? null;
  let connectors = opts.meta?.connectors ?? null;
  const projectChip = h("button", { class: "cmp-foot-chip", type: "button", "aria-label": "Project", title: workspace.path }, icon("folder"), h("span", {}, workspace.name));
  const branchChip = h("span", { class: "cmp-foot-chip", hidden: true, title: "Git branch" }, icon("branch"), h("span", {}));
  const machineChip = h("span", { class: "cmp-foot-chip", title: "Runs on this computer" }, icon("laptop"), h("span", {}, "This Mac"));
  const ring = h("button", { class: "cmp-ring", type: "button", title: "", "aria-label": "Context: open the overview" }, h("span", { class: "cmp-ring-dial" }), h("span", { class: "cmp-ring-text" }, "0%"));
  ring.addEventListener("click", () => nav.openOverview?.());
  // Photos, files and folders added with + (or ⌘U, paste, drag and drop) wait here above the text until the message is sent.
  const attach = createAttachments(workspace, { onChange: () => { syncControls(); vox?.attachChanged(); } });
  // Dictation: speak and the words fill the box (Apple's on-device recognizer; renderer/voice.js).
  const mic = createMic({ textarea, workspace, isVisible: () => root.isConnected && !!root.offsetParent && !vox?.active(), onText: () => textarea.dispatchEvent(new Event("input", { bubbles: true })), onSend: () => void submit(), onNote: (file) => attach.addPaths([file]) });
  // "Attach to message" on a file link: only the chat whose composer is on screen takes it.
  window.addEventListener("opscode:attach-paths", (e) => {
    if (!root.isConnected || !root.offsetParent || !Array.isArray(e.detail?.paths)) return;
    void attach.addPaths(e.detail.paths);
    textarea.focus();
  });
  // Voice mode: a spoken conversation with a front agent that briefs the worker (renderer/voicechat.js). Normal chats only.
  // Its own button above the box (the small mic in the box stays: it types what you say).
  const talkBtn = h("button", { class: "vox-launch", type: "button", hidden: true, "aria-label": "Start voice mode", title: "Voice mode: talk to the agent. It answers out loud and briefs the worker." },
    h("span", { class: "vl-bars", "aria-hidden": "true" }, ...Array.from({ length: 5 }, () => h("i"))),
    h("span", { class: "vl-label" }, "Voice mode"));
  let vox = null;
  const composer = h(
    "div",
    { class: "composer-wrap" },
    h("div", { class: "composer-top" }, crewSwitch, h("span", { class: "pane-grow" }), talkBtn),
    h("div", { class: "composer" }, attach.el, textarea,
      h("div", { class: "composer-controls" }, plusBtn, settingsBtn, modeBadge, h("span", { class: "pane-grow" }), accountChip, engineChip, effortChip, mic.timer, mic.el, send)),
    h("div", { class: "composer-under" }, projectChip, branchChip, machineChip, h("span", { class: "pane-grow" }), ring),
  );

  const root = h("div", { class: "chat pane-surface", dataset: { empty: "true", crew: "normal" } }, stageEl, emptyHead, conversation, jump, composer);

  // Voice mode: the stage sits where the message box was, the Voice model chip beside the worker's, the big microphone
  // takes the small one's place (dictation stays on ⌥Space and in the + menu).
  if (!opts.chief) {
    const box = composer.querySelector(".composer");
    vox = createVoiceMode({
      workspace, root, composerBox: box, textarea, attach, talkBtn,
      getChatId: () => chatId,
      bindChat: (id) => { if (chatId === id) return; chatId = id; opts.onBind?.(id); void loadHistory(); },
      getWorker: () => {
        const eng = currentEngine();
        const account = eng !== "api" ? (pick.account ?? pins[eng]) : undefined;
        return { engine: eng, ...(pick.model ? { model: pick.model } : {}), ...(pick.effort ? { effort: pick.effort } : {}), ...(account ? { account_id: account } : {}), mode };
      },
      showWorker: () => scrollDown(),
      browserWcId: () => nav.browserWcId?.(workspace.id) ?? null,
      onActive: (on) => {
        talkBtn.dataset.active = String(on);
        talkBtn.title = on ? "End voice mode (Esc)" : "Voice mode: talk to the agent. It answers out loud and briefs the worker.";
        talkBtn.setAttribute("aria-label", on ? "End voice mode" : "Start voice mode");
        engineChip.title = on ? "WORKER: the engine and model that does the coding (reads and edits files, runs commands) when you ask for a change" : "Choose the engine and model";
        talkBtn.querySelector(".vl-label").textContent = on ? "End voice" : "Voice mode";
      },
    });
    const ctl = box.querySelector(".composer-controls");
    box.insertBefore(vox.el, ctl);
    ctl.insertBefore(vox.chip, accountChip);
    ctl.insertBefore(vox.voiceChip, accountChip);
    talkBtn.addEventListener("click", () => { if (vox.active()) void vox.leave(); else void vox.enter(); });
    // Always shown in Normal. If this Mac cannot do voice mode, pressing it says why (vox.enter checks again).
    talkBtn.hidden = crew !== "normal";
    void voiceModeAvailable().then((ok) => { talkBtn.dataset.unavailable = String(!ok); });
  }

  function syncStage() {
    if (!stage) return;
    const t = crewTheme(crew);
    stage.render(root.dataset.empty === "true" ? { mode: crew, stars: t.stars, trail: t.trail, dot: t.dot, ping: t.ping } : null);
  }
  function setCrew(id) {
    const changed = id !== crew;
    crew = id;
    const t = crewTheme(id);
    root.dataset.crew = id;
    root.style.setProperty("--crew-1", t.c1);
    root.style.setProperty("--crew-2", t.c2);
    for (const b of crewSwitch.children) b.setAttribute("aria-checked", String(b.dataset.crew === id));
    const normal = id === "normal";
    if (vox) talkBtn.hidden = !normal;
    mascotBox.dataset.crew = id;
    mascotBox.replaceChildren(normal
      ? h("img", { class: "nc-bot", src: "mascots/robot.svg", alt: "", draggable: false })
      : modeCharacter(id, 5, "mode-char nc-char"));
    who.textContent = normal ? "What should we" : `What should ${MODE_INFO[id].name}`;
    crewLine.textContent = normal ? "You and one model." : `${MODE_INFO[id].line} A Conductor runs the crew.`;
    textarea.placeholder = normal ? "Describe a task, or @ to add files…" : `Tell ${MODE_INFO[id].name} what to build…`;
    syncStage();
    if (changed && !normal) requestAnimationFrame(() => pixelBurst(mascotBox, 3));
  }

  if (opts.chief) {
    for (const el of [settingsBtn, modeBadge, engineChip, effortChip, accountChip]) el.style.display = "none";
    const ctl = composer.querySelector(".composer-controls");
    for (const el of opts.chief.left ?? []) ctl.insertBefore(el, ctl.firstChild);
    for (const el of opts.chief.right ?? []) ctl.insertBefore(el, send);
    composer.querySelector(".composer-under").style.display = "none";
    // The Conductor's live dock (workers, images being made, gates) sits inside the composer box, above the input.
    if (opts.chief.above) composer.insertBefore(opts.chief.above, composer.querySelector(".composer"));
    emptyHead.replaceChildren(opts.chief.welcome);
    emptyHead.className = "chief-welcome";
    root.classList.add("chat-chief");
  }
  const turns = new Map(); // turn_id -> { text, status, body, status el }
  const userTexts = [];
  let runningTurn = null;
  let pendingRender = false;

  const setEmpty = () => {
    const empty = inner.childElementCount === 0;
    root.dataset.empty = String(empty);
    emptyHead.hidden = !empty;
    conversation.hidden = empty;
    textarea.placeholder = opts.chief ? opts.chief.placeholder ?? "Tell it anything" : empty ? (crew === "normal" ? "Describe a task, or @ to add files…" : `Tell ${MODE_INFO[crew].name} what to build…`) : "Ask for a change, / for commands, @ to add…";
    crewSwitch.hidden = !canChooseCrew || !empty || chatId !== null;
    syncStage();
  };

  // ---- chips: project, branch, permissions, model, context ----
  const syncChips = () => {
    const m = modeInfo(mode);
    modeBadge.hidden = mode === "supervised";
    modeBadge.dataset.mode = mode;
    modeBadge.replaceChildren(icon(m.icon), h("span", {}, m.short));
    const pickable = chatId === null && inner.childElementCount === 0 && state.workspaces.length > 1;
    projectChip.disabled = !pickable;
    projectLink.disabled = !pickable;
    projectChip.querySelector("span").textContent = workspace.name;
    projectLink.textContent = workspace.name;
    syncRing();
    if (Date.now() - branchAt > 5000) void refreshBranch();
  };
  function syncRing() {
    if (usage?.context_tokens) {
      const win = usage.context_window ?? 200000;
      const pct = Math.min(100, Math.round((usage.context_tokens / win) * 100));
      ring.style.setProperty("--pct", String(pct));
      ring.querySelector(".cmp-ring-text").textContent = `${pct}%`;
      ring.title = `${usage.context_tokens.toLocaleString()} of ${win.toLocaleString()} tokens in context · this chat used ${usage.input_tokens.toLocaleString()} in, ${usage.output_tokens.toLocaleString()} out, ${usage.cached_tokens.toLocaleString()} cached`;
      return;
    }
    let chars = userTexts.reduce((n, t) => n + t.length, 0);
    for (const t of turns.values()) for (const p of t.parts) chars += p.kind === "text" ? p.text.length : (p.detail?.length ?? 0) + (p.output?.length ?? 0);
    const tokens = Math.round(chars / 4);
    const pct = Math.min(100, Math.round((tokens / 200000) * 100));
    ring.style.setProperty("--pct", String(pct));
    ring.querySelector(".cmp-ring-text").textContent = `${pct}%`;
    ring.title = `About ${pct}% of a 200k-token context (≈${tokens.toLocaleString()} tokens, estimated from the text)`;
  }
  let branchAt = 0;
  async function refreshBranch() {
    branchAt = Date.now();
    try {
      const { env } = await state.client.call("workspace.env", { workspace_id: workspace.id });
      branchChip.hidden = !env.git;
      branchChip.querySelector("span").textContent = env.branch ?? "";
    } catch { branchChip.hidden = true; }
  }
  async function chooseMode(next) {
    if (next === mode) return;
    if (next === "full" && !(await confirmDialog({ title: "Give this chat full access?", body: "The agent will edit files and run commands without asking. It still cannot leave this project's folder, but a command can do anything your account can inside it.", confirm: "Use full access", danger: true }))) return;
    if (chatId) {
      try { await state.client.call("chat.set_mode", { chat_id: chatId, mode: next }); } catch (err) { toast(err.message); return; }
    }
    mode = next;
    syncChips();
  }
  // What this project does about new git branches (answered on the branch card, changed here).
  let branchRule = "ask";
  const BRANCH_CHOICES = [
    { id: "ask", label: "Ask me each time", description: "A card asks before a new branch is created" },
    { id: "current", label: "Stay on the current branch", description: "Agents never create branches here" },
    { id: "allow", label: "Allow new branches", description: "Agents may create them without asking" },
  ];
  const setBranchRule = async (rule) => {
    try { await state.client.call("branch.rule.set", { workspace_id: workspace.id, rule }); branchRule = rule; toast(rule === "ask" ? "New branches: I'll ask" : rule === "current" ? "New branches: stay on the current branch" : "New branches: allowed"); }
    catch (err) { toast(err.message); }
  };
  const openSettings = async (anchor) => {
    if (!opts.chief && workspace.id) { try { branchRule = (await state.client.call("branch.rule", { workspace_id: workspace.id })).rule; } catch { /* keep the last known */ } }
    openSettingsMenu(anchor);
  };
  const openSettingsMenu = (anchor) => openMenu(anchor, [
    { heading: "Permissions" },
    ...MODES.map((m) => ({ label: m.label, description: m.description, icon: m.icon, checked: m.id === mode, onSelect: () => void chooseMode(m.id) })),
    { separator: true },
    { heading: "New git branches" },
    ...BRANCH_CHOICES.map((c) => ({ label: c.label, description: c.description, icon: "branch", checked: c.id === branchRule, onSelect: () => void setBranchRule(c.id) })),
    { separator: true },
    { label: "Skills…", icon: "file", onSelect: () => nav.openSettings("skills") },
    { label: "Sub-agents…", icon: "users", onSelect: () => nav.openSettings("agents") },
  ], { width: 320 });
  settingsBtn.addEventListener("click", () => openSettings(settingsBtn));
  modeBadge.addEventListener("click", () => openSettings(modeBadge));
  const insertAtCaret = (text) => {
    const pos = textarea.selectionStart ?? textarea.value.length;
    const before = textarea.value.slice(0, pos);
    const pad = before && !/\s$/.test(before) ? " " : "";
    textarea.value = `${before}${pad}${text}${textarea.value.slice(pos)}`;
    const at = before.length + pad.length + text.length;
    textarea.focus();
    textarea.setSelectionRange(at, at);
    autosize();
  };
  const addMenu = [
    { label: "Add files or photos", icon: "paperclip", shortcut: "⌘U", onSelect: () => void attach.pick("files") },
    { label: "Add folder", icon: "folder", onSelect: () => void attach.pick("folder") },
  ];
  // A voice note is saved in the project; a Conductor's own chat has no project folder, so it only dictates.
  const voiceNoteItem = { label: "Record a voice note", description: "Keeps the recording and its text", icon: "mic", onSelect: () => mic.note() };
  const voiceOk = () => !mic.el.hidden;
  plusBtn.addEventListener("click", () => openMenu(plusBtn, opts.chief ? addMenu : [
    ...addMenu,
    ...(voiceOk() ? [voiceNoteItem] : []),
    { separator: true },
    { label: "Mention a project file", description: "Type @ and pick one", icon: "at", onSelect: () => { insertAtCaret("@"); void mentionMenu(); } },
    { label: "Commands and skills", description: "Run a skill with /", icon: "file", onSelect: () => { textarea.value = "/"; autosize(); textarea.focus(); skillMenu(); } },
  ], { width: 300 }));
  const EFFORT_LABEL = { low: "Low", medium: "Medium", high: "High", xhigh: "Extra high", max: "Max" };
  const engineInfo = (id) => (state.engines ?? []).find((e) => e.id === id);
  const currentEngine = () => pick.engine ?? state.engineSettings?.default_engine ?? "api";
  async function choose(next) {
    if (chatId) {
      try { await state.client.call("chat.set_engine", { chat_id: chatId, engine: next.engine, ...(next.model ? { model: next.model } : {}), ...(next.effort ? { effort: next.effort } : {}) }); }
      catch (e) { toast(e.message); return; }
    }
    pick = { engine: next.engine, model: next.model ?? null, effort: next.effort ?? null, account: next.engine === pick.engine ? pick.account : null };
    refreshEngine();
  }
  /** The account chip: who this chat runs on, and a menu to move it to another signed-in account. */
  function paintAccountChip() {
    const eng = currentEngine();
    const list = eng && eng !== "api" ? accountsOf(eng) : [];
    const a = list.length ? list.find((x) => x.id === (pick.account ?? pins[eng])) ?? accountForChat(eng, pins) : null;
    accountChip.hidden = !a || !signedIn(a);
    if (!a || !signedIn(a)) return;
    accountChip.replaceChildren(avatar(a, 16), h("span", {}, accountShort(a)));
    accountChip.title = `${accountTitle(a)}${a.status?.plan ? ` · ${planName(a.status.plan)}` : ""}. This chat runs on this account. Click to change.`;
  }
  async function chooseAccount(eng, a) {
    const current = pick.account ?? pins[eng];
    if (a.id === current) return;
    if (chatId) {
      if (hasSession && !(await confirmDialog({ title: `Move this chat to ${accountTitle(a)}?`, body: "It carries on there as a new session, with the conversation so far as context. Work the old account had cached is not carried over.", confirm: "Move chat" }))) return;
      try { await state.client.call("chat.set_account", { chat_id: chatId, account_id: a.id }); } catch (e) { toast(e.message, 6000); return; }
      pins = { ...pins, [eng]: a.id };
      hasSession = false;
    } else pick.account = a.id;
    paintAccountChip();
  }
  accountChip.addEventListener("click", () => {
    const eng = currentEngine();
    if (!eng || eng === "api") return;
    const cur = (pick.account ?? pins[eng]) ?? accountForChat(eng, pins)?.id;
    openMenu(accountChip, [...accountMenuItems(eng, cur, (a) => void chooseAccount(eng, a)), { separator: true }, { label: "Manage accounts…", icon: "sliders", onSelect: () => nav.openSettings("models") }], { width: 320 });
  });
  engineChip.addEventListener("click", () => openModelPicker(engineChip, {
    value: { engine: currentEngine(), model: pick.model ?? undefined, effort: pick.effort ?? undefined },
    defaults: state.engineSettings ? { engine: state.engineSettings.default_engine, model: state.engineSettings.default_model } : undefined,
    onMakeDefault: (v) => state.client.call("engines.set", { default_engine: v.engine, default_model: v.engine === "api" ? "" : v.model ?? "" }).then((r) => nav.setEngines?.(r.engines, r.settings)).catch((e) => toast(e.message)),
    onChange: (v) => {
      if (v.engine === "api" && v.provider) void state.client.call("provider.select", { id: v.provider }).catch((e) => toast(e.message));
      if (v.engine === pick.engine && effortLevel(v.effort) > effortLevel(pick.effort)) requestAnimationFrame(() => pixelBurst(engineChip.querySelector(".cmp-effort-in") ?? engineChip, effortLevel(v.effort)));
      void choose({ engine: v.engine, model: v.model, effort: v.effort });
    },
  }));

  const pickProject = (anchor) => openMenu(anchor, [{ heading: "Work in" }, ...state.workspaces.map((w) => ({ label: w.name, icon: "folder", checked: w.id === workspace.id, onSelect: () => opts.onSelectProject?.(w.id) }))], { width: 280 });
  projectChip.addEventListener("click", () => pickProject(projectChip));
  projectLink.addEventListener("click", () => pickProject(projectLink));

  const nearBottom = () => conversation.scrollHeight - conversation.scrollTop - conversation.clientHeight < 80;
  const scrollDown = () => { conversation.scrollTop = conversation.scrollHeight; jump.hidden = true; };
  // Scroll anchor: new output never pulls you down while you read above; a pill takes you back.
  conversation.addEventListener("scroll", () => { if (nearBottom()) jump.hidden = true; }, { passive: true });

  const syncControls = () => {
    const running = runningTurn !== null;
    const hasInput = !!textarea.value.trim() || attach.count > 0;
    send.disabled = opts.chief ? !hasInput && !running : !running && !hasInput;
    const stopping = running && !(opts.chief && hasInput);
    send.replaceChildren(icon(stopping ? "stop" : "arrow-up", stopping ? "icon stop" : "icon"));
    send.setAttribute("aria-label", stopping ? "Stop" : "Send message");
  };

  function addUser(text, event = false, attached = []) {
    userTexts.push(text);
    dateLine();
    const load = thumbLoader(workspace.id);
    inner.append(event
      ? h("div", { class: "msg msg-event" }, icon("zap"), h("span", {}, text))
      : h("div", { class: "msg msg-user" },
        attached.length ? h("div", { class: "att-row" }, ...attached.map((a) => attachmentTile(a, { load }))) : null,
        text ? h("div", { class: "bubble" }, text) : null));
    setEmpty();
    syncChips();
  }

  function ensureAssistant(turnId, parts = [], status = "streaming", error) {
    let t = turns.get(turnId);
    if (t) return t;
    const body = h("div", { class: "parts" });
    const note = h("div", { class: "msg-status", hidden: true });
    const copy = h("button", { class: "icon-btn", type: "button", title: "Copy", "aria-label": "Copy reply", onclick: async () => {
      try { await navigator.clipboard.writeText(textOf(t)); toast("Copied"); } catch { toast("Couldn't copy"); }
    } }, icon("copy"));
    const worked = h("div", { class: "msg-worked", hidden: true });
    const handoffEl = h("div", { class: "msg-handoff", hidden: true });
    const at = h("span", { class: "msg-time" });
    // 🔊 Read this reply aloud with Pocket TTS on this Mac (renderer/speak.js).
    const speak = createSpeakControls(() => ({ key: turnId, text: () => textOf(t), get node() { return el; } }));
    const el = h("div", { class: "msg msg-assistant" }, handoffEl, worked, body, note, h("div", { class: "msg-actions" }, copy, speak, at));
    dateLine();
    inner.append(el);
    t = { turnId, parts, status, error, body, note, el, worked, handoffEl, at, startedAt: status === "streaming" ? Date.now() : null, endedAt: null };
    // The reply itself is a React island of assistant-ui elements (src/islands/message.tsx).
    t.island = mountMessage(body, {
      approve: (callId, allow, remember) => { const part = toolPart(t, callId); if (part) void decide(t, part, allow, remember); },
      markdown: (text) => renderMarkdown(opts.chief ? text.replace(/\[\[(\d+)\]\]/g, "#$1").replace(/\[\[chat:[^\]]+\]\]/g, "a chat") : text, { root: workspace.path }),
      ...(opts.chief ? {} : { continue: () => resend("Continue from where you stopped."), retry: () => resend(userTexts.at(-1) ?? "") }),
    });
    turns.set(turnId, t);
    paint(t);
    setEmpty();
    return t;
  }

  /** "Took over from Codex · ~5.2k tokens": this turn started on another engine than the chat's last one. */
  function showHandoff(t, info) {
    if (!info || !t.handoffEl) return;
    const engine = (id) => (String(id).startsWith("claude-code") ? "Claude Code" : String(id).startsWith("codex") ? "Codex" : String(id).startsWith("antigravity") ? "Antigravity" : String(id).startsWith("qoder") ? "Qoder" : "the built-in agent");
    const size = info.tokens >= 1000 ? `${(info.tokens / 1000).toFixed(1)}k` : String(info.tokens);
    t.handoffEl.textContent = info.reason === "limit"
      ? `${engine(info.from)} hit its limit · continued in ${engine(info.to)}${info.tokens ? ` · ~${size} tokens` : ""}`
      : `${info.kind === "update" ? "Caught up on" : "Took over from"} ${engine(info.from)}${info.kind === "update" ? "'s work" : ""} · ~${size} tokens${info.via === "inject" ? " · as history" : ""}`;
    t.handoffEl.dataset.reason = info.reason ?? "";
    t.handoffEl.title = `${info.from} → ${info.to}. Opscode handed over the task record (plan, decisions, changed files, commands, your recent messages).`;
    t.handoffEl.hidden = false;
  }

  const textOf = (t) => t.parts.filter((p) => p.kind === "text").map((p) => p.text).join("");

  async function decide(t, part, allow, remember) {
    try { await state.client.call("turn.approve", { turn_id: t.turnId, call_id: part.call_id, allow, ...(remember ? { remember } : {}) }); if (remember) branchRule = remember; }
    catch (err) { toast(err.message); }
  }

  function paint(t) {
    if (t.startedAt && t.status !== "streaming") t.endedAt ??= Date.now();
    t.island.render({ turnId: t.turnId, parts: t.parts.map((p) => ({ ...p })), status: t.status, ...(t.error ? { error: t.error } : {}), ...(t.startedAt ? { startedAt: t.startedAt } : {}), ...(t.endedAt ? { endedAt: t.endedAt } : {}) });
    // Stopped / failed / "Worked 6s" are drawn by the island (Stopped run, Error state, Run activity).
    t.note.hidden = true;
    t.worked.hidden = true;
    t.el.querySelector(".msg-actions").hidden = t.status === "streaming" || textOf(t) === "";
    if (t.endedAt) t.at.textContent = new Date(t.endedAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  }

  /** "Today Sun 15 Nov" above the first message of the day. */
  let dated = false;
  function dateLine() {
    if (dated || !opts.chief) return;
    dated = true;
    const d = new Date();
    inner.append(h("div", { class: "msg-date" }, h("span", {}, `Today ${d.toLocaleDateString([], { weekday: "short", day: "numeric", month: "short" })}`)));
  }

  function schedule(t) {
    t.dirty = true;
    if (pendingRender) return;
    pendingRender = true;
    requestAnimationFrame(() => {
      pendingRender = false;
      const stick = nearBottom();
      for (const x of turns.values()) if (x.dirty) { x.dirty = false; paint(x); }
      if (stick) scrollDown();
      else if (runningTurn) jump.hidden = false;
    });
  }

  const toolPart = (t, id) => t.parts.find((p) => p.kind === "tool" && p.call_id === id);

  function onEvent(ev) {
    // The launch animation ends when real work shows up in the chat on screen.
    if (ev.type !== "started" && root.offsetParent !== null) endLaunch();
    const t = ensureAssistant(ev.turn_id);
    switch (ev.type) {
      case "handoff":
        showHandoff(t, ev.handoff);
        break;
      case "started":
        t.status = "streaming";
        t.startedAt ??= Date.now();
        runningTurn = ev.turn_id;
        break;
      case "delta": {
        runningTurn = ev.turn_id;
        const last = t.parts[t.parts.length - 1];
        if (last?.kind === "text") last.text += ev.text ?? "";
        else t.parts.push({ kind: "text", text: ev.text ?? "" });
        schedule(t);
        break;
      }
      case "tool_start":
        t.parts.push({ kind: "tool", call_id: ev.call_id, tool: ev.tool, summary: ev.summary, detail: ev.detail, status: "running" });
        schedule(t);
        break;
      case "approval_request": {
        const p = toolPart(t, ev.call_id);
        if (p) { p.status = "awaiting_approval"; if (ev.summary) p.summary = ev.summary; if (ev.detail) p.detail = ev.detail; if (ev.branch) p.branch = ev.branch; }
        schedule(t);
        break;
      }
      case "approval_resolved": {
        const p = toolPart(t, ev.call_id);
        if (p) p.status = ev.approved ? "running" : "denied";
        schedule(t);
        break;
      }
      case "tool_end": {
        const p = toolPart(t, ev.call_id);
        if (p) { p.status = ev.approved === false ? "denied" : ev.is_error ? "error" : "done"; p.output = ev.output; }
        schedule(t);
        break;
      }
      default:
        t.status = ev.type === "completed" ? "complete" : ev.type;
        t.error = ev.error;
        for (const p of t.parts) if (p.kind === "tool" && (p.status === "running" || p.status === "awaiting_approval")) p.status = "error";
        t.dirty = false;
        paint(t);
        if (runningTurn === ev.turn_id) runningTurn = null;
    }
    // Only an approval pulls you down (it needs you); other output waits behind the Latest pill.
    if (ev.type === "approval_request") scrollDown();
    else if (ev.type === "tool_start") { if (nearBottom()) scrollDown(); else jump.hidden = false; }
    syncControls();
    if (ev.type === "completed" || ev.type === "failed" || ev.type === "interrupted") { syncRing(); void refreshBranch(); }
    opts.onActivity?.(ev);
  }

  async function submit() {
    const typed = textarea.value.trim();
    if ((!typed && !attach.count) || (runningTurn && !opts.chief)) return;
    if (attach.busy) { toast("Still adding your files…"); return; }
    const attached = attach.ready();
    const paths = attached.map((a) => a.path);
    const text = typed || "Please look at what I attached.";
    textarea.value = "";
    autosize();
    if (opts.chief) {
      // A note to the Chief: it runs now, or right after its current reply.
      try {
        const r = await opts.chief.send(text, paths);
        attach.clear();
        addUser(text, false, attached);
        if (r.turn_id) { runningTurn = r.turn_id; ensureAssistant(r.turn_id); }
        else toast("Noted. It reads that right after its current reply.");
        scrollDown();
      } catch (err) { textarea.value = text; toast(err.message); }
      syncControls();
      return;
    }
    const theme = crewTheme(crew);
    const colors = [theme.c1, theme.c2, ...theme.stars.slice(2)];
    if (chatId === null && canChooseCrew && crew !== "normal") {
      // A mode: a Conductor takes the message (app.js opens its page). The animation keeps
      // running there until the Conductor starts answering.
      const fx = launchFx(root, crew, colors);
      try { await opts.onStartMode(crew, text, attached.map((a) => (a.path.startsWith("/") ? a.path : workspace.path + "/" + a.path))); attach.clear(); }
      catch (err) { fx?.done(true); textarea.value = typed; autosize(); toast(err.message); }
      return;
    }
    const fx = chatId === null ? launchFx(root, "normal", colors) : null;
    try {
      if (chatId === null) {
        const { chat } = await state.client.call("chat.create", { workspace_id: workspace.id, mode, ...(pick.engine ? { engine: pick.engine } : {}), ...(pick.model ? { model: pick.model } : {}), ...(pick.effort ? { effort: pick.effort } : {}), ...(pick.account && (pick.engine === "claude-code" || pick.engine === "codex") ? { account_id: pick.account } : {}) });
        chatId = chat.id;
        if (pick.account) pins = { ...pins, [pick.engine]: pick.account };
        opts.onBind?.(chatId);
      }
      const { turn_id } = await state.client.call("turn.submit", { workspace_id: workspace.id, chat_id: chatId, text, ...(paths.length ? { attachments: paths } : {}) });
      runningTurn = turn_id;
      attach.clear();
      addUser(text, false, attached);
      ensureAssistant(turn_id);
      scrollDown();
    } catch (err) {
      fx?.done(true);
      textarea.value = typed;
      toast(err.message);
    }
    syncControls();
  }

  /** Send a follow-up as if typed (Continue after a stop, Retry after a failure). */
  function resend(text) {
    if (!text || runningTurn) return;
    textarea.value = text;
    void submit();
  }

  async function stop() {
    if (!runningTurn) return;
    try { await state.client.call("turn.interrupt", { turn_id: runningTurn }); } catch (err) { toast(err.message); }
  }

  function autosize() {
    textarea.style.height = "auto";
    textarea.style.height = `${Math.min(textarea.scrollHeight, 240)}px`;
    syncControls();
  }

  // "/" at the start of a message lists skills; Enter or Tab inserts one.
  function skillMenu() {
    closeMenu();
    const m = /^\/([a-z0-9-]*)$/.exec(textarea.value);
    if (!m || !(state.skills ?? []).length) return;
    const hits = state.skills.filter((s) => s.name.startsWith(m[1]) || s.name.includes(m[1])).slice(0, 8);
    if (hits.length === 0) return;
    openMenu(textarea, [{ heading: "Skills" }, ...hits.map((s) => ({ label: `/${s.name}`, description: s.description, icon: "file", onSelect: () => { textarea.value = `/${s.name} `; autosize(); textarea.focus(); } }))], { width: 380 });
  }
  // "@" lists project files (fs.search); picking one inserts @path.
  let mentionSeq = 0;
  async function mentionMenu() {
    const pos = textarea.selectionStart ?? textarea.value.length;
    const m = /(^|\s)@([^\s@]*)$/.exec(textarea.value.slice(0, pos));
    if (!m) return;
    const my = ++mentionSeq;
    let results = [];
    try { results = (await state.client.call("fs.search", { workspace_id: workspace.id, query: m[2], limit: 8 })).results; } catch { return; }
    if (my !== mentionSeq || results.length === 0) return;
    openMenu(textarea, [{ heading: "Files" }, ...results.map((f) => ({ label: f.path, icon: f.kind === "dir" ? "folder" : "file", onSelect: () => {
      const start = pos - m[2].length - 1;
      const next = `${textarea.value.slice(0, start)}@${f.path} ${textarea.value.slice(pos)}`;
      textarea.value = next;
      const at = start + f.path.length + 2;
      textarea.focus();
      textarea.setSelectionRange(at, at);
      autosize();
    } }))], { width: 420 });
  }
  textarea.addEventListener("input", () => {
    autosize();
    skillMenu();
    const pos = textarea.selectionStart ?? 0;
    if (/(^|\s)@[^\s@]*$/.test(textarea.value.slice(0, pos))) void mentionMenu();
  });
  textarea.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey && !e.isComposing) {
      e.preventDefault();
      if (mic.listening()) mic.stop(true); // finish the dictation, then send
      else void submit();
    } else if ((e.metaKey || e.ctrlKey) && !e.shiftKey && !e.altKey && e.key.toLowerCase() === "u") {
      e.preventDefault();
      void attach.pick("files");
    }
  });
  // Pictures pasted from the clipboard, and files or folders dragged in from Finder.
  textarea.addEventListener("paste", (e) => {
    const files = [...(e.clipboardData?.files ?? [])];
    if (!files.length) return;
    e.preventDefault();
    void attach.addFiles(files);
  });
  const composerBox = composer.querySelector(".composer");
  const hasFiles = (e) => [...(e.dataTransfer?.types ?? [])].includes("Files");
  composerBox.addEventListener("dragover", (e) => { if (hasFiles(e)) { e.preventDefault(); composerBox.dataset.drop = "true"; } });
  composerBox.addEventListener("dragleave", (e) => { if (!composerBox.contains(e.relatedTarget)) delete composerBox.dataset.drop; });
  composerBox.addEventListener("drop", (e) => {
    if (!hasFiles(e)) return;
    e.preventDefault();
    delete composerBox.dataset.drop;
    void attach.addFiles(e.dataTransfer.files);
  });
  send.addEventListener("click", () => (runningTurn && !(opts.chief && (textarea.value.trim() || attach.count)) ? stop() : submit()));

  async function loadHistory() {
    if (chatId === null) return;
    try {
      const { messages } = await state.client.call("turn.history", { chat_id: chatId });
      inner.replaceChildren();
      dated = false;
      turns.clear();
      userTexts.length = 0;
      for (const m of messages) {
        if (m.role === "user") addUser(m.text, m.event === true, m.attachments ?? []);
        else {
          const ta = ensureAssistant(m.turn_id, m.parts ?? (m.text ? [{ kind: "text", text: m.text }] : []), m.status, m.error);
          if (m.handoff) showHandoff(ta, m.handoff);
          if (m.status === "streaming") runningTurn = m.turn_id;
        }
      }
      for (const t of turns.values()) paint(t);
      setEmpty();
      syncRing();
      opts.onActivity?.(null);
      syncControls();
      scrollDown();
    } catch { /* offline: the next reconnect reloads */ }
  }

  /** Re-reads the engine choice and providers: updates the model and effort chips and the empty-state hint. */
  function refreshEngine() {
    const eng = currentEngine();
    const active = (state.providers ?? []).find((p) => p.active);
    engineChip.replaceChildren(...[engineMark(eng, "icon em"), h("span", {}, modelName({ engine: eng, model: pick.model ?? undefined })), eng === "api" ? null : h("span", { class: `cmp-effort-in${pick.effort === "max" ? " max" : ""}` }, effortName(pick.effort ?? "medium")), icon("chevron-down", "icon chip-caret")].filter(Boolean));
    engineChip.dataset.engine = eng;
    vox?.repaintChip();
    paintAccountChip();
    effortChip.hidden = true;
    const missing = eng !== "api" && engineInfo(eng) && !engineInfo(eng).found;
    put(emptyNote,
      missing ? `${engineInfo(eng).label} isn't installed on this computer. ` : eng === "api" && !active ? "No model is set up yet, so replies are just an echo. " : "",
      missing || (eng === "api" && !active) ? h("button", { class: "link", type: "button", onclick: () => nav.openSettings("models") }, missing ? "Models & keys" : "Add a provider") : null);
    syncRing();
  }
  const put = (el, ...kids) => { el.replaceChildren(...kids.filter((k) => k !== null && k !== undefined && k !== "")); };

  /** The runtime's record of this chat changed (title, mode). */
  function setMeta(meta) {
    if (!meta) return;
    if (meta.mode !== mode) { mode = meta.mode; syncChips(); }
    usage = meta.usage ?? null;
    connectors = meta.connectors ?? null;
    const next = { engine: meta.engine ?? "api", model: meta.model ?? null, effort: meta.effort ?? null };
    const accountsChanged = JSON.stringify(pins) !== JSON.stringify(meta.accounts ?? {});
    pins = meta.accounts ?? {};
    hasSession = !!meta.engine_session;
    if (next.engine !== pick.engine || next.model !== pick.model || next.effort !== pick.effort) { pick = { ...next, account: pick.account }; refreshEngine(); }
    else { if (accountsChanged) paintAccountChip(); syncRing(); }
  }

  /** What the side panel reads: the chat's turns (parts), its user messages, whether it is running. */
  function snapshot() {
    return {
      chatId,
      running: runningTurn !== null,
      users: userTexts.slice(),
      turns: [...turns.values()].map((t) => ({ turnId: t.turnId, status: t.status, parts: t.parts })),
      usage,
      connectors,
      engine: currentEngine(),
      model: pick.model,
      effort: pick.effort,
      stop: () => void stop(),
    };
  }

  refreshEngine();
  void refreshBranch();
  if (!opts.chief) setCrew("normal");
  setEmpty();
  syncControls();
  syncChips();
  /** Puts text in the box, ready to edit and send. */
  function setDraft(text) {
    textarea.value = text;
    autosize();
    textarea.focus();
    textarea.setSelectionRange(text.length, text.length);
  }

  /** A fresh chat's welcome arrives through a dissolving grid of pixels. */
  function reveal() { if (!emptyHead.hidden) pixelReveal(emptyHead.closest(".chat") ?? emptyHead, { cell: 12, ms: 560 }); }

  /** Puts text in the box and sends it right away. */
  const sendNow = async (text, files = []) => {
    if (files.length) await attach.addPaths(files);
    setDraft(text);
    return submit();
  };

  return { el: root, reveal, setDraft, sendNow, onEvent, loadHistory, refreshEngine, setMeta, syncChips, snapshot, refreshBranch, get chatId() { return chatId; }, get busy() { return runningTurn !== null; }, focus: () => textarea.focus() };
}
