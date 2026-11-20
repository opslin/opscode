#!/usr/bin/env node
// A stand-in for `chrome --headless --dump-dom <url>` for tests. It fetches the page through the proxy it was
// given (as a real browser would) and sends the header x-rendered: 1, which the fixture sites read as "scripts ran".
//   FAKE_CHROME_LOG    file: one JSON line per event (start, probe results)
//   FAKE_CHROME_PROBE  comma-separated URLs fetched through the proxy as if a page script asked for them
//   FAKE_CHROME_HANG   never finishes (to test the timeout and process cleanup)
//   FAKE_CHROME_EMPTY  prints nothing
import http from "node:http";
import { appendFileSync, existsSync } from "node:fs";

const args = process.argv.slice(2);
const flag = (n) => args.find((a) => a.startsWith(`--${n}=`))?.split("=").slice(1).join("=");
const proxy = new URL(flag("proxy-server") ?? "http://127.0.0.1:1");
const url = args[args.length - 1];
const log = (o) => process.env.FAKE_CHROME_LOG && appendFileSync(process.env.FAKE_CHROME_LOG, JSON.stringify(o) + "\n");
log({ ev: "start", pid: process.pid, profile: flag("user-data-dir"), profileExists: existsSync(flag("user-data-dir") ?? "/nonexistent"), headless: args.includes("--headless"), dump: args.includes("--dump-dom"), bypass: flag("proxy-bypass-list"), ua: flag("user-agent") });
if (process.env.FAKE_CHROME_HANG) setInterval(() => {}, 1000);
else {
  // A real browser would CONNECT for https; the fixtures speak plain http, so the stand-in asks for http.
  const get = (target0) => new Promise((resolve) => {
    const target = target0.replace(/^https:/, "http:");
    const u = new URL(target);
    const req = http.request({ host: proxy.hostname, port: proxy.port, path: target, headers: { host: u.host, "x-rendered": "1" } }, (res) => { const c = []; res.on("data", (d) => c.push(d)); res.on("end", () => resolve({ status: res.statusCode, body: Buffer.concat(c).toString("utf8") })); });
    req.on("error", () => resolve({ status: 0, body: "" }));
    req.end();
  });
  for (const p of (process.env.FAKE_CHROME_PROBE ?? "").split(",").filter(Boolean)) log({ ev: "probe", url: p, status: (await get(p)).status });
  if (!process.env.FAKE_CHROME_EMPTY) process.stdout.write((await get(url)).body);
}
