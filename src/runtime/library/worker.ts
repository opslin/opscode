// Worker thread: walks and reads one app folder so the runtime stays responsive.
import { parentPort, workerData } from "node:worker_threads";
import { scanFolder } from "./scan";

const { root, known } = workerData as { root: string; known: [string, number, number][] };
const map = new Map(known.map(([p, s, m]) => [p, [s, m] as [number, number]]));
try {
  const r = scanFolder(root, map, (seen) => parentPort?.postMessage({ type: "progress", seen }));
  parentPort?.postMessage({ type: "done", result: r });
} catch (e) {
  parentPort?.postMessage({ type: "error", message: e instanceof Error ? e.message : String(e) });
}
