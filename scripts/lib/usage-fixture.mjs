// Writes small, known Claude Code and Codex session logs for the usage tests.
// Numbers are chosen so the expected report can be worked out by hand:
//   session S1 (4 calls, 3 sonnet + 1 opus, one duplicated message), S2 (60 days old).
import { mkdirSync, writeFileSync, appendFileSync } from "node:fs";
import { join } from "node:path";

export function writeFixture(base, now = Date.now()) {
  const claude = join(base, "claude", "-x-proj1");
  const codex = join(base, "codex", "2026", "11", "15");
  mkdirSync(claude, { recursive: true });
  mkdirSync(codex, { recursive: true });
  const iso = (ms) => new Date(ms).toISOString();
  const H = 3_600_000, M = 60_000;
  const call = (sid, id, t, model, inp, cw, cr, out, extra = {}) => JSON.stringify({ type: "assistant", sessionId: sid, timestamp: iso(t), cwd: "/x/worktrees/proj1", entrypoint: "claude-desktop", isSidechain: false, message: { id, model, content: extra.tool ? [{ type: "tool_use", id: extra.tool, name: "Bash", input: {} }] : [{ type: "text", text: "ok" }], usage: { input_tokens: inp, cache_creation_input_tokens: cw, cache_read_input_tokens: cr, output_tokens: out, cache_creation: { ephemeral_1h_input_tokens: 0 } } } });
  const user = (sid, t, content) => JSON.stringify({ type: "user", sessionId: sid, timestamp: iso(t), cwd: "/x/worktrees/proj1", message: { content } });
  const S1 = "11111111-aaaa";
  const t0 = now - 3 * H;
  const a = [
    user(S1, t0 - 1000, "Build the login screen"),
    call(S1, "m1", t0, "claude-sonnet-5-5", 10, 100000, 0, 50, { tool: "tu1" }),
    user(S1, t0 + 1000, [{ type: "tool_result", tool_use_id: "tu1", content: "x".repeat(4000) }]),
    call(S1, "m2", t0 + M, "claude-sonnet-5-5", 5, 100, 100010, 200),
    call(S1, "m3", t0 + H + 1 * M, "claude-sonnet-5-5", 0, 60000, 100000, 100),
    call(S1, "m4", t0 + H + 2 * M, "claude-opus-5-5", 0, 50000, 160000, 100),
  ];
  writeFileSync(join(claude, "s1.jsonl"), a.join("\n") + "\n");
  // The same message again in another file (a resumed session repeats history).
  writeFileSync(join(claude, "s1-resumed.jsonl"), call(S1, "m2", t0 + M, "claude-sonnet-5-5", 5, 100, 100010, 200) + "\n");
  const S2 = "22222222-bbbb";
  writeFileSync(join(claude, "s2.jsonl"), call(S2, "m5", now - 60 * 24 * H, "claude-haiku-5-5", 100, 0, 0, 10) + "\n");
  const meta = (id, t, cwd, orig) => JSON.stringify({ timestamp: iso(t), type: "session_meta", payload: { id, cwd, originator: orig } });
  const ctx = (t, model) => JSON.stringify({ timestamp: iso(t), type: "turn_context", payload: { model, cwd: "/x/projA" } });
  const tok = (t, input, cached, out, weekly) => JSON.stringify({ timestamp: iso(t), type: "event_msg", payload: { type: "token_count", info: { total_token_usage: { input_tokens: input, cached_input_tokens: cached, output_tokens: out, reasoning_output_tokens: 0, total_tokens: input + out } }, rate_limits: { primary: { used_percent: 3 }, secondary: { used_percent: weekly } } } });
  writeFileSync(join(codex, "rollout-a.jsonl"), [meta("cx-1", now - 2 * H, "/x/projA", "codex_exec"), ctx(now - 2 * H, "gpt-fake"), tok(now - 2 * H + 1000, 27000, 26000, 100, 40)].join("\n") + "\n");
  writeFileSync(join(codex, "rollout-b.jsonl"), [meta("cx-2", now - H, "/x/projA", "Codex Desktop"), ctx(now - H, "gpt-fake"), tok(now - H + 1000, 50000, 40000, 5000, 41)].join("\n") + "\n");
  return { claudeRoot: join(base, "claude"), codexRoot: join(base, "codex"), appendCall: () => appendFileSync(join(claude, "s1.jsonl"), call(S1, "m6", now - 60_000, "claude-sonnet-5-5", 0, 10, 160000, 20) + "\n"), now };
}
