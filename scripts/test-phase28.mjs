// Device slice D2: the iOS Simulator. A fake `xcrun simctl` (two simulators) and a fake
// opscode-sim helper stand in for Xcode; the checks cover the ios_simulator tool through
// Claude Code's MCP path (permission modes, approvals), every action's simctl/helper calls,
// screenshots scaled to points, the panel's RPCs, and the real helper's self-check.

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, sleep } from "./lib/harness.mjs";

const t = reporter();
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p28-")));
const proj = join(base, "app");
mkdirSync(proj, { recursive: true });
const logFile = join(base, "engines.log");
writeFileSync(logFile, "");
const PHONE = "11111111-2222-3333-4444-555555555555";
const env = {
  OPSCODE_CLAUDE_BIN: join(process.cwd(), "scripts/lib/fake-claude.mjs"),
  OPSCODE_XCRUN: join(process.cwd(), "scripts/lib/fake-xcrun.mjs"),
  OPSCODE_SIM_HELPER: join(process.cwd(), "scripts/lib/fake-simhelper.mjs"),
  OPSCODE_FAKE_SIM_STATE: join(base, "sim.json"),
  OPSCODE_FAKE_ENGINE_LOG: logFile,
};
const L = () => readFileSync(logFile, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const simctl = (cmd) => L().filter((l) => l.bin === "xcrun" && l.argv[1] === cmd);
const helper = (pred = () => true) => L().filter((l) => l.bin === "simhelper" && l.cmd && pred(l));

// A built .app to install (just enough for plutil).
const app = join(base, "Shop.app");
mkdirSync(app);
writeFileSync(join(app, "Info.plist"), `<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.shotlin.shop</string></dict></plist>`);

if (process.platform === "darwin" && existsSync("dist/native/opscode-sim")) {
  let out = "";
  try { out = execFileSync("dist/native/opscode-sim", ["check"], { encoding: "utf8" }); } catch (e) { out = String(e.stdout ?? e.message); }
  t.check("the real helper loads Xcode's simulator frameworks (self-check)", JSON.parse(out).ok === true, out.trim());
}

const rt = await startRuntime({ env, stateDir: join(base, "state"), keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  const wid = (await C.call("workspace.add", { path: proj })).result.workspace.id;
  const waitFor = async (fn, ms = 20000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(50)) { const v = await fn(); if (v) return v; } return null; };
  const events = (turnId) => C.find("turn.event", (p) => p.turn_id === turnId).map((n) => n.params);
  const finished = (turnId) => waitFor(() => events(turnId).some((e) => ["completed", "failed", "interrupted"].includes(e.type)));
  const results = () => L().filter((l) => l.device_tool === "ios_simulator");
  /** Runs ios_simulator calls in a Claude Code chat; approves (or not) each request. */
  const run = async (chatId, calls, allow = true) => {
    const before = results().length;
    const text = `go\n${calls.map((a) => `FAKE_DEVICE ios_simulator ${JSON.stringify(a)}`).join("\n")}`;
    const r = (await C.call("turn.submit", { workspace_id: wid, chat_id: chatId, text })).result;
    let answered = 0;
    await waitFor(async () => {
      for (const ev of events(r.turn_id).filter((e) => e.type === "approval_request").slice(answered)) { answered++; await C.call("turn.approve", { turn_id: r.turn_id, call_id: ev.call_id, allow }); }
      return events(r.turn_id).some((e) => ["completed", "failed"].includes(e.type));
    });
    return { asked: answered, out: results().slice(before), turn: r.turn_id };
  };

  t.check("devices.status reports the iOS Simulator", (await C.call("devices.status", {})).result?.ios === true);
  const list = (await C.call("ios.list", {})).result;
  t.check("ios.list lists the simulators (booted first, runtime named)", list.available && list.devices.length === 2 && list.devices.some((d) => d.name === "iPhone 17" && d.runtime === "iOS 26.5"), JSON.stringify(list));

  const sup = (await C.call("chat.create", { workspace_id: wid, engine: "claude-code", mode: "supervised" })).result.chat;
  let r = await run(sup.id, [{ action: "list" }, { action: "screenshot" }]);
  t.check("Claude Code gets the ios_simulator tool", (L().find((l) => l.device_tools)?.device_tools ?? []).includes("ios_simulator"));
  t.check("and the iOS note in its prompt", (() => { const a = L().filter((l) => l.bin === "claude" && l.argv?.includes("--input-format")).at(-1)?.argv ?? []; return (a[a.indexOf("--append-system-prompt") + 1] ?? "").includes("ios_simulator"); })());
  t.check("list needs no approval and lists both devices", r.asked === 0 && /iPhone 17 \(iOS 26\.5\) 11111111/.test(r.out[0]?.result ?? ""), r.out[0]?.result);
  t.check("with nothing booted, a screenshot says how to boot one", r.out[1]?.is_error && /No simulator is booted.*boot.*iPhone 17/.test(r.out[1].result), r.out[1]?.result);

  r = await run(sup.id, [{ action: "boot", device: "iPhone 17" }]);
  t.check("Supervised: booting asks first, then boots and waits", r.asked === 1 && /iPhone 17 \(iOS 26\.5\) is booted/.test(r.out[0]?.result ?? "") && simctl("boot").length === 1 && simctl("bootstatus").some((l) => l.argv.includes("-b")));
  r = await run(sup.id, [{ action: "boot", device: PHONE }]);
  t.check("booting a booted device is fine", /is booted/.test(r.out[0]?.result ?? "") && !r.out[0].is_error, r.out[0]?.result);

  r = await run(sup.id, [{ action: "screenshot" }]);
  t.check("screenshot: a picture for the model, scaled to device points", r.asked === 0 && r.out[0]?.image === true && /393x852 points/.test(r.out[0].result), r.out[0]?.result);
  t.check("taken with simctl io … screenshot", simctl("io").some((l) => l.argv.includes("screenshot") && l.argv.includes(PHONE)));

  writeFileSync(logFile, "");
  r = await run(sup.id, [{ action: "tap", x: 100, y: 200 }]);
  const taps = helper((l) => l.cmd === "touch");
  t.check("tap asks, then sends touch down + up at that point through the helper", r.asked === 1 && taps.length === 2 && taps[0].phase === "down" && taps[1].phase === "up" && taps[0].x === 100 && taps[0].y === 200 && taps[0].udid === PHONE, JSON.stringify(taps));
  r = await run(sup.id, [{ action: "tap", x: 50, y: 60 }], false);
  t.check("a denied tap is not sent", /denied/.test(r.out[0]?.result ?? "") && helper((l) => l.cmd === "touch" && l.x === 50).length === 0);

  const full = (await C.call("chat.create", { workspace_id: wid, engine: "claude-code", mode: "full" })).result.chat;
  writeFileSync(logFile, "");
  r = await run(full.id, [
    { action: "swipe", x: 200, y: 700, x2: 200, y2: 200, duration: 0.2 },
    { action: "touch2_path", points2: [{ x1: 150, y1: 400, x2: 250, y2: 400 }, { x1: 100, y1: 400, x2: 300, y2: 400, dt_ms: 30 }] },
    { action: "text", text: "Hi!" },
    { action: "text", text: "héllo" },
    { action: "press_key", key: "select_all" },
    { action: "button", name: "home" },
    { action: "tap", x: 500, y: 10 },
  ]);
  t.check("Full access: no asking", r.asked === 0);
  const sw = helper((l) => l.cmd === "touch" && !l.x2);
  t.check("swipe: down, several moves, up, from start to end", sw[0]?.phase === "down" && sw[0].y === 700 && sw.filter((x) => x.phase === "move").length >= 5 && sw.find((x) => x.phase === "up")?.y === 200, JSON.stringify(sw.map((x) => [x.phase, Math.round(x.y)])));
  const two = helper((l) => l.cmd === "touch" && l.x2 !== undefined);
  t.check("two-finger path sends both fingers", two.length === 3 && two[0].phase === "down" && two[2].phase === "up" && two[1].x2 === 300, JSON.stringify(two));
  const keys = helper((l) => l.cmd === "key");
  const downs = keys.filter((k) => k.phase === "down").map((k) => k.usage);
  t.check("text types with HID key presses (shift for capitals and !)", downs.slice(0, 5).join(",") === "225,11,12,225,30", downs.join(","));
  t.check("text a US keyboard can't type is pasted (pbcopy + cmd+v)", simctl("pbcopy").some((l) => l.stdin === "héllo") && downs.includes(227) && downs.includes(25));
  t.check("press_key select_all = cmd+a", (() => { const i = downs.lastIndexOf(4); return i > 0 && downs[i - 1] === 227; })());
  t.check("button home presses and releases the Home button", helper((l) => l.cmd === "button" && l.name === "home").map((b) => b.phase).join(",") === "down,up");
  t.check("a point outside the screen is an error the model sees", results().at(-1)?.is_error && /outside the screen/.test(results().at(-1).result), results().at(-1)?.result);

  writeFileSync(logFile, "");
  r = await run(full.id, [
    { action: "launch", app_path: app },
    { action: "launch", app_path: "relative/Shop.app" },
    { action: "open_url", url: "myshop://cart" },
    { action: "open_url", url: "file:///etc/passwd" },
    { action: "set_appearance", state: "dark" },
    { action: "appearance" },
    { action: "list_apps" },
    { action: "logs", process: "Shop", seconds: 30 },
    { action: "set_location", latitude: 22.57, longitude: 88.36 },
    { action: "terminate", bundle_id: "com.shotlin.shop" },
  ]);
  const o = r.out.map((x) => x.result);
  t.check("launch app_path installs the .app, then launches its bundle id", simctl("install").some((l) => l.argv.includes(app)) && simctl("launch").some((l) => l.argv.includes("--terminate-running-process") && l.argv.at(-1) === "com.shotlin.shop") && /Launched com\.shotlin\.shop \(installed it first\) \(pid 4242\)/.test(o[0]), o[0]);
  t.check("a relative or non-.app path is refused", /absolute path of a built \.app/.test(o[1]) && simctl("install").length === 1);
  t.check("open_url opens deep links but not file: URLs", simctl("openurl").some((l) => l.argv.at(-1) === "myshop://cart") && /deep link/.test(o[3]) && simctl("openurl").length === 1);
  t.check("set_appearance + appearance", simctl("ui").some((l) => l.argv.at(-1) === "dark") && /in dark mode/.test(o[5]), o[5]);
  t.check("list_apps shows the user's apps, not Apple's", /com\.shotlin\.shop/.test(o[6]) && !/mobilesafari/.test(o[6].split("\n")[0]), o[6]);
  t.check("logs reads the device log for a process", simctl("spawn").some((l) => l.argv.includes("log") && l.argv.includes("30s") && l.argv.join(" ").includes('process == "Shop"')) && /boom in checkout/.test(o[7]), o[7]);
  t.check("set_location and terminate", simctl("location").some((l) => l.argv.at(-1) === "22.57,88.36") && simctl("terminate").some((l) => l.argv.at(-1) === "com.shotlin.shop"));

  writeFileSync(logFile, "");
  r = await run(full.id, [{ action: "tap", x: 10, y: 20, screenshot_after: true }]);
  t.check("screenshot_after returns the action and a picture", r.out[0]?.image === true && /^Tapped 10,20\. Screenshot/.test(r.out[0].result), r.out[0]?.result);

  // Read only: look, don't touch.
  const ro = (await C.call("chat.create", { workspace_id: wid, engine: "claude-code", mode: "read" })).result.chat;
  writeFileSync(logFile, "");
  r = await run(ro.id, [{ action: "screenshot" }, { action: "tap", x: 1, y: 1 }, { action: "shutdown" }]);
  t.check("Read only can look at the simulator", r.out[0]?.image === true && r.asked === 0);
  t.check("but not touch it or shut it down", /read-only/.test(r.out[1]?.result ?? "") && /read-only/.test(r.out[2]?.result ?? "") && helper((l) => l.cmd === "touch").length === 0 && simctl("shutdown").length === 0);

  // Panel RPCs (the user's own clicks).
  const scr = (await C.call("ios.screen", { udid: PHONE })).result;
  t.check("ios.screen returns the picture for the panel", scr?.data_url?.startsWith("data:image/jpeg;base64,") && scr.width === 393 && scr.height === 852, JSON.stringify(Object.keys(scr ?? {})));
  writeFileSync(logFile, "");
  await C.call("ios.tap", { udid: PHONE, x: 30, y: 40 });
  t.check("ios.tap (a click in the panel) taps the device", helper((l) => l.cmd === "touch" && l.x === 30).length === 2);
  t.check("ios.screen of a device that is off says so", !!(await C.call("ios.screen", { udid: "66666666-7777-8888-9999-000000000000" })).error);
  const act = C.find("ios.activity");
  t.check("the panel hears what the agent is doing", act.some((n) => n.params.udid === PHONE && n.params.label === "tap"));
  await run(full.id, [{ action: "shutdown" }]);
  t.check("shutdown shuts the booted device down", simctl("shutdown").some((l) => l.argv.includes(PHONE)) && (await C.call("ios.list", {})).result.devices.every((d) => d.state !== "Booted"));
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
}
process.exit(t.finish());
