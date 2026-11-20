#!/usr/bin/env python3
"""Inspect, verify, export, or assemble the Dealker Flutter UI kit."""

import argparse
from hashlib import sha256
import json
from pathlib import Path
import re
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source"
CATALOG = json.loads((ROOT / "references/catalog.json").read_text())

CUSTOMER_UI = [
    "core/models/store_model.dart",
    "core/theme/app_colors.dart",
    "core/theme/app_dimensions.dart",
    "core/theme/app_text_styles.dart",
    "core/theme/app_theme.dart",
    "core/theme/product_card_tokens.dart",
    "core/theme/remote_theme_model.dart",
    "core/theme/store_tab_palette.dart",
    "features/products/domain/entities/product_entity.dart",
    "features/products/domain/entities/product_entity.freezed.dart",
    "features/products/data/models/product_model.dart",
    "features/products/data/models/product_model.freezed.dart",
    "features/products/data/models/product_model.g.dart",
    "shared/widgets/home_header.dart",
    "shared/widgets/home_search_bar.dart",
    "shared/widgets/dealker_product_card.dart",
]
HOME_WIDGETS = {
    "store_tiles_row", "tabbed_section_parts", "category_hub_section",
    "category_deals_section", "collection_showcase_section", "brand_spotlight_section",
    "price_shop_section", "price_sale_section", "steal_deals_section",
    "banner_rail_section", "oval_spotlight_section", "top_brands_section",
}
CUSTOMER_UI.extend(f"features/home/presentation/widgets/{name}.dart" for name in sorted(HOME_WIDGETS))

VENDOR_UI = [
    "core/theme/app_colors.dart", "core/theme/app_theme.dart",
    "routing/route_names.dart", "shared/widgets/premium_ui.dart",
    "shared/widgets/dm_logo.dart", "shared/widgets/wholesale_product_card.dart",
    "features/home/presentation/widgets/home_actions.dart",
    "features/home/presentation/widgets/home_bottom_nav.dart",
    "features/home/presentation/widgets/home_common.dart",
    "features/home/presentation/widgets/home_header_stats.dart",
    "features/wholesale/data/wholesale_models.dart",
]

STATE_IMPORTS = {
    "features/shops/presentation/providers/shop_distance_provider.dart",
    "core/utils/app_toast.dart",
    "features/auth/presentation/providers/auth_gate_controller.dart",
    "features/cart/presentation/providers/cart_provider.dart",
    "features/purchase_limits/presentation/providers/purchase_limits_provider.dart",
    "features/wishlist/presentation/providers/wishlist_provider.dart",
    "features/products/presentation/widgets/show_product_options.dart",
}
MEDIA_IMPORTS = {"shared/widgets/app_image.dart", "core/constants/api_constants.dart"}
STORE_IMPORTS = {"core/providers/store_provider.dart", "core/theme/remote_theme_provider.dart"}


def replace_once(source, before, after):
    if source.count(before) != 1:
        raise ValueError(f"preview adapter anchor missing or repeated: {before[:75]}")
    return source.replace(before, after, 1)


def save_source(destination, path, text):
    output = destination / path
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text)


def copy_files(root, destination, paths):
    for path in sorted(set(paths)):
        output = destination / path
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / path, output)


def customer_source(path):
    text = (SOURCE / "customer/lib" / path).read_text()
    for original, adapter in [(STATE_IMPORTS, "customer_state"),
                              (MEDIA_IMPORTS, "local_media"),
                              (STORE_IMPORTS, "store_state")]:
        found = [f"import 'package:dealker_app/{name}';\n" for name in sorted(original)
                 if f"import 'package:dealker_app/{name}';\n" in text]
        if found:
            text = text.replace(found[0], f"import 'package:dealker_app/preview/{adapter}.dart';\n", 1)
            for statement in found[1:]:
                text = text.replace(statement, "", 1)
    if path.endswith("/dealker_product_card.dart"):
        text = replace_once(text, "import 'package:dealker_app/core/di/providers.dart';\n", "")
        start = text.index("      onTap: product.isSponsored")
        end = text.index("\n", text.index(": onTap,", start))
        text = text[:start] + "      onTap: onTap," + text[end:]
        start = text.index("  /// Bills the advertiser")
        end = text.index("  String? _badgeText()", start)
        text = text[:start] + text[end:]
    return text


