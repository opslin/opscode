#!/usr/bin/env python3
"""Regenerate the local index from the bundled original Flutter routers."""

from pathlib import Path
import json
import re

KIT = Path(__file__).resolve().parents[1]
DEMO = KIT / "modules/full-demo/source"
ROUTES_PATTERN = re.compile(r"\bGoRoute\s*\(")
TOKENS = re.compile(r"""//[^\n]*|/\*[\s\S]*?\*/|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|[()]""")
FIRST_PRODUCT = "DEMO_FIRST_PRODUCT"


def end_of_call(text, start):
    depth = 1
    for token in TOKENS.finditer(text, start):
        if token.group() == "(":
            depth += 1
        elif token.group() == ")":
            depth -= 1
            if depth == 0:
                return token.end()
    raise ValueError(f"unclosed GoRoute at {start}")


def fixture_path(path, role):
    parts = path.split("/")
    for index, part in enumerate(parts):
        if not part.startswith(":"):
            continue
        key = part[1:]
        prefix = "/".join(parts[:index])
        if key in {"productId", "slug"} or prefix in {"/product", "/products", "/wholesale", "/products/view", "/wholesale/view"}:
            value = FIRST_PRODUCT if key != "slug" else "velo-1"
            if role == "vendor" and prefix.startswith("/products"):
                value = "p1"
        elif key == "categoryId":
            value = "phones"
        elif "repair" in prefix:
            value = "demo-offer" if key == "offerId" else "demo-repair"
        elif "auction" in prefix:
            value = ("L1" if "/lot" in prefix else "d1") if role == "vendor" else "demo-auction"
        elif "shop" in prefix:
            value = "demo-shop"
        elif "demand" in prefix:
            value = "o-pay" if "/orders" in prefix else "r1"
        elif "order" in prefix or "return" in prefix:
            value = "demo-order"
        elif "campaign" in prefix:
            value = "c1"
        elif "abandoned-carts" in prefix:
            value = "c1"
        elif "deals" in prefix:
            value = "demo-deal"
        elif key == "tabKey":
            value = "all"
        elif key == "vendorId":
            value = "demo-shop"
        else:
            value = "demo-record"
        parts[index] = value
    actual = "/".join(parts)
    if re.search(r"(^|/)(phone|otp|login|register|welcome)$", actual):
        actual += "?inspect=1"
    return actual


def read_routes(role):
    base = DEMO / role / "lib/routing"
    names = dict(re.findall(r"""static\s+const(?:\s+String)?\s+(\w+)\s*=\s*['"]([^'"]+)['"]""", (base / "route_names.dart").read_text()))
    source = (base / "app_router.dart").read_text()
    stack, result = [], []
    for match in ROUTES_PATTERN.finditer(source):
        start = match.end()
        end = end_of_call(source, start)
        while stack and stack[-1][0] < start:
            stack.pop()
        immediate = source[start:end]
        path = re.match(r"""\s*path:\s*(?:["']([^"']+)["']|(?:RouteNames|Routes)\.(\w+))""", immediate)
        if not path:
            continue
        raw = path[1] or names.get(path[2])
        if not raw:
            continue
        full = raw if raw.startswith("/") else ((stack[-1][1] if stack else "").rstrip("/") + "/" + raw)
        stack.append((end, full))
        next_route = immediate.find("GoRoute(")
        if next_route >= 0:
            immediate = immediate[:next_route]
        widgets = re.findall(r"\b([A-Z]\w+(?:Screen|Page|View))\s*\(", immediate)
        label = (widgets[0] if widgets else full.rsplit("/", 1)[-1] or "Splash")
        label = re.sub(r"(?<=[a-z])(?=[A-Z])", " ", label).removesuffix(" Screen")
        result.append({
            "label": label,
            "route": full,
            "example": fixture_path(full, role),
            "source": f"{role}/lib/routing/app_router.dart:{source.count(chr(10), 0, match.start()) + 1}",
            "group": full.split("/")[1].split(":")[0] or "Entry",
        })
    return sorted(result, key=lambda row: (row["group"], row["route"]))


