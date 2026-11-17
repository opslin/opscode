// Makes native helpers usable regardless of how npm extracted them.
//
// node-pty@1.1.0 ships its macOS `spawn-helper` (used to launch shells inside
// a PTY) without the execute bit, and none of its install scripts fix that, so
// every terminal fails with "posix_spawnp failed". Run on postinstall and on
// every build so it never depends on install-script policy.

import { chmodSync, existsSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const helpers = ["darwin-arm64", "darwin-x64"].map((p) =>
  join(root, "node_modules/node-pty/prebuilds", p, "spawn-helper"),
);

for (const file of helpers) {
  if (!existsSync(file)) continue;
  const mode = statSync(file).mode & 0o777;
  if ((mode & 0o111) === 0o111) continue;
  chmodSync(file, 0o755);
  console.log(`ensure-native: made ${file.slice(root.length + 1)} executable (was ${mode.toString(8)})`);
}
