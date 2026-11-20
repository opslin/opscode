// Lead intelligence: the ontology store, industry packs and offerings (slice 1), the website scout (slices 2 and 2b) and
// Lead LAB (slice 3). See docs/lead-intelligence-design.md. Everything written goes through the store, so every lead fact
// keeps its quote, URL and date.

import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { ensurePrivateDir } from "../jsonFile";
import { LeadStore } from "./store";
import { OFFERING_TEMPLATES, PackRegistry, CORE_RUBRIC } from "./packs";
import type { GoldCase } from "./lab";

export { LeadError } from "./store";

const isRec = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null && !Array.isArray(v);

export class LeadsService {
  readonly store: LeadStore;
  readonly packs: PackRegistry;
  private readonly lab: string;
  constructor(stateDir: string) {
    this.store = new LeadStore(stateDir);
    this.packs = new PackRegistry(stateDir);
    this.lab = join(stateDir, "leads", "lab");
    ensurePrivateDir(join(stateDir, "leads"));
  }
  templates(): typeof OFFERING_TEMPLATES { return OFFERING_TEMPLATES; }
  coreRubric(): typeof CORE_RUBRIC { return CORE_RUBRIC; }

  /** Gold cases a person added as JSON files in <state>/leads/lab/gold/. A file with the wrong shape is skipped and named. */
  extraGold(): { cases: GoldCase[]; skipped: string[] } {
    const dir = join(this.lab, "gold");
    const cases: GoldCase[] = [], skipped: string[] = [];
    if (!existsSync(dir)) return { cases, skipped };
    for (const f of readdirSync(dir).sort()) {
      if (!f.endsWith(".json")) continue;
      try {
        const raw = JSON.parse(readFileSync(join(dir, f), "utf8")) as unknown;
        for (const g of Array.isArray(raw) ? raw : [raw]) {
          if (!isRec(g) || typeof g.id !== "string" || !isRec(g.case) || !isRec(g.expected) || !Object.values(g.expected).every((x) => typeof x === "boolean")) throw new Error("bad shape");
          const c = g.case;
          if (!isRec(c.campaign) || !isRec(c.organization) || !Array.isArray(c.evidence) || !Array.isArray(c.signals) || !Array.isArray(c.emails)) throw new Error("bad case");
          cases.push({ id: g.id, note: typeof g.note === "string" ? g.note : "", case: { ...(c as object), id: g.id } as GoldCase["case"], expected: g.expected as Record<string, boolean> });
        }
      } catch { skipped.push(f); }
    }
    return { cases, skipped };
  }

  /** Saves a gold report next to the others; returns where. */
  saveReport(markdown: string, json: unknown): string {
    const dir = join(this.lab, "reports");
    mkdirSync(dir, { recursive: true, mode: 0o700 });
    const stamp = new Date().toISOString().replace(/[:.]/g, "-");
    const base = join(dir, `gold-${stamp}`);
    writeFileSync(`${base}.md`, markdown + "\n", { mode: 0o600 });
    writeFileSync(`${base}.json`, JSON.stringify(json, null, 2) + "\n", { mode: 0o600 });
    return `${base}.md`;
  }
}
