// Provider configuration. API keys live only in the runtime's private state dir
// (providers.json, mode 0600) and are never sent to the renderer: the UI sees a
// "configured" flag and the last four characters.

import { join } from "node:path";
import type { ProviderId, ProviderInfo } from "../../shared/protocol";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "../jsonFile";
import { isRecord } from "../rpc";
import { validateBaseUrl, type LlmConfig } from "./llm";

const META: Record<ProviderId, { label: string; base: string; model: string }> = {
  anthropic: { label: "Anthropic", base: "https://api.anthropic.com", model: "claude-sonnet-5-5" },
  openai: { label: "OpenAI-compatible", base: "https://api.openai.com/v1", model: "" },
};
export const PROVIDER_IDS = Object.keys(META) as ProviderId[];

interface Entry {
  api_key: string;
  base_url: string;
  model: string;
}
interface File {
  active: ProviderId | null;
  items: Partial<Record<ProviderId, Entry>>;
}

export interface ProviderPatch {
  api_key?: string;
  base_url?: string;
  model?: string;
}

export class ProviderStore {
  private readonly file: string;
  private data: File;

  constructor(stateDir: string) {
    ensurePrivateDir(stateDir);
    this.file = join(stateDir, "providers.json");
    this.data = this.load();
  }

  private load(): File {
    const raw = readJson(this.file);
    const out: File = { active: null, items: {} };
    if (!isRecord(raw)) return out;
    if (isRecord(raw.items)) {
      for (const id of PROVIDER_IDS) {
        const e = raw.items[id];
        if (isRecord(e) && typeof e.api_key === "string" && typeof e.base_url === "string" && typeof e.model === "string") {
          out.items[id] = { api_key: e.api_key, base_url: e.base_url, model: e.model };
        }
      }
    }
    if (typeof raw.active === "string" && (PROVIDER_IDS as string[]).includes(raw.active)) out.active = raw.active as ProviderId;
    return out;
  }

  private save(): void {
    writeJsonAtomic(this.file, this.data);
  }

  private entry(id: ProviderId): Entry {
    return this.data.items[id] ?? { api_key: "", base_url: META[id].base, model: META[id].model };
  }

  private configured(id: ProviderId): boolean {
    const e = this.entry(id);
    return e.api_key !== "" && e.model !== "";
  }

  list(): ProviderInfo[] {
    return PROVIDER_IDS.map((id) => {
      const e = this.entry(id);
      return {
        id,
        label: META[id].label,
        configured: this.configured(id),
        key_hint: e.api_key ? e.api_key.slice(-4) : "",
        base_url: e.base_url,
        default_base_url: META[id].base,
        model: e.model,
        active: this.data.active === id,
      };
    });
  }

  /** Throws Error with a user-facing message on bad input. */
  set(id: ProviderId, patch: ProviderPatch): void {
    const cur = this.entry(id);
    const next: Entry = { ...cur };
    if (patch.api_key !== undefined) {
      const k = patch.api_key.trim();
      if (/[\s\0]/.test(k)) throw new Error("the API key must not contain spaces or line breaks");
      next.api_key = k;
    }
    if (patch.base_url !== undefined) next.base_url = patch.base_url.trim() === "" ? META[id].base : validateBaseUrl(patch.base_url.trim());
    if (patch.model !== undefined) {
      const m = patch.model.trim();
      if (/[\s\0]/.test(m)) throw new Error("the model name must not contain spaces");
      next.model = m;
    }
    // A key must never be sent somewhere other than the URL it was saved with silently:
    // changing the base URL without a new key keeps the old key, so require re-entry.
    if (patch.base_url !== undefined && next.base_url !== cur.base_url && patch.api_key === undefined && cur.api_key) {
      throw new Error("changing the base URL requires entering the API key again");
    }
    this.data.items[id] = next;
    if (this.data.active === null && this.configured(id)) this.data.active = id;
    this.save();
  }

  remove(id: ProviderId): void {
    delete this.data.items[id];
    if (this.data.active === id) this.data.active = PROVIDER_IDS.find((p) => this.configured(p)) ?? null;
    this.save();
  }

  setActive(id: ProviderId): void {
    if (!this.configured(id)) throw new Error("set an API key and model for this provider first");
    this.data.active = id;
    this.save();
  }

  /** The active provider's full config, or null when none is usable. */
  active(): LlmConfig | null {
    const id = this.data.active;
    if (!id || !this.configured(id)) return null;
    const e = this.entry(id);
    return { kind: id, base_url: e.base_url, api_key: e.api_key, model: e.model };
  }
}
