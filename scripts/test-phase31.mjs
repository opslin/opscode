// Attachments: photos, files and folders added with the + button (or pasted). They are copied into the
// project (.opscode/attachments), secrets and build output are left out, pictures reach the model itself
// (Claude Code inline, Codex as local images), a Conductor sees them and passes them to its workers.
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p31-")));
const proj = join(base, "shop");
const api = join(base, "api");
const ext = join(base, "design-refs");
for (const d of [join(proj, "src"), api, join(ext, "sub"), join(ext, "node_modules")]) mkdirSync(d, { recursive: true });
writeFileSync(join(proj, "package.json"), "{}");
writeFileSync(join(api, "package.json"), "{}");
const PNG = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==", "base64");
writeFileSync(join(ext, "home-screen.png"), PNG);
writeFileSync(join(ext, "notes.md"), "# Notes\nmake the cart red");
writeFileSync(join(ext, "sub", "deep.txt"), "deep");
writeFileSync(join(ext, ".env"), "SECRET=1");
writeFileSync(join(ext, "server.pem"), "-----BEGIN");
writeFileSync(join(ext, "node_modules", "x.js"), "x");
writeFileSync(join(proj, "src", "mock.png"), PNG);
const logFile = join(base, "engines.log");
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile };
const entries = () => (existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const rt = await startRuntime({ env, stateDir: join(base, "state"), keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  const aid = (await C.call("workspace.add", { path: api })).result.workspace.id;
  await C.call("engines.set", { default_engine: "claude-code" });
  const waitFor = async (fn, ms = 15000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(100)) { const v = await fn(); if (v) return v; } return null; };
  const events = (id) => C.find("turn.event", (p) => p.turn_id === id).map((n) => n.params);
  const finished = (id) => waitFor(() => events(id).some((e) => ["completed", "failed", "interrupted"].includes(e.type)));
  const add = (p) => C.call("attachment.add", { workspace_id: wid, ...p });

  // ---- adding -------------------------------------------------------------------------------------
  const r1 = await add({ paths: [join(ext, "home-screen.png"), ext] });
  const [img, folder] = r1.result?.items ?? [];
  t.check("a photo and a folder from outside the project are attached", img?.kind === "image" && folder?.kind === "folder" && img.name === "home-screen.png" && folder.name === "design-refs", JSON.stringify(r1));
  t.check("they are copied into the project's .opscode/attachments", img.path.startsWith(".opscode/attachments/") && existsSync(join(proj, img.path)) && existsSync(join(proj, folder.path, "notes.md")) && existsSync(join(proj, folder.path, "sub", "deep.txt")));
  t.check("keys, .env files and build folders are left out and counted", !existsSync(join(proj, folder.path, ".env")) && !existsSync(join(proj, folder.path, "server.pem")) && !existsSync(join(proj, folder.path, "node_modules")) && folder.files === 3 && folder.skipped >= 3, JSON.stringify(folder));
  t.check("the attachments folder is never committed (it carries its own .gitignore)", readFileSync(join(proj, ".opscode/attachments/.gitignore"), "utf8").trim() === "*");
  const before0 = readdirSync(join(proj, ".opscode/attachments")).length;
  const key = await add({ paths: [join(ext, "server.pem")] });
  const kitem = key.result?.items?.[0];
  t.check("a key file picked on its own IS attachable: by reference, not copied (its path is kept)", kitem?.kind === "file" && kitem.ref === true && kitem.path === join(ext, "server.pem") && readdirSync(join(proj, ".opscode/attachments")).length === before0, JSON.stringify(key));
  const envItem = (await add({ paths: [join(ext, ".env")] })).result?.items?.[0];
  t.check("so is a .env file", envItem?.ref === true);
  writeFileSync(join(ext, "bundle.zip"), Buffer.from("PK\x03\x04 fake zip bytes"));
  const zip = (await add({ paths: [join(ext, "bundle.zip")] })).result?.items?.[0];
  t.check("a zip (any kind of file) is attached and copied into the project", zip?.kind === "file" && !zip.ref && existsSync(join(proj, zip.path)) && readFileSync(join(proj, zip.path)).length > 10, JSON.stringify(zip));
  const before = readdirSync(join(proj, ".opscode/attachments")).length;
  const inside = await add({ paths: [join(proj, "src", "mock.png")] });
  t.check("something already in the project is used where it is (no copy)", inside.result?.items?.[0]?.path === "src/mock.png" && readdirSync(join(proj, ".opscode/attachments")).length === before);
  const blob = await add({ name: "Screen Shot 1.png", data: PNG.toString("base64") });
  t.check("a pasted picture is saved as a file", blob.result?.items?.[0]?.kind === "image" && existsSync(join(proj, blob.result.items[0].path)), JSON.stringify(blob));
  const big = await add({ name: "huge.png", data: Buffer.alloc(1_200_000).toString("base64") });
  t.check("a pasted picture that is too large says to attach it as a file", /attach it as a file/.test(big.error?.message ?? ""), JSON.stringify(big.error));
  t.check("a missing path is a clear error", /could not find/.test((await add({ paths: [join(base, "nope.png")] })).error?.message ?? ""));
  const th = (path) => C.call("attachment.thumb", { workspace_id: wid, path });
  t.check("thumbnails: a picture gives a data URL; a folder, a stranger's path and .. give none", (await th(img.path)).result?.data_url?.startsWith("data:image/png;base64,") && (await th(folder.path)).result?.data_url === null && (await th("../../etc/hosts")).result?.data_url === null && (await th("package.json")).result?.data_url === null);

  // ---- Claude Code: sees the picture, knows the folder -----------------------------------------------
  const cc = (await C.call("chat.create", { workspace_id: wid, engine: "claude-code", mode: "auto_edits" })).result.chat;
  writeFileSync(logFile, "");
  let r = (await C.call("turn.submit", { workspace_id: wid, chat_id: cc.id, text: "build this home screen", attachments: [img.path, folder.path, "../../etc/passwd", "/etc/hosts"] })).result;
  await finished(r.turn_id);
  const sent = entries();
  t.check("Claude Code gets the picture itself as an image block", sent.some((e) => e.user_images?.length === 1 && e.user_images[0].startsWith("image/png:")), JSON.stringify(sent.filter((e) => e.user_images)));
  const prompt = sent.find((e) => e.prompt)?.prompt ?? "";
  t.check("and a note naming the picture and the folder (with its file count)", prompt.startsWith("build this home screen") && prompt.includes(`image: ${img.path}`) && prompt.includes(`folder: ${folder.path}/ (3 files)`), prompt.slice(0, 300));
  t.check("paths outside the project are ignored, not attached", !/etc\/(passwd|hosts)/.test(prompt));
  const hist = (await C.call("turn.history", { chat_id: cc.id })).result;
  const um = (hist.messages ?? hist).find?.((m) => m.role === "user");
  t.check("the chat remembers the attachments for thumbnails; its text stays what was typed", um?.text === "build this home screen" && um.attachments?.length === 2 && um.attachments[0].kind === "image" && um.attachments[1].files === 3, JSON.stringify(um));
  writeFileSync(logFile, "");
  r = (await C.call("turn.submit", { workspace_id: wid, chat_id: cc.id, text: "deploy with this key", attachments: [kitem.path, zip.path, "/etc/hosts"] })).result;
  await finished(r.turn_id);
  const keyPrompt = entries().find((e) => e.prompt)?.prompt ?? "";
  t.check("a key attached to a message: the agent is told its path, that it was not copied, and not to print or commit it", keyPrompt.includes(`left where it is (not copied): ${join(ext, "server.pem")}`) && /never print, copy or commit/.test(keyPrompt) && keyPrompt.includes(`file: ${zip.path}`) && !keyPrompt.includes("/etc/hosts"), keyPrompt.slice(0, 400));
  const hist2 = (await C.call("turn.history", { chat_id: cc.id })).result;
  const um2 = (hist2.messages ?? hist2).filter?.((m) => m.role === "user" && m.text === "deploy with this key")[0];
  t.check("the chat remembers the key as a reference (so it shows as a key chip)", um2?.attachments?.[0]?.ref === true, JSON.stringify(um2?.attachments));
  r = (await C.call("turn.submit", { workspace_id: wid, chat_id: cc.id, text: "plain follow-up" })).result;
  await finished(r.turn_id);
  t.check("a message without attachments carries no note", !entries().filter((e) => e.prompt).at(-1)?.prompt?.includes("Attached by the person"));

  // ---- Codex: local image --------------------------------------------------------------------------------
  const cx = (await C.call("chat.create", { workspace_id: wid, engine: "codex", mode: "auto_edits" })).result.chat;
  writeFileSync(logFile, "");
  r = (await C.call("turn.submit", { workspace_id: wid, chat_id: cx.id, text: "match this", attachments: [img.path] })).result;
  await finished(r.turn_id);
  const turnStart = entries().find((e) => e.bin === "codex" && e.method === "turn/start");
  t.check("Codex gets the picture as a local image", (turnStart?.params?.input ?? []).some((i) => i.type === "localImage" && i.path === join(proj, img.path)), JSON.stringify(turnStart?.params?.input));

  // ---- a Conductor: sees the picture, hands it to workers (also in another project) ----------------------
  const tool = (name, args) => `FAKE_TOOL ${name} ${JSON.stringify(args)}`;
  const w = (await C.call("chief.create", { mode: "warlord", project_id: wid })).result.chief;
  await C.call("chief.update", { chief_id: w.id, project_ids: [wid, aid], max_parallel: 4 });
  writeFileSync(logFile, "");
  // The Conductor's own chat runs in its private home folder; attachments for it live there.
  const [himg, hfolder] = (await C.call("attachment.add", { workspace_id: `chief:${w.id}`, paths: [join(ext, "home-screen.png"), ext] })).result.items;
  const home = realpathSync(join(base, "state", "chiefs", w.id));
  const abs = (rel) => join(home, rel);
  const kref = (await C.call("attachment.add", { workspace_id: `chief:${w.id}`, paths: [join(ext, "server.pem")] })).result.items[0];
  const job = (title, pid, eng, extra) => tool("chat_start", { title, brief: `Goal: ${title} FAKE_REPORT=done FAKE_CHECK`, quotes: ["build this home screen"], project_ids: [pid], engine: eng, ...extra });
  await C.call("chief.note", { chief_id: w.id, text: ["build this home screen", job("api-job", aid, "claude-code", { attachments: [abs(himg.path), abs(hfolder.path), kref.path] }), job("ui-job", wid, "codex", { attachments: [abs(himg.path)] })].join("\n"), attachments: [himg.path, hfolder.path, kref.path] });
  const gotWorkers = await waitFor(() => entries().filter((e) => e.prompt?.startsWith("Goal: api-job")).length && entries().some((e) => e.bin === "codex" && e.method === "turn/start" && JSON.stringify(e.params).includes("ui-job")));
  const e1 = entries();
  const chiefPrompt = e1.find((e) => e.prompt?.includes("<attached>"))?.prompt ?? "";
  t.check("the Conductor is told what was attached, with full paths it can hand on", chiefPrompt.includes(`image: ${abs(himg.path)}`) && chiefPrompt.includes(`folder: ${abs(hfolder.path)}/ (4 files)`) /* 3 + bundle.zip added above */ && /chat_start attachments/.test(chiefPrompt), chiefPrompt.slice(0, 200));
  t.check("the Conductor is also told about the key file (stays where it is)", chiefPrompt.includes(`key or credentials file (stays where it is; give workers its path): ${join(ext, "server.pem")}`), chiefPrompt.slice(0, 500));
  t.check("and sees the picture itself (it has no file tools)", e1.some((e) => e.user_images?.length === 1 && e1.indexOf(e) < e1.findIndex((x) => x.prompt?.startsWith("Goal: api-job"))));
  const apiBrief = e1.find((e) => e.prompt?.startsWith("Goal: api-job"))?.prompt ?? "";
  const copied = readdirSync(join(api, ".opscode/attachments")).filter((n) => n !== ".gitignore");
  t.check("a worker in ANOTHER project gets the picture and folder copied into its own project", copied.length >= 1 && /Reference images \(look at them\): \.opscode\/attachments\/[^ ,]+\/home-screen\.png/.test(apiBrief) && /attached for this task.*design-refs\//.test(apiBrief), apiBrief.slice(0, 500));
  t.check("a worker is told where a key file is (not copied) and how to treat it", new RegExp(`${join(ext, "server.pem").replace(/[.*+?^${}()|[\]\\]/g, "\\$&")} \\(key or credentials: left where it is`).test(apiBrief), apiBrief.slice(0, 700));
  t.check("and its Claude Code sees the picture too", e1.filter((e) => e.user_images).length >= 2);
  const uiStart = e1.find((e) => e.bin === "codex" && e.method === "turn/start" && JSON.stringify(e.params).includes("ui-job"));
  t.check("a Codex worker gets it as a local image, copied into its own project first", (uiStart?.params?.input ?? []).some((i) => i.type === "localImage" && i.path.startsWith(join(proj, ".opscode/attachments/")) && i.path.endsWith("home-screen.png")) && gotWorkers, JSON.stringify(uiStart?.params?.input));
  const ev = (await C.call("chief.get", { chief_id: w.id })).result;
  t.check("the workers ran and reported", ev.items.some((i) => i.chats.length) );

  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
}
process.exit(t.finish());
