// Session protocol shared by the runtime (server), main (Node client) and,
// mirrored by hand in src/renderer/rpc.js, the renderer (browser client).

import { APP_HOST, APP_SCHEME, type ThemeSource } from "./ipc";

/** WebSocket path of the session endpoint. */
export const SESSION_PATH = "/session/v1";
/** Subprotocol every client offers; the server echoes only this one. */
export const SUBPROTOCOL = "opscode.session.v1";
/** Browser clients cannot set headers, so they carry the token as a subprotocol. */
export const BEARER_PREFIX = "base64url.bearer.";

/** Bumped on breaking protocol changes. */
export const PROTOCOL_REVISION = 1;
/** Oldest client revision this runtime still accepts. */
export const MIN_CLIENT_REVISION = 1;
/** Largest accepted frame, in bytes. */
export const MAX_FRAME_BYTES = 2 * 1024 * 1024;

/**
 * Browser origins allowed to open a session. Node clients send no Origin.
 * (The researched runtime authorized on the token alone; we also pin Origin.)
 */
export const ALLOWED_ORIGINS: readonly string[] = [`${APP_SCHEME}://${APP_HOST}`];

/** Line the runtime prints on stdout once it is listening. */
export const READY_LINE = "OPSCODE_RUNTIME_READY";

/** JSON-RPC-style error codes. */
export const ErrorCode = {
  PARSE_ERROR: -32700,
  INVALID_REQUEST: -32600,
  METHOD_NOT_FOUND: -32601,
  INVALID_PARAMS: -32602,
  INTERNAL: -32603,
  HELLO_REQUIRED: -32002,
  CLIENT_TOO_OLD: -32003,
  /** Unknown workspace / terminal / turn, or a missing file. */
  NOT_FOUND: -32004,
  /** Path outside the project (incl. via symlink) or a protected path such as .git. */
  FORBIDDEN: -32005,
  /** Conflicting state, e.g. a turn is already running in this project. */
  CONFLICT: -32009,
  /** A resource cap was hit (e.g. too many terminals). */
  RESOURCE_LIMIT: -32010,
  /** Filesystem failure (permissions, disk full, ...); data.errno has the code. */
  IO_ERROR: -32011,
} as const;

/** Hard caps on payloads and resources. */
export const LIMITS = {
  PATH_MAX_CHARS: 4096,
  FS_LIST_MAX_ENTRIES: 5000,
  /** Largest file read/write per call; base64 of this still fits a 2 MiB frame. */
  FS_IO_MAX_BYTES: 1024 * 1024,
  TERM_MAX_OPEN: 32,
  TERM_WRITE_MAX_CHARS: 64 * 1024,
  TERM_SCROLLBACK_CHARS: 256 * 1024,
  TURN_TEXT_MAX_CHARS: 100_000,
  TURN_HISTORY_MAX_MESSAGES: 200,
} as const;

/** A project folder the user added. `path` is stored fully resolved (realpath). */
export interface Workspace {
  id: string;
  name: string;
  path: string;
  added_at: string;
}

export type FsEntryKind = "file" | "dir" | "symlink" | "other";

export interface FsEntry {
  name: string;
  kind: FsEntryKind;
  size: number;
  mtime: string;
}

export type TurnEventType =
  | "started"
  | "delta"
  | "completed"
  | "interrupted"
  | "failed"
  | "tool_start"
  | "tool_end"
  | "approval_request"
  | "approval_resolved"
  | "handoff";

/** A turn that started on a different engine than the chat's last one: what the new engine was given. */
export interface HandoffInfo {
  /** full = the whole task record; update = only what happened since this engine's own last turn. */
  kind: "full" | "update";
  from: string;
  to: string;
  /** Estimated size of what was handed over. */
  tokens: number;
  /** inject = Codex history items; message = in the first message of the turn. */
  via: "inject" | "message";
  /** Set when Opscode moved the chat because the other engine ran out of its plan limit (H4). */
  reason?: "limit";
}

export type ToolStatus = "awaiting_approval" | "running" | "done" | "error" | "denied";

/** One ordered piece of an assistant reply: prose or a tool call. */
export type MessagePart =
  | { kind: "text"; text: string }
  | {
      kind: "tool";
      call_id: string;
      tool: string;
      /** One-line description, e.g. the path or command. */
      summary: string;
      /** Longer preview shown for approval (command text, file head). */
      detail?: string;
      status: ToolStatus;
      output?: string;
      /** Set while the person is asked about creating a new git branch. */
      branch?: { names: string[]; current: string };
    };

