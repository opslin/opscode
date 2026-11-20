// Encrypted companion transport and reconnection. Uses a disposable HTTP/WebSocket relay.
import assert from "node:assert/strict";
import { once } from "node:events";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import WebSocket, { WebSocketServer } from "ws";
import { MobileBridge, sealMobile, openMobile, mobileApprovalRevision } from "../dist/main/mobileBridge.js";
import { MobileWorkspace } from "../dist/main/mobileWorkspace.js";
import { MainRpcClient } from "../dist/main/rpcClient.js";
import { startRuntime, waitFor } from "./lib/harness.mjs";

const path = mkdtempSync(join(tmpdir(), "opscode-mobile-relay-"));
const keyPath = join(path, "devices.json");
const macToken = "2".repeat(64);
const invitation = "3".repeat(64);
const phoneId = "a".repeat(32);
const phoneToken = phoneId + "." + "4".repeat(64);
const header = Buffer.concat([Buffer.from([1]), Buffer.from(phoneId, "hex")]);
const wss = new WebSocketServer({ noServer: true });
let mac;
let phone;
let paired = false;
const event = (socket, value) => {
  if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify(value));
};
const server = createServer((req, res) => {
  const reply = (status, value) => res.writeHead(status, { "Content-Type": "application/json" }).end(JSON.stringify(value));
  if (req.url === "/v1/pair" && req.headers.authorization === "Bearer " + invitation && !paired) {
    paired = true;
    return reply(201, { device_id: phoneId, token: phoneToken });
  }
  if (req.headers.authorization !== "Bearer " + macToken) return reply(401, {});
  if (req.url === "/v1/invite") return reply(201, { token: invitation, expires_at_ms: Date.now() + 120_000 });
  if (req.url === "/v1/devices") return reply(200, { devices: paired ? [{ device_id: phoneId }] : [] });
  if (req.method === "DELETE" && req.url === "/v1/devices/" + phoneId) {
    paired = false;
    phone?.close(4003);
    return reply(200, { revoked: true });
  }
  return reply(404, {});
});
server.on("upgrade", (req, socket, head) => {
  const isMac = req.url === "/v1/socket/mac" && req.headers.authorization === "Bearer " + macToken;
  const isPhone = req.url === "/v1/socket/phone" && paired && req.headers.authorization === "Bearer " + phoneToken;
  assert.ok(isMac || isPhone);
  wss.handleUpgrade(req, socket, head, (client) => {
    if (isMac) {
      mac = client;
      event(mac, { type: "relay.ready", protocol: 1, online_phone_ids: phone ? [phoneId] : [] });
      event(phone, { type: "relay.presence", peer: "mac", online: true });
    } else {
      phone = client;
      event(phone, { type: "relay.ready", protocol: 1, mac_online: mac?.readyState === WebSocket.OPEN });
    }
    client.on("message", (payload, binary) => {
      if (!binary) { if (payload.toString() === "ping") client.send("pong"); return; }
      if (isMac && phone?.readyState === WebSocket.OPEN) {
        assert.deepEqual(payload.subarray(0, 17), header);
        phone.send(payload.subarray(17));
      } else if (isPhone && mac?.readyState === WebSocket.OPEN) {
        mac.send(Buffer.concat([header, payload]));
      }
    });
    client.on("close", () => {
      if (isMac && mac === client) {
        mac = undefined;
        event(phone, { type: "relay.presence", peer: "mac", online: false });
      } else if (isPhone && phone === client) {
        phone = undefined;
        event(mac, { type: "relay.presence", peer: "phone", device_id: phoneId, online: false });
      }
    });
  });
});
server.listen(0, "127.0.0.1");
await once(server, "listening");
const origin = "http://127.0.0.1:" + server.address().port;

