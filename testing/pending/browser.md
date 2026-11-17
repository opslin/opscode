# Pending: browser control, remaining real-world tests

Status: browser control was real-tested with Claude Code (Fable 5.2, Sonnet 5.5, Haiku 5.5) in Full
access on 2026-11-16; see `testing/reports/2026-11-16-browser-real-test.md`. Still to test:

- [ ] Codex engine (install Codex; check the `mcp_servers.opscode_devices` thread config and `http_headers` are accepted by the real app-server).
- [ ] Built-in agent with a real Anthropic key and an OpenAI-compatible key.
- [ ] Supervised mode: every action shows Allow/Deny on the engine's card; Deny reaches the model.
- [ ] Read only: model can open/read but is refused actions.
- [ ] A site outside this computer asks once per chat.
- [ ] Chief worker and GODMODE / WARLORD / SHINOBI worker chats using the browser.
- [ ] Pages with iframes (refs do not reach inside frames yet), shadow DOM forms, file upload, drag and drop.
- [ ] Login with redirects, cookies kept in the browser partition between runs.
- [ ] Long pages (outline cut at 12k chars), infinite scroll.
- [ ] Browser tab hidden (another project in front): reads/acts work, screenshot explains.
- [ ] No window open: hidden-window fallback.
- [ ] The user clicking in the tab while the agent works.
