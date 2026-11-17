// Live activity: Codex's image tool shows up as a live tool event (start with the prompt,
// end with the saved file), so the Conductor's dock can show progress then the picture;
// the preview RPC serves only a Chief worker's images from its own project or Codex's
// generated_images folder, never anything else.

import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p26-")));
const proj = join(base, "shop");
mkdirSync(proj, { recursive: true });
writeFileSync(join(proj, "package.json"), "{}");
writeFileSync(join(base, "secret.png"), "not yours");
const logFile = join(base, "engines.log");
const env = { OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"), OPSCODE_CODEX_BIN: join(process.cwd(), "scripts/lib/fake-codex.mjs"), OPSCODE_FAKE_ENGINE_LOG: logFile, OPSCODE_FAKE_IMAGE_MS: "300" };
const rt = await startRuntime({ env, stateDir: join(base, "state"), keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const events = [];
  C.on?.("turn.event", (ev) => events.push(ev));
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  await C.call("engines.set", { default_engine: "claude-code" });
  const waitFor = async (fn, ms = 15000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(100)) { const v = await fn(); if (v) return v; } return null; };
  const sh = (await C.call("chief.create", { mode: "shinobi", project_id: wid })).result.chief;
  await C.call("chief.note", { chief_id: sh.id, text: `bag\nFAKE_TOOL chat_start ${JSON.stringify({ title: "Bag", brief: "Goal: bag FAKE_IMAGE=assets/bag.png", quotes: ["bag"], project_ids: [wid], kind: "asset" })}` });
  const worker = await waitFor(async () => (await C.call("chat.list", {})).result.chats.find((c) => c.title === "Bag" && c.chief?.role !== "home"));
  await waitFor(async () => existsSync(join(proj, "assets/bag.png")) && (await C.call("chat.list", {})).result.chats.find((c) => c.id === worker?.id)?.usage);
  await sleep(800);
  const hist = (await C.call("turn.history", { workspace_id: wid, chat_id: worker.id })).result;
  const msgs = hist?.messages ?? hist?.history ?? [];
  const parts = msgs.flatMap((m) => m.parts ?? []);
  const img = parts.find((p) => p.kind === "tool" && p.tool === "image_generation");
  t.check("Codex's image tool is a live tool card with its prompt", !!img && /Generate image: A glossy 3D shopping bag icon/.test(img.summary), JSON.stringify(img ?? parts.map((p) => p.tool)).slice(0, 200));
  t.check("and it ends with the saved file's path", img?.status === "done" && img.output === join(proj, "assets/bag.png"), JSON.stringify([img?.status, img?.output]));
  t.check("the file edit after it is a card too", parts.some((p) => p.kind === "tool" && p.tool === "write_file" && /manifest\.json/.test(p.summary)));

  const ok = await C.call("chief.worker_image", { chat_id: worker.id, path: img?.output ?? "" });
  t.check("the preview RPC returns the worker's image as a PNG", ok.result?.data_url?.startsWith("data:image/png;base64,") && ok.result.bytes > 0, JSON.stringify(ok.error ?? Object.keys(ok.result ?? {})));
  const rel = await C.call("chief.worker_image", { chat_id: worker.id, path: "assets/bag.png" });
  t.check("a path relative to the project works too", !!rel.result?.data_url);
  const out = await C.call("chief.worker_image", { chat_id: worker.id, path: join(base, "secret.png") });
  t.check("an image outside the project is refused", !!out.error && /outside/.test(out.error.message), JSON.stringify(out.error));
  const dots = await C.call("chief.worker_image", { chat_id: worker.id, path: "../secret.png" });
  t.check("so is ../ out of it", !!dots.error);
  const notImg = await C.call("chief.worker_image", { chat_id: worker.id, path: "package.json" });
  t.check("and anything that is not an image", !!notImg.error && /not an image/.test(notImg.error.message));
  const home = await C.call("chief.worker_image", { chat_id: sh.chat_id, path: "assets/bag.png" });
  t.check("only a worker chat's images (not the Conductor's own chat)", !!home.error, JSON.stringify(home.error));
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
}
process.exit(t.finish());
