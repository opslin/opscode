#!/usr/bin/env python3
"""Assemble a bundled Bakaloo app into a new directory."""
import argparse
import json
from pathlib import Path
import shutil
import tempfile


MODULES = Path(__file__).resolve().parents[1] / "modules"
BUNDLE = MODULES / "mobile-home" / "source"
THEME = MODULES / "theme-builder" / "source"
COMMERCE = MODULES / "commerce" / "source"
FIXTURE = Path("assets/demo/storefront.json")


def check_tree(root):
    for entry in root.rglob("*"):
        if entry.is_symlink() or entry.name in {
            ".git", ".dart_tool", ".env", ".local", ".next", "node_modules", "build",
        }:
            raise ValueError(f"unexpected entry in the source bundle: {entry.name}")


def check_bundle():
    check_tree(BUNDLE)
    fixture = json.loads((BUNDLE / FIXTURE).read_text(encoding="utf-8"))
    for photo in [*fixture["promos"], *fixture["products"]]:
        image = photo.get("image")
        if not image:
            continue
        path = Path(image)
        if path.is_absolute() or ".." in path.parts or not (BUNDLE / path).is_file():
            raise ValueError(f"missing or invalid bundled image: {image}")
    return fixture


def write_home(destination, fixture):
    shutil.copytree(BUNDLE, destination)
    (destination / FIXTURE).write_text(
        json.dumps(fixture, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def replace_once(file, anchor, replacement):
    original = file.read_text(encoding="utf-8")
    if original.count(anchor) != 1:
        raise ValueError(f"could not find the integration point in {file.name}")
    file.write_text(original.replace(anchor, replacement), encoding="utf-8")


def insert_once(file, anchor, addition):
    replace_once(file, anchor, addition + anchor)


def overlay(source, destination, replacements=()):
    for file in source.rglob("*"):
        if not file.is_file():
            continue
        relative = file.relative_to(source)
        target = destination / relative
        if target.exists() and relative.as_posix() not in replacements:
            raise ValueError(f"unexpected module overlay collision: {relative}")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(file, target)


def write_theme(destination, fixture):
    destination.mkdir()
    shutil.copytree(THEME, destination, dirs_exist_ok=True, ignore=shutil.ignore_patterns("flutter"))
    flutter = destination / "flutter-app"
    write_home(flutter, fixture)
    overlay(THEME / "flutter", flutter, ("pubspec.lock",))
    insert_once(flutter / "pubspec.yaml", "  gap: 3.0.1\n", "  http: 1.6.0\n")
    home = flutter / "lib/features/home/presentation/screens/home_screen.dart"
    insert_once(home, "import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';",
                "import '../widgets/dynamic_home_sections.dart';\n")
    insert_once(home, "          if (_category == 'all' && storefront.promos.isNotEmpty)",
                "          if (_category == 'all') const DynamicHomeSections(),\n")


def write_commerce(destination, fixture):
    write_theme(destination, fixture)
    backend = destination / "backend"
    dashboard = destination / "dashboard"
    flutter = destination / "flutter-app"
    overlay(COMMERCE / "backend", backend)
    overlay(COMMERCE / "dashboard", dashboard)
    overlay(COMMERCE / "flutter", flutter, (
        "pubspec.lock",
        "lib/features/home/presentation/widgets/dynamic_home_sections.dart",
        "lib/features/home/presentation/screens/home_screen.dart",
        "lib/shared/widgets/home_header.dart",
        "lib/shared/widgets/app_image.dart",
        "test/home_smoke_test.dart",
    ))
    publication = backend / "src/modules/themes/publication.js"
    schema = backend / "src/modules/admin/sections/sections.schema.js"
    replace_once(schema, "const SECTION_TYPES = [", "export const SECTION_TYPES = [")
    replace_once(
        publication,
        "const supported = new Set(['text_header', 'spacer', 'custom_banner', 'fee_strip'])",
        "import { SECTION_TYPES } from '../admin/sections/sections.schema.js'\n\n"
        "const supported = new Set(SECTION_TYPES)",
    )
    replace_once(publication, "This bundle supports up to 50 text, banner, fee strip, and spacer sections",
                 "This bundle supports up to 50 Bakaloo sections")
    library = dashboard / "src/components/builder/SectionLibrary.tsx"
    replace_once(
        library,
        'let types = sectionTypesMeta.filter(meta => ["text_header", "spacer", "custom_banner", "fee_strip"].includes(meta.type))',
        'let types = sectionTypesMeta',
    )
    server = backend / "src/server.js"
    insert_once(server, "import { error, success }", "import commerceRoutes from './modules/commerce/commerce.routes.js'\n")
    insert_once(server, "app.addHook('onClose'", "await app.register(commerceRoutes)\n\n")
    replace_once(
        server,
        "app.get('/api/v1/products', admin, async () =>\n"
        "  success((await query('SELECT * FROM products ORDER BY name LIMIT 30')).rows))",
        """app.get('/api/v1/products', {
  ...admin,
  schema: { querystring: { type: 'object', properties: {
    search: { type: 'string', maxLength: 100 },
    limit: { type: 'integer', minimum: 1, maximum: 100, default: 30 },
  } } },
}, async request => success((await query(
  `SELECT * FROM products WHERE is_active AND strpos(lower(name), lower($1)) > 0
   ORDER BY name, id LIMIT $2`,
  [request.query.search?.trim() || '', request.query.limit]
)).rows))""",
    )
    proxy = dashboard / "src/app/api/builder/[...path]/route.ts"
    replace_once(proxy, '"admin/themes/tabs",', '"admin/commerce/products", "admin/commerce/orders", "admin/themes/tabs",')
    layout = dashboard / "src/app/layout.tsx"
    insert_once(layout, 'import type { ReactNode }', 'import Link from "next/link"\n')
    replace_once(layout, '<ThemeBuilderProviders>{children}</ThemeBuilderProviders>', '''
        <ThemeBuilderProviders>
          <nav aria-label="Store admin" className="flex flex-wrap gap-5 border-b bg-white px-5 py-3 text-sm font-semibold text-brand-800">
            <Link href="/catalog">Catalog</Link>
            <Link href="/orders">Orders</Link>
            <Link href="/themes/builder">Theme builder</Link>
          </nav>
          {children}
        </ThemeBuilderProviders>'''.strip())
    insert_once(flutter / "pubspec.yaml", "  gap: 3.0.1\n", "  flutter_slidable: 3.1.2\n  lottie: 3.7.0\n")
    insert_once(flutter / "pubspec.yaml", "    - assets/demo/\n", "    - assets/commerce/\n")


def assemble(destination, brand, profile="home-ui"):
    dest = destination.expanduser().absolute()
    if dest.exists() or dest.is_symlink():
        raise ValueError(f"destination already exists: {dest}")
    if MODULES in dest.resolve().parents:
        raise ValueError("choose a destination outside the bundled module")
    if brand is not None and (not brand.strip() or len(brand) > 80
                              or any(ord(char) < 32 for char in brand)):
        raise ValueError("brand must be a single line of 1–80 characters")

    fixture = check_bundle()
    if profile in {"theme-builder", "commerce"}:
        check_tree(THEME)
    if profile == "commerce":
        check_tree(COMMERCE)
        fixture = json.loads((COMMERCE / "storefront.json").read_text(encoding="utf-8"))
    if brand is not None:
        fixture["brand"] = brand.strip()

    with tempfile.TemporaryDirectory(prefix=".bakaloo-home-", dir=dest.parent) as staging:
        app = Path(staging) / "app"
        if profile == "commerce":
            write_commerce(app, fixture)
        elif profile == "theme-builder":
            write_theme(app, fixture)
        else:
            write_home(app, fixture)
        if dest.exists() or dest.is_symlink():
            raise ValueError(f"destination already exists: {dest}")
        app.rename(dest)
    return {"path": str(dest), "profile": profile, "brand": fixture["brand"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path, help="new directory under an existing parent")
    parser.add_argument("--brand", help="display name for the assembled storefront")
    parser.add_argument("--profile", choices=["home-ui", "theme-builder", "commerce"], default="home-ui")
    args = parser.parse_args()
    try:
        result = assemble(args.destination, args.brand, args.profile)
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f"Assembly failed: {error}\n")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
