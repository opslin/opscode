// Where tokens go: the usage scanner and report (fixture logs with hand-worked numbers),
// the per-file cache, the 30 vs 90 day window, Opscode-chat attribution.

import { existsSync, mkdirSync, mkdtempSync, realpathSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime } from "./lib/harness.mjs";
import { writeFixture } from "./lib/usage-fixture.mjs";

const t = reporter();
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 400);
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p18-")));
mkdirSync(join(base, "project"));
const fx = writeFixture(base);
const stateDir = join(base, "state");
const rt = await startRuntime({ env: { OPSCODE_CLAUDE_LOGS: fx.claudeRoot, OPSCODE_CODEX_LOGS: fx.codexRoot }, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

try {
  const C = await session(rt);
  let res = await C.call("usage.report", { days: 30, wait: true });
  const r = res.result?.report;
  const c = r?.claude;
  t.check("report arrives with Claude and Codex parts", !!c && !!r.codex, why(res));
  t.check("the duplicated message counts once; the 60-day-old session is outside 30 days", c?.calls === 4 && c.sessions === 1, JSON.stringify({ calls: c?.calls, sessions: c?.sessions }));
  t.check("list-price cost is worked out per model (0.71)", c?.usd === 0.71 && c.models.find((m) => m.model === "claude-sonnet-5-5")?.calls === 3 && c.models.find((m) => m.model === "claude-opus-5-5")?.calls === 1, JSON.stringify(c?.models));
  t.check("cache writes are the biggest part (0.65), re-reads 0.05", c?.split.write === 0.65 && c.split.read === 0.05, JSON.stringify(c?.split));
  t.check("average context 142,531; share of calls over 100k/200k/500k = 100/25/0", c?.avg_context === 142531 && c.ctx_over_pct.k100 === 100 && c.ctx_over_pct.k200 === 25 && c.ctx_over_pct.k500 === 0, JSON.stringify({ a: c?.avg_context, p: c?.ctx_over_pct }));
  t.check("cache rebuilds: 0.15 after a break, 0.25 after the model switch, 2 in all", c?.burners.rewrites.breaks === 0.15 && c.burners.rewrites.switches === 0.25 && c.burners.rewrites.other === 0 && c.burners.rewrite_count === 2, JSON.stringify(c?.burners.rewrites));
  t.check("the starting prompt (100k tokens) is re-read on every call (0.05)", c?.burners.start_prompt === 0.05 && c.burners.start_prompt_median_k === 100, JSON.stringify({ s: c?.burners.start_prompt, k: c?.burners.start_prompt_median_k }));
  t.check("history over 150k tokens is counted as avoidable (0.01)", c?.burners.long_chats === 0.01, String(c?.burners.long_chats));
  t.check("a small Opus step is flagged (0.17)", c?.burners.small_steps_on_big_models === 0.17, String(c?.burners.small_steps_on_big_models));
  t.check("tool output carried through later calls is listed (Bash, 4000 characters)", c?.burners.tool_carry[0]?.tool === "Bash" && c.burners.tool_carry[0].chars === 4000, JSON.stringify(c?.burners.tool_carry));
  t.check("start size by where it ran: one desktop session starting at 100k", c?.start_by_entry.length === 1 && c.start_by_entry[0].entry === "claude-desktop" && c.start_by_entry[0].median_k === 100, JSON.stringify(c?.start_by_entry));
  const row = c?.top_sessions[0];
  t.check("the session row has project, calls, first prompt and starting context", row?.proj === "proj1" && row.calls === 4 && row.first === "Build the login screen" && row.start_ctx_k === 100 && row.entry === "claude-desktop", JSON.stringify(row));
  t.check("Codex: 2 sessions, 1 tiny (<2k output), tokens summed, weekly 41% used", r?.codex?.sessions === 2 && r.codex.tiny_sessions === 1 && r.codex.input === 77000 && r.codex.output === 5100 && r.codex.weekly_used === 41 && r.codex.models["gpt-fake"] === 2, JSON.stringify(r?.codex));
  t.check("log sizes are counted", r?.logs.claude_files === 3 && r.logs.codex_files === 2 && r.logs.claude_bytes > 0, JSON.stringify(r?.logs));

  res = await C.call("usage.report", { days: 90, wait: true });
  t.check("a 90-day window includes the old session", res.result?.report?.claude?.sessions === 2 && res.result.report.claude.calls === 5, why(res));
  t.check("the cache is written to the state dir", existsSync(join(stateDir, "usage-cache.json")));

  fx.appendCall();
  res = await C.call("usage.report", { days: 30, refresh: true, wait: true });
  t.check("refresh reads only the changed file (1 of 5) and the new call shows", res.result?.progress?.total === 1 && res.result.report.claude.calls === 5, JSON.stringify({ p: res.result?.progress, calls: res.result?.report?.claude?.calls }));
  res = await C.call("usage.report", { days: 30 });
  t.check("a second read without refresh does not rescan", !res.result?.scanning && res.result?.report?.claude?.calls === 5);

  // Attribution: sessions that are Opscode chats are labelled (pure report function).
  const { buildReport } = await import(join(process.cwd(), "dist/runtime/usage/report.js"));
  const { scanClaude } = await import(join(process.cwd(), "dist/runtime/usage/scan.js"));
  const s = await scanClaude(join(fx.claudeRoot, "-x-proj1", "s1.jsonl"));
  const labelled = buildReport([s], { days: 30, now: fx.now, labels: new Map([["11111111-aaaa", { chat_id: "chat-1", title: "Login", workspace_id: "w1", mode: "warlord" }]]) });
  t.check("a session that is an Opscode chat is labelled with its chat and mode", labelled.claude.opscode.sessions === 1 && labelled.claude.top_sessions[0].label?.mode === "warlord" && labelled.claude.opscode.usd > 0, JSON.stringify(labelled.claude.opscode));
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
