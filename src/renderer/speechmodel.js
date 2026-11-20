import { confirmDialog } from "./dialogs.js";
import { state, toast } from "./store.js";

let pending;
/** Checks the model before turning on the microphone. Voice and dictation share the same local download. */
export function ensureSpeechModel() {
  if (pending) return pending;
  pending = install().finally(() => { pending = null; });
  return pending;
}

async function install() {
  const st = await state.client.call("voice.status", {});
  if (!st.available) throw new Error(st.error || "The local speech engine is unavailable.");
  if (st.installed || st.download_bytes === undefined) return true;
  const mb = Math.round(st.download_bytes / 1e6);
  if (!st.installing && !(await confirmDialog({
    title: "Download Whisper?",
    body: `Whisper Large-v3 Turbo Q5 transcribes your microphone on this computer. The one-time download uses ${mb} MB.`,
    confirm: `Download ${mb} MB`,
  }))) return false;

  let listener;
  const done = new Promise((resolve) => {
    listener = (e) => {
      const v = e.detail;
      if (v?.ev !== "install" || !["done", "error"].includes(v.phase)) return;
      if (v.phase === "error") toast(v.message || "Couldn't download Whisper.", 8000);
      resolve(v.phase === "done");
    };
    window.addEventListener("opscode:voice", listener);
  });
  try {
    await state.client.call("voice.install", {});
    if ((await state.client.call("voice.status", {})).installed) return true;
    toast("Downloading Whisper. You can check progress in Settings → General → Voice.", 6000);
    return await done;
  } finally {
    window.removeEventListener("opscode:voice", listener);
  }
}
