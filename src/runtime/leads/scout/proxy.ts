// A tiny local forward proxy that Chrome is pointed at while it renders a page. A page's own scripts can ask
// the browser for any address, including private ones (a router, a cloud-metadata service). Routing every
// request through here applies the same rule as the plain fetcher: only public addresses are connected to,
// checked when the connection is made (so a DNS answer that changes between check and use cannot slip through).

import http from "node:http";
import net from "node:net";
import { lookup as dnsLookup } from "node:dns/promises";
import { isIP } from "node:net";
import { isPublicAddress } from "./net";

export interface ProxyOpts {
  /** Test hook: maps a host:port to a local fixture. Production never sets it; a mapped target skips the address check. */
  rewrite?: (host: string, port: number) => { host: string; port: number } | undefined;
  idleMs?: number; maxConnections?: number;
}
export interface FilterProxy { port: number; blocked: string[]; requests: number; close(): Promise<void> }

const SAFE_PORTS = new Set([80, 443, 8080, 8443]);

async function target(host: string, port: number, o: ProxyOpts): Promise<{ host: string; port: number } | string> {
  const mapped = o.rewrite?.(host, port);
  if (mapped) return mapped;
  if (!SAFE_PORTS.has(port)) return `port ${port} is not allowed`;
  if (isIP(host) !== 0) return isPublicAddress(host) ? { host, port } : `${host} is not a public address`;
  try {
    const all = await dnsLookup(host, { all: true });
    const ok = all.find((a) => isPublicAddress(a.address));
    // Connect to the address we checked, not to the name again.
    return ok ? { host: ok.address, port } : `${host} resolves to a non-public address`;
  } catch { return `${host} did not resolve`; }
}

export async function startFilterProxy(o: ProxyOpts = {}): Promise<FilterProxy> {
  const state = { blocked: [] as string[], requests: 0 };
  const open = new Set<net.Socket>();
  const idle = o.idleMs ?? 30_000;
  const track = (s: net.Socket): void => { open.add(s); s.setTimeout(idle, () => s.destroy()); s.on("close", () => open.delete(s)); s.on("error", () => s.destroy()); };

  const server = http.createServer(async (req, res) => {
    state.requests++;
    let u: URL;
    try { u = new URL(req.url ?? ""); } catch { res.writeHead(400).end(); return; }
    if (u.protocol !== "http:") { res.writeHead(400).end(); return; }
    const to = await target(u.hostname.replace(/^\[|\]$/g, ""), Number(u.port || 80), o);
    if (typeof to === "string") { state.blocked.push(to); res.writeHead(403, { "content-type": "text/plain" }).end(`blocked: ${to}`); return; }
    const headers = { ...req.headers };
    delete headers["proxy-connection"];
    const up = http.request({ host: to.host, port: to.port, path: u.pathname + u.search, method: req.method, headers }, (r) => { res.writeHead(r.statusCode ?? 502, r.headers); r.pipe(res); });
    up.setTimeout(idle, () => up.destroy());
    up.on("error", () => { if (!res.headersSent) res.writeHead(502).end(); else res.destroy(); });
    req.pipe(up);
  });

  server.on("connect", async (req, client: net.Socket, head) => {
    state.requests++;
    track(client);
    if (open.size > (o.maxConnections ?? 64)) { client.end("HTTP/1.1 503 Busy\r\n\r\n"); return; }
    const m = /^(\[[^\]]+\]|[^:]+):(\d+)$/.exec(req.url ?? "");
    if (!m) { client.end("HTTP/1.1 400 Bad Request\r\n\r\n"); return; }
    const to = await target(m[1]!.replace(/^\[|\]$/g, ""), Number(m[2]), o);
    if (typeof to === "string") { state.blocked.push(to); client.end("HTTP/1.1 403 Forbidden\r\n\r\n"); return; }
    const up = net.connect(to.port, to.host, () => { client.write("HTTP/1.1 200 Connection Established\r\n\r\n"); if (head.length) up.write(head); up.pipe(client); client.pipe(up); });
    track(up);
    up.on("error", () => client.destroy());
  });
  server.on("connection", track);

  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  return {
    port: (server.address() as net.AddressInfo).port, blocked: state.blocked,
    get requests() { return state.requests; },
    close: () => new Promise<void>((r) => { for (const s of open) s.destroy(); server.close(() => r()); }),
  };
}
