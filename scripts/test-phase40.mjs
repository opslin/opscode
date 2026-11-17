// Read aloud (V3, Pocket TTS): the reply is cleaned to sentences, the voice is downloaded only when asked and
// verified (checksum, archive paths, GitHub-only redirects), audio streams one sentence at a time with a limit
// on how far it runs ahead, stop works, and the worker (the model's memory) goes away when idle.
// A stand-in worker makes tones; the real voice is checked separately against the real model.
import { createServer } from "node:http";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";
const t = reporter();
const SP = await import(join(process.cwd(), "dist/runtime/tts/speakable.js"));

// ---- text cleaning -------------------------------------------------------------------------------------------------
const md = "## Done\n\nI fixed the **cart total** in `src/cart.ts`. It now rounds to two decimals, e.g. 2.50 vs. 2.5.\n\n```ts\nconst total = round(sum, 2);\n```\n\n- All twelve tests pass.\n- See [the notes](</Users/me/My Docs/notes.md>) or https://example.com/x?y=1 for details 🙂\n\n| item | price |\n|---|---|\n| tea | 5 |\n\nShall I open a pull request?";
const sents = SP.speakableSentences(md);
const all = sents.join(" ");
t.check("code blocks are skipped (said once), their code is never read", /Code block skipped\.$/.test(all) && !/round\(sum|const total/.test(all));
t.check("a path in code reads as the file name, a link as its label, a URL as 'link'", /in cart\.ts\./.test(all) && /See the notes or link for details\./.test(all) && !/https|My Docs|\/Users/.test(all), all);
t.check("markdown marks, emoji and table bars are gone; the table reads as rows", !/[*#`|]|🙂/.test(all) && /item, price\./.test(all) && /tea, 5\./.test(all) && !/---/.test(all), all);
t.check("'e.g.' and 'vs.' do not end a sentence", sents.some((s) => /e\.g\. 2\.50 vs\. 2\.5\./.test(s)), JSON.stringify(sents));
t.check("headings end like sentences", sents[0].startsWith("Done. I fixed"), sents[0]);
t.check("every sentence is short enough for the voice (<=280) and the first starts quickly (<=160)", sents.every((s) => s.length <= 280) && sents[0].length <= 160);
const long = SP.speakableSentences("A ".repeat(20) + "word, " + "text ".repeat(120));
t.check("one long sentence is broken at commas or spaces", long.length >= 2 && long.every((s) => s.length <= 280), long.map((s) => s.length).join());
t.check("nothing to say: empty list", SP.speakableSentences("```\ncode only\n```").join("") === "Code block skipped." && SP.speakableSentences("   \n 🙂 ").length === 0);
t.check("unclosed code fence at the end is skipped too", !/secret/.test(SP.speakableSentences("Intro here.\n```js\nsecret()").join(" ")));

// ---- fixtures: a fake voice archive served over http -------------------------------------------------------------------
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p40-")));
const FOLDER = "sherpa-onnx-pocket-tts-int8-2026-01-26";
const FILES = ["vocab.json", "test_wavs/bria.wav", "test_wavs/loona.wav"];
function archive(name, folder, files) {
  const src = join(base, `src-${name}`);
  for (const f of files) { mkdirSync(join(src, folder, f, ".."), { recursive: true }); writeFileSync(join(src, folder, f), `data of ${f}`); }
  const out = join(base, `${name}.tar.bz2`);
  execFileSync("/usr/bin/tar", ["-cjf", out, "-C", src, folder]);
  return out;
}
const good = archive("good", FOLDER, FILES);
const wrong = archive("wrong", "other-folder", FILES);
const missing = archive("missing", FOLDER, ["vocab.json"]);
const sha = (f) => createHash("sha256").update(readFileSync(f)).digest("hex");
const server = createServer((req, res) => {
  if (req.url === "/good") res.writeHead(200, { "content-length": readFileSync(good).length }).end(readFileSync(good));
  else if (req.url === "/wrong") res.writeHead(200).end(readFileSync(wrong));
  else if (req.url === "/missing") res.writeHead(200).end(readFileSync(missing));
  else if (req.url === "/redirect") res.writeHead(302, { location: "https://evil.example.com/x.tar.bz2" }).end();
  else if (req.url === "/redir-ok") res.writeHead(302, { location: "/good" }).end();
  else if (req.url === "/gone") res.writeHead(404).end("no");
  else res.writeHead(404).end();
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const port = server.address().port;
const waitFor = async (fn, ms = 10000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(40)) { const v = await fn(); if (v) return v; } return null; };
const workerLog = join(base, "worker.log");
const wlog = () => (existsSync(workerLog) ? readFileSync(workerLog, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const baseEnv = { OPSCODE_TTS_FILES: FILES.join(","), OPSCODE_TTS_WORKER: join(process.cwd(), "scripts/lib/fake-tts-worker.mjs"), OPSCODE_FAKE_TTS_LOG: workerLog, OPSCODE_TTS_IDLE_MS: "700" };

// ---- installer --------------------------------------------------------------------------------------------------------------
async function installWith(path, sum, name) {
  const stateDir = join(base, `state-${name}`);
  const rt = await startRuntime({ env: { ...baseEnv, OPSCODE_TTS_URL: `http://127.0.0.1:${port}${path}`, OPSCODE_TTS_SHA256: sum }, stateDir, keepState: true });
  const C = await session(rt);
  const before = { ...(await C.call("tts.status", {})).result, ttsDir: existsSync(join(stateDir, "tts")) };
  const started = (await C.call("tts.install", {})).result;
  const end = await waitFor(() => C.find("tts.event", (p) => p.ev === "install" && ["done", "error"].includes(p.phase))[0]?.params);
  const after = (await C.call("tts.status", {})).result;
  const phases = C.find("tts.event", (p) => p.ev === "install").map((m) => m.params.phase);
  return { rt, C, stateDir, before, started, end, after, phases };
}
let r = await installWith("/good", sha(good), "good");
t.check("before the download: not installed, nothing happens by itself", r.before.installed === false && r.before.installing === null && r.before.ttsDir === false);
t.check("install: downloads, checks, unpacks, and reports each step", r.started.started === true && r.end?.phase === "done" && ["download", "verify", "extract", "done"].every((p) => r.phases.includes(p)), r.phases.join());
t.check("…the files are in <state>/tts/<model folder>, the temporary files are gone", r.after.installed === true && FILES.every((f) => existsSync(join(r.stateDir, "tts", FOLDER, f))) && readdirSync(join(r.stateDir, "tts")).join() === FOLDER, readdirSync(join(r.stateDir, "tts")).join());
t.check("a second install does nothing", (await r.C.call("tts.install", {})).result.started === false);
const rm = (await r.C.call("tts.remove", {})).result;
t.check("remove deletes the voice files", rm.freed > 0 && !existsSync(join(r.stateDir, "tts", FOLDER)) && (await r.C.call("tts.status", {})).result.installed === false);
await r.rt.stop();

r = await installWith("/good", "0".repeat(64), "badsum");
t.check("a download that does not match its checksum is thrown away", r.end?.phase === "error" && /checksum/.test(r.end.message) && r.after.installed === false && !existsSync(join(r.stateDir, "tts", FOLDER)) && !readdirSync(join(r.stateDir, "tts")).length, JSON.stringify(r.end));
await r.rt.stop();
r = await installWith("/wrong", sha(wrong), "wrongdir");
t.check("an archive with files outside the model folder is refused", r.end?.phase === "error" && /unexpected path/.test(r.end.message) && r.after.installed === false, JSON.stringify(r.end));
await r.rt.stop();
r = await installWith("/missing", sha(missing), "missingfile");
t.check("an archive missing a needed file is refused", r.end?.phase === "error" && r.after.installed === false, JSON.stringify(r.end));
await r.rt.stop();
r = await installWith("/redirect", "", "evilredirect");
t.check("a redirect to a host that is not GitHub is refused", r.end?.phase === "error" && /will not download from evil\.example\.com/.test(r.end.message) && r.after.installed === false, JSON.stringify(r.end));
await r.rt.stop();
r = await installWith("/redir-ok", sha(good), "redirok");
t.check("a normal redirect is followed", r.end?.phase === "done" && r.after.installed === true, JSON.stringify(r.end));
await r.rt.stop();
r = await installWith("/gone", "", "gone");
t.check("a missing file on the server is reported", r.end?.phase === "error" && /404/.test(r.end.message), JSON.stringify(r.end));
await r.rt.stop();

// ---- speaking -----------------------------------------------------------------------------------------------------------------
const spState = join(base, "state-speak");
mkdirSync(join(spState, "tts", FOLDER, "test_wavs"), { recursive: true });
for (const f of FILES) writeFileSync(join(spState, "tts", FOLDER, f), "x");
const rt = await startRuntime({ env: { ...baseEnv, OPSCODE_TTS_URL: "http://127.0.0.1:1/unused", OPSCODE_FAKE_TTS_MS: "60" }, stateDir: spState, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
try {
  const C = await session(rt);
  const evs = (sid) => C.find("tts.event", (p) => p.session === sid).map((m) => m.params);
  t.check("status: installed, the model is not loaded (no memory used) until it speaks", (await C.call("tts.status", {})).result.installed === true && (await C.call("tts.status", {})).result.loaded === false && wlog().length === 0);

  const bad = await C.call("tts.speak", { text: "```\nonly code\n```".replace("only code", "x") });
  t.check("a reply with nothing to read is refused with a reason (code only gets one phrase)", !!bad.result || /nothing to read/.test(bad.error?.message ?? ""));
  const empty = await C.call("tts.speak", { text: "  🙂  " });
  t.check("an empty reply is refused", /nothing to read/.test(empty.error?.message ?? ""), JSON.stringify(empty.error));

  const text = ["First sentence is right here and it is long enough to stand alone.", "Second one follows it closely and also stands on its own two feet.", "Third comes after that one and it keeps the same length again.", "Fourth is next in line and it is a bit longer than the others.", "Fifth keeps it going with yet another reasonably long sentence.", "Sixth is nearly there and it is long enough for the voice.", "Seventh ends it all today with a final sentence of normal size."].join(" ");
  const s1 = (await C.call("tts.speak", { text })).result;
  t.check("speak returns a session and the sentence count", !!s1.session && s1.sentences >= 3, JSON.stringify(s1));
  await waitFor(() => evs(s1.session).filter((e) => e.ev === "audio").length >= 2);
  await sleep(600);
  let audio = evs(s1.session).filter((e) => e.ev === "audio");
  t.check("the model is loaded on first use, the first sentence arrives quickly with a voice name from settings (bria)", wlog().some((e) => e.got === "init") && wlog().find((e) => e.got === "speak")?.voice === "bria" && audio[0]?.i === 0 && audio[0].rate === 24000);
  t.check("generation stops a few sentences ahead of the player (nothing played yet)", audio.length === 4 && audio.at(-1).i === 3 && !evs(s1.session).some((e) => e.ev === "done"), `audio=${audio.length}`);
  const pcm = Buffer.from(audio[0].pcm, "base64");
  t.check("audio is 16-bit mono PCM at 24 kHz, in order", pcm.length > 4000 && pcm.length % 2 === 0 && audio.map((e) => e.i).join() === "0,1,2,3" && audio.every((e) => e.n === s1.sentences));
  await C.call("tts.progress", { session: s1.session, played: 4 });
  await waitFor(() => evs(s1.session).some((e) => e.ev === "done"));
  audio = evs(s1.session).filter((e) => e.ev === "audio");
  t.check("when the player moves on, the rest is generated and 'done' follows the last sentence", audio.length === s1.sentences && evs(s1.session).at(-1).ev === "done", `audio=${audio.length}/${s1.sentences}`);

  // stop mid-way
  const s2 = (await C.call("tts.speak", { text: text + " SLOW one here." })).result;
  await waitFor(() => evs(s2.session).filter((e) => e.ev === "audio").length >= 1);
  await C.call("tts.stop", { session: s2.session });
  await sleep(400);
  t.check("stop ends the session and cancels the sentence being made", evs(s2.session).some((e) => e.ev === "stopped") && wlog().some((e) => e.got === "cancel" && e.id.startsWith(s2.session)));
  const n2 = evs(s2.session).filter((e) => e.ev === "audio").length;
  await sleep(500);
  t.check("nothing more arrives after stop", evs(s2.session).filter((e) => e.ev === "audio").length === n2 && !evs(s2.session).some((e) => e.ev === "done"));

  // a new speak replaces the old one
  const s3 = (await C.call("tts.speak", { text })).result;
  const s4 = (await C.call("tts.speak", { text: "Only this one now." })).result;
  await waitFor(() => evs(s4.session).some((e) => e.ev === "done"));
  t.check("a new request stops the old one first", evs(s3.session).some((e) => e.ev === "stopped") && evs(s4.session).some((e) => e.ev === "done") && s3.session !== s4.session);
  t.check("stopping an unknown session is harmless", (await C.call("tts.stop", { session: s3.session })).result.stopped === false);

  // errors from the voice reach the window
  const s5 = (await C.call("tts.speak", { text: "This one will FAILME for sure." })).result;
  const err = await waitFor(() => evs(s5.session).find((e) => e.ev === "error"));
  t.check("a failing sentence is reported as an error event and ends the session", /fake voice failure/.test(err?.message ?? "") && !evs(s5.session).some((e) => e.ev === "done"));

  // another voice and settings
  t.check("the voice setting only takes a voice name; the speed only 0.75-2", !!(await C.call("settings.set", { patch: { tts_voice: "../x" } })).error && !!(await C.call("settings.set", { patch: { tts_speed: 5 } })).error && !(await C.call("settings.set", { patch: { tts_voice: "loona", tts_speed: 1.25 } })).error);
  const s6 = (await C.call("tts.speak", { text: "Hello there my friend." })).result;
  await waitFor(() => evs(s6.session).some((e) => e.ev === "done"));
  t.check("the chosen voice reaches the worker", wlog().filter((e) => e.got === "speak").at(-1)?.voice === "loona");

  // idle: the worker (the model's memory) goes away
  const pid = wlog().filter((e) => e.got === "init").at(-1)?.pid; // the worker now running (an earlier one was already stopped while idle)
  await waitFor(() => { try { process.kill(pid, 0); return false; } catch { return true; } }, 6000);
  const alive = (() => { try { process.kill(wlog().filter((e) => e.got === "init").at(-1).pid, 0); return true; } catch { return false; } })();
  const st2 = (await C.call("tts.status", {})).result;
  t.check("after a few idle minutes (0.7 s here) the worker process is gone and the status says not loaded", !alive && st2.loaded === false, `alive=${alive} loaded=${st2.loaded} log=${wlog().map((e) => e.got ?? (e.exit ? "EXIT" : "?")).join(",")} pids=${[...new Set(wlog().map((e) => e.pid))].join()}`);
  const s7 = (await C.call("tts.speak", { text: "Back again." })).result;
  await waitFor(() => evs(s7.session).some((e) => e.ev === "done"));
  t.check("speaking again starts a fresh worker", wlog().filter((e) => e.got === "init").length >= 2 && evs(s7.session).some((e) => e.ev === "done"));
} catch (e) {
  t.check("no exception", false, String(e?.stack ?? e));
}
const exit = await rt.stop();
t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);

// not installed: speaking is refused, nothing is downloaded behind your back
const rt2 = await startRuntime({ env: { ...baseEnv, OPSCODE_TTS_URL: "http://127.0.0.1:1/unused" }, stateDir: join(base, "state-empty") });
try {
  const C = await session(rt2);
  const e = await C.call("tts.speak", { text: "Hello there." });
  t.check("speaking without the voice is refused (no silent download)", /not installed/.test(e.error?.message ?? "") && !existsSync(join(base, "state-empty", "tts")), JSON.stringify(e.error));
} catch (e) {
  t.check("no exception (empty)", false, String(e?.stack ?? e));
}
await rt2.stop();
server.close();
process.exit(t.finish());