/** Broadcast as the `turn.event` notification. `seq` orders events within a turn. */
export interface TurnEvent {
  turn_id: string;
  chat_id: string;
  workspace_id: string;
  seq: number;
  type: TurnEventType;
  engine?: string;
  text?: string;
  error?: string;
  /** tool_start / tool_end / approval_*: */
  call_id?: string;
  tool?: string;
  summary?: string;
  detail?: string;
  /** approval_request: this is a question about creating a new git branch. */
  branch?: { names: string[]; current: string };
  output?: string;
  is_error?: boolean;
  approved?: boolean;
  /** handoff: */
  handoff?: HandoffInfo;
}

export interface ChatMessage {
  role: "user" | "assistant";
  text: string;
  turn_id: string;
  status: "complete" | "streaming" | "interrupted" | "failed";
  /** Assistant messages only: text and tool calls in order. `text` is the prose joined. */
  parts?: MessagePart[];
  /** Set when status is "failed". */
  error?: string;
  /** Assistant messages only: this turn took over from another engine. */
  handoff?: HandoffInfo;
  /** A user-role line the runtime wrote (a Chief's chat update), not the person's words. */
  event?: boolean;
  /** User messages: what the person attached (paths inside the project), shown as thumbnails and chips. */
  attachments?: { path: string; name: string; kind: "image" | "file" | "folder"; files?: number; ref?: boolean }[];
}

export type ProviderId = "anthropic" | "openai";

/** What the renderer may know about a provider. The key itself never leaves the runtime. */
export interface ProviderInfo {
  id: ProviderId;
  label: string;
  configured: boolean;
  /** Last 4 characters of the key, for recognition only. */
  key_hint: string;
  base_url: string;
  default_base_url: string;
  model: string;
  active: boolean;
}

export type RequestId = number | string;

export interface RpcRequest {
  id: RequestId;
  method: string;
  params?: unknown;
}

export interface RpcError {
  code: number;
  message: string;
  data?: unknown;
}

export interface RpcResponse {
  /** null only when the request was unreadable (parse error / bad envelope). */
  id: RequestId | null;
  result?: unknown;
  error?: RpcError;
}

/** Server -> client push (no id). */
export interface RpcNotification {
  method: string;
  params?: unknown;
}

/** Written by main to the runtime's fd 3 as one JSON line. */
export interface Bootstrap {
  host: string;
  port: number;
  token: string;
  stateDir: string;
  appVersion: string;
  /** The runtime exits if this process goes away (no orphans). */
  parentPid: number;
}

/** Result of runtime.hello. */
export interface Hello {
  version: string;
  protocol_revision: number;
  min_client_revision: number;
  capabilities: string[];
  session_id: string;
}

/** Runtime-owned user settings (persisted in the state dir). */
export interface Settings {
  display_name: string;
  theme: ThemeSource;
  keep_awake: boolean;
  text_size: "small" | "default" | "large";
  density: "comfortable" | "compact";
  /** When off, no notes are read into chats and agents cannot save notes. */
  memory_enabled: boolean;
  /** Permission mode a new chat starts in. */
  default_mode: PermissionMode;
  /** Voice input language (BCP-47, e.g. "en-IN"), or "auto" = the Mac's own language and region. */
  voice_locale: string;
  /** Read-aloud voice (Pocket TTS): which voice, and how fast it is played (pitch stays). */
  tts_voice: string;
  tts_speed: number;
  /** Voice mode: what the front agent runs on ("" = the chat's own engine), and how long a pause ends what you said. */
  voice_brain_engine: string;
  voice_brain_model: string;
  voice_brain_effort: string;
  voice_end_ms: number;
  /** Voice mode: the agent's voice ("" = the read-aloud voice), its speed (0.8–1.4) and pitch in semitones (-4..4). */
  voice_tts_voice: string;
  voice_tts_speed: number;
  voice_tts_pitch: number;
}

export const DEFAULT_SETTINGS: Settings = {
  display_name: "",
  theme: "system",
  keep_awake: false,
  text_size: "default",
  density: "comfortable",
  memory_enabled: true,
  default_mode: "supervised",
  voice_locale: "auto",
  tts_voice: "bria",
  tts_speed: 1,
  voice_brain_engine: "",
  voice_brain_model: "",
  voice_brain_effort: "",
  voice_end_ms: 1100,
  voice_tts_voice: "",
  voice_tts_speed: 1,
  voice_tts_pitch: 0,
};

/**
 * What an agent may do without asking:
 *   read        - look around only; no edits, commands or MCP tools
 *   supervised  - edits, commands and MCP tools each ask first
 *   auto_edits  - file edits go ahead; commands and MCP tools ask
 *   full        - everything goes ahead (still inside the project folder)
 */
export type PermissionMode = "read" | "supervised" | "auto_edits" | "full";
export const PERMISSION_MODES: readonly PermissionMode[] = ["read", "supervised", "auto_edits", "full"];

