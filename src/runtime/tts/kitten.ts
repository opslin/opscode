import type { ModelFile } from "../voice/download";

const BASE = "https://huggingface.co/KittenML/kitten-tts-2-mini/resolve/8e89ae2a718ee4bb893c67d67657e520e6112faf";

export const KITTEN_FILES: ModelFile[] = [
  ["config.json", 18_475, "fb960637bf495a6cd363044ca4fb5d358cb7eba7fb3eb233c1914455f64e72fa"],
  ["g2p/cmu_misaki_us.json", 3_418_388, "ae564e1a76df3501058a5ec99d135d016759c9475042fb6c3811374daee1ef04"],
  ["kitten_tts_2_mini.onnx", 82_711_386, "fa821c1cdd8f7fbfdbd5d1cae0a767673871d62696b85af7db059a9bd26b42d2"],
  ["vocab.json", 1_324, "b007200ac2a7973ac25c509f8346815076b9d9f33758cb0bfe4de99e2f58f851"],
  ["voices_da.npz", 1_567_468, "a4d191e87175519bab110aed747ccdb48586455b9c4896aa74c2d269766d8eef"],
  ["voices_de.npz", 6_792_294, "b33f8c44a7f3968ed53aca31666bed9110d5ab0023a75dc69125f3e3218e9a9d"],
  ["voices_en.npz", 5_747_328, "5c18573d075f53f6f218c2056dfc84ad10e976e81e23d55e5a7a6adc6e9135a4"],
  ["voices_es.npz", 6_792_300, "3de943ddab5eeced04a42c732d39152802df01fd94f194181a7bc5bd60d52c3b"],
  ["voices_fi.npz", 2_612_426, "7764dec2e1e21cae23d623e9b9ccb5d15122f1fbbc582e40fbd57c53e3ce2c73"],
  ["voices_fr.npz", 4_179_894, "df2f679a9b3b73b6b3cf14003a782804db1a22985f68f3912859598249dcd79e"],
  ["voices_hi.npz", 2_089_954, "ce6d14445f10b16347daa9385f411d87f8cc73d989f5467c0fd975abdf906329"],
  ["voices_it.npz", 6_792_298, "1c9d98962dd50e240450d5316a1ad80f32d67f9b2919c9419422359d1c4333d6"],
  ["voices_ja.npz", 2_612_432, "17293773d30660c39120541586451aa66c0a8e8b58590e38381e22dc1bf6d271"],
  ["voices_ko.npz", 1_567_476, "d3d5295000153ad90f7a321769cd4647b8db42612feaf6e3d6e765f1c35b9daf"],
  ["voices_nl.npz", 2_612_428, "d1862bfe3554d1c47d22dc44ed943335ba695cbbe6d5324a129365fadf22238d"],
  ["voices_pt.npz", 6_792_306, "83dc34bca3e2c454548d8d63cda7830aa22748cc1a0643fa5bdac445fe8f4f57"],
  ["voices_ru.npz", 6_792_308, "f998f1fce7b19a0714c47b99aaaa06c8ab94be13e1dfb3acf8a6a6c2b97a05f2"],
  ["voices_sv.npz", 1_567_468, "73c6b92a0be1c970bd0334b0099a57354057930c40911d17c6dfc0347c6b1cba"],
  ["voices_sw.npz", 2_089_952, "809450b8dc88cae0e042ad935c1e5751b9a2448a2251c51f29285cc6d3f46e09"],
  ["voices_tr.npz", 1_044_986, "d2af4c7636381c26ad3252002021cbacef130b401e45ed5d4ee079f901b61920"],
].map(([name, bytes, sha256]) => ({ name: String(name), bytes: Number(bytes), sha256: String(sha256), url: `${BASE}/${name}` }));

export const KITTEN_LANGUAGES = ["en", "de", "es", "it", "pt", "ru", "hi", "da", "fi", "fr", "ja", "ko", "nl", "sv", "sw", "tr"];

const VOICE_NAMES: Record<string, string[]> = {
  en: ["Eleanor", "Martha", "Serena", "Iris", "Grace", "Edith", "Diana", "Otis", "Vincent", "Max", "Danny"],
  de: ["Lena", "Greta", "Jonas", "Felix", "Eleanor", "Martha", "Serena", "Iris", "Grace", "Edith", "Diana", "Otis", "Vincent"],
  es: ["Lucia", "Carmen", "Javier", "Diego", "Eleanor", "Martha", "Serena", "Iris", "Grace", "Edith", "Diana", "Otis", "Vincent"],
  it: ["Giulia", "Chiara", "Marco", "Luca", "Eleanor", "Martha", "Serena", "Iris", "Grace", "Edith", "Diana", "Otis", "Vincent"],
  pt: ["Beatriz", "Camila", "Rafael", "Thiago", "Eleanor", "Martha", "Serena", "Iris", "Grace", "Edith", "Diana", "Otis", "Vincent"],
  ru: ["Anastasia", "Natasha", "Dmitri", "Ivan", "Eleanor", "Martha", "Serena", "Iris", "Grace", "Edith", "Diana", "Otis", "Vincent"],
  hi: ["Priya", "Ananya", "Arjun", "Vikram"],
  da: ["Freja", "Mads", "Rasmus"],
  fi: ["Aino", "Helmi", "Eero", "Juho", "Ville"],
  fr: ["Camille", "Chloe", "Manon", "Louis", "Antoine", "Julien", "Mathis", "Etienne"],
  ja: ["Yuki", "Sakura", "Haruka", "Aoi", "Haruto"],
  ko: ["Seoyeon", "Minjun", "Jihoon"],
  nl: ["Sanne", "Fenna", "Daan", "Bram", "Joris"],
  sv: ["Astrid", "Elsa", "Oskar"],
  sw: ["Zawadi", "Neema", "Baraka", "Juma"],
  tr: ["Elif", "Zeynep"],
};

export const KITTEN_VOICES = Object.entries(VOICE_NAMES).flatMap(([language, names]) =>
  names.map((name) => ({ id: `${language}-${name.toLowerCase()}`, name, language })));
