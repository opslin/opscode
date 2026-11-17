// Registers the privileged `opscode://` scheme and serves the renderer bundle
// from dist/renderer with a strict CSP, path-traversal containment, and
// anti-framing headers. Mirrors the researched app's asset server, rewritten.

import { protocol } from "electron";
import { readFile, stat } from "node:fs/promises";
import { extname, join, resolve, sep } from "node:path";
import { APP_HOST, APP_SCHEME } from "../shared/ipc";

const MIME: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".webp": "image/webp",
  ".ico": "image/x-icon",
  ".woff2": "font/woff2",
  ".woff": "font/woff",
  ".ttf": "font/ttf",
  ".txt": "text/plain; charset=utf-8",
};

/** Strict Content-Security-Policy for the first-party app origin. */
function contentSecurityPolicy(): string {
  return [
    "default-src 'self'",
    "script-src 'self'",
    // xterm.js injects a <style> element at runtime; styles only, scripts stay 'self'.
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob:",
    "font-src 'self'",
    // Loopback is allowed ahead of Phase 2 (local runtime over ws/http).
    "connect-src 'self' ws://127.0.0.1:* http://127.0.0.1:*",
    "media-src 'self' blob:",
    "worker-src 'self' blob:",
    "base-uri 'none'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ].join("; ");
}

/** Must be called before app `ready`. */
export function registerSchemePrivileges(): void {
  protocol.registerSchemesAsPrivileged([
    {
      scheme: APP_SCHEME,
      privileges: {
        standard: true,
        secure: true,
        supportFetchAPI: true,
        corsEnabled: true,
        stream: true,
      },
    },
  ]);
}

/** Registers the handler that serves dist/renderer. Call after app `ready`. */
export function serveAppScheme(rendererDir: string): void {
  const root = resolve(rendererDir);

  protocol.handle(APP_SCHEME, async (request) => {
    const url = new URL(request.url);
    if (url.host !== APP_HOST) return new Response(null, { status: 404 });
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response(null, { status: 405 });
    }

    let pathname: string;
    try {
      pathname = decodeURIComponent(url.pathname);
    } catch {
      return new Response(null, { status: 400 });
    }
    if (pathname.includes("\0")) return new Response(null, { status: 400 });

    // Contain every resolved path inside the renderer root.
    const assetPath = resolve(root, "." + pathname);
    if (assetPath !== root && !assetPath.startsWith(root + sep)) {
      return new Response(null, { status: 404 });
    }

    // SPA fallback: unknown non-file paths serve index.html.
    let filePath = assetPath;
    const info = await stat(assetPath).catch(() => null);
    if (!info?.isFile()) {
      const wantsHtml = request.headers.get("accept")?.includes("text/html") ?? false;
      if (extname(assetPath) !== "" && !wantsHtml) return new Response(null, { status: 404 });
      filePath = join(root, "index.html");
    }

    const body = await readFile(filePath).catch(() => null);
    if (body === null) return new Response(null, { status: 404 });

    return new Response(request.method === "HEAD" ? null : new Uint8Array(body), {
      headers: {
        "content-type": MIME[extname(filePath).toLowerCase()] ?? "application/octet-stream",
        "content-security-policy": contentSecurityPolicy(),
        "x-content-type-options": "nosniff",
        "x-frame-options": "DENY",
      },
    });
  });
}
