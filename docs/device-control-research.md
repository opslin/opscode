# Device control research: browser, iOS Simulator, Android Emulator

Date: 2026-11-16. Source: read-only analysis of the installed apps (bundles unpacked into a scratch folder; nothing installed was changed):
Claude.app 5.11492.5 (desktop, Code tab), Codex desktop (ChatGPT.app, `openai-codex-electron` 26.1111.21308), Caveman Code.app 0.1.5.

Opscode re-implements the *ideas* below with its own code. Nothing from these bundles is copied.

## 1. Browser control: how each app does it

| | Claude desktop | Codex desktop | Caveman Code |
|---|---|---|---|
| Where the page lives | Electron `WebContentsView` inside the app window (the "Browser pane"), owned by main | Electron in-app browser ("IAB"), owned by main | Headless Chromium (`chrome-headless-shell`) run by the runtime with `playwright-core` (`launchPersistentContext`) |
| How the agent drives it | Main attaches `webContents.debugger` (Chrome DevTools Protocol). An allow-list of ~60 CDP methods only | A per-thread MCP server `node_repl` injected into the Codex thread config (`mcp_servers.node_repl`); the model writes JS against a browser API, served to the IAB over a native pipe | Playwright API behind MCP tools `preview_open / navigate / snapshot / act / evaluate / wait_for / dialog / resize / set_appearance / recording_start|stop / list / close / status` |
| Page reading | Injected script tags elements `ref_N` (`window.__claudeElementMap`), YAML-ish accessibility tree; `find` searches it; also `Accessibility.getFullAXTree` | Snapshot + JS in the REPL | Playwright aria snapshot with refs; actions target `locator='aria-ref=<ref>'` |
| Input | `Input.dispatchMouseEvent` (real trusted events), `Input.insertText`, `Input.dispatchKeyEvent` | same CDP input family | Playwright (also CDP underneath) |
| Screenshots | `Page.captureScreenshot`, scaled | `Page.captureScreenshot` | Playwright screenshot; UI gets `Page.startScreencast` JPEG frames |
| Extras | console (`Runtime.consoleAPICalled`, `Log.entryAdded`), network (`Network.*`), file chooser intercept, JS dialogs, iframes via `Target.setAutoAttach`, device emulation, batch of actions in one call | network bodies, downloads, history | recordings, user/agent control hand-off (`browser.control`) |
| Which model | Whatever chat model is running (Claude). No special browser model | Whatever Codex model is running | Whatever engine the chat uses (Claude Code or Codex) via MCP |

**Model finding:** none of the three uses a special "browser model". The chat's own model drives the browser through tool calls. What makes it reliable is the *tool design*, not the model:

1. Read the page as text with stable element refs (cheap tokens, exact targets). Screenshots only to check visuals.
2. Act on refs, fall back to coordinates from the last screenshot.
3. Real input events through CDP (pages see trusted clicks/keys; React inputs update).
4. Batch several predictable steps in one call to save round trips.

Claude models (Sonnet/Opus) are trained for screenshot coordinates (computer use), so they are best when a page has no accessible names. Codex/GPT models do best with the ref/text path. So Opscode gives both engines the same ref-first tools.

## 2. iOS Simulator: how Claude does it

- A separate signed helper app: `Claude.app/Contents/Helpers/Claude iOS Sim.app` (Swift, background-only, bundle id `com.anthropic.claude.ios-sim`).
- Built on Meta's **idb** (`FBSimulatorControl`, `FBControlCore`, `FBSimulatorAX`, `FBVideoCore`; MIT licence shipped as `LICENSE-facebook-idb.txt`).
- Weak-links `CoreSimulator.framework` (private) and loads `SimulatorKit.framework` from Xcode.
- Touch/keys/buttons: HID events sent straight to the simulated device. Two transports: legacy **Indigo** HID messages, and **DTUHID** (`dtuhidd`) which newer CoreSimulator (Xcode 27+) prefers.
- Screen: screenshots, and a live **H.264 stream** (VideoToolbox) shown in a panel (MP4 fragments into Media Source).
- UI tree: accessibility through `AccessibilityPlatformTranslation` (iOS accessibility elements → frames, labels).
- Transport to the app: a local serve socket with JSON commands, e.g. `{"command":{"ping":{}},"id":"…","version":1}`.
- Tool surface (one tool, many actions): attach, launch, screenshot, tap, swipe, touch_path, touch2_path, text, button, press_key, set_appearance, appearance, set_keyboard, open_url, rotate, detach, plus build (xcodebuild) and logs.
- Edge rule: a drag that starts within 4pt of an edge becomes the OS edge gesture.

## 3. Android Emulator: how Claude does it (no helper, plain `adb`)

