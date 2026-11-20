// The question card: an agent asks the person to choose, and the card sits on top of the message box while the work
// waits (docs/quality-fix-plan.md, Slice B). 1-4 questions, one at a time; 2-4 options each (the first is the agent's
// recommendation); "Other" with a text box is always there; Skip lets the agent decide.
//
// Keys: 1-4 pick an option, Enter goes on (or sends on the last question), Esc hides the card (it can be opened again
// from the chat's "Waiting for your answer" line).

import { h } from "./dom.js";
import { icon } from "./icons.js";

const RECOMMENDED = /\s*\((recommended|suggested)\)\s*$/i;

/**
 * opts.onAnswer(answers) / opts.onSkip(): resolve the card (async; a rejection keeps it open).
 * Returns { el, show(card), hide(), reopen(), isOpen(), openCall(), typedAnswer(text) }.
 */
export function createAskCard(opts) {
  let card = null; // { turnId, callId, questions }
  let step = 0;
  let picks = []; // per question: Set of labels
  let other = []; // per question: text
  let busy = false;
  const el = h("div", { class: "ask-card", hidden: true, role: "dialog", "aria-label": "The agent asks you" });

  const q = () => card.questions[step];
  const answered = (i) => picks[i].size > 0 || other[i].trim() !== "";

  function answers() {
    return card.questions.map((x, i) => ({ id: x.id, picks: [...picks[i]], ...(other[i].trim() ? { other: other[i].trim() } : {}) })).filter((a, i) => answered(i));
  }

  async function finish(fn) {
    if (busy) return;
    busy = true;
    paint();
    try { await fn(); hide(); }
    catch { /* the caller showed why; the card stays open */ }
    finally { busy = false; if (card) paint(); }
  }

  const send = () => finish(() => opts.onAnswer(card, answers()));
  const skip = () => finish(() => opts.onSkip(card));

  function next() {
    if (!answered(step)) return;
    if (step < card.questions.length - 1) { step++; paint(); focusFirst(); }
    else void send();
  }

  function toggle(label) {
    const set = picks[step];
    if (q().multi) { if (set.has(label)) set.delete(label); else set.add(label); }
    else { set.clear(); set.add(label); other[step] = ""; }
    paint();
  }

  function focusFirst() {
    requestAnimationFrame(() => el.querySelector(".ask-opt[aria-checked=true], .ask-opt")?.focus());
  }

  function paint() {
    if (!card) return;
    const cur = q();
    const last = step === card.questions.length - 1;
    const multi = !!cur.multi;
    const otherBox = h("input", {
      class: "ask-other-input", type: "text", placeholder: "Type your own answer…", value: other[step], maxlength: 4000,
      "aria-label": "Your own answer",
      oninput: (e) => { other[step] = e.target.value; if (!multi && other[step].trim()) picks[step].clear(); syncButtons(); syncChecks(); },
      onkeydown: (e) => { if (e.key === "Enter") { e.preventDefault(); next(); } else if (e.key === "Escape") { e.preventDefault(); hide(true); } e.stopPropagation(); },
    });
    const options = cur.options.map((o, i) => {
      const rec = i === 0 && RECOMMENDED.test(o.label);
      const label = o.label.replace(RECOMMENDED, "");
      const on = picks[step].has(o.label);
      return h("button", { class: "ask-opt", type: "button", role: multi ? "checkbox" : "radio", "aria-checked": String(on), dataset: { label: o.label },
        onclick: () => { toggle(o.label); if (!multi && !last) setTimeout(next, 120); } },
        h("span", { class: "ask-key" }, String(i + 1)),
        h("span", { class: "ask-opt-text" },
          h("span", { class: "ask-opt-label" }, label, rec ? h("span", { class: "ask-rec" }, "Recommended") : null),
          o.description ? h("span", { class: "ask-opt-desc" }, o.description) : null),
        h("span", { class: `ask-mark${multi ? " box" : ""}` }, on ? icon("check") : null));
    });
    const backBtn = h("button", { class: "btn btn-ghost btn-sm", type: "button", disabled: step === 0 || busy, onclick: () => { step--; paint(); } }, "Back");
    const nextBtn = h("button", { class: "btn btn-primary btn-sm ask-next", type: "button", disabled: !answered(step) || busy, onclick: next }, busy ? "Sending…" : last ? "Send" : "Next", last ? null : icon("arrow-right"));
    function syncButtons() { nextBtn.disabled = !answered(step) || busy; }
    function syncChecks() { for (const b of el.querySelectorAll(".ask-opt")) { const on = picks[step].has(b.dataset.label); b.setAttribute("aria-checked", String(on)); b.querySelector(".ask-mark").replaceChildren(...(on ? [icon("check")] : [])); } }
    // Native replaceChildren prints null as text: keep only real nodes.
    el.replaceChildren(...[
      h("div", { class: "ask-head" },
        cur.header ? h("span", { class: "ask-chip" }, cur.header) : null,
        h("span", { class: "ask-wait" }, h("span", { class: "ask-dot" }), "Waiting for your answer"),
        h("span", { class: "grow" }),
        h("button", { class: "icon-btn ask-hide", type: "button", title: "Hide (Esc). The work keeps waiting.", "aria-label": "Hide the question", onclick: () => hide(true) }, icon("x"))),
      h("div", { class: "ask-q" }, cur.question),
      multi ? h("div", { class: "ask-hint" }, "Pick one or more.") : null,
      h("div", { class: "ask-opts", role: multi ? "group" : "radiogroup" }, ...options,
        h("label", { class: "ask-other" }, h("span", { class: "ask-key" }, String(cur.options.length + 1)), otherBox)),
      h("div", { class: "ask-foot" },
        card.questions.length > 1 ? h("span", { class: "ask-count" }, `Question ${step + 1} of ${card.questions.length}`) : null,
        h("span", { class: "grow" }),
        h("button", { class: "btn btn-ghost btn-sm ask-skip", type: "button", disabled: busy, title: "The agent goes on with its own best judgment", onclick: () => void skip() }, "Skip"),
        card.questions.length > 1 ? backBtn : null,
        nextBtn)].filter(Boolean));
  }

  function onKey(e) {
    if (!card || el.hidden || busy) return;
    if (e.target instanceof HTMLTextAreaElement || (e.target instanceof HTMLInputElement && !e.target.classList.contains("ask-opt"))) return;
    const n = Number(e.key);
    if (n >= 1 && n <= q().options.length) { e.preventDefault(); toggle(q().options[n - 1].label); return; }
    if (n === q().options.length + 1) { e.preventDefault(); el.querySelector(".ask-other-input")?.focus(); return; }
    if (e.key === "Enter") { e.preventDefault(); next(); }
    else if (e.key === "Escape") { e.preventDefault(); hide(true); }
  }
  el.addEventListener("keydown", onKey);

  function show(next) {
    const same = card && card.callId === next.callId;
    card = next;
    if (!same) {
      step = 0;
      picks = next.questions.map(() => new Set());
      other = next.questions.map(() => "");
    }
    el.hidden = false;
    paint();
    focusFirst();
  }

  function hide(keep = false) {
    el.hidden = true;
    if (!keep) card = null;
    opts.onHide?.(keep);
  }

  return {
    el,
    show,
    hide: () => hide(false),
    /** Opens a card that was hidden with Esc. */
    reopen: () => { if (card) { el.hidden = false; paint(); focusFirst(); } },
    isOpen: () => !!card,
    openCall: () => card?.callId ?? null,
    /** The message box was used while a card is open: its text answers the current question. */
    typedAnswer: (text) => {
      if (!card) return false;
      other[step] = text;
      if (!q().multi) picks[step].clear(); // several picks + your own words both count
      void finish(() => opts.onAnswer(card, answers()));
      return true;
    },
  };
}
