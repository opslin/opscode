// Accounts for the coding agents (Claude Code, Codex, Antigravity, Qoder): who is signed in, sign in, sign out, add, switch.
// Opscode only drives the programs' own sign-in: the browser page belongs to Claude or ChatGPT, so no password
// or token ever passes through here. Used by Settings -> Models & keys, the chat's account chip, Conductor
// settings and the Usage page.

import { h } from "./dom.js";
import { icon } from "./icons.js";
import { state, toast } from "./store.js";
import { confirmDialog, showDialog, closeDialog } from "./dialogs.js";
import { openMenu } from "./popover.js";
import { CLAUDE_MARK, CODEX_TILE, CODEX_GLYPH } from "./brandmarks.js";
import { icon as glyph } from "./icons.js";

export const ENGINES = {
  "claude-code": { id: "claude-code", name: "Claude Code", who: "Claude", shared: "The claude command in Terminal uses it too, so it is signed out as well.", site: "claude.com/claude-code" },
  codex: { id: "codex", name: "Codex", who: "ChatGPT", shared: "Codex in the ChatGPT app and the codex command use it too, so they are signed out as well.", site: "" },
  antigravity: { id: "antigravity", name: "Antigravity", who: "Google", shared: "The agy command uses it too, so it is signed out as well.", site: "antigravity.google" },
  qoder: { id: "qoder", name: "Qoder", who: "Qoder", shared: "The qoder command in Terminal uses it too, so it is signed out as well.", site: "qoder.com/cli" },
};
/** What to do when a program is not on this Mac. */
const INSTALL = {
  "claude-code": (E) => `Install Claude Code (${E.site}), then press Check.`,
  codex: () => "Install Codex, or the ChatGPT app (it includes Codex), then press Check.",
  antigravity: () => "Install Antigravity and its agy command, then press Check.",
  qoder: () => "Install the Qoder command: curl -fsSL https://qoder.com/install | bash in Terminal, then press Check.",
};
const NS = "http://www.w3.org/2000/svg";
const svgEl = (tag, attrs = {}, ...kids) => { const n = document.createElementNS(NS, tag); for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, String(v)); n.append(...kids); return n; };

let gradient = 0;
/** The brand tile: Claude's orange spark, or Codex's gradient glyph. */
export function engineLogo(engine, size = 36) {
  // Antigravity: its own colours on a white tile. Qoder: its mark (white with the green accent) on a dark tile.
  if (engine === "antigravity") return h("span", { class: "ac-logo ac-logo-tile ac-logo-white", dataset: { engine }, style: `--s:${size}px` }, h("img", { src: "brand/engines/antigravity-color.svg", alt: "", draggable: false }));
  if (engine === "qoder") return h("span", { class: "ac-logo ac-logo-tile", dataset: { engine }, style: `--s:${size}px;background:#101312` }, glyph("engine-qoder-color", "icon"));
  const codex = engine === "codex";
  const s = svgEl("svg", { viewBox: codex ? "0 0 24 24" : "0 0 100 100", width: size, height: size, "aria-hidden": "true" });
  if (codex) {
    const id = `ac-cx-${gradient++}`;
    s.append(
      svgEl("defs", {}, svgEl("linearGradient", { id, gradientUnits: "userSpaceOnUse", x1: 12, x2: 12, y1: 3, y2: 21 }, svgEl("stop", { "stop-color": "#B1A7FF" }), svgEl("stop", { offset: ".5", "stop-color": "#7A9DFF" }), svgEl("stop", { offset: "1", "stop-color": "#3941FF" }))),
      svgEl("path", { d: CODEX_TILE, fill: "#fff" }), svgEl("path", { d: CODEX_GLYPH, fill: `url(#${id})` }));
  } else {
    s.append(svgEl("rect", { width: 100, height: 100, rx: 23, fill: "#D97757" }), svgEl("path", { d: CLAUDE_MARK, fill: "#fff", transform: "translate(17 17) scale(.66)" }));
  }
  return h("span", { class: "ac-logo", dataset: { engine }, style: `--s:${size}px` }, s);
}

// ---- words and data --------------------------------------------------------------------------------------
const PLAN = { pro: "Pro", max: "Max", team: "Team", plus: "Plus", free: "Free", go: "Go", enterprise: "Enterprise", edu: "Edu", business: "Business", prolite: "Pro Lite", promax: "Pro Max" };
export const planName = (p) => (p ? PLAN[p] ?? p.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase()) : null);
const METHOD = { "claude.ai": "Claude subscription", console: "Anthropic Console", sso: "Single sign-on", chatgpt: "ChatGPT account", google: "Google account", qoder: "Qoder account", api_key: "API key", oauth_token: "Access token" };
export const methodName = (m) => (m ? METHOD[m] ?? m : null);

