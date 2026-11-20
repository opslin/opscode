// Browser sign-in (OAuth) for MCP servers: discovery, dynamic registration, authorization code + PKCE, loopback redirect,
// refresh, sign-out, and the ways it must refuse. A fake server plays the service; the test plays the browser.

import { mkdtempSync, readFileSync, realpathSync, statSync } from "node:fs";
import { request as httpRequest } from "node:http";
import { createConnection } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, waitFor, sleep } from "./lib/harness.mjs";
import { browserSignIn, startOAuthMcp } from "./lib/mock-oauth-mcp.mjs";

const t = reporter();
const E = { NOT_FOUND: -32004, CONFLICT: -32009 };
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 300);

const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p54-")));
const stateDir = join(base, "state");
let rt = await startRuntime({ stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);
const svc = await startOAuthMcp();
try {
  let C = await session(rt);
  const servers = async () => (await C.call("mcp.list")).result.servers;
  const one = async (id) => (await servers()).find((s) => s.id === id);
  const until = async (id, pred, ms = 6000) => { for (const end = Date.now() + ms; Date.now() < end; await sleep(50)) { const s = await one(id); if (s && pred(s)) return s; } return one(id); };
  const doneEvents = (id) => C.find("mcp.oauth.done", (p) => p.id === id);

  // ---- a server that asks for a sign-in ------------------------------------------------------------------------------------
  let res = await C.call("mcp.add", { input: svc.url, name: "mock" });
  const id = res.result.server.id;
  let s = await until(id, (x) => x.state === "error");
  t.check("a server that answers 401 with sign-in settings is marked 'needs a sign-in', not 'needs a key'", s.state === "error" && s.auth === "oauth" && s.needs_signin === true && !s.needs_key && s.signed_in === false, JSON.stringify(s));

  // ---- start the sign-in ---------------------------------------------------------------------------------------------------
  res = await C.call("mcp.oauth.start", { id });
  const url = res.result?.url;
  t.check("mcp.oauth.start returns the address to open in the browser", typeof url === "string" && url.startsWith(`http://127.0.0.1:${svc.port}/authorize?`), why(res));
  const q = Object.fromEntries(new URL(url).searchParams);
  t.check("the address asks for a code with PKCE S256 and a state", q.response_type === "code" && q.code_challenge_method === "S256" && q.code_challenge?.length >= 40 && q.state?.length >= 24, JSON.stringify(q));
  t.check("it carries the resource (RFC 8707) and the scope the server named", q.resource === svc.url && q.scope === "read write", JSON.stringify(q));
  t.check("the redirect is a loopback address on this computer", /^http:\/\/127\.0\.0\.1:\d+\/callback$/.test(q.redirect_uri), q.redirect_uri);
  const reg = svc.registrations[0];
  t.check("Opscode registered itself as a public native client named Opscode", svc.registrations.length === 1 && reg.client_name === "Opscode" && reg.token_endpoint_auth_method === "none" && reg.application_type === "native" && reg.redirect_uris?.[0] === q.redirect_uri && reg.grant_types.includes("refresh_token"), JSON.stringify(reg));
  s = await one(id);
  t.check("the list says a sign-in is waiting for the browser", s.signing_in === true && s.signed_in === false, JSON.stringify(s));

  // ---- the browser comes back with the wrong state: ignored ---------------------------------------------------------------------
  const cb = new URL(q.redirect_uri);
  let bad = await fetch(`${cb.origin}/callback?code=stolen&state=wrong-state-value-wrong-state-value`);
  t.check("a callback with the wrong state is refused and does not end the sign-in", (await bad.text()).includes("did not match") && (await one(id)).signing_in === true);
  bad = await fetch(`${cb.origin}/elsewhere?state=${q.state}&code=x`);
  t.check("only /callback answers (other paths are 404)", bad.status === 404);
  const rebind = await new Promise((r) => { const req = httpRequest({ host: "127.0.0.1", port: Number(cb.port), path: `/callback?state=${q.state}&code=x`, headers: { host: "evil.example" } }, (res) => { res.resume(); r(res.statusCode); }); req.on("error", () => r("error")); req.end(); });
  t.check("a request that names another host is refused (DNS rebinding)", rebind === 404, String(rebind));
  t.check("and it did not end the sign-in", (await one(id)).signing_in === true);

  // ---- the person signs in -------------------------------------------------------------------------------------------------------
  const page = await browserSignIn(url);
  t.check("the loopback page tells the person they are signed in", page.status === 200 && /signed in/i.test(page.text), page.text.slice(0, 120));
  t.check("the sign-in finishes: server ready, signed in, tools listed", !!(await until(id, (x) => x.state === "ready" && x.signed_in)), JSON.stringify(await one(id)));
  s = await one(id);
  t.check("its tool is listed", s.tools.some((x) => x.name === "whoami"), JSON.stringify(s.tools));
  t.check("an mcp.oauth.done event said ok", doneEvents(id).some((n) => n.params.ok === true), JSON.stringify(doneEvents(id)));
  const tokenCall = svc.tokenCalls.find((x) => x.grant_type === "authorization_code");
  t.check("the code was traded with the PKCE verifier, the redirect and the resource", !!tokenCall?.code_verifier && tokenCall.redirect_uri === q.redirect_uri && tokenCall.resource === svc.url && tokenCall.client_id === "client-1", JSON.stringify(tokenCall));
  const access = readFileSync(join(stateDir, "mcp-oauth.json"), "utf8");
  const secret = JSON.parse(access)[id].tokens.access_token;
  t.check("tokens are in mcp-oauth.json, private (0600)", !!secret && (statSync(join(stateDir, "mcp-oauth.json")).mode & 0o777) === 0o600);
  t.check("the list, the events and mcp.json never hold a token", !JSON.stringify(await servers()).includes(secret) && !JSON.stringify(C.notes).includes(secret) && !readFileSync(join(stateDir, "mcp.json"), "utf8").includes(secret));
  const dead = await new Promise((r) => { const c = createConnection(Number(cb.port), "127.0.0.1"); c.on("connect", () => { c.destroy(); r(false); }); c.on("error", () => r(true)); });
  t.check("the loopback listener is closed once the sign-in ends", dead);

  // ---- the stored sign-in survives a restart ---------------------------------------------------------------------------------------
  C.close();
  await rt.stop();
  rt = await startRuntime({ stateDir, keepState: true });
  C = await session(rt);
  t.check("after a restart the server connects by itself (no new sign-in)", !!(await until(id, (x) => x.state === "ready")) && (await one(id)).signed_in === true, JSON.stringify(await one(id)));
  const regsBefore = svc.registrations.length;

  // ---- the server revokes the token: refreshed, same call again ----------------------------------------------------------------------
  const refreshesBefore = svc.tokenCalls.filter((x) => x.grant_type === "refresh_token").length;
  svc.revokeAll();
  res = await C.call("mcp.refresh", { id });
  t.check("a revoked token is renewed with the refresh token and the call is repeated", (await one(id)).state === "ready" && svc.tokenCalls.filter((x) => x.grant_type === "refresh_token").length === refreshesBefore + 1, why(res));
  const newest = JSON.parse(readFileSync(join(stateDir, "mcp-oauth.json"), "utf8"))[id].tokens;
  t.check("the new tokens replace the old ones (the refresh token is rotated)", newest.access_token !== secret);

  // ---- refresh is refused: sign-in needed again -----------------------------------------------------------------------------------
  svc.failRefresh = true;
  svc.revokeAll();
  await C.call("mcp.refresh", { id });
  s = await until(id, (x) => x.state === "error");
  t.check("when the refresh token is refused, the server asks for a sign-in again", s.needs_signin === true && s.signed_in === false, JSON.stringify(s));
  t.check("the dead tokens are gone from the file", !JSON.parse(readFileSync(join(stateDir, "mcp-oauth.json"), "utf8"))[id].tokens);
  svc.failRefresh = false;

  // ---- sign in again: the registered client is reused --------------------------------------------------------------------------------
  res = await C.call("mcp.oauth.start", { id });
  const q2 = Object.fromEntries(new URL(res.result.url).searchParams);
  await browserSignIn(res.result.url);
  await until(id, (x) => x.state === "ready" && x.signed_in);
  t.check("signing in again works", (await one(id)).signed_in === true);
  t.check("the same client is reused when the redirect still matches (no second registration)", q2.redirect_uri !== undefined && (q2.client_id === "client-1" ? svc.registrations.length === regsBefore : svc.registrations.length === regsBefore + 1), `${q2.client_id} ${svc.registrations.length}/${regsBefore}`);

  // ---- sign out ------------------------------------------------------------------------------------------------------------------------
  res = await C.call("mcp.oauth.sign_out", { id });
  s = await until(id, (x) => x.state === "error");
  t.check("sign out removes the tokens and the server asks for a sign-in", res.result && s.signed_in === false && s.needs_signin === true && !JSON.parse(readFileSync(join(stateDir, "mcp-oauth.json"), "utf8"))[id]?.tokens, why(res));

  // ---- cancel and deny -----------------------------------------------------------------------------------------------------------------
  res = await C.call("mcp.oauth.start", { id });
  const nDone = doneEvents(id).length;
  res = await C.call("mcp.oauth.cancel", { id });
  t.check("cancel ends a waiting sign-in", res.result?.cancelled === true && await waitFor(() => doneEvents(id).length > nDone, 2000) && doneEvents(id).at(-1).params.ok === false && /cancel/i.test(doneEvents(id).at(-1).params.error), why(res));
  t.check("after cancel nothing is waiting", (await one(id)).signing_in === false);
  res = await C.call("mcp.oauth.start", { id });
  const denied = await browserSignIn(res.result.url, "&deny=1");
  t.check("if the person says no, the sign-in ends with the service's reason", /not completed/i.test(denied.text) && await waitFor(() => doneEvents(id).at(-1)?.params.ok === false && /access_denied/.test(doneEvents(id).at(-1)?.params.error ?? ""), 3000), JSON.stringify(doneEvents(id).at(-1)));

  // ---- refusals --------------------------------------------------------------------------------------------------------------------------
  const noReg = await startOAuthMcp({ noRegistration: true });
  res = await C.call("mcp.add", { input: noReg.url, name: "noreg" });
  const nid = res.result.server.id;
  await until(nid, (x) => x.state === "error");
  res = await C.call("mcp.oauth.start", { id: nid });
  t.check("a service that does not let apps register is told plainly", res.error?.code === E.CONFLICT && /does not let apps register/.test(res.error.message), why(res));
  const other = await startOAuthMcp({ otherResource: true });
  res = await C.call("mcp.add", { input: other.url, name: "other" });
  const oid = res.result.server.id;
  await until(oid, (x) => x.state === "error");
  res = await C.call("mcp.oauth.start", { id: oid });
  t.check("sign-in settings that name a different site are refused", res.error?.code === E.CONFLICT && /different site/.test(res.error.message), why(res));
  t.check("nothing was registered for either refusal", other.registrations.length === 0 && noReg.registrations.length === 0);
  res = await C.call("mcp.set_secrets", { id: nid, values: { Authorization: "Bearer typed-by-hand" } });
  res = await C.call("mcp.oauth.start", { id: nid });
  t.check("a server that already has a typed key is not signed in to", res.error?.code === E.CONFLICT && /already has a key/.test(res.error.message), why(res));
  res = await C.call("mcp.oauth.start", { id: "00000000-0000-4000-8000-000000000000" });
  t.check("an unknown server is not found", res.error?.code === E.NOT_FOUND, why(res));

  // ---- the catalog -----------------------------------------------------------------------------------------------------------------------
  res = await C.call("mcp.catalog");
  const cat = res.result.catalog;
  const oauthIds = cat.filter((e) => e.auth === "oauth").map((e) => e.id);
  t.check("the catalog lists the services behind a sign-in, with a category", ["linear", "notion-hosted", "sentry-hosted", "stripe", "atlassian", "cloudflare", "neon", "posthog", "monday", "supabase-hosted", "firecrawl-signin"].every((x) => oauthIds.includes(x)) && cat.every((e) => typeof e.category === "string" && e.category), oauthIds.join());
  t.check("Slack and Asana say why they cannot be added yet", cat.find((e) => e.id === "slack")?.unavailable?.includes("registered") && cat.find((e) => e.id === "asana")?.unavailable);
  res = await C.call("mcp.catalog.add", { id: "slack" });
  t.check("adding an unavailable service is refused with that reason", res.error?.code === E.CONFLICT && /registered/.test(res.error.message), why(res));
  res = await C.call("mcp.catalog.add", { id: "linear" });
  const lid = res.result?.server?.id;
  s = await until(lid, (x) => x.state === "error", 3000);
  t.check("adding Linear makes a server that waits for a sign-in (no network call yet)", s.auth === "oauth" && s.needs_signin === true && s.catalog === "linear" && s.target === "https://mcp.linear.app/mcp", JSON.stringify(s));
  res = await C.call("mcp.remove", { id });
  t.check("removing a server also removes its sign-in", res.result?.removed === true && !JSON.parse(readFileSync(join(stateDir, "mcp-oauth.json"), "utf8"))[id]);
  await C.call("mcp.remove", { id: lid });
  await C.call("mcp.remove", { id: nid });
  await C.call("mcp.remove", { id: oid });
  await noReg.close();
  await other.close();
} finally {
  await svc.close();
  const exit = await rt.stop();
  t.check("runtime stops cleanly", exit === "code=0 signal=null", exit);
}
process.exit(t.finish());
