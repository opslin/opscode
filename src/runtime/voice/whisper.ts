import type { ModelFile } from "./download";
import { SILERO } from "./models";

export const WHISPER_ENGINE = "Whisper Large-v3 Turbo Q5";
export const WHISPER_MODEL = "ggml-large-v3-turbo-q5_0.bin";
export const WHISPER_FILES: ModelFile[] = [
  {
    name: WHISPER_MODEL,
    url: `https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/${WHISPER_MODEL}`,
    bytes: 574_041_195,
    sha256: "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2",
  },
  { name: "silero_vad.onnx", ...SILERO },
];

// Whisper locale codes (region-specific settings from older versions map to their base language).
export const WHISPER_LANGUAGES = "af am ar as az ba be bg bn bo br bs ca cs cy da de el en es et eu fa fi fo fr gl gu ha haw he hi hr ht hu hy id is it ja jw ka kk km kn ko la lb ln lo lt lv mg mi mk ml mn mr ms mt my ne nl nn no oc pa pl ps pt ro ru sa sd si sk sl sn so sq sr su sv sw ta te tg th tk tl tr tt uk ur uz vi yi yo yue zh".split(" ");
export function whisperLocale(locale: string): string {
  const base = locale.toLowerCase().split("-")[0];
  return WHISPER_LANGUAGES.includes(base) ? base : "auto";
}
