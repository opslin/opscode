import { createHash, randomUUID } from "node:crypto";
import { appendFileSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { PERMISSION_MODES, type ChatMessage, type ChatMeta, type PermissionMode, type PluginInfo, type ProviderInfo, type Workspace } from "../shared/protocol";
import type { EngineInfo } from "../runtime/engines/detect";
import type { MainRpcClient } from "./rpcClient";

const FILE_LIMIT = 10 * 1024 * 1024;
const CHUNK = 36 * 1024;
const EXPIRY = 15 * 60_000;
const ENGINES = new Set(["api", "claude-code", "codex", "antigravity", "qoder"]);
const EFFORTS = new Set(["low", "medium", "high", "xhigh", "max"]);
type ChatSettings = Pick<ChatMeta, "title" | "mode" | "engine" | "model" | "effort">;

function permissions(value: unknown): PermissionMode {
  if (!PERMISSION_MODES.includes(value as PermissionMode)) throw new Error("Choose an Opscode permission mode.");
  return value as PermissionMode;
}

function modelPick(body: Record<string, unknown>) {
  const { engine, model, effort } = body;
  if (engine !== undefined && (typeof engine !== "string" || !ENGINES.has(engine))) throw new Error("Choose an engine available on your Mac.");
  if (model !== undefined && (typeof model !== "string" || !model.trim() || model.length > 120 || /[\x00-\x1f\x7f]/.test(model))) {
    throw new Error("Choose a valid model.");
  }
  if (effort !== undefined && (typeof effort !== "string" || !EFFORTS.has(effort))) throw new Error("Choose a valid reasoning effort.");
  return { engine, model, effort };
}

const settingsOf = ({ title, mode, engine, model, effort }: ChatSettings) =>
  ({ title: title.slice(0, 200), mode, engine: engine ?? "api", model, effort });

interface Upload {
  owner: string;
  workspace: string;
  directory: string;
  path: string;
  size: number;
  offset: number;
  expiry: number;
  imported?: string;
  used?: string;
}

interface MobileVoice { owner: string; session: string; tts?: string; seq: number; ack: number; events: { seq: number; event: Record<string, unknown> }[]; touched: number }

interface Chief { id: string; chat_id: string; mode?: string; project_ids: string[]; name: string; title?: string }

interface Download { owner: string; workspace: string; path: string; size: number; revision: string; expiry: number }

function identifier(value: unknown): string {
  if (typeof value !== "string" || !/^[a-zA-Z0-9:_-]{1,200}$/.test(value)) throw new Error("Choose a valid project or conversation.");
  return value;
}
function integer(value: unknown, max = Number.MAX_SAFE_INTEGER): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0 || value > max) throw new Error("Invalid transfer offset or list page.");
  return value;
}
function fileName(value: unknown): string {
  if (typeof value !== "string" || !value || value.length > 100 || /[\/\\\x00-\x1f\x7f]/.test(value)
    || /^\./.test(value) || /\.(pem|key|p12|pfx|keystore|jks)$/i.test(value) || /^credentials(\.|$)/i.test(value)) {
    throw new Error("Choose a regular file with a valid name.");
  }
  return value;
}

export class MobileWorkspace {
  private readonly uploads = new Map<string, Upload>();
  private readonly downloads = new Map<string, Download>();
  private readonly sent = new Map<string, { result: Promise<object>; expires: number }>();
  private readonly timer: NodeJS.Timeout;
  private voice?: MobileVoice;
  private voiceStarting = false;
  private earlyVoice: { kind: "agent" | "tts"; event: Record<string, unknown> }[] = [];
  private readonly createdChiefs = new Map<string, { chief: Chief; expires: number }>();
  private readonly createdChats = new Map<string, { id: string; workspace: string; expires: number }>();

  constructor(private readonly client: () => MainRpcClient | null) {
    this.timer = setInterval(() => this.prune(), 60_000);
    this.timer.unref();
  }