const approval = { turn_id: "turn-123", call_id: "call-456", tool: "test", summary: "Approve a test", at: 5 };
const makeFeed = (title, approvals = []) => ({
  sessions: [{ title, project: "Demo", engine: "codex", status: approvals.length ? "needs" : "working", line: "Checking…", approvals }],
  counts: { working: approvals.length ? 0 : 1, needs: Number(approvals.length > 0), unseen: 0 },
});
let feed = null;
let decisions = 0;
let pairedEvents = 0;
let runtime;
let rpc = null;
const workspace = new MobileWorkspace(() => rpc);
const create = () => new MobileBridge({
  origin, token: macToken, path: keyPath, label: "Test Mac",
  feed: () => feed, onPaired: () => pairedEvents++,
  decide: async ({ revision }) => {
    decisions++;
    return revision === mobileApprovalRevision(approval);
  },
  log: console.error,
  workspace: (owner, body) => workspace.request(owner, body),
});
let bridge = create();
const phones = [];
let key;
async function connectPhone() {
  const ws = new WebSocket(origin.replace("http:", "ws:") + "/v1/socket/phone",
    { headers: { Authorization: "Bearer " + phoneToken } });
  phones.push(ws);
  const messages = [];
  ws.on("message", (bytes, binary) => {
    if (binary) messages.push(openMobile(key, phoneId, "mac", bytes));
    else messages.push(JSON.parse(bytes.toString()));
  });
  await once(ws, "open");
  return {
    ws,
    send: (value) => ws.send(sealMobile(key, phoneId, "phone", value)),
    async get(type, pred = () => true) {
      const until = Date.now() + 2_000;
      while (Date.now() < until) {
        const index = messages.findIndex((value) => value.type === type && pred(value));
        if (index !== -1) return messages.splice(index, 1)[0];
        await sleep(5);
      }
      assert.fail("No relay message " + type);
    },
  };
}

