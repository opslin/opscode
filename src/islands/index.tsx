// React islands for Opscode's renderer (plain ES modules elsewhere). Each mount returns a
// small handle the vanilla code drives; React and the elements stay inside this bundle.

import { createRoot } from "react-dom/client";
import { flushSync } from "react-dom";
import { Dock, type DockHandlers, type DockSnapshot } from "./dock";
import { Pipeline, type PipelineHandlers, type PipelineSnap } from "./pipeline";
import { Message, type MsgHandlers, type MsgSnap } from "./message";
import { Stage, type StageSnap } from "./stage";

export function mountDock(el: HTMLElement, on: DockHandlers): { render(snap: DockSnapshot): void; unmount(): void } {
  const root = createRoot(el);
  return {
    render: (snap) => root.render(<Dock snap={snap} on={on} />),
    unmount: () => root.unmount(),
  };
}

/** A pipeline's Job progress (Work panel card). */
export function mountPipeline(el: HTMLElement, on: PipelineHandlers): { render(p: PipelineSnap): void; unmount(): void } {
  const root = createRoot(el);
  return {
    render: (p) => root.render(<div className="aui-island"><Pipeline p={p} on={on} /></div>),
    unmount: () => root.unmount(),
  };
}

/** One assistant reply in a chat. */
export function mountMessage(el: HTMLElement, on: MsgHandlers): { render(m: MsgSnap): void; unmount(): void } {
  const root = createRoot(el);
  return {
    // Synchronous, so the chat can measure and scroll right after (it sticks to the bottom while streaming).
    render: (m) => flushSync(() => root.render(<Message m={m} on={on} />)),
    unmount: () => root.unmount(),
  };
}

/** The new-chat background (sonar dots + pixel stars, coloured by mode). render(null) clears it. */
export function mountStage(el: HTMLElement): { render(s: StageSnap | null): void; unmount(): void } {
  const root = createRoot(el);
  return {
    render: (s) => root.render(s ? <Stage s={s} /> : null),
    unmount: () => root.unmount(),
  };
}
