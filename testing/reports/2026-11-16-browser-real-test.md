# Browser control: real-model test report

Date: 2026-11-16 · Opscode dev build · Claude Code 2.1.325 · Full access mode

## What was tested

A real Claude Code chat inside Opscode (fresh throwaway profile, your real Claude sign-in) was asked:

> A small shop web app is running at http://localhost:PORT. Test it in the browser like a real customer: create an account, add the two cheapest products to the cart, check out, and confirm the order went through. Then tell me every bug you noticed. Don't change any files.

The shop (served by the test, `src/main/realtest.ts`) has a sign-up form with a **custom dropdown** (not a native select), a product grid loaded by `fetch`, a cart drawer, and a checkout that opens a **`confirm()` dialog** before `POST /api/orders`.

**Planted bugs** (4):
1. Tea's price is the string `"49"`, so the cart total concatenates (₹35 + ₹49 shows ₹3549).
2. Candle's price is `"twelve"` and shows ₹NaN.
3. Bag's image is a 404.
4. Opening the cart with a Mug in it logs a console `TypeError`. This only shows if the agent explores, since Mug is not one of the cheapest products.

Run it yourself:

```bash
node scripts/realtest-browser.mjs --model claude-sonnet-5-5
```

Then summarize a run:

```bash
node testing/summarize.mjs testing/runs/<run folder> --full
```

Every run's raw data (each tool call, outputs, per-request tokens, screenshots every 30 s) is in `testing/runs/`.

## Results

Cost is at API list prices (Fable $10/$50, Sonnet 5.5 $2/$10, Haiku 5.5 $0.10/$0.50 per million tokens in/out). A Pro/Max plan does not bill this way; the numbers are for comparing.

| Run | Model | Tools | Time | Model requests | Tool calls | Tool errors | Order placed | Bugs found | Cost |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Fable 5.2 | first version | 60 s | 9 | 9 | 0 | yes | 4/4 | $0.91 |
| 2 | Sonnet 5.5 | first version | 38 s | 8 | 13 | 0 | yes | 3/4 | $0.18 |
| 3 | Haiku 5.5 | first version | 58 s | 15 | 36 | 0 | yes | 4/4 | $0.018 |
| 4 | Haiku 5.5 | + change reports | 49 s | 12 | 24 | 0 | yes¹ | 3/4 | $0.012 |
| 5 | Sonnet 5.5 | + change reports | 135 s | 12 | 15 | **2 (hung 45 s)** | yes | 3/4 | $0.15 |
| 6 | Fable 5.2 | + change reports | 87 s | 8 | 10 | 0 | yes | 3/4 | $0.54 |
| 7 | Sonnet 5.5 | **final** | 32 s | 10 | 13 | 0 | yes | 3/4 | $0.13 |
| 8 | Haiku 5.5 | **final** | 44 s | 14 | 28 | 1² | yes | 3/4 | $0.013 |

¹ Haiku treated Candle ("twelve") as cheap and ordered it; that was a judgement call, not a tool problem.
² The intended notice "A confirm dialog is open… answer it"; Haiku then answered it.

**Verdict:** browser control works with real models. All 8 runs signed up through the custom dropdown, used the cart and placed the order (the server received it). No run needed a file edit or a workaround. The models found every bug that a normal checkout path shows; bug 4 needs exploring off that path, and only Fable and Haiku did it in the first runs.

## Where the tokens go

- Most of each run is Claude Code's own start-up prompt (about 25–45k tokens, written to cache once) plus re-reading the conversation on each request. Opscode's 9 browser tools add only about 1,400 tokens.
- Each browser step adds about 1–2k tokens: we send page outlines as short text with `[ref_N]` tags, not screenshots. Runs used 0–2 screenshots on average.
- **The model is the biggest cost lever.** The same task cost $0.91 on Fable, $0.13 on Sonnet and $0.013 on Haiku.

## Problems found and fixed

1. **A click on a hidden element clicked the page's corner.** In run 5, Sonnet re-clicked the dropdown, which closed it, then clicked an option. The option had no box, so the click went to (0,0), the header. Now a hidden or zero-size element is refused, with a reason ("not visible right now: it may be in a closed menu…"). Native `<option>`s point to `fill` instead.
2. **A click that opens `alert/confirm/prompt` hung for 45 s.** Chrome pauses the page until the dialog is answered, and our click waited for it. I confirmed this with a separate Electron test. Now the click returns as soon as the dialog opens and says so. Page reads explain instead of hanging. Answering the dialog reports what changed (e.g. `New text: "Order #1001 placed!"`).
3. **Actions said nothing about what changed**, so models re-read the page after almost every click (Haiku: 36 calls). Now every action reports what appeared, changed or went away, plus new text.
4. **Bugs had to be polled** (Haiku called the logs tool 7 times). Now page loads and actions report new console errors and failed or 4xx/5xx requests automatically. `browser_logs` returns both lists by default.
5. **Opening a page was always followed by a read.** Now `browser_navigate` returns the page's buttons, links and fields directly.
6. **Haiku never batched steps.** The prompt note now asks for `browser_batch` when the next steps are predictable.

Effect: Haiku went from 36 calls and 15 model requests to 24–28 calls and 12–14 requests; log polling dropped from 7 calls to 1–3. Sonnet's final run was the fastest of all (32 s, no errors).

## Recommendation

| Use | Model | Why |
|---|---|---|
| Everyday "check my page / click through the flow" | **Sonnet 5.5** | Fast, batches well, careful, about $0.13 per flow at list price |
| Cheap repeated checks (smoke flows, automations) | Haiku 5.5 | About 10x cheaper than Sonnet, completes flows; needs more steps and weaker judgement |
| Deep bug hunts, tricky UIs | Fable 5.2 / Opus | Most thorough, about 4–7x Sonnet's cost |

## Not tested yet

These are in `testing/pending/browser.md`:

- Codex as the engine (Codex is not installed on this Mac).
- The built-in agent with a real API key (none is set up).
- Supervised mode with real approval clicks; sites outside this computer.
- Iframes, file uploads, login flows with redirects, very long pages.
