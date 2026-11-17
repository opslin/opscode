#!/usr/bin/env node
// A stand-in for `xcrun simctl …` with two simulators (state kept in $OPSCODE_FAKE_SIM_STATE).
// Logs argv to $OPSCODE_FAKE_ENGINE_LOG as {bin:"xcrun", argv}.
import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { deflateSync } from "node:zlib";
const argv = process.argv.slice(2);
const log = process.env.OPSCODE_FAKE_ENGINE_LOG;
let stdin = "";
if (argv[1] === "pbcopy") stdin = readFileSync(0, "utf8");
if (log) appendFileSync(log, JSON.stringify({ bin: "xcrun", argv, ...(stdin ? { stdin } : {}) }) + "\n");
const statePath = process.env.OPSCODE_FAKE_SIM_STATE;
const st = statePath && existsSync(statePath) ? JSON.parse(readFileSync(statePath, "utf8")) : { booted: [], appearance: "light" };
const save = () => statePath && writeFileSync(statePath, JSON.stringify(st));
const PHONE = "11111111-2222-3333-4444-555555555555", PAD = "66666666-7777-8888-9999-000000000000";
const dev = (udid, name) => ({ udid, name, state: st.booted.includes(udid) ? "Booted" : "Shutdown", isAvailable: true });
const [tool, cmd, ...rest] = argv;
if (tool !== "simctl") { console.error("only simctl"); process.exit(1); }
const crc = (b) => { let c = ~0; for (const x of b) { c ^= x; for (let k = 0; k < 8; k++) c = c & 1 ? (c >>> 1) ^ 0xedb88320 : c >>> 1; } return ~c >>> 0; };
const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([len, td, c]); };
function png(w, h) {
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2;
  const row = Buffer.alloc(1 + w * 3, 0x40); row[0] = 0;
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk("IHDR", ihdr), chunk("IDAT", deflateSync(Buffer.concat(Array.from({ length: h }, () => row)))), chunk("IEND", Buffer.alloc(0))]);
}
const known = (u) => { if (u !== PHONE && u !== PAD) { console.error(`Invalid device: ${u}`); process.exit(164); } };
switch (cmd) {
  case "list": console.log(JSON.stringify({ devices: { "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [dev(PHONE, "iPhone 17"), dev(PAD, "iPad Air")], "com.apple.CoreSimulator.SimRuntime.watchOS-12-0": [] } })); break;
  case "boot": known(rest[0]); if (st.booted.includes(rest[0])) { console.error("Unable to boot device in current state: Booted"); process.exit(149); } st.booted.push(rest[0]); save(); break;
  case "bootstatus": known(rest[0]); break;
  case "shutdown": st.booted = st.booted.filter((u) => u !== rest[0]); save(); break;
  case "io": known(rest[0]); writeFileSync(rest.at(-1), png(786, 1704)); break;
  case "ui": if (rest[2]) { st.appearance = rest[2]; save(); } else console.log(st.appearance); break;
  case "launch": console.log(`${rest.at(-1)}: 4242`); break;
  case "listapps": console.log('{\n "com.apple.mobilesafari" = { CFBundleIdentifier = "com.apple.mobilesafari"; };\n "com.shotlin.shop" = { CFBundleIdentifier = "com.shotlin.shop"; CFBundleDisplayName = Shop; };\n}'); break;
  case "spawn": console.log("Timestamp               Ty Process[PID:TID]\n2026-11-16 10:00:00.000 E  Shop[4242:1] boom in checkout"); break;
  default: break; // install, terminate, openurl, pbcopy, location: fine
}
