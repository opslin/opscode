// File links in replies: paths an engine writes ([name](</abs/my file.xlsx>), [name](/abs/x.pdf), file://,
// project-relative, `/abs/path` in code, bare /abs/x.apk) become file links in every chat; web links stay
// web links; anything else stays text. Opening never runs programs or scripts (they are only shown in Finder).
import { chmodSync, mkdirSync, mkdtempSync, realpathSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { reporter } from "./lib/harness.mjs";
const t = reporter();

// A tiny DOM, enough for dom.js's h().
class Node {}
class El extends Node {
  constructor(tag) { super(); this.tag = tag; this.children = []; this.attrs = {}; this.dataset = {}; this.className = ""; }
  append(...c) { this.children.push(...c); }
  addEventListener() {}
  setAttribute(k, v) { this.attrs[k] = v; }
  get textContent() { return this.children.map((c) => (typeof c === "string" ? c : c.textContent)).join(""); }
}
globalThis.Node = Node;
globalThis.document = { createElement: (tag) => new El(tag) };
const M = await import(join(process.cwd(), "src/renderer/markdown.js"));
const all = (n, out = []) => { if (n instanceof El) { out.push(n); n.children.forEach((c) => all(c, out)); } return out; };
const files = (n) => all(n).filter((e) => e.tag === "a" && e.className.includes("op-file")).map((e) => ({ path: e.dataset.path, text: e.textContent, code: e.className.includes("op-file-code") }));
const webs = (n) => all(n).filter((e) => e.tag === "a" && !e.className.includes("op-file")).map((e) => e.attrs.href);
const md = (s, root) => M.renderMarkdown(s, root ? { root } : {});

const r1 = md("[Download the Excel file](</Users/me/Documents/Acme Laundry/outputs/pricing/acme-prices-import.xlsx>)");
t.check("a link with an <angle-bracket> path (spaces) becomes a file link with its label", JSON.stringify(files(r1)) === JSON.stringify([{ path: "/Users/me/Documents/Acme Laundry/outputs/pricing/acme-prices-import.xlsx", text: "Download the Excel file", code: false }]) && !r1.textContent.includes("]("), JSON.stringify(files(r1)) + " | " + r1.textContent);
t.check("[name](/abs/x.pdf) and file:// links", files(md("[Report](/tmp/r.pdf) and [APK](file:///Users/me/app%20release.apk)")).map((f) => f.path).join("|") === "/tmp/r.pdf|/Users/me/app release.apk");
t.check("a project-relative link resolves against the project folder", files(md("see [cart](src/cart.ts:12) and [doc](./docs/a.md)", "/p/shop")).map((f) => f.path).join("|") === "/p/shop/src/cart.ts:12|/p/shop/docs/a.md");
t.check("…but without a project folder it stays text", files(md("see [cart](src/cart.ts)")).length === 0 && md("see [cart](src/cart.ts)").textContent === "see cart");
t.check("a path in inline code is a file link (code look kept); spaces allowed", JSON.stringify(files(md("Saved to `/Users/me/My Docs/out.xlsx` and `~/x/y/`."))) === JSON.stringify([{ path: "/Users/me/My Docs/out.xlsx", text: "/Users/me/My Docs/out.xlsx", code: true }, { path: "~/x/y/", text: "~/x/y/", code: true }]));
t.check("ordinary inline code stays code", files(md("run `npm test` or `a/b`")).length === 0);
t.check("a bare /abs/path.ext in text is a file link", files(md("APK at /Users/me/build/app-release.apk, done.")).map((f) => f.path).join() === "/Users/me/build/app-release.apk");
t.check("URLs are not mistaken for file paths, and stay web links", files(md("see https://x.com/a/b.html and [docs](https://d.io/x.pdf)")).length === 0 && webs(md("[docs](https://d.io/x.pdf)")).join() === "https://d.io/x.pdf");
t.check("javascript:, mailto: and ../ links stay plain text", files(md("[a](javascript:alert(1)) [b](mailto:x@y.z) [c](../etc/passwd)", "/p")).length === 0 && webs(md("[a](javascript:alert(1)) [b](mailto:x@y.z)")).length === 0);
t.check("links work in lists and headings too", files(md("- [one](/a/1.pdf)\n- [two](/a/2.pdf)\n# [h](/a/h.md)")).length === 3);

// ---- main's path rules (no Electron needed for these) ---------------------------------------------------------
const F = await import(join(process.cwd(), "dist/main/fileLinks.js"));
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p36-")));
mkdirSync(join(base, "out"));
writeFileSync(join(base, "out", "prices.xlsx"), "x");
writeFileSync(join(base, "out", "a:b.txt"), "x");
writeFileSync(join(base, "run.sh"), "echo hi");
writeFileSync(join(base, "tool"), "x"); chmodSync(join(base, "tool"), 0o755);
writeFileSync(join(base, "helper.py"), "print(1)");
mkdirSync(join(base, "My.app"));
t.check("~/ expands, file:// and %20 decode, line suffixes drop, relative paths are refused", F.cleanPath("~/x") === join(homedir(), "x") && F.cleanPath(`file://${base}/out/prices%20x.xlsx`) === `${base}/out/prices x.xlsx` && F.cleanPath(`${base}/out/prices.xlsx:12`) === `${base}/out/prices.xlsx` && F.cleanPath("src/a.ts") === undefined && F.cleanPath("") === undefined);
t.check("a colon that is part of the real file name is kept", F.cleanPath(`${base}/out/a:b.txt`) === `${base}/out/a:b.txt`);
const i1 = F.fileInfo(`${base}/out/prices.xlsx`);
t.check("an Excel file exists and is safe to open", i1.exists && !i1.dir && !i1.runnable);
t.check("folders are folders", F.fileInfo(`${base}/out`).dir === true);
t.check("scripts, programs, app bundles and anything executable are 'runnable' (shown in Finder, never run)", ["run.sh", "tool", "helper.py", "My.app"].every((n) => F.fileInfo(join(base, n)).runnable), JSON.stringify(["run.sh", "tool", "helper.py", "My.app"].map((n) => F.fileInfo(join(base, n)).runnable)));
t.check("a missing file says so", F.fileInfo(`${base}/nope.pdf`).exists === false);
const inf = await F.fileAction("info", `${base}/out/prices.xlsx`);
t.check("info answers without opening anything", inf.ok && inf.exists && inf.path === `${base}/out/prices.xlsx`);
const bad = await F.fileAction("open", "relative/x.pdf");
t.check("open refuses a non-absolute path", !bad.ok && /Not a file path/.test(bad.error));
const gone = await F.fileAction("open", `${base}/gone.pdf`);
t.check("open of a missing file reports it (nothing opened)", !gone.ok && /not there/.test(gone.error));
process.exit(t.finish());
