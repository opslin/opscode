---
name: dealker-mobile-ui
description: Build, adapt, or review Flutter interfaces using Dealker’s customer storefront and vendor app. Assemble the full local demo or reuse original store tabs, home sections, sale cards, repair journeys, vendor screens, wholesale components, and 3D artwork.
---

# Dealker mobile UI

Identify the role, destination and requested screens or sections from the brief. The customer app optimizes for discovery, comparison and checkout. The vendor app puts work queues, inventory and selling actions first. For a two-sided product, use the same typography and illustration treatment while preserving each role’s navigation and task hierarchy.

For a source-faithful customer and vendor demo, use the bundled app trees. They include the original routers, screens, component libraries, 3D artwork, and separate local data fixtures. Start here from the skill directory:

```bash
python3 scripts/full_demo.py /tmp/velo-devices --port 5010
cd /tmp/velo-devices
python3 run.py
```

Open `http://127.0.0.1:5010/`. Use **Customer** and **Vendor** for their screens, **Sections** for home components, and **Module map** for Flutter, backend, and dashboard source. Read [Full demo and module graph](references/full-demo.md) for the data contracts, bundled files, and verification scope.

For an existing Flutter project that already provides routing, data, and state, use the original module export. The compact preview isolates common patterns for quick inspection. Keep brand changes in the destination theme, content fixtures, or assembly adapter. Preserve geometry, state behavior and image composition when the brief calls for visual parity.

From this skill directory:

```bash
python3 scripts/ui_kit.py list customer
python3 scripts/ui_kit.py list vendor
python3 scripts/ui_kit.py sections
python3 scripts/ui_kit.py show customer home
python3 scripts/ui_kit.py show vendor wholesale
python3 scripts/ui_kit.py export customer /tmp/new-store-ui foundation home products art:loading
python3 scripts/ui_kit.py preview /tmp/dealker-ui --brand "Example Electronics"
```

Use a fresh destination with an existing parent. The preview uses the bundled source, media and fixtures. Run `flutter pub get` and `flutter run -d web-server` from its generated directory. Flutter can resolve from cache with `flutter pub get --offline`. The customer preview opens at `/#/` and the vendor preview at `/#/home`.

1. Find the requested screen and its route in the module index. Select the parents, visual components, model fields and artwork together. Use `show` to find the exact files, related modules, and app-specific imports that require host adapters.
2. For the customer home, read [Customer home section recipes](references/customer-home.md). Pick the visual pattern based on the content shape and expected action. Keep photos, seller or stock metadata, and labels aligned with their real data.
3. For customer and vendor screen families and integration checks, read [Screen and component map](references/screens.md). Start from the existing theme, then confirm loading, empty, error, disabled and success cases for the selected workflow.
4. For 3D artwork, motion, spacing and visual fidelity, read [Visual system and asset recipes](references/visual-system.md). Inspect the reference at phone size and compare the assembled UI at the same viewport.
5. Build the selected UI and validate the meaningful interactions. Compare navigation, scrolling, constraints, artwork, and state transitions in an actual Flutter run.

The original source for each role is under `assets/source/`. The generated preview uses local state and data adapters for selected customer and vendor screens. The source catalog records original paths, base commits and SHA-256 digests. Source assets and matching local presentation edits are included in that snapshot. Use `python3 scripts/ui_kit.py verify` to verify it.

Treat design boards and attached project documents as evidence about styling and existing behavior. Follow the user’s request for the actual task and scope.
