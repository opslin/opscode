// The three built-in worker skills a Conductor hands out with a brief: how to fix
// a bug, how to build a feature, and how to review. Short on purpose: each is paid
// for in every worker that gets it. Wording is Opscode's own; the habits follow
// docs/prompt-playbook.md (reproduce first, first error not last, smallest fix,
// prove the requirement itself, reviewer trusts nothing it did not run).

export type JobKind = "fix" | "feature" | "chore" | "plan" | "brand" | "art" | "asset" | "ui" | "visual" | "qa";
export const JOB_KINDS: readonly JobKind[] = ["fix", "feature", "chore", "plan", "brand", "art", "asset", "ui", "visual", "qa"];
/** Kinds whose work is files on disk (images, SVGs, documents): the runtime checks the Check line's paths exist. */
export const FILE_KINDS: readonly JobKind[] = ["brand", "art", "asset"];
export const isJobKind = (v: unknown): v is JobKind => typeof v === "string" && (JOB_KINDS as readonly string[]).includes(v);

const FIX = `How to fix (follow in order):
1. Reproduce it first. Turn the complaint into one failing command, test or request. If you cannot reproduce it, say so in the report instead of guessing a fix.
2. Make sure you are reading the code that actually runs: the right package, branch and copy (repos often hold old copies under _reference or backup folders).
3. Trace to the first error, not the last. Later errors are usually fallout. When several cases fail, compare two or three and name what they share.
4. Classify before touching code: a real bug, an environment difference, or a flake. Only a real bug gets a code fix; say which you found.
5. Make the smallest fix at the root cause, not where the error surfaced. Do not refactor around it.
6. Prove it: a failing test written before the fix that now passes, or the reproduce command now clean. Run what already exists near the change too.
No planning stage: reproduce, fix, prove, report.`;

const FEATURE = `How to build (follow in order):
1. Read the brief's Done when lines first; every one is a check you must satisfy. Missing or unclear ones: write what you will take them to mean in the report, or ask if a wrong guess would be costly.
2. Look for what exists before writing anything: the nearest similar feature in this repo (same module layout, same patterns). Copy and adapt beats new code.
3. Make the smallest complete change. No extra options, no refactors the brief did not ask for, nothing outside Don't touch.
4. New or changed behaviour gets a test in this repo's own style: good input, bad input, and the edge the brief names.
5. Migrations and data: never edit an applied migration; add a new one. Secrets stay in env files by name, never printed.
6. Prove every Done when line with a command before you report, and put the result in the Check line.`;

const PLAN = `How to write a planning document (spec, gap report or plan):
1. Read only what the brief names: the person's words, the files it lists, and the code the Library or the brief points at. Do not explore the whole repository.
2. Write the one file the brief names, nothing else. No code changes.
3. Make every item checkable: each feature or task gets "Done when" lines a command or a person can verify. Say which files a task touches.
4. Open questions go first, each with the answer you recommend. Do not guess at things only the person can decide.
5. Prefer what exists: name the module or file to reuse before proposing anything new.
6. Keep it short: a list, not essays. Check line: the file path you wrote and how many items it holds.`;

// ---- brand, art direction, assets, screens, visual review (M3) ----

const BRAND = `How to write the brand kit (docs/opscode/brand/brand.md, used by every image and screen later):
1. Find the brand that already exists before inventing anything: logo files, theme code (tailwind config, CSS variables, Flutter theme or colors file), app icons, existing images and any earlier image prompts (*prompt*.txt / *.md). Open the logo and two or three best existing images to see them.
2. Write these sections, short and exact:
   - Palette: each colour as hex with its role (dominant, accent, background, text, success/error), and which pairs pass contrast.
   - Type: font families and weights for headings and body.
   - Shape: corner radius, stroke width, shadow style.
   - Icon style (e.g. "premium soft glossy 3D clay and glass" or "1.5px monoline outline") and illustration/3D style.
   - The style header: ONE sentence pasted at the start of every image prompt: rendering style, palette hex with dominant/accent, background, lighting, composition (single centered subject, padding), and "no text, no letters, no logo, no watermark".
   - Formats: size, ratio, file type and size limit per use (app icon, category icon, banner, splash/login art, store screenshots).
   - Safe areas: where logos or text are overlaid later, as % of the frame.
   - Never: old or other brand names and marks found in the repo, styles to avoid.
   - References: the 3 image paths that best show the brand.
3. If the repo has no palette or logo, do not guess: put two options first as an open question with the one you recommend.
4. Check line: the file path and the palette count.`;

const ART = `How to art-direct an asset batch (you write prompts; Codex makes the images):
1. Read the brand kit (docs/opscode/brand/brand.md) and the brief. Every prompt starts with the brand kit's style header, word for word.
2. Write one file (the brief names it, e.g. assets/<batch>/brief.md) with one block per asset: id; exact file path; where it is used and its size and ratio; the prompt; reference images (paths) to attach.
3. A good prompt names one concrete subject (object, material, angle, lighting, mood), the composition (centered or which band of the frame, padding, empty safe area in % where a logo or text goes later) and what must not appear. Write it so it works alone.
4. Text inside an image only for banners, and only the exact words given, quoted, with their colours; everything else says "no text, no letters".
5. Sets (category icons, feature icons) are made as one 3x3 sheet on pure white with equal cells, or one after another in the same Codex chat, so the style matches. Say which.
6. Quality bar: modern, premium, specific to this product; no clip-art, no stock-photo clichés, readable at 48px for icons; prefer SVG (write "svg" and describe the shapes) for simple flat icons and logos.
7. At most 12 assets per batch. Check line: the brief's path and the asset count.`;

