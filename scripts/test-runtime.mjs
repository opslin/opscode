// Phase 2 protocol tests: auth, origin pinning, the hello gate, RPC error
// codes, notifications, settings persistence and shutdown.

import { readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { BEARER_PREFIX, SUBPROTOCOL, client, dial, reporter, startRuntime, waitFor } from "./lib/harness.mjs";

const t = reporter();
const rt = await startRuntime();
t.check("runtime starts and prints READY", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);
const { url, token, stateDir } = rt;

try {
  // --- authentication & origin -------------------------------------------
  let r = await dial(url, [SUBPROTOCOL]);
  t.check("no token -> 401", r.status === 401, JSON.stringify(r.status ?? r.error));

  r = await dial(url, [SUBPROTOCOL], { headers: { authorization: "Bearer " + "0".repeat(64) } });
  t.check("wrong token -> 401", r.status === 401, JSON.stringify(r.status ?? r.error));

  r = await dial(url, [SUBPROTOCOL], { headers: { authorization: `Bearer ${token}` }, origin: "https://evil.example" });
  t.check("good token + foreign Origin -> 403", r.status === 403, JSON.stringify(r.status ?? r.error));

  r = await dial(url.replace("/session/v1", "/other"), [SUBPROTOCOL], { headers: { authorization: `Bearer ${token}` } });
  t.check("wrong path -> 404", r.status === 404, JSON.stringify(r.status ?? r.error));

  const b64 = Buffer.from(token, "utf8").toString("base64url");
  r = await dial(url, [SUBPROTOCOL, BEARER_PREFIX + b64], { origin: "opscode://app" });
  t.check("browser-style subprotocol auth + app Origin -> open", !!r.ws, JSON.stringify(r.status ?? r.error));
  t.check("server echoes only the session subprotocol", r.ws?.protocol === SUBPROTOCOL, r.ws?.protocol);
  r.ws?.close();

  // --- session behaviour --------------------------------------------------
  const a = await dial(url, [SUBPROTOCOL], { headers: { authorization: `Bearer ${token}` } });
  const b = await dial(url, [SUBPROTOCOL], { headers: { authorization: `Bearer ${token}` } });
  const A = client(a.ws);
  const B = client(b.ws);

  let res = await A.call("runtime.ping", {});
  t.check("call before hello -> -32002", res.error?.code === -32002, JSON.stringify(res.error));

  res = await A.call("runtime.hello", { client_revision: 0 });
  t.check("too-old client -> -32003", res.error?.code === -32003, JSON.stringify(res.error));

  res = await A.call("runtime.hello", { client_revision: 1 });
  t.check("hello -> version + revision + session", res.result?.protocol_revision === 1 && res.result?.version === "0.0.1-test" && !!res.result?.session_id);
  await B.call("runtime.hello", { client_revision: 1 });

  res = await A.call("runtime.ping", { sent_at: 42 });
  t.check("runtime.ping echoes", res.result?.pong === true && res.result?.echo === 42);

  res = await A.call("nope.method", {});
  t.check("unknown method -> -32601", res.error?.code === -32601);

  res = await A.call("settings.set", { patch: { theme: "purple" } });
  t.check("invalid setting value -> -32602", res.error?.code === -32602, res.error?.message);

  res = await A.call("settings.set", { patch: { favorite_color: "green" } });
  t.check("unknown setting key -> -32602", res.error?.code === -32602, res.error?.message);

  res = await A.raw("{not json");
  t.check("malformed JSON -> -32700", res.error?.code === -32700);

  res = await A.call("settings.get", {});
  t.check("settings.get returns defaults", res.result?.settings?.theme === "system" && res.result?.settings?.display_name === "");

  res = await A.call("settings.set", { patch: { display_name: "  Sayan  ", theme: "dark" } });
  t.check("settings.set trims + applies", res.result?.settings?.display_name === "Sayan" && res.result?.settings?.theme === "dark");

  const pushed = await waitFor(() => B.find("settings.changed", (p) => p?.settings?.theme === "dark").length > 0);
  t.check("other session receives settings.changed", pushed);

  const file = join(stateDir, "settings.json");
  const saved = JSON.parse(readFileSync(file, "utf8"));
  t.check("settings persisted to state dir", saved.theme === "dark" && saved.display_name === "Sayan");
  t.check("settings file is mode 0600", (statSync(file).mode & 0o777) === 0o600, (statSync(file).mode & 0o777).toString(8));
  t.check("state dir is mode 0700", (statSync(stateDir).mode & 0o777) === 0o700, (statSync(stateDir).mode & 0o777).toString(8));

  A.close();
  B.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
}

process.exit(t.finish());
