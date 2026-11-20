// Speed and pitch for the agent's voice. The window changes them
// while playing: a WSOLA time-stretch (overlap-add of short speech frames, each placed where it lines up best with the
// last one) changes the length without changing the pitch, then the playback rate moves the pitch. Together:
//   stretch by pitch/speed, play at rate = pitch   ->   length / speed, pitch * pitch
// so either can change without the other. Done once per sentence (a few ms for a few seconds of 24 kHz speech).

/** Semitones -> frequency factor. */
export const pitchFactor = (semitones) => 2 ** ((Number(semitones) || 0) / 12);

/**
 * Time-stretches mono samples by `alpha` (output length ≈ input × alpha), keeping the pitch.
 * WSOLA: 40 ms Hann frames, 50% overlap, each frame searched ±10 ms for the best match with the natural continuation.
 */
export function stretch(x, alpha, rate = 24000) {
  if (!(alpha > 0) || Math.abs(alpha - 1) < 0.01 || x.length < rate * 0.06) return x;
  const N = Math.round(rate * 0.04) & ~1; // frame
  const H = N >> 1; // synthesis hop
  const Ha = H / alpha; // analysis hop
  const tol = Math.round(rate * 0.01);
  const win = new Float32Array(N);
  for (let i = 0; i < N; i++) win[i] = 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / N);
  const outLen = Math.ceil(x.length * alpha) + N;
  const out = new Float32Array(outLen);
  const norm = new Float32Array(outLen);
  const at = (i) => (i >= 0 && i < x.length ? x[i] : 0);

  let prev = 0; // where the last frame was taken from
  for (let k = 0; ; k++) {
    const outPos = k * H;
    if (outPos + N > outLen) break;
    const ideal = Math.round(k * Ha);
    if (ideal >= x.length) break;
    let best = ideal;
    if (k > 0) {
      // The frame that would naturally follow the last one starts at prev + H; find the input position near `ideal`
      // that looks most like it (cross-correlation over the overlap, every second sample).
      const nat = prev + H;
      let bestScore = -Infinity;
      for (let d = -tol; d <= tol; d += 2) {
        const p = ideal + d;
        if (p < 0) continue;
        let score = 0;
        for (let i = 0; i < H; i += 2) score += at(nat + i) * at(p + i);
        if (score > bestScore) { bestScore = score; best = p; }
      }
    }
    for (let i = 0; i < N; i++) {
      out[outPos + i] += at(best + i) * win[i];
      norm[outPos + i] += win[i];
    }
    prev = best;
  }
  const len = Math.min(outLen, Math.ceil(x.length * alpha));
  const y = new Float32Array(len);
  for (let i = 0; i < len; i++) y[i] = norm[i] > 1e-3 ? out[i] / norm[i] : 0;
  return y;
}

/**
 * The samples to schedule and the rate to play them at, for a speed (1 = as made) and pitch (semitones, 0 = as made).
 * Result plays for (input length / speed) at (pitch factor) times the pitch.
 */
export function applyTone(samples, { speed = 1, pitch = 0 } = {}, rate = 24000) {
  const p = pitchFactor(pitch);
  const s = Number(speed) > 0 ? Number(speed) : 1;
  if (Math.abs(p - 1) < 0.001 && Math.abs(s - 1) < 0.001) return { samples, playbackRate: 1 };
  return { samples: stretch(samples, p / s, rate), playbackRate: p };
}
