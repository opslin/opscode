// Attachments in the composer: photos, files and folders added with the + button, ⌘U, paste or drag and drop.
// They are copied into the project by the runtime (attachment.add); this keeps the tray of thumbnails and chips
// above the message box, and hands the project paths to turn.submit when the message is sent.

import { h } from "./dom.js";
import { icon } from "./icons.js";
import { state, toast } from "./store.js";

const MAX_ITEMS = 12;
const IMG = /\.(png|jpe?g|gif|webp)$/i;

/** A pasted or dropped picture with no file on disk, shrunk to a JPEG under ~900 KB so it fits one message. */
async function shrink(file) {
  const bitmap = await createImageBitmap(file);
  let scale = Math.min(1, 1800 / Math.max(bitmap.width, bitmap.height));
  for (let quality = 0.88; ; quality -= 0.12) {
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(bitmap.width * scale));
    canvas.height = Math.max(1, Math.round(bitmap.height * scale));
    canvas.getContext("2d").drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    const blob = await new Promise((res) => canvas.toBlob(res, "image/jpeg", Math.max(quality, 0.4)));
    if (blob && (blob.size < 900_000 || scale < 0.3)) { bitmap.close?.(); return blob; }
    scale *= 0.75;
  }
}

const toBase64 = (blob) => new Promise((res, rej) => {
  const r = new FileReader();
  r.onload = () => res(String(r.result).split(",")[1] ?? "");
  r.onerror = () => rej(r.error);
  r.readAsDataURL(blob);
});

/** One attachment as a picture tile or a file/folder chip. `thumb` may be set later. */
export function attachmentTile(a, { onRemove, load } = {}) {
  const remove = onRemove ? h("button", { class: "att-x", type: "button", "aria-label": `Remove ${a.name}`, title: "Remove", onclick: (e) => { e.stopPropagation(); onRemove(); } }, icon("x")) : null;
  if (a.kind === "image") {
    const img = h("img", { alt: a.name, draggable: false });
    const tile = h("div", { class: "att att-img", title: a.name, dataset: { status: a.status ?? "ready" } }, img, remove);
    const show = (src) => { if (src) img.src = src; };
    if (a.thumb) show(a.thumb);
    else if (load) void load(a).then(show).catch(() => {});
    return tile;
  }
  const sub = a.ref ? "stays where it is" : a.kind === "folder" ? (a.files !== undefined ? `${a.files} file${a.files === 1 ? "" : "s"}` : "folder") : "";
  return h("div", { class: "att att-file", title: a.ref ? `${a.path} (not copied)` : a.path ?? a.name, dataset: { status: a.status ?? "ready" } },
    icon(a.ref ? "key" : a.kind === "folder" ? "folder" : "file"),
    h("span", { class: "att-name" }, a.name), sub ? h("span", { class: "att-sub" }, sub) : null, remove);
}

/** Loads a picture's thumbnail from the runtime (for tiles built from history). */
export const thumbLoader = (workspaceId) => async (a) => (await state.client.call("attachment.thumb", { workspace_id: workspaceId, path: a.path })).data_url;

export function createAttachments(workspace, { onChange } = {}) {
  /** { key, name, kind, path?, files?, ref?, thumb?, status: "adding" | "ready" } */
  let items = [];
  let seq = 0;
  const tray = h("div", { class: "attach-tray", hidden: true });

  const render = () => {
    tray.hidden = items.length === 0;
    tray.replaceChildren(...items.map((a) => attachmentTile(a, { onRemove: () => { items = items.filter((x) => x.key !== a.key); render(); } })));
    onChange?.();
  };
  const call = (params) => state.client.call("attachment.add", { workspace_id: workspace.id, ...params });
  const room = (n) => {
    if (items.length + n > MAX_ITEMS) { toast(`At most ${MAX_ITEMS} attachments in one message`); return false; }
    return true;
  };

  /** Files or folders by absolute path (the picker, or dropped from Finder). */
  async function addPaths(paths) {
    if (!paths.length || !room(paths.length)) return;
    const pending = paths.map((p) => ({ key: ++seq, name: p.split("/").filter(Boolean).pop() ?? p, kind: IMG.test(p) ? "image" : "file", status: "adding" }));
    items.push(...pending);
    render();
    try {
      const { items: got } = await call({ paths });
      const keys = new Set(pending.map((x) => x.key));
      const at = items.findIndex((x) => keys.has(x.key));
      items = items.filter((x) => !keys.has(x.key));
      const made = got.map((g) => ({ key: ++seq, ...g, status: "ready" }));
      items.splice(at < 0 ? items.length : at, 0, ...made);
      render();
      for (const a of made) if (a.kind === "image") void state.client.call("attachment.thumb", { workspace_id: workspace.id, path: a.path }).then((r) => { if (r.data_url && items.includes(a)) { a.thumb = r.data_url; render(); } }).catch(() => {});
    } catch (e) {
      const keys = new Set(pending.map((x) => x.key));
      items = items.filter((x) => !keys.has(x.key));
      render();
      toast(e.message);
    }
  }

  /** Files from a drop or a paste: ones on disk go by path, a pasted picture is sent as a small JPEG. */
  async function addFiles(list) {
    const files = [...list];
    const onDisk = [];
    for (const f of files) {
      const p = window.opscode?.pathForFile?.(f) ?? "";
      if (p) { onDisk.push(p); continue; }
      if (!f.type.startsWith("image/")) { toast(`${f.name || "That item"} has no file on disk to attach`); continue; }
      if (!room(1)) break;
      const entry = { key: ++seq, name: f.name || "pasted-image.png", kind: "image", status: "adding", thumb: URL.createObjectURL(f) };
      items.push(entry);
      render();
      try {
        const blob = await shrink(f);
        const { items: got } = await call({ name: (f.name || "pasted-image").replace(/\.[^.]+$/, "") + ".jpg", data: await toBase64(blob) });
        Object.assign(entry, got[0], { status: "ready" });
      } catch (e) { items = items.filter((x) => x !== entry); toast(e.message); }
      render();
    }
    if (onDisk.length) await addPaths(onDisk);
  }

  async function pick(kind) {
    try { await addPaths((await window.opscode?.pickAttachments?.(kind)) ?? []); }
    catch (e) { toast(e.message); }
  }

  return {
    el: tray,
    pick,
    addPaths,
    addFiles,
    get count() { return items.length; },
    get busy() { return items.some((a) => a.status === "adding"); },
    /** What was added, for sending and for showing in the sent message. */
    ready: () => items.filter((a) => a.status === "ready").map(({ path, name, kind, files, thumb, ref }) => ({ path, name, kind, ...(files !== undefined ? { files } : {}), ...(ref ? { ref: true } : {}), ...(thumb ? { thumb } : {}) })),
    clear() { items = []; render(); },
    /** Takes items already imported elsewhere (a draft handing its attachments to a new chat). */
    set(list) { items = list.map((a) => ({ key: ++seq, ...a, status: "ready" })); render(); },
  };
}