/** The Check button is working: the cards say "Checking…" until their program answers anew. */
export const checking = { on: false, since: 0 };

export const accountsOf = (engine) => (state.accounts ?? []).filter((a) => a.engine === engine);
export const activeAccount = (engine) => accountsOf(engine).find((a) => a.active);
export const signedIn = (a) => !!a?.status?.signed_in;
/** The headline for an account: its email. */
export function accountTitle(a) {
  const s = a.status;
  if (!s) return "Checking…";
  if (!s.signed_in) return a.is_default ? "Not signed in" : "Signed out";
  if (s.email) return s.email;
  if (s.method === "api_key") return "API key";
  // Antigravity and Qoder do not say who is signed in: an added account is named by when it was added.
  if (!a.is_default && (a.engine === "antigravity" || a.engine === "qoder")) return `Account added ${new Date(a.added_at).toLocaleDateString([], { day: "numeric", month: "short" })}`;
  return a.is_default ? "Signed in (this Mac's account)" : "Signed in";
}
/** A short label for tight places (the chat's account chip): the part of the email before the @. */
export function accountShort(a) {
  const t = a.status?.email ?? accountTitle(a);
  const i = t.indexOf("@");
  const w = i > 0 ? t.slice(0, i) : t;
  return w.length > 16 ? `${w.slice(0, 15)}…` : w;
}
/** The account a chat will use: the one it is pinned to, else the one new chats use. */
export function accountForChat(engine, pins) {
  const list = accountsOf(engine);
  return list.find((a) => a.id === pins?.[engine]) ?? list.find((a) => a.active) ?? list[0];
}
const HUES = [18, 200, 262, 142, 330, 38, 172, 290];
function hueOf(text) { let n = 0; for (const c of text) n = (n * 31 + c.charCodeAt(0)) >>> 0; return HUES[n % HUES.length]; }
export function avatar(a, size = 34) {
  const t = a.status?.email ?? (a.status?.signed_in ? (a.engine === "antigravity" ? "G" : a.engine === "qoder" ? "Q" : "?") : "·");
  const on = a.status?.signed_in;
  return h("span", { class: `ac-avatar${on ? "" : " off"}`, style: `--s:${size}px;--h:${hueOf(a.status?.email ?? a.id)}`, "aria-hidden": "true" }, on ? t.slice(0, 1).toUpperCase() : icon("x"));
}
const ago = (iso) => {
  const s = Math.max(0, (Date.now() - Date.parse(iso)) / 1000);
  return s < 90 ? "just now" : s < 5400 ? `${Math.round(s / 60)} min ago` : s < 129600 ? `${Math.round(s / 3600)} h ago` : `${Math.round(s / 86400)} days ago`;
};
const pill = (kind, text) => h("span", { class: `ac-pill ac-pill-${kind}` }, h("i"), text);

async function call(method, params) {
  try { return await state.client.call(method, params); }
  catch (e) { toast(e.message); throw e; }
}
/** Re-reads who is signed in (cheap: the programs' own status commands). */
export async function reloadAccounts(refresh = true) {
  try { const r = await state.client.call("accounts.list", { refresh }); setAccountsHook?.(r.accounts, r.login); return r; }
  catch (e) { toast(`Couldn't read the accounts: ${e.message}`); return null; }
}
let setAccountsHook = null;
/** app.js gives the place that stores accounts and re-draws what shows them. */
export function bindAccounts(fn) { setAccountsHook = fn; }

// ---- sign out, use, add ---------------------------------------------------------------------------------------------
export async function signOut(a) {
  const E = ENGINES[a.engine];
  const who = a.status?.email ? `${a.status.email}` : "this account";
  const ok = await confirmDialog(a.is_default
    ? { title: `Sign out of ${E.name} on this Mac?`, body: `This signs out the ${E.who} account this Mac uses (${who}). ${E.shared} You can sign in again here any time.`, confirm: "Sign out", danger: true }
    : { title: `Sign out of ${who}?`, body: `This signs ${who} out of ${E.name} and removes it from Opscode. Chats that ran on it carry on with the account new chats use.`, confirm: "Sign out", danger: true });
  if (!ok) return false;
  try { await state.client.call("accounts.logout", { engine: a.engine, account_id: a.id }); toast(`Signed out of ${E.name}${a.is_default ? "" : ` (${who})`}`); return true; }
  catch (e) { toast(e.message, 6000); return false; }
}