  stop(): void {
    clearInterval(this.timer);
    for (const [id, upload] of this.uploads) this.removeUpload(id, upload);
    this.downloads.clear();
    this.sent.clear();
    this.createdChiefs.clear();
    this.createdChats.clear();
    this.stopVoice();
  }

  disposeDevice(id: string): void {
    if (this.voice?.owner === id) this.stopVoice();
    for (const [key, upload] of this.uploads) if (upload.owner === id) this.removeUpload(key, upload);
    for (const [key, download] of this.downloads) if (download.owner === id) this.downloads.delete(key);
  }

  async request(owner: string, body: Record<string, unknown>): Promise<object> {
    this.prune();
    const client = this.client();
    if (!client) throw new Error("Opscode is starting on your Mac.");
    switch (body.op) {
      case "voice.settings": {
        const [{ settings }, locales, tts] = await Promise.all([
          client.call<{ settings: { voice_locale: string; tts_locale: string; voice_tts_voice: string } }>("settings.get", {}),
          client.call<{ speech: string[] }>("voice.locales", {}),
          client.call<{ installed: boolean; languages: string[]; voices: { id: string; name: string; language: string }[] }>("tts.status", {}),
        ]);
        return { settings: { voice_locale: settings.voice_locale, tts_locale: settings.tts_locale, voice_tts_voice: settings.voice_tts_voice }, speech: locales.speech, installed: tts.installed, languages: tts.languages, voices: tts.voices };
      }
      case "voice.settings.set": {
        const field = body.field, value = body.value;
        if (typeof value !== "string" || typeof field !== "string" || !["voice_locale", "tts_locale", "voice_tts_voice"].includes(field)) throw new Error("Choose a valid voice setting.");
        const info = field === "voice_locale" ? await client.call<{ speech: string[] }>("voice.locales", {}) : await client.call<{ languages: string[]; voices: { id: string }[] }>("tts.status", {});
        const valid = field === "voice_locale" ? value === "auto" || ("speech" in info && info.speech.includes(value)) : field === "tts_locale" ? value === "auto" || ("languages" in info && info.languages.includes(value)) : value === "" || ("voices" in info && info.voices.some((voice) => voice.id === value));
        if (!valid) throw new Error("Choose an available language or voice.");
        await client.call("settings.set", { patch: { [field]: value } });
        return { ok: true };
      }
      case "voice.start": {
        if (this.voice || this.voiceStarting) throw new Error("A mobile voice session is already running.");
        const workspace_id = identifier(body.workspace);
        const chat_id = body.chat ? identifier(body.chat) : undefined;
        if (chat_id) {
          if (await this.chiefFor(client, workspace_id, chat_id)) throw new Error("Open a normal chat for voice mode.");
          await client.call("turn.history", { workspace_id, chat_id });
        }
        this.voiceStarting = true;
        this.earlyVoice = [];
        try {
          const worker = { ...modelPick(body), mode: permissions(body.mode ?? "supervised") };
          const result = await client.call<{ session: string; chat_id?: string }>("voiceagent.start", { workspace_id, ...(chat_id ? { chat_id } : {}), worker }, 30_000);
          this.voice = { owner, session: identifier(result.session), seq: 0, ack: 0, events: [], touched: Date.now() };
          for (const item of this.earlyVoice) this.voiceEvent(item.kind, item.event);
          return { session: result.session, chat: result.chat_id ?? null };
        } finally { this.voiceStarting = false; this.earlyVoice = []; }
      }
      case "voice.poll": {
        const voice = this.requireVoice(owner);
        const ack = integer(body.ack ?? 0, voice.seq);
        if (ack < voice.ack) throw new Error("Voice playback is out of sync.");
        voice.ack = ack;
        while (voice.events.length && voice.events[0].seq <= ack) voice.events.shift();
        return voice.events[0] ?? {};
      }
      case "voice.audio": {
        const voice = this.requireVoice(owner);
        if (typeof body.pcm !== "string" || body.pcm.length > 12000 || !/^[A-Za-z0-9+/]+={0,2}$/.test(body.pcm)) throw new Error("Invalid microphone audio.");
        await client.call("voiceagent.audio", { session: voice.session, pcm: body.pcm });
        return {};
      }
      case "voice.playback": {
        const voice = this.requireVoice(owner);
        if (typeof body.playing !== "boolean") throw new Error("Invalid playback state.");
        await client.call("voiceagent.playback", { session: voice.session, playing: body.playing });
        return {};
      }
      case "voice.progress": {
        const voice = this.requireVoice(owner);
        if (!voice.tts || body.tts !== voice.tts) return {};
        await client.call("tts.progress", { session: voice.tts, played: integer(body.played, 100000) });
        return {};
      }
      case "voice.interrupt": {
        const voice = this.requireVoice(owner);
        await client.call("voiceagent.interrupt", { session: voice.session });
        return {};
      }
      case "voice.stop": {
        this.requireVoice(owner);
        this.stopVoice();
        return {};
      }
      case "projects": {
        const { workspaces } = await client.call<{ workspaces: Workspace[] }>("workspace.list", {});
        const offset = integer(body.offset ?? 0);
        return { projects: workspaces.slice(offset, offset + 50).map(({ id, name }) => ({ id, name: name.slice(0, 160) })),
          more: offset + 50 < workspaces.length };
      }
      case "chats": {
        const workspace_id = identifier(body.workspace);
        const offset = integer(body.offset ?? 0);
        const { chats, running } = await client.call<{ chats: ChatMeta[]; running: string[] }>("chat.list", { workspace_id });
        const { chiefs } = await client.call<{ chiefs: Chief[] }>("chief.list", {});
        const visible = [ ...chats.filter((chat) => !chat.voice).map((entry) => ({
          id: entry.id, ...settingsOf(entry), running: running.includes(entry.id),
        })), ...chiefs.filter((chief) => chief.mode && chief.project_ids.includes(workspace_id)).map((chief) => ({
          id: chief.chat_id, title: chief.title || chief.name, team: chief.mode, running: running.includes(chief.chat_id),
        })) ];
        return { chats: visible.slice(offset, offset + 50), more: offset + 50 < visible.length };
      }
      case "history": {
        const { messages, settings } = await this.history(client, body);
        const before = integer(body.before ?? messages.length, messages.length);
        const page = [];
        let cursor = before;
        let budget = 57_000;
        while (cursor > 0 && page.length < 24) {
          const message = messages[cursor - 1];
          const files = (message.attachments ?? []).flatMap((file, index) =>
            !file.ref && file.kind !== "folder" ? [{ index, name: file.name.slice(0, 160), kind: file.kind }] : []);
          const row = {
            role: message.role, text: message.text.slice(0, 10_000), turn: message.turn_id,
            status: message.status, error: message.error?.slice(0, 500), files,
            ...(message.text.length > 10_000 ? { index: cursor - 1, text_length: message.text.length, revision: createHash("sha256").update(message.text).digest("hex") } : {}),
          };
          let size = Buffer.byteLength(JSON.stringify(row)) + 1;
          // Escaping can make even a short string exceed the relay limit. Always make
          // progress on the first row and expose any remainder through history.text.
          if (size > budget && page.length === 0) {
            row.index = cursor - 1;
            row.text_length = message.text.length;
            row.revision = createHash("sha256").update(message.text).digest("hex");
            while (size > budget && row.text.length > 1) {
              row.text = row.text.slice(0, Math.floor(row.text.length / 2));
              size = Buffer.byteLength(JSON.stringify(row)) + 1;
            }
          }
          if (size > budget) break;
          budget -= size;
          page.unshift(row);
          cursor--;
        }
        return { messages: page, before: cursor, ...(settings ? { settings: settingsOf(settings) } : {}) };
      }
      case "history.text": {
        const { messages } = await this.history(client, body);
        const index = integer(body.index, messages.length ? messages.length - 1 : 0);
        const message = messages[index];
        if (!message || message.turn_id !== identifier(body.turn) || message.role !== body.role || typeof body.revision !== "string" ||
          createHash("sha256").update(message.text).digest("hex") !== body.revision) throw new Error("This message changed. Refresh the conversation and try again.");
        const offset = integer(body.offset, message.text.length);
        return { offset, text: message.text.slice(offset, offset + 8_000) };
      }
      case "project.files": {
        const workspace_id = identifier(body.workspace);
        const path = typeof body.path === "string" ? body.path : "";
        if (path.length > 1024 || path.split("/").some((part) => part === ".." || part.startsWith(".")) || path.startsWith("/")) {
          throw new Error("Choose a folder inside this project.");
        }
        const result = await client.call<{ path: string; entries: { name: string; kind: string }[]; truncated: boolean }>("fs.list", { workspace_id, path });
        return { path: result.path, entries: result.entries.filter((entry) =>
          (entry.kind === "dir" || entry.kind === "file") && !entry.name.startsWith(".") &&
          !/\.(pem|key|p12|pfx|keystore|jks)$/i.test(entry.name) && !/^credentials(\.|$)/i.test(entry.name)
        ).map(({ name, kind }) => ({ name, kind })), truncated: result.truncated };
      }
      case "engines": {
        const [{ engines }, { providers }] = await Promise.all([
          client.call<{ engines: EngineInfo[] }>("engines.list", {}),
          client.call<{ providers: ProviderInfo[] }>("provider.list", {}),
        ]);
        const available = engines.filter((item) => item.found && ENGINES.has(item.id)).map(({ id, label, models }) => ({
          id, label, models: models.slice(0, 50).map((row) => ({ id: row.id, label: row.label, efforts: row.efforts })),
        }));
        const active = providers.find((provider) => provider.active && provider.configured);
        return { engines: [...(active ? [{ id: "api", label: "API key", models: [{ id: active.model, label: active.model }] }] : []), ...available] };
      }
      case "providers": {
        const { providers } = await client.call<{ providers: ProviderInfo[] }>("provider.list", {});
        return { providers: providers.filter((item) => item.configured).map(({ id, label, active, model }) => ({ id, label, active, model })) };
      }
      case "provider.select": {
        const id = identifier(body.provider);
        const { providers } = await client.call<{ providers: ProviderInfo[] }>("provider.list", {});
        if (!providers.some((item) => item.id === id && item.configured)) throw new Error("Set up this provider on your Mac first.");
        await client.call("provider.select", { id });
        return { ok: true };
      }
      case "accounts": {
        const { accounts } = await client.call<{ accounts: { id: string; engine: string; is_default: boolean; active: boolean; status: { signed_in: boolean; email?: string } | null }[] }>("accounts.list", {});
        return { accounts: accounts.map(({ id, engine, is_default, active, status }) => ({ id, engine, is_default, active, signed_in: status?.signed_in ?? false, ...(status?.email ? { email: status.email } : {}) })) };
      }
      case "account.switch": {
        const engine = body.engine;
        if (typeof engine !== "string" || !["claude-code", "codex", "antigravity", "qoder"].includes(engine)) throw new Error("Choose a coding engine.");
        await client.call("accounts.switch", { engine, account_id: identifier(body.account) });
        return { ok: true };
      }
      case "chat.mode":
      case "chat.account":
      case "chat.engine": {
        const workspace_id = identifier(body.workspace);
        const chat_id = identifier(body.chat);
        const { chats } = await client.call<{ chats: ChatMeta[] }>("chat.list", { workspace_id });
        if (!chats.some((chat) => chat.id === chat_id && !chat.voice)) throw new Error("Choose a conversation in this project.");
        const { chat } = body.op === "chat.mode"
          ? await client.call<{ chat: ChatMeta }>("chat.set_mode", { chat_id, mode: permissions(body.mode) })
          : body.op === "chat.account"
            ? await client.call<{ chat: ChatMeta }>("chat.set_account", { chat_id, account_id: identifier(body.account) })
            : await client.call<{ chat: ChatMeta }>("chat.set_engine", { chat_id, ...modelPick(body) });
        return { settings: settingsOf(chat) };
      }
      case "stop": {
        const { messages } = await this.history(client, body);
        const turn = identifier(body.turn);
        if (!messages.some((item) => item.turn_id === turn && item.role === "assistant" && item.status === "streaming")) {
          throw new Error("This task is no longer running.");
        }
        return client.call<{ interrupted: boolean }>("turn.interrupt", { turn_id: turn });
      }
      case "plugins": {
        const { plugins } = await client.call<{ plugins: PluginInfo[] }>("plugin.list", {});
        const offset = integer(body.offset ?? 0);
        return { plugins: plugins.slice(offset, offset + 40).map(({ name, description, enabled, skills, mcp_servers }) => ({
          name: name.slice(0, 120), description: description.slice(0, 320), enabled, skills: skills.length, integrations: mcp_servers.length,
        })), more: offset + 40 < plugins.length };
      }
      case "integrations": {
        const { servers } = await client.call<{ servers: { name: string; state: string; enabled: boolean }[] }>("mcp.list", {});
        return { servers: servers.slice(0, 100).map(({ name, state, enabled }) => ({ name, state, enabled })) };
      }
      case "upload.begin": {
        const workspace = identifier(body.workspace);
        const name = fileName(body.name);
        const size = integer(body.size, FILE_LIMIT);
        const { workspaces } = await client.call<{ workspaces: Workspace[] }>("workspace.list", {});
        if (!workspaces.some((item) => item.id === workspace)) throw new Error("This project is unavailable on the Mac.");
        const current = [...this.uploads.values()];
        if (current.filter((item) => item.owner === owner).length >= 6 ||
          current.reduce((bytes, item) => bytes + item.size, size) > 60 * 1024 * 1024 || current.length >= 32) {
          throw new Error("Too many attachments are waiting. Remove an attachment and try again.");
        }
        const directory = mkdtempSync(join(tmpdir(), "opscode-mobile-"));
        const path = join(directory, name);
        const id = randomUUID();
        try { writeFileSync(path, "", { flag: "wx", mode: 0o600 }); }
        catch (error) { rmSync(directory, { recursive: true, force: true }); throw error; }
        this.uploads.set(id, { owner, workspace, directory, path, size, offset: 0, expiry: Date.now() + EXPIRY });
        return { id };
      }
      case "upload.chunk": {
        const upload = this.upload(owner, body.id);
        if (integer(body.offset, FILE_LIMIT) !== upload.offset || typeof body.data !== "string" ||
          body.data.length > CHUNK * 4 / 3 || !/^[A-Za-z0-9+/]+={0,2}$/.test(body.data)) {
          throw new Error("The attachment transfer is out of sync.");
        }
        const bytes = Buffer.from(body.data, "base64");
        if (!bytes.length || bytes.toString("base64") !== body.data || upload.offset + bytes.length > upload.size) {
          throw new Error("The attachment transfer is invalid.");
        }
        appendFileSync(upload.path, bytes);
        upload.offset += bytes.length;
        upload.expiry = Date.now() + EXPIRY;
        return { offset: upload.offset };
      }
      case "upload.status": {
        const upload = this.uploads.get(identifier(body.id));
        return { ready: upload?.owner === owner && upload.offset === upload.size && !upload.used };
      }
      case "upload.cancel": {
        const id = identifier(body.id);
        const upload = this.uploads.get(id);
        if (upload?.owner === owner && !upload.used) this.removeUpload(id, upload);
        return {};
      }
      case "submit": {
        const id = owner + ":" + identifier(body.id);
        const previous = this.sent.get(id);
        if (previous) return previous.result;
        if (this.sent.size >= 1024) throw new Error("Too many mobile sends. Try again shortly.");
        // Register before awaiting runtime calls so simultaneous retries share the same result.
        const result = this.submit(client, owner, body).catch((error) => { this.sent.delete(id); throw error; });
        this.sent.set(id, { result, expires: Date.now() + EXPIRY });
        return result;
      }
      case "download.begin": {
        const project = identifier(body.workspace);
        const chief = await this.chiefFor(client, project, identifier(body.chat));
        const workspace_id = chief ? `chief:${chief.id}` : project;
        const { messages } = await this.history(client, body);
        const message = messages.find((entry) => entry.role === "user" && entry.turn_id === identifier(body.turn));
        const file = message?.attachments?.[integer(body.index, 11)];
        if (!file || file.ref || file.kind === "folder") throw new Error("This attachment is unavailable.");
        if (this.downloads.size >= 16) throw new Error("Too many downloads are in progress.");
        const { size, revision } = await client.call<{ size: number; revision: string }>(
          "attachment.download_chunk", { workspace_id, path: file.path, offset: 0, limit: 0 },
        );
        if (size > FILE_LIMIT) throw new Error("This attachment is too large to download on mobile.");
        const id = randomUUID();
        this.downloads.set(id, { owner, workspace: workspace_id, path: file.path, size, revision, expiry: Date.now() + EXPIRY });
        return { id, size };
      }
      case "download.chunk": {
        const id = identifier(body.id);
        const download = this.downloads.get(id);
        const offset = integer(body.offset, FILE_LIMIT);
        if (download?.owner !== owner || offset > download.size) throw new Error("This download expired.");
        const reply = await client.call<{ data: string; offset: number }>("attachment.download_chunk", {
          workspace_id: download.workspace, path: download.path, offset, limit: CHUNK, revision: download.revision,
        });
        download.expiry = Date.now() + EXPIRY;
        return { data: reply.data, offset: reply.offset };
      }
      case "download.end": {
        const id = identifier(body.id);
        if (this.downloads.get(id)?.owner === owner) this.downloads.delete(id);
        return {};
      }
      default: throw new Error("This mobile action is unavailable.");
    }
  }

