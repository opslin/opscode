# Engineering and local verification

## Source baseline

| Layer | Entry points and tooling |
|---|---|
| API | `src/app.js` registers routes and plugins. `src/server.js` starts the server. Route and schema files delegate to controllers, services and PostgreSQL repositories. Redis, worker jobs and sockets support selected features. Use Node and npm compatible with `package.json` and its lockfile. |
| Dashboard | `src/app/(dashboard)/` holds staff screens. Check `src/lib/api.ts`, `src/services/`, `src/types/`, and `src/store/` before porting data hooks or routes. Next.js dev listens on 4501 in the pinned package. |
| Mobile | `lib/main.dart`, `lib/app.dart`, `lib/routing/`, `lib/core/`, and `lib/features/` define bootstrap, navigation and data access. The pinned `.fvmrc` selects Flutter 3.41.9. Use Flutter, Android tooling or Xcode for the platforms in scope. |

For an exact baseline, compare visible flows on the pinned versions before editing. Preserve dependency lockfiles and fixture parity. For a new company, determine brand, supported devices, locale and currency, staff roles, storefront type, stores and service area, then choose the relevant flows. Use the same expectations for the reference and destination when calling the result equivalent. Treat improvements as explicit changes with evidence such as a passing regression check or a measured performance improvement.

## Local setup

1. Give each app isolated local configuration. Use the backend env schema in `src/config/env.js` and the example file as the reference for keys. Set a known port, for example the schema default 4500, and local PostgreSQL and Redis endpoints. Use fresh synthetic data. Verify native configuration and any required provider test keys. Checkout can contain repository-specific integration metadata. Replace it for the destination as appropriate.
2. In the API, use `npm ci`, `npm run infra:up`, `npm run db:migrate`, `npm run db:seed`, and `npm run dev`. Confirm `GET /health` and inspect `/documentation` on the configured port. Read migrations before transplanting a feature. Use a new migration for an existing destination database.
3. In the dashboard, point `NEXT_PUBLIC_API_URL` at the test API base including `/api/v1`. Use `npm ci` and `npm run dev`. Set the backend's allowed origins to the local dashboard as required by its config. Check the role's routes by signing in against a seeded or newly created test account.
4. Flutter reads `BASE_URL`, `SOCKET_URL` and optionally `WEB_BASE_URL` via dotenv in `lib/core/constants/api_constants.dart`. Use an accessible API address for the simulator, emulator or physical device, and check its existing localhost normalization. If the scoped test needs platform services, configure them for the destination's bundle IDs. Run `flutter pub get` and `flutter run` using the pinned SDK. Stub or disable unrelated external integrations for fixture-only adoption.

## Implementation decisions

- Start with source registration and real entry points so the feature is reachable by users. Behavior crossing repos needs one agreed request, response and error shape, plus a fixture each client can consume. Confirm older stored layouts and data can still be read where the new app inherits them.
- Keep authorization and business invariants in the API. Exercise role and store scoping with straight API requests as well as UI navigation. Keep provider secrets and admin authority server-side. Use compatible migrations and exercise retry and concurrency on multi-step writes.
- Optimize measured bottlenecks. Add indexes based on query plans, cap result windows and payload size, avoid per-item database lookups on list routes, and review cache keys and invalidation against store, user and audience boundaries. In the clients, check request duplication, unnecessary rerenders, image size and list scrolling on representative data.
- Preserve domain boundaries. Keep payment, media and messaging integrations behind adapters when switching providers. Reuse source tests and add focused checks for modified contracts and changed behavior.

## Test evidence

| Layer | Commands and evidence |
|---|---|
| API | `npm run lint` and `npm test`. Apply migrations to a clean test DB. Exercise successful and rejected requests against test data, and verify rows, totals and stock for checkout. |
| Dashboard | `npm run lint`, `npm test`, `npm run build`, and relevant `npm run e2e` specs with local test URLs and accounts. Run the requested flows in a browser, including denied direct deep links for the wrong role. |
| Flutter | `flutter analyze`, `flutter test`, and the selected flow on a simulator, emulator or device. Exercise loading, empty, error, offline and refresh states where relevant. |
| Cross-app | Verify source and destination results using identical seeded fixtures if parity is requested. Record request or UI action, expected result, actual result, and limitations by environment. |

Treat configuration keys, migration order, source revisions, test fixtures and command results as part of the build handoff. Review behavior involving external services with sandbox credentials or fakes. Leave deployment, store submission and live integrations to the project's release process.
