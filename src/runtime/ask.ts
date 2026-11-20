// Question cards: an agent asks the person to choose (1-4 questions, 2-4 options each, "Other" always possible) and
// waits for the answer inside the same turn, instead of asking in its reply and ending (docs/quality-fix-plan.md, Slice B).
//
// Every engine's way of asking ends up here: Claude Code's AskUserQuestion, Codex's request_user_input, Opscode's own
// ask_user tool (Codex, Antigravity, Qoder, the API agent), and a "Questions:" block at the end of a reply (backup for an
// agent that cannot reach Opscode's tools).

import { ASK_LIMITS, type AskAnswer, type AskOption, type AskQuestion } from "../shared/protocol";
import type { Tool } from "./agent/tools";

export type AskResult = { answers: AskAnswer[] } | { skipped: true; reason: string };

/** Told to every engine (with the other notes). */
export const QUESTION_NOTE =
  "When you need the user's decision, ask with the ask_user tool (in Claude Code: AskUserQuestion) instead of asking in your reply and stopping. Ask 1 to 4 questions at once, each with 2 to 4 short options; put the option you recommend first and add \"(Recommended)\" to its label; add one short line per option saying what it means. The user can always type their own answer, so do not add an \"Other\" option. After the answer, continue the work in the same turn. Do not ask what you can find out yourself, and do not ask for permission to run commands: Opscode asks for that.";

const clip = (v: unknown, n: number): string => (typeof v === "string" ? v.trim().slice(0, n) : "");
const rec = (v: unknown): Record<string, unknown> => (v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : {});

/**
 * Questions from any engine's shape, checked and cut to the limits. Accepts `{question, header, options:[{label,
 * description}|string], multiSelect|multi, id}`. Questions without text or with fewer than 2 options are dropped
 * (a question with no options is still kept when it is the only way to ask: the person then types the answer).
 */
export function normalizeQuestions(raw: unknown): AskQuestion[] {
  const list = Array.isArray(raw) ? raw : [];
  const out: AskQuestion[] = [];
  const ids = new Set<string>();
  for (const item of list.slice(0, 20)) {
    if (out.length >= ASK_LIMITS.QUESTIONS) break;
    const q = rec(item);
    const question = clip(q.question ?? q.text ?? q.prompt, ASK_LIMITS.QUESTION);
    if (!question) continue;
    const seen = new Set<string>();
    const options: AskOption[] = [];
    for (const o of Array.isArray(q.options) ? q.options : []) {
      const r = typeof o === "string" ? { label: o } : rec(o);
      const label = clip(r.label ?? r.title ?? r.value, ASK_LIMITS.LABEL);
      // "Other" is the card's own text box: an agent's "Other" option would only duplicate it.
      if (!label || seen.has(label.toLowerCase()) || /^(other|something else)\b/i.test(label)) continue;
      seen.add(label.toLowerCase());
      const description = clip(r.description ?? r.hint, ASK_LIMITS.DESCRIPTION);
      options.push({ label, ...(description ? { description } : {}) });
      if (options.length >= ASK_LIMITS.OPTIONS) break;
    }
    if (options.length === 1) continue; // one option is not a choice
    let id = clip(q.id, 64) || `q${out.length + 1}`;
    while (ids.has(id)) id = `${id}-${out.length + 1}`;
    ids.add(id);
    const header = clip(q.header, ASK_LIMITS.HEADER);
    out.push({ id, question, options, ...(header ? { header } : {}), ...(q.multiSelect === true || q.multi === true ? { multi: true } : {}) });
  }
  return out;
}

/** Checks the person's answers against the card: known ids, offered labels only, one pick unless multi. */
export function checkAnswers(questions: AskQuestion[], answers: AskAnswer[]): string | null {
  for (const a of answers) {
    const q = questions.find((x) => x.id === a.id);
    if (!q) return `no question "${a.id}" on this card`;
    for (const p of a.picks) if (!q.options.some((o) => o.label === p)) return `"${p}" is not an option of "${q.id}"`;
    if (!q.multi && a.picks.length > 1) return `"${q.id}" takes one answer`;
    if (a.other !== undefined && a.other.length > ASK_LIMITS.OTHER) return "the answer is too long";
    if (!a.picks.length && !a.other?.trim()) return `"${q.id}" has no answer`;
  }
  return null;
}

/** One question's answer in words: the picks, then the person's own words. */
export function answerText(a: AskAnswer | undefined): string {
  if (!a) return "(not answered)";
  const own = a.other?.trim();
  return [...a.picks, ...(own ? [own] : [])].join(", ") || "(not answered)";
}

/** What a model gets back from a question (Opscode's ask_user, the backup message, Codex's tool result). */
export function resultText(questions: AskQuestion[], r: AskResult): string {
  if ("skipped" in r) return `${r.reason} Continue with your best judgment and say in your reply what you assumed.`;
  const lines = questions.map((q) => `- ${q.question} -> ${answerText(r.answers.find((a) => a.id === q.id))}`);
  return `The user answered:\n${lines.join("\n")}\nContinue the work with these answers.`;
}

/**
 * Claude Code's AskUserQuestion wants `answers` keyed by the question text exactly as it sent it: a string, or a list
 * when several were picked. `raw` is the tool's own `questions` input.
 */