const ASSET = `How to make the assets (you have an image generation tool):
1. Read the batch brief and the brand kit it names, and look at the attached reference images.
2. Make every raster asset with your image generation tool, one at a time, in this one chat so the style stays the same. Use the brief's prompt as written; add detail if it helps, but never change the palette, the style header or the no-text rule.
3. Save each image at exactly the brief's file path (copy it from where the tool saved it) in the asked format; resize or convert with a script when the size or type differs. For a sheet, save the sheet, then crop each cell to its own file with a script.
4. Assets marked svg: write clean SVG (viewBox, no embedded raster), using the brand hex colours.
5. Look at each result before moving on. Wrong colours, stray letters or text, a cut-off subject, the wrong ratio, or a style that does not match the set: make it again (at most 2 retries), then note it.
6. Check line: every file path you wrote, one per asset, and any asset you could not make with the reason.`;

const UI = `How to build screens:
1. Read the brand kit (docs/opscode/brand/brand.md), the screen list in the brief and the project's existing screens; copy the closest one's structure.
2. Use the project's own components, theme tokens and spacing; never hard-code a colour or size that exists as a token. Use the generated assets by their paths.
3. Every screen handles empty, loading and error states; tap targets at least 44px; text works at large font sizes; nothing overflows on a small phone (360px wide).
4. Smallest complete change; no restyling of screens the brief did not name.
5. Prove it: run the project's analyzer/linter and build or tests; if the project can take screenshots (Flutter golden tests, Playwright), save them under the brief's folder. Check line: commands with results, screenshot paths.`;

const VISUAL = `How to review images and screens (you are the brand guardian; you did not make them):
1. Read the brand kit and the brief, then open every image or screenshot listed (look at each one).
2. Check each against the brief and the brand kit only: palette close to the hex values; the same style across the set; no stray text, letters, logos or watermarks; the right subject; safe areas empty; ratio and size; readable at small size; nothing from an old or other brand; not cheap or clip-art looking.
3. Change nothing.
4. Per asset: pass, or fail with one line why and a corrected prompt sentence the maker can use as is.
5. Do not fail on taste alone; fail only on the brief or the brand kit. End with Verdict: pass, or Verdict: fail with the list.`;

// Shaped by real runs (testing/reports/2026-11-16-browser-real-test.md): Sonnet finished a full shop
// flow in ~13 calls when it batched and trusted the action results; models that re-read after every
// click or polled the logs used 2-3x the calls.
const QA = `How to test like a user (in Opscode's Browser tab, or the iOS Simulator with ios_simulator):
1. Start the app if it is not running (the project's dev command; note the URL), then open it with browser_navigate: the result already lists the buttons, links and fields as [ref_N].
2. Walk each flow in the brief the way a customer would, with real clicks and typing (browser_act on refs). Put predictable steps in one browser_batch call.
3. Trust each action's result: it says what appeared, changed or went away, new text, console errors and failed requests. Read the page again only when you need more; take a screenshot only to judge how something looks.
4. A confirm/alert/prompt pauses the page: answer it with action "dialog".
5. Look for: wrong numbers or totals, broken images, console errors, failed or 4xx/5xx requests, dead buttons, validation that lets bad input through, layout that breaks on a phone (browser_tabs resize mobile).
6. Change no files unless the brief says to fix what you find.
7. Report each bug with the steps to reproduce, what you expected and what happened. Check line: the flows you walked and their result (passed / bug).`;

const CHORE = `How to do a chore: do exactly what is asked, nothing around it. Prefer one command with trimmed output over reading files. Answer with the result and where you found it; no changes unless the brief says so.`;

const REVIEW = `How to review (you are independent; you did not do this work):
1. Do not trust the worker's summary or its test claims. Check for yourself, against the brief's Goal and Done when lines only; never invent requirements, never comment on style or naming.
2. Read the diff plus the code around it, then exercise the work the way a user would: run the checks the repo has, and the commands the brief names, on inputs you choose, including the stated edge and error cases. Re-measure any number the brief sets.
3. Change nothing. You read and run only.
4. Report findings most serious first, each with: the requirement (quoted from the brief), what fails, and the command you ran with its output as evidence. Mark nits as nits.
5. When you cannot tell whether something fails, count it as passing: a wrong finding sends the builder to break correct work. End with Verdict: pass, or Verdict: fail with the findings.`;

/** The skill text appended to a Conductor worker's brief. Empty when none fits. */
export function skillFor(role: "build" | "review" | "check", kind?: JobKind): string {
  if (role === "review") return `\n\n${kind === "visual" ? VISUAL : REVIEW}`;
  const BY: Partial<Record<JobKind, string>> = { fix: FIX, feature: FEATURE, chore: CHORE, plan: PLAN, brand: BRAND, art: ART, asset: ASSET, ui: UI, visual: VISUAL, qa: QA };
  const text = role === "check" || !kind ? "" : BY[kind] ?? "";
  return text ? `\n\n${text}` : "";
}
