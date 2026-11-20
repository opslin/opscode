// Copies the static renderer assets into dist/ so the privileged scheme can
// serve them from one directory (mirrors how the shell serves its own origin).
import { cpSync, mkdirSync, copyFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
mkdirSync(resolve(root, "dist/renderer"), { recursive: true });
cpSync(resolve(root, "src/renderer"), resolve(root, "dist/renderer"), { recursive: true });
console.log("copied src/renderer -> dist/renderer");

// xterm.js is loaded as classic scripts from dist/renderer/vendor (CSP: 'self' only).
mkdirSync(resolve(root, "dist/renderer/vendor"), { recursive: true });
copyFileSync(resolve(root, "node_modules/@xterm/xterm/lib/xterm.js"), resolve(root, "dist/renderer/vendor/xterm.js"));
copyFileSync(resolve(root, "node_modules/@xterm/xterm/css/xterm.css"), resolve(root, "dist/renderer/vendor/xterm.css"));
copyFileSync(resolve(root, "node_modules/@xterm/addon-fit/lib/addon-fit.js"), resolve(root, "dist/renderer/vendor/addon-fit.js"));
console.log("copied xterm vendor files");

// Opscode's own pixel mascots (Chief pictures), served as dist/renderer/mascots/*.svg.
mkdirSync(resolve(root, "dist/renderer/mascots"), { recursive: true });
cpSync(resolve(root, "assets/brand/mascots/svg"), resolve(root, "dist/renderer/mascots"), { recursive: true });
copyFileSync(resolve(root, "assets/brand/mascots/mascots.json"), resolve(root, "dist/renderer/mascots/mascots.json"));
console.log("copied mascots");

// The Opscode mark (sidebar wordmark).
mkdirSync(resolve(root, "dist/renderer/brand"), { recursive: true });
copyFileSync(resolve(root, "assets/brand/logo/opscode-mark-128.png"), resolve(root, "dist/renderer/brand/opscode-mark-128.png"));
// The marks of the coding agents (Claude, Codex, Antigravity, Qoder), served as dist/renderer/brand/engines/*.svg.
cpSync(resolve(root, "assets/brand/engines"), resolve(root, "dist/renderer/brand/engines"), { recursive: true });
// The logos of the MCP servers and services in the Plugins page, served as dist/renderer/brand/integrations/*.svg.
cpSync(resolve(root, "assets/brand/integrations"), resolve(root, "dist/renderer/brand/integrations"), { recursive: true });
console.log("copied brand mark");
