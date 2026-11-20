// Rendering for sites that build their content in the browser. Uses a Chrome/Chromium/Edge already installed on
// this machine (nothing is downloaded), headless, with a throw-away profile, pointed at the filtering proxy so the
// page's scripts can only reach public addresses. Used only when the plain page looks empty.

import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ParsedPage } from "./html";
import { startFilterProxy } from "./proxy";
import type { ProxyOpts } from "./proxy";
import { USER_AGENT } from "./net";

const CANDIDATES: Record<string, string[]> = {
  darwin: ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", "/Applications/Chromium.app/Contents/MacOS/Chromium", "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge", "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"],
  win32: ["C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe", "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe", "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe", "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe"],
  linux: ["/usr/bin/google-chrome", "/usr/bin/google-chrome-stable", "/usr/bin/chromium", "/usr/bin/chromium-browser", "/snap/bin/chromium", "/usr/bin/microsoft-edge"],
};

/** The browser to render with: OPSCODE_CHROME if set, else the first one installed. Undefined when there is none. */
export function findChrome(): string | undefined {
  const env = process.env.OPSCODE_CHROME;
  if (env) return existsSync(env) ? env : undefined;
  return (CANDIDATES[process.platform] ?? CANDIDATES.linux!).find((p) => existsSync(p));
}

/**
 * Does this page look like an empty shell that a browser would fill in? Little visible text, plus either a typical
 * app mount point or several scripts. A short but real page (a one-line landing page with no scripts) is left alone.
 */
export function needsRender(p: ParsedPage, rawHtml: string): boolean {
  if (p.text.length >= 400) return false;
  // A mount point can be any tag (a <section id="root"> is common), and a module script on a nearly empty page is an app.
  const mount = /<[a-z][a-z0-9]*\b[^>]*\bid=["'](root|app|__next|__nuxt|svelte|q-app)["']/i.test(rawHtml) || /__NUXT__|window\.__INITIAL_STATE__|data-reactroot/i.test(rawHtml);
  const scripts = (rawHtml.match(/<script\b/gi) ?? []).length;
  const askForJs = /enable javascript|requires javascript|you need to enable javascript/i.test(rawHtml);
  return mount || askForJs || scripts >= 3 || (p.text.length < 150 && scripts >= 1);
}

export interface RenderOpts { chrome: string; timeoutMs?: number; maxBytes?: number; proxy?: ProxyOpts; onBlocked?: (hosts: string[]) => void }

/** The page's HTML after its scripts ran. Throws with a readable message on failure; always cleans up the browser, its profile and the proxy. */
export async function renderPage(url: string, o: RenderOpts): Promise<string> {
  const proxy = await startFilterProxy(o.proxy);
  const profile = mkdtempSync(join(tmpdir(), "opscode-render-"));
  const max = o.maxBytes ?? 3_000_000;
  try {
    const args = [
      "--headless", "--disable-gpu", "--disable-extensions", "--disable-sync", "--mute-audio", "--no-first-run", "--no-default-browser-check",
      "--disable-background-networking", "--disable-component-update", "--force-webrtc-ip-handling-policy=disable_non_proxied_udp",
      `--user-data-dir=${profile}`, `--proxy-server=http://127.0.0.1:${proxy.port}`, "--proxy-bypass-list=<-loopback>", `--user-agent=${USER_AGENT}`,
      "--virtual-time-budget=8000", "--dump-dom", url,
    ];
    const out = await new Promise<string>((resolve, reject) => {
      const child = spawn(o.chrome, args, { stdio: ["ignore", "pipe", "ignore"], detached: process.platform !== "win32" });
      // Chrome starts helper processes; on Unix the whole group is stopped, so none is left running.
      const kill = (): void => { try { if (process.platform !== "win32" && child.pid) process.kill(-child.pid, "SIGKILL"); else child.kill("SIGKILL"); } catch { /* already gone */ } };
      const chunks: Buffer[] = [];
      let size = 0;
      const timer = setTimeout(() => { kill(); reject(new Error("the browser did not finish in time")); }, o.timeoutMs ?? 30_000);
      child.stdout.on("data", (c: Buffer) => { size += c.length; if (size <= max) chunks.push(c); else kill(); });
      child.on("error", (e) => { clearTimeout(timer); reject(new Error(`could not start the browser: ${e.message}`)); });
      child.on("close", () => { clearTimeout(timer); kill(); resolve(Buffer.concat(chunks).toString("utf8")); });
    });
    if (!/<html[\s>]/i.test(out)) throw new Error("the browser returned no page");
    return out;
  } finally {
    o.onBlocked?.(proxy.blocked);
    await proxy.close();
    rmSync(profile, { recursive: true, force: true });
  }
}
