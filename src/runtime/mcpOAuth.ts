// Browser sign-in (OAuth 2.1) for MCP servers that sit behind a login: Linear, Notion, Sentry, Stripe, Atlassian...
// Follows the public MCP authorization spec:
//   1. the server answers 401 with a pointer to its "protected resource metadata" (RFC 9728)
//   2. that names an authorization server, whose metadata (RFC 8414 / OpenID) gives the endpoints
//   3. Opscode registers itself as a client (RFC 7591, dynamic registration, no secret needed)
//   4. the person signs in in their own browser (authorization code + PKCE S256, loopback redirect, RFC 8252)
//   5. the code is traded for tokens (with the "resource" parameter, RFC 8707); tokens are refreshed when they run out
// Tokens live only in mcp-oauth.json (0600) and never leave the runtime: lists show "signed in" and nothing more.

import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import { createServer, type Server } from "node:http";
import { isIP } from "node:net";
import { join } from "node:path";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "./jsonFile";
import { isRecord } from "./rpc";

const FLOW_TIMEOUT_MS = 5 * 60 * 1000;
const HTTP_TIMEOUT_MS = 15_000;
const MAX_BODY = 1024 * 1024;
const MAX_SCOPES = 60;
const CLIENT_NAME = "Opscode";
/** A token this close to its end is refreshed first. */
const SKEW_MS = 60_000;

/** The server wants a sign-in and this computer has no (working) one. */
export class SignInRequired extends Error {
  constructor(readonly www?: string) { super("401 Unauthorized: sign-in required"); this.name = "SignInRequired"; }
}
/** Something the person can read: the sign-in cannot continue (and why). */
export class OAuthFailed extends Error {
  constructor(message: string, readonly code = "failed") { super(message); this.name = "OAuthFailed"; }
}

interface Tokens { access_token: string; refresh_token?: string; expires_at?: number; scope?: string }
interface Client { client_id: string; client_secret?: string; redirect_uri: string; auth_method: "none" | "client_secret_post" | "client_secret_basic"; expires_at?: number }
interface Record_ {
  server_url: string;
  resource: string;
  issuer: string;
  authorization_endpoint: string;
  token_endpoint: string;
  registration_endpoint?: string;
  client?: Client;
  port?: number;
  scope?: string;
  tokens?: Tokens;
  signed_in_at?: string;
}
interface Flow { server: Server; state: string; cancel(reason: string): void; done: Promise<void> }

type FetchLike = (url: string, init?: { method?: string; headers?: Record<string, string>; body?: string; signal?: AbortSignal; redirect?: "error" | "manual" | "follow" }) => Promise<{ ok: boolean; status: number; headers: { get(n: string): string | null }; text(): Promise<string> }>;

const b64url = (b: Buffer): string => b.toString("base64url");
const isLoopbackHost = (h: string): boolean => h === "localhost" || h === "127.0.0.1" || h === "[::1]" || h === "::1";

/** Private, link-local and loopback addresses: an authorization server on one is refused unless the MCP server itself is local. */
function privateHost(host: string): boolean {
  const h = host.replace(/^\[|\]$/g, "");
  if (isLoopbackHost(host) || h === "0.0.0.0") return true;
  if (isIP(h) === 4) { const [a, b] = h.split(".").map(Number); return a === 10 || a === 127 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || a === 0; }
  if (isIP(h) === 6) return /^(fc|fd|fe80|::1)/i.test(h);
  return h.endsWith(".local") || h.endsWith(".internal") || h === "metadata.google.internal";
}

/** Every address we send the person's data to must be https (loopback http only when the MCP server is itself on this computer). */
export function checkEndpoint(raw: unknown, what: string, localOk: boolean): string {
  if (typeof raw !== "string") throw new OAuthFailed(`The server's sign-in settings have no ${what}.`, "bad_metadata");
  let u: URL;
  try { u = new URL(raw); } catch { throw new OAuthFailed(`The server's ${what} is not a valid address.`, "bad_metadata"); }
  if (u.username || u.password) throw new OAuthFailed(`The server's ${what} contains a password.`, "bad_metadata");
  const local = isLoopbackHost(u.hostname);
  if (u.protocol !== "https:" && !(u.protocol === "http:" && local && localOk)) throw new OAuthFailed(`Refusing to send sign-in data to a non-https ${what}.`, "insecure");
  if (privateHost(u.hostname) && !localOk) throw new OAuthFailed(`The server's ${what} points at a private address.`, "private_address");
  return u.toString();
}

