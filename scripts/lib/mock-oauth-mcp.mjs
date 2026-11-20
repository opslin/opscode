// A fake MCP server behind a browser sign-in, for tests: protected-resource and authorization-server metadata,
// dynamic client registration, authorization code + PKCE (S256), token + refresh, and a /mcp endpoint that wants a Bearer token.
// The "browser" is the test itself: it opens the authorize address and follows the redirect.
import { createHash, randomBytes } from "node:crypto";
import { createServer } from "node:http";

export async function startOAuthMcp(opts = {}) {
  const s = {
    expiresIn: opts.expiresIn ?? 3600,
    noRegistration: !!opts.noRegistration,
    otherResource: !!opts.otherResource,
    failRefresh: false,
    registrations: [],
    tokenCalls: [],
    mcpCalls: 0,
    authorizeCalls: [],
    codes: new Map(),
    access: new Set(),
    refresh: new Map(),
    clients: new Map(),
    port: 0,
    url: "",
    /** Makes every token we gave out stop working (the server restarted, or the person revoked it). */
    revokeAll() { s.access.clear(); },
    async close() { await new Promise((r) => { server.closeAllConnections?.(); server.close(r); }); },
  };
  const json = (res, code, body, headers = {}) => res.writeHead(code, { "content-type": "application/json", ...headers }).end(JSON.stringify(body));
  const server = createServer((req, res) => {
    let raw = "";
    req.on("data", (c) => (raw += c));
    req.on("end", () => {
      const u = new URL(req.url, `http://127.0.0.1:${s.port}`);
      const base = `http://127.0.0.1:${s.port}`;
      if (u.pathname === "/mcp" && req.method === "POST") {
        s.mcpCalls++;
        const tok = /^Bearer (.+)$/.exec(req.headers.authorization ?? "")?.[1];
        if (!tok || !s.access.has(tok)) return json(res, 401, { error: "unauthorized" }, { "www-authenticate": `Bearer realm="OAuth", resource_metadata="${base}/.well-known/oauth-protected-resource/mcp", scope="read write"` });
        const m = JSON.parse(raw || "{}");
        if (m.id === undefined) return res.writeHead(202).end();
        const result = m.method === "initialize" ? { protocolVersion: "2024-11-05", capabilities: {}, serverInfo: { name: "oauth-mock", version: "1" } }
          : m.method === "tools/list" ? { tools: [{ name: "whoami", description: "who is signed in", inputSchema: { type: "object", properties: {} } }] }
          : m.method === "tools/call" ? { content: [{ type: "text", text: `hello ${tok.slice(0, 6)}` }] } : {};
        return json(res, 200, { jsonrpc: "2.0", id: m.id, result });
      }
      if (u.pathname === "/.well-known/oauth-protected-resource/mcp") return json(res, 200, { resource: s.otherResource ? "https://evil.example/mcp" : `${base}/mcp`, authorization_servers: [base], scopes_supported: ["read", "write"] });
      if (u.pathname === "/.well-known/oauth-authorization-server") return json(res, 200, { issuer: base, authorization_endpoint: `${base}/authorize`, token_endpoint: `${base}/token`, ...(s.noRegistration ? {} : { registration_endpoint: `${base}/register` }), code_challenge_methods_supported: ["S256"], token_endpoint_auth_methods_supported: ["none"], grant_types_supported: ["authorization_code", "refresh_token"] });
      if (u.pathname === "/register" && req.method === "POST") {
        const b = JSON.parse(raw);
        s.registrations.push(b);
        const id = `client-${s.registrations.length}`;
        s.clients.set(id, b.redirect_uris);
        return json(res, 201, { client_id: id, redirect_uris: b.redirect_uris, token_endpoint_auth_method: "none" });
      }
      if (u.pathname === "/authorize") {
        const q = Object.fromEntries(u.searchParams);
        s.authorizeCalls.push(q);
        if (!s.clients.get(q.client_id)?.includes(q.redirect_uri)) return json(res, 400, { error: "invalid_redirect_uri" });
        if (q.code_challenge_method !== "S256" || !q.code_challenge) return json(res, 400, { error: "pkce_required" });
        if (q.deny) { return res.writeHead(302, { location: `${q.redirect_uri}?error=access_denied&state=${q.state}` }).end(); }
        const code = randomBytes(8).toString("hex");
        s.codes.set(code, { challenge: q.code_challenge, redirect: q.redirect_uri, client: q.client_id, resource: q.resource });
        return res.writeHead(302, { location: `${q.redirect_uri}?code=${code}&state=${q.state}` }).end();
      }
      if (u.pathname === "/token" && req.method === "POST") {
        const f = Object.fromEntries(new URLSearchParams(raw));
        s.tokenCalls.push(f);
        const issue = () => {
          const access = `at-${randomBytes(6).toString("hex")}`;
          const refresh = `rt-${randomBytes(6).toString("hex")}`;
          s.access.add(access);
          s.refresh.set(refresh, f.client_id);
          return json(res, 200, { access_token: access, token_type: "Bearer", expires_in: s.expiresIn, refresh_token: refresh, scope: "read write" });
        };
        if (f.grant_type === "authorization_code") {
          const c = s.codes.get(f.code);
          s.codes.delete(f.code);
          if (!c || c.redirect !== f.redirect_uri || c.client !== f.client_id) return json(res, 400, { error: "invalid_grant" });
          const ok = createHash("sha256").update(f.code_verifier ?? "").digest("base64url") === c.challenge;
          if (!ok) return json(res, 400, { error: "invalid_grant", error_description: "PKCE failed" });
          if (c.resource !== f.resource) return json(res, 400, { error: "invalid_target" });
          return issue();
        }
        if (f.grant_type === "refresh_token") {
          if (s.failRefresh || !s.refresh.has(f.refresh_token)) return json(res, 400, { error: "invalid_grant" });
          s.refresh.delete(f.refresh_token);
          return issue();
        }
        return json(res, 400, { error: "unsupported_grant_type" });
      }
      res.writeHead(404).end();
    });
  });
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  s.port = server.address().port;
  s.url = `http://127.0.0.1:${s.port}/mcp`;
  return s;
}

/** Plays the browser: opens the authorize address, follows its redirect to Opscode's loopback address, returns the page text. */
export async function browserSignIn(authUrl, extra = "") {
  const r = await fetch(authUrl + extra, { redirect: "manual" });
  const loc = r.headers.get("location");
  if (!loc) return { status: r.status, text: await r.text() };
  const back = await fetch(loc);
  return { status: back.status, text: await back.text(), location: loc };
}
