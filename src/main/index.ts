// App entry: single-instance lock, scheme registration, runtime supervisor,
// window + IPC wiring, and orderly shutdown of the runtime on quit.

import { app, BrowserWindow, ipcMain, Menu, MenuItem } from "electron";
import { appendFileSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, renameSync, rmSync, statSync, writeFileSync } from "node:fs";
import { createServer as createHttpServer } from "node:http";
import { execFileSync } from "node:child_process";
import { tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import { registerSchemePrivileges, serveAppScheme } from "./scheme";
import { lockDownPermissions } from "./permissions";
import { createMainWindow, focusWindow } from "./window";
import { registerIpc } from "./ipc";
import { RuntimeSupervisor } from "./runtime";
import { MainRpcClient } from "./rpcClient";
import { BrowserHost } from "./browserHost";
import { rendererBridge } from "./rendererBridge";
import { Notch } from "./notch";
import { APP_URL, CH, isOwnFrame } from "../shared/ipc";

// Must run before `ready`.
registerSchemePrivileges();

// Smoke runs get a throwaway profile so they never touch real projects/settings.
// Preferred: scripts/smoke.mjs creates it (OPSCODE_SMOKE_PROFILE) and deletes it
// after Electron fully exits — Chromium flushes profile files during shutdown,
// after any cleanup we could do in-process. Fallback: make our own and sweep
// leftovers from earlier runs (our prefix only).
const SMOKE = !!process.env.OPSCODE_SMOKE;
const SMOKE_PREFIX = "opscode-smoke-profile-";
let smokeUserData: string | undefined;
// The real-model browser test (scripts/realtest-browser.mjs) also runs on a throwaway profile.
if (process.env.OPSCODE_REALTEST && process.env.OPSCODE_SMOKE_PROFILE) app.setPath("userData", process.env.OPSCODE_SMOKE_PROFILE);
// Development only: run from source beside the installed app on a separate profile (its own data and single-instance lock).
if (!app.isPackaged && process.env.OPSCODE_PROFILE) app.setPath("userData", process.env.OPSCODE_PROFILE);
if (SMOKE) {
  smokeUserData = process.env.OPSCODE_SMOKE_PROFILE;
  if (!smokeUserData) {
    for (const name of readdirSync(tmpdir())) {
      if (name.startsWith(SMOKE_PREFIX)) rmSync(join(tmpdir(), name), { recursive: true, force: true });
    }
    smokeUserData = mkdtempSync(join(tmpdir(), SMOKE_PREFIX));
  }
  app.setPath("userData", smokeUserData);
  // Read aloud plays through <audio>; the smoke has no person to click first, and nobody wants to hear its tones.
  app.commandLine.appendSwitch("autoplay-policy", "no-user-gesture-required");
  // Voice mode captures the microphone in the window; the smoke run has none, so Chromium plays a test tone instead.
  app.commandLine.appendSwitch("use-fake-device-for-media-stream");
  app.commandLine.appendSwitch("use-fake-ui-for-media-stream");
}

// The app's name (menu bar, Dock, About) and, when running from source, its Dock icon.
app.setName("Opscode");
// Windows groups the taskbar button, notifications and jump lists by this id.
if (process.platform === "win32") app.setAppUserModelId("com.opscode.app");
if (process.platform === "darwin" && !app.isPackaged) {
  const dockIcon = join(__dirname, "..", "..", "assets", "brand", "logo", "opscode-app-icon-1024.png");
  if (existsSync(dockIcon)) app.dock?.setIcon(dockIcon);
}

let mainWindow: BrowserWindow | null = null;
let supervisor: RuntimeSupervisor | null = null;
let browserHost: BrowserHost | null = null;
let shuttingDown = false;
/** Set once the person really quits (⌘Q, the menu): then the window closes instead of hiding. */
let quitting = false;
let notch: Notch | null = null;

// The app's own log file (a packaged Windows app has no console): <app data>/logs/opscode.log, 2 MB, one older copy kept.
let logFile: string | null = null;
const fileLog = (line: string): void => {
  if (SMOKE) return;
  try {
    if (!logFile) {
      const dir = join(app.getPath("userData"), "logs");
      mkdirSync(dir, { recursive: true });
      logFile = join(dir, "opscode.log");
      try { if (statSync(logFile).size > 2_000_000) renameSync(logFile, `${logFile}.1`); } catch { /* new file */ }
      appendFileSync(logFile, `\n---- ${new Date().toISOString()} Opscode ${app.getVersion()} ${process.platform} ${process.arch} Electron ${process.versions.electron} ----\n`);
    }
    appendFileSync(logFile, `${new Date().toISOString().slice(11, 23)} ${line}\n`);
  } catch { /* logging must never break the app */ }
};
const log = (line: string): void => { console.log(line); fileLog(line); };
process.on("uncaughtException", (e) => fileLog(`uncaught: ${e instanceof Error ? e.stack : String(e)}`));
process.on("unhandledRejection", (e) => fileLog(`unhandled rejection: ${e instanceof Error ? e.stack : String(e)}`));
const pause = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * Smoke mode (OPSCODE_SMOKE=1): renderer loads over opscode://app/, the runtime
 * becomes ready, main completes an RPC hello + ping, and the renderer's own RPC
 * client reaches "ready" (which proves the Origin + subprotocol auth path).
 */
async function runSmoke(win: BrowserWindow, sup: RuntimeSupervisor): Promise<void> {
  const finish = async (code: number, message: string): Promise<void> => {
    (code === 0 ? console.log : console.error)(`OPSCODE_SMOKE: ${message}`);
    await sup.stop();
    app.exit(code);
  };
  const watchdog = setTimeout(() => void finish(2, "FAIL timed out"), 180_000);

  win.webContents.setAudioMuted(true);
  // Surface renderer console output (errors in app.js would otherwise be invisible).
  // Electron 33 signature: (event, level, message, line, sourceId).
  win.webContents.on("console-message", (_event, level, message, line, sourceId) => {
    console.log(`OPSCODE_SMOKE: [renderer level=${level}] ${message} (${sourceId}:${line})`);
  });

  try {
    await new Promise<void>((resolve, reject) => {
      win.webContents.once("did-finish-load", () => resolve());
      win.webContents.once("did-fail-load", (_e, code, desc) => reject(new Error(`load failed ${code} ${desc}`)));
    });
    console.log("OPSCODE_SMOKE: renderer loaded from", win.webContents.getURL());

    await sup.waitReady(15_000);
    const client = new MainRpcClient(sup.endpoint);
    const hello = await client.open();
    const pong = await client.call<{ pong: boolean }>("runtime.ping", { sent_at: Date.now() });
    client.close();
    console.log(`OPSCODE_SMOKE: main RPC ok (runtime ${hello.version}, rev ${hello.protocol_revision}, pong=${pong.pong})`);
    // The runtime must not be a second visible app: on macOS it runs from the bundle's background-only Helper (no Dock icon).
    if (process.platform === "darwin" && sup.pid) {
      // The runtime renames itself in `ps`, so ask which program file it is running.
      const cmd = execFileSync("lsof", ["-a", "-p", String(sup.pid), "-d", "txt", "-Fn"], { encoding: "utf8" }).split("\n").find((l) => l.startsWith("n")) ?? "";
      if (!/Helper/.test(cmd)) throw new Error(`the runtime runs from the app's own program (it would get a Dock icon): ${cmd.trim().slice(0, 120)}`);
      console.log("OPSCODE_SMOKE: runtime runs from the background-only Helper (no extra Dock icon)");
    }

    let state = "missing";
    for (const deadline = Date.now() + 15_000; Date.now() < deadline; await pause(200)) {
      state = await win.webContents.executeJavaScript("window.__opscodeRpc ? window.__opscodeRpc.state : 'missing'");
      if (state === "ready") break;
    }
    if (state !== "ready") {
      const diag = await win.webContents.executeJavaScript(
        `JSON.stringify({ bridge: typeof window.opscode, runtime: window.opscode ? window.opscode.runtime : "n/a" })`,
      );
      throw new Error(`renderer RPC state is "${state}"; diagnostics ${diag}`);
    }
    console.log("OPSCODE_SMOKE: renderer RPC ready (origin + subprotocol auth ok)");

    if (process.env.OPSCODE_SMOKE_FOCUS === "voice-settings") {
      const result = await win.webContents.executeJavaScript(`(async () => {
        const until = async (find) => {
          for (const end = Date.now() + 10000; Date.now() < end;) {
            const result = await find();
            if (result) return result;
            await new Promise((r) => setTimeout(r, 50));
          }
          throw new Error("voice settings did not update");
        };
        const get = (label) => document.querySelector('select[aria-label="' + label + '"]');
        (await until(() => document.querySelector('[aria-label="Settings"]'))).click();
        await until(() => get("Microphone language")?.querySelector('option[value="hi"]') &&
          get("Spoken reply language")?.querySelector('option[value="hi"]') &&
          document.querySelector('[data-voice="action"]')?.textContent.includes("575 MB") &&
          document.querySelector('[data-tts="action"]')?.textContent.includes("Download"));
        for (const label of ["Microphone language", "Spoken reply language"]) {
          const select = get(label);
          select.value = "hi";
          select.dispatchEvent(new Event("change", { bubbles: true }));
          await until(() => get(label)?.value === "hi");
          await new Promise((r) => setTimeout(r, 200));
        }
        await until(() => get("Speaking voice")?.querySelector('option[value="hi-priya"]'));
        return (await window.__opscodeRpc.call("settings.get", {})).settings;
      })()`);
      if (result.voice_locale !== "hi" || result.tts_locale !== "hi") throw new Error("Hindi voice settings were not saved");
      clearTimeout(watchdog);
      await finish(0, "PASS (voice settings, model controls, and persisted Hindi selections)");
      return;
    }

    // Crash recovery: kill the runtime; the supervisor must restart it on the
    // same port/token and the renderer client must reconnect by itself.
    const crashedPid = sup.pid;
    if (crashedPid === undefined) throw new Error("no runtime pid to crash");
    process.kill(crashedPid, "SIGKILL");
    await pause(300);
    await sup.waitReady(15_000);
    if (sup.pid === crashedPid) throw new Error("runtime was not restarted");
    state = "offline";
    for (const deadline = Date.now() + 15_000; Date.now() < deadline; await pause(200)) {
      state = await win.webContents.executeJavaScript("window.__opscodeRpc.state");
      if (state === "ready") break;
    }
    if (state !== "ready") throw new Error(`renderer did not reconnect after crash (state "${state}")`);
    console.log(`OPSCODE_SMOKE: crash recovery ok (pid ${crashedPid} -> ${sup.pid}, renderer reconnected)`);

    // Phase 3 through the real spawn path: project + PTY under Electron-as-Node,
    // and the renderer's Files panel picks the project up via workspace.changed.
    const project = mkdtempSync(join(tmpdir(), "opscode-smoke-project-"));
    writeFileSync(join(project, "hello-smoke.txt"), "hi\n");
    const c = new MainRpcClient(sup.endpoint);
    await c.open();
    const output = new Map<string, string>();
    const exits = new Map<string, number>();
    c.on<{ terminal_id: string; data: string }>("term.output", (p) => output.set(p.terminal_id, (output.get(p.terminal_id) ?? "") + p.data));
    c.on<{ terminal_id: string; exit_code: number }>("term.exit", (p) => exits.set(p.terminal_id, p.exit_code));
    const { workspace } = await c.call<{ workspace: { id: string } }>("workspace.add", { path: project });
    const term = await c.call<{ terminal_id: string }>("term.open", { workspace_id: workspace.id, command: "echo smoke-$((6*7))" });
    for (const deadline = Date.now() + 10_000; Date.now() < deadline && !exits.has(term.terminal_id); ) await pause(100);
    const termOut = output.get(term.terminal_id) ?? "";
    if (exits.get(term.terminal_id) !== 0 || !termOut.includes("smoke-42")) {
      throw new Error(`PTY under Electron failed: exit=${exits.get(term.terminal_id)} out=${JSON.stringify(termOut)}`);
    }
    console.log("OPSCODE_SMOKE: PTY terminal ok under Electron-as-Node (smoke-42)");

    const ev = async <T,>(code: string): Promise<T> => {
      try {
        return (await win.webContents.executeJavaScript(code)) as T;
      } catch (e) {
        throw new Error(`${e instanceof Error ? e.message : String(e)} — in: ${code.slice(0, 160)}`);
      }
    };
    const until = async (code: string, what: string, ms = 10_000): Promise<void> => {
      for (const deadline = Date.now() + ms; Date.now() < deadline; await pause(150)) {
        if (await ev<boolean>(code)) return;
      }
      // Say what the window shows instead, so a failing step can be understood from the log alone.
      const store = await ev<string>("import('./store.js').then((m) => JSON.stringify({ page: m.state.page, conn: m.state.conn, workspaces: (m.state.workspaces ?? []).length, active: m.state.active })).catch((e) => String(e))").catch(() => "?");
      console.log(`OPSCODE_SMOKE: store ${store}`);
      const seen = await ev<string>("JSON.stringify({ title: document.title, sidebar: (document.querySelector('.sidebar') ?? document.body).innerText.slice(0, 300), current: [...document.querySelectorAll('.sidebar-item')].map((e) => (e.getAttribute('aria-current') ?? '-') + ':' + e.textContent.trim().slice(0, 40)).slice(0, 8) })").catch(() => "?");
      throw new Error(`renderer did not ${what} (window: ${seen})`);
    };
    const click = (text: string, sel = ".pane-tab") =>
      ev(`[...document.querySelectorAll(${JSON.stringify(sel)})].find((e) => e.textContent.trim() === ${JSON.stringify(text)})?.click()`);
    const shotDir = process.env.OPSCODE_SHOT_DIR;
    const shot = async (name: string): Promise<void> => {
      if (!shotDir) return;
      await pause(350);
      const img = await win.webContents.capturePage();
      writeFileSync(join(shotDir, `${name}.png`), img.toPNG());
    };

    // The workspace.changed push makes the new project active; its sidebar row appears.
    await until("!!document.querySelector('.sidebar-item[aria-current=true] .sidebar-label') && document.title.includes('Opscode')", "show the project in the sidebar");

    // Chat: send through the real composer and wait for the streamed stub reply.
    await shot("01-chat-empty");
    await ev(`(() => { const t = document.querySelector('.chat:not([hidden]) textarea'); t.value = 'hello from smoke'; t.dispatchEvent(new Event('input', { bubbles: true })); document.querySelector('.chat:not([hidden]) .send').click(); })()`);
    await until("document.querySelector('.msg-assistant .body')?.textContent.includes('hello from smoke') && !document.querySelector('.caret')", "stream a chat reply into the transcript");
    console.log("OPSCODE_SMOKE: renderer chat composer -> turn.submit -> streamed reply");
    await shot("02-chat");

    // Attachments: the + menu offers files/photos (with the shortcut) and a folder; a pasted picture lands in the tray,
    // goes with the message, and shows as a thumbnail in the sent message.
    await ev(`document.querySelector('.chat:not([hidden]) .cmp-icon[aria-label="Add files and more"]').click()`);
    await until(`[...document.querySelectorAll('.menu .menu-label')].map((e) => e.textContent).join('|').startsWith('Add files or photos|Add folder') && document.querySelector('.menu .menu-shortcut')?.textContent === '⌘U'`, "show Add files or photos and Add folder in the + menu");
    await shot("02b-plus-menu");
    await ev(`document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))`);
    await ev(`(async () => {
      const c = document.createElement('canvas'); c.width = 64; c.height = 48; const g = c.getContext('2d'); g.fillStyle = '#d33'; g.fillRect(0, 0, 64, 48);
      const blob = await new Promise((r) => c.toBlob(r, 'image/png'));
      const dt = new DataTransfer(); dt.items.add(new File([blob], 'design.png', { type: 'image/png' }));
      document.querySelector('.chat:not([hidden]) textarea').dispatchEvent(new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true }));
    })()`);
    await until("!!document.querySelector('.chat:not([hidden]) .attach-tray .att-img[data-status=ready] img[src]')", "show a pasted picture in the tray");
    await shot("02c-attach-tray");
    await ev(`(() => { const t = document.querySelector('.chat:not([hidden]) textarea'); t.value = 'match this design'; t.dispatchEvent(new Event('input', { bubbles: true })); document.querySelector('.chat:not([hidden]) .send').click(); })()`);
    await until("!!document.querySelector('.msg-user .att-row .att-img img[src]') && document.querySelector('.chat:not([hidden]) .attach-tray').hidden", "show the sent picture as a thumbnail and empty the tray");
    await until("!document.querySelector('.caret')", "finish the reply with the picture");
    console.log("OPSCODE_SMOKE: renderer attachments: + menu (files/photos ⌘U, folder), pasted picture -> tray -> sent with a thumbnail");

    // Several chats: a second chat via the compose button, switched through the sidebar.
    await ev("document.querySelector('.sb-new').click()");
    await until("document.querySelector('.chat:not([hidden])')?.dataset.empty === 'true'", "open an empty new chat");
    await shot("02b-new-chat");
    // New chat stage: mode switch recolours the frame + background; Normal is back before sending.
    await until("!!document.querySelector('.chat:not([hidden]) .nc-stage canvas') && !!document.querySelector('.chat:not([hidden]) .nc-bot')", "draw the new-chat background and mascot");
    for (const m of ["godmode", "warlord", "shinobi"]) {
      await ev(`document.querySelector('.chat:not([hidden]) .crew-opt[data-crew="${m}"]').click()`);
      await until(`document.querySelector('.chat:not([hidden])').dataset.crew === '${m}' && !!document.querySelector('.chat:not([hidden]) .nc-char') && document.querySelectorAll('.chat:not([hidden]) .nc-stage canvas').length === 2`, `switch the new chat to ${m}`);
      await pause(900);
      await shot(`02b-new-chat-${m}`);
    }
    await ev(`document.querySelector('.chat:not([hidden]) .crew-opt[data-crew="normal"]').click()`);
    await until("document.querySelector('.chat:not([hidden])').dataset.crew === 'normal'", "switch the new chat back to Normal");
    console.log("OPSCODE_SMOKE: renderer new chat: mascot, sonar + stars background, mode switch recolours (GODMODE/WARLORD/SHINOBI)");
    await ev(`(() => { const t = document.querySelector('.chat:not([hidden]) textarea'); t.value = 'second chat hello'; t.dispatchEvent(new Event('input', { bubbles: true })); document.querySelector('.chat:not([hidden]) .send').click(); })()`);
    await until("document.querySelectorAll('.sidebar-item[data-chat]').length === 2 && [...document.querySelectorAll('.chat:not([hidden]) .msg-assistant .body')].some((e) => e.textContent.includes('second chat hello')) && !document.querySelector('.caret')", "create the second chat on its first message");
    await until("!document.querySelector('.pfx-launch-cap') && !document.querySelector('canvas.pfx-launch')", "end the launch animation once the reply streams", 5000);
    await ev("[...document.querySelectorAll('.sidebar-item[data-chat]')].find((e) => e.textContent.includes('hello from smoke'))?.click()");
    await until("[...document.querySelectorAll('.chat:not([hidden]) .bubble')].some((e) => e.textContent === 'hello from smoke') && ![...document.querySelectorAll('.chat:not([hidden]) .bubble')].some((e) => e.textContent === 'second chat hello')", "switch back to the first chat");
    console.log("OPSCODE_SMOKE: renderer chats: new chat, two in the sidebar, switch between them");

    // Permissions live in the composer's Chat settings menu; a badge shows any mode but Supervised.
    const settingsBtn = "document.querySelector('.chat:not([hidden]) [aria-label=\"Chat settings\"]')";
    const badge = "document.querySelector('.chat:not([hidden]) .cmp-mode')";
    await ev(`${settingsBtn}.click()`);
    await until("!!document.querySelector('.menu')", "open the chat settings menu");
    await shot("02c-mode-menu");
    await ev("[...document.querySelectorAll('.menu-item')].find((e) => e.textContent.includes('Read-only')).click()");
    await until(`${badge}.dataset.mode === 'read' && !${badge}.hidden`, "switch the chat to Read-only");
    const modes = await ev<string[]>("window.__opscodeRpc.call('chat.list', {}).then((r) => r.chats.map((c) => c.mode))");
    if (!modes.includes("read")) throw new Error(`runtime did not record the mode: ${JSON.stringify(modes)}`);
    await ev(`${settingsBtn}.click()`);
    await until("!!document.querySelector('.menu')", "reopen the chat settings menu");
    await ev("[...document.querySelectorAll('.menu-item')].find((e) => e.textContent.includes('Full access')).click()");
    await until("!!document.querySelector('.dialog[role=alertdialog]')", "ask before granting full access");
    await shot("02d-full-confirm");
    await ev("[...document.querySelectorAll('.dialog-foot .btn')].find((b) => b.textContent === 'Cancel').click()");
    await until("!document.querySelector('.overlay')", "cancel the full-access prompt");
    if ((await ev<string>(`${badge}.dataset.mode`)) !== "read") throw new Error("cancelling must keep the mode");
    await ev(`${settingsBtn}.click()`);
    await until("!!document.querySelector('.menu')", "reopen the chat settings menu again");
    await ev("[...document.querySelectorAll('.menu-item')].find((e) => e.textContent.includes('Supervised')).click()");
    await until(`${badge}.dataset.mode === 'supervised' && ${badge}.hidden`, "back to Supervised");
    console.log("OPSCODE_SMOKE: renderer permission menu: Read-only, full-access confirm (cancel), Supervised");

    // Side panel: the toggle opens a New tab with the tools grid.
    await ev("document.querySelector('.pane-panel-btn').click()");
    await until("!!document.querySelector('.sp:not([hidden]) .sp-tool[data-kind=files]') && document.querySelectorAll('.sp:not([hidden]) .sp-tool').length === 10", "open the side panel on a New tab with 10 tools");
    await shot("03a-new-tab");
    // Files: from the New tab (it replaces the New tab), see and preview the project's file.
    await ev("document.querySelector('.sp:not([hidden]) .sp-tool[data-kind=files]').click()");
    await until("[...document.querySelectorAll('.sp:not([hidden]) .file__name')].some((e) => e.textContent === 'hello-smoke.txt') && document.querySelectorAll('.sp:not([hidden]) .sp-tab').length === 1", "list the project's file in a Files tab");
    console.log("OPSCODE_SMOKE: renderer side panel: New tab -> Files lists the project (fs.list)");
    await ev("[...document.querySelectorAll('.sp:not([hidden]) .file')].find((e) => e.textContent.includes('hello-smoke.txt'))?.click()");
    await until("document.querySelector('.sp:not([hidden]) .preview-code')?.textContent.trim() === 'hi'", "preview the file");
    await shot("03-files");

    // Terminal: a second tab; xterm mounts and a real shell prints into it.
    const before = await ev<number>("window.__opscodeRpc.call('term.list', {}).then((r) => r.terminals.length)");
    await ev("document.querySelector('.sp:not([hidden]) .sp-tab-new').click()");
    await until("!!document.querySelector('.sp:not([hidden]) [data-surface=new]:not([hidden]) .sp-tool[data-kind=terminal]')", "open another New tab");
    await ev("document.querySelector('.sp:not([hidden]) [data-surface=new]:not([hidden]) .sp-tool[data-kind=terminal]').click()");
    await until("!!document.querySelector('.sp:not([hidden]) [data-surface=terminal] .xterm')", "mount xterm");
    await until(`window.__opscodeRpc.call('term.list', {}).then((r) => r.terminals.length > ${before})`, "open a PTY for the Terminal tab");
    await until("document.querySelector('.sp:not([hidden]) [data-surface=terminal] .xterm-rows')?.textContent.trim().length > 0", "render shell output in xterm");
    console.log("OPSCODE_SMOKE: renderer side panel Terminal tab opens a PTY and renders it with xterm");
    await shot("04-terminal");

    // Actions: save a personal action, run it, see it pass; output opens in a Terminal tab.
    await ev("document.querySelector('.sp:not([hidden]) .sp-tab-new').click()");
    await ev("document.querySelector('.sp:not([hidden]) [data-surface=new]:not([hidden]) .sp-tool[data-kind=actions]').click()");
    await until("!!document.querySelector('.sp:not([hidden]) [data-surface=actions]') && [...document.querySelectorAll('.sp:not([hidden]) [data-surface=actions] .btn')].some((b) => b.textContent.includes('New action'))", "open Actions");
    await ev("[...document.querySelectorAll('.sp:not([hidden]) [data-surface=actions] .btn')].find((b) => b.textContent.includes('New action')).click()");
    await ev(`(() => { const s = (l, v) => { const e = document.querySelector('.sp:not([hidden]) [aria-label="' + l + '"]'); e.value = v; }; s('Name', 'Say hi'); s('Command', 'echo action-$((6*7))'); })()`);
    await ev("[...document.querySelectorAll('.sp:not([hidden]) [data-surface=actions] .btn')].find((b) => b.textContent === 'Save').click()");
    await until("!!document.querySelector('.sp:not([hidden]) [data-action=say-hi]')", "save the action");
    await ev("document.querySelector('.sp:not([hidden]) [data-action=say-hi] .sp-action-run').click()");
    await until("document.querySelector('.sp:not([hidden]) [data-action=say-hi]')?.textContent.includes('Passed')", "run the action and see it pass", 15_000);
    await shot("05a-actions");
    await ev("document.querySelector('.sp:not([hidden]) [data-action=say-hi] [aria-label^=Show]').click()");
    await until("document.querySelector('.sp:not([hidden]) [data-surface=terminal]:not([hidden]) .xterm-rows')?.textContent.includes('action-42')", "show the action's output");
    console.log("OPSCODE_SMOKE: renderer Actions: new action saved, run, passed, output shown");

    // Changes: make the project a git repo with one commit, edit a file, see the diff.
    const git = (args: string[]) => execFileSync("git", ["-c", "user.name=smoke", "-c", "user.email=smoke@example.invalid", ...args], { cwd: project, stdio: "ignore" });
    git(["init", "-q", "-b", "main"]);
    git(["add", "."]);
    git(["commit", "-q", "-m", "first"]);
    writeFileSync(join(project, "hello-smoke.txt"), "hi\nchanged\n");
    writeFileSync(join(project, "new-file.txt"), "fresh\n");
    await ev("document.querySelector('.sp:not([hidden]) .sp-tab-new').click()");
    await ev("document.querySelector('.sp:not([hidden]) [data-surface=new]:not([hidden]) .sp-tool[data-kind=diff]').click()");
    await until("document.querySelectorAll('.sp:not([hidden]) [data-surface=diff] .sp-file').length === 2 && !!document.querySelector('.sp:not([hidden]) [data-surface=diff] .ins')", "show two changed files with added lines");
    await shot("05b-changes");
    console.log("OPSCODE_SMOKE: renderer Changes: git diff of the working tree (modified + untracked)");

    // Overview: environment card shows the branch; composer foot shows it too.
    await ev("document.querySelector('.sp:not([hidden]) .sp-tab-new').click()");
    await ev("document.querySelector('.sp:not([hidden]) [data-surface=new]:not([hidden]) .sp-tool[data-kind=overview]').click()");
    await until("document.querySelector('.sp:not([hidden]) [data-surface=overview]')?.textContent.includes('main') && document.querySelector('.sp:not([hidden]) [data-surface=overview]').textContent.includes('2 files changed')", "show the environment and changes in Overview");
    await shot("05c-overview");
    console.log("OPSCODE_SMOKE: renderer Overview: environment, context, changes cards");

    // Browser: a local page loads in the webview and names the tab.
    const AGENT_PAGE = `<!doctype html><title>Agent page</title><h1>Shop</h1>
<label for=email>Email</label><input id=email type=email placeholder="you@example.com">
<select id=size aria-label=Size><option value=s>Small</option><option value=l>Large</option></select>
<label><input type=checkbox id=agree> I agree</label>
<button id=go onclick="document.getElementById('out').textContent='Thanks '+email.value+' '+size.value+' '+agree.checked; console.log('submitted', email.value)">Send</button>
<p id=out>waiting</p><button id=del onclick="if(confirm('Delete everything?'))document.getElementById('out').textContent='Deleted'">Delete</button>
<button id=mt onclick="document.getElementById('menu').hidden=!document.getElementById('menu').hidden">Menu</button><div id=menu hidden><button>Secret item</button></div><script>console.error('smoke console error')</script>`;
    const page = createHttpServer((req, res) => res.writeHead(200, { "content-type": "text/html" }).end(req.url === "/app" ? AGENT_PAGE : "<!doctype html><title>Smoke page</title><h1>Hello from the smoke page</h1>"));
    await new Promise<void>((r) => page.listen(0, "127.0.0.1", () => r()));
    const pagePort = (page.address() as { port: number }).port;
    try {
      // OPSCODE_SMOKE_FOCUS=voice: only the voice-mode steps (the part being changed), then stop.
      if (process.env.OPSCODE_SMOKE_FOCUS === "voice") {
        // The voice is normally downloaded by the read-aloud step; here it is installed first.
        await c.call("tts.install", {});
        for (const end = Date.now() + 20_000; Date.now() < end && !(await c.call<{ installed: boolean }>("tts.status", {})).installed; ) await pause(200);
        await voiceSteps();
        clearTimeout(watchdog);
        await finish(0, "PASS (focus: voice mode only)");
        return;
      }
      await ev("document.querySelector('.sp:not([hidden]) .sp-tab-new').click()");
      await ev("document.querySelector('.sp:not([hidden]) [data-surface=new]:not([hidden]) .sp-tool[data-kind=browser]').click()");
      await until("!!document.querySelector('.sp:not([hidden]) [data-surface=browser]:not([hidden]) .sp-address')", "open the Browser tab");
      await ev(`(() => { const a = document.querySelector('.sp:not([hidden]) [data-surface=browser]:not([hidden]) .sp-address'); a.value = 'localhost:${pagePort}'; a.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true })); })()`);
      try {
        await until("[...document.querySelectorAll('.sp:not([hidden]) .sp-tab')].some((t) => t.textContent.includes('Smoke page'))", "load the page and name the tab after it", 15_000);
      } catch (e) {
        console.log("OPSCODE_SMOKE: browser debug", await ev<string>("(() => { const w = document.querySelector('.sp-webview'); let u = ''; try { u = w?.getURL(); } catch (e) { u = 'ERR ' + e.message; } return JSON.stringify({ has: !!w, src: w?.getAttribute('src'), url: u, overlay: document.querySelector('.sp-browser-overlay')?.hidden, text: document.querySelector('.sp-browser-overlay')?.textContent, tabs: [...document.querySelectorAll('.sp-tab')].map((t) => t.textContent) }); })()"));
        throw e;
      }
      await shot("05d-browser");
      console.log("OPSCODE_SMOKE: renderer Browser: localhost page loads in the webview (tab titled)");

      // The agent drives that Browser tab: a Claude Code chat (fake engine) calls Opscode's browser tools over
      // MCP; main runs them with the DevTools Protocol on the real page.
      const agentChat = (await c.call<{ chat: { id: string } }>("chat.create", { workspace_id: workspace.id, engine: "claude-code", mode: "full" })).chat;
      const dl = (n: string, a: unknown) => `FAKE_DEVICE ${n} ${JSON.stringify(a)}`;
      const steps: [string, unknown][] = [
        ["browser_navigate", { url: `localhost:${pagePort}/app` }],
        ["browser_read", {}],
        ["browser_act", { action: "fill", ref: "ref_2", value: "a@b.co" }],
        ["browser_act", { action: "fill", ref: "ref_3", value: "Large" }],
        ["browser_act", { action: "fill", ref: "ref_4", value: true }],
        ["browser_act", { action: "click", ref: "ref_5" }],
        ["browser_read", { mode: "text" }],
        ["browser_find", { query: "agree" }],
        ["browser_logs", { kind: "console" }],
        ["browser_eval", { code: "document.title" }],
        ["browser_screenshot", {}],
        ["browser_act", { action: "key", keys: "Tab" }],
        ["browser_act", { action: "click", ref: "ref_6" }],
        ["browser_read", {}],
        ["browser_act", { action: "dialog", accept: true }],
        ["browser_act", { action: "click", ref: "ref_7" }],
        ["browser_act", { action: "click", ref: "ref_7" }],
        ["browser_act", { action: "click", ref: "ref_8" }],
      ];
      await c.call("turn.submit", { workspace_id: workspace.id, chat_id: agentChat.id, text: `test the shop page\n${steps.map(([n, a]) => dl(n, a)).join("\n")}` });
      await until("!!document.querySelector('.sp:not([hidden]) [data-surface=browser]:not([hidden]) .sp-agent:not([hidden])')", "show that Opscode is using the Browser tab", 20_000);
      let outs: { tool: string; output?: string; status: string }[] = [];
      for (const end = Date.now() + 30_000; Date.now() < end; await pause(250)) {
        const hist = await c.call<{ messages?: { role: string; status: string; parts?: { kind: string; tool: string; output?: string; status: string }[] }[] }>("turn.history", { chat_id: agentChat.id });
        const last = hist.messages?.filter((m) => m.role === "assistant").at(-1);
        outs = (last?.parts ?? []).filter((p) => p.kind === "tool");
        if (last && last.status !== "streaming") break;
      }
      const out = (i: number) => outs[i]?.output ?? "";
      const want: [number, RegExp, string][] = [
        [0, /Loaded "Agent page"/, "navigate loads the page"],
        [1, /textbox "Email" \[ref_2\][\s\S]*combobox "Size" \[ref_3\][\s\S]*checkbox "I agree" \[ref_4\][\s\S]*button "Send" \[ref_5\]/, "read lists the form with refs"],
        [2, /Set textbox "Email" to "a@b.co"/, "fill types into the email field"],
        [3, /Selected "Large"/, "fill picks the select option"],
        [4, /Checked "I agree"/, "fill ticks the checkbox"],
        [5, /Clicked button "Send"/, "click presses the button"],
        [6, /Thanks a@b\.co l true/, "the page reacted to real input"],
        [7, /checkbox "I agree" \[ref_4\]/, "find locates the checkbox"],
        [8, /\[error\] smoke console error[\s\S]*submitted a@b\.co/, "console logs are captured"],
        [9, /^Agent page$/, "eval runs in the page"],
        [10, /Screenshot \d+x\d+/, "a screenshot of the visible tab"],
        [11, /Pressed Tab/, "keys are pressed"],
        [12, /Clicked button "Delete"[\s\S]*confirm dialog is open: "Delete everything\?"/, "a click that opens confirm() returns at once and says so"],
        [13, /dialog is open .*paused/, "reading while a dialog is open explains instead of hanging"],
        [14, /Accepted the confirm[\s\S]*New text: "Deleted"/, "answering the dialog reports what changed"],
        [15, /Clicked button "Menu"[\s\S]*Appeared:\s*- button "Secret item" \[ref_8\]/, "a click reports what appeared"],
        [16, /Gone: button "Secret item"/, "and what went away"],
        [17, /ref_8 \(button "Secret item"\) is not visible right now/, "a hidden element is refused, never clicked blind"],
      ];
      const bad = want.filter(([i, re]) => !re.test(out(i)));
      if (outs.length < want.length || bad.length) throw new Error(`agent browser: ${bad.map(([i, , w]) => `${w}: ${JSON.stringify(out(i).slice(0, 300))}`).join(" | ") || `only ${outs.length} tool results`}`);
      await shot("05e-agent-browser");
      await c.call("chat.delete", { chat_id: agentChat.id }); // later steps use the project's newest chat

      // Hand-off (H3): a chat moves from Claude Code to Codex; Codex gets the task record as thread history
      // and the reply shows "Took over from Claude Code".
      const hoChat = (await c.call<{ chat: { id: string } }>("chat.create", { workspace_id: workspace.id, engine: "claude-code", mode: "full" })).chat;
      const waitTurn = async (turnId: string, chatId = hoChat.id): Promise<void> => {
        for (const end = Date.now() + 20_000; Date.now() < end; await pause(200)) {
          const hist = await c.call<{ messages?: { turn_id: string; role: string; status: string }[] }>("turn.history", { chat_id: chatId });
          if (hist.messages?.some((m) => m.turn_id === turnId && m.role === "assistant" && m.status !== "streaming")) return;
        }
        throw new Error("hand-off: a turn did not finish");
      };
      await waitTurn((await c.call<{ turn_id: string }>("turn.submit", { workspace_id: workspace.id, chat_id: hoChat.id, text: "Fix the cart FAKE_TOOLS" })).turn_id);
      await c.call("chat.set_engine", { chat_id: hoChat.id, engine: "codex", model: "gpt-fake" });
      await waitTurn((await c.call<{ turn_id: string }>("turn.submit", { workspace_id: workspace.id, chat_id: hoChat.id, text: "Continue." })).turn_id);
      await until(`!!document.querySelector('.sb-chat[data-chat="${hoChat.id}"]')`, "list the hand-off chat in the sidebar");
      await ev(`document.querySelector('.sb-chat[data-chat="${hoChat.id}"]').click()`);
      await until("[...document.querySelectorAll('.msg-handoff:not([hidden])')].some((e) => /^Took over from Claude Code · ~[0-9.]+k? tokens · as history$/.test(e.textContent))", "show that Codex took over from Claude Code", 15_000);
      await shot("05g-handoff");
      await c.call("chat.delete", { chat_id: hoChat.id });
      console.log("OPSCODE_SMOKE: hand-off: Claude Code -> Codex, task record injected as Codex history, reply shows 'Took over from Claude Code'");

      // File links (renderer/filelinks.js): paths in a reply are blue links; right-click shows the file menu;
      // "Attach to message" adds the file to the composer; a project text file opens in the File tab.
      // (Opening with the default app or Finder is not clicked here: it would open real apps on this Mac.)
      const wsPath = (workspace as unknown as { path?: string }).path ?? project;
      mkdirSync(join(wsPath, "out"), { recursive: true });
      writeFileSync(join(wsPath, "out", "notes.md"), "# Notes\nfrom the smoke\n");
      writeFileSync(join(wsPath, "out", "prices list.xlsx"), "x");
      const flChat = (await c.call<{ chat: { id: string } }>("chat.create", { workspace_id: workspace.id, engine: "claude-code", mode: "full" })).chat;
      await waitTurn((await c.call<{ turn_id: string }>("turn.submit", { workspace_id: workspace.id, chat_id: flChat.id, text: `make files\nHere: [Download the Excel file](<${wsPath}/out/prices list.xlsx>) and [the notes](out/notes.md)` })).turn_id, flChat.id);
      await until(`!!document.querySelector('.sb-chat[data-chat="${flChat.id}"]')`, "list the file-link chat");
      await ev(`document.querySelector('.sb-chat[data-chat="${flChat.id}"]').click()`);
      const xlsx = `${wsPath}/out/prices list.xlsx`;
      await until(`(() => { const a = [...document.querySelectorAll('.msg-assistant a.op-file')]; return a.some((x) => x.dataset.path === ${JSON.stringify(xlsx)} && x.textContent === 'Download the Excel file') && a.some((x) => x.dataset.path === ${JSON.stringify(`${wsPath}/out/notes.md`)}) && getComputedStyle(a[0]).cursor === 'pointer'; })()`, "show the reply's file paths as file links");
      await ev(`[...document.querySelectorAll('.msg-assistant a.op-file')].find((x) => x.dataset.path === ${JSON.stringify(xlsx)}).dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, cancelable: true }))`);
      await until("(() => { const l = [...document.querySelectorAll('.menu .menu-label')].map((x) => x.textContent); return ['Open', 'Show in Finder', 'Copy path', 'Copy name', 'Attach to message'].every((w) => l.includes(w)) && !l.includes('Open in Opscode'); })()", "right-click a file link: Open, Show in Finder, Copy path, Copy name, Attach");
      await shot("05h-file-link-menu");
      await ev("[...document.querySelectorAll('.menu .menu-item')].find((b) => b.textContent.includes('Attach to message')).click()");
      await until("[...document.querySelectorAll('.attach-tray:not([hidden]) .att-name')].some((x) => x.textContent === 'prices list.xlsx')", "attach the linked file to the message being written", 15_000);
      await ev(`[...document.querySelectorAll('.msg-assistant a.op-file')].find((x) => x.dataset.path.endsWith('/out/notes.md')).click()`);
      await until("[...document.querySelectorAll('.sp:not([hidden]) .sp-tab')].some((t) => t.textContent.includes('notes.md'))", "open a project text file from its link in the File tab", 15_000);
      await shot("05h-file-link-open");
      await ev("document.querySelectorAll('.attach-tray .att-x').forEach((b) => b.click())");
      await c.call("chat.delete", { chat_id: flChat.id });
      rmSync(join(wsPath, "out"), { recursive: true, force: true }); // later steps count the project's changed files
      // Voice (renderer/voice.js + runtime/voice.ts; a fake helper here): the mic fills the box as you speak,
      // click again to finish; Esc cancels and puts the box back.
      const box = "document.querySelector('.chat:not([hidden]) .composer textarea')";
      await until("(() => { const b = document.querySelector('.chat:not([hidden]) .cmp-mic'); return !!b && !b.hidden; })()", "show the mic button");
      await ev(`(() => { const t = ${box}; t.value = 'Note:'; t.dispatchEvent(new Event('input', { bubbles: true })); })()`);
      await ev("document.querySelector('.chat:not([hidden]) .cmp-mic').click()");
      await until("document.querySelector('.chat:not([hidden]) .cmp-mic').dataset.state === 'listening'", "start listening");
      await until(`${box}.value.startsWith('Note: please update the Opscode cart total')`, "show the words in the box as they are spoken");
      await shot("05i-mic-listening");
      await ev("document.querySelector('.chat:not([hidden]) .cmp-mic').click()");
      await until(`${box}.value === 'Note: please update the Opscode cart total and run the tests' && document.querySelector('.chat:not([hidden]) .cmp-mic').dataset.state === 'idle' && !document.querySelector('.chat:not([hidden]) .send').disabled`, "finish: the whole sentence in the box, ready to send");
      await ev("document.querySelector('.chat:not([hidden]) .cmp-mic').click()");
      await until(`${box}.value.length > 'Note: please update the Opscode cart total and run the tests'.length`, "start a second dictation");
      await ev("document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))");
      await until(`${box}.value === 'Note: please update the Opscode cart total and run the tests' && document.querySelector('.chat:not([hidden]) .cmp-mic').dataset.state === 'idle'`, "Esc cancels and puts the box back");
      await ev(`(() => { const t = ${box}; t.value = ''; t.dispatchEvent(new Event('input', { bubbles: true })); })()`);
      // Voice note (+ menu): the same, with a timer; the recording is saved in the project and attached.
      await ev("document.querySelector('.chat:not([hidden]) .composer-controls .cmp-icon[aria-label=\"Add files and more\"]').click()");
      await until("[...document.querySelectorAll('.menu .menu-label')].some((x) => x.textContent === 'Record a voice note')", "list 'Record a voice note' in the + menu");
      await ev("[...document.querySelectorAll('.menu .menu-item')].find((b) => b.textContent.includes('Record a voice note')).click()");
      await until("document.querySelector('.chat:not([hidden]) .cmp-mic').dataset.state === 'listening' && !document.querySelector('.chat:not([hidden]) .mic-timer').hidden", "record a voice note with a running timer");
      await ev("document.querySelector('.chat:not([hidden]) .cmp-mic').click()");
      await until("[...document.querySelectorAll('.chat:not([hidden]) .attach-tray:not([hidden]) .att-name')].some((x) => /^voice-note-\\d{8}-\\d{6}\\.m4a$/.test(x.textContent)) && document.querySelector('.chat:not([hidden]) .mic-timer').hidden", "attach the recording to the message", 15_000);
      await shot("05i-voice-note");
      await ev("document.querySelectorAll('.chat:not([hidden]) .attach-tray .att-x').forEach((b) => b.click())");
      await ev(`(() => { const t = ${box}; t.value = ''; t.dispatchEvent(new Event('input', { bubbles: true })); })()`);
      // Read aloud (renderer/speak.js + runtime/tts; a stand-in voice here): 🔊 on a reply asks before the first
      // download, downloads, then plays; pause/resume, stop and the speed button work.
      const speakBtn = ".chat:not([hidden]) .msg-assistant .msg-speak button:first-child";
      await until(`!!document.querySelector('${speakBtn}') && document.querySelector('${speakBtn}').title === 'Read aloud (Kitten TTS 2 Mini)'`, "show 🔊 on the reply");
      await ev(`document.querySelector('${speakBtn}').click()`);
      await until("!!document.querySelector('.dialog[role=alertdialog]') && /Download the Kitten TTS 2 Mini voice/.test(document.querySelector('.dialog').textContent) && /synthesized on this computer/.test(document.querySelector('.dialog').textContent)", "ask before downloading the voice");
      await shot("05j-voice-download-question");
      await ev("[...document.querySelectorAll('.dialog .btn')].find((b) => /^Download/.test(b.textContent)).click()");
      await until(`document.querySelector('${speakBtn}')?.dataset.phase === 'playing' && document.querySelector('${speakBtn}').title === 'Pause'`, "play the reply after the voice is downloaded", 20_000);
      await shot("05j-reading-aloud");
      await ev(`document.querySelector('${speakBtn}').click()`);
      await until(`document.querySelector('${speakBtn}').dataset.phase === 'paused' && document.querySelector('${speakBtn}').title === 'Resume'`, "pause reading");
      await ev("document.querySelector('.chat:not([hidden]) .msg-assistant .msg-speed').click()");
      await until("document.querySelector('.chat:not([hidden]) .msg-assistant .msg-speed').textContent === '1.25×'", "change the reading speed");
      await ev(`document.querySelector('${speakBtn}').click()`);
      await until(`document.querySelector('${speakBtn}').dataset.phase === 'playing'`, "resume reading");
      await ev("document.querySelector('.chat:not([hidden]) .msg-assistant .msg-speak button[aria-label=\"Stop reading\"]').click()");
      await until(`document.querySelector('${speakBtn}').dataset.phase === 'idle' && document.querySelector('${speakBtn}').title === 'Read aloud (Kitten TTS 2 Mini)'`, "stop reading");
      await c.call("settings.set", { patch: { tts_speed: 1 } });
      console.log("OPSCODE_SMOKE: read aloud: 🔊 asks first, downloads the voice, plays, pause/resume, speed, stop");
      console.log("OPSCODE_SMOKE: voice: mic fills the box live (project word fixed), click finishes, Esc cancels; voice note keeps the recording as an attachment");
      console.log("OPSCODE_SMOKE: file links: reply paths are links; right-click menu (Open, Show in Finder, Copy, Attach); attach to message; project file opens in the File tab");

      async function voiceSteps(): Promise<void> {
        // Voice mode (renderer/voicechat.js + runtime/voiceagent; fake microphone helper, stand-in voice, fake Claude Code as
        // the front agent): the message box dissolves, the orb takes over, what you say is heard, the agent briefs the worker
        // (its chat appears), speaks, and the worker's state shows. Ending brings the message box back.
        await c.call("settings.set", { patch: { voice_brain_engine: "claude-code", voice_brain_model: "sonnet" } });
        await ev("document.querySelector('.sb-new').click()");
        const vc = ".chat:not([hidden])";
        await until(`!!document.querySelector('${vc} .vox-launch') && !document.querySelector('${vc} .vox-launch').hidden && getComputedStyle(document.querySelector('${vc} .cmp-mic')).display !== 'none'`, "show the Voice mode button above the box, and keep the small dictation mic in the box");
        await pause(1000); // the new chat's pixel reveal
        await shot("05k-voice-before");
        await ev(`document.querySelector('${vc} .vox-launch').click()`);
        await until(`document.querySelector('${vc}').dataset.voice === 'on' && !document.querySelector('${vc} .vox').hidden`, "open voice mode", 15_000);
        try {
          await until(`document.querySelector('${vc} .vox').dataset.state === 'listening' && document.querySelector('${vc} .vox-status-text').textContent === 'Listening'`, "listen once the helper is ready", 15_000);
        } catch (e) {
          const dump = await ev<string>(`JSON.stringify({ voice: document.querySelector('${vc}')?.dataset.voice, state: document.querySelector('${vc} .vox')?.dataset.state, status: document.querySelector('${vc} .vox-status-text')?.textContent, toasts: [...document.querySelectorAll('.toast')].map((t) => t.textContent) })`);
          throw new Error(`${(e as Error).message} -- ${dump}`);
        }
        await pause(1200); // the opening animation
        const layout = await ev<Record<string, boolean | string>>(`(() => { const q = (s) => document.querySelector('${vc} ' + s); const d = (s) => q(s) ? getComputedStyle(q(s)).display : 'missing'; return { textareaGone: d('.composer textarea') === 'none', sendGone: d('.send') === 'none', micGone: d('.cmp-mic') === 'none', crewGone: d('.crew-switch') === 'none', voiceChip: d('.cmp-voice-model') !== 'none' && d('.cmp-voice-model') !== 'missing' && /Voice/.test(q('.cmp-voice-model').textContent), chipInfo: d('.cmp-voice-model') + '|' + (q('.cmp-voice-model') ? q('.cmp-voice-model').textContent : ''), plus: d('.composer-controls .cmp-icon[aria-label="Add files and more"]') !== 'none', under: !!q('.composer-under'), workerChip: d('.cmp-model') !== 'none' }; })()`);
        if (!Object.entries(layout).filter(([k]) => k !== 'chipInfo').every(([, v]) => v === true)) throw new Error(`voice mode layout: ${JSON.stringify(layout)}`);
        await shot("05k-voice-on");
        const va = (await c.call<{ running: string | null }>("voiceagent.status", {})).running;
        if (!va) throw new Error("voice mode did not start a session");
        const heard = (words: string): Promise<unknown> => c.call("voiceagent.audio", { session: va, pcm: Buffer.from(`SAY:${words}`, "latin1").toString("base64") });
        if (process.env.OPSCODE_VA_DEBUG) await ev(`window.addEventListener('opscode:voiceagent', (e) => console.log('VA ' + JSON.stringify(e.detail).slice(0, 220)))`);
        await heard('please add dark mode to the settings FAKE_TOOL work_start {"brief":"Goal: add a dark mode switch to the settings page. Where to start: the settings page. Done when: it toggles the theme.","title":"Dark mode"}');
        await until(`/please add dark mode to the settings/.test(document.querySelector('${vc} .vox-user').textContent)`, "show what was heard");
        try {
          await until(`document.querySelectorAll('${vc} .msg-user').length >= 1 && /Goal: add a dark mode switch/.test(document.querySelector('${vc} .msg-user').textContent)`, "show the worker's chat with the brief the agent wrote", 20_000);
        } catch (e) {
          await shot("05k-voice-fail");
          const dump = await ev<string>(`JSON.stringify({ state: document.querySelector('${vc} .vox')?.dataset.state, status: document.querySelector('${vc} .vox-status-text')?.textContent, user: document.querySelector('${vc} .vox-user')?.textContent, agent: document.querySelector('${vc} .vox-agent')?.textContent, worker: document.querySelector('${vc} .vox-worker')?.textContent, msgs: document.querySelectorAll('${vc} .msg').length, empty: document.querySelector('${vc}')?.dataset.empty, toasts: [...document.querySelectorAll('.toast')].map((t) => t.textContent) })`);
          const chats = (await c.call<{ chats: { id: string; title: string }[] }>("chat.list", {})).chats.map((x) => x.title);
          throw new Error(`${(e as Error).message} -- ${dump} -- chats: ${JSON.stringify(chats.slice(0, 6))}`);
        }
        await until(`!!document.querySelector('${vc} .vox-col-l .vw-card[data-worker="w1"]') && /Dark mode/.test(document.querySelector('${vc} .vw-card[data-worker="w1"]').textContent)`, "show the first worker's box on the left of the orb", 15_000);
        await until(`!!document.querySelector('${vc} .vox-bot canvas')`, "show the agent's pixel robot on the stage");
        await until(`/Chief handled it/.test(document.querySelector('${vc} .vox-agent').textContent)`, "show what the agent said", 15_000);
        await shot("05k-voice-worker");
        // While the agent talks, the orb cuts it off; then it mutes.
        await until(`document.querySelector('${vc} .vox').dataset.state === 'speaking'`, "show that the agent is speaking", 15_000);
        await shot("05k-voice-speaking");
        await ev(`document.querySelector('${vc} .vox-orb').click()`);
        await until(`document.querySelector('${vc} .vox').dataset.state === 'listening'`, "cut the agent off with the orb");
        await ev(`document.querySelector('${vc} .vox-orb').click()`);
        await until(`document.querySelector('${vc} .vox').dataset.state === 'muted'`, "mute the microphone with the orb");
        await shot("05k-voice-muted");
        await ev(`document.querySelector('${vc} .vox-orb').click()`);
        await until(`document.querySelector('${vc} .vox').dataset.state !== 'muted'`, "unmute");
        // A second piece of work: a second worker in its own new chat, its box on the right; the robot carries the brief over.
        await pause(500);
        await heard('also fix the login page FAKE_TOOL work_start {"brief":"Goal: fix the login page so a wrong password shows an error. Where to start: the login page. Done when: a wrong password shows a clear error.","title":"Login fix"}');
        await until(`!!document.querySelector('${vc} .vox-col-r .vw-card[data-worker="w2"]') && /Login fix/.test(document.querySelector('${vc} .vw-card[data-worker="w2"]').textContent)`, "show the second worker's box on the right", 20_000);
        const wl = (await c.call<{ chats: { id: string; title: string }[] }>("chat.list", {})).chats;
        if (!wl.some((x) => x.title === "Login fix") || !wl.some((x) => x.title === "Dark mode")) throw new Error(`each worker should have its own chat: ${JSON.stringify(wl.map((x) => x.title))}`);
        await until(`document.querySelector('${vc} .vox-bot').style.transform !== ''`, "move the robot");
        await pause(700);
        await shot("05k-voice-two-workers");
        // Wide (the side panel out of the way): the boxes stand left and right of the orb.
        await ev(`document.querySelectorAll('.sp').forEach((p) => { p.dataset.smokeHid = p.style.display; p.style.display = 'none'; })`);
        await pause(900);
        const side = await ev<string>(`(() => { const v = document.querySelector('${vc} .vox').getBoundingClientRect(), a = document.querySelector('${vc} .vw-card[data-worker="w1"]').getBoundingClientRect(), b = document.querySelector('${vc} .vw-card[data-worker="w2"]').getBoundingClientRect(), o = document.querySelector('${vc} .vox-orb').getBoundingClientRect(); return (a.right < o.left ? 'L' : '?') + (b.left > o.right ? 'R' : '?') + ' ' + Math.round(v.width); })()`);
        await ev(`(() => { const a = document.querySelector('${vc} .vw-card[data-worker="w1"]'); a.dataset.status = 'running'; a.querySelector('.vw-now').textContent = 'Editing settings.tsx'; a.querySelector('.vw-time').textContent = '1m 12s'; a.querySelector('.vw-state').textContent = 'Working'; const f = a.querySelector('.vw-files'); f.hidden = false; f.textContent = '2 files'; const b = document.querySelector('${vc} .vw-card[data-worker="w2"]'); b.dataset.status = 'waiting'; b.querySelector('.vw-now').textContent = 'Waiting for your answer'; b.querySelector('.vw-state').textContent = 'Needs your OK'; const k = b.querySelector('.vw-ask'); k.hidden = false; k.querySelector('.vw-ask-what').textContent = 'Run the database migration'; const d = k.querySelector('.vw-ask-detail'); d.hidden = false; d.textContent = 'npm run db:migrate'; })()`);
        await pause(120);
        await shot("05k-voice-wide");
        await ev(`document.querySelectorAll('.sp').forEach((p) => { p.style.display = p.dataset.smokeHid ?? ''; delete p.dataset.smokeHid; })`);
        if (!side.startsWith("LR")) throw new Error(`wide voice stage: the boxes should be left and right of the orb (${side})`);
        // The Voice chip lists the same engines as the worker's picker (Claude Code, Codex, Antigravity, Qoder, API keys): the model you talk to.
        await ev(`document.querySelector('${vc} .cmp-voice-model').click()`);
        await until(`!!document.querySelector('.mp') && [...document.querySelectorAll('.mp .mp-rail-btn')].map((b) => b.title).filter((t) => /Claude|Codex|Antigravity|Qoder/i.test(t)).length >= 4`, "show every engine (Claude Code, Codex, Antigravity, Qoder) in the Voice model picker");
        const rail = await ev<string>(`[...document.querySelectorAll('.mp .mp-rail-btn')].map((b) => b.title).join(' | ')`);
        await shot("05k-voice-model-picker");
        // Pick Codex's fake model as the voice model, check the chip follows and the choice is saved; then put it back.
        await ev(`[...document.querySelectorAll('.mp .mp-rail-btn')].find((b) => /Codex/i.test(b.title)).click()`);
        await until(`[...document.querySelectorAll('.mp .mp-row')].some((r) => /GPT Fake/i.test(r.textContent))`, "list Codex's models in the Voice picker");
        await ev(`[...document.querySelectorAll('.mp .mp-row')].find((r) => /GPT Fake/i.test(r.textContent)).click()`);
        await until(`/GPT Fake/i.test(document.querySelector('${vc} .cmp-voice-model').textContent)`, "show the chosen Codex model on the Voice chip");
        const vb = (await c.call<{ settings: Record<string, unknown> }>("settings.get", {})).settings;
        if (vb.voice_brain_engine !== "codex" || vb.voice_brain_model !== "gpt-fake") throw new Error(`voice model not saved: ${JSON.stringify({ e: vb.voice_brain_engine, m: vb.voice_brain_model })} (rail: ${rail})`);
        await c.call("settings.set", { patch: { voice_brain_engine: "claude-code", voice_brain_model: "sonnet", voice_brain_effort: "" } });
        await ev(`document.querySelector('${vc} .vox-lines').dispatchEvent(new MouseEvent('mousedown', { bubbles: true }))`);
        await until(`!document.querySelector('.mp')`, "close the model picker (a click outside it)");
        // The agent's voice: chip -> panel with the Kitten TTS 2 Mini voices, speed and pitch; picking a voice plays a sample.
        await until(`getComputedStyle(document.querySelector('${vc} .cmp-voice-tts')).display !== 'none' && /Automatic/.test(document.querySelector('${vc} .cmp-voice-tts').textContent)`, "show the agent's voice chip (Automatic) in voice mode");
        await ev(`document.querySelector('${vc} .cmp-voice-tts').click()`);
        await until(`document.querySelectorAll('.vtone .vtone-voice').length >= 4 && document.querySelectorAll('.vtone .vtone-range').length === 2 && document.querySelector('.vtone').classList.contains('vtone-open')`, "open the voice panel (voice options, speed and pitch)");
        await ev(`(() => { const r = document.querySelectorAll('.vtone .vtone-range'); r[0].value = '1.15'; r[0].dispatchEvent(new Event('input', { bubbles: true })); r[1].value = '-1.5'; r[1].dispatchEvent(new Event('input', { bubbles: true })); document.querySelector('.vtone .vtone-voice[data-voice="en-serena"]').click(); })()`);
        await until(`document.querySelector('.vtone').dataset.previewing === 'true' && /1\\.15×/.test(document.querySelector('.vtone').textContent) && /−1\\.5 st/.test(document.querySelector('.vtone').textContent)`, "pick Serena, change speed and pitch, and hear a sample");
        await pause(500);
        await shot("05k-voice-panel");
        await until(`document.querySelector('.vtone').dataset.previewing === 'false'`, "finish the sample", 20_000);
        const sv = (await c.call<{ settings: Record<string, unknown> }>("settings.get", {})).settings;
        if (sv.voice_tts_voice !== "en-serena" || sv.voice_tts_speed !== 1.15 || sv.voice_tts_pitch !== -1.5) throw new Error(`voice settings not saved: ${JSON.stringify({ voice: sv.voice_tts_voice, speed: sv.voice_tts_speed, pitch: sv.voice_tts_pitch })}`);
        await ev(`document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))`);
        await until(`!document.querySelector('.vtone') && document.querySelector('${vc}').dataset.voice === 'on'`, "close the voice panel with Esc");
        await pause(900);
        await until(`document.querySelector('${vc}').dataset.voice === 'on'`, "keep voice mode on after closing the panel");
        await until(`/Serena/.test(document.querySelector('${vc} .cmp-voice-tts').textContent) && !!document.querySelector('${vc} .cmp-voice-tts .vtc-tuned')`, "show Serena (tuned) on the chip");
        await c.call("settings.set", { patch: { voice_tts_voice: "", voice_tts_speed: 1, voice_tts_pitch: 0 } });
        // The voice agent uses the Browser panel itself (no worker): "open my app" -> browser_navigate on the real page.
        if (!process.env.OPSCODE_SKIP_VB) {
        await pause(400);
        await heard(`open my app in the browser FAKE_TOOL browser_navigate {"url":"localhost:${pagePort}/app?from=voice"}`);
        try {
          await until(`[...document.querySelectorAll('.sp-webview')].some((w) => { try { return /from=voice/.test(w.getURL()); } catch { return false; } })`, "let the voice agent open a page in the Browser panel", 20_000);
        } catch (e) {
          await shot("05k-voice-browser-fail");
          throw e;
        }
        await until(`!document.querySelector('${vc} .vox-screen').hidden && document.querySelector('${vc} .vox-screen').dataset.has === 'true' && document.querySelector('${vc} .vs-img').src.startsWith('data:image/jpeg') && /127\.0\.0\.1|localhost/.test(document.querySelector('${vc} .vs-host').textContent)`, "show the live browser screen with a real picture of the page while the agent browses", 15_000);
        // Not a blank picture: the smoke page is white with black text (the first frame can come before the page is painted: wait for a real one).
        const brightNow = `new Promise(async (res) => { const im = document.querySelector('${vc} .vs-img'); const c = document.createElement('canvas'); c.width = 40; c.height = 25; const g = c.getContext('2d'); try { await im.decode(); } catch {} g.drawImage(im, 0, 0, 40, 25); const d = g.getImageData(0, 0, 40, 25).data; let t = 0; for (let i = 0; i < d.length; i += 4) t += (d[i] + d[i + 1] + d[i + 2]) / 3; res(Math.round(t / (d.length / 4))); })`;
        let bright = 0;
        for (const end = Date.now() + 10_000; Date.now() < end && bright < 60; await pause(400)) bright = await ev<number>(brightNow);
        if (bright < 60) { await shot("05k-voice-browser-blank"); throw new Error(`the live browser screen is blank (brightness ${bright}); the page is white`); }
        await pause(300);
        await shot("05k-voice-browser");
        }
        await ev(`document.querySelector('${vc} .vox-launch').click()`);
        await until(`!document.querySelector('${vc}').dataset.voice && document.querySelector('${vc} .vox').hidden && getComputedStyle(document.querySelector('${vc} .composer textarea')).display !== 'none' && getComputedStyle(document.querySelector('${vc} .cmp-mic')).display !== 'none'`, "end voice mode and bring the message box and the small mic back", 15_000);
        if ((await c.call<{ running: string | null }>("voiceagent.status", {})).running) throw new Error("the voice session did not end");
        await c.call("settings.set", { patch: { voice_brain_engine: "", voice_brain_model: "" } });
        await shot("05k-voice-after");
        // The approval round runs in the voice-focused run (OPSCODE_SMOKE_FOCUS=voice): it leaves another chat open than the older steps below expect.
        if (process.env.OPSCODE_SMOKE_FOCUS === "voice") {
          // Approval by voice: a Claude Code worker asks to run a risky command; its card shows what it wants with
          // Allow / Deny, the agent asks, and a spoken "yes, do it" approves it at once.
          const engBefore = (await c.call<{ settings: { default_engine: string } }>("engines.set", {})).settings.default_engine;
          await c.call("engines.set", { default_engine: "claude-code" });
          await pause(400);
          await ev("document.querySelector('.sb-new').click()");
          await until(`!!document.querySelector('${vc} .vox-launch') && !document.querySelector('${vc} .vox-launch').hidden`, "show Voice mode in a new Claude Code chat");
          await pause(800);
          await ev(`document.querySelector('${vc} .vox-launch').click()`);
          await until(`document.querySelector('${vc}').dataset.voice === 'on' && document.querySelector('${vc} .vox').dataset.state === 'listening'`, "open voice mode again", 15_000);
          const va2 = (await c.call<{ running: string | null }>("voiceagent.status", {})).running;
          if (!va2) throw new Error("the second voice session did not start");
          const say2 = (words: string): Promise<unknown> => c.call("voiceagent.audio", { session: va2, pcm: Buffer.from(`SAY:${words}`, "latin1").toString("base64") });
          await say2('clean up the old build folder FAKE_TOOL work_start {"brief":"Goal: remove the old build folder. Run FAKE_BASH=«rm -rf build-old» and report what happened.","title":"Cleanup"}');
          await until(`!!document.querySelector('${vc} .vw-card[data-status="waiting"] .vw-ask:not([hidden]) .vw-allow') && /rm -rf build-old|Bash|command/i.test(document.querySelector('${vc} .vw-card[data-status="waiting"] .vw-ask').textContent)`, "show the worker's approval on its card (what it wants, Allow, Deny, say yes or no)", 25_000);
          await pause(2500); // the agent asks aloud
          await shot("05k-voice-approval");
          await say2("yes do it");
          await until(`!document.querySelector('${vc} .vw-card[data-status="waiting"]') && /Approved/.test(document.querySelector('${vc} .vox-notice').textContent)`, "approve it from the spoken yes (card leaves waiting, Approved shown)", 15_000);
          await until(`!!document.querySelector('${vc} .vw-card[data-status="complete"]')`, "let the worker finish after the approval", 15_000);
          await pause(600);
          await shot("05k-voice-approved");
          await ev(`document.querySelector('${vc} .vox-launch').click()`);
          await until(`!document.querySelector('${vc}').dataset.voice`, "end the second voice session", 15_000);
          await c.call("engines.set", { default_engine: engBefore });
          // Back to the first worker's chat (the later steps expect to be in it, on the built-in agent). Ending a voice session shows its worker's chat, so wait for that first.
          await pause(1800);
          await ev(`[...document.querySelectorAll('.sb-chat')].find((e) => /Dark mode/.test(e.textContent)).click()`);
          await until(`/dark mode switch/.test(document.querySelector('.chat:not([hidden]) .msg-user')?.textContent ?? '')`, "go back to the first worker's chat (the dark mode brief is shown)", 8000);
        }
        console.log("OPSCODE_SMOKE: voice mode: Talk button, the box dissolves into the orb, speech is heard, the agent briefs the worker (chat appears), speaks, worker state shows, mute, end restores the box");
      }
      await voiceSteps();

      // Simulator tab (fake simctl + helper in the smoke): pick, boot, watch, tap.
      await ev("document.querySelector('.sp:not([hidden]) .sp-tab-new').click()");
      await ev("document.querySelector('.sp:not([hidden]) [data-surface=new]:not([hidden]) .sp-tool[data-kind=simulator]').click()");
      await until("[...document.querySelectorAll('.sp:not([hidden]) [data-surface=simulator] .sp-sim-pick option')].some((o) => o.textContent.startsWith('iPhone 17 · iOS 26.5'))", "list the simulators in the Simulator tab");
      await ev("[...document.querySelectorAll('.sp:not([hidden]) [data-surface=simulator] .btn')].find((b) => b.textContent === 'Boot').click()");
      await until("document.querySelector('.sp:not([hidden]) [data-surface=simulator] .sp-sim-screen')?.naturalWidth === 393", "boot it and show its screen at device points", 20_000);
      await ev("document.querySelector('.sp:not([hidden]) [data-surface=simulator] .sp-sim-screen').click()");
      await shot("05f-simulator");
      console.log("OPSCODE_SMOKE: renderer Simulator tab: device list, Boot, live screen, click-to-tap");
      console.log("OPSCODE_SMOKE: agent browser: Claude Code drives the Browser tab over MCP + DevTools (navigate, read refs, fill/select/check, click, text, find, console, eval, screenshot, keys)");
    } finally {
      page.close();
    }
    // Review page: the project's changes; opening it shows the Changes tab beside the chat.
    await ev("document.querySelector('.sb-nav[data-page=review]').click()");
    await until(`!!document.querySelector('.rv-row[data-workspace="${workspace.id}"]') && document.querySelector('.rv-row[data-workspace="${workspace.id}"]').textContent.includes('2 files')`, "list the project with 2 changed files on Review");
    await shot("22-review");
    await ev(`document.querySelector('.rv-row[data-workspace="${workspace.id}"]').click()`);
    await until("!!document.querySelector('.sp:not([hidden]) [data-surface=diff]:not([hidden]) .sp-file') && !document.querySelector('.rv-page:not([hidden])')", "open the Changes tab from Review");
    console.log("OPSCODE_SMOKE: renderer Review page: changed project -> its Changes tab");

    // Plugins page: recommended row, the catalog by category, search, the add dialog with a key (cancelled), and the one for a server behind a sign-in (cancelled).
    await ev("document.querySelector('.sb-nav[data-page=plugins]').click()");
    await until("document.querySelectorAll('.pl-section[data-section=featured] .pl-card').length >= 10 && document.querySelectorAll('.pl-rcard').length >= 3", "show the recommended servers and the catalog");
    await shot("23-plugins");
    await ev(`(() => { const i = document.querySelector('.pl-search-input'); i.value = 'supabase'; i.dispatchEvent(new Event('input', { bubbles: true })); })()`);
    await until("document.querySelectorAll('.pl-section[data-section=featured] .pl-card').length === 2", "filter the catalog by search (the token and the sign-in Supabase)");
    await ev("document.querySelector('[data-catalog=supabase] .pl-plus').click()");
    await until("!!document.querySelector('.dialog [aria-label=\"Supabase (token) Access token\"]') && document.querySelector('.dialog').textContent.includes('npx -y @supabase/mcp-server-supabase')", "show what Supabase runs and ask for its token");
    await shot("24-plugin-add");
    await ev("[...document.querySelectorAll('.dialog .btn')].find((b) => b.textContent === 'Cancel').click()");
    await ev("document.querySelector('[data-catalog=supabase-hosted] .pl-plus').click()");
    await until("!!document.querySelector('.dialog') && !document.querySelector('.dialog input') && /sign in to Supabase/.test(document.querySelector('.dialog').textContent) && [...document.querySelectorAll('.dialog .btn')].some((b) => b.textContent === 'Add and sign in')", "a server behind a sign-in asks for no key and offers Add and sign in");
    await shot("24b-plugin-signin-add");
    await ev("[...document.querySelectorAll('.dialog .btn')].find((b) => b.textContent === 'Cancel').click()");
    await ev(`(() => { const i = document.querySelector('.pl-search-input'); i.value = ''; i.dispatchEvent(new Event('input', { bubbles: true })); })()`);
    console.log("OPSCODE_SMOKE: renderer Plugins page: catalog, search, add dialog with key");
    await ev(`[...document.querySelectorAll('.sidebar-item[data-chat]')][0]?.click()`);
    await until("!document.querySelector('.pl-page:not([hidden])')", "go back to a chat");

    // Hide the panel again for the rest of the run.
    await ev("document.querySelector('.pane-panel-btn').click()");
    await until("!document.querySelector('.sp:not([hidden])')", "hide the side panel");

    // Settings page: open, go to Appearance, switch theme through the runtime.
    const nav = (text: string) => click(text, ".settings-nav, .sidebar-item");
    await ev("document.querySelector('[aria-label=Settings]').click()");
    await until("!!document.querySelector('.settings-col[data-section=general]') && !!document.querySelector('.sidebar-back')", "open the Settings page");
    await shot("05-settings-general");
    await nav("Appearance");
    await until("!!document.querySelector('.settings-col[data-section=appearance]')", "open Appearance");
    await ev("[...document.querySelectorAll('.segmented button')].find((b) => b.textContent.trim() === 'Light').click()");
    await until("document.documentElement.getAttribute('data-theme') === 'light'", "apply the light theme");
    await shot("06-settings-appearance-light");
    await ev("[...document.querySelectorAll('.segmented button')].find((b) => b.textContent.trim() === 'Dark').click()");
    await until("document.documentElement.getAttribute('data-theme') === 'dark'", "apply the dark theme");
    await ev("[...document.querySelectorAll('.segmented button')].find((b) => b.textContent.trim() === 'Large').click()");
    await until("document.documentElement.dataset.text === 'large'", "apply the large text size");
    await ev("[...document.querySelectorAll('.segmented button')].find((b) => b.textContent.trim() === 'Default').click()");
    await until("document.documentElement.dataset.text === 'default'", "reset the text size");
    await ev("document.querySelector('.sidebar-back').click()");
    await until("!document.querySelector('.settings-col') || document.querySelector('.settings').hidden", "leave the Settings page");
    await ev("document.querySelector('.sp:not([hidden])') && document.querySelector('.pane-panel-btn')?.click()");
    console.log("OPSCODE_SMOKE: renderer Settings page: nav, theme, text size ok");
    // Agent through the real UI: configure a provider in Settings (against a local mock
    // of the Anthropic API), ask for a file write, approve it on the card, see it land.
    const sse = (evs: unknown[]): string => evs.map((e) => `event: x\ndata: ${JSON.stringify(e)}\n\n`).join("");
    const script = [
      sse([
        { type: "content_block_start", index: 0, content_block: { type: "tool_use", id: "tu_smoke", name: "write_file" } },
        { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: JSON.stringify({ path: "agent-smoke.txt", content: "from the agent\n" }) } },
        { type: "content_block_stop", index: 0 },
        { type: "message_delta", delta: { stop_reason: "tool_use" } },
      ]),
      sse([
        { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } },
        { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: "All done." } },
        { type: "content_block_stop", index: 0 },
        { type: "message_delta", delta: { stop_reason: "end_turn" } },
      ]),
    ];
    const mockApi = createHttpServer((req, res) => {
      req.resume();
      req.on("end", () => res.writeHead(200, { "content-type": "text/event-stream" }).end(script.shift() ?? ""));
    });
    await new Promise<void>((r) => mockApi.listen(0, "127.0.0.1", r));
    const mockUrl = `http://127.0.0.1:${(mockApi.address() as { port: number }).port}`;
    try {
      await ev("document.querySelector('[aria-label=Settings]').click()");
      await nav("Models & keys");
      await until("!!document.querySelector('.settings-col [data-provider=anthropic]')", "show the providers in Settings");
      const fill = (label: string, value: string) =>
        ev(`(() => { const i = document.querySelector('[aria-label=${JSON.stringify(label)}]'); i.value = ${JSON.stringify(value)}; i.dispatchEvent(new Event('input', { bubbles: true })); })()`);
      await ev("document.querySelector('[data-provider=anthropic]').open = true");
      await fill("Anthropic API key", "sk-smoke-0000");
      await fill("Anthropic model", "smoke-model");
      await ev(`(async () => { const i = document.querySelector('[aria-label="Anthropic base URL"]'); i.value = ${JSON.stringify(mockUrl)}; })()`);
      // Changing the base URL needs the key re-entered: the form sends both in one save.
      await shot("07-providers");
      await ev("[...document.querySelectorAll('[data-provider=anthropic] .btn')].find((b) => b.textContent === 'Save').click()");
      await until("document.querySelector('[data-provider=anthropic] .badge')?.textContent === 'In use'", "activate the provider after Save");
      console.log("OPSCODE_SMOKE: renderer provider form saved + activated (key stays in the runtime)");
      // Memory + MCP pages, through the real UI.
      await nav("Memory");
      await until("!!document.querySelector('.settings-col[data-section=memory]')", "open Memory");
      await click("New note", ".btn");
      await until("!!document.querySelector('.note-form textarea')", "open the note form");
      await ev(`(() => { const t = document.querySelector('.note-form textarea'); t.value = 'Use tabs, never spaces.'; t.dispatchEvent(new Event('input', { bubbles: true })); })()`);
      await click("Add note", ".btn");
      await until("[...document.querySelectorAll('.note-body')].some((e) => e.textContent === 'Use tabs, never spaces.')", "list the new note");
      await shot("10-memory");
      await ev("document.querySelector('.set-card .switch').click()");
      await until("document.querySelector('.set-card .switch')?.getAttribute('aria-checked') === 'false'", "turn memory off");
      await ev("document.querySelector('.set-card .switch').click()");
      await until("document.querySelector('.set-card .switch')?.getAttribute('aria-checked') === 'true'", "turn memory back on");
      console.log("OPSCODE_SMOKE: renderer Memory page: add note, toggle");
      const mcpApi = createHttpServer((rq, rs) => {
        let b = "";
        rq.on("data", (d) => (b += d));
        rq.on("end", () => {
          const m = JSON.parse(b);
          if (m.id === undefined) return void rs.writeHead(202).end();
          const result = m.method === "tools/list" ? { tools: [{ name: "lookup", description: "Look something up", inputSchema: { type: "object", properties: {} } }] } : { protocolVersion: "2024-11-05", capabilities: {}, serverInfo: { name: "smoke" } };
          rs.writeHead(200, { "content-type": "application/json" }).end(JSON.stringify({ jsonrpc: "2.0", id: m.id, result }));
        });
      });
      await new Promise<void>((r) => mcpApi.listen(0, "127.0.0.1", r));
      try {
        await nav("MCP servers");
        await until("!!document.querySelector('.settings-col[data-section=mcp]')", "open MCP servers");
        await ev(`(() => { const i = document.querySelector('[aria-label="MCP server URL or command"]'); i.value = 'http://127.0.0.1:${(mcpApi.address() as { port: number }).port}/mcp'; i.dispatchEvent(new Event('input', { bubbles: true })); })()`);
        await click("Add", ".btn");
        await until("[...document.querySelectorAll('.srv-count')].some((e) => e.textContent === '1 tool')", "connect the MCP server and list its tool");
        await shot("11-mcp");
        console.log("OPSCODE_SMOKE: renderer MCP page: add server, tools listed");
        await ev("document.querySelector('.srv .icon-btn').click()");
        await until("!document.querySelector('.srv')", "remove the MCP server");
      } finally {
        mcpApi.close();
      }
      // Skills page: create a project skill through the form.
      await nav("Skills");
      await until("!!document.querySelector('.settings-col[data-section=skills]')", "open Skills");
      await click("New skill", ".btn");
      await until("!!document.querySelector('.note-form')", "open the skill form");
      const fillByLabel = (label: string, value: string) =>
        ev(`(() => { const i = document.querySelector('[aria-label=${JSON.stringify(label)}]'); i.value = ${JSON.stringify(value)}; i.dispatchEvent(new Event('input', { bubbles: true })); })()`);
      await fillByLabel("Skill name", "smoke-skill");
      await fillByLabel("When to use it", "Say hello the smoke way");
      await fillByLabel("Skill steps", "1. Say hello.");
      await shot("12-skill-form");
      await click("Save skill", ".btn");
      await until("!!document.querySelector('.note[data-skill=smoke-skill]')", "list the new skill");
      if (!existsSync(join(project, ".opscode/skills/smoke-skill/SKILL.md"))) throw new Error("project skill file was not written");
      console.log("OPSCODE_SMOKE: renderer Skills page: new skill saved to <project>/.opscode/skills");

      // Plugins page: install from a marketplace, via the preview dialog.
      const market = mkdtempSync(join(tmpdir(), "opscode-smoke-market-"));
      mkdirSync(join(market, ".claude-plugin"), { recursive: true });
      mkdirSync(join(market, "plugins/smoke-plugin/.claude-plugin"), { recursive: true });
      mkdirSync(join(market, "plugins/smoke-plugin/skills/plugin-skill"), { recursive: true });
      writeFileSync(join(market, ".claude-plugin/marketplace.json"), JSON.stringify({ name: "Smoke Market", plugins: [{ name: "smoke-plugin", source: "./plugins/smoke-plugin", description: "A plugin" }] }));
      writeFileSync(join(market, "plugins/smoke-plugin/.claude-plugin/plugin.json"), JSON.stringify({ name: "smoke-plugin", description: "A plugin", version: "1.0.0" }));
      writeFileSync(join(market, "plugins/smoke-plugin/skills/plugin-skill/SKILL.md"), '---\nname: plugin-skill\ndescription: "From the plugin"\n---\nSteps.\n');
      try {
        await c.call("marketplace.add", { path: market });
        await nav("Plugins");
        await until("!!document.querySelector('.settings-col[data-section=plugins] [data-market]')", "list the marketplace");
        await click("Install…", ".btn");
        await until("!!document.querySelector('.dialog[aria-label=\"What this brings\"]')", "open the preview dialog");
        if (!(await ev<boolean>("document.querySelector('.dialog').textContent.includes('plugin-skill') && document.querySelector('.dialog').textContent.includes('Nothing is installed until you confirm')"))) throw new Error("preview did not show what the plugin brings");
        await shot("13-plugin-preview");
        await ev("[...document.querySelectorAll('.dialog .btn')].find((b) => b.textContent === 'Install plugin').click()");
        await until("!!document.querySelector('[data-plugin=smoke-plugin]')", "show the installed plugin");
        await ev("document.querySelector('[data-plugin=smoke-plugin] .switch').click()");
        await until("document.querySelector('[data-plugin=smoke-plugin] .switch')?.getAttribute('aria-checked') === 'false'", "disable the plugin");
        await ev("document.querySelector('[data-plugin=smoke-plugin] .switch').click()");
        await until("document.querySelector('[data-plugin=smoke-plugin] .switch')?.getAttribute('aria-checked') === 'true'", "enable the plugin");
        await shot("14-plugins");
        console.log("OPSCODE_SMOKE: renderer Plugins page: marketplace -> preview -> install -> toggle");
        await ev("[...document.querySelectorAll('[data-plugin=smoke-plugin] .btn')].find((b) => b.textContent === 'Uninstall').click()");
        await until("!!document.querySelector('.dialog[role=alertdialog]')", "confirm the uninstall");
        await ev("document.querySelector('.dialog[role=alertdialog] .btn-danger').click()");
        await until("!document.querySelector('[data-plugin=smoke-plugin]')", "uninstall the plugin");
        await ev("document.querySelector('[data-market] .icon-btn').click()");
        await until("!document.querySelector('[data-market]')", "remove the marketplace");
      } finally {
        rmSync(market, { recursive: true, force: true });
      }

      // Computer use page: switch on, add and remove an app rule. (Config only: no screen or input is touched.)
      await nav("Computer use");
      await until("!!document.querySelector('.settings-col[data-section=computer]') && !!document.querySelector('.settings-col[data-section=computer] .switch')", "open Computer use");
      await ev("document.querySelector('.settings-col[data-section=computer] .switch').click()");
      await until("document.querySelector('.settings-col[data-section=computer] .switch')?.getAttribute('aria-checked') === 'true'", "turn computer use on");
      await until("!!document.querySelector('.settings-col[data-section=computer] [aria-label=\"App name\"]')", "show the app name field");
      await ev(`(() => { const i = document.querySelector('.settings-col[data-section=computer] [aria-label="App name"]'); i.value = 'Notes'; i.dispatchEvent(new Event('input', { bubbles: true })); })()`);
      await click("Add", ".settings-col[data-section=computer] .btn");
      await until("!!document.querySelector('.srv[data-rule=always]')", "add an Always allow rule");
      await ev("document.querySelector('.srv .segmented button[aria-checked=false]').click()");
      await until("!!document.querySelector('.srv[data-rule=never]')", "switch the rule to Never");
      await shot("16-computer-use");
      await ev("document.querySelector('.srv .icon-btn').click()");
      await until("!document.querySelector('.srv')", "remove the rule");
      await ev("document.querySelector('.settings-col[data-section=computer] .switch').click()");
      await until("document.querySelector('.settings-col[data-section=computer] .switch')?.getAttribute('aria-checked') === 'false'", "turn computer use off");
      console.log("OPSCODE_SMOKE: renderer Computer use page: switch, app rule add/change/remove");

      // Import page: scan the fixture home, import a skill and an MCP server, see them as "Already here".
      await nav("Import");
      await until("!!document.querySelector('[data-id=\"claude:skill:smoke-import\"]') && !!document.querySelector('[data-id=\"claude:mcp:smokesrv\"]')", "list the fixture items");
      await ev("document.querySelector('[data-id=\"claude:skill:smoke-import\"] input').click()");
      await ev("document.querySelector('[data-id=\"claude:mcp:smokesrv\"] input').click()");
      await shot("17-import");
      await click("Import 2", ".btn");
      await until("document.querySelectorAll('.imp-row .pill-ok').length === 2", "mark both as Already here");
      console.log("OPSCODE_SMOKE: renderer Import page: scan, pick, import");
      await nav("MCP servers");
      await until("!!document.querySelector('.settings-col[data-section=mcp]') && document.body.textContent.includes('smokesrv')", "see the imported server (off)");

      // Sub-agents page: built-in listed, create a personal agent, delete it.
      await nav("Sub-agents");
      await until("!!document.querySelector('[data-agent=explorer]')", "list the built-in explorer");
      await click("New agent", ".btn");
      await ev(`(() => { const set = (l, v) => { const e = document.querySelector('[aria-label="' + l + '"]'); e.value = v; e.dispatchEvent(new Event('input', { bubbles: true })); }; set('Agent name', 'smoke-agent'); set('When to use it', 'Smoke helper'); set('Agent instructions', 'Say hi.'); })()`);
      await click("Save agent", ".btn");
      await until("!!document.querySelector('[data-agent=smoke-agent]')", "save the agent");
      await shot("18-subagents");
      await ev("document.querySelector('[data-agent=smoke-agent] .danger').click()");
      await click("Delete agent", ".btn");
      await until("!document.querySelector('[data-agent=smoke-agent]')", "delete the agent");
      console.log("OPSCODE_SMOKE: renderer Sub-agents page: built-in, create, delete");

      await ev("document.querySelector('.sidebar-back').click()");
      await ev("document.querySelector('.sp:not([hidden])') && document.querySelector('.pane-panel-btn')?.click()");
      // "/" in the composer lists skills.
      await ev(`(() => { const t = document.querySelector('.chat:not([hidden]) textarea'); t.value = '/smoke'; t.dispatchEvent(new Event('input', { bubbles: true })); })()`);
      await until("[...document.querySelectorAll('.menu-item')].some((e) => e.textContent.includes('/smoke-skill'))", "show the skill in the / menu");
      await shot("15-slash-menu");
      await ev("document.querySelector('.menu-item').click()");
      await until("document.querySelector('.chat:not([hidden]) textarea').value === '/smoke-skill '", "insert the skill name");
      await ev(`(() => { const t = document.querySelector('.chat:not([hidden]) textarea'); t.value = ''; t.dispatchEvent(new Event('input', { bubbles: true })); })()`);
      console.log("OPSCODE_SMOKE: renderer composer: / menu lists skills and inserts one");
      if ((await ev<string>(`${badge}.dataset.mode`)) !== "supervised") {
        await ev(`${settingsBtn}.click()`);
        await until("!!document.querySelector('.menu')", "open permissions for the write approval fixture");
        await ev("[...document.querySelectorAll('.menu-item')].find((e) => e.textContent.includes('Supervised')).click()");
        await until(`${badge}.dataset.mode === 'supervised'`, "set the write approval fixture to Supervised");
      }
      await ev(`(() => { const t = document.querySelector('.chat:not([hidden]) textarea'); t.value = 'write the agent file'; t.dispatchEvent(new Event('input', { bubbles: true })); document.querySelector('.chat:not([hidden]) .send').click(); })()`);
      try {
        await until("!!document.querySelector('[data-slot=opscode-message] [data-slot=approval-card][data-call] [data-slot=approval-card-allow-once]')", "show the approval card (assistant-ui Approval card in the reply)");
      } catch (e) {
        const dump = await ev<string>(`JSON.stringify({ chip: document.querySelector('.chat:not([hidden]) .cmp-model')?.textContent, msgs: [...document.querySelectorAll('.chat:not([hidden]) .msg')].map((m) => m.textContent.slice(0, 120)), toasts: [...document.querySelectorAll('.toast')].map((t) => t.textContent), settings: null })`);
        const es = (await c.call<{ settings: Record<string, unknown> }>("engines.set", {})).settings;
        throw new Error(`${(e as Error).message} -- ${dump} -- engine settings ${JSON.stringify(es)}`);
      }
      await shot("08-approval");
      if (existsSync(join(project, "agent-smoke.txt"))) throw new Error("file was written before approval");
      await ev("document.querySelector('[data-slot=opscode-message] [data-slot=approval-card-allow-once]').click()");
      await until("[...document.querySelectorAll('.msg-assistant .body')].some((e) => e.textContent.includes('All done.')) && !document.querySelector('.caret')", "finish the agent turn");
      if (readFileSync(join(project, "agent-smoke.txt"), "utf8") !== "from the agent\n") throw new Error("approved write did not land");
      await shot("09-agent-done");
      await until("!!document.querySelector('.chat:not([hidden]) [data-slot=opscode-message] [data-slot=run-activity]') && document.querySelector('.chat:not([hidden]) [data-slot=file-tree]')?.textContent.includes('1 file changed')", "the reply folds its work into Run activity and ends with the File tree");
      console.log("OPSCODE_SMOKE: renderer agent turn -> approval card -> Allow -> file written -> reply");
      await c.call("provider.remove", { id: "anthropic" });

      // Engines: Settings shows Claude Code found (the smoke wrapper points at a fake one);
      // a new chat picks Claude Code · Sonnet from the model menu and gets its reply.
      await ev("document.querySelector('[aria-label=Settings]').click()");
      await nav("Models & keys");
      // Each agent is found by itself (no path to type) and shows who is signed in, with its brand logo.
      await until("document.querySelector('[data-engine=claude-code] .ac-pill-ok')?.textContent === 'Signed in' && document.querySelector('[data-engine=codex] .ac-pill-ok')?.textContent === 'Signed in'", "show both coding agents signed in");
      await until("!!document.querySelector('[data-engine=claude-code] .ac-logo svg') && !!document.querySelector('[data-engine=codex] .ac-logo svg')", "show the Claude and Codex logos");
      if (await ev<boolean>("!!document.querySelector('.engine-card, [aria-label$=\"program path\"]')")) throw new Error("the manual program path is still shown");
      await until("document.querySelector('[data-engine=claude-code] .ac-email')?.textContent === 'sayan@claude.example' && document.querySelector('[data-engine=claude-code] .ac-plan')?.textContent === 'Max' && document.querySelector('[data-engine=codex] .ac-email')?.textContent === 'sayan@chatgpt.example'", "show each account's email and plan");
      await shot("19-coding-agents");
      // A2: add a second Claude account through the sign-in dialog (the fake finishes the browser step by itself after a moment).
      await ev("[...document.querySelectorAll('[data-engine=claude-code] .ac-foot button')].find((b) => b.textContent.includes('Add account')).click()");
      await until("!!document.querySelector('.ac-dialog .ac-methods')", "open the add-account dialog");
      await shot("19b-add-account");
      await ev("[...document.querySelectorAll('.ac-dialog button')].find((b) => b.textContent.includes('Continue in browser')).click()");
      await until("!!document.querySelector('.ac-dialog .ac-link code') && /claude\\.com/.test(document.querySelector('.ac-dialog .ac-link code').textContent)", "show the sign-in link while waiting for the browser");
      await shot("19c-signin-waiting");
      await until("document.querySelector('.ac-dialog .ac-result.ok strong')?.textContent === \"You're signed in\"", "finish the sign-in", 20_000);
      await shot("19d-signin-done");
      await ev("[...document.querySelectorAll('.ac-dialog button')].find((b) => b.textContent === 'Done').click()");
      await until("document.querySelectorAll('[data-engine=claude-code] .ac-row').length === 2 && document.querySelector('[data-engine=claude-code] .ac-row.active .ac-email')?.textContent === 'work@claude.example'", "list both Claude accounts with the new one in use");
      await shot("19e-two-accounts");
      // Use the first one again (asks first), then sign the added one out (asks first) and it leaves the list.
      await ev("[...document.querySelectorAll('[data-engine=claude-code] .ac-row')].find((r) => r.querySelector('.ac-email').textContent === 'sayan@claude.example').querySelector('.ac-row-actions .btn').click()");
      await until("!!document.querySelector('[role=alertdialog]') && /Use sayan@claude.example/.test(document.querySelector('[role=alertdialog]').textContent)", "ask before switching account");
      await ev("[...document.querySelectorAll('[role=alertdialog] button')].find((b) => b.textContent === 'Use this account').click()");
      await until("document.querySelector('[data-engine=claude-code] .ac-row.active .ac-email')?.textContent === 'sayan@claude.example'", "switch the account new chats use");
      await ev("[...document.querySelectorAll('[data-engine=claude-code] .ac-row')].find((r) => r.querySelector('.ac-email').textContent === 'work@claude.example').querySelector('.ac-out').click()");
      await until("!!document.querySelector('[role=alertdialog]') && /Sign out of work@claude.example/.test(document.querySelector('[role=alertdialog]').textContent)", "ask before signing out");
      await ev("[...document.querySelectorAll('[role=alertdialog] button')].find((b) => b.textContent === 'Sign out').click()");
      await until("document.querySelectorAll('[data-engine=claude-code] .ac-row').length === 1", "remove the signed-out account from the list");
      console.log("OPSCODE_SMOKE: renderer accounts: logos, emails and plans, add-account dialog (link, browser finishes), switch and sign out each ask first");
      // H4: the "continue in the other one" switch is on the Codex card, off by default; turning it on saves it.
      await until("[...document.querySelectorAll('[data-engine=codex] .set-row')].some((r) => r.textContent.includes('When one runs out, continue in the other'))", "show the auto-switch setting");
      await ev("[...document.querySelectorAll('[data-engine=codex] .set-row')].find((r) => r.textContent.includes('When one runs out')).querySelector('[role=switch], input[type=checkbox], button').click()");
      for (const end = Date.now() + 10_000; Date.now() < end; await pause(200)) if ((await c.call<{ settings: { auto_switch: boolean } }>("engines.list", {})).settings.auto_switch) break;
      if (!(await c.call<{ settings: { auto_switch: boolean } }>("engines.list", {})).settings.auto_switch) throw new Error("the auto-switch toggle did not turn the setting on");
      await c.call("engines.set", { auto_switch: false });
      console.log("OPSCODE_SMOKE: renderer Models & keys: 'When one runs out, continue in the other' toggle saves the setting");

      // Antigravity and Qoder: their cards (logo, who is signed in), a Qoder sign-in through the browser, then a chat on Antigravity from the model picker.
      await until("document.querySelector('[data-engine=antigravity] .ac-pill-ok')?.textContent === 'Signed in' && document.querySelector('[data-engine=qoder] .ac-pill')?.textContent === 'Not signed in' && document.querySelector('[data-engine=antigravity] .ac-logo img')?.complete && document.querySelector('[data-engine=antigravity] .ac-logo img').naturalWidth > 0 && document.querySelectorAll('[data-engine=qoder] .ac-logo svg path').length === 2", "show Antigravity (signed in) and Qoder (signed out), each with its real logo");
      await until("/^Signed in/.test(document.querySelector('[data-engine=antigravity] .ac-email')?.textContent ?? '') && /Google account/.test(document.querySelector('[data-engine=antigravity] .ac-row-sub')?.textContent ?? '')", "say Antigravity is signed in with a Google account (no email is known)");
      await ev("[...document.querySelectorAll('[data-engine=qoder] .ac-row button')].find((b) => b.textContent === 'Sign in').click()");
      await until("!![...document.querySelectorAll('.ac-dialog button')].find((b) => b.textContent.includes('Continue in browser')) && /Qoder/.test(document.querySelector('.ac-dialog .ac-lead').textContent)", "open the Qoder sign-in dialog");
      await ev("[...document.querySelectorAll('.ac-dialog button')].find((b) => b.textContent.includes('Continue in browser')).click()");
      await until("!!document.querySelector('.ac-dialog .ac-link code') && /qoder\\.com/.test(document.querySelector('.ac-dialog .ac-link code').textContent)", "show Qoder's sign-in link while waiting for the browser", 15_000);
      writeFileSync(join(process.env.OPSCODE_FAKE_DEFAULT_QODER_HOME as string, "fake-login-complete.json"), "{}");
      await until("document.querySelector('.ac-dialog .ac-result.ok strong')?.textContent === \"You're signed in\"", "finish the Qoder sign-in", 20_000);
      await ev("[...document.querySelectorAll('.ac-dialog button')].find((b) => b.textContent === 'Done').click()");
      await until("document.querySelector('[data-engine=qoder] .ac-pill-ok')?.textContent === 'Signed in' && /2 models/.test(document.querySelector('[data-engine=qoder] .ac-sub').textContent)", "Qoder shows signed in, with the models it offers");
      // Check: every program is asked again; the button says so while it works, and the result says what was found for each.
      await ev("[...document.querySelectorAll('.set-row')].find((r) => r.textContent.includes('Check again')).querySelector('button').click()");
      await until("[...document.querySelectorAll('.toast')].some((t) => /^Checked\\./.test(t.textContent) && /Antigravity: signed in, 2 models/.test(t.textContent) && /Qoder: signed in, 2 models/.test(t.textContent) && /Claude Code: signed in/.test(t.textContent))", "Check reads every program again and says what it found", 20_000);
      await until("(() => { const b = [...document.querySelectorAll('.set-row')].find((r) => r.textContent.includes('Check again'))?.querySelector('button'); return !!b && !b.disabled && b.textContent.trim() === 'Check'; })()", "the Check button is ready again");
      await ev("document.querySelector('[data-engine=antigravity]').scrollIntoView({ block: 'start' })");
      await new Promise((r) => setTimeout(r, 400));
      await shot("19f-antigravity-qoder");
      await ev("document.querySelector('.sidebar-back').click()");
      await ev("document.querySelector('.sb-new').click()");
      await until("!!document.querySelector('.chat:not([hidden]) .cmp-model')", "open a new chat for Antigravity");
      await ev("document.querySelector('.chat:not([hidden]) .cmp-model').click()");
      await until("document.querySelectorAll('.mp-rail-btn[aria-label=Antigravity] svg path').length === 1 && document.querySelectorAll('.mp-rail-btn[aria-label=Qoder] svg path').length === 2", "the model picker has Antigravity and Qoder beside Claude and Codex");
      await ev("document.querySelector('.mp-rail-btn[aria-label=Antigravity]').click()");
      await until("[...document.querySelectorAll('.mp-row .mp-name')].map((e) => e.textContent).join() === 'Fast One,Smart Two'", "list the models Antigravity reported");
      await new Promise((r) => setTimeout(r, 300));
      await shot("19g-picker-antigravity");
      await ev("[...document.querySelectorAll('.mp-row')].find((e) => e.textContent.includes('Smart Two')).click()");
      await ev("document.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }))");
      await until("!document.querySelector('.mp') && document.querySelector('.chat:not([hidden]) .cmp-model')?.dataset.engine === 'antigravity' && document.querySelector('.chat:not([hidden]) .cmp-model')?.textContent.includes('Smart Two')", "choose Antigravity · Smart Two");
      await ev(`(() => { const t = document.querySelector('.chat:not([hidden]) textarea'); t.value = 'hello antigravity'; t.dispatchEvent(new Event('input', { bubbles: true })); t.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true })); })()`);
      await until("[...document.querySelectorAll('.chat:not([hidden]) .msg-assistant')].some((e) => e.textContent.includes('ACP reply: hello antigravity'))", "show the Antigravity reply");
      await until("document.querySelector('.chat:not([hidden]) .cmp-account')?.hidden === false", "show the account chip for an Antigravity chat");
      await shot("19h-antigravity-chat");
      const acpChat = await ev<string>("window.__opscodeRpc.call('chat.list', {}).then((r) => r.chats.filter((c) => c.engine === 'antigravity').map((c) => c.model + '/' + (c.engine_session ?? '').slice(0, 2) + '/' + (c.accounts?.antigravity ?? '')).join())");
      if (acpChat !== "smart-2/s-/default") throw new Error(`the Antigravity chat did not record its model, session and account: ${acpChat}`);
      console.log("OPSCODE_SMOKE: renderer Antigravity + Qoder: cards with logos and sign-in state, Qoder browser sign-in, model picker rail and models, a chat on Antigravity with its account");
      await ev("document.querySelector('[aria-label=Settings]').click()");
      await nav("Models & keys");
      await ev("document.querySelector('.sidebar-back').click()");
      await ev("document.querySelector('.sb-new').click()");
      await until("!!document.querySelector('.chat:not([hidden]) .cmp-model')", "open a new chat");
      await ev("document.querySelector('.chat:not([hidden]) .cmp-model').click()");
      await until("['Opus 5.5','Sonnet 5.5','Fable 5.2','Haiku 5.5'].every((n) => [...document.querySelectorAll('.mp-row .mp-name')].some((e) => e.textContent === n)) && !!document.querySelector('.mp-more') && !!document.querySelector('.mp-rail-btn[aria-label=Home]')", "list Claude models in the picker");
      await shot("20-engine-menu");
      await ev("[...document.querySelectorAll('.mp-row')].find((e) => e.textContent.includes('Sonnet 5.5')).click()");
      await until("!!document.querySelector('.mp-effort') && document.querySelector('.mp-effort-name')?.textContent === 'Medium' && document.querySelectorAll('.mp-tick').length === 5", "show the effort slider");
      const effortAt = (k: number) => `(() => { const t = document.querySelector('.mp-effort'); const r = t.getBoundingClientRect(); const x = r.left + 12 + (r.width - 24) * ${k}; t.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, clientX: x, pointerId: 1 })); t.dispatchEvent(new PointerEvent('pointerup', { bubbles: true, clientX: x, pointerId: 1 })); })()`;
      // Max: the label and knob turn red and Opus's bars and price climb.
      const opusAt = "(() => { const r = [...document.querySelectorAll('.mp-row')].find((e) => e.textContent.includes('Opus 5.5')); return r.querySelectorAll('.mp-bars i.on').length + '/' + r.querySelector('.mp-price').textContent; })()";
      const before = await ev<string>(opusAt);
      await ev(effortAt(1));
      await until("document.querySelector('.mp-effort-name')?.textContent === 'Max' && document.querySelector('.mp-effort-name').classList.contains('max') && document.querySelector('.mp-effort').classList.contains('max')", "turn effort to Max (red)");
      const after = await ev<string>(opusAt);
      if (before !== "4/$$$" || after !== "5/$$$$") throw new Error(`Opus bars/price did not follow effort: ${before} -> ${after}`);
      await ev(effortAt(0.5));
      await until("document.querySelector('.mp-effort-name')?.textContent === 'High'", "move effort to High");
      // Hover card: where the model sits, smarter against pricier.
      await ev("[...document.querySelectorAll('.mp-row')].find((e) => e.textContent.includes('Opus 5.5')).dispatchEvent(new PointerEvent('pointerenter'))");
      await until("document.querySelector('.mp-card.show .mp-plot circle.mp-plot-me') && document.querySelector('.mp-card').textContent.includes('Opus 5.5') && document.querySelector('.mp-card').textContent.includes('Current')", "show the hover card with the plot");
      // More models folds open.
      await ev("document.querySelector('.mp-more').click()");
      await until("document.querySelector('.mp-fold')?.hasAttribute('data-open') && [...document.querySelectorAll('.mp-fold .mp-name')].some((e) => e.textContent === 'Opus 4.8')", "open More models");
      await new Promise((r) => setTimeout(r, 300));
      await shot("20b-model-picker");
      await ev("document.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }))");
      await until("!document.querySelector('.mp') && document.querySelector('.chat:not([hidden]) .cmp-model')?.dataset.engine === 'claude-code' && document.querySelector('.chat:not([hidden]) .cmp-model')?.textContent.includes('Claude Sonnet 5.5') && document.querySelector('.chat:not([hidden]) .cmp-model')?.textContent.includes('High')", "switch the chat to Claude Sonnet 5.5 · High");
      await ev(`(() => { const t = document.querySelector('.chat:not([hidden]) textarea'); t.value = 'hello engines'; t.dispatchEvent(new Event('input', { bubbles: true })); t.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true })); })()`);
      await until("[...document.querySelectorAll('.chat:not([hidden]) .msg-assistant')].some((e) => e.textContent.includes('Claude says: hello engines'))", "show the Claude Code reply");
      // The chat shows which account it runs on (pinned by its first message), beside the model.
      await until("document.querySelector('.chat:not([hidden]) .cmp-account')?.hidden === false && document.querySelector('.chat:not([hidden]) .cmp-account').textContent.endsWith('sayan')", "show the account this chat runs on");
      await shot("20-account-chip");
      const engs = await ev<string[]>("window.__opscodeRpc.call('chat.list', {}).then((r) => r.chats.map((c) => c.engine + '/' + c.model + '/' + (c.engine_session ?? '')))");
      if (!engs.includes("claude-code/claude-sonnet-5-5/sess-claude-1")) throw new Error(`chat did not record the engine: ${JSON.stringify(engs)}`);
      await shot("21-claude-code-chat");
      // A command that creates a git branch gets the branch card (git icon, the new name, the branch it is on); "Stay on ..." refuses it.
      await ev(`(() => { const t = document.querySelector('.chat:not([hidden]) textarea'); t.value = 'go FAKE_BASH=«git checkout -b smoke/new-branch»'; t.dispatchEvent(new Event('input', { bubbles: true })); t.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true })); })()`);
      await until("(() => { const c = document.querySelector('.chat:not([hidden]) [data-branch=true]'); return !!c && c.textContent.includes('Create a new branch?') && c.textContent.includes('smoke/new-branch') && !!c.querySelector('svg.lucide-git-branch') && [...c.querySelectorAll('button')].some((b) => b.textContent.startsWith('Stay on')) && [...c.querySelectorAll('button')].some((b) => b.textContent.startsWith('Always stay on')); })()", "show the new-branch card with its choices");
      await shot("21c-branch-card");
      await ev("[...document.querySelectorAll('.chat:not([hidden]) [data-branch=true] button')].find((b) => b.textContent.startsWith('Stay on')).click()");
      await until("[...document.querySelectorAll('.chat:not([hidden]) .msg-assistant')].some((e) => e.textContent.includes('Bash deny')) && !document.querySelector('.chat:not([hidden]) [data-branch=true]')", "refuse the branch and carry on");
      console.log("OPSCODE_SMOKE: renderer branch card: git icon, name, current branch, Create / Always allow / Stay on / Always stay -> refused");
      // Question card (Slice B): Claude Code asks with AskUserQuestion; the card sits on top of the message box, the first
      // option is marked Recommended, picking it moves to question 2 (several picks), typing in the message box answers it.
      await ev(`(() => { const t = document.querySelector('.chat:not([hidden]) textarea'); t.value = 'please FAKE_ASK'; t.dispatchEvent(new Event('input', { bubbles: true })); t.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true })); })()`);
      await until("(() => { const c = document.querySelector('.chat:not([hidden]) .composer-wrap > .ask-card:not([hidden])'); return !!c && c.textContent.includes('Deploy the backend now?') && !!c.querySelector('.ask-rec') && c.querySelectorAll('.ask-opt').length === 2 && !!c.querySelector('.ask-other-input'); })()", "show the question card above the message box");
      await until("!!document.querySelector('.chat:not([hidden]) .ask-line[data-state=waiting]') && [...document.querySelectorAll('.sb-chat[data-state=needs]')].length > 0", "show Waiting for your answer in the chat and Needs you in the sidebar");
      await shot("21d-question-card");
      await ev("document.querySelector('.chat:not([hidden]) .ask-card .ask-opt').click()");
      await until("(() => { const c = document.querySelector('.chat:not([hidden]) .ask-card:not([hidden])'); return !!c && c.textContent.includes('Which apps get a new APK?') && c.textContent.includes('Question 2 of 2') && c.textContent.includes('Pick one or more.'); })()", "move to the second question");
      await ev("document.querySelectorAll('.chat:not([hidden]) .ask-card .ask-opt')[0].click()");
      await ev(`(() => { const t = document.querySelector('.chat:not([hidden]) textarea'); t.value = 'and the web build'; t.dispatchEvent(new Event('input', { bubbles: true })); t.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true })); })()`);
      await until("[...document.querySelectorAll('.chat:not([hidden]) .msg-assistant')].some((e) => e.textContent.includes('Going on with:') && e.textContent.includes('Deploy the backend now? = Yes, deploy now (Recommended)') && e.textContent.includes('Vendor app + and the web build')) && document.querySelector('.chat:not([hidden]) .ask-card').hidden", "send the answers and go on in the same turn");
      await until("!!document.querySelector('.chat:not([hidden]) .ask-line[data-state=answered]') && document.querySelector('.chat:not([hidden]) .ask-line[data-state=answered]').textContent.includes('You chose: Yes, deploy now')", "show what you chose in the chat");
      await shot("21e-question-answered");
      console.log("OPSCODE_SMOKE: renderer question card: above the message box, Recommended, 1 of 2 -> several picks, typed answer, You chose, Needs you in the sidebar");
      // The context ring opens Overview with Context unfolded: tokens in the window and the cache estimate.
      await ev("document.querySelector('.chat:not([hidden]) .cmp-ring').click()");
      await until("(() => { const o = document.querySelector('.sp:not([hidden]) [data-surface=overview]'); const c = o?.querySelector('[data-section=context] .ov-head'); return o && c?.getAttribute('aria-expanded') === 'true' && o.textContent.includes('Environment') && o.textContent.includes('Remote') && o.textContent.includes('Cache expiry') && o.textContent.includes('Claude Sonnet 5.5') && o.querySelector('[data-section=connectors]'); })()", "open Overview from the context ring");
      await ev("document.querySelector('.sp:not([hidden]) [data-surface=overview] [data-section=connectors] .ov-head').click()");
      await until("document.querySelector('.sp:not([hidden]) [data-surface=overview] [data-section=connectors] .ov-fold')?.hasAttribute('data-open')", "unfold Connectors");
      await new Promise((r) => setTimeout(r, 400));
      await shot("21b-overview-context");
      console.log("OPSCODE_SMOKE: renderer engines: Coding agents found; model picker (rail, rows, bars, price, More, effort slider) -> Claude Sonnet 5.5 · High replies (fake CLI)");

      // Automations: the form writes one, Run runs it on (fake) Claude Code, the step's chat opens.
      await ev("document.querySelector('.sb-nav[data-page=automations]').click()");
      await until("!!document.querySelector('.au-page:not([hidden]) .au-new')", "open Automations");
      await ev("document.querySelector('.au-new').click()");
      await until("!!document.querySelector('.au-create .au-title-input')", "show the New automation box");
      await ev(`(() => { const t = document.querySelector('.au-title-input'); t.value = 'Smoke hello'; const w = document.querySelector('.au-what'); w.value = 'Say hello to the project'; const e = document.querySelector('[aria-label=Engine]'); e.value = 'claude-code'; })()`);
      await shot("25-automation-new");
      await ev("[...document.querySelectorAll('.au-create .btn')].find((b) => b.textContent === 'Create').click()");
      await until("!!document.querySelector('.au-item[data-automation=smoke-hello]') && !!document.querySelector('.au-step[data-step=main]')", "create the automation and show its step");
      await ev("[...document.querySelectorAll('.au-head .btn')].find((b) => b.textContent.includes('Run')).click()");
      await until("document.querySelector('.au-run .pill')?.textContent === 'Succeeded' && document.querySelector('.au-srun[data-step=main]')?.dataset.status === 'succeeded'", "run it and see it succeed", 20_000);
      await shot("26-automation-run");
      await until("[...document.querySelectorAll('.au-srun .btn')].some((b) => b.textContent === 'Open chat')", "offer the step's chat");
      await ev("[...document.querySelectorAll('.au-srun .btn')].find((b) => b.textContent === 'Open chat').click()");
      await until("[...document.querySelectorAll('.chat:not([hidden]) .msg-assistant')].some((e) => e.textContent.includes('Claude says')) && !document.querySelector('.au-page:not([hidden])')", "open the step's chat");
      const hidden = await ev<boolean>("![...document.querySelectorAll('.sidebar-item[data-chat]')].some((e) => e.textContent.includes('smoke-hello'))");
      if (!hidden) throw new Error("automation chats must not crowd the project's chat list");
      await ev("document.querySelector('.sb-nav[data-page=automations]').click()");
      await until("!!document.querySelector('.au-page:not([hidden]) .au-new')", "reopen Automations");
      await ev("document.querySelector('.au-new').click()");
      await until("[...document.querySelectorAll('.au-create .btn')].some((b) => b.textContent === 'Use template')", "show the New automation box again");
      await ev("[...document.querySelectorAll('.au-create .btn')].find((b) => b.textContent === 'Use template').click()");
      await until("[...document.querySelectorAll('.menu-item')].some((e) => e.textContent.includes('Software agency'))", "list the templates");
      await ev("[...document.querySelectorAll('.menu-item')].find((e) => e.textContent.includes('Software agency')).click()");
      await until("!!document.querySelector('.au-item[data-automation=build-from-brief]') && document.querySelectorAll('.au-step').length === 4", "add the software agency template with its 4 steps");
      await shot("27-automation-agency");
      console.log("OPSCODE_SMOKE: renderer Automations: form -> run on Claude Code -> succeeded; step chat opens; agency template added");

      // Chief: make one from the sidebar; the welcome shows; a note starts a worker; the Work panel lists it.
      await ev("[...document.querySelectorAll('.sb-head-btn')].find((b) => b.getAttribute('aria-label') === 'New Manager').click()");
      await until("!!document.querySelector('.cf-page:not([hidden]) .cf-welcome .cf-namepill') && document.querySelectorAll('.cf-welcome .cf-row').length >= 5 && !!document.querySelector('.sb-chief[data-chief] img.mascot')", "make a Chief and show its welcome");
      await until("!!document.querySelector('.pane-header .cf-scope') && !!document.querySelector('.cf-work .cf-empty')", "show the Chief header and an empty Work panel");
      await shot("28-chief-empty");
      await ev("[...document.querySelectorAll('.cf-welcome .cf-row')].find((e) => e.textContent.includes('Hold it for later')).click()");
      await until("document.querySelector('.cf-chat textarea').value.startsWith('tomorrow 9am')", "fill the box from a welcome example");
      const chiefNote = `build the login screen\nFAKE_TOOL chat_start ${JSON.stringify({ title: "Login screen", brief: "Goal: login screen. FAKE_REPORT=review", quotes: ["build the login screen"], project_ids: [workspace.id], engine: "claude-code", tier: "base" })}`;
      await ev(`(() => { const t = document.querySelector('.cf-chat textarea'); t.value = ${JSON.stringify(chiefNote)}; t.dispatchEvent(new Event('input', { bubbles: true })); t.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true })); })()`);
      await until("[...document.querySelectorAll('.cf-chat .msg-assistant')].some((e) => e.textContent.includes('Chief handled it')) && !!document.querySelector('.cf-chat .msg-date')", "show the Chief's reply under a date line", 20_000);
      await until("[...document.querySelectorAll('.cf-work .cf-item')].some((e) => e.textContent.includes('Login screen') && /Ready for review|Running/.test(e.textContent))", "list the work in the Work panel", 20_000);
      await until("[...document.querySelectorAll('.cf-chat [data-slot=run-activity]')].some((e) => /Worked \\d/.test(e.textContent))", "say how long the Chief worked (Run activity)");
      await ev("[...document.querySelectorAll('.cf-work .cf-item-head')].find((e) => e.textContent.includes('Login screen')).click()");
      await until("[...document.querySelectorAll('.cf-chatrow .btn')].some((b) => b.textContent === 'Open chat')", "list the worker chat on the item");
      await shot("29-chief-board");
      await ev("[...document.querySelectorAll('.cf-views button')].find((b) => b.textContent === 'Board').click()");
      await until("document.querySelectorAll('.cf-columns .cf-col').length === 5", "show the Board columns");
      await ev("[...document.querySelectorAll('.cf-views button')].find((b) => b.textContent === 'List').click()");
      await ev("document.querySelector('.pane-header .cf-hbtn[aria-label=\"Manager settings\"]').click()");
      await until("!!document.querySelector('.dialog.cfs .cf-slider') && document.querySelectorAll('.dialog.cfs .cf-avatar').length === 16 && !!document.querySelector('.dialog.cfs .cfs-soul textarea')", "open Chief settings with sliders, pictures and the soul");
      await ev("document.querySelector('.cf-avatar[aria-label=\"Picture fox\"]').click()");
      await until("document.querySelector('.sb-chief img.mascot')?.getAttribute('src') === 'mascots/fox.svg'", "change the Chief's picture");
      await shot("30-chief-settings");
      await ev("document.querySelector('.dialog.cfs .cfs-head .icon-btn').click()");
      console.log("OPSCODE_SMOKE: renderer Chief: welcome -> note -> Work panel (List/Board) -> settings dialog");

      // Usage: both plans' 5-hour and weekly windows, pixel countdowns that tick, and the pace line.
      await ev("document.querySelector('.sb-nav[data-page=usage]').click()");
      await until("(() => { const c = (e) => document.querySelector(`.us-card[data-engine=${e}]`); return c('claude-code')?.querySelectorAll('.us-win').length === 3 && c('codex')?.querySelectorAll('.us-win').length === 2 && c('claude-code').textContent.includes('85% left') && c('codex').textContent.includes('45% left') && c('codex').querySelectorAll('.us-credit').length === 2 && /\\dd .*left/.test(c('codex').querySelector('.us-credit-left').textContent) && c('claude-code').textContent.includes('Weekly · Fable') && c('claude-code').textContent.includes('Pro') && document.querySelectorAll('.px-clock .px-glyph').length >= 16; })()", "show Claude and Codex limits with countdowns", 20_000);
      // A fresh usage report (any Claude Code turn ending) resets the fake window to 2.5 h: try a few times.
      let clock1 = "", clock2 = "";
      for (let k = 0; k < 4; k++) {
        clock1 = await ev<string>("document.querySelector('.us-card[data-engine=claude-code] .px-clock').dataset.text");
        await new Promise((r) => setTimeout(r, 1300));
        clock2 = await ev<string>("document.querySelector('.us-card[data-engine=claude-code] .px-clock').dataset.text");
        if (clock1 !== clock2) break;
      }
      if (clock1 === clock2 || !/^02:2\d:\d\d$/.test(clock2)) throw new Error(`countdown did not tick: ${clock1} -> ${clock2}`);
      await new Promise((r) => setTimeout(r, 900));
      await shot("31-usage");
      console.log("OPSCODE_SMOKE: renderer Usage: Claude (Pro) and Codex (Team) 5-hour + weekly windows, ticking pixel countdowns");

      // Usage → Where tokens go: reads the fixture session logs, shows cost, what burns tokens, heaviest chats.
      await ev("document.querySelector('.us-tab[data-tab=tokens]').click()");
      await until("(() => { const t = document.querySelector('.ut'); const x = t?.textContent ?? ''; return t && !t.hidden && x.includes('Usage value') && x.includes('$0.71') && x.includes('Where the usage goes') && x.includes('Long chats') && x.includes('A heavy starting prompt') && x.includes('Build the login screen') && x.includes('proj1') && x.includes('Codex') && x.includes('API list prices'); })()", "show where tokens go from the logs", 20_000);
      // Worker start-up size: the card, choosing a level, measuring (fake Claude: 52k / 43k / 29k).
      await until("!!document.querySelector('[data-card=start] .ut-level[data-level=lean][aria-checked=true]')", "show the worker start-up card with Lean chosen");
      await ev("document.querySelector('.ut-level[data-level=leanest]').click()");
      await until("document.querySelector('.ut-level[data-level=leanest]')?.getAttribute('aria-checked') === 'true'", "choose Leanest");
      await ev("[...document.querySelectorAll('[data-card=start] .btn')].find((b) => b.textContent.includes('Measure')).click()");
      await until("(() => { const t = document.querySelector('.ut-measure'); const x = t?.textContent ?? ''; return x.includes('52k tokens') && x.includes('43k tokens') && x.includes('29k tokens'); })()", "measure the worker start-up size", 30_000);
      await ev("document.querySelector('.ut-level[data-level=lean]').click()");
      await ev("document.querySelector('.ut-seg:nth-child(3)').click()");
      await until("document.querySelector('.ut')?.textContent.includes('$0.71') && document.querySelectorAll('.ut-table:not(.ut-measure) tbody tr').length === 2", "widen to 90 days and see the older session", 20_000);
      await new Promise((r) => setTimeout(r, 600));
      await shot("32-usage-tokens");
      await ev("document.querySelector('.us-tab[data-tab=limits]').click()");
      console.log("OPSCODE_SMOKE: renderer Usage: Where tokens go (cost split, burners, heaviest chats, 7/30/90 days)");

      // Modes: the picker (Normal + 3 characters), a SHINOBI Conductor in the project, Normal chat untouched.
      await ev("document.querySelector('.sb-new').click()");
      await until("!!document.querySelector('.chat:not([hidden]) .cmp-model') && !document.querySelector('.cf-conductor')", "Normal chat opens as before (no mode, no Conductor)");
      await ev("document.querySelector('.sb-modes').click()");
      await until("[...document.querySelectorAll('.mode-card')].map((c) => c.dataset.mode).join() === 'normal,godmode,warlord,shinobi'", "show the mode picker with Normal and three modes");
      await until("document.querySelectorAll('.mode-char').length === 3 && [...document.querySelectorAll('.mode-char')].every((c) => { const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data; let n = 0; for (let i = 3; i < d.length; i += 4) if (d[i] > 0) n++; return n > 2000; })", "draw the three pixel characters");
      await new Promise((r) => setTimeout(r, 700));
      await shot("33-mode-picker");
      await ev("document.querySelector('.mode-card[data-mode=shinobi]').click()");
      await until("!!document.querySelector('.sb-conductor[data-mode=shinobi]') && document.querySelector('.cf-conductor')?.textContent === 'Conductor' && !!document.querySelector('.mode-emblem-hd') && !!document.querySelector('.mode-char-hello') && document.querySelector('.cf-namepill')?.textContent === 'SHINOBI'", "start a SHINOBI Conductor in this project", 20_000);
      const cid = await ev<string>("document.querySelector('.sb-conductor').dataset.chief");
      if (await ev<boolean>(`!!document.querySelector('.sb-chief[data-chief="${cid}"]')`)) throw new Error("a Conductor must not be listed under Chiefs");
      const conductor = await ev<{ mode: string; max_parallel: number; project_ids: string[] }>(`window.__opscodeRpc.call('chief.list', {}).then((r) => r.chiefs.find((c) => c.id === '${cid}'))`);
      if (conductor.mode !== "shinobi" || conductor.max_parallel !== 1 || conductor.project_ids[0] !== workspace.id) throw new Error(`Conductor is wrong: ${JSON.stringify(conductor)}`);
      await new Promise((r) => setTimeout(r, 600));
      await shot("34-conductor");
      // Pipeline: the Conductor starts one (plan + deliver), the plan stage reaches its gate, the person approves it on the card.
      const plNote = (t: string) => `window.__opscodeRpc.call('chief.note', { chief_id: '${cid}', text: ${JSON.stringify(t)} })`;
      await ev(plNote(`build a shop app\nFAKE_TOOL pipeline_start ${JSON.stringify({ title: "Shop app", quotes: ["build a shop app"], project_ids: [workspace.id], skip: ["spec", "gap", "ui", "build", "test", "review"] })}`));
      await until(`window.__opscodeRpc.call('chief.get', { chief_id: '${cid}' }).then((v) => v.pipelines.length === 1 && v.pipelines[0].stages.find((s) => s.id === 'plan').state === 'running')`, "the Conductor starts a pipeline at its plan stage", 20_000);
      await until("!!document.querySelector('.cf-pipeline .cf-stage[data-stage=plan][data-state=running]') && !!document.querySelector('.cf-stage[data-stage=spec].skipped')", "draw the pipeline card with its stage strip");
      await until("!!document.querySelector('.cf-pipeline [data-slot=job-progress][data-pipeline]') && document.querySelector('.cf-pipeline [data-slot=job-progress]').textContent.includes('Shop app') && document.querySelector('.cf-pipeline [data-slot=job-progress]').textContent.includes('Plan')", "the pipeline shows as assistant-ui Job progress (weighted stages, estimate, stop)");
      const planRef = await ev<number>(`window.__opscodeRpc.call('chief.get', { chief_id: '${cid}' }).then((v) => v.items.find((i) => i.id === v.pipelines[0].stages.find((s) => s.id === 'plan').item_id).ref)`);
      const plId = await ev<string>(`window.__opscodeRpc.call('chief.get', { chief_id: '${cid}' }).then((v) => v.pipelines[0].id)`);
      await ev(plNote(`plan it\nFAKE_TOOL chat_start ${JSON.stringify({ item_id: `[[${planRef}]]`, title: "Shop plan", brief: "Goal: shop plan FAKE_REPORT=done FAKE_CHECK", quotes: ["build a shop app"], project_ids: [workspace.id], engine: "claude-code", kind: "plan", tier: "opus" })}`));
      await until(`window.__opscodeRpc.call('chief.get', { chief_id: '${cid}' }).then((v) => { const i = v.items.find((x) => x.ref === ${planRef}); return i.chats.length === 1 && i.chats[0].state === 'idle'; })`, "the plan stage's worker reports", 20_000);
      // An image the stage "made", so the gate's gallery has something to show.
      mkdirSync(join(project, "docs/opscode/shop-app/assets"), { recursive: true });
      writeFileSync(join(project, "docs/opscode/shop-app/assets/hero.png"), Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==", "base64"));
      await ev(plNote(`done\nFAKE_TOOL stage_done ${JSON.stringify({ pipeline_id: plId, summary: "plan.md written" })}`));
      await until("!!document.querySelector('.cf-pipeline[data-state=gate] .cf-gate') && document.querySelector('.cf-stage[data-stage=plan]')?.dataset.state === 'gate'", "the plan waits at its gate with Approve and Send back", 20_000);
      await until("document.querySelectorAll('.cf-gate .cf-thumb img').length >= 1 && document.querySelector('.cf-gate .cf-thumb img').naturalWidth === 1", "the gate's gallery shows the image the stage made", 20_000);
      await until("!!document.querySelector('.composer-wrap .cw-dock [data-slot=approval-card][data-gate] [data-slot=image-gallery] img') && document.querySelector('.cw-dock [data-slot=approval-card]')?.textContent.includes('Plan needs your OK') && !!document.querySelector('.cw-dock [data-slot=approval-card-allow-once]') && !!document.querySelector('.cw-dock [data-slot=approval-card-deny]')", "the gate also shows inside the chat box (assistant-ui Approval card) with its image, Request changes and Approve", 20_000);
      await new Promise((r) => setTimeout(r, 500));
      await shot("35-pipeline-gate");
      await ev("document.querySelector('.cw-dock [data-slot=approval-card-allow-once]').click()");
      await until("document.querySelector('.cf-stage[data-stage=plan]')?.dataset.state === 'done' && document.querySelector('.cf-stage[data-stage=deliver]')?.dataset.state === 'running'", "approving moves on to the next stage", 20_000);
      console.log("OPSCODE_SMOKE: renderer Pipeline: Conductor starts it, plan stage reaches its gate, the person approves from the chat box, deliver starts");
      // Live dock: a Codex asset worker shows as a card inside the chat box: engine and model, a live verb, the image
      // being made (rotating headline + progress), then the real image and the file it touched.
      await ev(plNote(`make the bag icon\nFAKE_TOOL chat_start ${JSON.stringify({ title: "Bag icon", brief: "Goal: bag icon FAKE_IMAGE=docs/opscode/shop-app/assets/bag.png", quotes: ["make the bag icon"], project_ids: [workspace.id], kind: "asset" })}`));
      await until("!!document.querySelector('.cw-dock [data-slot=task-card][data-engine=codex][data-state=working] [data-slot=image-generation]') && !document.querySelector('.cw-dock [data-slot=image-generation] img') && document.querySelector('.cw-dock [data-slot=task-card][data-engine=codex]')?.textContent.includes('Assets') && !!document.querySelector('.cw-dock [data-slot=agent-status]')", "a live Codex Task card appears in the chat box while its image is made (dot grid, Agent status pill)", 20_000);
      await new Promise((r) => setTimeout(r, 900));
      await until("!!document.querySelector('.cw-dock [data-slot=subagent-list]') && document.querySelector('.cw-dock [data-slot=subagent-list]').textContent.includes('Bag icon') && document.querySelector('.cw-dock [data-slot=subagent-list]').textContent.includes('Shop plan')", "two workers show as assistant-ui's Subagent list", 20_000);
      await shot("36-live-image-making");
      await until("!!document.querySelector('.cw-dock [data-slot=task-card][data-engine=codex] [data-slot=image-generation] img') && document.querySelector('.cw-dock [data-slot=image-generation] img').naturalWidth === 1 && document.querySelector('.cw-dock [data-slot=task-card][data-engine=codex] [data-slot=tool-timeline]')?.textContent.includes('Edited 1 file')", "the real image resolves out of the blur, and the timeline says Edited 1 file", 20_000);
      await shot("37-live-image-done");
      await until("!!document.querySelector('.cw-dock [data-slot=task-card][data-engine=codex][data-state=done]') && /Worked for/.test(document.querySelector('.cw-dock [data-slot=task-card][data-engine=codex]')?.textContent ?? '') && document.querySelector('.cw-dock [data-slot=task-card][data-engine=codex]')?.textContent.includes('made the shopping bag icon')", "when the worker finishes, its card says what it found and how long it worked", 20_000);
      console.log("OPSCODE_SMOKE: renderer Live dock: Codex card in the chat box, image progress then preview, edited file, Worked for");
      // Handoff: a worker whose chat grew past SHINOBI's 120k gets the next message in a fresh worker; the dock says so.
      await ev(plNote(`a big one\nFAKE_TOOL chat_start ${JSON.stringify({ title: "Big refactor", brief: "Goal: big refactor FAKE_BIG_CTX FAKE_REPORT=done FAKE_CHECK", quotes: ["a big one"], project_ids: [workspace.id], engine: "claude-code", kind: "feature" })}`));
      await until(`window.__opscodeRpc.call('chat.list', {}).then((r) => { const c = r.chats.find((x) => x.title === 'Big refactor'); return !!c && c.usage?.context_tokens > 150000; })`, "the big worker reports a large chat", 20_000);
      const bigId = await ev<string>(`window.__opscodeRpc.call('chat.list', {}).then((r) => r.chats.find((x) => x.title === 'Big refactor').id)`);
      await ev(plNote(`more\nFAKE_TOOL chat_send ${JSON.stringify({ chat_id: bigId, text: "now add the tests FAKE_REPORT=done FAKE_CHECK" })}`));
      await until("!!document.querySelector('.cw-dock [data-slot=agent-handoff]') && document.querySelector('.cw-dock [data-slot=agent-handoff]').textContent.includes('Fresh') && document.querySelector('.cw-dock [data-slot=agent-handoff]').textContent.includes('Its last report')", "the dock shows the handoff to a fresh worker, with why and what it carried", 20_000);
      await shot("38-handoff");
      console.log("OPSCODE_SMOKE: renderer Conductor elements: Job progress, Subagent list, Agent handoff");

      // Sidebar: the mode chat is named after the first thing asked, its workers nest under it, delete asks at the top middle, unlink says the files stay.
      const sb = (q: string) => `document.querySelector(${JSON.stringify(q)})`;
      await until("document.querySelector('.sb-conductor[data-mode=shinobi] .sidebar-label')?.textContent === 'Build a shop app' && document.querySelector('.sb-conductor[data-mode=shinobi] .mode-emblem-sm') && !/SHINOBI/.test(document.querySelector('.sb-conductor').textContent)", "name the mode chat after its first request, with only the emblem for the mode");
      const workerIds = await ev<string[]>(`window.__opscodeRpc.call('chat.list', {}).then((r) => r.chats.filter((x) => x.chief && x.chief.id === '${cid}' && x.chief.role !== 'home').map((x) => x.id))`);
      if (workerIds.length < 3) throw new Error(`expected the Conductor's workers, got ${workerIds.length}`);
      await until(`${JSON.stringify(workerIds)}.every((id) => !document.querySelector('.sb-chats > .sb-chat[data-chat="' + id + '"]')) && /\\d+ nested/.test(${sb(`.sb-group[data-group="${cid}"] .sb-nest-sum`)}?.textContent ?? '')`, "workers are not top-level rows: the mode chat shows '<n> nested' under it");
      await shot("39-sidebar-nested-collapsed");
      await ev(`${sb(`.sb-group[data-group="${cid}"] .sb-expand`)}.click()`);
      await until(`document.querySelectorAll('.sb-group[data-group="${cid}"] .sb-nest[data-open=true] .sb-chat').length >= 3 && [...document.querySelectorAll('.sb-group[data-group="${cid}"] .sb-nest .sb-chat')].every((r) => r.querySelector('.spin, .sb-state'))`, "expand it: each nested worker is named and carries a state marker");
      await until(`[...document.querySelectorAll('.sb-group[data-group="${cid}"] .sb-nest .sidebar-label')].some((l) => l.textContent === 'Big refactor') && !!document.querySelector('.sb-nest .sb-chat[data-state=done]')`, "nested workers are named by their job and the finished ones say done");
      await shot("40-sidebar-nested-open");
      // delete one nested chat: the confirm drops in at the top middle
      const bagId = await ev<string>(`window.__opscodeRpc.call('chat.list', {}).then((r) => r.chats.find((x) => x.title === 'Bag icon').id)`);
      await ev(`${sb(`.sb-chat[data-chat="${bagId}"] .sb-more`)}.click()`);
      await until("[...document.querySelectorAll('.menu-item')].some((b) => b.textContent.includes('Delete chat'))", "the row's … menu offers Delete chat");
      await ev("[...document.querySelectorAll('.menu-item')].find((b) => b.textContent.includes('Delete chat')).click()");
      await until("!!document.querySelector('.overlay[data-top] .dialog.confirm-top[role=alertdialog]')", "delete asks first, in the top-middle popup");
      const pop = await ev<{ top: number; mid: number; win: number }>("(() => { const r = document.querySelector('.dialog.confirm-top').getBoundingClientRect(); return { top: r.top, mid: r.left + r.width / 2, win: window.innerWidth / 2 }; })()");
      if (pop.top > 120 || Math.abs(pop.mid - pop.win) > 6) throw new Error(`confirm is not at the top middle: ${JSON.stringify(pop)}`);
      await new Promise((r) => setTimeout(r, 400));
      await shot("41-confirm-delete-chat");
      await ev("document.querySelector('.confirm-top [data-act=cancel]').click()");
      await until(`!document.querySelector('.dialog.confirm-top') && !!document.querySelector('.sb-chat[data-chat="${bagId}"]')`, "Cancel keeps the chat");
      await ev(`${sb(`.sb-chat[data-chat="${bagId}"] .sb-more`)}.click()`);
      await ev("[...document.querySelectorAll('.menu-item')].find((b) => b.textContent.includes('Delete chat')).click()");
      await until("!!document.querySelector('.dialog.confirm-top')", "ask again");
      await ev("document.querySelector('.confirm-top [data-act=confirm]').click()");
      await until(`!document.querySelector('.sb-chat[data-chat="${bagId}"]') && !!document.querySelector('.sb-conductor')`, "the nested chat is deleted and the mode chat stays", 15_000);
      // hide and show a project's chat history
      await ev("document.querySelector('.sb-project[data-open=true] .sb-caret').click()");
      await until("!!document.querySelector('.sb-project[data-open=false]') && !document.querySelector('.sb-project[data-open=false] .sb-chats') && !!document.querySelector('.sb-project[data-open=false] .sb-count')", "clicking the open project hides its chats (and shows how many are hidden)");
      await shot("42-sidebar-project-hidden");
      await ev("document.querySelector('.sb-project[data-open=false] .sb-caret').click()");
      await until("!!document.querySelector('.sb-project[data-open=true] .sb-chats .sb-conductor')", "and shows them again");
      // delete the mode chat: it takes its nested chats, and the confirm says so
      await ev(`${sb(".sb-conductor .sb-more")}.click()`);
      await until("[...document.querySelectorAll('.menu-item')].some((b) => /Delete chat and \\d+ nested/.test(b.textContent))", "the mode chat's menu says it deletes its nested chats too");
      await ev("[...document.querySelectorAll('.menu-item')].find((b) => /Delete chat and/.test(b.textContent)).click()");
      await until("/nested chats/.test(document.querySelector('.dialog.confirm-top')?.textContent ?? '') && /stay as they are/.test(document.querySelector('.dialog.confirm-top').textContent)", "the confirm says the nested chats go too and files stay");
      await ev("document.querySelector('.confirm-top [data-act=confirm]').click()");
      await until(`!document.querySelector('.sb-conductor') && ${JSON.stringify(workerIds)}.every((id) => !document.querySelector('.sb-chat[data-chat="' + id + '"]'))`, "the mode chat and its nested chats are gone", 15_000);
      const left = await ev<number>(`window.__opscodeRpc.call('chat.list', {}).then((r) => r.chats.filter((x) => x.chief && x.chief.id === '${cid}').length)`);
      if (left !== 0) throw new Error(`${left} Conductor chats were left behind`);
      // unlink a project: says the files stay, and only the link goes
      const spare = mkdtempSync(join(tmpdir(), "opscode-smoke-spare-"));
      writeFileSync(join(spare, "note.txt"), "stays");
      const spareWs = await c.call<{ workspace: { path: string } }>("workspace.add", { path: spare });
      const sparePath = spareWs.workspace.path;
      await until(`[...document.querySelectorAll('.sb-project-row')].some((r) => r.title === ${JSON.stringify(sparePath)})`, "list the second project");
      const spareRow = `[...document.querySelectorAll('.sb-project-row')].find((r) => r.title === ${JSON.stringify(sparePath)})`;
      await ev(`${spareRow}.querySelector('.sb-more').click()`);
      await until("[...document.querySelectorAll('.menu-item')].some((b) => b.textContent.includes('Unlink project'))", "the project menu says Unlink project");
      if (await ev<boolean>("[...document.querySelectorAll('.menu-item')].some((b) => /Remove|Delete project/.test(b.textContent))")) throw new Error("the project menu must not say remove or delete");
      await ev("[...document.querySelectorAll('.menu-item')].find((b) => b.textContent.includes('Unlink project')).click()");
      await until("/not touched|nothing on disk/.test(document.querySelector('.overlay[data-top] .dialog.confirm-top')?.textContent ?? '') && document.querySelector('.confirm-top [data-act=confirm]')?.textContent === 'Unlink project'", "unlink confirms at the top middle and says the files on disk are not touched");
      await new Promise((r) => setTimeout(r, 400));
      await shot("43-confirm-unlink");
      await ev("document.querySelector('.confirm-top [data-act=cancel]').click()");
      await until(`!document.querySelector('.dialog.confirm-top') && !!(${spareRow})`, "Cancel keeps the project linked");
      await ev(`${spareRow}.querySelector('.sb-more').click()`);
      await ev("[...document.querySelectorAll('.menu-item')].find((b) => b.textContent.includes('Unlink project')).click()");
      await until("!!document.querySelector('.dialog.confirm-top')", "ask again");
      await ev("document.querySelector('.confirm-top [data-act=confirm]').click()");
      await until(`![...document.querySelectorAll('.sb-project-row')].some((r) => r.title === ${JSON.stringify(sparePath)})`, "the project is unlinked");
      if (!existsSync(join(spare, "note.txt"))) throw new Error("unlinking touched the folder");
      rmSync(spare, { recursive: true, force: true });
      console.log("OPSCODE_SMOKE: renderer Sidebar: mode chat named from its first request, workers nested with state markers, delete (one and all) and unlink ask at the top middle, files stay, project history hides and shows");
      await ev("document.querySelector('.sb-new').click()");
      await until("!!document.querySelector('.chat:not([hidden]) .cmp-model') && ![...document.querySelectorAll('.cf-conductor, .cf-hello, .mode-char-hello')].some((e) => e.offsetParent !== null)", "Normal chat is still a normal chat");
      console.log("OPSCODE_SMOKE: renderer Modes: picker (Normal + GODMODE/WARLORD/SHINOBI characters), SHINOBI Conductor in the project with emblem, Normal chat unchanged");

      // Library: suggestions, add an app, features with layers, search "do we already have...", a feature's detail.
      await ev("document.querySelector('.sb-nav[data-page=library]').click()");
      await until("!!document.querySelector('.lb-page:not([hidden]) .lb-sugg-row') && document.querySelector('.lb-sugg-n')?.textContent === 'shopfix'", "show the Library with the suggested app");
      await ev("document.querySelector('.lb-sugg-row .btn').click()");
      await until("document.querySelectorAll('.lb-frow').length === 6 && !!document.querySelector('.lb-pkg') && document.querySelector('.lb-main')?.textContent.includes('NestJS')", "read the app and list its 6 features", 30_000);
      await ev(`(() => { const i = document.querySelector('.lb-search'); i.value = 'loyalty points'; i.dispatchEvent(new Event('input', { bubbles: true })); })()`);
      await until("document.querySelector('.lb-hit')?.dataset.feature === 'loyalty' && document.querySelector('.lb-hit').textContent.includes('Backend') && document.querySelector('.lb-hit').textContent.includes('App')", "search 'loyalty points' across the apps");
      await ev("document.querySelector('.lb-hit').click()");
      await until("(() => { const p = document.querySelector('.lb-fpane[data-open=loyalty]'); const x = p?.textContent ?? ''; return x.includes('/loyalty/points') && x.includes('loyalty_points') && x.includes('same name') ; })()", "open the loyalty feature with its routes, table and why the layers joined");
      await new Promise((r) => setTimeout(r, 500));
      await shot("35-library");
      await ev("document.querySelector('.sb-nav[data-page=chief]')?.click()");
      console.log("OPSCODE_SMOKE: renderer Library: suggested app added and read, 6 features, search finds loyalty across backend + app, feature detail");
    } finally {
      mockApi.close();
    }
    await c.call("workspace.remove", { workspace_id: workspace.id });
    c.close();
    rmSync(project, { recursive: true, force: true });

    clearTimeout(watchdog);
    await finish(0, "PASS");
  } catch (err) {
    clearTimeout(watchdog);
    try { if (process.env.OPSCODE_SHOT_DIR) writeFileSync(join(process.env.OPSCODE_SHOT_DIR, "FAIL.png"), (await win.webContents.capturePage()).toPNG()); } catch { /* window gone */ }
    await finish(1, `FAIL ${err instanceof Error ? err.message : String(err)}`);
  }
}

