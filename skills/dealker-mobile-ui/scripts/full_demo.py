#!/usr/bin/env python3
"""Assemble the two original Flutter apps with their local demo adapters."""

import argparse
from pathlib import Path
import re
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules/full-demo/source"

def patch(file, before, after):
    text = file.read_text()
    if text.count(before) != 1:
        raise ValueError(f"expected one demo integration point in {file}: {before[:64]}")
    file.write_text(text.replace(before, after, 1))


def demo_brand(customer, vendor):
    display_labels = {
        customer: (
            'Welcome to Dealkr', 'Dealkr Wallet', 'Why Dealkr Repair?',
            'Dealkr Customer', 'New on Dealkr', 'Dealkr Money', 'Dealkr  •  Version',
            'Dealkr. All rights reserved.', 'Shop mobiles and electronics on Dealkr:',
        ),
        vendor: ("Text('Dealkr',", 'Dealkr support', 'Dealkr Support', 'Dealkr Wallet', 'DMobileMart'),
    }
    for tree, labels in display_labels.items():
        for file in tree.glob('features/**/*.dart'):
            if file.name.endswith('.g.dart'):
                continue
            before = after = file.read_text()
            for label in labels:
                after = after.replace(label, label.replace('Dealkr', 'Velo Devices').replace('DMobileMart', 'Velo Devices'))
            if before != after:
                file.write_text(after)


