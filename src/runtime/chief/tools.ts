// The Chief's tools. The same Tool objects serve the API agent loop directly
// and Claude Code through the MCP endpoint (chief/mcp.ts). None of them can
// approve a permission prompt, merge, push or delete: those stay the person's.

import type { Tool, ToolResult } from "../agent/tools";
import type { ChiefManager } from "./manager";
import type { Access, ChiefProfile, Item, StartSpec, Tier, WorkerEngine } from "./store";
import { isJobKind, type JobKind } from "./skills";
import { STAGE_IDS, isStage, type StageId } from "./pipeline";
import { MODE_IDS, isMode, type ModeId } from "./modes";

const ENGINES: WorkerEngine[] = ["claude-code", "codex", "api"];
const TIERS: Tier[] = ["fast", "base", "frontier", "opus"];
const ACCESS: Access[] = ["read", "edit", "full"];

const s = (description: string): Record<string, unknown> => ({ type: "string", description });
const arr = (description: string): Record<string, unknown> => ({ type: "array", items: { type: "string" }, description });
const ok = (v: unknown): ToolResult => ({ output: typeof v === "string" ? v : JSON.stringify(v), is_error: false });
const str = (v: unknown, name: string, max = 20_000): string => {
  if (typeof v !== "string" || !v.trim()) throw new Error(`${name} is required`);
  return v.trim().slice(0, max);
};
const strs = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === "string" && x.trim() !== "").map((x) => x.trim()) : []);
const norm = (t: string): string => t.replace(/[“”]/g, "\"").replace(/[‘’]/g, "'").replace(/\s+/g, " ").trim().toLowerCase();

/** Every quote must be a verbatim run of the person's notes. */
function checkQuotes(words: string, quotes: string[]): void {
  const hay = norm(words);
  for (const q of quotes) if (!hay.includes(norm(q))) throw new Error(`This quote is not in the person's notes word for word: "${q.slice(0, 120)}". Quote exactly, or leave it out.`);
}

/** Where a kind of job is done best when the Conductor names no engine. */
function strongestFor(kind: JobKind | undefined, fallback: WorkerEngine): WorkerEngine {
  if (kind === "ui" || kind === "asset") return "codex";
  if (kind === "brand" || kind === "art" || kind === "visual" || kind === "plan" || kind === "fix" || kind === "feature" || kind === "qa") return "claude-code";
  return fallback;
}

