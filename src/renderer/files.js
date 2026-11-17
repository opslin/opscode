// Files surface: project-relative browser (fs.list) + read-only preview (fs.read).

import { h, formatSize } from "./dom.js";
import { icon } from "./icons.js";
import { state } from "./store.js";

export function createFiles(workspace) {
  let dir = "";
  let openPath = null;

  const crumbs = h("div", { class: "crumbs" });
  const list = h("ul", { class: "file-list" });
  const previewHead = h("div", { class: "preview-head" }, h("span", { class: "grow" }, "Select a file"));
  const previewBody = h("div", { class: "preview-body" }, h("div", { class: "preview-empty" }, "Select a file to preview it"));
  const root = h(
    "div",
    { class: "files pane-surface" },
    h("div", { class: "files-list-pane" }, crumbs, list),
    h("div", { class: "preview" }, previewHead, previewBody),
  );

  function renderCrumbs(rel) {
    const parts = rel === "." || rel === "" ? [] : rel.split("/");
    const items = [h("button", { class: "crumb", type: "button", onclick: () => open("") }, workspace.name)];
    parts.forEach((part, i) => {
      items.push(h("span", { class: "crumb-sep" }, "/"), h("button", { class: "crumb", type: "button", onclick: () => open(parts.slice(0, i + 1).join("/")) }, part));
    });
    crumbs.replaceChildren(...items);
  }

  async function open(rel) {
    dir = rel;
    await refresh();
  }

  async function refresh() {
    try {
      const res = await state.client.call("fs.list", { workspace_id: workspace.id, path: dir });
      renderCrumbs(res.path);
      const rows = res.entries.map((e) => {
        const child = res.path === "." ? e.name : `${res.path}/${e.name}`;
        const glyph = e.kind === "dir" ? "folder" : e.kind === "symlink" ? "link" : "file";
        return h(
          "li",
          {},
          h(
            "button",
            {
              class: `file file--${e.kind}`,
              type: "button",
              "aria-current": child === openPath ? "true" : "false",
              onclick: () => (e.kind === "file" ? preview(child) : open(child)),
            },
            icon(glyph),
            h("span", { class: "file__name" }, e.name),
            h("span", { class: "file__meta" }, e.kind === "file" ? formatSize(e.size) : ""),
          ),
        );
      });
      if (rows.length === 0) rows.push(h("li", { class: "file-note" }, "This folder is empty."));
      if (res.truncated) rows.push(h("li", { class: "file-note" }, "List truncated."));
      list.replaceChildren(...rows);
    } catch (err) {
      // e.g. a symlink that points outside the project (-32005)
      list.replaceChildren(h("li", { class: "file-note" }, `Can't open: ${err.message}`));
    }
  }

  async function preview(rel) {
    openPath = rel;
    previewHead.replaceChildren(h("span", { class: "grow" }, rel));
    previewBody.replaceChildren(h("div", { class: "preview-empty" }, "Loading…"));
    for (const b of list.querySelectorAll(".file")) b.setAttribute("aria-current", "false");
    try {
      const res = await state.client.call("fs.read", { workspace_id: workspace.id, path: rel, max_bytes: 256 * 1024 });
      previewHead.replaceChildren(h("span", { class: "grow" }, res.path), h("span", {}, `${formatSize(res.size)}${res.truncated ? " · truncated" : ""}`));
      if (res.encoding !== "utf8") {
        previewBody.replaceChildren(h("div", { class: "preview-empty" }, `Binary file (${formatSize(res.size)}) — no preview.`));
        return;
      }
      const lines = res.content.split("\n");
      if (lines.length > 1 && lines[lines.length - 1] === "") lines.pop();
      const frag = document.createDocumentFragment();
      lines.forEach((ln, i) => frag.append(h("div", { class: "preview-line" }, h("span", { class: "preview-ln" }, String(i + 1)), h("span", { class: "preview-code" }, ln || " "))));
      previewBody.replaceChildren(frag);
      previewBody.scrollTop = 0;
      for (const b of list.querySelectorAll(".file")) if (b.querySelector(".file__name")?.textContent === rel.split("/").pop()) b.setAttribute("aria-current", "true");
    } catch (err) {
      previewBody.replaceChildren(h("div", { class: "preview-empty" }, `Can't read: ${err.message}`));
    }
  }

  return { el: root, refresh, open };
}

/** One file, read-only (side panel "file" tabs: from Artifacts, search, @). */
export function createFileView(workspace, path) {
  const head = h("div", { class: "preview-head" }, h("span", { class: "grow mono" }, path));
  const body = h("div", { class: "preview-body" }, h("div", { class: "preview-empty" }, "Loading…"));
  const root = h("div", { class: "file-view pane-surface" }, head, body);
  async function refresh() {
    try {
      const res = await state.client.call("fs.read", { workspace_id: workspace.id, path, max_bytes: 512 * 1024 });
      head.replaceChildren(h("span", { class: "grow mono" }, res.path), h("span", {}, `${formatSize(res.size)}${res.truncated ? " · truncated" : ""}`));
      if (res.encoding !== "utf8") { body.replaceChildren(h("div", { class: "preview-empty" }, `Binary file (${formatSize(res.size)}) — no preview.`)); return; }
      const lines = res.content.split("\n");
      if (lines.length > 1 && lines[lines.length - 1] === "") lines.pop();
      const frag = document.createDocumentFragment();
      lines.forEach((ln, i) => frag.append(h("div", { class: "preview-line" }, h("span", { class: "preview-ln" }, String(i + 1)), h("span", { class: "preview-code" }, ln || " "))));
      body.replaceChildren(frag);
    } catch (err) {
      body.replaceChildren(h("div", { class: "preview-empty" }, `Can't read: ${err.message}`));
    }
  }
  void refresh();
  return { el: root, refresh };
}
