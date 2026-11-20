# Mobile project and chat reliability

- [x] Verify paired devices discover registered Mac projects and their normal and team conversations, including running work.
- [x] Refresh project and conversation navigation after Mac changes and after a reconnect, without losing drafts or resetting the open conversation.
- [x] Make retained conversation text and older messages reachable across bounded encrypted relay messages.
- [x] Verify engine, model and reasoning selection are applied to the first Mac turn, and guard retries against duplicate new chats and turns.
- [x] Run Android unit tests and encrypted relay tests, including reconnect, long history, and first-message selection.
- [x] Build and verify a signed APK, install a compatible preview, and report real-device verification limits.

The desktop runtime retains up to 200 messages per conversation. Mobile can display all messages the Mac still retains, but cannot recover older messages already discarded by the desktop.
