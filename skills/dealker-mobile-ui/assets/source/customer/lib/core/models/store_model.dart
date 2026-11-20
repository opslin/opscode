import 'package:flutter/material.dart';

/// Store key the app opens on until the customer picks another store tile.
/// Must be one of the keys the backend returns from `GET /theme/stores`.
const String kDefaultStoreKey = 'mobile';

/// One of the top-of-home stores (Mobile, Mobile Part, Accessories, …).
/// Label, icon and order come from the backend (`storefront_stores`).
class StoreModel {
  const StoreModel({
    required this.id,
    required this.label,
    this.iconUrl,
    this.subtitle = '',
    this.backgroundColor = const Color(0xFFF7DC4E),
    this.chipActiveColor = const Color(0xFFFFFFFF),
    this.textColor = Colors.black,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) => StoreModel(
        id: json['store_key'] as String,
        label: (json['label'] as String?) ?? (json['store_key'] as String),
        iconUrl: json['icon_url'] as String?,
      );

  final String id;
  final String label;
  final String? iconUrl;
  final String subtitle;
  final Color backgroundColor;
  final Color chipActiveColor;
  final Color textColor;
}

/// Used only until the store list has loaded (or if it can't be fetched).
const StoreModel fallbackStore = StoreModel(
  id: kDefaultStoreKey,
  label: 'Mobile',
);
