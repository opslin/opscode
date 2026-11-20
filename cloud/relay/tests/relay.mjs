import assert from "node:assert/strict";
import { once } from "node:events";
import { setTimeout as sleep } from "node:timers/promises";
import { test } from "node:test";
import WebSocket from "ws";

const root = new URL(process.env.OPSCODE_TEST_RELAY_URL || "http://127.0.0.1:8787");
assert.equal(root.hostname, "127.0.0.1", "Tests require a disposable local relay");
const token = process.env.OPSCODE_TEST_MAC_TOKEN;
assert.match(token ?? "", /^[a-f0-9]{64}$/, "Set the disposable local relay's Mac token");

function headers(credential) {
  return credential ? { authorization: `Bearer ${credential}` } : {};
}

const url = (path) => new URL(path, root);
async function request(path, method, credential, status) {
  const response = await fetch(url(path), { method, headers: headers(credential) });
  assert.equal(response.status, status, `${method} ${path}`);
  assert.equal(response.headers.get("cache-control"), "no-store");
  return response.json();
}

const socketUrl = (role) => {
  const address = url(`/v1/socket/${role}`);
  address.protocol = address.protocol === "https:" ? "wss:" : "ws:";
  return address;
};

async function connect(role, credential, all, { captureBinary = true } = {}) {
  const socket = new WebSocket(socketUrl(role), { headers: headers(credential), handshakeTimeout: 5000 });
  all.push(socket);
  const queue = [];
  let readyAt;
  socket.on("message", (data, binary) => {
    if (binary) {
      if (captureBinary) queue.push(data);
    }
    else {
      const message = data.toString();
      const parsed = message === "pong" ? message : JSON.parse(message);
      if (parsed.type === "relay.ready") readyAt = performance.now();
      queue.push(parsed);
    }
  });
  await once(socket, "open");
  return {
    socket,
    get readyAt() { return readyAt; },
    async receive(matches) {
      for (const deadline = Date.now() + 3000; Date.now() < deadline; await sleep(10)) {
        const i = queue.findIndex(matches);
        if (i !== -1) return queue.splice(i, 1)[0];
      }
      assert.fail(`Timed out waiting on the ${role} socket`);
    },
    async event(type, matches = () => true) {
      return this.receive((value) => value.type === type && matches(value));
    },
  };
}

async function rejectsSocket(role, credential) {
  const ws = new WebSocket(socketUrl(role), { headers: headers(credential), handshakeTimeout: 5000 });
  try {
    await assert.rejects(once(ws, "open"), /Unexpected server response: 401/);
  } finally {
    ws.terminate();
  }
}

function route(id, bytes) {
  return Buffer.concat([Buffer.from([1]), Buffer.from(id, "hex"), bytes]);
}

async function closed(socket, label) {
  try {
    const start = performance.now();
    const result = await once(socket, "close", { signal: AbortSignal.timeout(15000) });
    if (process.env.OPSCODE_TEST_CLOSE_TIMING === "1") {
      console.log(`${label} closed in ${(performance.now() - start).toFixed(2)}ms with code ${result[0]}`);
    }
    return result;
  } catch (error) {
    throw new Error(`Timed out waiting for ${label} to close`, { cause: error });
  }
}

