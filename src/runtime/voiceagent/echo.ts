// The agent's own voice can come back through the microphone. Chromium's echo canceller removes most of it; this is the
// second line of defence: a recognised phrase that is (almost) only words the agent has just said is not the person.

const words = (t: string): string[] => t.toLowerCase().replace(/[^\p{L}\p{M}\p{N}\s']/gu, " ").split(/\s+/).filter(Boolean);

/**
 * `heard` is what the recogniser reported, `spoken` the agent's latest sentences. True when at least 4 words were
 * heard and 80% or more of them occur in what was spoken. (Callers only ask while the agent is audible.)
 */
export function isEcho(heard: string, spoken: readonly string[]): boolean {
  const hw = words(heard);
  if (hw.length < 4) return false;
  const pool = new Set(spoken.flatMap(words));
  if (pool.size === 0) return false;
  return hw.filter((w) => pool.has(w)).length / hw.length >= 0.8;
}

export const countWords = (t: string): number => words(t).length;

/** The share (0..1) of the heard words that the agent itself just said. For partial words, where isEcho's 4-word minimum is too slow. */
export function echoShare(heard: string, spoken: readonly string[]): number {
  const hw = words(heard);
  if (!hw.length) return 0;
  const pool = new Set(spoken.flatMap(words));
  if (pool.size === 0) return 0;
  return hw.filter((w) => pool.has(w)).length / hw.length;
}
