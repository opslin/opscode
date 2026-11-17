// Provider clients. Each turns one request (system + messages + tools) into a
// stream of normalized events, so the agent loop never sees wire formats.
//   - anthropic: Messages API (SSE)
//   - openai:    Chat Completions API (SSE) — also fits OpenRouter, Ollama, vLLM, etc.

export type Block =
  | { type: "text"; text: string }
  | { type: "tool_use"; id: string; name: string; input: Record<string, unknown> }
  | { type: "tool_result"; id: string; content: string; is_error: boolean; image?: { media_type: string; data: string } };

export interface Msg {
  role: "user" | "assistant";
  blocks: Block[];
}

export interface ToolDef {
  name: string;
  description: string;
  schema: Record<string, unknown>;
}

export type LlmEvent =
  | { type: "text"; text: string }
  | { type: "tool"; id: string; name: string; input: Record<string, unknown> }
  | { type: "stop"; reason: "end" | "tool_use" | "length" | "other" };

export interface LlmConfig {
  kind: "anthropic" | "openai";
  base_url: string;
  api_key: string;
  model: string;
}

export interface LlmRequest {
  system: string;
  messages: Msg[];
  tools: ToolDef[];
  signal: AbortSignal;
  maxTokens?: number;
}

/** Plain-HTTP is only for local servers; keys never travel in cleartext to the internet. */
export function validateBaseUrl(raw: string): string {
  let u: URL;
  try {
    u = new URL(raw);
  } catch {
    throw new Error("base URL is not a valid URL");
  }
  const local = u.hostname === "localhost" || u.hostname === "127.0.0.1" || u.hostname === "[::1]";
  if (u.protocol !== "https:" && !(u.protocol === "http:" && local)) {
    throw new Error("base URL must use https (http is allowed only for localhost)");
  }
  if (u.username || u.password) throw new Error("base URL must not contain credentials");
  return u.toString().replace(/\/+$/, "");
}

/** Server-sent events: yields each `data:` payload. */
async function* sse(res: Response, signal: AbortSignal): AsyncGenerator<string> {
  if (!res.body) throw new Error("empty response body");
  const reader = res.body.getReader();
  const dec = new TextDecoder();
  let buf = "";
  try {
    for (;;) {
      if (signal.aborted) return;
      const { value, done } = await reader.read();
      if (done) break;
      buf += dec.decode(value, { stream: true });
      let i: number;
      while ((i = buf.search(/\r?\n\r?\n/)) >= 0) {
        const raw = buf.slice(0, i);
        buf = buf.slice(i).replace(/^\r?\n\r?\n/, "");
        const data = raw
          .split(/\r?\n/)
          .filter((l) => l.startsWith("data:"))
          .map((l) => l.slice(5).replace(/^ /, ""))
          .join("\n");
        if (data) yield data;
      }
    }
  } finally {
    reader.cancel().catch(() => {});
  }
}

async function post(cfg: LlmConfig, path: string, headers: Record<string, string>, body: unknown, signal: AbortSignal): Promise<Response> {
  const res = await fetch(cfg.base_url + path, {
    method: "POST",
    headers: { "content-type": "application/json", accept: "text/event-stream", ...headers },
    body: JSON.stringify(body),
    signal,
    redirect: "error", // a redirect could carry the key to another host
  });
  if (!res.ok) {
    let text = "";
    try {
      text = (await res.text()).slice(0, 400);
    } catch { /* ignore */ }
    const msg = `${res.status} ${res.statusText}${text ? `: ${text}` : ""}`;
    throw new Error(scrub(msg, cfg.api_key));
  }
  return res;
}

const scrub = (s: string, key: string): string => (key ? s.split(key).join("[key]") : s);

const parseJson = (s: string): Record<string, unknown> => {
  if (!s.trim()) return {};
  try {
    const v = JSON.parse(s);
    return v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : {};
  } catch {
    return {};
  }
};

// ---- Anthropic Messages -------------------------------------------------------

