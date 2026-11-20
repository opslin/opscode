import { app, BrowserWindow, clipboard, dialog, powerMonitor } from "electron";
import { execFile } from "node:child_process";
import { hostname, userInfo } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import { MOBILE_ORIGIN, MobileBridge, type MobileDevice } from "./mobileBridge";
import { mobilePush } from "./mobilePush";

export interface MobileStatus { devices: MobileDevice[]; relay: "connecting" | "online" | "unconfigured" }
type BridgeOptions = ConstructorParameters<typeof MobileBridge>[0];

export class MobilePairing {
  private window?: BrowserWindow;
  private busy = false;
  private stopped = false;
  private bridge?: MobileBridge;
  private initializing?: Promise<MobileBridge>;
  private readonly resume = () => this.bridge?.reconnect();

  constructor(private readonly options: Pick<BridgeOptions, "feed" | "decide" | "log" | "workspace" | "onRevoked">) {
    powerMonitor.on("resume", this.resume);
    void this.start().catch(() => options.log("mobile: Opscode relay credential is unavailable"));
  }

  status(): MobileStatus {
    return { devices: this.bridge?.list() ?? [], relay: this.bridge?.online ? "online" : this.bridge || this.initializing ? "connecting" : "unconfigured" };
  }

  async revoke(id: string): Promise<void> { await (await this.start()).revoke(id); }
  notifyApproval(): void { this.bridge?.notifyApproval(); }
  publish(): void { this.bridge?.publish(); }
  workspaceChanged(): void { this.bridge?.workspaceChanged(); }

  async show(reportInWindow = true): Promise<void> {
    if (this.busy || this.stopped) return;
    if (this.window && !this.window.isDestroyed()) { this.window.focus(); return; }
    this.busy = true;
    try {
      const bridge = await this.start();
      if (this.stopped) return;
      const invite = await bridge.invite();
      const png = await qrPng(invite.url);
      if (this.stopped) return;
      const win = new BrowserWindow({
        width: 425, height: 465, title: "Pair Android", show: false, resizable: false,
        minimizable: false, maximizable: false, backgroundColor: "#151417",
        webPreferences: { sandbox: true, contextIsolation: true, nodeIntegration: false },
      });
      this.window = win;
      const timer = setTimeout(() => { if (!win.isDestroyed()) win.close(); }, Math.max(0, invite.expires - Date.now()));
      win.on("closed", () => {
        clearTimeout(timer);
        if (this.window === win) this.window = undefined;
      });
      win.webContents.setWindowOpenHandler(({ url }) => {
        if (url === "https://copy-link.invalid/" && Date.now() < invite.expires) clipboard.writeText(invite.url);
        return { action: "deny" };
      });
      win.webContents.on("will-navigate", (event) => event.preventDefault());
      await win.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(pairPage(png))}`);
      if (!win.isDestroyed()) win.show();
    } catch (error) {
      this.window?.close();
      const message = error instanceof Error ? error.message : "Pairing could not start.";
      this.options.log(`mobile: pairing could not start: ${message}`);
      if (!reportInWindow) throw new Error(message);
      if (!this.stopped) await dialog.showMessageBox({ type: "error", title: "Opscode Mobile", message });
    } finally { this.busy = false; }
  }

  stop(): void {
    this.stopped = true;
    powerMonitor.removeListener("resume", this.resume);
    this.window?.close();
    this.bridge?.stop();
  }

  private start(): Promise<MobileBridge> {
    if (this.bridge) return Promise.resolve(this.bridge);
    return this.initializing ??= relayCredential().then((token) => {
      if (this.stopped) throw new Error("Opscode is closing.");
      let push: BridgeOptions["push"];
      if (process.env.OPSCODE_MOBILE_FCM_ACCOUNT) {
        try { push = mobilePush(process.env.OPSCODE_MOBILE_FCM_ACCOUNT); }
        catch { this.options.log("mobile: Firebase service account unreadable or invalid"); }
      }
      const bridge = new MobileBridge({
        ...this.options, token, push, origin: MOBILE_ORIGIN,
        label: hostname().replace(/\.local$/i, "").replace(/[\x00-\x1f\x7f]/g, "").slice(0, 100) || "Mac",
        path: join(app.getPath("userData"), "mobile-relay.json"),
        onPaired: () => this.window?.close(),
      });
      bridge.start();
      this.bridge = bridge;
      return bridge;
    }).finally(() => { this.initializing = undefined; });
  }
}

async function relayCredential(): Promise<string> {
  const override = process.env.OPSCODE_MOBILE_RELAY_TOKEN;
  if (override) return override.trim();
  try {
    const { stdout } = await promisify(execFile)("/usr/bin/security",
      ["find-generic-password", "-a", userInfo().username, "-s", "com.opscode.relay.mac-token", "-w"], { timeout: 10_000 });
    return stdout.trim();
  } catch {
    throw new Error("The Opscode relay credential is unavailable in this Mac’s Keychain.");
  }
}

function qrPng(invitation: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const helper = join(__dirname, "..", "native", "opscode-pair-qr");
    const child = execFile(helper, [], { timeout: 6000 }, (error, stdout) => {
      const png = stdout.trim();
      if (error || !/^iVBORw0KGgo[A-Za-z0-9+/=]+$/.test(png)) reject(new Error("Build Opscode’s native QR helper and try again."));
      else resolve(png);
    });
    child.stdin?.on("error", () => {});
    child.stdin?.end(invitation);
  });
}

function pairPage(png: string): string {
  return `<!doctype html><html lang="en"><meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'">
  <title>Pair Android</title><style>
    body{color-scheme:dark;background:#151417;color:#f5f5f7;font:15px/1.45 system-ui;text-align:center;margin:25px 28px}
    h1{font-size:25px;letter-spacing:-.03em;margin:0}p{color:#d2ccd4;margin:7px 0 16px}
    img{box-sizing:border-box;display:block;margin:auto;background:#fff;padding:16px;width:264px;height:264px;image-rendering:pixelated;border-radius:12px}
    small{display:block;margin:10px 0;color:#c4bdc6}a{color:#ffaf93}
  </style><main><h1>Pair Android</h1><p>Open Opscode on Android and choose <b>Pair Mac → Scan QR</b>.</p>
  <img alt="Opscode pairing QR" src="data:image/png;base64,${png}">
  <small>This one-time QR expires in two minutes.</small>
  <a href="https://copy-link.invalid/" target="_blank" rel="noopener">Copy pairing link</a></main></html>`;
}
