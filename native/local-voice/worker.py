"""Local JSON-lines adapter for the upstream Kitten Mini and whisper.cpp runtimes."""
import base64
import contextlib
import json
import os
from pathlib import Path
import site
import sys
import time

site.addsitedir(str(Path(__file__).resolve().parent / "packages"))
os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")


class Whisper:
    def __init__(self, path):
        import _pywhispercpp
        from pywhispercpp.model import Model

        if not path.is_file():
            raise FileNotFoundError("The Whisper model is missing")
        self.bindings = _pywhispercpp
        self.model = Model(
            str(path), n_threads=min(6, os.cpu_count() or 2), no_context=True,
            translate=False, no_timestamps=True, print_realtime=False, print_progress=False,
            print_special=False, print_timestamps=False, redirect_whispercpp_logs_to=None,
            temperature_inc=0.0, context_params={"use_gpu": sys.platform == "darwin" and os.environ.get("OPSCODE_WHISPER_CPU") != "1"},
        )

    def run(self, req):
        import numpy as np

        samples = np.frombuffer(base64.b64decode(req["pcm"]), dtype="<i2").astype(np.float32) / 32768.0
        if len(samples) < 1600:
            return {"text": "", "language": req["language"]}
        language = "" if req["language"] == "auto" else req["language"]
        segments = self.model.transcribe(
            samples, language=language, initial_prompt=req.get("prompt") or "",
            suppress_blank=True, extract_probability=True,
            audio_ctx=min(1500, max(512, (len(samples) + 319) // 320 + 64)) if req.get("partial") else 0,
        )
        text = " ".join(seg.text.strip() for seg in segments if seg.probability >= 0.18).strip()
        lang = self.bindings.whisper_full_lang_id(self.model._ctx)
        language = self.bindings.whisper_lang_str(lang) if lang >= 0 else req["language"]
        return {"text": text, "language": language}


def kitten_frontend(model, directory):
    from kittenml.kittentts2_tiny.frontend import Frontend, G2PResult, phonemize_v1, phonemize_v2
    from kittenml.kittentts2_tiny.frontend.english import EnglishG2P, Fallback
    from kittenml.kittentts2_tiny.frontend.tts_norm import normalize

    class EnglishFallback(Fallback):
        # Retain Kitten's English lexicons. Use the training phonemizer for uncommon words.
        def __init__(self, lexicon):
            from kittenml.kittentts2_tiny.frontend.espeak import EspeakFallback

            self.cmu = json.loads(lexicon.read_text(encoding="utf-8"))
            self.espeak = EspeakFallback(british=False)

        def __call__(self, token):
            pronunciation = self._cmu(token.text)
            return (pronunciation, self.RATING) if pronunciation else self.espeak(token)

    class English(EnglishG2P):
        def __init__(self, vocab, lexicon):
            from misaki import en

            self._pm, self._normalize = phonemize_v1, normalize
            self.vocab = {key: value for key, value in vocab.items() if key != "\u0289"}
            self.fallback = EnglishFallback(lexicon)
            self.g2p = en.G2P(trf=False, british=False, fallback=self.fallback, unk="")
            self._unsaid = []

    class OpscodeFrontend(Frontend):
        def g2p(self, lang):
            if lang == "en" and lang not in self._g2p:
                self._g2p["en"] = English(self.vocab, Path(self.g2p_dir) / "cmu_misaki_us.json")
            if lang == "ja" and lang not in self._g2p:
                from misaki.ja import JAG2P

                g2p = JAG2P(version="pyopenjtalk")
                phonemizer = phonemize_v1 if self.phon == "v1" else phonemize_v2

                def japanese(text, normalise=True):
                    phonemes = phonemizer.phonemize_lang(g2p, text, "ja")
                    return G2PResult(text, "".join(c for c in phonemes if c in self.vocab))

                self._g2p["ja"] = japanese
            return super().g2p(lang)

    g2p_dir = directory / model.config.get("g2p_dir", "g2p")
    return OpscodeFrontend(model.config.get("phonemizer", "v1"), model.vocab, str(g2p_dir))


class Kitten:
    def __init__(self, path):
        from kittenml import KittenTTS2Tiny

        self.model = KittenTTS2Tiny(str(path), backend="onnx", device="cpu", threads=2)
        self.model._frontend = kitten_frontend(self.model, path)
        # All sixteen languages share the same ONNX graph.
        self.model._session("en")
        self.identifier = None

    def run(self, req):
        import numpy as np

        text = req["text"]
        voice_id = req.get("voice", "")
        voice_lang, _, voice = voice_id.partition("-")
        language = req.get("language")
        if language not in self.model.languages:
            hint = req.get("hint")
            # In auto mode, prefer the detected script and use the last spoken language for brief replies.
            if self.identifier is None:
                from langid.langid import LanguageIdentifier, model
                self.identifier = LanguageIdentifier.from_modelstring(model, norm_probs=True)
                self.identifier.set_languages(self.model.languages)
            detected, confidence = self.identifier.classify(text)
            language = detected if confidence >= 0.85 else (
                hint if hint in self.model.languages else voice_lang if voice_lang in self.model.languages else "en"
            )
        if voice not in {v["key"] for v in self.model.voices(language)}:
            voice = None
        audio = self.model.generate(text, voice=voice, language=language)
        pcm = (np.clip(audio, -1, 1) * 32767).astype("<i2")
        return {"pcm": base64.b64encode(pcm.tobytes()).decode("ascii"), "rate": self.model.sample_rate}


def main():
    worker_class = {"whisper": Whisper, "kitten": Kitten}[sys.argv[1]]
    path = Path(sys.argv[2])
    protocol = sys.stdout
    engine = None
    with contextlib.redirect_stdout(sys.stderr):
        for line in sys.stdin:
            try:
                req = json.loads(line)
                start = time.monotonic()
                if req["cmd"] == "load":
                    engine = worker_class(path)
                    result = {"ready": True}
                else:
                    if engine is None:
                        raise RuntimeError("The local voice model has not loaded")
                    result = engine.run(req)
                result["ms"] = round((time.monotonic() - start) * 1000)
            except Exception as error:
                result = {"error": str(error)}
            protocol.write(json.dumps(result) + "\n")
            protocol.flush()


if __name__ == "__main__":
    main()
