#!/usr/bin/env node
// A stand-in for native opscode-sim: `serve --udid X` speaks its JSON lines and logs each command.
import { appendFileSync } from "node:fs";
const log = process.env.OPSCODE_FAKE_ENGINE_LOG;
const out = (m) => process.stdout.write(JSON.stringify(m) + "\n");
const udid = process.argv[process.argv.indexOf("--udid") + 1];
if (log) appendFileSync(log, JSON.stringify({ bin: "simhelper", start: udid }) + "\n");
out({ id: 0, ok: true, ready: true, width: 393, height: 852 });
let buf = "";
process.stdin.on("data", (d) => {
  buf += d;
  let i;
  while ((i = buf.indexOf("\n")) >= 0) {
    const m = JSON.parse(buf.slice(0, i)); buf = buf.slice(i + 1);
    if (log) appendFileSync(log, JSON.stringify({ bin: "simhelper", udid, ...m }) + "\n");
    if (m.cmd === "touch" && (m.x > 393 || m.y > 852)) out({ id: m.id, ok: false, error: "outside the screen" });
    else out({ id: m.id, ok: true });
  }
});
