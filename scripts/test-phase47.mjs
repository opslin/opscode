// Windows support (checked from any system): npm .cmd shims resolved to what they really run, program lookup by extension,
// the shells, the wording and shortcuts for other systems, the speech model downloader's safety checks, and the
// dictation path through the runtime (window-captured audio -> speech helper -> events). The Windows installer itself is
// built by scripts/package-win.mjs and can only be run on Windows.
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync, copyFileSync } from "node:fs";
import { createServer } from "node:http";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const dist = (p) => import(join(process.cwd(), "dist", p));
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p47-")));

// ---- npm shims ------------------------------------------------------------------------------------------------------------
{
  const { launch, shimTarget, programExts } = await dist("runtime/proc.js");
  const bin = join(base, "npm-global");
  mkdirSync(join(bin, "node_modules/@openai/codex/bin"), { recursive: true });
  mkdirSync(join(bin, "node_modules/@anthropic-ai/claude-code"), { recursive: true });
  writeFileSync(join(bin, "node_modules/@openai/codex/bin/codex.js"), "console.log(JSON.stringify(process.argv.slice(2)))");
  writeFileSync(join(bin, "node_modules/@anthropic-ai/claude-code/cli.js"), "console.log('claude')");
  const NPM_SHIM = (target) => `@ECHO off\r\nGOTO start\r\n:find_dp0\r\nSET dp0=%~dp0\r\nEXIT /b\r\n:start\r\nSETLOCAL\r\nCALL :find_dp0\r\n\r\nIF EXIST "%dp0%\\node.exe" (\r\n  SET "_prog=%dp0%\\node.exe"\r\n) ELSE (\r\n  SET "_prog=node"\r\n  SET PATHEXT=%PATHEXT:;.JS;=;%\r\n)\r\n\r\nendLocal & goto #_undefined_# 2>NUL || title %COMSPEC% & "%_prog%"  "%dp0%\\${target}" %*\r\n`;
  writeFileSync(join(bin, "codex.cmd"), NPM_SHIM("node_modules\\@openai\\codex\\bin\\codex.js"));
  writeFileSync(join(bin, "claude.cmd"), NPM_SHIM("node_modules\\@anthropic-ai\\claude-code\\cli.js"));
  const sys = "You are the voice of Opscode.\nLine two with \"quotes\" & more";
  const c = launch(join(bin, "codex.cmd"), ["app-server", "--flag"], true);
  t.check("a npm .cmd shim is run as its Node script with Electron-as-Node (no cmd.exe)", c.file === process.execPath && c.args[0] === join(bin, "node_modules/@openai/codex/bin/codex.js") && c.args.slice(1).join() === "app-server,--flag" && c.env.ELECTRON_RUN_AS_NODE === "1" && !c.verbatim, JSON.stringify(c));
  const cl = launch(join(bin, "claude.cmd"), ["-p", "--system-prompt", sys], true);
  t.check("…so a multi-line system prompt with quotes and & reaches the program untouched", cl.args.at(-1) === sys && cl.file === process.execPath);
  t.check("a program (.exe) is started as it is", launch("C:\\tools\\claude.exe", ["-p"], true).file === "C:\\tools\\claude.exe");
  t.check("a script is run with Electron-as-Node", launch("C:\\x\\tool.mjs", ["a"], true).args.join() === "C:\\x\\tool.mjs,a" && launch("C:\\x\\tool.mjs", [], true).env.ELECTRON_RUN_AS_NODE === "1");
  writeFileSync(join(bin, "odd.cmd"), "@echo hello %*\r\n");
  const odd = launch(join(bin, "odd.cmd"), ["a b", "c%PATH%"], true);
  t.check("an unreadable shim goes through cmd.exe with every argument quoted and % escaped", /cmd(\.exe)?$/i.test(odd.file) && odd.verbatim && odd.args.at(-1).includes('"a b"') && odd.args.at(-1).includes("%%PATH%%"), JSON.stringify(odd));
  t.check("on other systems nothing changes", launch("/usr/local/bin/claude", ["-p"], false).file === "/usr/local/bin/claude");
  t.check("program extensions: Windows prefers real programs and never the bare npm script", programExts(true).join() === ".exe,.com,.cmd,.bat" && programExts(false).join() === "");
  t.check("shimTarget finds the script a shim runs", shimTarget(join(bin, "codex.cmd"))?.js?.endsWith("codex.js") === true);
  // The same launch really starts a script with the right arguments (here with this system's own Node).
  const r = spawnSync(c.file, c.args, { env: { ...process.env, ...c.env }, encoding: "utf8" });
  t.check("…and it runs: the script saw the arguments", r.stdout.trim() === JSON.stringify(["app-server", "--flag"]), r.stdout + r.stderr);
}

