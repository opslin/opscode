// main <-> renderer requests for the agent's browser (open a Browser tab in a
// project's side panel, list/select/close tabs, show "Opscode is browsing").
// Only the app's own frame may answer.

import { ipcMain, type BrowserWindow } from "electron";
import { randomUUID } from "node:crypto";
import { CH, isOwnFrame } from "../shared/ipc";
import type { RendererBridge } from "./browserHost";

export function rendererBridge(window: () => BrowserWindow | null): RendererBridge {
  const pending = new Map<string, { resolve(v: unknown): void; reject(e: Error): void; timer: NodeJS.Timeout }>();
  let readyFor: number | undefined; // webContents id of the window whose renderer listens

  ipcMain.on(CH.BROWSER_READY, (event) => {
    if (isOwnFrame(event.senderFrame?.url)) readyFor = event.sender.id;
  });
  ipcMain.on(CH.BROWSER_REPLY, (event, msg: { rid?: unknown; result?: unknown; error?: unknown }) => {
    if (!isOwnFrame(event.senderFrame?.url) || typeof msg?.rid !== "string") return;
    const p = pending.get(msg.rid);
    if (!p) return;
    pending.delete(msg.rid);
    clearTimeout(p.timer);
    if (typeof msg.error === "string") p.reject(new Error(msg.error));
    else p.resolve(msg.result);
  });

  const live = (): BrowserWindow | null => {
    const w = window();
    return w && !w.isDestroyed() && !w.webContents.isDestroyed() && w.webContents.id === readyFor ? w : null;
  };

  return {
    available: () => live() !== null,
    ask<T>(op: string, args: Record<string, unknown>, timeoutMs = 8000): Promise<T> {
      const w = live();
      if (!w) return Promise.reject(new Error("no window"));
      const rid = randomUUID();
      return new Promise<T>((resolve, reject) => {
        const timer = setTimeout(() => { pending.delete(rid); reject(new Error(`the window did not answer ${op}`)); }, timeoutMs);
        pending.set(rid, { resolve: resolve as (v: unknown) => void, reject, timer });
        w.webContents.send(CH.BROWSER, { rid, op, args });
      });
    },
  };
}