try {
  bridge.start();
  const invite = new URL((await bridge.invite()).url);
  assert.equal(invite.origin, "null");
  assert.equal(invite.hostname, "v2");
  key = invite.searchParams.get("key");
  assert.match(key, /^[a-f0-9]{64}$/);
  assert.equal(invite.searchParams.get("code"), invitation);
  assert.equal((statSync(keyPath).mode & 0o777), 0o600);
  const proof = { challenge: "1".repeat(32), type: "hello", name: "Android" };
  const tampered = sealMobile(key, phoneId, "phone", proof);
  tampered[15] ^= 1;
  assert.throws(() => openMobile(key, phoneId, "phone", tampered));
  assert.throws(() => openMobile(key, phoneId, "mac", sealMobile(key, phoneId, "phone", proof)));
  assert.throws(() => openMobile(key, "b".repeat(32), "phone", sealMobile(key, phoneId, "phone", proof)));

  const eligibility = { Authorization: "Bearer " + invitation };
  const redeem = () => fetch(origin + "/v1/pair", { method: "POST", headers: eligibility });
  assert.equal((await redeem()).status, 201);
  assert.equal((await redeem()).status, 401);

  // Restart before the first authenticated hello. The QR key already survived on disk.
  bridge.stop();
  bridge = create();
  bridge.start();
  let android = await connectPhone();
  const online = await android.get("relay.ready");
  if (!online.mac_online) await android.get("relay.presence", (value) => value.online);
  android.ws.send(tampered);
  android.send(proof);
  const first = await android.get("welcome");
  assert.equal(first.challenge, proof.challenge);
  assert.equal(first.workspace, true);
  assert.equal((await android.get("feed")).feed, null);
  assert.equal(pairedEvents, 1);

  feed = makeFeed("Project started after pairing", [approval]);
  bridge.publish();
  const live = await android.get("feed");
  assert.equal(live.feed.sessions[0].title, "Project started after pairing");
  assert.ok(live.version > 1);
  const decision = { type: "decision", session: first.session, seq: 1, body: {
    turn_id: approval.turn_id, call_id: approval.call_id, revision: mobileApprovalRevision(approval), allow: true,
  } };
  android.send(decision);
  android.send(decision);
  assert.equal((await android.get("result")).status, 200);

  // Mac restart while the Android socket stays alive. New work is in the first fresh snapshot.
  bridge.stop();
  feed = makeFeed("New project after Mac restart");
  bridge = create();
  bridge.start();
  await android.get("relay.presence", (value) => value.online);
  android.send({ ...proof, challenge: "2".repeat(32) });
  const second = await android.get("welcome");
  assert.notEqual(second.session, first.session);
  assert.equal((await android.get("feed")).feed.sessions[0].title, "New project after Mac restart");
  android.send({ ...decision, seq: 2 });
  assert.equal(pairedEvents, 1);

  // Phone process/network restart with the same saved credential and no new QR.
  android.ws.terminate();
  feed = makeFeed("Work started while Android was away");
  android = await connectPhone();
  assert.ok((await android.get("relay.ready")).mac_online);
  android.send({ ...proof, challenge: "3".repeat(32) });
  const third = await android.get("welcome");
  assert.notEqual(third.session, second.session);
  const resumed = await android.get("feed");
  assert.equal(resumed.feed.sessions[0].title, "Work started while Android was away");
  android.send({ type: "sync", session: third.session, seq: 1 });
  assert.ok((await android.get("feed")).version > resumed.version);
  assert.equal(decisions, 1);
  assert.equal(pairedEvents, 1);
  assert.ok(bridge.list()[0].connected);

  runtime = await startRuntime();
  assert.ok(runtime.ready);
  rpc = new MainRpcClient(runtime);
  await rpc.open();
  const directory = join(path, "mobile-project");
  mkdirSync(directory);
  const { workspace: project } = await rpc.call("workspace.add", { path: directory });
  const turns = [];
  rpc.on("turn.event", (event) => {
    turns.push(event);
    bridge.workspaceChanged();
  });
  let sequence = 1;
  async function mobile(op, payload = {}, error) {
    const seq = ++sequence;
    android.send({ type: "workspace", session: third.session, seq, body: { op, ...payload } });
    const status = await android.get("workspace.result", (value) => value.seq === seq);
    if (error) assert.match(status.error, error);
    else assert.equal(status.error, undefined);
    return status.data;
  }
  assert.deepEqual((await mobile("projects")).projects, [{ id: project.id, name: project.name }]);
  // A conversation created on the Mac after pairing must appear on mobile, with its complete history.
  const desktopChat = (await rpc.call("chat.create", { workspace_id: project.id, engine: "api", model: "desktop-test-model" })).chat;
  const longDesktopText = "Project history · नमस्ते 🙂 ".repeat(900);
  await rpc.call("turn.submit", { workspace_id: project.id, chat_id: desktopChat.id, text: longDesktopText });
  const desktopListing = await mobile("chats", { workspace: project.id });
  assert.ok(desktopListing.chats.some((entry) => entry.id === desktopChat.id));
  const desktopHistory = await mobile("history", { workspace: project.id, chat: desktopChat.id });
  const longMessage = desktopHistory.messages.find((entry) => entry.role === "user");
  assert.equal(longMessage.text_length, longDesktopText.length);
  let wholeText = longMessage.text;
  while (wholeText.length < longMessage.text_length) {
    const part = await mobile("history.text", { workspace: project.id, chat: desktopChat.id, index: longMessage.index,
      turn: longMessage.turn, role: longMessage.role, revision: longMessage.revision, offset: wholeText.length });
    assert.equal(part.offset, wholeText.length);
    wholeText += part.text;
  }
  assert.equal(wholeText, longDesktopText);
  assert.deepEqual((await mobile("plugins")).plugins, []);
  await mobile("fs.read", { path: "/etc/passwd" }, /unavailable/);
  mkdirSync(join(directory, "src"));
  writeFileSync(join(directory, "src", "example.txt"), "Mac project file");
  writeFileSync(join(directory, ".env"), "private");
  assert.deepEqual((await mobile("project.files", { workspace: project.id, path: "src" })).entries, [{ name: "example.txt", kind: "file" }]);
  assert.ok(!(await mobile("project.files", { workspace: project.id })).entries.some((item) => item.name === ".env"));
  await mobile("project.files", { workspace: project.id, path: "../" }, /folder inside/);
  await mobile("submit", { workspace: project.id, id: "invalid-project-file", text: "test", projectFiles: ["../outside"] }, /valid project file/);
  const source = Buffer.alloc(1_100_000, 0x61);
  const png = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==", "base64");
  async function transfer(name, bytes) {
    const { id } = await mobile("upload.begin", { workspace: project.id, name, size: bytes.length });
    await assert.rejects(workspace.request("another-device", { op: "upload.chunk", id, offset: 0, data: "YQ==" }), /expired/);
    await mobile("upload.chunk", { id, offset: 1, data: "YQ==" }, /out of sync/);
    for (let offset = 0; offset < bytes.length; offset += 36 * 1024) {
      const chunk = bytes.subarray(offset, offset + 36 * 1024);
      assert.equal((await mobile("upload.chunk", { id, offset, data: chunk.toString("base64") })).offset, offset + chunk.length);
    }
    return id;
  }
  const textFile = await transfer("sample.txt", source);
  const photo = await transfer("photo.png", png);
  const action = { id: "send-1", workspace: project.id, text: "Look at this photo", files: [textFile, photo], mode: "auto_edits", engine: "api", model: "mobile-selected-model", effort: "high" };
  const sent = await mobile("submit", action);
  assert.deepEqual(await mobile("submit", action), sent);
  assert.ok(await waitFor(() => turns.some((turn) => turn.turn_id === sent.turn && turn.type === "completed"), 5000));
  await android.get("workspace.changed");
  assert.ok((await mobile("chats", { workspace: project.id })).chats.some((entry) => entry.id === sent.chat));
  const conversation = { workspace: project.id, chat: sent.chat };
  const { messages, settings } = await mobile("history", conversation);
  assert.equal(settings.mode, "auto_edits");
  assert.equal(settings.engine, "api");
  assert.equal(settings.model, "mobile-selected-model");
  assert.equal(settings.effort, "high");
  for (const mode of ["supervised", "auto_edits", "auto", "full", "read"]) {
    assert.equal((await mobile("chat.mode", { ...conversation, mode })).settings.mode, mode);
  }
  assert.equal((await mobile("chat.engine", { ...conversation, engine: "api" })).settings.engine, "api");
  await mobile("chat.mode", { ...conversation, workspace: "other-project", mode: "auto" }, /choose a conversation/i);
  await mobile("chat.mode", { ...conversation, mode: "invalid" }, /permission mode/i);
  assert.equal(messages[0].text, action.text);
  assert.deepEqual(messages[0].files.map(({ kind, name }) => [kind, name]), [["file", "sample.txt"], ["image", "photo.png"]]);
  assert.equal(messages.at(-1).role, "assistant");
  const actual = (await rpc.call("turn.history", { chat_id: sent.chat })).messages[0].attachments;
  assert.deepEqual(readFileSync(join(directory, actual[1].path)), png);
  const { id: downloadId, size } = await mobile("download.begin", { ...conversation, turn: sent.turn, index: 0 });
  const download = [];
  for (let offset = 0; offset < size;) {
    const chunk = await mobile("download.chunk", { id: downloadId, offset });
    download.push(Buffer.from(chunk.data, "base64"));
    offset = chunk.offset;
  }
  assert.deepEqual(Buffer.concat(download), source);
  writeFileSync(join(directory, actual[0].path), "Replaced attachment");
  await mobile("download.chunk", { id: downloadId, offset: 0 }, /changed during transfer/);
  await mobile("download.end", { id: downloadId });
  const followup = await mobile("submit", { ...conversation, id: "send-2", text: "Follow up from mobile", projectFiles: ["src/example.txt"] });
  assert.equal(followup.chat, sent.chat);
  const followed = await rpc.call("turn.history", { chat_id: sent.chat });
  assert.ok(followed.messages.some((message) => message.turn_id === followup.turn && message.attachments?.[0]?.path === "src/example.txt"));
  console.log("PASS  encrypted projects, plugins, new task, follow-up, photo and file transfers through the real Mac runtime");

  const revoked = once(android.ws, "close", { signal: AbortSignal.timeout(2000) });
  await bridge.revoke(phoneId);
  assert.equal((await revoked)[0], 4003);
  assert.deepEqual(bridge.list(), []);
  console.log("PASS  encrypted mobile pairing, pushed activity, replay rejection, Mac restart, phone reconnect, and revocation");
} finally {
  workspace.stop();
  rpc?.close();
  await runtime?.stop();
  bridge.stop();
  for (const socket of phones) socket.terminate();
  for (const socket of wss.clients) socket.terminate();
  wss.close();
  server.closeAllConnections();
  server.close();
  rmSync(path, { recursive: true, force: true });
}