// ---- shells -------------------------------------------------------------------------------------------------------------------
{
  const { shellArgs } = await dist("runtime/terminals.js");
  t.check("PowerShell: interactive, and one command", shellArgs("C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe").join() === "-NoLogo" && shellArgs("C:\\Program Files\\PowerShell\\7\\pwsh.exe", "ls").join() === "-NoLogo,-NoProfile,-Command,ls");
  t.check("cmd.exe: interactive, and one command", shellArgs("C:\\Windows\\System32\\cmd.exe").length === 0 && shellArgs("cmd.exe", "dir").join() === "/d,/s,/c,dir");
  t.check("a Unix shell: login shell, and -lc", shellArgs("/bin/zsh").join() === "-l" && shellArgs("/bin/zsh", "ls").join() === "-lc,ls");
}

// ---- the words and shortcuts for other systems ---------------------------------------------------------------------------------------
{
  const { makeWords } = await import(join(process.cwd(), "src/renderer/dom.js"));
  const win = makeWords(false, true), mac = makeWords(true, false);
  const s = "Dictate (⌥Space). Speech becomes text on this Mac. Save with ⌘S, reveal in Finder, allow in System Settings.";
  t.check("Windows: the mic shortcut, Ctrl, this PC, File Explorer, Settings", win(s) === "Dictate (Ctrl+Shift+Space). Speech becomes text on this PC. Save with Ctrl+S, reveal in File Explorer, allow in Settings.", win(s));
  t.check("macOS: unchanged", mac(s) === s);
  t.check("only whole words change (\"Macro\", \"Findering\")", win("Macro and Mac mini") === "Macro and Mac mini" && win("Your Mac is fine") === "Your PC is fine");
}

// ---- the speech model downloader refuses what it should -------------------------------------------------------------------------------
{
  const { ensureSpeechModel, speechInstalled, tarProgram } = await dist("runtime/voice/models.js");
  const dir = join(base, "voice-bad");
  const before = process.env.OPSCODE_VOICE_MODEL_URL;
  process.env.OPSCODE_VOICE_MODEL_URL = "http://evil.example.com/model.tar.bz2";
  let err = "";
  try { await ensureSpeechModel(dir, () => {}); } catch (e) { err = e.message; }
  t.check("it will not download from a host that is not GitHub", /will not download from/.test(err), err);
  process.env.OPSCODE_VOICE_MODEL_URL = before ?? "";
  if (before === undefined) delete process.env.OPSCODE_VOICE_MODEL_URL;
  t.check("not installed until all files are there", !speechInstalled(dir));
  t.check("tar is found (Windows 10+ has its own)", typeof tarProgram() === "string" && tarProgram().length > 0);
}