/**
 * What runs the runtime. Started from the app's own program, macOS counts the runtime as a second app and gives it its own
 * Dock icon (a plain "exec" tile). Electron's Helper program in the same bundle is marked as background-only (LSUIElement), so
 * the runtime runs from that one: same engine, no Dock icon. Falls back to the app's program where there is no Helper (Linux, Windows).
 */
function runtimeCommand(): string {
  if (process.platform !== "darwin") return process.execPath;
  const base = basename(process.execPath);
  const helper = join(dirname(process.execPath), "..", "Frameworks", `${base} Helper.app`, "Contents", "MacOS", `${base} Helper`);
  return existsSync(helper) ? helper : process.execPath;
}

/**
 * The main window's close button (macOS): hides the window instead of closing it, like other Mac apps, so the notch,
 * chats and agents keep going and the window comes back at once. ⌘Q (or Quit in the notch's menu) really quits.
 * Tells the notch when the window gains or loses focus, so a finished chat on screen counts as seen.
 */
function attachMain(win: BrowserWindow): BrowserWindow {
  win.on("close", (event) => {
    if (quitting || SMOKE || process.env.OPSCODE_REALTEST || process.platform !== "darwin" || !notch) return;
    event.preventDefault();
    if (win.isFullScreen()) { win.once("leave-full-screen", () => win.hide()); win.setFullScreen(false); }
    else win.hide();
  });
  win.on("focus", () => notch?.mainFocus(true));
  win.on("blur", () => notch?.mainFocus(false));
  win.on("hide", () => notch?.mainFocus(false));
  win.on("closed", () => { notch?.mainFocus(false); if (mainWindow === win) mainWindow = null; });
  return win;
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on("second-instance", () => focusWindow(mainWindow));

  app.whenReady().then(async () => {
    lockDownPermissions();
    // dist/main/index.js -> ../renderer == dist/renderer
    serveAppScheme(join(__dirname, "..", "renderer"));

    // Run the runtime with Electron's own binary in Node mode (dev). A packaged
    // build would flip the RunAsNode fuse off and ship a separate node instead.
    supervisor = await RuntimeSupervisor.create({
      command: runtimeCommand(),
      args: [join(__dirname, "..", "runtime", "index.js")],
      env: { ...process.env, ELECTRON_RUN_AS_NODE: "1" },
      stateDir: join(app.getPath("userData"), "runtime"),
      appVersion: app.getVersion(),
      log,
    });
    supervisor.start();
    registerIpc(() => supervisor?.endpoint ?? null);
    // The agent's browser: main registers with the runtime as the device host.
    browserHost = new BrowserHost(() => supervisor?.endpoint ?? null, rendererBridge(() => mainWindow), log);
    browserHost.start();

    const preloadPath = join(__dirname, "..", "preload", "index.js");
    mainWindow = attachMain(createMainWindow(preloadPath));
    // The notch: always on at the top of the screen, with its own runtime connection (works with the window closed).
    if (!SMOKE && !process.env.OPSCODE_REALTEST && process.env.OPSCODE_NOTCH !== "0" && (process.platform === "darwin" || process.platform === "win32")) {
      notch = new Notch({
        url: `${APP_URL}notch.html`,
        preload: join(__dirname, "..", "preload", "notch.js"),
        log,
        endpoint: () => supervisor?.endpoint ?? null,
        openMain: (target) => {
          if (!mainWindow || mainWindow.isDestroyed()) mainWindow = attachMain(createMainWindow(preloadPath));
          const win = mainWindow;
          focusWindow(win);
          if (target.chat_id || target.newchat || target.workspace_id) {
            const go = (): void => win.webContents.send(CH.NOTCH_OPEN, target);
            if (win.webContents.isLoading()) win.webContents.once("did-finish-load", () => setTimeout(go, 400)); else go();
          }
        },
      });
      notch.start();
      if (process.platform === "darwin") {
        const menu = Menu.getApplicationMenu();
        if (menu) {
          const appMenu = menu.items[0]?.submenu;
          appMenu?.insert(Math.min(2, appMenu.items.length), new MenuItem({
            label: "Pair Android…", accelerator: "Command+Option+Shift+P", click: () => notch?.pairAndroid(),
          }));
          Menu.setApplicationMenu(menu);
        }
      }
      ipcMain.on(CH.NOTCH_VIEWING, (event, chatId: unknown) => {
        if (!isOwnFrame(event.senderFrame?.url) || event.sender !== mainWindow?.webContents) return;
        notch?.viewing(typeof chatId === "string" && chatId.length <= 200 ? chatId : null);
      });
    }
    ipcMain.handle(CH.MOBILE_DEVICES, async (event, action: unknown, arg: unknown) => {
      if (!isOwnFrame(event.senderFrame?.url) || event.sender !== mainWindow?.webContents) return null;
      switch (action) {
        case "status": break;
        case "pair": await notch?.pairAndroid(false); break;
        case "revoke":
          if (typeof arg === "string" && /^[0-9a-f]{32}$/.test(arg)) await notch?.revokeMobileDevice(arg);
          break;
      }
      return notch?.mobileStatus() ?? null;
    });
    if (SMOKE) void runSmoke(mainWindow, supervisor);
    else if (process.env.OPSCODE_REALTEST) {
      const sup = supervisor;
      void import("./realtest").then((m) => m.runRealTest(mainWindow as BrowserWindow, sup)).finally(async () => { await sup.stop(); app.exit(0); });
    }

    app.on("activate", () => {
      if (!mainWindow || mainWindow.isDestroyed()) mainWindow = attachMain(createMainWindow(preloadPath));
      else focusWindow(mainWindow);
    });
  });

  // Stop the runtime before quitting so it never outlives the app.
  app.on("before-quit", (event) => {
    quitting = true;
    if (shuttingDown || !supervisor) return;
    notch?.stop();
    event.preventDefault();
    shuttingDown = true;
    browserHost?.stop();
    void supervisor.stop().finally(() => app.quit());
  });

  app.on("window-all-closed", () => {
    if (process.platform !== "darwin") app.quit();
  });
}
