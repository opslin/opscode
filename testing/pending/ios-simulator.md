# Pending: iOS Simulator production testing

Status: **pending** (added 2026-11-16). Slice D2 is built and passes its automated tests
(`scripts/test-phase28.mjs`, smoke step 05f), but only against a stand-in `simctl` and a
stand-in input helper. Nothing below has run on a real simulator yet.

**Blocker:** this Mac has no iOS simulator runtime, and only ~8 GB of disk is free. Free
15–20 GB, then:

```bash
xcodebuild -downloadPlatform iOS
```

Create a device in Xcode → Window → Devices and Simulators (for example iPhone 17 on iOS 26.x).

## 1. Helper (native/opscode-sim) on a real device

- [ ] `opscode-sim serve --udid <booted>` answers ready with the right size in points (iPhone 17: 402x874 or what Xcode reports).
- [ ] Tap lands where asked: tap Settings icon, General row, a switch; compare with screenshot coordinates at every corner and the centre.
- [ ] Long press (duration 1s) opens the home-screen context menu.
- [ ] Swipe: scroll a long list up/down; swipe back from the left edge; pull down Notification Center from the top edge.
- [ ] touch_path: drag an app icon in jiggle mode; draw in Notes with a curve.
- [ ] touch2_path: pinch to zoom in Photos/Maps; two-finger rotate in Maps.
- [ ] Keys: type letters, capitals, digits, `!@#$%^&*()_+{}|:"<>?` in a text field; return, delete, tab, arrows, select_all/copy/paste/undo.
- [ ] Non-US text ("héllo", emoji, Bengali) goes in by paste.
- [ ] Buttons: home, lock (screen off/on), side, siri, applepay (double press).
- [ ] Hardware keyboard off ("I/O → Keyboard → Connect Hardware Keyboard" off) — what happens; message to the model if typing fails.
- [ ] Two simulators booted at once: input goes only to the chosen one.
- [ ] Simulator shut down while the helper runs: helper restarts cleanly on next action.
- [ ] Xcode switched with `xcode-select` while running.

## 2. simctl actions

- [ ] list / boot (cold, ~30–90 s) / shutdown / boot an already booted device.
- [ ] screenshot: correct size in points, JPEG small (< 150 KB), sharp enough to read text.
- [ ] launch with app_path from a real `xcodebuild -sdk iphonesimulator` build (SwiftUI app + Flutter app).
- [ ] terminate, open_url (https and a custom scheme), set_appearance + appearance, list_apps, set_location (Maps shows it).
- [ ] logs for a crashing app (`process` and `bundle_id` filters), size cap.

## 3. Agent end-to-end (real models, every engine and mode)

- [ ] Claude Code (Sonnet, Opus) builds + launches + tests a sample app: login, list, detail, settings.
- [ ] Codex does the same task.
- [ ] Built-in agent (API key) does the same task.
- [ ] Modes: Read only (look only), Supervised (every action asks, Deny works), Auto edits, Full access.
- [ ] Chief worker and GODMODE / WARLORD / SHINOBI worker chats can use it.
- [ ] Automation step using the simulator.
- [ ] Measure: steps, screenshots, tokens and cost per task; compare with Claude desktop's own iOS tool on the same task.

## 4. Panel

- [ ] Simulator tab shows the live screen (~1 fps), device picker, Boot, Home.
- [ ] Click-to-tap matches the picture at every corner, light and dark theme, panel narrow and wide.
- [ ] "Opscode · …" badge while the agent acts; stops refreshing when the tab is hidden.

## 5. Not built yet (test when built)

- [ ] iOS accessibility tree (element names + frames, like the browser's refs).
- [ ] Live H.264 video stream in the panel.
- [ ] Rotate action.
- [ ] DTUHID input path for Xcode 27 / CoreSimulator 1155+.
