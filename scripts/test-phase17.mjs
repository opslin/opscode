// Plan limits: Claude Code's get_usage and Codex's account/rateLimits/read (fake CLIs),
// parsing, live updates from a Claude rate_limit_event, and a missing engine.

import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reporter, session, startRuntime, waitFor } from "./lib/harness.mjs";

const t = reporter();
const why = (res) => JSON.stringify(res.error ?? res.result)?.slice(0, 300);
const FAKE_CLAUDE = join(process.cwd(), "scripts/lib/fake-claude.mjs");
const FAKE_CODEX = join(process.cwd(), "scripts/lib/fake-codex.mjs");
const base = realpathSync(mkdtempSync(join(tmpdir(), "opscode-p17-")));
mkdirSync(join(base, "project"));
const logFile = join(base, "engines.log");
const entries = () => (existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const stateDir = join(base, "state");
let rt = await startRuntime({ env: { OPSCODE_CLAUDE_BIN: FAKE_CLAUDE, OPSCODE_CODEX_BIN: FAKE_CODEX, OPSCODE_FAKE_ENGINE_LOG: logFile }, stateDir, keepState: true });
t.check("runtime starts", rt.ready, rt.ready ? "" : rt.output().trim());
if (!rt.ready) process.exit(1);

// Parsers, straight from the build.
const { claudeUsageToLimits, codexLimitsToLimits } = await import(join(process.cwd(), "dist/runtime/engines/limits.js"));
const cu = claudeUsageToLimits({ subscription_type: "max", rate_limits_available: true, rate_limits: { five_hour: { utilization: 99.5, resets_at: "2026-11-15T12:59:59.79+00:00" }, seven_day: { utilization: 10, resets_at: null }, seven_day_sonnet: { utilization: 3, resets_at: "2026-11-20T00:00:00Z" }, extra_usage: { is_enabled: true, utilization: 12 } } });
t.check("Claude usage -> session, weekly, weekly · Sonnet, extra usage", cu.state === "ok" && cu.plan === "max" && cu.windows.map((w) => w.id).join(",") === "five_hour,seven_day,seven_day_sonnet,extra_usage" && cu.windows[0].used_percent === 99.5 && cu.windows[0].resets_at === "2026-11-15T12:59:59.790Z" && !("resets_at" in cu.windows[1]), JSON.stringify(cu));
t.check("Claude without plan limits (API key) is 'unavailable'", claudeUsageToLimits({ rate_limits_available: false }).state === "unavailable");
const xu = codexLimitsToLimits({ rateLimits: { primary: { usedPercent: 1, windowDurationMins: 300, resetsAt: 1794732523 }, secondary: { usedPercent: 55, windowDurationMins: 10080, resetsAt: 1794932363 }, planType: "team" }, rateLimitResetCredits: { availableCount: 2 } });
t.check("Codex limits -> 5-hour + weekly with epoch-second resets, plan, reset credits", xu.state === "ok" && xu.plan === "team" && xu.reset_credits === 2 && xu.windows[0].label === "5-hour session" && xu.windows[1].label === "Weekly" && xu.windows[0].resets_at === new Date(1794732523000).toISOString(), JSON.stringify(xu));

try {
  let C = await session(rt);
  let res = await C.call("limits.get", { refresh: true });
  const cl = res.result?.limits.find((l) => l.engine === "claude-code");
  const cx = res.result?.limits.find((l) => l.engine === "codex");
  t.check("limits.get reads Claude Code: Pro, 15% session, 43% weekly, reset times", cl?.state === "ok" && cl.plan === "pro" && cl.windows.find((w) => w.kind === "session")?.used_percent === 15 && cl.windows.find((w) => w.kind === "weekly")?.used_percent === 43 && Date.parse(cl.windows[0].resets_at) > Date.now(), why(res));
  t.check("limits.get reads Codex: Team, 1% / 55%, 2 reset credits", cx?.state === "ok" && cx.plan === "team" && cx.windows[0].used_percent === 1 && cx.windows[1].used_percent === 55 && cx.reset_credits === 2, why(res));
  t.check("Codex's available reset credits are listed with expiry, soonest first; used ones are left out", cx?.reset_credit_list?.length === 2 && cx.reset_credit_list[0].id === "c1" && Date.parse(cx.reset_credit_list[0].expires_at) > Date.now() + 8 * 86400_000 && Date.parse(cx.reset_credit_list[0].expires_at) < Date.parse(cx.reset_credit_list[1].expires_at), JSON.stringify(cx?.reset_credit_list));
  t.check("Claude's per-model weekly limit (Fable) is a window", cl?.windows.some((w) => w.label === "Weekly · Fable" && w.used_percent === 7 && w.resets_at), JSON.stringify(cl?.windows.map((w) => w.label)));
  t.check("the Claude check ran no prompt (get_usage only)", entries().some((e) => e.get_usage) && !entries().some((e) => e.prompt !== undefined), JSON.stringify(entries().slice(-3)));
  t.check("limits.changed is broadcast", C.find("limits.changed").length > 0);
  const n = entries().filter((e) => e.get_usage).length;
  await C.call("limits.get", {});
  t.check("a second read within a minute uses the cache", entries().filter((e) => e.get_usage).length === n);
  C.close();
  await rt.stop();

  rt = await startRuntime({ env: { OPSCODE_CLAUDE_BIN: join(base, "nope"), OPSCODE_CODEX_BIN: join(base, "nope") }, stateDir, keepState: true });
  C = await session(rt);
  res = await C.call("limits.get", { refresh: true });
  t.check("missing programs are reported as missing", res.result?.limits.length === 2 && res.result.limits.every((l) => l.state === "missing" || l.state === "error"), why(res));
  C.close();
} finally {
  const exit = await rt.stop();
  t.check("SIGTERM -> clean exit", exit === "code=0 signal=null", exit);
  rmSync(base, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}
process.exit(t.finish());
