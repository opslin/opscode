import { sign } from "node:crypto";
import { readFileSync } from "node:fs";

interface ServiceAccount { project_id: string; client_email: string; private_key: string }

const tokenUri = "https://oauth2.googleapis.com/token";
const scope = "https://www.googleapis.com/auth/firebase.messaging";
const encode = (value: object): string => Buffer.from(JSON.stringify(value)).toString("base64url");

/** FCM gets a generic approval wake-up. The phone fetches the details from the Mac after unlock. */
export function mobilePush(path: string): (device: string) => Promise<"sent" | "invalid"> {
  const account = JSON.parse(readFileSync(path, "utf8")) as ServiceAccount;
  if (!/^[a-z0-9-]{3,100}$/.test(account.project_id) || typeof account.client_email !== "string" || typeof account.private_key !== "string") {
    throw new Error("Invalid Firebase service account.");
  }
  let cache: { token: string; expires: number } | undefined;
  let acquiring: Promise<string> | undefined;
  async function acquire(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    if (cache && now < cache.expires - 60) return cache.token;
    const message = `${encode({ alg: "RS256", typ: "JWT" })}.${encode({ iss: account.client_email, scope, aud: tokenUri, iat: now, exp: now + 3600 })}`;
    const assertion = `${message}.${sign("RSA-SHA256", Buffer.from(message), account.private_key).toString("base64url")}`;
    const response = await fetch(tokenUri, {
      method: "POST", signal: AbortSignal.timeout(8000), redirect: "error",
      body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
    });
    if (!response.ok) throw new Error("FCM authorization failed");
    const payload = await response.json() as { access_token?: string; expires_in?: number };
    if (typeof payload.access_token !== "string" || typeof payload.expires_in !== "number") throw new Error("FCM authorization invalid");
    cache = { token: payload.access_token, expires: now + payload.expires_in };
    return cache.token;
  }

  return async (device) => {
    acquiring ??= acquire().finally(() => { acquiring = undefined; });
    const token = await acquiring;
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
      method: "POST", redirect: "error", signal: AbortSignal.timeout(8000),
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ message: {
        token: device, data: { kind: "approval" },
        android: { priority: "high", ttl: "120s", collapse_key: "opscode-approval" },
      } }),
    });
    if (response.ok) return "sent";
    if (response.status === 404) {
      const body = await response.json() as { error?: { details?: { errorCode?: string }[] } };
      if (body.error?.details?.some((entry) => entry.errorCode === "UNREGISTERED")) return "invalid";
    }
    throw new Error(`FCM rejected approval push (${response.status})`);
  };
}