async function* anthropic(cfg: LlmConfig, req: LlmRequest): AsyncGenerator<LlmEvent> {
  const messages = req.messages.map((m) => ({
    role: m.role,
    content: m.blocks.map((b) =>
      b.type === "text"
        ? { type: "text", text: b.text }
        : b.type === "tool_use"
          ? { type: "tool_use", id: b.id, name: b.name, input: b.input }
          : {
              type: "tool_result",
              tool_use_id: b.id,
              content: b.image
                ? [{ type: "text", text: b.content }, { type: "image", source: { type: "base64", media_type: b.image.media_type, data: b.image.data } }]
                : b.content,
              is_error: b.is_error,
            },
    ),
  }));
  const res = await post(
    cfg,
    "/v1/messages",
    { "x-api-key": cfg.api_key, "anthropic-version": "2023-06-01" },
    {
      model: cfg.model,
      max_tokens: req.maxTokens ?? 8192,
      stream: true,
      system: req.system,
      messages,
      tools: req.tools.map((t) => ({ name: t.name, description: t.description, input_schema: t.schema })),
    },
    req.signal,
  );
  const tools = new Map<number, { id: string; name: string; json: string }>();
  let stop: "end" | "tool_use" | "length" | "other" = "end";
  for await (const data of sse(res, req.signal)) {
    const ev = parseJson(data) as { type?: string; index?: number; content_block?: Record<string, string>; delta?: Record<string, string>; error?: { message?: string } };
    if (ev.type === "content_block_start" && ev.content_block?.type === "tool_use" && ev.index !== undefined) {
      tools.set(ev.index, { id: String(ev.content_block.id), name: String(ev.content_block.name), json: "" });
    } else if (ev.type === "content_block_delta" && ev.delta) {
      if (ev.delta.type === "text_delta" && ev.delta.text) yield { type: "text", text: ev.delta.text };
      else if (ev.delta.type === "input_json_delta" && ev.index !== undefined) {
        const t = tools.get(ev.index);
        if (t) t.json += ev.delta.partial_json ?? "";
      }
    } else if (ev.type === "content_block_stop" && ev.index !== undefined) {
      const t = tools.get(ev.index);
      if (t) {
        tools.delete(ev.index);
        yield { type: "tool", id: t.id, name: t.name, input: parseJson(t.json) };
      }
    } else if (ev.type === "message_delta" && ev.delta?.stop_reason) {
      const r = ev.delta.stop_reason;
      stop = r === "tool_use" ? "tool_use" : r === "max_tokens" ? "length" : r === "end_turn" || r === "stop_sequence" ? "end" : "other";
    } else if (ev.type === "error") {
      throw new Error(scrub(ev.error?.message ?? "provider error", cfg.api_key));
    }
  }
  yield { type: "stop", reason: stop };
}

// ---- OpenAI Chat Completions --------------------------------------------------

async function* openai(cfg: LlmConfig, req: LlmRequest): AsyncGenerator<LlmEvent> {
  const messages: unknown[] = [{ role: "system", content: req.system }];
  for (const m of req.messages) {
    if (m.role === "assistant") {
      const text = m.blocks.filter((b) => b.type === "text").map((b) => (b as { text: string }).text).join("");
      const calls = m.blocks.filter((b) => b.type === "tool_use").map((b) => {
        const u = b as { id: string; name: string; input: Record<string, unknown> };
        return { id: u.id, type: "function", function: { name: u.name, arguments: JSON.stringify(u.input) } };
      });
      messages.push({ role: "assistant", content: text || null, ...(calls.length ? { tool_calls: calls } : {}) });
    } else {
      // Chat Completions tool messages are text only, so images follow as one user message.
      const images: unknown[] = [];
      for (const b of m.blocks) {
        if (b.type === "tool_result") {
          messages.push({ role: "tool", tool_call_id: b.id, content: b.content });
          if (b.image) images.push({ type: "image_url", image_url: { url: `data:${b.image.media_type};base64,${b.image.data}` } });
        } else if (b.type === "text") messages.push({ role: "user", content: b.text });
      }
      if (images.length) messages.push({ role: "user", content: [{ type: "text", text: "Screenshot from the tool call above:" }, ...images] });
    }
  }
  const res = await post(
    cfg,
    "/chat/completions",
    { authorization: `Bearer ${cfg.api_key}` },
    {
      model: cfg.model,
      stream: true,
      messages,
      tools: req.tools.length ? req.tools.map((t) => ({ type: "function", function: { name: t.name, description: t.description, parameters: t.schema } })) : undefined,
    },
    req.signal,
  );
  const calls = new Map<number, { id: string; name: string; json: string }>();
  let finish: string | null = null;
  for await (const data of sse(res, req.signal)) {
    if (data.trim() === "[DONE]") break;
    const ev = parseJson(data) as { choices?: { delta?: { content?: string; tool_calls?: { index: number; id?: string; function?: { name?: string; arguments?: string } }[] }; finish_reason?: string | null }[]; error?: { message?: string } };
    if (ev.error) throw new Error(scrub(ev.error.message ?? "provider error", cfg.api_key));
    const choice = ev.choices?.[0];
    if (!choice) continue;
    if (choice.delta?.content) yield { type: "text", text: choice.delta.content };
    for (const tc of choice.delta?.tool_calls ?? []) {
      const cur = calls.get(tc.index) ?? { id: "", name: "", json: "" };
      if (tc.id) cur.id = tc.id;
      if (tc.function?.name) cur.name += tc.function.name;
      if (tc.function?.arguments) cur.json += tc.function.arguments;
      calls.set(tc.index, cur);
    }
    if (choice.finish_reason) finish = choice.finish_reason;
  }
  for (const [, c] of [...calls].sort((a, b) => a[0] - b[0])) {
    yield { type: "tool", id: c.id || `call_${Math.random().toString(36).slice(2, 10)}`, name: c.name, input: parseJson(c.json) };
  }
  yield { type: "stop", reason: finish === "tool_calls" || calls.size > 0 ? "tool_use" : finish === "length" ? "length" : finish === "stop" || finish === null ? "end" : "other" };
}

export function streamLlm(cfg: LlmConfig, req: LlmRequest): AsyncGenerator<LlmEvent> {
  return cfg.kind === "anthropic" ? anthropic(cfg, req) : openai(cfg, req);
}