export async function useAccount(a) {
  const E = ENGINES[a.engine];
  const ok = await confirmDialog({ title: `Use ${accountTitle(a)} for new chats?`, body: `New ${E.name} chats start on this account. Chats already running keep the account they started on.`, confirm: "Use this account" });
  if (!ok) return false;
  try { await state.client.call("accounts.switch", { engine: a.engine, account_id: a.id }); toast(`New ${E.name} chats use ${accountTitle(a)}`); return true; }
  catch (e) { toast(e.message, 6000); return false; }
}

// ---- the sign-in dialog -------------------------------------------------------------------------------------------------
let session = null; // { render() } of the open sign-in dialog
/** app.js: the runtime reported the open sign-in's state. */
export function loginChanged(login) { state.login = login; session?.render(); }
/** app.js: accounts changed (the dialog's result line reads who signed in). */
export function accountsChanged() { session?.render(); }

const METHODS = [
  ["claudeai", "Claude subscription", "Pro, Max, Team or Enterprise. Chats use your plan's limits."],
  ["console", "Anthropic Console", "An API account. Chats are billed to it by usage."],
  ["sso", "Single sign-on", "Your company's identity provider."],
];

/** Sign in (again) to `accountId`, or add another account beside the existing ones. */
export function signIn({ engine, accountId, newAccount = false }) {
  const E = ENGINES[engine];
  let method = "claudeai";
  let step = "choose"; // choose | waiting | result
  let busy = false;
  let loginId = null;
  const email = h("input", { class: "input", type: "email", placeholder: "you@company.com", autocomplete: "off", spellcheck: false, "aria-label": "Email (optional)" });
  const code = h("input", { class: "input mono", placeholder: "Paste the code here", autocomplete: "off", spellcheck: false, "aria-label": "Code from the browser" });
  const body = h("div", { class: "dialog-body ac-dlg" });
  const title = newAccount ? `Add a ${E.name} account` : `Sign in to ${E.name}`;

  const close = () => closeDialog();
  const start = async () => {
    if (busy) return;
    busy = true; render();
    try {
      const r = await state.client.call("accounts.login_start", { engine, ...(newAccount ? { new_account: true } : { account_id: accountId }), ...(engine === "claude-code" ? { method } : {}), ...(engine === "claude-code" && email.value.trim() ? { email: email.value.trim() } : {}) });
      loginId = r.login.id; state.login = r.login; step = "waiting";
    } catch (e) { toast(e.message, 6000); }
    busy = false; render();
  };
  const cancelOpen = () => { if (step === "waiting" && loginId) void state.client.call("accounts.login_cancel", { login_id: loginId }).catch(() => {}); };
  const copy = async (url) => { try { await navigator.clipboard.writeText(url); toast("Link copied"); } catch { toast("Couldn't copy: select the link and copy it"); } };
  const submitCode = async () => {
    const v = code.value.trim();
    if (!v || !loginId) return;
    try { await state.client.call("accounts.login_code", { login_id: loginId, code: v }); code.value = ""; toast("Code sent"); }
    catch (e) { toast(e.message, 6000); }
  };

  function render() {
    const login = state.login && state.login.id === loginId ? state.login : null;
    if (step === "waiting" && login && (login.state === "done" || login.state === "failed" || login.state === "cancelled")) step = "result";
    const kids = [];
    if (step === "choose") {
      kids.push(
        h("p", { class: "ac-lead" }, engine === "codex"
          ? "Opscode opens your browser so Codex can sign you in with your ChatGPT account. Opscode never sees your password."
          : engine === "antigravity" ? "Opscode opens your browser so Antigravity can sign you in with your Google account (your Gemini plan). Opscode never sees your password."
          : engine === "qoder" ? "Opscode opens your browser so Qoder can sign you in with your Qoder account. Opscode never sees your password."
          : "Opscode opens your browser so Claude Code can sign you in. Opscode never sees your password."),
        engine === "claude-code" ? h("div", { class: "ac-methods", role: "radiogroup", "aria-label": "How to sign in" }, ...METHODS.map(([id, label, help]) =>
          h("button", { class: "ac-method", type: "button", role: "radio", "aria-checked": String(method === id), onclick: () => { method = id; render(); } },
            h("span", { class: "ac-radio" }), h("span", { class: "ac-method-text" }, h("strong", {}, label), h("span", {}, help))))) : null,
        engine === "claude-code" ? h("label", { class: "field" }, h("span", { class: "field-label" }, "Email ", h("span", { class: "ac-opt" }, "optional")), email, h("span", { class: "field-help" }, "Fills in the sign-in page for you.")) : null,
        newAccount ? h("p", { class: "ac-note" }, icon("shield"), `Your other ${E.name} account stays signed in. The new one gets its own private folder, so the two never mix.`) : null,
        h("div", { class: "dialog-foot" }, h("span", { class: "grow" }), h("button", { class: "btn btn-sm", type: "button", onclick: close }, "Cancel"),
          h("button", { class: "btn btn-sm btn-primary", type: "button", disabled: busy, onclick: start }, busy ? "Starting…" : "Continue in browser", icon("arrow-up-right"))));
    } else if (step === "waiting") {
      const url = login?.url;
      kids.push(
        h("div", { class: "ac-wait" }, h("span", { class: "ac-ring" }, engineLogo(engine, 44)), h("div", {}, h("strong", {}, "Waiting for you in the browser…"), h("p", {}, engine === "codex" ? "Finish signing in with ChatGPT on the page that opened." : engine === "antigravity" ? "Finish signing in with Google on the page that opened." : engine === "qoder" ? "Finish signing in with Qoder on the page that opened." : "Finish signing in on the page that opened. This window updates by itself."))),
        url ? h("div", { class: "ac-link" }, h("span", { class: "ac-link-label" }, "The page didn't open?"), h("code", { title: url }, url), h("div", { class: "ac-link-actions" },
          h("button", { class: "btn btn-sm", type: "button", onclick: () => window.open(url, "_blank", "noopener") }, icon("external"), "Open link"),
          h("button", { class: "btn btn-sm", type: "button", onclick: () => copy(url) }, icon("copy"), "Copy link"))) : h("div", { class: "ac-link" }, h("span", { class: "ac-link-label" }, "Getting the sign-in page…")),
        login?.can_paste ? h("details", { class: "ac-paste" }, h("summary", {}, "The browser shows a code instead of coming back here?"),
          h("div", { class: "ac-paste-row" }, code, h("button", { class: "btn btn-sm", type: "button", onclick: submitCode }, "Submit code")),
          h("span", { class: "field-help" }, "The code goes straight to Claude Code and is not kept.")) : null,
        h("div", { class: "dialog-foot" }, h("span", { class: "grow" }, "Closing this window cancels the sign-in."), h("button", { class: "btn btn-sm", type: "button", onclick: close }, "Cancel sign-in")));
    } else {
      const ok = login?.state === "done";
      const acct = ok ? accountsOf(engine).find((a) => a.id === (login?.account_id)) : null;
      kids.push(
        h("div", { class: `ac-result ${ok ? "ok" : "bad"}` }, h("span", { class: "ac-result-mark" }, icon(ok ? "check" : "x")),
          h("div", {}, h("strong", {}, ok ? "You're signed in" : login?.state === "cancelled" ? "Sign-in cancelled" : "Couldn't sign in"),
            ok && acct ? h("p", {}, accountTitle(acct), signedIn(acct) && acct.status.plan ? ` · ${planName(acct.status.plan)}` : "") : null,
            login?.message ? h("p", { class: ok ? "" : "ac-err" }, login.message) : null)),
        h("div", { class: "dialog-foot" }, h("span", { class: "grow" }),
          ok ? null : h("button", { class: "btn btn-sm", type: "button", onclick: () => { step = "choose"; loginId = null; render(); } }, "Try again"),
          h("button", { class: "btn btn-sm btn-primary", type: "button", onclick: close }, ok ? "Done" : "Close")));
    }
    body.replaceChildren(...kids.filter(Boolean));
  }

  session = { render };
  showDialog(h("div", { class: "dialog ac-dialog", role: "dialog", "aria-modal": "true", "aria-label": title },
    h("div", { class: "dialog-head" }, engineLogo(engine, 28), h("h2", {}, title), h("button", { class: "icon-btn", type: "button", "aria-label": "Close", onclick: close }, icon("x"))), body),
  { onClose: () => { cancelOpen(); session = null; } });
  render();
}

