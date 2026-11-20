// Preload of the notch window (notch.html). Bundled on its own (npm run build:preload). The page gets only these
// functions: it is told what to show and asks main to act; no runtime endpoint or token reaches it.

import { contextBridge, ipcRenderer } from "electron";
import { NOTCH } from "../shared/ipc";

contextBridge.exposeInMainWorld("opscodeNotch", {
  /** The feed now and at every change. Calling it tells main the page listens. */
  onState: (fn: (s: unknown) => void): void => {
    ipcRenderer.on(NOTCH.STATE, (_e, s) => fn(s));
    ipcRenderer.send(NOTCH.READY);
  },
  onAway: (fn: () => void): void => { ipcRenderer.on(NOTCH.AWAY, () => fn()); },
  onSummon: (fn: () => void): void => { ipcRenderer.on(NOTCH.SUMMON, () => fn()); },
  onVoice: (fn: (e: unknown) => void): void => { ipcRenderer.on(NOTCH.VOICE, (_e, v) => fn(v)); },
  onToast: (fn: (text: string) => void): void => { ipcRenderer.on(NOTCH.TOAST, (_e, t) => fn(String(t))); },
  onTalk: (fn: (e: unknown) => void): void => { ipcRenderer.on(NOTCH.TALK, (_e, v) => fn(v)); },
  onTalkSummon: (fn: () => void): void => { ipcRenderer.on(NOTCH.TALK_SUMMON, () => fn()); },
  act: (action: unknown): void => ipcRenderer.send(NOTCH.ACT, action),
  over: (on: boolean): void => ipcRenderer.send(NOTCH.OVER, on === true),
  menu: (): void => ipcRenderer.send(NOTCH.MENU),
});