/** Coding agents that run on this computer with the person's own sign-in. Antigravity and Qoder speak ACP (Agent Client Protocol). */
export type AcpEngineId = "antigravity" | "qoder";
export type AgentEngineId = "claude-code" | "codex" | AcpEngineId;
export const AGENT_ENGINES: readonly AgentEngineId[] = ["claude-code", "codex", "antigravity", "qoder"];
export const isAgentEngine = (e: unknown): e is AgentEngineId => (AGENT_ENGINES as readonly unknown[]).includes(e);
export const isAcpEngine = (e: unknown): e is AcpEngineId => e === "antigravity" || e === "qoder";

export interface ChatUsage {
  input_tokens: number;
  output_tokens: number;
  cached_tokens: number;
  /** Tokens in the model's context after the last request, and the window size, when the engine says. */
  context_tokens?: number;
  context_window?: number;
  /** When the engine last reported, the model it named, and the tokens it read or wrote to its prompt cache then. */
  reported_at?: string;
  model?: string;
  cache_tokens?: number;
}
/** An MCP server the engine itself loaded for this chat, as it reported at session start. */
export interface ChatConnector { name: string; status: string }
export interface ChatMeta {
  id: string;
  workspace_id: string;
  title: string;
  mode: PermissionMode;
  created_at: string;
  updated_at: string;
  /** Which engine answers: "api" (a provider key), "claude-code", "codex", "antigravity" or "qoder". Absent = "api". */
  engine?: "api" | AgentEngineId;
  model?: string;
  effort?: string;
  /** The engine's own session/thread id, to resume its context. */
  engine_session?: string;
  /** Each engine's own session in this chat, kept when the chat moves to another engine, so coming back resumes it. */
  engine_sessions?: Partial<Record<AgentEngineId, string>>;
  /** The account each engine runs on in this chat ("default" = the Mac's own sign-in), set on the first message and kept. */
  accounts?: Partial<Record<AgentEngineId, string>>;
  /** Running totals for this chat (engines that report them). */
  usage?: ChatUsage;
  /** MCP servers the engine loaded (Claude Code reports these at session start). */
  connectors?: ChatConnector[];
  /** Set when an automation run started this chat for one of its steps. */
  origin?: { automation: string; run_id: string; step: string };
  /** Set on a Chief's own chat (role "home") and on the worker chats it starts. */
  chief?: { id: string; role: "home" | "build" | "review" | "check"; item_id?: string };
  /** Set on the hidden chat a voice agent talks in (never listed; removed when the voice session ends). */
  voice?: { session: string };
}

export type NoteState = "kept" | "draft";
/** A remembered fact. scope is "global" or a workspace id. */
export interface Note {
  id: string;
  title: string;
  body: string;
  scope: string;
  state: NoteState;
  pinned: boolean;
  created_at: string;
  updated_at: string;
}

export type SkillScope = "user" | "project" | "plugin";
export interface SkillInfo {
  name: string;
  description: string;
  scope: SkillScope;
  /** Plugin name, for scope "plugin". */
  plugin?: string;
}

export interface PluginInfo {
  id: string;
  name: string;
  description: string;
  version: string;
  enabled: boolean;
  /** Where it was installed from (a folder path). */
  source: string;
  skills: string[];
  mcp_servers: string[];
}

export interface MarketplaceInfo {
  id: string;
  name: string;
  path: string;
  plugins: { name: string; description: string; installed: boolean; path: string }[];
  error?: string;
}

/** What a folder would bring in, shown before anything is installed. */
export interface FolderPreview {
  kind: "plugin" | "marketplace" | "skills";
  name: string;
  description: string;
  version: string;
  skills: { name: string; description: string }[];
  /** MCP servers a plugin would add; "command" runs code on this computer. */
  mcp_servers: { name: string; transport: "stdio" | "http"; target: string }[];
  plugins: { name: string; description: string }[];
  warnings: string[];
}

export type McpState = "off" | "connecting" | "ready" | "error";
export interface McpServerInfo {
  id: string;
  name: string;
  transport: "stdio" | "http";
  /** Display form: the command line or the URL (no secrets are stored). */
  target: string;
  enabled: boolean;
  /** Set when a plugin owns this server (change it by changing the plugin). */
  plugin?: string;
  state: McpState;
  error?: string;
  tools: { name: string; description: string }[];
  /** Names of the keys it was given (environment variables or HTTP headers). Values never leave the runtime. */
  secrets?: string[];
  /** Where it came from: "Claude Code", "Codex", "Cursor" (imported) or a catalog id. */
  source?: string;
  catalog?: string;
  /** Its last error looks like a missing or wrong key / sign-in. */
  needs_key?: boolean;
}