  voiceEvent(kind: "agent" | "tts", event: Record<string, unknown>): void {
    const voice = this.voice;
    if (!voice) {
      if (this.voiceStarting && this.earlyVoice.length < 64) this.earlyVoice.push({ kind, event });
      return;
    }
    if (kind === "agent") {
      if (event.session !== voice.session) return;
      if (!["say_start", "stop_audio", "partial", "heard", "say", "ended", "state", "error"].includes(String(event.ev))) return;
      if (event.ev === "say_start" && typeof event.tts === "string") voice.tts = event.tts;
      event = { ev: event.ev, session: event.session, ...(typeof event.tts === "string" ? { tts: event.tts } : {}), ...(typeof event.text === "string" ? { text: event.text.slice(0, 4000) } : {}), ...(typeof event.state === "string" ? { state: event.state.slice(0, 80) } : {}), ...(typeof event.why === "string" ? { why: event.why.slice(0, 200) } : {}), ...(typeof event.message === "string" ? { message: event.message.slice(0, 500) } : {}) };
    } else if (!voice.tts || event.session !== voice.tts) return;
    const append = (value: Record<string, unknown>) => {
      if (voice.events.length >= 200) { this.stopVoice(); return; }
      voice.events.push({ seq: ++voice.seq, event: value });
    };
    if (kind === "tts" && event.ev === "audio" && typeof event.pcm === "string") {
      const pcm = Buffer.from(event.pcm, "base64");
      for (let offset = 0; offset < pcm.length; offset += 12_000) {
        append({ ev: "audio", tts: event.session, i: event.i, rate: event.rate, first: offset === 0, pcm: pcm.subarray(offset, offset + 12_000).toString("base64") });
      }
    } else append({ ...event, kind });
  }

