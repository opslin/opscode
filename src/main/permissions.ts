// Web permissions. Electron grants every permission request by default, and the in-app browser shows arbitrary websites,
// so once the person allows the microphone for Opscode any page there could ask for it too. Here:
//   - the app's own pages may use the microphone (audio only: voice mode) and write to the clipboard;
//   - everything else, and every page in the in-app browser's partition, is refused.

import { session } from "electron";
import { APP_URL, GUEST_PARTITION } from "../shared/ipc";

const own = (url: string | undefined): boolean => typeof url === "string" && url.startsWith(APP_URL);

export function lockDownPermissions(): void {
  const mine = session.defaultSession;
  mine.setPermissionRequestHandler((_wc, permission, callback, details) => {
    const d = details as { requestingUrl?: string; mediaTypes?: string[] };
    if (!own(d.requestingUrl ?? _wc.getURL())) return callback(false);
    if (permission === "media") return callback(Array.isArray(d.mediaTypes) && d.mediaTypes.length > 0 && d.mediaTypes.every((m) => m === "audio"));
    callback(permission === "clipboard-sanitized-write");
  });
  mine.setPermissionCheckHandler((_wc, permission, origin) => own(origin.endsWith("/") ? origin : `${origin}/`) && (permission === "media" || permission === "clipboard-sanitized-write"));

  const guest = session.fromPartition(GUEST_PARTITION);
  guest.setPermissionRequestHandler((_wc, _permission, callback) => callback(false));
  guest.setPermissionCheckHandler(() => false);
}
