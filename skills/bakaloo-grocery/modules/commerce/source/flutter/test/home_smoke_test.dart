import 'package:bakaloo_flutter_app/shared/widgets/home_header.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_search_bar.dart';
import 'package:bakaloo_flutter_app/demo/storefront.dart';
import 'package:bakaloo_flutter_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the Bakaloo header, search and bundled product art', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storefront = await tester.runAsync(Storefront.load);
    await tester.pumpWidget(
      ProviderScope(child: GroceryApp(storefront: storefront!)),
    );
    await tester.pump();
    expect(find.byType(HomeHeader), findsOneWidget);
    expect(find.byType(HomeSearchBar), findsOneWidget);
    expect(find.bySemanticsLabel('Open cart'), findsOneWidget);
    for (final asset in [
      'assets/commerce/market-hero.webp',
      'assets/commerce/category-0.webp',
      ...storefront.products.map((item) => item.thumbnailUrl!),
    ]) {
      final bytes = await tester.runAsync(() => rootBundle.load(asset));
      expect(bytes!.lengthInBytes, greaterThan(0));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
