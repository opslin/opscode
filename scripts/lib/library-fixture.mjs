// A small multi-package app for the Library tests: a NestJS-style backend and a Flutter app,
// with planted secrets and noise folders that must never reach the index.
import { mkdirSync, symlinkSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

export const SECRET_TEXT = "SUPERSECRET-DO-NOT-INDEX";
export const LITERAL = "TOP_SECRET_LITERAL_do_not_store_me";
export const SENTINEL = "OVERCAPTURE_SENTINEL_text";

export function writeLibraryFixture(parent) {
  const root = join(parent, "shopfix");
  const w = (rel, text) => { const p = join(root, rel); mkdirSync(dirname(p), { recursive: true }); writeFileSync(p, text); };
  // ---- backend (NestJS + Drizzle)
  w("backend/package.json", JSON.stringify({ name: "@shop/backend", dependencies: { "@nestjs/core": "^10", "drizzle-orm": "^0.3" }, scripts: { build: "x", test: "y" } }));
  w("backend/tsconfig.json", `{\n  // comments are allowed in tsconfig\n  "compilerOptions": { "baseUrl": ".", "paths": { "@/*": ["src/*"] } },\n}`);
  w("backend/src/app.ts", `import { LoyaltyService } from './modules/loyalty/loyalty.service';\nimport { schema } from '@/db/schema';\nimport { gone } from './missing';\nimport express from 'express';\nconst app = express();\napp.post('/api/vendors/payout', () => 1);\nexport const secret = '${LITERAL}';\n`);
  w("backend/src/modules/loyalty/loyalty.controller.ts", `import { Controller, Get } from '@nestjs/common';\nimport { LoyaltyService } from './loyalty.service';\n@Controller('loyalty')\nexport class LoyaltyController { @Get('points') points() {} }\n`);
  w("backend/src/modules/loyalty/loyalty.service.ts", `import { LoyaltyRepository } from './loyalty.repository';\nexport class LoyaltyService { run() { return '${LITERAL}'; } }\n`);
  w("backend/src/modules/loyalty/loyalty.repository.ts", `export class LoyaltyRepository {}\n`);
  w("backend/src/modules/orders/orders.controller.ts", `import { Controller, Post } from '@nestjs/common';\n@Controller('orders')\nexport class OrdersController { @Post() create() {} }\n`);
  w("backend/src/modules/orders/orders.service.ts", `export class OrdersService {}\n`);
  w("backend/src/modules/admin/admin-credentials.service.ts", `export class AdminCredentialsService {}\n`);
  w("backend/src/db/schema.ts", `import { pgTable } from 'drizzle-orm/pg-core';\nexport const a = pgTable('loyalty_points', {});\nexport const b = pgTable('order_items', {});\nexport const c = pgTable('auction_bids', {});\n`);
  w("backend/src/db/migrations/0001_init.sql", `CREATE TABLE IF NOT EXISTS cart_items (id int);\n`);
  // The word "import" inside a string must not start a capture that swallows code up to the next quote.
  w("backend/src/notes.ts", `const a = 'dynamic import' + OVERCAPTURE_SENTINEL_text + "tail";\n`);
  // ---- Flutter app
  w("app/pubspec.yaml", `name: shopapp\ndependencies:\n  flutter:\n    sdk: flutter\n  flutter_riverpod: ^2.0.0\n  go_router: ^13.0.0\n`);
  w("app/lib/main.dart", `import 'package:shopapp/features/orders/order_screen.dart';\n`);
  w("app/lib/features/loyalty/loyalty_screen.dart", `import 'package:shopapp/features/loyalty/loyalty_repo.dart';\nclass LoyaltyScreen extends StatelessWidget {}\n`);
  w("app/lib/features/loyalty/loyalty_repo.dart", `class LoyaltyRepo {}\n`);
  w("app/lib/features/orders/order_screen.dart", `class OrderScreen extends StatelessWidget {}\nfinal r = GoRoute(path: '/orders', builder: (c, s) => OrderScreen());\n`);
  // ---- things that must never be indexed
  w("backend/.env", `API_KEY=${SECRET_TEXT}\n`);
  w(".env.local", `X=${SECRET_TEXT}\n`);
  w("keys/server.pem", `-----BEGIN PRIVATE KEY-----\n${SECRET_TEXT}\n`);
  w("backend/config/credentials.json", `{"token":"${SECRET_TEXT}"}`);
  w("backend/google-services.json", `{"k":"${SECRET_TEXT}"}`);
  w("backend/node_modules/lib/index.js", `export const nm = 1;\n`);
  w("backend/dist/app.js", `export const built = 1;\n`);
  w("backend/.hidden/h.ts", `export const hidden = 1;\n`);
  w("backend/testdata/t.ts", `export const fixture = 1;\n`);
  w("app/ios/Runner/AppDelegate.swift", `class AppDelegate {}\n`);
  w("app/android/app/Main.kt", `class Main\n`);
  symlinkSync(root, join(root, "backend", "loop"));
  return { root, files: 17 };
}