export function chiefTools(m: ChiefManager, p: ChiefProfile): Tool[] {
  const item = (id: unknown): Item => {
    const raw = typeof id === "string" ? id.trim() : typeof id === "number" ? String(id) : "";
    const ref = /^\[?\[?#?(\d+)\]?\]?$/.exec(raw);
    const it = ref ? m.store.byRef(p.id, Number(ref[1])) : m.store.item(raw);
    if (!it || it.chief_id !== p.id) throw new Error(`No item ${raw} on your board.`);
    return it;
  };
  const project = (id: string): string => {
    const all = m.projectsOf(p);
    const w = all.find((x) => x.id === id) ?? all.find((x) => x.name.toLowerCase() === id.toLowerCase());
    if (!w) throw new Error(`No project ${id} among: ${all.map((x) => `${x.name} (${x.id})`).join(", ") || "none"}.`);
    return w.id;
  };
  const tool = (name: string, description: string, properties: Record<string, unknown>, required: string[], summary: (i: Record<string, unknown>) => string, run: (i: Record<string, unknown>) => ToolResult | Promise<ToolResult>, detail?: (i: Record<string, unknown>) => string | undefined): Tool => ({
    def: { name, description, schema: { type: "object", properties, required } },
    kind: "chief",
    describe: (i) => { const d = detail?.(i); return { summary: summary(i), ...(d ? { detail: d.slice(0, 3000) } : {}) }; },
    run: async (i) => run(i),
  });

  return [
    tool("chat_start",
      "Start worker chats for a piece of work: one chat per project id (repeat an id for two approaches). The runtime may answer proposed (the person starts it) or waiting (no free slot); report that in one line, never work around it.",
      {
        item_id: s("The board item this is for (its id or [[n]]). Absent: a new item is made."),
        title: s("A few words naming the work."),
        brief: s("All the chat gets: labelled lines Goal, Done when, Projects, Start at, Decided, Don't touch. The runtime adds how to report."),
        quotes: arr("The person's own words this is for, each verbatim from their notes."),
        project_ids: arr("One project id per chat."),
        engine: { type: "string", enum: ENGINES, description: "Who does it: claude-code (logic, debugging, data, payments, plans, reviews), codex (screens, image assets, mechanical edits across many files, small jobs; also a strong second opinion on hard bugs), api (an API key). Absent: in a mode, chosen by kind (ui and asset to Codex, the rest to Claude)." },
        tier: { type: "string", enum: TIERS, description: "fast for chores, base for normal work, frontier for hard work and reviews, opus for planning a big project. In a mode the runtime applies that mode's models and limits." },
        role: { type: "string", enum: ["build", "review", "check"], description: "build changes code; review reads it adversarially and changes nothing; check runs something once and reports." },
        images: arr("Reference images for the worker, as paths inside the project (the logo, earlier assets, a screenshot). Both engines see them."),
        attachments: arr("Pictures, files or folders the person attached (the paths in <attached>) that this worker needs. Pictures are shown to it; the rest it opens. Only pass what the task needs."),
        pin_engine: { type: "boolean", description: "True only when the person asked for this engine. Otherwise, in a mode, the runtime may move chores to Codex when Claude's plan limit is nearly used." },
        kind: { type: "string", enum: ["fix", "feature", "chore", "plan", "brand", "art", "asset", "ui", "visual", "qa"], description: "The job's shape: qa (test the running app like a user in the browser or iOS Simulator and report bugs; always Claude Code on Sonnet), fix (a bug: reproduce, smallest fix, prove it; no plan), feature (build or change something: reuse first), chore (look something up or run something), plan (write a spec, gap report or plan file), brand (write the project's brand kit), art (write image prompts for an asset batch), asset (make the images: always Codex), ui (build screens), visual (with role review: check images or screens against the brand kit). The runtime hands the worker the matching short skill." },
        access: { type: "string", enum: ACCESS, description: "What the chat may do; capped by the person's setting. Reviews and checks: read." },
        guess: { type: "boolean", description: "True when you are not sure which project this is for." },
      },
      ["title", "brief", "project_ids"],
      (i) => `Start ${String(i.role ?? "build") === "build" ? "work" : String(i.role)}: ${String(i.title ?? "")}`,
      (i) => {
        const brief = str(i.brief, "brief", 12_000);
        const title = str(i.title, "title", 100);
        const quotes = strs(i.quotes);
        checkQuotes(m.personWords(p), quotes);
        const ids = strs(i.project_ids).map(project);
        if (ids.length === 0) throw new Error("project_ids needs at least one project.");
        if (ids.length > 4) throw new Error("At most 4 chats at once; split the work.");
        const role = i.role === "review" || i.role === "check" ? i.role : "build";
        const kind = isJobKind(i.kind) ? i.kind : undefined;
        // Each engine where it is strongest: in a mode, a job with no engine named goes by its kind (screens and assets to Codex,
        // the rest to Claude). Images only exist on Codex (it has the image tool), so an asset job always runs there.
        const named = ENGINES.includes(i.engine as WorkerEngine) ? (i.engine as WorkerEngine) : undefined;
        const engine: WorkerEngine = p.mode && kind === "asset" ? "codex" : named ?? (p.mode ? strongestFor(kind, p.worker_engine) : p.worker_engine);
        const tier = TIERS.includes(i.tier as Tier) ? (i.tier as Tier) : undefined;
        const access = ACCESS.includes(i.access as Access) ? (i.access as Access) : role === "build" ? "edit" : "read";
        const it = i.item_id !== undefined && i.item_id !== "" ? item(i.item_id) : m.store.addItem({ chief_id: p.id, title, text: quotes.join(" / ") || undefined, state: "queued", project_ids: [...new Set(ids)], ...(i.guess === true ? { guess: true } : {}) });
        const fullBrief = quotes.length ? `${brief}\n\nThe person's words: ${quotes.map((q) => `"${q}"`).join(" ")}` : brief;
        const specs: StartSpec[] = ids.map((pid) => ({ project_id: pid, title, brief: fullBrief, engine, role, access, ...(tier ? { tier } : {}), ...(kind ? { kind } : {}), ...(i.pin_engine === true || (p.mode && kind === "asset") ? { pin_engine: true as const } : {}), ...(strs(i.images).length + strs(i.attachments).length ? { images: [...strs(i.images), ...strs(i.attachments)].slice(0, 12) } : {}) }));
        const builds = specs.filter((x) => x.role === "build").length;
        const propose = p.autonomy === 1 && role === "build" && (i.guess === true || new Set(ids).size > 1 || builds > 1);
        const r = m.startChats(p, it, specs, propose);
        return ok({ item_id: it.id, item_ref: `[[${it.ref}]]`, ...r });
      },
      (i) => String(i.brief ?? "")),

    tool("chat_send",
      "Message one of your chats (or a chat in your projects): the instruction, then why. An idle chat starts on it now; a busy one gets it when its current step ends.",
      { chat_id: s("The chat."), text: s("What it should do, then why, in a sentence or two it can act on alone.") },
      ["chat_id", "text"],
      (i) => `Message ${m.store.itemOfChat(String(i.chat_id ?? "")) ? `[[${m.store.itemOfChat(String(i.chat_id))?.ref}]]` : "a chat"}`,
      (i) => ok(m.send(p, str(i.chat_id, "chat_id", 64), str(i.text, "text", 8000))),
      (i) => String(i.text ?? "")),

    tool("chat_stop", "Stop a chat's running turn.", { chat_id: s("The chat.") }, ["chat_id"],
      () => "Stop a chat",
      (i) => { m.chatFor(p, str(i.chat_id, "chat_id", 64)); return ok({ stopped: m.stop(String(i.chat_id)) }); }),

    tool("chat_digest", "A chat's goal, whether it runs, and its latest answer.", { chat_id: s("The chat.") }, ["chat_id"],
      () => "Read a chat's latest answer",
      (i) => ok(m.digest(p, str(i.chat_id, "chat_id", 64)))),

    tool("chat_search", "Find a chat by topic when the board does not show it: searches titles, goals and latest answers in your projects; best five.", { query: s("Words from its topic.") }, ["query"],
      (i) => `Find chats about ${String(i.query ?? "")}`,
      (i) => ok({ chats: m.search(p, str(i.query, "query", 300)) })),

    tool("library_search", "Search the person's existing apps (the Library) before planning new work: which features already exist, in which app, and which files hold them. Read-only; costs nothing. Use it to answer \"do we already have X?\" and to name the files a worker should start from.", { query: s("The feature in a few words, e.g. loyalty points, cart, vendor payouts.") }, ["query"],
      (i) => `Library: ${String(i.query ?? "")}`,
      (i) => {
        const lib = m.library();
        if (!lib) return ok({ hits: [], note: "The Library is not available." });
        if (!lib.list().some((a) => a.status === "ready")) return ok({ hits: [], note: "The Library has no apps yet. The person adds them in the Library page." });
        return ok({ hits: lib.search(str(i.query, "query", 200), undefined, 8).map((h) => ({ app: h.app, feature: h.name, layers: h.layers.map((l) => `${l.layer}:${l.package}`), why: h.why, routes: h.routes, tables: h.tables })), note: "No hit means no app has it." });
      }),

    tool("queue_add", "Put work on the board for later (not started).", { title: s("A few words."), text: s("What it is, in the person's words if any."), project_ids: arr("Projects, if known.") }, ["title"],
      (i) => `Queue: ${String(i.title ?? "")}`,
      (i) => {
        const it = m.store.addItem({ chief_id: p.id, title: str(i.title, "title", 100), ...(typeof i.text === "string" && i.text.trim() ? { text: i.text.trim().slice(0, 2000) } : {}), state: "queued", project_ids: strs(i.project_ids).map(project) });
        m.editItem(it.id, {});
        return ok({ item_id: it.id, item_ref: `[[${it.ref}]]` });
      }),

    tool("queue_update", "Change a board item: retitle it, mark it done, put it back in the queue, or drop it (drop stops its chats).", { item_id: s("The item (id or [[n]])."), title: s("New title."), state: { type: "string", enum: ["queued", "done", "dropped"] } }, ["item_id"],
      (i) => `Update [[${(() => { try { return item(i.item_id).ref; } catch { return "?"; } })()}]]${i.state ? ` → ${String(i.state)}` : ""}`,
      (i) => {
        const it = item(i.item_id);
        const state = i.state === "queued" || i.state === "done" || i.state === "dropped" ? i.state : undefined;
        m.editItem(it.id, { ...(state ? { state } : {}), ...(typeof i.title === "string" && i.title.trim() ? { title: i.title } : {}) });
        return ok({ item_ref: `[[${it.ref}]]`, state: it.state });
      }),

    tool("automation_run", "Run one of a project's automations (listed in your instructions) as one board item. Use it when an automation fits the whole job, such as building an app from a brief.", { project_id: s("The project."), name: s("The automation's name."), inputs: { type: "object", additionalProperties: { type: "string" }, description: "Its inputs by name." }, title: s("A few words for the board."), item_id: s("An existing item to attach it to.") }, ["project_id", "name"],
      (i) => `Run automation ${String(i.name ?? "")}`,
      (i) => {
        const inputs: Record<string, string> = {};
        if (i.inputs && typeof i.inputs === "object") for (const [k, v] of Object.entries(i.inputs as Record<string, unknown>)) if (typeof v === "string") inputs[k] = v.slice(0, 20_000);
        const it = m.runAutomation(p, { project_id: project(str(i.project_id, "project_id", 64)), name: str(i.name, "name", 64), inputs, ...(typeof i.title === "string" ? { title: i.title } : {}), ...(i.item_id ? { item: item(i.item_id) } : {}) });
        return ok({ item_id: it.id, item_ref: `[[${it.ref}]]`, run_id: it.automation?.run_id });
      },
      (i) => JSON.stringify(i.inputs ?? {}, null, 2)),

    tool("ask", "Ask the person one question with the answer you recommend, then end your turn: the answer comes as the next note. Unless must_wait, it may go ahead with your recommendation after a wait (a <no_answer> line tells you).",
      { question: s("One sentence that names the choice."), recommended: s("The answer you recommend, as you would act on it."), item_id: s("The item it holds up; without one nothing goes ahead by itself."), chat_id: s("The chat whose question this is, if any."), must_wait: { type: "boolean", description: "True when going ahead cannot be undone or is the person's to decide." } },
      ["question", "recommended"],
      (i) => `Ask: ${String(i.question ?? "")}`,
      (i) => ok(m.ask(p, { question: str(i.question, "question", 400), recommended: str(i.recommended, "recommended", 400), must_wait: i.must_wait === true, ...(i.item_id ? { item: item(i.item_id) } : {}), ...(typeof i.chat_id === "string" && i.chat_id ? { chat_id: i.chat_id } : {}) })),
      (i) => `Recommended: ${String(i.recommended ?? "")}`),

    tool("remember", "Save a standing rule or preference the person told you, as their memory note (all projects, or one). quote must be their exact words.",
      { text: s("The note as it should stay true, with the same meaning as the quote (keep no/never/don't)."), quote: s("The person's exact words it comes from."), project_id: s("A project, for a note about one project; absent: everywhere.") },
      ["text", "quote"],
      (i) => `Remember: ${String(i.text ?? "")}`,
      (i) => {
        const text = str(i.text, "text", 1000);
        const quote = str(i.quote, "quote", 1000);
        checkQuotes(m.personWords(p), [quote]);
        if (/\b(no|not|never|don't|dont|do not)\b/i.test(text) && !/\b(no|not|never|don't|dont|do not)\b/i.test(quote)) throw new Error("The note says no/never but the quote does not. Keep the person's meaning.");
        const scope = typeof i.project_id === "string" && i.project_id ? project(i.project_id) : "global";
        m.remember(scope, text);
        return ok({ remembered: true });
      }),

    // A Conductor only: the end-to-end pipeline for a whole new project. There is deliberately no tool to approve a gate.
    ...(p.mode ? [
      tool("pipeline_start", "Start the end-to-end pipeline for a whole new project or app (never for a fix or a single feature): spec, gap report, plan (the person approves), UI (the person approves), build, test, review, deliver (the person approves). Each stage arrives as a <pipeline_stage> with what to start; the runtime keeps the order and each stage's mode.",
        { title: s("A few words naming the project."), quotes: arr("The person's words this is for, each verbatim from their notes."), project_ids: arr("The projects it builds in (the first holds the stage files)."), skip: { type: "array", items: { type: "string", enum: [...STAGE_IDS] }, description: "Stages that do not apply, e.g. ui for a backend-only job." }, modes: { type: "object", additionalProperties: { type: "string", enum: [...MODE_IDS] }, description: "Stage -> mode, only where the person asked for a different one." } },
        ["title", "quotes", "project_ids"],
        (i) => `Start pipeline: ${String(i.title ?? "")}`,
        (i) => {
          const quotes = strs(i.quotes);
          if (!quotes.length) throw new Error("quotes needs the person's words.");
          checkQuotes(m.personWords(p), quotes);
          const skip = strs(i.skip).filter(isStage);
          const modes: Partial<Record<StageId, ModeId>> = {};
          if (i.modes && typeof i.modes === "object") for (const [k, v] of Object.entries(i.modes as Record<string, unknown>)) if (isStage(k) && isMode(v)) modes[k] = v;
          const r = m.startPipeline(p, { title: str(i.title, "title", 80), goal: quotes.join(" / "), project_ids: strs(i.project_ids).map(project), skip, modes });
          return ok({ pipeline_id: r.pipeline.id, first_stage: r.text });
        }),
      tool("stage_done", "Say that the running stage of a pipeline is done: its chats have reported and their Check lines prove the stage's work. Refused while chats still run. A gated stage then waits for the person; any other starts the next stage.",
        { pipeline_id: s("The pipeline."), summary: s("Two lines: what the stage produced and where.") },
        ["pipeline_id", "summary"],
        (i) => `Stage done: ${String(i.summary ?? "").slice(0, 60)}`,
        (i) => ok(m.stageDone(p, str(i.pipeline_id, "pipeline_id", 64), str(i.summary, "summary", 600)))),
    ] : []),
  ];
}