test("authorizes pairing and routes audio-shaped binary frames across reconnects", { timeout: 45000 }, async () => {
  const sockets = [];
  const paired = [];
  try {
    assert.deepEqual(await request("/health", "GET", null, 200), { ok: true, protocol: 1 });
    await request("/v1/devices", "GET", null, 401);
    await request("/v1/invite", "POST", "a".repeat(64), 401);
    await request("/v1/socket/mac?token=example", "GET", token, 400);
    await request("/v1/socket/mac", "GET", token, 426);
    await rejectsSocket("phone", token);
    await rejectsSocket("mac", "a".repeat(64));

    const createInvite = () => request("/v1/invite", "POST", token, 201);
    const stale = await createInvite();
    const invite = await createInvite();
    assert.ok(invite.expires_at_ms > Date.now());
    await request("/v1/pair", "POST", stale.token, 401);
    const attempts = await Promise.all(
      Array.from({ length: 2 }, () => fetch(url("/v1/pair"), { method: "POST", headers: headers(invite.token) })),
    );
    assert.deepEqual(attempts.map((response) => response.status).sort(), [201, 401]);
    const device = await attempts.find((response) => response.status === 201).json();
    paired.push(device.device_id);
    await request("/v1/pair", "POST", invite.token, 401);
    const second = await createInvite();
    const secondDevice = await request("/v1/pair", "POST", second.token, 201);
    paired.push(secondDevice.device_id);

    const phone = await connect("phone", device.token, sockets);
    assert.equal((await phone.event("relay.ready")).mac_online, false);
    phone.socket.send("ping");
    assert.equal(await phone.receive((value) => value === "pong"), "pong");
    phone.socket.send(Buffer.from([10]));
    await phone.event("relay.unavailable", (value) => value.peer === "mac");

    const mac = await connect("mac", token, sockets);
    assert.deepEqual((await mac.event("relay.ready")).online_phone_ids, [device.device_id]);
    await phone.event("relay.presence", (value) => value.peer === "mac" && value.online);
    const other = await connect("phone", secondDevice.token, sockets);
    assert.equal((await other.event("relay.ready")).mac_online, true);
    await rejectsSocket("phone", `${device.device_id}.${secondDevice.token.split(".")[1]}`);
    await rejectsSocket("mac", device.token);
    await request(`/v1/devices/${secondDevice.device_id}`, "DELETE", device.token, 401);

    const mic = Buffer.from([0, 254, 255, 0, 170]);
    phone.socket.send(mic);
    assert.deepEqual(await mac.receive(Buffer.isBuffer), route(device.device_id, mic));
    const pretendsToBeOtherPhone = route(secondDevice.device_id, mic);
    phone.socket.send(pretendsToBeOtherPhone);
    assert.deepEqual(
      await mac.receive(Buffer.isBuffer),
      route(device.device_id, pretendsToBeOtherPhone),
    );
    const replyToFirst = Buffer.from([5, 0, 9]);
    const replyToSecond = Buffer.from([44, 0, 9]);
    mac.socket.send(route(device.device_id, replyToFirst));
    mac.socket.send(route(secondDevice.device_id, replyToSecond));
    assert.deepEqual(await phone.receive(Buffer.isBuffer), replyToFirst);
    assert.deepEqual(await other.receive(Buffer.isBuffer), replyToSecond);
    const maxFrame = Buffer.alloc(64 * 1024, 0x5a);
    phone.socket.send(maxFrame);
    assert.deepEqual(await mac.receive(Buffer.isBuffer), route(device.device_id, maxFrame));

    const previousClosed = closed(phone.socket, "the superseded phone");
    const resumed = await connect("phone", device.token, sockets);
    assert.equal((await resumed.event("relay.ready")).mac_online, true);
    assert.equal((await previousClosed)[0], 4001);
    resumed.socket.send(mic);
    assert.deepEqual(await mac.receive(Buffer.isBuffer), route(device.device_id, mic));

    const macClosed = closed(mac.socket, "the first Mac connection");
    mac.socket.close(1000);
    assert.equal((await macClosed)[0], 1000);
    await resumed.event("relay.presence", (value) => value.peer === "mac" && !value.online);
    const newMac = await connect("mac", token, sockets);
    const online = (await newMac.event("relay.ready")).online_phone_ids;
    assert.deepEqual(online.sort(), paired.slice().sort());
    await resumed.event("relay.presence", (value) => value.peer === "mac" && value.online);

    const replacedMac = closed(newMac.socket, "the superseded Mac");
    const latestMac = await connect("mac", token, sockets);
    assert.deepEqual((await latestMac.event("relay.ready")).online_phone_ids.sort(), paired.slice().sort());
    await resumed.event("relay.presence", (value) => value.peer === "mac" && value.online);
    assert.equal((await replacedMac)[0], 4001);

    resumed.socket.terminate();
    await latestMac.event("relay.presence", (value) => value.device_id === device.device_id && !value.online);
    const afterLoss = await connect("phone", device.token, sockets);
    assert.equal((await afterLoss.event("relay.ready")).mac_online, true);
    await latestMac.event("relay.presence", (value) => value.device_id === device.device_id && value.online);
    latestMac.socket.send(route(device.device_id, replyToFirst));
    assert.deepEqual(await afterLoss.receive(Buffer.isBuffer), replyToFirst);

    const inventory = await request("/v1/devices", "GET", token, 200);
    assert.ok(inventory.devices.find((value) => value.device_id === device.device_id && value.online));
    const revokedClosed = closed(afterLoss.socket, "the revoked phone");
    const revocationStart = performance.now();
    assert.deepEqual(await request(`/v1/devices/${device.device_id}`, "DELETE", token, 200), { revoked: true });
    if (process.env.OPSCODE_TEST_CLOSE_TIMING === "1") {
      console.log(`Revocation request completed in ${(performance.now() - revocationStart).toFixed(2)}ms`);
    }
    latestMac.socket.send(route(device.device_id, replyToFirst));
    await latestMac.event("relay.unavailable", (value) => value.device_id === device.device_id);
    await rejectsSocket("phone", device.token);
    assert.equal((await revokedClosed)[0], 4003);

    const oversizedClosed = closed(other.socket, "the phone with an oversized frame");
    other.socket.send(Buffer.alloc(64 * 1024 + 1));
    assert.equal((await oversizedClosed)[0], 1009);
    await request("/v1/device", "DELETE", token, 401);
    assert.deepEqual(await request("/v1/device", "DELETE", secondDevice.token, 200), { revoked: true });
    await rejectsSocket("phone", secondDevice.token);
  } finally {
    for (const socket of sockets) socket.terminate();
    await Promise.allSettled(paired.map((id) => request(`/v1/devices/${id}`, "DELETE", token, 200)));
  }
});