def vendor_source(path):
    text = (SOURCE / "vendor/lib" / path).read_text()
    if path.endswith("/premium_ui.dart"):
        text = text.replace("import 'dart:io' show Platform;\n", "")
        text = text.replace("(MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||\n        Platform.environment.containsKey('FLUTTER_TEST')",
                            "MediaQuery.disableAnimationsOf(context)")
    if path.endswith("/wholesale_product_card.dart"):
        text = text.replace("package:dealker_vendor/features/products/presentation/widgets/product_common.dart",
                            "package:dealker_app/preview/local_media.dart")
    if path.endswith("/home_header_stats.dart"):
        text = re.sub(r"^import .*\b(application|cached_network_image)/.*\n", "", text, flags=re.M)
        text = text.replace("import 'package:flutter_riverpod/flutter_riverpod.dart';\n", "")
        text = text.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:dealker_app/preview/store_state.dart';")
        text = text.replace("extends ConsumerWidget", "extends StatelessWidget")
        text = text.replace("BuildContext context, WidgetRef ref", "BuildContext context")
        start = text.index("    final session =")
        end = text.index("    return Container(", start)
        text = text[:start] + "    final business = PreviewBrand.of(context);\n" + text[end:]
        text = re.sub(r"                // Long-press.*?\.logout\(\),\n", "", text, flags=re.S)
        text = text.replace("if (info?.verified == true)\n                          const WidgetSpan(", "const WidgetSpan(")
        text = replace_once(text, "  const HomeHeader({super.key});",
                            "  const HomeHeader({super.key, required this.cartCount});\n\n  final int cartCount;")
        text = re.sub(r"onTap: \(\) async \{.*?\n                \},", "onTap: () => context.push(Routes.wholesaleCart),", text, count=1, flags=re.S)
        text = text.replace("                  logoUrl: ref.watch(growthProvider).asData?.value.logoUrl,\n", "")
        text = text.replace(", this.logoUrl", "")
        text = text.replace("  final String? logoUrl;\n", "")
        start = text.index("          child: (logoUrl")
        end = text.index(": Text(", start)
        text = text[:start] + "          child: Text(" + text[end + len(": Text("):]
        start = text.index("    final orders =")
        end = text.index("    return HomeCard", start)
        text = text[:start] + text[end:]
        for field, value in {"orders": "18", "live": "4", "quoted": "6", "wallet": "₹24,900"}.items():
            text = re.sub(r"value: " + field + r"\.whenOrNull\(data: [^\n]+\n\s*failed: " + field + r"\.hasError,", f"value: '{value}',\n              failed: false,", text)
    return text.replace("package:dealker_vendor/", "package:dealker_app/vendor/")


def assemble_preview(destination, brand):
    shutil.copytree(ROOT / "assets/preview", destination, dirs_exist_ok=True)
    for path in CUSTOMER_UI:
        save_source(destination, "lib/" + path, customer_source(path))
    for path in VENDOR_UI:
        save_source(destination, "lib/vendor/" + path, vendor_source(path))

    customer = CATALOG["roles"]["customer"]
    vendor = CATALOG["roles"]["vendor"]
    copy_files(SOURCE / "customer", destination,
               [p for group in ("branding", "loading", "fonts", "images", "nav")
                for p in customer["assets"][group] if not p.endswith(".otf")])
    copy_files(SOURCE / "vendor", destination,
               [p for group in ("icons", "categories", "banners", "3d/new", "3d/repair", "3d/auction")
                for p in vendor["assets"][group]])
    copy_files(SOURCE / "vendor", destination, ["assets/branding/app_logo.png"])
    (destination / "assets/preview.json").write_text(json.dumps({"brand": brand}, ensure_ascii=False) + "\n")

    assets = sorted({file.parent.relative_to(destination).as_posix() + "/"
                     for file in (destination / "assets").rglob("*")
                     if file.is_file() and file.parent.name not in {"assets", "fonts"}})
    with (destination / "pubspec.yaml").open("a") as out:
        out.write("  assets:\n    - assets/preview.json\n")
        out.writelines(f"    - {asset}\n" for asset in assets)
        out.write("  fonts:\n")
        for family, weights in {
            "DMSans": ["Regular", "Medium", "SemiBold", "Bold"],
            "PlusJakartaSans": ["Regular", "Medium", "SemiBold", "Bold", "ExtraBold"],
            "Poppins": ["Regular", "Medium", "SemiBold", "Bold"],
            "Inter": ["Regular", "Medium", "SemiBold", "Bold"],
        }.items():
            out.write(f"    - family: {family}\n      fonts:\n")
            for name, weight in zip(weights, range(400, 900, 100)):
                out.write(f"        - asset: assets/fonts/{family}-{name}.ttf\n          weight: {weight}\n")