/** The parameters of a WWW-Authenticate: Bearer challenge. */
export function parseChallenge(header: string | null | undefined): Record<string, string> {
  const out: Record<string, string> = {};
  if (!header) return out;
  for (const m of header.matchAll(/([A-Za-z_][A-Za-z0-9_-]*)=(?:"([^"]*)"|([^\s,]+))/g)) out[m[1].toLowerCase()] = m[2] ?? m[3];
  return out;
}

/** "https://h/p" + "/.well-known/x" -> "https://h/.well-known/x/p" (path inserted, as RFC 8414 and 9728 say). */
const wellKnown = (base: string, name: string): string => { const u = new URL(base); const path = u.pathname === "/" ? "" : u.pathname.replace(/\/+$/, ""); return `${u.origin}/.well-known/${name}${path}`; };

export interface OAuthHooks {
  /** A flow ended: ok, or the reason it did not. */
  done(id: string, ok: boolean, error?: string): void;
  log(line: string): void;
}

export class McpOAuth {
  private readonly file: string;
  private data: Record<string, Record_>;
  private readonly flows = new Map<string, Flow>();
  private readonly refreshing = new Map<string, Promise<string | undefined>>();

  constructor(stateDir: string, private readonly hooks: OAuthHooks, private readonly fetchImpl: FetchLike = (u, i) => fetch(u, i) as ReturnType<FetchLike>, private readonly now: () => number = Date.now) {
    ensurePrivateDir(stateDir);
    this.file = join(stateDir, "mcp-oauth.json");
    const raw = readJson(this.file);
    this.data = {};
    if (isRecord(raw)) for (const [id, r] of Object.entries(raw)) if (isRecord(r) && typeof r.server_url === "string" && typeof r.token_endpoint === "string" && typeof r.authorization_endpoint === "string") this.data[id] = r as unknown as Record_;
  }

  private save(): void { writeJsonAtomic(this.file, this.data); }

  status(id: string, serverUrl?: string): { signed_in: boolean; signing_in: boolean; expires_at?: string } {
    const r = this.data[id];
    const ok = !!r?.tokens && (!serverUrl || sameOrigin(r.server_url, serverUrl));
    return { signed_in: ok, signing_in: this.flows.has(id), ...(ok && r.tokens?.expires_at ? { expires_at: new Date(r.tokens.expires_at).toISOString() } : {}) };
  }

  has(id: string): boolean { return !!this.data[id]?.tokens; }

  // ---- tokens -------------------------------------------------------------------------------------------------------------

  /** A token that works now, refreshed first when it is about to end. Undefined = not signed in. */
  async accessToken(id: string, serverUrl: string): Promise<string | undefined> {
    const r = this.data[id];
    if (!r?.tokens || !sameOrigin(r.server_url, serverUrl)) return undefined;
    if (!r.tokens.expires_at || r.tokens.expires_at - this.now() > SKEW_MS) return r.tokens.access_token;
    return this.refresh(id);
  }

  /** The server said 401 to the token we have: try the refresh token once. Undefined = signed out now. */
  refresh(id: string): Promise<string | undefined> {
    const running = this.refreshing.get(id);
    if (running) return running;
    const p = this.doRefresh(id).finally(() => this.refreshing.delete(id));
    this.refreshing.set(id, p);
    return p;
  }

  private async doRefresh(id: string): Promise<string | undefined> {
    const r = this.data[id];
    if (!r?.tokens?.refresh_token || !r.client) { if (r?.tokens) { delete r.tokens; this.save(); } return undefined; }
    try {
      const body = new URLSearchParams({ grant_type: "refresh_token", refresh_token: r.tokens.refresh_token, client_id: r.client.client_id, resource: r.resource });
      const t = await this.tokenRequest(r, body, localServer(r.server_url));
      r.tokens = { ...t, refresh_token: t.refresh_token ?? r.tokens.refresh_token };
      this.save();
      return r.tokens.access_token;
    } catch (e) {
      // invalid_grant = the refresh token is no longer good: sign-in is needed again. A network blip keeps the tokens.
      if (e instanceof OAuthFailed && e.code === "invalid_grant") { delete r.tokens; this.save(); this.hooks.log(`mcp oauth: refresh for ${id} was refused, sign-in needed again`); }
      else this.hooks.log(`mcp oauth: refresh for ${id} failed: ${e instanceof Error ? e.message : e}`);
      return undefined;
    }
  }

  signOut(id: string): boolean {
    this.cancel(id);
    if (!this.data[id]) return false;
    delete this.data[id].tokens;
    delete this.data[id].signed_in_at;
    this.save();
    return true;
  }

  /** The server was removed. */
  forget(id: string): void { this.cancel(id); if (this.data[id]) { delete this.data[id]; this.save(); } }

  cancel(id: string): boolean {
    const f = this.flows.get(id);
    if (!f) return false;
    f.cancel("Sign-in was cancelled.");
    return true;
  }

  closeAll(): void { for (const f of [...this.flows.values()]) f.cancel("closed"); }

  // ---- discovery ------------------------------------------------------------------------------------------------------------

  private async getJson(url: string, localOk: boolean): Promise<Record<string, unknown>> {
    checkEndpoint(url, "address", localOk);
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), HTTP_TIMEOUT_MS);
    try {
      const res = await this.fetchImpl(url, { headers: { accept: "application/json" }, signal: ctl.signal, redirect: "error" });
      if (!res.ok) throw new OAuthFailed(`${new URL(url).host} answered ${res.status}.`, "bad_metadata");
      const text = await res.text();
      if (text.length > MAX_BODY) throw new OAuthFailed("The sign-in settings were too large.", "bad_metadata");
      const j = JSON.parse(text);
      if (!isRecord(j)) throw new OAuthFailed("The sign-in settings were not readable.", "bad_metadata");
      return j;
    } catch (e) {
      if (e instanceof OAuthFailed) throw e;
      throw new OAuthFailed(`Could not read the server's sign-in settings (${e instanceof Error ? e.message : String(e)}).`, "bad_metadata");
    } finally { clearTimeout(timer); }
  }

  /** What the server and its authorization server say about signing in. */
  async discover(serverUrl: string, www?: string): Promise<{ resource: string; issuer: string; authorization_endpoint: string; token_endpoint: string; registration_endpoint?: string; scope?: string; methods: string[]; pkce?: string[] }> {
    const local = localServer(serverUrl);
    let challenge = parseChallenge(www);
    if (!www) {
      // Ask the server itself: an unauthenticated call is answered 401 with where its sign-in settings are.
      try {
        const res = await this.fetchImpl(serverUrl, { method: "POST", headers: { "content-type": "application/json", accept: "application/json, text/event-stream" }, body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-03-26", capabilities: {}, clientInfo: { name: "opscode", version: "0.0.1" } } }), signal: AbortSignal.timeout(HTTP_TIMEOUT_MS), redirect: "error" });
        if (res.status === 401) challenge = parseChallenge(res.headers.get("www-authenticate"));
        else if (res.ok) throw new OAuthFailed("This server does not ask for a sign-in.", "no_signin");
      } catch (e) { if (e instanceof OAuthFailed) throw e; /* then the well-known address is tried */ }
    }
    const prUrl = challenge.resource_metadata ? checkEndpoint(challenge.resource_metadata, "sign-in settings address", local) : wellKnown(serverUrl, "oauth-protected-resource");
    let pr: Record<string, unknown> | undefined;
    try { pr = await this.getJson(prUrl, local); } catch (e) {
      if (challenge.resource_metadata) throw e;
      try { pr = await this.getJson(`${new URL(serverUrl).origin}/.well-known/oauth-protected-resource`, local); } catch { /* the server itself may be its authorization server */ }
    }
    const resource = typeof pr?.resource === "string" ? pr.resource : serverUrl;
    // The resource must be this server (or a parent of it): a server cannot point us at someone else's token audience.
    if (!sameOrigin(resource, serverUrl)) throw new OAuthFailed("The server's sign-in settings name a different site than the one you connected to.", "bad_metadata");
    const issuerUrl = Array.isArray(pr?.authorization_servers) && typeof pr.authorization_servers[0] === "string" ? pr.authorization_servers[0] : new URL(serverUrl).origin;
    checkEndpoint(issuerUrl, "authorization server", local);
    const meta = await this.authServerMeta(issuerUrl, local);
    const authorization_endpoint = checkEndpoint(meta.authorization_endpoint, "authorization address", local);
    const token_endpoint = checkEndpoint(meta.token_endpoint, "token address", local);
    const registration_endpoint = typeof meta.registration_endpoint === "string" ? checkEndpoint(meta.registration_endpoint, "registration address", local) : undefined;
    const pkce = Array.isArray(meta.code_challenge_methods_supported) ? meta.code_challenge_methods_supported.map(String) : undefined;
    if (pkce && !pkce.includes("S256")) throw new OAuthFailed("This server's sign-in does not support the safe (S256) method Opscode needs.", "no_pkce");
    const supported = Array.isArray(pr?.scopes_supported) ? pr.scopes_supported.filter((s): s is string => typeof s === "string") : [];
    const scope = challenge.scope || (supported.length > 0 && supported.length <= MAX_SCOPES ? supported.join(" ") : undefined);
    const methods = Array.isArray(meta.token_endpoint_auth_methods_supported) ? meta.token_endpoint_auth_methods_supported.map(String) : ["client_secret_basic"];
    return { resource, issuer: typeof meta.issuer === "string" ? meta.issuer : issuerUrl, authorization_endpoint, token_endpoint, ...(registration_endpoint ? { registration_endpoint } : {}), ...(scope ? { scope } : {}), methods, ...(pkce ? { pkce } : {}) };
  }

  private async authServerMeta(issuer: string, local: boolean): Promise<Record<string, unknown>> {
    const u = new URL(issuer);
    const path = u.pathname === "/" ? "" : u.pathname.replace(/\/+$/, "");
    const tries = [`${u.origin}/.well-known/oauth-authorization-server${path}`, `${u.origin}/.well-known/openid-configuration${path}`, `${issuer.replace(/\/+$/, "")}/.well-known/openid-configuration`];
    let last: unknown;
    for (const t of tries) {
      try { return await this.getJson(t, local); } catch (e) { last = e; }
    }
    // Servers that publish nothing use the plain defaults.
    if (!path) return { issuer, authorization_endpoint: `${u.origin}/authorize`, token_endpoint: `${u.origin}/token`, registration_endpoint: `${u.origin}/register` };
    throw last instanceof Error ? last : new OAuthFailed("Could not read the authorization server's settings.", "bad_metadata");
  }

  // ---- registration -----------------------------------------------------------------------------------------------------------

  private async register(endpoint: string, redirect: string, methods: string[], scope: string | undefined, local: boolean): Promise<Client> {
    const method = methods.includes("none") ? "none" : methods.includes("client_secret_post") ? "client_secret_post" : "client_secret_basic";
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), HTTP_TIMEOUT_MS);
    try {
      checkEndpoint(endpoint, "registration address", local);
      const res = await this.fetchImpl(endpoint, { method: "POST", headers: { "content-type": "application/json", accept: "application/json" }, body: JSON.stringify({ client_name: CLIENT_NAME, redirect_uris: [redirect], grant_types: ["authorization_code", "refresh_token"], response_types: ["code"], token_endpoint_auth_method: method, application_type: "native", ...(scope ? { scope } : {}) }), signal: ctl.signal, redirect: "error" });
      const text = (await res.text()).slice(0, MAX_BODY);
      if (!res.ok) throw new OAuthFailed(`${new URL(endpoint).host} did not let Opscode register (${res.status}). Some services only allow apps they have approved.`, "registration_refused");
      const j = JSON.parse(text) as Record<string, unknown>;
      if (typeof j.client_id !== "string" || !j.client_id) throw new OAuthFailed("The server's registration answer had no client id.", "registration_refused");
      const given = typeof j.token_endpoint_auth_method === "string" ? j.token_endpoint_auth_method : method;
      return { client_id: j.client_id, ...(typeof j.client_secret === "string" ? { client_secret: j.client_secret } : {}), redirect_uri: redirect, auth_method: given === "client_secret_post" || given === "client_secret_basic" ? given : "none", ...(typeof j.client_secret_expires_at === "number" && j.client_secret_expires_at > 0 ? { expires_at: j.client_secret_expires_at * 1000 } : {}) };
    } catch (e) {
      if (e instanceof OAuthFailed) throw e;
      throw new OAuthFailed(`Could not register with the server (${e instanceof Error ? e.message : String(e)}).`, "registration_refused");
    } finally { clearTimeout(timer); }
  }

  // ---- the sign-in -----------------------------------------------------------------------------------------------------------

  /**
   * Starts a sign-in: finds the settings, registers if needed, starts the loopback listener and returns the address to open in the
   * browser. The flow then waits (up to five minutes) for the browser to come back; `hooks.done` says how it ended.
   */
  async start(id: string, serverUrl: string, opts: { www?: string; scope?: string } = {}): Promise<{ url: string }> {
    if (this.flows.has(id)) this.cancel(id);
    const local = localServer(serverUrl);
    const d = await this.discover(serverUrl, opts.www);
    const prev = this.data[id];
    const reuse = prev && prev.issuer === d.issuer && prev.client && (!prev.client.expires_at || prev.client.expires_at > this.now() + 60_000) ? prev : undefined;

    // The loopback listener first (a registered redirect must match the port we really got).
    const state = b64url(randomBytes(24));
    const verifier = b64url(randomBytes(48));
    const challenge = b64url(createHash("sha256").update(verifier).digest());
    let resolveCode!: (c: { code: string }) => void;
    let rejectCode!: (e: Error) => void;
    const code = new Promise<{ code: string }>((res, rej) => { resolveCode = res; rejectCode = rej; });
    code.catch(() => undefined);
    const server = createServer((req, res) => {
      const u = new URL(req.url ?? "/", "http://127.0.0.1");
      const hostOk = /^(127\.0\.0\.1|localhost)(:\d+)?$/i.test(req.headers.host ?? "");
      if (!hostOk || u.pathname !== "/callback" || req.method !== "GET") { res.writeHead(404).end(); return; }
      const page = (title: string, text: string): void => { res.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "referrer-policy": "no-referrer", "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'" }).end(`<!doctype html><meta charset="utf-8"><title>${title}</title><body style="font:16px system-ui;margin:12vh auto;max-width:28em;padding:0 1em"><h2>${title}</h2><p>${text}</p></body>`); };
      const got = u.searchParams.get("state") ?? "";
      const a = Buffer.from(got), b = Buffer.from(state);
      if (a.length !== b.length || !timingSafeEqual(a, b)) { page("Sign-in did not match", "This page was not opened by the sign-in that Opscode started. You can close it."); return; }
      const err = u.searchParams.get("error");
      if (err) { page("Sign-in was not completed", "You can close this tab and try again in Opscode."); rejectCode(new OAuthFailed(`The service said: ${err.slice(0, 80)}${u.searchParams.get("error_description") ? ` — ${u.searchParams.get("error_description")!.slice(0, 160)}` : ""}`, "denied")); return; }
      const c = u.searchParams.get("code");
      if (!c) { page("Sign-in did not finish", "No code came back. You can close this tab and try again."); return; }
      page("You are signed in", "You can close this tab and go back to Opscode.");
      resolveCode({ code: c });
    });
    const listen = (port: number): Promise<number> => new Promise((res, rej) => { server.once("error", rej); server.listen(port, "127.0.0.1", () => { server.off("error", rej); res((server.address() as { port: number }).port); }); });
    let port: number;
    try { port = await listen(reuse?.port ?? 0); } catch { port = await listen(0); }
    const redirect = `http://127.0.0.1:${port}/callback`;
    const cleanup = (): void => { try { server.close(); server.closeAllConnections?.(); } catch { /* closed */ } };

    try {
      let client = reuse?.client && reuse.client.redirect_uri === redirect ? reuse.client : undefined;
      if (!client) {
        if (!d.registration_endpoint) throw new OAuthFailed("This service does not let apps register themselves, so Opscode cannot sign in to it yet.", "no_registration");
        client = await this.register(d.registration_endpoint, redirect, d.methods, opts.scope ?? d.scope, local);
      }
      const scope = opts.scope ?? d.scope;
      const rec: Record_ = { server_url: serverUrl, resource: d.resource, issuer: d.issuer, authorization_endpoint: d.authorization_endpoint, token_endpoint: d.token_endpoint, ...(d.registration_endpoint ? { registration_endpoint: d.registration_endpoint } : {}), client, port, ...(scope ? { scope } : {}), ...(prev?.tokens ? { tokens: prev.tokens } : {}) };
      const authUrl = new URL(d.authorization_endpoint);
      for (const [k, v] of Object.entries({ response_type: "code", client_id: client.client_id, redirect_uri: redirect, code_challenge: challenge, code_challenge_method: "S256", state, resource: d.resource, ...(scope ? { scope } : {}) })) authUrl.searchParams.set(k, v);

      let cancelled: ((r: string) => void) | undefined;
      const aborted = new Promise<never>((_, rej) => { cancelled = (reason) => rej(new OAuthFailed(reason, "cancelled")); });
      aborted.catch(() => undefined);
      const timer = setTimeout(() => cancelled?.("The sign-in took too long and was stopped. Try again."), FLOW_TIMEOUT_MS);
      timer.unref?.();
      const done = (async (): Promise<void> => {
        try {
          const { code: authCode } = await Promise.race([code, aborted]);
          const body = new URLSearchParams({ grant_type: "authorization_code", code: authCode, redirect_uri: redirect, client_id: client!.client_id, code_verifier: verifier, resource: d.resource });
          const tokens = await Promise.race([this.tokenRequest(rec, body, local), aborted]);
          rec.tokens = tokens;
          rec.signed_in_at = new Date(this.now()).toISOString();
          this.data[id] = rec;
          this.save();
          this.hooks.log(`mcp oauth: signed in to ${new URL(serverUrl).host}`);
          this.finish(id, true);
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          this.finish(id, false, msg);
        } finally { clearTimeout(timer); cleanup(); }
      })();
      this.flows.set(id, { server, state, cancel: (r) => { cancelled?.(r); rejectCode(new OAuthFailed(r, "cancelled")); }, done });
      return { url: authUrl.toString() };
    } catch (e) {
      cleanup();
      throw e;
    }
  }

  private finish(id: string, ok: boolean, error?: string): void {
    this.flows.delete(id);
    this.hooks.done(id, ok, error);
  }

  /** Waits for a running sign-in to end (tests and callers that need to know). */
  async whenDone(id: string): Promise<void> { await this.flows.get(id)?.done; }

  // ---- token endpoint -------------------------------------------------------------------------------------------------------

  private async tokenRequest(r: Record_, body: URLSearchParams, local: boolean): Promise<Tokens> {
    const headers: Record<string, string> = { "content-type": "application/x-www-form-urlencoded", accept: "application/json" };
    const c = r.client;
    if (c?.auth_method === "client_secret_basic" && c.client_secret) headers.authorization = `Basic ${Buffer.from(`${encodeURIComponent(c.client_id)}:${encodeURIComponent(c.client_secret)}`).toString("base64")}`;
    else if (c?.auth_method === "client_secret_post" && c.client_secret) body.set("client_secret", c.client_secret);
    checkEndpoint(r.token_endpoint, "token address", local);
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), HTTP_TIMEOUT_MS);
    try {
      const res = await this.fetchImpl(r.token_endpoint, { method: "POST", headers, body: body.toString(), signal: ctl.signal, redirect: "error" });
      const text = (await res.text()).slice(0, MAX_BODY);
      let j: Record<string, unknown> = {};
      try { const x = JSON.parse(text); if (isRecord(x)) j = x; } catch { /* below */ }
      if (!res.ok) {
        const code = typeof j.error === "string" ? j.error : "";
        throw new OAuthFailed(`The service refused the sign-in (${res.status}${code ? `: ${code.slice(0, 60)}` : ""}).`, code === "invalid_grant" ? "invalid_grant" : "token_refused");
      }
      if (typeof j.access_token !== "string" || !j.access_token) throw new OAuthFailed("The service did not send an access token.", "token_refused");
      if (typeof j.token_type === "string" && j.token_type.toLowerCase() !== "bearer") throw new OAuthFailed("The service sent a token type Opscode does not use.", "token_refused");
      const expires = typeof j.expires_in === "number" && j.expires_in > 0 ? this.now() + j.expires_in * 1000 : typeof j.expires_in === "string" && Number(j.expires_in) > 0 ? this.now() + Number(j.expires_in) * 1000 : undefined;
      return { access_token: j.access_token, ...(typeof j.refresh_token === "string" ? { refresh_token: j.refresh_token } : {}), ...(expires ? { expires_at: expires } : {}), ...(typeof j.scope === "string" ? { scope: j.scope } : {}) };
    } catch (e) {
      if (e instanceof OAuthFailed) throw e;
      throw new OAuthFailed(`Could not reach the service to finish signing in (${e instanceof Error ? e.message : String(e)}).`, "network");
    } finally { clearTimeout(timer); }
  }
}

function sameOrigin(a: string, b: string): boolean { try { return new URL(a).origin === new URL(b).origin; } catch { return false; } }
function localServer(url: string): boolean { try { return isLoopbackHost(new URL(url).hostname); } catch { return false; } }