// ---- Settings: one card per engine ---------------------------------------------------------------------------------------------
/** The card for one coding agent (`e` is its entry from engines.list). `extras` are rows put under the accounts. */
export function engineCard(e, extras = []) {
  const E = ENGINES[e.id];
  const list = accountsOf(e.id);
  const cur = list.find((a) => a.active) ?? list[0];
  const loaded = (state.accounts ?? []).length > 0;
  const fresh = !checking.on || (cur?.status && Date.parse(cur.status.checked_at) >= checking.since);
  const status = !e.found ? pill("warn", "Not installed") : !loaded || !fresh ? pill("wait", "Checking…") : signedIn(cur) ? pill("ok", "Signed in") : pill("warn", "Not signed in");

  const head = h("div", { class: "ac-head" }, engineLogo(e.id, 44),
    h("div", { class: "ac-head-text" }, h("div", { class: "ac-name" }, E.name, status),
      h("div", { class: "ac-sub" }, e.found ? `${e.version ?? "Installed"} · found on this Mac${e.models.length ? ` · ${e.models.length} model${e.models.length === 1 ? "" : "s"}` : ""}` : (INSTALL[e.id] ?? INSTALL["claude-code"])(E)),
      e.error ? h("div", { class: "ac-sub ac-warn" }, e.error) : null));

  const rows = !e.found ? [] : list.map((a) => accountRow(e, a));
  const signedCount = list.filter(signedIn).length;
  const foot = !e.found ? null : h("div", { class: "ac-foot" },
    signedCount > 1 ? h("button", { class: "btn btn-sm", type: "button", onclick: (ev) => openMenu(ev.currentTarget, [{ heading: `New ${E.name} chats use…` }, ...list.filter(signedIn).map((a) => ({ label: accountTitle(a), description: [planName(a.status.plan), a.status.org].filter(Boolean).join(" · ") || undefined, checked: a.active, onSelect: () => { if (!a.active) void useAccount(a); } }))], { up: false, width: 320 }) }, "Switch account", icon("chevron-down", "icon chip-caret")) : null,
    h("button", { class: "btn btn-sm", type: "button", onclick: () => signIn({ engine: e.id, newAccount: true }) }, icon("plus"), "Add account"),
    h("span", { class: "grow" }),
    h("span", { class: "ac-private" }, icon("shield"), "Sign-in happens in your browser. Opscode never sees your password."));

  return h("section", { class: "set-card ac-card", dataset: { engine: e.id } }, head,
    e.found ? h("div", { class: "ac-accounts" }, ...(rows.length ? rows : [h("div", { class: "ac-empty" }, "Reading who is signed in…")])) : null,
    foot, ...extras);
}

