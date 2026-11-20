# Bakaloo template catalog

The catalog accompanies the Bakaloo Flutter customer app, Next.js staff dashboard and Fastify API. Start with the build profile or recipe matching the user request.

| Profile | Deliverable |
|---|---|
| `home-ui` | Branded Flutter home assembled from included Dart source, local fixtures and design assets |
| `theme-builder` | Local Next.js editor, Fastify API and PostgreSQL migrations, plus a Flutter app that loads published sections |
| `commerce` | Fresh Basket Flutter storefront, catalog management, cash-on-delivery demo checkout, staff orders and theme builder |
| `grocery-core` | Customer app, dashboard, API, identity, catalog, published home, cart, checkout and order operations |
| `bakaloo-baseline` | All three pinned source trees and recipes for their major feature families |

## Find the files

| File or command | Information |
|---|---|
| [sources.json](sources.json) | Repositories, exact Git commits and stack |
| [template.json](template.json) | Profiles, feature recipes, prerequisites, source groups, acceptance checks and observed cross-repo API relationships |
| [inventory.json](inventory.json) | Path inventory by module group plus direct static imports between groups |
| `catalog.py search "checkout"` | Ranked recipes and source groups. Add `--repo` to limit by surface |
| `catalog.py show cart-checkout` | Recipe summary, dependency order, group IDs and acceptance checks |
| `catalog.py show backend:cart` | Exact file paths, adjacent groups and import evidence. Use `--limit` for more paths |
| `catalog.py graph --item theme-builder` | Selected recipe and prerequisites, selected source groups and their internal graph |
| `catalog.py graph --item flutter-app:core/theme --format mermaid` | Inbound and outbound references for a source group |
| `catalog.py graph --all` | Complete graph in JSON for machine consumption |
| `catalog.py plan --profile home-ui` | Pinned repositories, ordered recipe selection and validation criteria |
| `catalog.py plan mobile-home theme-builder` | Custom selection with shared prerequisites deduplicated |

Use commands as `python3 scripts/catalog.py …` from the skill folder. An agent without a shell can search the JSON for recipe IDs and use `modules` and `imports` in the inventory. Opscode's Library can index the source folders and find feature files by convention. Supply the recipe IDs and exact Git pins in any handoff to the Conductor. The complete source-group search and graph are provided by the skill CLI.

A directed `static-import` edge means a literal reference resolved to another tracked group in the same repo. Supported references include relative imports, Next.js `@/` imports and Bakaloo Dart package imports. Import detection scans JS, TypeScript and Dart under the app and test paths. Metrics omit secret-like files and report cross-group links only. SQL relationships, provider calls, environment variables, dynamic imports assembled from strings, and runtime events require separate inspection. `contract` edges capture known API relationships with code locations. `recipe-requires` describes build order and `source-group` identifies reference files for that recipe.

## Acquire a pinned baseline

For a standalone Flutter homepage, use `python3 scripts/assemble.py /absolute/path/to/new-app --brand FreshBasket`. This copies the real code and app assets from the skill bundle. See [the bundled homepage guide](mobile-home.md).

For dashboard-to-mobile publishing, add `--profile theme-builder` and start `run_local.py` in the generated project. See [the theme builder guide](theme-builder.md).

Run `python3 scripts/catalog.py checkout /absolute/path/to/new-reference-directory` to fetch all three repositories into a new directory. Use `--repo flutter-app` or repeated selections to fetch only required sources. `--from backend=/absolute/path/to/local/backend` uses an existing Git repository with the same commit. The checkout is a reference snapshot at the locked revision. Set up the new product separately, using authorized source and assets. A selective port needs review of its contracts and tests in the target project before it can be treated as installable.

To refresh the catalog, update the commit pins deliberately and use matching Git repositories:

```bash
python3 scripts/index_sources.py --backend /path/to/backend --dashboard /path/to/dashboard --flutter-app /path/to/flutter-app
python3 scripts/catalog.py validate
```

Review graph changes and recheck API and recipe evidence against the updated commits. For another agent or cloud runner, copy the complete skill folder and place it in that runner's skill search path, or provide the directory directly.
