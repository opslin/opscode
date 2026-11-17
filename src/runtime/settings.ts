// Runtime-owned settings, persisted as JSON in the private state dir.
// Writes are atomic (temp file + rename) and the file is mode 0600.

import { join } from "node:path";
import { DEFAULT_SETTINGS, PERMISSION_MODES, type PermissionMode, type Settings } from "../shared/protocol";
import { ensurePrivateDir, readJson, writeJsonAtomic } from "./jsonFile";
import { err, isRecord, ok, type Result } from "./rpc";

/** Validates a partial update; rejects unknown keys and bad values. */
export function validateSettingsPatch(input: unknown): Result<Partial<Settings>> {
  if (!isRecord(input)) return err("patch must be an object");
  const out: Partial<Settings> = {};
  for (const [key, value] of Object.entries(input)) {
    switch (key) {
      case "display_name":
        if (typeof value !== "string" || value.length > 64) {
          return err("display_name must be a string of at most 64 characters");
        }
        out.display_name = value.trim();
        break;
      case "theme":
        if (value !== "system" && value !== "light" && value !== "dark") {
          return err('theme must be "system", "light" or "dark"');
        }
        out.theme = value;
        break;
      case "keep_awake":
        if (typeof value !== "boolean") return err("keep_awake must be a boolean");
        out.keep_awake = value;
        break;
      case "text_size":
        if (value !== "small" && value !== "default" && value !== "large") return err('text_size must be "small", "default" or "large"');
        out.text_size = value;
        break;
      case "density":
        if (value !== "comfortable" && value !== "compact") return err('density must be "comfortable" or "compact"');
        out.density = value;
        break;
      case "memory_enabled":
        if (typeof value !== "boolean") return err("memory_enabled must be a boolean");
        out.memory_enabled = value;
        break;
      case "voice_locale":
        if (typeof value !== "string" || !/^(auto|[a-z]{2,3}(-[A-Za-z0-9]{2,8})*)$/.test(value)) return err('voice_locale must be "auto" or a language like en-IN');
        out.voice_locale = value;
        break;
      case "tts_voice":
        if (typeof value !== "string" || !/^[a-z0-9_-]{1,40}$/i.test(value)) return err("tts_voice must be a voice name");
        out.tts_voice = value;
        break;
      case "tts_speed":
        if (typeof value !== "number" || !(value >= 0.75 && value <= 2)) return err("tts_speed must be between 0.75 and 2");
        out.tts_speed = value;
        break;
      case "voice_brain_engine":
        if (typeof value !== "string" || !/^(|api|claude-code|codex|antigravity|qoder)$/.test(value)) return err("voice_brain_engine must be an engine id or empty");
        out.voice_brain_engine = value;
        break;
      case "voice_brain_model":
      case "voice_brain_effort":
        if (typeof value !== "string" || value.length > 120 || /[\u0000-\u001f]/.test(value)) return err(`${key} must be a short text`);
        out[key] = value;
        break;
      case "voice_tts_voice":
        if (typeof value !== "string" || !/^([a-z0-9_-]{1,40})?$/i.test(value)) return err("voice_tts_voice must be a voice name");
        out.voice_tts_voice = value;
        break;
      case "voice_tts_speed":
        if (typeof value !== "number" || !(value >= 0.8 && value <= 1.4)) return err("voice_tts_speed must be between 0.8 and 1.4");
        out.voice_tts_speed = value;
        break;
      case "voice_tts_pitch":
        if (typeof value !== "number" || !(value >= -4 && value <= 4)) return err("voice_tts_pitch must be between -4 and 4");
        out.voice_tts_pitch = value;
        break;
      case "voice_end_ms":
        if (typeof value !== "number" || !Number.isInteger(value) || value < 600 || value > 3000) return err("voice_end_ms must be between 600 and 3000");
        out.voice_end_ms = value;
        break;
      case "default_mode":
        if (!(PERMISSION_MODES as readonly unknown[]).includes(value)) return err("default_mode must be read, supervised, auto_edits or full");
        out.default_mode = value as PermissionMode;
        break;
      default:
        return err(`unknown setting "${key}"`);
    }
  }
  return ok(out);
}

export class SettingsStore {
  private readonly file: string;
  private current: Settings;

  constructor(stateDir: string) {
    ensurePrivateDir(stateDir);
    this.file = join(stateDir, "settings.json");
    this.current = this.load();
  }

  get(): Settings {
    return { ...this.current };
  }

  update(patch: Partial<Settings>): Settings {
    this.current = { ...this.current, ...patch };
    writeJsonAtomic(this.file, this.current);
    return this.get();
  }

  /** Keeps only valid known keys from disk; falls back to defaults. */
  private load(): Settings {
    const raw = readJson(this.file);
    const merged: Settings = { ...DEFAULT_SETTINGS };
    if (isRecord(raw)) {
      for (const [key, value] of Object.entries(raw)) {
        const one = validateSettingsPatch({ [key]: value });
        if (one.ok) Object.assign(merged, one.value);
      }
    }
    return merged;
  }
}
