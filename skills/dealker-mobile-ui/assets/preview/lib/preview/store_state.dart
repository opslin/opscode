import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/store_model.dart';
import '../core/theme/remote_theme_model.dart';

const fixtureStores = [
  StoreModel(
    id: 'mobile',
    label: 'Mobile',
    iconUrl: 'assets/loading/mobile.png',
    subtitle: '25 minutes',
  ),
  StoreModel(
    id: 'parts',
    label: 'Parts',
    iconUrl: 'assets/loading/powerbank.png',
    subtitle: '40 minutes',
  ),
  StoreModel(
    id: 'accessories',
    label: 'Accessories',
    iconUrl: 'assets/loading/headphones.png',
    subtitle: '30 minutes',
  ),
  StoreModel(
    id: 'electronics',
    label: 'Electronics',
    iconUrl: 'assets/loading/electronics.png',
    subtitle: '45 minutes',
  ),
];

final storesProvider = Provider<AsyncValue<List<StoreModel>>>(
  (ref) => const AsyncData(fixtureStores),
);
final selectedStoreProvider = NotifierProvider<StoreSelection, StoreModel>(
  StoreSelection.new,
);
final selectedCategoryIdProvider = NotifierProvider<CategorySelection, String>(
  CategorySelection.new,
);
final activeTabThemeProvider = Provider<RemoteTheme>(
  (ref) => RemoteTheme.defaults(),
);

class StoreSelection extends Notifier<StoreModel> {
  @override
  StoreModel build() => fixtureStores.first;

  void select(StoreModel store) => state = store;
}

class CategorySelection extends Notifier<String> {
  @override
  String build() => '';

  void select(String category) => state = category;
}

class PreviewBrand extends InheritedWidget {
  const PreviewBrand({super.key, required this.brand, required super.child});

  final String brand;

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreviewBrand>()!.brand;

  @override
  bool updateShouldNotify(PreviewBrand oldWidget) => oldWidget.brand != brand;
}