def home_slots():
    home = "customer/lib/features/home/presentation"
    vendor = "vendor/lib/features/home/presentation/widgets"
    return {
        "customer": [
            ["Delivery header and store switcher", f"{home}/screens/home_screen.dart"],
            ["Subcategory tabs and search", f"{home}/screens/home_screen.dart"],
            ["Dynamic merchandising and sale sections", f"{home}/widgets/section_registry.dart"],
        ],
        "vendor": [
            ["Header, store and stats", f"{vendor}/home_header_stats.dart"],
            ["Quick actions", f"{vendor}/home_actions.dart"],
            ["Demand banner", "vendor/lib/features/demand/presentation/widgets/demand_banner.dart"],
            ["Needs action", f"{vendor}/needs_action.dart"],
            ["Abandoned carts", "vendor/lib/features/abandoned_carts/presentation/widgets/home_cart_card.dart"],
            ["Live auctions and campaigns", f"{vendor}/live_section.dart"],
            ["Wholesale marketplace", f"{vendor}/home_marketplace.dart"],
            ["Bottom navigation", f"{vendor}/home_bottom_nav.dart"],
        ],
    }


def main():
    section_index = json.loads((KIT / "references/catalog.json").read_text())["home_sections"]
    areas = {
        "storefront": {"flutter": ["customer/lib/features/home", "customer/lib/features/categories", "customer/lib/core/theme"],
                       "backend": ["src/modules/themes", "src/modules/admin/sections", "src/modules/admin/theme-tabs"],
                       "dashboard": ["src/components/builder", "src/app/(dashboard)/themes/builder/page.tsx"],
                       "fixture": "service/fixtures/home.mjs"},
        "catalog": {"flutter": ["customer/lib/features/products", "vendor/lib/features/products", "vendor/lib/features/wholesale"],
                    "backend": ["src/modules/products", "src/modules/shop-products", "src/modules/product-families"],
                    "dashboard": ["src/app/(dashboard)/products", "src/app/(dashboard)/shop-products/page.tsx"],
                    "fixture": "service/fixtures/catalog.mjs"},
        "repair": {"flutter": ["customer/lib/features/repair", "vendor/lib/features/repairs", "vendor/lib/features/repair_book"],
                   "backend": ["src/modules/repairs"], "dashboard": ["src/app/(dashboard)/repairs", "src/components/repairs"],
                   "fixture": "service/fixtures/repair.mjs"},
        "commerce": {"flutter": ["customer/lib/features/cart", "customer/lib/features/checkout", "vendor/lib/features/orders"],
                     "backend": ["src/modules/cart", "src/modules/cart-quote", "src/modules/orders", "src/modules/vendor-orders"],
                     "dashboard": ["src/app/(dashboard)/orders", "src/app/(dashboard)/seller-orders/page.tsx"],
                     "fixture": "service/demo-api.mjs"},
        "vendor_operations": {"flutter": ["vendor/lib/features/home", "vendor/lib/features/demand", "vendor/lib/features/profile", "vendor/lib/features/campaigns", "vendor/lib/features/auctions"],
                              "backend": ["src/modules/vendors", "src/modules/auctions", "src/modules/vendor-procurement"],
                              "dashboard": ["src/app/(dashboard)/vendors/page.tsx", "src/app/(dashboard)/auctions"],
                              "fixture": "vendor/lib/features/*/data/demo_*_repository.dart"},
    }
    output = {
        "roles": {role: read_routes(role) for role in ("customer", "vendor")},
        "sections": section_index,
        "home_slots": home_slots(),
        "areas": areas,
    }
    target = DEMO / "dashboard/index.json"
    target.write_text(json.dumps(output, indent=2) + "\n")
    print(", ".join(f"{role} {len(routes)} routes" for role, routes in output["roles"].items()))
    print(f"{len(output['sections'])} homepage section types")


if __name__ == "__main__":
    main()