export function claudeAnswers(raw: unknown, questions: AskQuestion[], answers: AskAnswer[]): Record<string, string | string[]> {
  const sent = (Array.isArray(raw) ? raw : []).map((x) => rec(x).question).filter((x): x is string => typeof x === "string");
  const out: Record<string, string | string[]> = {};
  for (const q of questions) {
    const a = answers.find((x) => x.id === q.id);
    const key = sent.find((t) => t.trim().slice(0, ASK_LIMITS.QUESTION) === q.question);
    if (!a || !key) continue;
    const own = a.other?.trim();
    const all = [...a.picks, ...(own ? [own] : [])];
    if (!all.length) continue;
    out[key] = q.multi ? all : all.join(", ");
  }
  return out;
}

/** Codex's request_user_input answer: `{answers: {<question id>: {answers: [..]}}}`. */
export function codexAnswers(questions: AskQuestion[], r: AskResult): { answers: Record<string, { answers: string[] }> } {
  const out: Record<string, { answers: string[] }> = {};
  if ("skipped" in r) return { answers: out };
  for (const q of questions) {
    const a = r.answers.find((x) => x.id === q.id);
    if (!a) continue;
    const own = a.other?.trim();
    out[q.id] = { answers: [...a.picks, ...(own ? [own] : [])] };
  }
  return { answers: out };
}

/** The card's one-line summary. */
export function questionSummary(questions: AskQuestion[]): string {
  const first = questions[0];
  if (!first) return "Question";
  const more = questions.length > 1 ? ` (+${questions.length - 1} more)` : "";
  return `${first.header ? `${first.header}: ` : ""}${first.question}${more}`.slice(0, 160);
}

/** Opscode's own question tool (for engines without one, and the API agent). */
export function askTool(): Tool {
  return {
    def: {
      name: "ask_user",
      description: "Ask the user to choose, and wait for the answer (the task keeps going after it). 1-4 questions, each with 2-4 short options; the recommended option first with \"(Recommended)\" in its label. The user can always type their own answer.",
      schema: {
        type: "object",
        properties: {
          questions: {
            type: "array",
            minItems: 1,
            maxItems: ASK_LIMITS.QUESTIONS,
            items: {
              type: "object",
              properties: {
                question: { type: "string", description: "The full question" },
                header: { type: "string", description: "A 1-3 word title" },
                options: { type: "array", minItems: 2, maxItems: ASK_LIMITS.OPTIONS, items: { type: "object", properties: { label: { type: "string" }, description: { type: "string" } }, required: ["label"] } },
                multiSelect: { type: "boolean", description: "Several options may be picked" },
              },
              required: ["question", "options"],
            },
          },
        },
        required: ["questions"],
      },
    },
    kind: "note",
    describe: (i) => ({ summary: questionSummary(normalizeQuestions(i.questions)) }),
    async run(i, ctx) {
      const questions = normalizeQuestions(i.questions);
      if (!questions.length) return { output: "Give 1-4 questions, each with a question and 2-4 options.", is_error: true };
      if (!ctx.ask) return { output: resultText(questions, { skipped: true, reason: "Nobody can answer questions here." }), is_error: false };
      return { output: resultText(questions, await ctx.ask(questions)), is_error: false };
    },
  };
}

/**
 * Backup for an agent that cannot reach Opscode's tools: a reply that ends with
 *   Questions:
 *   1. Deploy now? [Yes, deploy (Recommended) | Not yet]
 * becomes a card; the person's answer is then sent as the next message. Only the last block of the reply counts, and
 * only when every line after "Questions:" is a numbered question with options in [ ... | ... ].
 */
export function parseQuestionBlock(reply: string): AskQuestion[] {
  const heads = [...reply.matchAll(/(^|\n)[ \t]*\**questions?\**[ \t]*:[ \t]*\n/gi)];
  const head = heads.at(-1);
  if (!head || head.index === undefined) return [];
  const body = reply.slice(head.index + head[0].length).split("\n").map((l) => l.trim()).filter(Boolean);
  if (!body.length) return [];
  const raw: { question: string; options: string[]; multiSelect?: boolean }[] = [];
  for (const line of body) {
    const m = /^(?:\d+[.)]|[-*])\s*(.+?)\s*\[([^\]]+)\](\s*\(pick (?:any|several)\))?\s*$/i.exec(line);
    if (!m) return [];
    raw.push({ question: m[1]!, options: m[2]!.split("|").map((x) => x.trim()).filter(Boolean), ...(m[3] ? { multiSelect: true } : {}) });
  }
  return normalizeQuestions(raw);
}

/** The backup's note (only for agents that cannot use ask_user). */
export const QUESTION_BLOCK_NOTE =
  "When you need the user's decision, end your reply with a block like this and stop:\nQuestions:\n1. <question> [<option you recommend> (Recommended) | <other option>]\nOne line per question (at most 4), 2 to 4 options in [ ] separated by |. The user can also type their own answer.";

/** The next message after a backup card was answered. */
export function answerMessage(questions: AskQuestion[], r: AskResult): string {
  if ("skipped" in r) return "I skipped your questions. Continue with your best judgment and say what you assumed.";
  return `My answers:\n${questions.map((q) => `- ${q.question} -> ${answerText(r.answers.find((a) => a.id === q.id))}`).join("\n")}`;
}
