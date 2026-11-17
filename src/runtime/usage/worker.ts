// Runs in a worker thread: reads session logs so the runtime's event loop stays free.
import { parentPort, workerData } from "node:worker_threads";
import { scanClaude, scanCodex } from "./scan";
import type { FileSummary } from "./scan";

interface Job { path: string; kind: "claude" | "codex" }
const jobs = (workerData as { jobs: Job[] }).jobs;
(async () => {
  let done = 0;
  for (const j of jobs) {
    let summary: FileSummary | null = null;
    try { summary = j.kind === "claude" ? await scanClaude(j.path) : await scanCodex(j.path); } catch { /* unreadable file: skip it */ }
    parentPort?.postMessage({ type: "file", path: j.path, summary });
    if (++done % 10 === 0) parentPort?.postMessage({ type: "progress", done });
  }
  parentPort?.postMessage({ type: "done" });
})();
