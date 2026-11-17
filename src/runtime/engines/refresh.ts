// Re-reading the coding agents (which are installed, their versions, the models they offer) takes seconds: each one is
// a program started and asked. This does it all at once, tells the windows about every step as it lands, and runs at most
// once at a time. The last answer is kept on disk (detect.ts), so a window opening later never starts from an empty list.

import type { EngineInfo, EngineSettings, EngineStore } from "./detect";

interface WithModels { models(): Promise<unknown> }

export class EngineRefresher {
  private flight: Promise<EngineInfo[]> | null = null;
  private lastDone = 0;

  constructor(
    private readonly store: EngineStore,
    private readonly agents: Record<"codex" | "antigravity" | "qoder", WithModels>,
    private readonly notify: (engines: EngineInfo[], settings: EngineSettings) => void,
    private readonly log: (line: string) => void = () => {},
  ) {}

  private push(list: EngineInfo[]): void {
    try { this.notify(list, this.store.settings()); } catch { /* no window to tell */ }
  }

  /** Everything again: versions, then each agent's models, all at the same time. Windows hear after every step. */
  refresh(): Promise<EngineInfo[]> {
    if (this.flight) return this.flight;
    const started = Date.now();
    this.flight = (async () => {
      const first = await this.store.list(true);
      this.push(first);
      await Promise.all((Object.keys(this.agents) as (keyof typeof this.agents)[]).map(async (id) => {
        if (!first.find((e) => e.id === id)?.found) return;
        try { await this.agents[id].models(); } catch (e) { this.log(`engines: could not read ${id} models: ${String(e)}`); }
        this.push(await this.store.list(false));
      }));
      const done = await this.store.list(false);
      this.lastDone = Date.now();
      this.log(`engines: read again in ${this.lastDone - started} ms`);
      return done;
    })().finally(() => { this.flight = null; });
    return this.flight;
  }

  /** In the background, when what is known is older than `maxAgeMs`. */
  revalidate(maxAgeMs = 5 * 60_000): void {
    if (this.flight || Date.now() - this.lastDone < maxAgeMs) return;
    void this.refresh().catch(() => undefined);
  }

  get busy(): boolean { return this.flight !== null; }
}