- Find tools: `adb`, `emulator`, `avdmanager`/`sdkmanager` (ANDROID_HOME / platform-tools).
- Boot: `emulator -avd <name> -no-window` (headless) and wait for `sys.boot_completed`.
- Screenshot: `adb -s <serial> exec-out screencap -p`.
- UI tree: `adb shell uiautomator dump /dev/tty` (XML with bounds).
- Screen facts: `wm size`, `wm density`, rotation.
- One finger: a long-lived `adb shell` running `input motionevent DOWN|MOVE|UP x y` (paths with timing).
- Two fingers: raw `sendevent /dev/input/eventN` multitouch (slot 47, tracking id 57, x 53, y 54, BTN_TOUCH 330).
- Text: base64 → `toybox base64 -d` → `input text`; Enter = keyevent 66. Keys: HOME 3, BACK 4, RECENTS 187, LOCK 26, VOLUME 24/25.
- Live panel: `screenrecord --output-format=h264 --bit-rate=4M --size=WxH -` piped and restarted at the time limit, wrapped into fragmented MP4.
- Works the same on macOS, Windows and Linux because it is only `adb` + `emulator`.

## 4. This Mac today

- Xcode 26.6, Swift 6.3.3, CoreSimulator present. **No iOS simulator runtime installed** (`xcrun simctl list runtimes` is empty), so no simulator can boot yet. Install: `xcodebuild -downloadPlatform iOS` (several GB).
- **No Android SDK** (`adb`, `emulator` missing). Install Android Studio or the command-line tools + an emulator image.

## 5. Opscode design (own code)

```
 engine (Claude Code / Codex / built-in agent)
        │  tool calls (MCP over loopback HTTP, or direct for the built-in agent)
        ▼
 runtime: devices/  ── browser tools ──► DeviceHost request ──► main (Electron)
                     │                                           └─ CDP on the project's Browser tab
                     ├─ ios tools ──► xcrun simctl + opscode-sim helper (Swift, later slice)
                     └─ android tools ──► adb / emulator (cross-platform)
```

- One loopback MCP endpoint `/mcp/devices` (bearer token per turn) gives the same tools to Claude Code and Codex in **every mode**: Normal chats, Chief and its workers, GODMODE / WARLORD / SHINOBI conductors, automations and sub-agents. The built-in agent gets the tools directly.
- Permission modes decide like other tools: Read only = read tools only; Supervised = each action asks; Auto edits and Full access = actions run. Pages outside localhost ask once per site.
- Token care: ref-first reads, screenshots scaled down, output capped.

## 6. Build slices

1. **D1 Browser control** (this slice): main-side CDP host on the project's Browser tab (hidden window fallback when no panel), runtime tools, `/mcp/devices`, wiring into all engines and modes, tests + smoke.
2. **D2 iOS Simulator** (built 2026-11-16): `simctl` driver (list/boot/shutdown/screenshot/install+launch/terminate/open_url/appearance/list_apps/logs/location) + `native/opscode-sim` (Objective-C helper, built into `dist/native`) for touches, one/two-finger paths, keys and hardware buttons + a Simulator side-panel tab. Not yet: the iOS accessibility tree (Claude reads it through `AccessibilityPlatformTranslation`), live video stream, rotation. Verified with a fake simctl/helper only: this Mac has no iOS runtime yet.
3. **D3 Android Emulator**: `adb`/`emulator` driver as in §3, Emulator panel, Windows support. Needs the Android SDK to verify.
4. **D4 Live streams**: H.264 → MP4 fragments → Media Source for both device panels.

## 7. How opscode-sim sends touches (checked on Xcode 26.6)

- Loads `/Library/Developer/PrivateFrameworks/CoreSimulator.framework` and Xcode's `SimulatorKit.framework` at run time.
- Device: `SimServiceContext sharedServiceContextForDeveloperDir:error:` → `defaultDeviceSetWithError:` → `devices` (match `UDID`); screen size in points = `deviceType.mainScreenSize / mainScreenScale`.
- Input client: `_TtC12SimulatorKit24SimDeviceLegacyHIDClient initWithDevice:error:`, then `sendWithMessage:freeWhenDone:completionQueue:completion:`.
- Messages come from SimulatorKit's own C builders, so their layout follows the installed Xcode:
  - `IndigoHIDMessageForMouseNSEvent(CGPoint *p, CGPoint *p2 /* 2nd finger or NULL */, target 0x32, NSEventType 1 down / 2 up / 6 drag, edge, CGSize screenPoints)`. Read from the disassembly; a byte dump shows it divides the point by the size and stores the x/y ratios as doubles at +0x3C/+0x44, with header 0x20 + 0xA0-byte payloads (two for one finger, three for two fingers).
  - `IndigoHIDMessageForButton(source, 1 down / 2 up, target 0x33)` (home 0x0, lock 0x1, side 0xBB8, siri 0x400002).
  - `IndigoHIDMessageForKeyboardArbitrary(HID usage, 1 down / 2 up)`.
- Claude's helper notes that CoreSimulator 1155+ (Xcode 27) prefers a newer DTUHID transport; Opscode will need that path when Xcode 27 arrives.