  private requireVoice(owner: string): MobileVoice {
    if (!this.voice || this.voice.owner !== owner) throw new Error("Your voice session is no longer active.");
    this.voice.touched = Date.now();
    return this.voice;
  }

  private stopVoice(): void {
    const voice = this.voice;
    this.voice = undefined;
    if (voice) void this.client()?.call("voiceagent.stop", { session: voice.session }).catch(() => {});
  }

  private async chiefFor(client: MainRpcClient, workspace: string, chat: string): Promise<Chief | undefined> {
    const { chiefs } = await client.call<{ chiefs: Chief[] }>("chief.list", {});
    return chiefs.find((chief) => chief.chat_id === chat && chief.project_ids.includes(workspace));
  }

  private async history(client: MainRpcClient, body: Record<string, unknown>) {
    const workspace = identifier(body.workspace), chat = identifier(body.chat);
    const chief = await this.chiefFor(client, workspace, chat);
    const result = await client.call<{ messages: ChatMessage[]; settings?: ChatSettings }>("turn.history", {
      workspace_id: chief ? `chief:${chief.id}` : workspace, chat_id: chat,
    });
    return result;
  }

  private async submit(client: MainRpcClient, owner: string, body: Record<string, unknown>): Promise<object> {
    const workspace_id = identifier(body.workspace);
    let chat_id = body.chat ? identifier(body.chat) : undefined;
    if (typeof body.text !== "string" || !body.text.trim() || body.text.length > 8_000) throw new Error("Enter a message of up to 8,000 characters.");
    const uploadIds = body.files ?? [];
    if (!Array.isArray(uploadIds) || uploadIds.length > 6 || new Set(uploadIds).size !== uploadIds.length) throw new Error("Attach up to six files.");
    const projectFiles = body.projectFiles ?? [];
    if (!Array.isArray(projectFiles) || projectFiles.length + uploadIds.length > 6 || new Set(projectFiles).size !== projectFiles.length) throw new Error("Attach up to six files.");
    for (const path of projectFiles) {
      if (typeof path !== "string" || !path || path.length > 1024 || path.startsWith("/") || path.split("/").some((part) => !part || part.startsWith(".")) || /\.(pem|key|p12|pfx|keystore|jks)$/i.test(path) || /(^|\/)credentials(\.|$)/i.test(path)) throw new Error("Choose a valid project file.");
      const parts = path.split("/");
      const name = parts.pop();
      const listing = await client.call<{ entries: { name: string; kind: string }[] }>("fs.list", { workspace_id, path: parts.join("/") });
      if (!listing.entries.some((entry) => entry.name === name && entry.kind === "file")) throw new Error("A project file is no longer available.");
    }
    const pick = modelPick(body);
    const mode = permissions(body.mode ?? "supervised");
    const team = body.team;
    if (team !== undefined && (typeof team !== "string" || !["godmode", "warlord", "shinobi"].includes(team))) throw new Error("Choose a valid team mode.");
    const uploads = uploadIds.map((id) => this.upload(owner, id));
    for (const upload of uploads) {
      if (upload.workspace !== workspace_id || upload.offset !== upload.size || upload.used) throw new Error("An attachment is incomplete or belongs to another project.");
    }
    for (const upload of uploads) upload.used = String(body.id);
    try {
      let chief = chat_id ? await this.chiefFor(client, workspace_id, chat_id) : undefined;
      if (chat_id && !chief) await client.call("turn.history", { workspace_id, chat_id });
      if (!chat_id && team) {
        const key = owner + ":" + identifier(body.id);
        chief = this.createdChiefs.get(key)?.chief;
        if (!chief) {
          if (this.createdChiefs.size >= 1024) throw new Error("Too many mobile sends. Try again shortly.");
          ({ chief } = await client.call<{ chief: Chief }>("chief.create", { mode: team, project_id: workspace_id }));
          this.createdChiefs.set(key, { chief, expires: Date.now() + EXPIRY });
        }
        chat_id = chief.chat_id;
      }
      const attachmentWorkspace = chief ? `chief:${chief.id}` : workspace_id;
      const attachments: string[] = chief ? [] : [...projectFiles];
      if (chief && projectFiles.length) {
        const { workspaces } = await client.call<{ workspaces: Workspace[] }>("workspace.list", {});
        const project = workspaces.find((item) => item.id === workspace_id);
        if (!project) throw new Error("This project is unavailable on the Mac.");
        const { items } = await client.call<{ items: { path: string; ref?: boolean }[] }>("attachment.add", { workspace_id: attachmentWorkspace, paths: projectFiles.map((path) => join(project.path, path)) });
        if (items.length !== projectFiles.length || items.some((item) => item.ref)) throw new Error("A project file could not be attached.");
        attachments.push(...items.map((item) => item.path));
      }
      for (const upload of uploads) {
        if (!upload.imported) {
          const { items } = await client.call<{ items: { path: string; ref?: boolean }[] }>("attachment.add", {
            workspace_id: attachmentWorkspace, paths: [upload.path],
          });
          if (!items[0] || items[0].ref) throw new Error("One of the attachments could not be added.");
          upload.imported = items[0].path;
        }
        attachments.push(upload.imported);
      }
      if (!chat_id) {
        const key = owner + ":" + identifier(body.id);
        const created = this.createdChats.get(key);
        if (created && created.workspace !== workspace_id) throw new Error("This request belongs to another project.");
        if (created) chat_id = created.id;
        else {
          if (this.createdChats.size >= 1024) throw new Error("Too many mobile sends. Try again shortly.");
          const { chat } = await client.call<{ chat: ChatMeta }>("chat.create", { workspace_id, mode, ...pick,
            request_id: createHash("sha256").update(owner + ":" + identifier(body.id)).digest("hex") });
          chat_id = chat.id;
          this.createdChats.set(key, { id: chat_id, workspace: workspace_id, expires: Date.now() + EXPIRY });
        }
      }
      const { turn_id } = chief
        ? await client.call<{ turn_id?: string }>("chief.note", { chief_id: chief.id, text: body.text.trim(), ...(attachments.length ? { attachments } : {}) })
        : await client.call<{ turn_id: string }>("turn.submit", { workspace_id, chat_id, text: body.text.trim(), request_id: createHash("sha256").update(owner + ":" + identifier(body.id)).digest("hex"), ...(attachments.length ? { attachments } : {}) });
      uploadIds.forEach((id, index) => this.removeUpload(id as string, uploads[index]));
      return { chat: chat_id, ...(turn_id ? { turn: turn_id } : {}) };
    } catch (error) {
      for (const upload of uploads) upload.used = undefined;
      throw error;
    }
  }

  private upload(owner: string, value: unknown): Upload {
    const upload = this.uploads.get(identifier(value));
    if (upload?.owner !== owner) throw new Error("This attachment expired. Add it again.");
    return upload;
  }

  private removeUpload(id: string, upload: Upload): void {
    this.uploads.delete(id);
    try { rmSync(upload.directory, { recursive: true, force: true }); } catch { /* A temporary file could not be removed. */ }
  }

  private prune(): void {
    const now = Date.now();
    if (this.voice && this.voice.touched + 30_000 < now) this.stopVoice();
    for (const [id, upload] of this.uploads) if (!upload.used && upload.expiry <= now) this.removeUpload(id, upload);
    for (const [id, download] of this.downloads) if (download.expiry <= now) this.downloads.delete(id);
    for (const [id, sent] of this.sent) if (sent.expires <= now) this.sent.delete(id);
    for (const [id, value] of this.createdChiefs) if (value.expires <= now) this.createdChiefs.delete(id);
    for (const [id, value] of this.createdChats) if (value.expires <= now) this.createdChats.delete(id);
  }
}
