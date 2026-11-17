// List prices, US$ per million tokens: [input, cache read, output]. A cache write
// costs 1.25x the input price (5-minute cache) or 2x (1-hour cache).
// These are API list prices, used to compare habits and models. They are not what
// a Pro, Max or Team plan charges: say so wherever the numbers are shown.

export type Family = "opus" | "sonnet" | "haiku" | "fable";
export const PRICE: Record<Family, readonly [number, number, number]> = {
  opus: [4, 0.2, 20],
  sonnet: [2, 0.1, 10],
  haiku: [0.1, 0.01, 0.5],
  fable: [10, 0.25, 50],
};

export function familyOf(model: string | undefined): Family | null {
  const m = (model ?? "").toLowerCase();
  for (const f of Object.keys(PRICE) as Family[]) if (m.includes(f)) return f;
  return null;
}

export interface Tokens { inp: number; cw: number; cr: number; out: number; h1: boolean }

/** The four parts of a call's cost, in dollars. */
export function costParts(model: string, t: Tokens): { read: number; write: number; out: number; inp: number } {
  const f = familyOf(model);
  if (!f) return { read: 0, write: 0, out: 0, inp: 0 };
  const p = PRICE[f];
  return { read: (t.cr * p[1]) / 1e6, write: (t.cw * p[0] * (t.h1 ? 2 : 1.25)) / 1e6, out: (t.out * p[2]) / 1e6, inp: (t.inp * p[0]) / 1e6 };
}
export const cost = (model: string, t: Tokens): number => {
  const c = costParts(model, t);
  return c.read + c.write + c.out + c.inp;
};
