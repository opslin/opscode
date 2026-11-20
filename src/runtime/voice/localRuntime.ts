import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { createInterface } from "node:readline";

function runtimePaths() {
  const root = join(__dirname, "..", "..", "..");
  const roots = [
    process.env.OPSCODE_LOCAL_VOICE_RUNTIME,
    join(root, "voice-runtime"),
    join(root, "out", "cache", "voice-runtime", `${process.platform}-${process.arch}`),
  ];
  for (const dir of roots) {
    if (!dir) continue;
    const python = join(dir, "python", process.platform === "win32" ? "python.exe" : "bin/python3.12");
    const script = join(dir, "worker.py");
    if (existsSync(python) && existsSync(script) && existsSync(join(dir, "packages"))) return { python, script };
  }
  return undefined;
}

export const localVoiceAvailable = (): boolean => !!runtimePaths();
export const LOCAL_VOICE_ERROR = "This build is missing the local voice runtime. Install a packaged Opscode build with local voice support.";

interface Request { resolve: (r: Record<string, unknown>) => void; reject: (e: Error) => void; timer: NodeJS.Timeout }

export class LocalVoiceWorker {
  private readonly proc: ChildProcessWithoutNullStreams;
  private request: Request | undefined;

  constructor(engine: "whisper" | "kitten", dir: string, cpuOnly = false) {
    const runtime = runtimePaths();
    if (!runtime) throw new Error(LOCAL_VOICE_ERROR);
    const proc = spawn(runtime.python, ["-I", "-B", "-u", runtime.script, engine, dir], {
      windowsHide: true,
      env: { ...process.env, ...(cpuOnly ? { OPSCODE_WHISPER_CPU: "1" } : {}), HF_HUB_OFFLINE: "1", TRANSFORMERS_OFFLINE: "1", PYTHONUTF8: "1" },
    });
    this.proc = proc;
    const lines = createInterface({ input: proc.stdout });
    lines.on("line", (line) => {
      try {
        const response = JSON.parse(line) as Record<string, unknown>;
        if (typeof response.error === "string") this.finish(new Error(response.error));
        else this.finish(undefined, response);
      } catch { this.finish(new Error("The local voice engine returned an invalid response")); }
    });
    // Libraries may write diagnostic logs or transcript fragments here. Drain without persisting them.
    proc.stderr.resume();
    proc.stdin.on("error", (e) => this.finish(e));
    proc.on("error", (e) => this.finish(e));
    proc.on("close", (code, signal) => this.finish(new Error(`The local ${engine} engine stopped (${signal ?? code})`)));
  }

  call(message: Record<string, unknown>, timeout = 45_000): Promise<Record<string, unknown>> {
    if (this.request) return Promise.reject(new Error("The local voice engine is busy"));
    if (!this.proc.stdin.writable) return Promise.reject(new Error("The local voice engine has stopped"));
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.finish(new Error("The local voice engine timed out"));
        this.close();
      }, timeout);
      this.request = { resolve, reject, timer };
      this.proc.stdin.write(JSON.stringify(message) + "\n");
    });
  }

  private finish(error?: Error, value: Record<string, unknown> = {}): void {
    const r = this.request;
    if (!r) return;
    this.request = undefined;
    clearTimeout(r.timer);
    if (error) r.reject(error);
    else r.resolve(value);
  }

  close(): void {
    this.finish(new Error("The local voice engine was closed"));
    this.proc.stdin.destroy();
    this.proc.kill();
  }
}