def export_modules(destination, role, selections):
    record = CATALOG["roles"][role]
    files = []
    for selection in selections:
        if selection.startswith("art:"):
            files.extend(record["assets"][selection[4:]])
        else:
            module = record["features"][selection]
            files.extend(module["files"])
            files.extend(module["literal_assets"])
    copy_files(SOURCE / role, destination, files)
    (destination / "module-selection.json").write_text(json.dumps({
        "role": role, "package": record["package"], "base_commit": record["base_commit"],
        "modules": {name: record["features"][name] for name in selections if not name.startswith("art:")},
        "files": sorted(set(files)),
    }, indent=2) + "\n")


def verify():
    total = 0
    for role, record in CATALOG["roles"].items():
        found = {p.relative_to(SOURCE / role).as_posix() for p in (SOURCE / role).rglob("*") if p.is_file()}
        if found != set(record["sha256"]):
            raise ValueError(f"file inventory mismatch for {role}")
        for name, expected in record["sha256"].items():
            if sha256((SOURCE / role / name).read_bytes()).hexdigest() != expected:
                raise ValueError(f"source snapshot differs: {role}/{name}")
        total += len(found)
    print(f"Verified {total} bundled files and {len(CATALOG['home_sections'])} customer section types.")


def materialize(destination, writer, *arguments):
    destination = destination.absolute()
    if destination.exists() or destination.is_symlink():
        raise ValueError(f"choose a new output directory: {destination}")
    if ROOT in destination.resolve().parents:
        raise ValueError("choose an output directory outside this skill")
    with tempfile.TemporaryDirectory(dir=destination.parent, prefix=".dealker-ui-") as temporary:
        stage = Path(temporary) / "project"
        stage.mkdir()
        writer(stage, *arguments)
        if destination.exists() or destination.is_symlink():
            raise ValueError(f"output directory already exists: {destination}")
        stage.rename(destination)
    print(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("verify")
    commands.add_parser("sections")
    listing = commands.add_parser("list")
    listing.add_argument("role", choices=CATALOG["roles"])
    show = commands.add_parser("show")
    show.add_argument("role", choices=CATALOG["roles"])
    show.add_argument("module")
    export = commands.add_parser("export")
    export.add_argument("role", choices=CATALOG["roles"])
    export.add_argument("destination", type=Path)
    export.add_argument("modules", nargs="+")
    preview = commands.add_parser("preview")
    preview.add_argument("destination", type=Path)
    preview.add_argument("--brand", default="Dealker")
    args = parser.parse_args()
    try:
        if args.command == "verify":
            verify()
        elif args.command == "sections":
            print(json.dumps(CATALOG["home_sections"], indent=2))
        elif args.command == "list":
            role = CATALOG["roles"][args.role]
            print(json.dumps({"modules": list(role["features"]), "art": list(role["assets"])}, indent=2))
        elif args.command == "show":
            role = CATALOG["roles"][args.role]
            info = role["assets"][args.module[4:]] if args.module.startswith("art:") else role["features"][args.module]
            print(json.dumps(info, indent=2))
        elif args.command == "export":
            materialize(args.destination, export_modules, args.role, args.modules)
        elif args.command == "preview":
            brand = args.brand.strip()
            if not brand or len(brand) > 60 or any(ord(char) < 32 for char in brand):
                raise ValueError("brand must be one line of 1 to 60 characters")
            materialize(args.destination, assemble_preview, brand)
    except (KeyError, OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
