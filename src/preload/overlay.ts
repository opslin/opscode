// Preload of the overlay window (overlay.html): told what to draw; it can only close the workers view or open a chat.
import { contextBridge, ipcRenderer } from "electron";
import { OVERLAY } from "../shared/ipc";

contextBridge.exposeInMainWorld("opscodeOverlay", {
  onState: (fn: (s: unknown) => void): void => { ipcRenderer.on(OVERLAY.STATE, (_e, s) => fn(s)); ipcRenderer.send(OVERLAY.READY); },
  act: (a: unknown): void => ipcRenderer.send(OVERLAY.ACT, a),
});
