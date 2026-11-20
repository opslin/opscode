import 'package:bakaloo_flutter_app/demo/storefront.dart';
import 'package:bakaloo_flutter_app/main.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_header.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_search_bar.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Storefront> launch(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final storefront = await tester.runAsync(Storefront.load);
  await tester.pumpWidget(
    ProviderScope(child: GroceryApp(storefront: storefront!)),
  );
  await tester.pump();
  return storefront;
}

void main() {
  testWidgets('renders the Bakaloo widgets and bundled artwork on a phone', (
    tester,
  ) async {
    final storefront = await launch(tester, const Size(390, 844));
    expect(
      tester.widget<HomeHeader>(find.byType(HomeHeader)).brandName,
      storefront.brand,
    );
    expect(find.byType(HomeSearchBar), findsOneWidget);
    expect(find.byType(AppImage), findsWidgets);
    expect(find.text('Chilled Drinks & Dessert'), findsOneWidget);
    for (final promo in storefront.promos) {
      final bytes = await tester.runAsync(() => rootBundle.load(promo.image));
      expect(bytes!.lengthInBytes, greaterThan(0));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'selects dairy and adds ice cream to the local cart on a small phone',
    (tester) async {
      await launch(tester, const Size(320, 640));
      await tester.tap(find.byKey(const ValueKey('category-dairy')));
      await tester.pumpAndSettle();
      expect(find.text('Chilled Drinks & Dessert'), findsNothing);
      expect(find.text('Vanilla Ice Cream'), findsOneWidget);
      final iceCream = find.ancestor(
        of: find.text('Vanilla Ice Cream'),
        matching: find.byType(ProductCard),
      );
      await tester.tap(
        find.descendant(of: iceCream, matching: find.text('ADD')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cart (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Your cart'), findsOneWidget);
      expect(find.text('Total ₹149'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove Vanilla Ice Cream'));
      await tester.pumpAndSettle();
      expect(find.text('Your cart is empty.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('searches demo products and shows an empty state', (
    tester,
  ) async {
    await launch(tester, const Size(390, 844));
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing item');
    await tester.pumpAndSettle();
    expect(find.text('No products match your search.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'tomatoes');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Fresh Tomatoes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
