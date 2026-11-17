// Runs on the audio thread. Turns the microphone into 100 ms chunks of 16 kHz mono Int16 for the voice helper, and
// reports the loudness for the orb. If the audio context could not be made at 16 kHz it averages down to it.
class Chunker extends AudioWorkletProcessor {
  constructor() {
    super();
    this.ratio = sampleRate / 16000;
    this.buf = new Int16Array(1600);
    this.n = 0;
    this.sum = 0;
    this.cnt = 0;
    this.phase = 0;
    this.energy = 0;
    this.muted = false;
    this.port.onmessage = (e) => { if (typeof e.data?.mute === "boolean") this.muted = e.data.mute; };
  }
  process(inputs) {
    const ch = inputs[0]?.[0];
    if (!ch) return true;
    for (let i = 0; i < ch.length; i++) {
      this.sum += ch[i];
      this.cnt++;
      this.phase += 1;
      if (this.phase < this.ratio) continue;
      this.phase -= this.ratio;
      const v = Math.max(-1, Math.min(1, this.sum / this.cnt));
      this.sum = 0;
      this.cnt = 0;
      this.energy += v * v;
      // A muted microphone still sends its timeline, as silence.
      this.buf[this.n++] = this.muted ? 0 : v < 0 ? v * 32768 : v * 32767;
      if (this.n === 1600) {
        const out = this.buf.slice();
        this.port.postMessage({ pcm: out.buffer, rms: Math.sqrt(this.energy / 1600) }, [out.buffer]);
        this.n = 0;
        this.energy = 0;
      }
    }
    return true;
  }
}
registerProcessor("opscode-chunker", Chunker);