test("sustains simultaneous live streams, isolates phones, and reconnects under load", { timeout: 60000 }, async (t) => {
  const sockets = [];
  const devices = [];
  const macListener = new AbortController();
  const addDevice = async () => {
    const invite = await request("/v1/invite", "POST", token, 201);
    const device = await request("/v1/pair", "POST", invite.token, 201);
    devices.push(device);
    return device;
  };
  try {
    for (let slot = 0; slot < 16; slot++) await addDevice();
    const limit = await request("/v1/invite", "POST", token, 201);
    await request("/v1/pair", "POST", limit.token, 409);
    const mac = await connect("mac", token, sockets, { captureBinary: false });
    await mac.event("relay.ready");
    const phones = await Promise.all(devices.map((device) =>
      connect("phone", device.token, sockets, { captureBinary: false }),
    ));
    await Promise.all(phones.map((phone) => phone.event("relay.ready")));

    const ids = devices.map((device) => device.device_id);
    const framesPerPhone = 600;
    const latency = [];
    const started = Array.from({ length: phones.length }, () => []);
    const received = Array(phones.length).fill(0);
    const { promise: waitForEchoes, resolve, reject } = Promise.withResolvers();
    macListener.signal.addEventListener("abort", () => reject(macListener.signal.reason), { once: true });
    mac.socket.on("message", (frame, binary) => {
      if (!binary || macListener.signal.aborted) return;
      try {
        assert.equal(frame.length, 17 + 640);
        assert.equal(frame[0], 1);
        assert.equal(frame.subarray(1, 17).toString("hex"), ids[frame[17]]);
        mac.socket.send(frame);
      } catch (error) {
        macListener.abort(error);
      }
    });
    const attach = (phone, slot) => phone.socket.on("message", (frame, binary) => {
      if (!binary || macListener.signal.aborted) return;
      try {
        assert.equal(frame.length, 640);
        assert.equal(frame[0], slot, "the relay must isolate phones");
        const sequence = frame.readUInt32BE(1);
        assert.equal(sequence, received[slot]++, "frames must arrive once and in order");
        assert.equal(frame[639], (slot + sequence) % 256, "payload bytes must survive");
        latency.push(performance.now() - started[slot][sequence]);
        if (latency.length === phones.length * framesPerPhone) resolve();
      } catch (error) {
        macListener.abort(error);
      }
    });
    for (const [slot, phone] of phones.entries()) attach(phone, slot);
    // Observe listener assertions immediately even while the sending loop is active.
    void waitForEchoes.catch(() => {});

    const cadence = performance.now();
    let reconnectMs;
    let superseded;
    for (let sequence = 0; sequence < framesPerPhone; sequence++) {
      macListener.signal.throwIfAborted();
      if (sequence === 300) {
        // Let the earlier sends for this phone drain before replacing its transport.
        for (const deadline = performance.now() + 2000; received[0] < sequence;) {
          assert.ok(performance.now() < deadline, "first phone drained before reconnect");
          await sleep(5);
        }
        const began = performance.now();
        superseded = closed(phones[0].socket, "superseded phone under load");
        void superseded.catch(() => {});
        phones[0] = await connect("phone", devices[0].token, sockets, { captureBinary: false });
        attach(phones[0], 0);
        await phones[0].event("relay.ready");
        reconnectMs = phones[0].readyAt - began;
      }
      for (const [slot, phone] of phones.entries()) {
        const audio = Buffer.alloc(640);
        audio[0] = slot;
        audio.writeUInt32BE(sequence, 1);
        audio[639] = (slot + sequence) % 256;
        started[slot][sequence] = performance.now();
        phone.socket.send(audio);
      }
      await sleep(Math.max(1, cadence + (sequence + 1) * 20 - performance.now()));
    }
    await Promise.race([
      waitForEchoes,
      sleep(3000, undefined, { ref: false }).then(() => assert.fail("Some frames were lost")),
    ]);
    assert.equal((await superseded)[0], 4001);
    latency.sort((a, b) => a - b);
    const percentile = (p) => latency[Math.ceil(latency.length * p) - 1].toFixed(2);
    t.diagnostic(`Local echo RTT over ${latency.length} round trips: p50=${percentile(.5)}ms p95=${percentile(.95)}ms p99=${percentile(.99)}ms max=${percentile(1)}ms`);
    t.diagnostic(`Local reconnect to ready: ${reconnectMs.toFixed(2)}ms`);
  } finally {
    macListener.abort();
    for (const socket of sockets) socket.terminate();
    await Promise.allSettled(devices.map(({ device_id }) =>
      request(`/v1/devices/${device_id}`, "DELETE", token, 200),
    ));
  }
});

test("bounds frame floods and HTTP connection attempts", { timeout: 35000 }, async () => {
  const sockets = [];
  let device;
  try {
    const invite = await request("/v1/invite", "POST", token, 201);
    device = await request("/v1/pair", "POST", invite.token, 201);
    const phone = await connect("phone", device.token, sockets);
    await phone.event("relay.ready");
    const kicked = closed(phone.socket, "a phone exceeding its frame budget");
    for (let i = 0; i < 240; i++) phone.socket.send(Buffer.from([1]));
    assert.equal((await kicked)[0], 4029);
    const fake = "f".repeat(64);
    const response = await (async () => {
      for (let attempt = 0; attempt < 100; attempt++) {
        const result = await fetch(url("/v1/pair"), { method: "POST", headers: headers(fake) });
        if (result.status === 429) return result;
        assert.equal(result.status, 401);
        await result.arrayBuffer();
      }
    })();
    assert.equal(response?.headers.get("retry-after"), "10");
  } finally {
    for (const socket of sockets) socket.terminate();
    if (device) await request(`/v1/devices/${device.device_id}`, "DELETE", token, 200);
  }
});