// ---- dictation through the runtime with the window-captured speech helper ------------------------------------------------------------
{
  const cache = process.env.OPSCODE_VOICE_TEST_DIR || join(tmpdir(), "opscode-voice-test-cache");
  const state = join(base, "state");
  mkdirSync(join(state, "voice", "kroko"), { recursive: true });
  const have = existsSync(join(cache, "kroko", "encoder.onnx"));
  if (have) {
    for (const f of ["encoder.onnx", "decoder.onnx", "joiner.onnx", "tokens.txt"]) copyFileSync(join(cache, "kroko", f), join(state, "voice", "kroko", f));
    copyFileSync(join(cache, "silero_vad.onnx"), join(state, "voice", "silero_vad.onnx"));
  }
  const proj = join(base, "Proj"); mkdirSync(proj, { recursive: true });
  const rt = await startRuntime({ env: { OPSCODE_VOICE_ENGINE: "sherpa", OPSCODE_TTS_URL: "http://127.0.0.1:1/x", OPSCODE_TTS_FILES: "a" }, stateDir: state, keepState: true });
  t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
  try {
    const C = await session(rt);
    const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
    const st = (await C.call("voice.status", {})).result;
    t.check("voice.status: the window captures the microphone; the model is there or will be fetched", st.helper && st.available && st.capture === "window" && st.engine === "kroko" && st.installed === have, JSON.stringify(st));
    if (have) {
      const b = readFileSync(join(process.cwd(), "scripts/fixtures/voice/a.wav")); const off = b.indexOf("data") + 8;
      const pcm = new Int16Array(b.buffer.slice(b.byteOffset + off, b.byteOffset + b.length - ((b.length - off) % 2)));
      const sil = new Int16Array(16000 * 2);
      const all = new Int16Array(pcm.length + sil.length); all.set(pcm); all.set(sil, pcm.length);
      const started = (await C.call("voice.start", { workspace_id: wid })).result;
      t.check("voice.start gives a session", !!started.session);
      for (let i = 0; i < all.length; i += 1600) {
        const chunk = all.subarray(i, Math.min(i + 1600, all.length));
        await C.call("voice.audio", { session: started.session, pcm: Buffer.from(chunk.buffer, chunk.byteOffset, chunk.byteLength).toString("base64") });
      }
      await C.call("voice.stop", {});
      for (const end = Date.now() + 15000; Date.now() < end && !C.find("voice.event", (p) => p.ev === "done" && p.session === started.session)[0]; await sleep(50));
      const evs = C.find("voice.event", (p) => p.session === started.session).map((m) => m.params);
      const done = evs.find((e) => e.ev === "done");
      t.check("the window's audio comes back as started → partial words → final → done with the sentence", evs.some((e) => e.ev === "started") && evs.some((e) => e.ev === "partial") && evs.some((e) => e.ev === "final") && /please add a dark mode switch to the settings page/i.test(done?.text ?? ""), JSON.stringify(evs.map((e) => e.ev)));
      const refused = await C.call("voice.audio", { session: started.session, pcm: "AAAA" });
      t.check("audio for a finished session is ignored", refused.result?.ok === false);
    } else console.log("SKIP  dictation through the runtime (run scripts/test-phase46.mjs once to download the speech model)");
  } finally { await rt.stop(); }
}
// ---- voice mode itself through the same helper: speech in, the agent hears it, answers aloud ----------------------------------------------
{
  const cache = process.env.OPSCODE_VOICE_TEST_DIR || join(tmpdir(), "opscode-voice-test-cache");
  if (!existsSync(join(cache, "kroko", "encoder.onnx"))) console.log("SKIP  voice mode through the speech helper (run scripts/test-phase46.mjs once to download the speech model)");
  else {
    const FOLDER = "sherpa-onnx-pocket-tts-int8-2026-01-26";
    const state = join(base, "state2");
    mkdirSync(join(state, "voice", "kroko"), { recursive: true });
    for (const f of ["encoder.onnx", "decoder.onnx", "joiner.onnx", "tokens.txt"]) copyFileSync(join(cache, "kroko", f), join(state, "voice", "kroko", f));
    copyFileSync(join(cache, "silero_vad.onnx"), join(state, "voice", "silero_vad.onnx"));
    mkdirSync(join(state, "tts", FOLDER), { recursive: true });
    writeFileSync(join(state, "tts", FOLDER, "a.onnx"), "x");
    const tlog = join(base, "tts.log");
    const brainReqs = [];
    const sse = (events) => events.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
    const text = (x) => sse([{ type: "content_block_start", index: 0, content_block: { type: "text", text: "" } }, { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: x } }, { type: "content_block_stop", index: 0 }, { type: "message_delta", delta: { stop_reason: "end_turn" } }]);
    const server = createServer((req, res) => { let b = ""; req.on("data", (c) => (b += c)); req.on("end", () => { const j = JSON.parse(b); const last = j.messages.at(-1); const lt = typeof last.content === "string" ? last.content : last.content.map((x) => x.text ?? "").join("\n"); brainReqs.push(lt); res.writeHead(200, { "content-type": "text/event-stream" }); res.end(text("Okay, I heard you.")); }); });
    await new Promise((r) => server.listen(0, "127.0.0.1", r));
    const proj = join(base, "Proj2"); mkdirSync(proj, { recursive: true });
    const rt = await startRuntime({ env: { OPSCODE_VOICE_ENGINE: "sherpa", OPSCODE_TTS_URL: "http://127.0.0.1:1/x", OPSCODE_TTS_FILES: "a.onnx", OPSCODE_TTS_WORKER: join(process.cwd(), "scripts/lib/fake-tts-worker.mjs"), OPSCODE_FAKE_TTS_LOG: tlog, OPSCODE_FAKE_TTS_MS: "20" }, stateDir: state, keepState: true });
    try {
      const C = await session(rt);
      const ok = async (m, p) => { const r = await C.call(m, p); if (r.error) throw new Error(`${m}: ${r.error.message}`); return r.result; };
      const wid = (await ok("workspace.add", { path: proj })).workspace.id;
      await ok("provider.set", { id: "anthropic", api_key: "sk-test-1234", base_url: `http://127.0.0.1:${server.address().port}`, model: "m" });
      const S = (await ok("voiceagent.start", { workspace_id: wid, brain: { engine: "api" } })).session;
      t.check("voice mode starts on the speech helper", !!S);
      const b = readFileSync(join(process.cwd(), "scripts/fixtures/voice/a.wav")); const off = b.indexOf("data") + 8;
      const pcm = new Int16Array(b.buffer.slice(b.byteOffset + off, b.byteOffset + b.length - ((b.length - off) % 2)));
      const all = new Int16Array(16000 + pcm.length + 16000 * 3); all.set(pcm, 16000);
      await sleep(500);
      for (let i = 0; i < all.length; i += 1600) { const c = all.subarray(i, Math.min(i + 1600, all.length)); await ok("voiceagent.audio", { session: S, pcm: Buffer.from(c.buffer, c.byteOffset, c.byteLength).toString("base64") }); }
      for (const end = Date.now() + 20000; Date.now() < end && !brainReqs.length; await sleep(60));
      t.check("the agent was given what was said, in the person's words", /<heard>Please add a dark mode switch to the settings page\.<\/heard>/.test(brainReqs[0] ?? ""), JSON.stringify(brainReqs[0]));
      for (const end = Date.now() + 10000; Date.now() < end && !(existsSync(tlog) && /Okay, I heard you/.test(readFileSync(tlog, "utf8"))); await sleep(60));
      t.check("…and its answer is spoken (sent to the voice)", existsSync(tlog) && /Okay, I heard you/.test(readFileSync(tlog, "utf8")));
      const evs = C.find("voiceagent.event", (p) => p.session === S).map((m) => m.params);
      t.check("the window is shown partial words, then what was heard", evs.some((e) => e.ev === "partial") && evs.some((e) => e.ev === "heard"), JSON.stringify([...new Set(evs.map((e) => e.ev))]));
      await ok("voiceagent.stop", { session: S });
    } finally { await rt.stop(); server.close(); }
  }
}
process.exit(t.finish());
