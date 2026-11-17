// Builds the React islands: src/islands/index.tsx -> dist/renderer/islands.js (one ES module,
// React bundled in) and src/islands/islands.css -> dist/renderer/islands.css (Tailwind v4).
import { build } from "esbuild";
import { execFileSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const isl = resolve(root, "src/islands");
const aui = resolve(isl, "aui");
mkdirSync(resolve(root, "dist/renderer"), { recursive: true });

await build({
  entryPoints: [resolve(isl, "index.tsx")],
  outfile: resolve(root, "dist/renderer/islands.js"),
  bundle: true,
  format: "esm",
  platform: "browser",
  target: "chrome130",
  jsx: "automatic",
  minify: true,
  sourcemap: true,
  legalComments: "linked",
  define: { "process.env.NODE_ENV": '"production"' },
  alias: {
    "@/lib/utils": resolve(isl, "lib/utils.ts"),
    cn: resolve(isl, "lib/utils.ts"),
    "@/components/assistant-ui": resolve(aui, "components/assistant-ui"),
    "@/components/ui": resolve(aui, "ui"),
    "@/hooks": resolve(aui, "hooks"),
    "@/registry/new-york-v4/ui": resolve(aui, "ui"),
  },
  logLevel: "warning",
});
console.log("built dist/renderer/islands.js");

execFileSync(process.execPath, [resolve(root, "node_modules/@tailwindcss/cli/dist/index.mjs"), "-i", resolve(isl, "islands.css"), "-o", resolve(root, "dist/renderer/islands.css"), "--minify"], { cwd: isl, stdio: ["ignore", "ignore", "inherit"] });
console.log("built dist/renderer/islands.css");