def assemble(destination, port):
    with tempfile.TemporaryDirectory(dir=destination.parent, prefix=".dealker-full-") as temporary:
        stage = Path(temporary) / "demo"
        shutil.copytree(SOURCE, stage)
        for role in ("customer", "vendor"):
            app = stage / role
            html = app / "web/index.html"
            text = html.read_text()
            text = re.sub(r'^.*https://checkout\.razorpay\.com.*\n', '', text, flags=re.M)
            text = re.sub(r'^.*(?:href="manifest\.json"|rel="apple-touch-icon").*\n', '', text, flags=re.M)
            text = text.replace("Dealker", "Velo Devices").replace("<title>dealker_app", "<title>Velo Devices")
            html.write_text(text)
        customer = stage / "customer/lib"
        patch(customer / "routing/app_router.dart",
              "import 'package:dealker_app/routing/route_names.dart';",
              "import 'package:dealker_app/routing/route_names.dart';\n"
              "import 'package:dealker_app/demo/section_screen.dart';")
        patch(customer / "routing/app_router.dart", "    routes: <RouteBase>[\n      GoRoute(",
              """    routes: <RouteBase>[
      GoRoute(
        path: '/demo/section/:type',
        builder: (_, state) => DemoSectionScreen(type: state.pathParameters['type']!),
      ),
      GoRoute(""")
        patch(customer / "features/repair/presentation/widgets/repair_guide.dart",
              "static Future<void> maybeShow(BuildContext context, String? userId) async {",
              "static Future<void> maybeShow(BuildContext context, String? userId) async {\n"
              "    if (const bool.fromEnvironment('VELO_DEMO')) return;")
        patch(customer / "routing/app_router.dart", "initialLocation: RouteNames.splash,", "initialLocation: RouteNames.home,")
        patch(customer / "routing/app_router.dart", "if (authenticated && isAuthRoute && pendingIntent == null) {",
              "if (authenticated && isAuthRoute && pendingIntent == null && state.uri.queryParameters['inspect'] != '1') {")
        patch(customer / "features/auth/presentation/providers/auth_notifier.dart",
              "ref.onDispose(socket.disconnect);\n    return const AuthUnauthenticated();",
              """ref.onDispose(socket.disconnect);
    return const AuthAuthenticated(user: UserEntity(
      id: 'demo-customer', phone: '0000000000', role: 'CUSTOMER', name: 'Asha Patel',
    ));""")
        patch(customer / "features/home/presentation/screens/home_screen.dart",
              "Future<void> _maybeShowLocationPrompt() async {",
              "Future<void> _maybeShowLocationPrompt() async {\n    if (const bool.fromEnvironment('VELO_DEMO')) return;")
        patch(customer / "app.dart", "return MaterialApp.router(\n          theme:", "return MaterialApp.router(\n          title: 'Velo Devices',\n          theme:")
        vendor = stage / "vendor/lib"
        patch(vendor / "routing/app_router.dart", "initialLocation: Routes.splash,", "initialLocation: Routes.home,")
        patch(vendor / "routing/app_router.dart",
              "return (isPublic || loc == Routes.splash) ? Routes.home : null;",
              "return (isPublic || loc == Routes.splash) && state.uri.queryParameters['inspect'] != '1' ? Routes.home : null;")
        patch(vendor / "features/auth/application/auth_controller.dart", "name: 'DM Mobile Store'", "name: 'Velo Devices'")
        patch(vendor / "app.dart", "title: 'DM Vendor Hub'", "title: 'Velo Devices Vendor'")
        patch(vendor / "features/profile/data/demo_profile_repository.dart", "name: 'DMobileMart'", "name: 'Velo Devices'")
        router = vendor / "routing/app_router.dart"
        patch(router, "OtpScreen(args: s.extra! as OtpArgs)",
              "OtpScreen(args: (s.extra as OtpArgs?) ?? const OtpArgs(phone: '0000000000', registering: false))")
        patch(router, "ProductSubmittedScreen(item: s.extra! as ListingDetail)",
              "ProductSubmittedScreen(item: (s.extra as ListingDetail?) ?? ListingDetail.fromJson("
              "{'id':'demo-1', 'name':'Velo sample listing', 'status':'ACTIVE'}))")
        patch(router, "SendOfferScreen(draft: s.extra! as OfferDraft)",
              "SendOfferScreen(draft: (s.extra as OfferDraft?) ?? OfferDraft("
              "requestId: 'demo-repair', rows: [DraftRow(itemId: 'repair-phone', "
              "deviceName: 'OnePlus 11', issue: 'SCREEN', parts: 2999, labour: 500)], devices: []))")
        patch(router, "AuctionCreatedScreen(auction: s.extra! as AuctionItem)",
              "AuctionCreatedScreen(auction: (s.extra as AuctionItem?) ?? AuctionItem.fromJson("
              "{'id':'demo-auction', 'title':'Velo sample auction'}))")
        patch(router, "CampaignCreatedScreen(campaign: s.extra! as CampaignDetail)",
              "CampaignCreatedScreen(campaign: (s.extra as CampaignDetail?) ?? CampaignDetail.fromJson("
              "{'id':'demo-campaign', 'name':'Velo launch campaign'}))")
        patch(vendor / "shared/widgets/premium_ui.dart",
              "import 'dart:io' show Platform;\n", "")
        patch(vendor / "shared/widgets/premium_ui.dart",
              "(MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||\n        Platform.environment.containsKey('FLUTTER_TEST');",
              "MediaQuery.disableAnimationsOf(context);")
        for file in vendor.glob("features/*/data/demo*.dart"):
            if "https://api.dealker.agnixstudio.in/uploads/products" in file.read_text():
                patch(file, "'https://api.dealker.agnixstudio.in/uploads/products'",
                      f"'http://127.0.0.1:{port}/uploads/products'")
        demo_brand(customer, vendor)
        (stage / "vendor/.env").write_text(f"DEMO_HOME=true\nBASE_URL=http://127.0.0.1:{port}/api/v1\n")
        (stage / "demo-port.txt").write_text(str(port) + "\n")
        if destination.exists() or destination.is_symlink():
            raise FileExistsError(destination)
        stage.rename(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--port", type=int, default=5010)
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error("port must be between 1024 and 65535")
    assemble(args.destination.absolute(), args.port)
    print(args.destination.absolute())


if __name__ == "__main__":
    main()
