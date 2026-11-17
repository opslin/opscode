// M3: UI and brand assets. Engines by strength (screens and images to Codex, logic and
// review to Claude) without being told; Codex models per mode from Codex's own list (one
// it does not offer is left out); reference images reach Codex attached and every worker
// by path; brand / art / asset / ui / visual skills land in the right briefs; an asset
// worker whose files do not exist is sent back once; the pipeline's UI stage runs brand
// kit -> prompts -> Codex images -> visual review with rounds by mode; the gate's gallery
// returns the images, from the pipeline's own folder only.

import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p25-")));
const proj = join(base, "shop");
mkdirSync(join(proj, "brand"), { recursive: true });
writeFileSync(join(proj, "package.json"), JSON.stringify({ name: "shop" }));
writeFileSync(join(proj, "brand/logo.png"), Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==", "base64"));
writeFileSync(join(base, "outside.png"), "x");
const logFile = join(base, "engines.log");
// Codex here offers Sol and Luna but not Astra, so GODMODE's frontier pick (Astra) must be left out.
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile, OPSCODE_FAKE_CODEX_MODELS: "gpt-6.1-sol,gpt-6-luna", OPSCODE_CHIEF_TICK_MS: "400" };
const entries = () => (existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const rt = await startRuntime({ env, stateDir: join(base, "state"), keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  await C.call("engines.set", { default_engine: "claude-code" });
  const tool = (name, args) => `FAKE_TOOL ${name} ${JSON.stringify(args)}`;
  const waitFor = async (fn, ms = 15000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(100)) { const v = await fn(); if (v) return v; } return null; };
  const chats = async () => (await C.call("chat.list", {})).result.chats;
  const chatNamed = (title) => waitFor(async () => (await chats()).find((c) => c.title === title));
  const codexInputs = () => entries().filter((e) => e.turn_input).map((e) => e.turn_input);
  const claudeBriefs = () => entries().filter((e) => e.bin === "claude" && e.prompt && !e.prompt.includes("<board>")).map((e) => e.prompt);
  const inputFor = (goal) => waitFor(async () => codexInputs().find((x) => x.text.includes(goal)));
  const job = (title, extra = {}) => tool("chat_start", { title, brief: `Goal: ${title} FAKE_REPORT=done FAKE_CHECK`, quotes: ["go"], project_ids: [wid], ...extra });
  await sleep(1500); // the runtime learns Codex's model ids at start

  const wl = (await C.call("chief.create", { mode: "warlord", project_id: wid })).result.chief;
  await C.call("chief.update", { chief_id: wl.id, max_parallel: 8 });

  // ---- engines by strength, without being told -----------------------------------------------------
  await C.call("chief.note", { chief_id: wl.id, text: ["go",
    job("screens", { kind: "ui" }), job("bugfix", { kind: "fix" }), job("chore-fast", { kind: "chore", tier: "fast" }),
    job("forced", { kind: "asset", engine: "claude-code" }).replace("FAKE_REPORT=done FAKE_CHECK", "FAKE_ASSET=assets/forced.png"),
    job("looks", { kind: "visual", role: "review" }),
  ].join("\n") });
  const screens = await chatNamed("screens"), bugfix = await chatNamed("bugfix"), forced = await chatNamed("forced"), looks = await chatNamed("Review: looks");
  t.check("a ui job with no engine named runs on Codex", screens?.engine === "codex", screens?.engine);
  t.check("a fix with no engine named runs on Claude", bugfix?.engine === "claude-code", bugfix?.engine);
  t.check("an asset job runs on Codex even when Claude was named (only Codex makes images)", forced?.engine === "codex", forced?.engine);
  t.check("a visual review runs on Claude", looks?.engine === "claude-code", looks?.engine);

  // ---- Codex models per mode -----------------------------------------------------------------------
  const sIn = await inputFor("Goal: screens");
  t.check("WARLORD's Codex base pick is GPT-6.1-Sol at medium effort", sIn?.model === "gpt-6.1-sol" && sIn.effort === "medium", JSON.stringify([sIn?.model, sIn?.effort]));
  await C.call("chief.note", { chief_id: wl.id, text: `more\n${job("tiny", { kind: "ui", tier: "fast" })}` });
  const tIn = await inputFor("Goal: tiny");
  t.check("tier fast on Codex is GPT-6-Luna at low effort", tIn?.model === "gpt-6-luna" && tIn.effort === "low", JSON.stringify([tIn?.model, tIn?.effort]));
  const gm = (await C.call("chief.create", { mode: "godmode", project_id: wid })).result.chief;
  await C.call("chief.note", { chief_id: gm.id, text: `go\n${job("hardui", { kind: "ui", tier: "frontier" })}` });
  const hIn = await inputFor("Goal: hardui");
  t.check("GODMODE's frontier pick (GPT-6-Astra) is left out when this Codex does not offer it: Codex's default applies", hIn && hIn.model === null && hIn.effort === "high", JSON.stringify([hIn?.model, hIn?.effort]));

  // ---- reference images ----------------------------------------------------------------------------
  await C.call("chief.note", { chief_id: wl.id, text: `icons\n${job("icons", { kind: "asset", images: ["brand/logo.png", "../outside.png", "/etc/hosts", "brand/missing.png"] }).replace("FAKE_REPORT=done FAKE_CHECK", "FAKE_ASSET=assets/icons/sheet.png")}` });
  const iIn = await inputFor("Goal: icons");
  t.check("Codex gets the logo attached as a local image", iIn?.images?.length === 1 && iIn.images[0] === join(proj, "brand/logo.png"), JSON.stringify(iIn?.images));
  t.check("paths outside the project, and missing files, are dropped", !JSON.stringify(iIn?.images).includes("outside") && !JSON.stringify(iIn?.images).includes("hosts"));
  t.check("the brief names the reference images too", /Reference images \(look at them\): brand\/logo\.png/.test(iIn?.text ?? ""), (iIn?.text ?? "").slice(0, 160));

  // ---- skills ---------------------------------------------------------------------------------------
  t.check("an asset worker gets the asset skill (image tool, exact paths, look before moving on)", /How to make the assets/.test(iIn?.text ?? "") && /image generation tool/.test(iIn?.text ?? "") && /never change the palette/.test(iIn?.text ?? ""));
  t.check("a ui worker gets the screens skill", /How to build screens/.test(sIn?.text ?? "") && /theme tokens/.test(sIn?.text ?? ""));
  const lookBrief = await waitFor(async () => claudeBriefs().find((x) => x.startsWith("Goal: looks")));
  t.check("a visual reviewer gets the brand-guardian skill, not the code review one", /brand guardian/.test(lookBrief ?? "") && !/How to review \(you are independent/.test(lookBrief ?? ""), (lookBrief ?? "").slice(0, 100));
  await C.call("chief.note", { chief_id: wl.id, text: `brand\n${job("brandkit", { kind: "brand" })}\n${job("prompts", { kind: "art" })}` });
  const bb = await waitFor(async () => claudeBriefs().find((x) => x.startsWith("Goal: brandkit")));
  const ab = await waitFor(async () => claudeBriefs().find((x) => x.startsWith("Goal: prompts")));
  t.check("a brand worker gets the brand-kit skill (style header, palette hex, safe areas)", /How to write the brand kit/.test(bb ?? "") && /style header/.test(bb ?? "") && /Safe areas/.test(bb ?? ""));
  t.check("an art director gets the prompt-writing skill (one subject, no text except given banner words, sheets)", /How to art-direct/.test(ab ?? "") && /3x3 sheet/.test(ab ?? "") && /exact words given/.test(ab ?? ""));

  // ---- the asset finish check ----------------------------------------------------------------------
  await waitFor(async () => existsSync(join(proj, "assets/icons/sheet.png")));
  await C.call("chief.note", { chief_id: wl.id, text: `banners\n${job("banners", { kind: "asset" }).replace("FAKE_REPORT=done FAKE_CHECK", "FAKE_ASSET_LOST=assets/banners/hero.png")}` });
  const back = await waitFor(async () => codexInputs().find((x) => x.text.includes("none of them exists")), 15000);
  t.check("an asset worker whose Check line names files that do not exist is sent back once", !!back && /assets\/banners\/hero\.png/.test(back.text), (back?.text ?? "").slice(0, 140));
  await waitFor(async () => existsSync(join(proj, "assets/banners/hero.png")));
  const view = async (id) => (await C.call("chief.get", { chief_id: id })).result;
  const ban = await waitFor(async () => { const i = (await view(wl.id)).items.find((x) => x.title === "banners"); return i?.chats?.[0]?.state === "idle" && i.chats[0].nudged ? i : null; });
  t.check("the second answer's file exists, so the Chief hears it (one reminder only)", !!ban && codexInputs().filter((x) => x.text.includes("none of them exists")).length === 1);
  const icons = (await view(wl.id)).items.find((x) => x.title === "icons");
  t.check("an asset whose file exists is not sent back", icons?.chats?.[0] && !icons.chats[0].nudged, JSON.stringify(icons?.chats?.[0]));

  // ---- the UI & assets stage, and its gallery ------------------------------------------------------
  await C.call("chief.note", { chief_id: wl.id, text: `make the brand assets for the shop\n${tool("pipeline_start", { title: "Shop look", quotes: ["make the brand assets for the shop"], project_ids: [wid], skip: ["spec", "gap", "plan", "build", "test", "review", "deliver"] })}` });
  const ps = await waitFor(async () => entries().find((e) => e.chief_tool === "pipeline_start" && e.result.includes("Shop look")));
  const stage = JSON.parse(ps?.result ?? "{}").first_stage ?? "";
  t.check("the UI stage runs brand kit -> art -> Codex assets -> screens -> visual review", /brand\.md/.test(stage) && /kind art/.test(stage) && /kind asset/.test(stage) && /kind ui/.test(stage) && /kind visual/.test(stage), stage.slice(0, 200));
  t.check("with WARLORD's 2 refinement rounds", /at most 2 rounds/.test(stage));
  const pid = JSON.parse(ps.result).pipeline_id;
  const g0 = (await C.call("chief.pipeline.gallery", { pipeline_id: pid })).result;
  t.check("the gallery is empty before anything is made", g0?.images?.length === 0, JSON.stringify(g0));
  await C.call("chief.note", { chief_id: wl.id, text: `cats\n${job("cat icons", { kind: "asset" }).replace("FAKE_REPORT=done FAKE_CHECK", "FAKE_ASSET=docs/opscode/shop-look/assets/cats/cat1.png")}` });
  await waitFor(async () => existsSync(join(proj, "docs/opscode/shop-look/assets/cats/cat1.png")));
  const g1 = (await C.call("chief.pipeline.gallery", { pipeline_id: pid })).result;
  t.check("the gallery returns the stage's image as a PNG", g1?.images?.length === 1 && g1.images[0].path === "docs/opscode/shop-look/assets/cats/cat1.png" && g1.images[0].data_url.startsWith("data:image/png;base64,"), JSON.stringify(g1?.images?.map((i) => i.path)));
  t.check("and only from the pipeline's own folder (the other assets are not in it)", !g1.images.some((i) => i.path.includes("assets/icons") || i.path.includes("brand/logo")));
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
}
process.exit(t.finish());
