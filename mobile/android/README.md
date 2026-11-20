# Opscode Android notch

This native Kotlin preview adapts the Mac notch to a round Android camera cutout. It opens directly into the notch and its approval panel. When Android reports a suitable top cutout, the notch aligns to it. On devices without a suitable cutout, it sits just below the status bar.

## First launch

Install the signed APK and open Opscode. The setup checklist shows connection, notification, background service, and overlay status. Return from Android settings to see each status refreshed. The camera area stays clear when the Mac is idle. The clock and battery stay visible, and the app honors Android’s animation scale.

In **Camera fit**, **Auto** uses the display cutout path on Android 12 and newer when the device provides it. Otherwise, it estimates the shape from Android’s top cutout bounds. **Circle** locks the width and height to one diameter for punch-hole cameras. **Wide notch** fits an elongated cutout. Adjust the center and size while the outline previews live, then **Save** or **Reset**. Phones with no top cutout show the review control below the status bar without a camera glow by default. A manual outline is available in Camera fit.

The notch follows the display’s frame timing during transitions and limits the steady approval glow to about 30 frames per second. The pixel effect stays near the top of the expanded panel, and there is no animation while the notch is hidden.

In **Phone access**, choose **Test notification** to test the notification channel. The test alert does not put sample tasks in Mac activity.

The engine marks use the same assets as the Mac notch. See [engine mark attribution](../../assets/brand/engines/NOTICE.md).

## Build

Use JDK 17 and Android SDK 36. From this folder:

```sh
./gradlew :app:assembleDebug
```

For an installable private release, set `OPSCODE_ANDROID_KEYSTORE`, `OPSCODE_ANDROID_STORE_PASSWORD`, `OPSCODE_ANDROID_KEY_ALIAS` and `OPSCODE_ANDROID_KEY_PASSWORD`, then run `./gradlew :app:assembleRelease`. Keep the preview signing key for updates to the same installation and outside source control.

## Pair with a real Mac

1. Open **Settings → Devices** in the updated Mac app and choose **Show pairing QR**.
2. In Opscode on Android, choose **Pair Mac → Scan QR**. The QR can be redeemed once and expires after two minutes. The initial upgrade from a saved Wi-Fi or Tunnel link requires one new scan.
3. Start a supervised task on the Mac. Open **Mac activity** on Android to see the project and review any approval. The Mac validates the exact approval revision and choice before applying a decision.

Both apps use the public `relay.shotlin.in` endpoint. Android stores the pairing in Android Keystore-backed storage. The Mac reads its relay credential from the macOS Keychain and saves the per-phone encryption key in the Opscode data folder. Each reconnection rebuilds the encrypted session and syncs the current activity. Keep Opscode open on the Mac while working remotely. After the Mac restarts, open Opscode again to restore the relay connection.

The background connection starts by default after pairing. You can turn it off in **Mac activity**. Allow notifications in **Phone access** to receive approval prompts and see the ongoing connection status. Android battery restrictions and force-stop can suspend the service until the app is reopened. On reopening, Opscode reconnects and fetches fresh activity using the saved pairing.

## Approval alerts

Grant **Notch over other apps** in **Phone access** to see the camera ring and mascot on the unlocked screen. Blue indicates running work, red indicates an approval, and amber indicates a failed task. Tap the mascot to expand the notch. Requests with multiple choices open in Opscode for confirmation. Android can show a notification on the lock screen. Unlock to review the request.

## Projects and conversations

Install the matching Mac and Android builds. From the Android home screen or **Mac activity**, choose **Projects**. Pick one of the Mac's projects, open an existing chat, or choose **New chat**. The chat follows updates from the Mac over the existing paired relay. The composer lets you choose the Mac engine, an available model, and any supported reasoning effort. It also offers the same five permission modes as desktop. New chats default to Supervised. Full access requires confirmation.

The navigation drawer refreshes while it is open as conversations change on the Mac; after reconnecting it fetches the current list again. Use **Load earlier messages** to page back through a conversation, and **Show full message** for a long message. The Mac currently retains up to 200 messages per conversation; older messages that were already discarded by the Mac cannot be recovered by the phone.

Use **+ → Photos** or **+ → Files** to pick up to six attachments per message, up to 10 MiB each. The Mac imports them into its normal project attachment store. Tap an attachment in a conversation to preview a photo or save a file to Android, up to 10 MiB per attachment. **Plugins** shows installed Mac plugins and their enabled state. The Mac controls plugin configuration and runs the task.

## Optional Firebase push notifications

Register `com.opscode.mobile` as an Android app in your dedicated Firebase project. Before building the APK, set the following values from its Firebase Android configuration. These identify the client app and are distinct from the server service account.

- `OPSCODE_ANDROID_FIREBASE_APP_ID`
- `OPSCODE_ANDROID_FIREBASE_API_KEY`
- `OPSCODE_ANDROID_FIREBASE_SENDER_ID`
- `OPSCODE_ANDROID_FIREBASE_PROJECT_ID`

Point `OPSCODE_MOBILE_FCM_ACCOUNT` on the Mac to a local service account JSON file with permission to send FCM messages in that same project. Keep this file outside the project and off the phone. Accept the Android notification permission on pairing or in Android settings.

Test with a supervised, harmless Mac task. Disable Wi-Fi on the paired phone and lock it. Start the desktop task, then use **Review** on Android’s notification, unlock, and confirm the exact request. Check that the desktop resumes and the request disappears. Notification delivery depends on Android, Google Play services, device settings, and connectivity.
