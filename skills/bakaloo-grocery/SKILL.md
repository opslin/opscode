---
name: bakaloo-grocery
description: Build or extend a grocery commerce product using Bakaloo's Flutter storefront, Next.js dashboard and Fastify API. Use for a full grocery starter or selected homepage, design, theme builder, catalog, checkout, order or operations modules.
---

## Select the build

Start with the user's scope, target workspace, brand and required surfaces. For a new app, choose `grocery-core` for an end-to-end grocery starter or `bakaloo-baseline` for all three source repos and their feature families. Choose `home-ui` for a standalone Flutter home with demo data. For an existing app, select specific recipes and compare their contracts with the destination before changing it.

For a new homepage-only project, assemble the bundled Dart code, assets and fixtures into a fresh directory using `python3 scripts/assemble.py /path/to/new/app --brand FreshBasket`. Use the [bundled homepage guide](references/mobile-home.md) to run and test it. This flow uses the files in `modules/mobile-home/source`.

For an editable homepage with a dashboard and API, use `python3 scripts/assemble.py /path/to/new/project --profile theme-builder --brand FreshBasket`. The [theme builder guide](references/theme-builder.md) covers the included editor, database migrations, Flutter renderer, and local publishing check.

For the Bakaloo-styled Fresh Basket storefront with Browse, Cart, a live catalog, the full homepage section library and staff orders, use `python3 scripts/assemble.py /path/to/new/project --profile commerce --brand "Fresh Basket"`. Start the generated project with `python3 run_local.py` and follow the [commerce module index and verification guide](references/commerce.md). The bundled profiles assemble from local files.

Use these commands from the skill directory. They require Python 3. The catalog reads metadata locally and checkout uses Git.

```bash
python3 scripts/catalog.py list
python3 scripts/catalog.py search "theme builder"
python3 scripts/catalog.py show theme-builder
python3 scripts/catalog.py show dashboard:components/builder
python3 scripts/catalog.py graph --item theme-builder --format mermaid
python3 scripts/catalog.py plan --profile grocery-core --brand FreshBasket
python3 scripts/catalog.py plan mobile-home theme-builder
python3 scripts/catalog.py validate
```

Read [the catalog guide](references/catalog.md) for the file map and tool workflow. Use the `guide` listed by each selected recipe. An Opscode Conductor can use `library_search` for other code the user already has, then carry the resolved template plan into its gap, build and test stages. The catalog also works over a shell and file reads without Opscode.

## Reuse the correct source

- Use the commits in [sources.json](references/sources.json) as provenance. When the selected features require source outside a bundle, work from separate reference directories. Fetch only the needed repositories with `catalog.py checkout` or reuse local Git objects at the same pins. Keep upstream file paths and commits in the work report.
- For a full Bakaloo-derived build, retain the three working framework shells, lockfiles and module boundaries. Configure the new app and its environments using [the engineering guide](references/engineering.md). Begin with a clean local baseline and record any failures before modifying behavior.
- For a module port, take the entry points, schema or models, required registration, migrations, tests and adapters together. `show` gives file groups and import evidence. Verify non-import dependencies by tracing route prefixes, environment keys, database tables, workers, events and client contracts. The catalog describes reference recipes that require integration and verification in each destination.
- Keep user-selected UI scope and business rules intact. Replace old branding and provider identifiers through explicit configuration, and use approved assets and synthetic test data. Add limited custom code where the new requirements differ or a source dependency needs an adapter.

## Prove the assembled app

Use each selected recipe's acceptance checks. Run the destination's native checks and demonstrate the actual user flow. For a full grocery build, publish a homepage section in the dashboard, load it in Flutter, create a test product, place an order, and verify dashboard status, authoritative totals and stock. Exercise relevant access boundaries and retry, failure and fallback behavior with test accounts and isolated services.

Deliver the runnable code, configuration keys, selected modules, source pins, commands and observed test results. Identify gaps and any checks still requiring a device, credentials or an external provider. Keep production deployment outside this build workflow.