function accountRow(e, a) {
  const s = a.status;
  const on = signedIn(a);
  const E = ENGINES[e.id];
  const detail = on ? [methodName(s.method), s.org && s.org !== s.email && !/'s Organization$/.test(s.org) ? s.org : null].filter(Boolean).join(" · ") : (!s ? "Reading who is signed in…" : s.error) ?? (a.is_default ? `Sign in to use ${E.name} with your ${E.who} account.` : "This account was signed out.");
  const busyBtn = (label, fn, cls = "btn btn-sm") => { const b = h("button", { class: cls, type: "button" }, label); b.addEventListener("click", async () => { b.disabled = true; try { await fn(); } finally { b.disabled = false; } }); return b; };
  return h("div", { class: `ac-row${a.active && on ? " active" : ""}${on ? "" : " off"}`, dataset: { account: a.id } },
    avatar(a),
    h("div", { class: "ac-row-text" },
      h("div", { class: "ac-row-title" }, h("span", { class: "ac-email" }, accountTitle(a)), on && s.plan ? h("span", { class: "ac-plan" }, planName(s.plan)) : null, a.is_default ? h("span", { class: "ac-tag", title: `The ${E.who} account this Mac already uses` }, "This Mac") : null),
      h("div", { class: "ac-row-sub" }, detail, on && a.last_used_at ? ` · used ${ago(a.last_used_at)}` : "")),
    h("div", { class: "ac-row-actions" },
      on && a.active ? h("span", { class: "ac-using", title: `New ${E.name} chats start on this account` }, icon("check"), "In use") : null,
      on && !a.active ? busyBtn("Use", () => useAccount(a)) : null,
      !on ? h("button", { class: "btn btn-sm btn-primary", type: "button", onclick: () => signIn({ engine: e.id, accountId: a.id }) }, "Sign in") : null,
      on ? busyBtn("Sign out", () => signOut(a), "btn btn-ghost btn-sm ac-out") : null));
}

// ---- the account chip in a chat, and a picker used by Conductor settings -------------------------------------------------------------
/** Items for a menu of signed-in accounts on one engine. `currentId` is checked. */
export function accountMenuItems(engine, currentId, onPick) {
  const E = ENGINES[engine];
  const list = accountsOf(engine).filter(signedIn);
  return [{ heading: `${E.name} account` }, ...list.map((a) => ({ label: accountTitle(a), description: [planName(a.status.plan), a.status.org && !/'s Organization$/.test(a.status.org) ? a.status.org : null, a.active ? "new chats use this" : null].filter(Boolean).join(" · ") || undefined, checked: a.id === currentId, onSelect: () => onPick(a) }))];
}
