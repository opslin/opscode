# Theme builder and Flutter rendering

## Run the bundled editor

From the skill directory, assemble the module and start the three local services:

```bash
python3 scripts/assemble.py /path/to/new/freshbasket-theme --profile theme-builder --brand FreshBasket
cd /path/to/new/freshbasket-theme
python3 run_local.py
```

Requirements are Python 3.9+, Node.js 20+ with npm, PostgreSQL with `initdb` and `pg_ctl` on PATH, and Flutter. The verifier used Flutter 3.47.5 and PostgreSQL 16. If Flutter is outside PATH, pass `--flutter /path/to/flutter/bin/flutter`. The script resolves dependencies using the bundled lockfiles, compiles Flutter for web, initializes and migrates an isolated PostgreSQL cluster, and serves everything on loopback. Use `--offline` with populated npm and Pub caches. Data persists in the generated project's `.local/postgres` across restarts. The local preview uses a per-run editor token on the server side.

1. Open [the local editor](http://127.0.0.1:4501/themes/builder) and [the Flutter preview](http://127.0.0.1:4502) in separate tabs.
2. Select the **Text Header** row, edit its **Text** field, and click **Save Draft**. The phone preview in the editor shows the draft. The running Flutter app shows the last publication.
3. Click **Push Live**, then confirm in the publish checklist. Flutter refreshes the published manifest every two seconds while the home layout is open. The updated header appears without a page reload.
4. Use the **Custom Banner** editor to upload a PNG, JPEG, or WebP image up to 5 MB, then publish it. The local API stores and serves the image. The same snapshot mechanism works for reordering and hiding sections.

The `theme-builder` profile exposes text headers, spacers, custom banners, and fee strips. The [commerce profile](commerce.md) adds the full 13-type Bakaloo section library and resolves merchandising data against the local catalog. The app uses the earlier homepage bundle for demo products and renders the published layout for the default B2C `zepto/all` tab. Set `THEME_BUILDER_STORE` and `THEME_BUILDER_TAB` as Flutter Dart defines when targeting another retail tab. The source-reference workflow below covers broader catalog integrations, theme configuration and deployment.

The generated `dashboard/e2e/publish-home.spec.ts` test runs against the running services. Install Playwright Chromium in the dashboard with `npx playwright install chromium`, then run `npm run test:e2e`. Alternatively set `PLAYWRIGHT_CHROMIUM_EXECUTABLE` to an existing Chrome binary. The test changes the local homepage and verifies draft isolation, publication, and the app's banner request. Use a fresh assembled project for a fresh demo layout.

## Source locations

Follow a single section from staff edit to phone rendering before porting additional section types.

| Layer | Primary source |
|---|---|
| Dashboard screen and editor | `src/app/(dashboard)/themes/builder/page.tsx`, `src/components/builder/SectionLibrary.tsx`, `sectionTypesMeta.ts`, editors, previews and publish checklist in `src/components/builder/` |
| Dashboard contract | `src/types/theme.types.ts`, `src/services/sections.service.ts`, `themes.service.ts` and `theme-tabs.service.ts` |
| API write and persistence | `src/modules/admin/sections/`, `src/modules/admin/themes/`, `src/modules/admin/theme-tabs/` and `src/modules/admin/admin.routes.js` |
| API read and cache | `src/modules/themes/public.routes.js`, `public.controller.js`, `theme-cache.js`, theme-tab schema and related SQL migrations |
| Flutter ABI | `lib/core/theme/section_manifest_model.dart`, `section_manifest_provider.dart`, `lib/features/home/presentation/widgets/section_registry.dart` and `dynamic_home_sections.dart` |

The dashboard persists editor changes with the admin section and theme APIs. Flutter consumes `GET /api/v1/theme/tabs/:tabKey/sections` from the public read model, with store and audience context where selected. Section entries carry identifiers, render types, order, visibility, configuration, optional merchandise binding and resolved products. Use the actual pinned response as the contract when copying types. Dashboard presets may share the same runtime section type with different default configuration. Store IDs and audience, cache and authorization rules affect which data each client sees.

1. Capture a real fixture for a selected tab, starting with a simple banner or text header. Record the TypeScript editor schema, server validation and stored shape, and the Dart parser and renderer values. Trace schema and seed files through the backend import and search results.
2. Port the editor and phone preview against the same fixture. Check drag and reorder behavior, distinction between draft and published state, validation feedback and who can edit, publish and roll back.
3. Seed a local tab and publish from the dashboard. Inspect the live manifest and load it on Flutter. Change the section twice, compare order and visibility, then test rollback and client refresh. Use a catalog-bound section to exercise availability and merchandise resolution before marking the feature end-to-end.
4. Verify old or unknown section data fails gracefully. The pinned Dart parser maps unknown type strings to `customBanner`. Preserve this behavior for parity or explicitly change the contract and test the fallback. Check absent assets and unknown optional fields.

Useful existing checks include backend `tests/unit/themes/public-theme.category-products.test.js` and dashboard `src/components/builder/__tests__/phase3.test.ts`. The cross-app check still needs a locally published manifest and a real Flutter run.
