import 'package:flutter/material.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/data/product_catalog.dart';

// Field names follow the real API:
//  GET /vendor/listings        → rows with price, mrp, stock, approval_status, listing_status, sell_b2c, sell_b2b, wholesale_price …
//  GET /vendor/listings/stats  → { total, pending, rejected, out_of_stock, … }
//  GET /vendor/listings/:id    → full listing (images, specifications, vendor_qc, qc_status …)

num? _n(dynamic v) => v == null ? null : (v is num ? v : num.tryParse('$v'));
int _i(dynamic v) => _n(v)?.toInt() ?? 0;
String _s(dynamic v) => v == null ? '' : '$v';

class CategoryOption {
  const CategoryOption(
    this.id,
    this.name, {
    this.slug = '',
    this.imageUrl,
    this.parentId,
  });
  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final String? parentId;
}

/// Picks the category for a product type. A custom type carries its own
/// category. A built-in matches by name (parts / accessories shops such as
/// "Mobile Parts" are skipped first so phones do not land there); otherwise
/// the first active category (the platform may only have one).
CategoryOption? categoryFor(ProductType t, List<CategoryOption> all) {
  if (all.isEmpty) return null;
  if (!t.builtIn) {
    for (final c in all) {
      if (c.id == t.categoryId) return c;
    }
    return all.first;
  }
  return _nameMatch(t, all) ?? all.first;
}

/// The category whose name matches a built-in type, or null (no fallback).
CategoryOption? _nameMatch(ProductType t, List<CategoryOption> all) {
  final words = switch (t.key) {
    'mobile' => ['phone', 'mobile'],
    'laptop' => ['laptop', 'computer'],
    'tablet' => ['tablet', 'ipad'],
    _ => ['accessor'],
  };
  bool hit(CategoryOption c) {
    final n = c.name.toLowerCase();
    return words.any(n.contains);
  }

  for (final c in all) {
    if (hit(c) && !c.name.toLowerCase().contains('part')) return c;
  }
  for (final c in all) {
    if (hit(c)) return c;
  }
  return null;
}

/// Picker list: the four built-in types, then every other top-level category
/// (admin-managed). Categories a built-in already maps
/// to are not repeated.
List<ProductType> productTypesFrom(List<CategoryOption> cats) {
  final claimed = {
    for (final t in ProductType.values) _nameMatch(t, cats)?.id,
  };
  final builtInKeys = {for (final t in ProductType.values) t.key};
  return [
    ...ProductType.values,
    for (final c in cats)
      if (c.parentId == null &&
          !claimed.contains(c.id) &&
          c.slug.isNotEmpty &&
          !builtInKeys.contains(c.slug))
        ProductType.custom(
          key: c.slug,
          label: c.name,
          imageUrl: c.imageUrl,
          categoryId: c.id,
        ),
  ];
}

/// What the seller sees for a listing in the app.
enum ListingState { live, pending, rejected, paused, outOfStock }

extension ListingStateX on ListingState {
  String get label => switch (this) {
        ListingState.live => 'Live',
        ListingState.pending => 'Pending',
        ListingState.rejected => 'Rejected',
        ListingState.paused => 'Paused',
        ListingState.outOfStock => 'Out of stock',
      };
  Color get fg => switch (this) {
        ListingState.live => AppColors.mint,
        ListingState.pending => const Color(0xFFB45309),
        ListingState.rejected => AppColors.rose,
        ListingState.paused => AppColors.textSecondary,
        ListingState.outOfStock => const Color(0xFFB45309),
      };
  Color get bg => switch (this) {
        ListingState.live => AppColors.mintSoft,
        ListingState.pending => AppColors.amberSoft,
        ListingState.rejected => AppColors.roseSoft,
        ListingState.paused => const Color(0xFFEDF0F6),
        ListingState.outOfStock => AppColors.amberSoft,
      };
}

ListingState listingState(String approval, String status) {
  if (approval == 'REJECTED') return ListingState.rejected;
  if (approval == 'PENDING') return ListingState.pending;
  if (status == 'PAUSED') return ListingState.paused;
  if (status == 'OUT_OF_STOCK') return ListingState.outOfStock;
  return ListingState.live;
}

class ListingCard {
  const ListingCard({
    required this.id,
    required this.name,
    required this.brand,
    required this.condition,
    required this.thumbnail,
    required this.price,
    required this.mrp,
    required this.wholesalePrice,
    required this.moq,
    required this.stock,
    required this.sellB2c,
    required this.sellB2b,
    required this.state,
    required this.rejectionReason,
    required this.qcStatus,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String brand;
  final ProductCondition condition;
  final String? thumbnail;
  final num price;
  final num? mrp;
  final num? wholesalePrice;
  final int moq;
  final int stock;
  final bool sellB2c;
  final bool sellB2b;
  final ListingState state;
  final String? rejectionReason;
  final String qcStatus;
  final DateTime? createdAt;

  /// The headline price: retail when sold to customers, else wholesale.
  num get headlinePrice => sellB2c ? price : (wholesalePrice ?? price);

  factory ListingCard.fromJson(Map<String, dynamic> j) => ListingCard(
        id: _s(j['id']),
        name: _s(j['name']),
        brand: _s(j['brand']),
        condition: ProductCondition.fromApi(_s(j['condition'])),
        thumbnail:
            _s(j['thumbnail_url']).isEmpty ? null : _s(j['thumbnail_url']),
        price: _n(j['price']) ?? 0,
        mrp: _n(j['mrp']),
        wholesalePrice: _n(j['wholesale_price']),
        moq: _i(j['min_order_qty']) < 1 ? 1 : _i(j['min_order_qty']),
        stock: _i(j['stock']),
        sellB2c: j['sell_b2c'] != false,
        sellB2b: j['sell_b2b'] == true,
        state: listingState(_s(j['approval_status']), _s(j['listing_status'])),
        rejectionReason: _s(j['rejection_reason']).isEmpty
            ? null
            : _s(j['rejection_reason']),
        qcStatus: _s(j['qc_status']),
        createdAt: DateTime.tryParse(_s(j['created_at']))?.toLocal(),
      );
}

class ListingPage {
  const ListingPage({required this.items, required this.total});
  final List<ListingCard> items;
  final int total;
}

class ListingStats {
  const ListingStats(
      {required this.total,
      required this.pending,
      required this.rejected,
      required this.outOfStock});
  final int total;
  final int pending;
  final int rejected;
  final int outOfStock;

  /// Approved listings (live, paused or out of stock).
  int get approved => (total - pending - rejected).clamp(0, total);

  factory ListingStats.fromJson(Map<String, dynamic> j) => ListingStats(
        total: _i(j['total']),
        pending: _i(j['pending']),
        rejected: _i(j['rejected']),
        outOfStock: _i(j['out_of_stock']),
      );
}

class ListingDetail {
  const ListingDetail({
    required this.id,
    required this.name,
    required this.brand,
    required this.description,
    required this.categoryName,
    required this.condition,
    required this.conditionNotes,
    required this.images,
    required this.videoUrl,
    required this.price,
    required this.mrp,
    required this.stock,
    required this.warranty,
    required this.accessories,
    required this.returnDays,
    required this.type,
    required this.model,
    required this.storage,
    required this.state,
    required this.approval,
    required this.listingStatus,
    required this.rejectionReason,
    required this.qcStatus,
    required this.qcScore,
    required this.qcNotes,
    required this.sellB2c,
    required this.sellB2b,
    required this.wholesalePrice,
    required this.moq,
    required this.discountPct,
    required this.b2bNotes,
    required this.vendorQc,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String brand;
  final String description;
  final String categoryName;
  final ProductCondition condition;
  final String conditionNotes;
  final List<String> images;
  final String? videoUrl;
  final num price;
  final num? mrp;
  final int stock;
  final String warranty;
  final String accessories;
  final int returnDays;
  final ProductType type;
  final String model;
  final String storage;
  final ListingState state;
  final String approval;
  final String listingStatus;
  final String? rejectionReason;
  final String qcStatus;
  final int? qcScore;
  final String qcNotes;
  final bool sellB2c;
  final bool sellB2b;
  final num? wholesalePrice;
  final int moq;
  final num? discountPct;
  final String b2bNotes;
  final Map<String, dynamic> vendorQc;
  final DateTime? createdAt;

  String? get cover => images.isEmpty ? null : images.first;

  factory ListingDetail.fromJson(Map<String, dynamic> j) {
    final specs = (j['specifications'] as Map?)?.cast<String, dynamic>() ?? {};
    return ListingDetail(
      id: _s(j['id']),
      name: _s(j['name']),
      brand: _s(j['brand']),
      description: _s(j['description']),
      categoryName: _s(j['category_name']),
      condition: ProductCondition.fromApi(_s(j['condition'])),
      conditionNotes: _s(j['condition_notes']),
      images: ((j['images'] as List?) ?? const []).map((e) => '$e').toList(),
      videoUrl: _s(j['video_url']).isEmpty ? null : _s(j['video_url']),
      price: _n(j['selling_price']) ?? 0,
      mrp: _n(j['mrp']),
      stock: _i(j['stock_quantity']),
      warranty: _s(j['warranty_info']),
      accessories: _s(j['accessories_included']),
      returnDays: _i(j['return_policy_days']),
      type: ProductType.fromKey(_s(specs['product_type'])),
      model: _s(specs['model']),
      storage: _s(specs['storage']),
      state: listingState(_s(j['approval_status']), _s(j['listing_status'])),
      approval: _s(j['approval_status']),
      listingStatus: _s(j['listing_status']),
      rejectionReason:
          _s(j['rejection_reason']).isEmpty ? null : _s(j['rejection_reason']),
      qcStatus: _s(j['qc_status']),
      qcScore: j['qc_score'] == null ? null : _i(j['qc_score']),
      qcNotes: _s(j['qc_notes']),
      sellB2c: j['sell_b2c'] != false,
      sellB2b: j['sell_b2b'] == true,
      wholesalePrice: _n(j['wholesale_price']),
      moq: _i(j['min_order_qty']) < 1 ? 1 : _i(j['min_order_qty']),
      discountPct: _n(j['b2b_discount_pct']),
      b2bNotes: _s(j['b2b_notes']),
      vendorQc: (j['vendor_qc'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: DateTime.tryParse(_s(j['created_at']))?.toLocal(),
    );
  }

  ListingCard toCard() => ListingCard(
        id: id,
        name: name,
        brand: brand,
        condition: condition,
        thumbnail: cover,
        price: price,
        mrp: mrp,
        wholesalePrice: wholesalePrice,
        moq: moq,
        stock: stock,
        sellB2c: sellB2c,
        sellB2b: sellB2b,
        state: state,
        rejectionReason: rejectionReason,
        qcStatus: qcStatus,
        createdAt: createdAt,
      );
}

/// Platform QC decision in seller-friendly words.
({String label, Color fg, Color bg}) qcStyle(String status) => switch (status) {
      'QC_PASSED' => (
          label: 'QC Passed',
          fg: AppColors.mint,
          bg: AppColors.mintSoft
        ),
      'QC_FAILED' => (
          label: 'QC Failed',
          fg: AppColors.rose,
          bg: AppColors.roseSoft
        ),
      'QC_RECHECK' => (
          label: 'QC Recheck',
          fg: const Color(0xFFB45309),
          bg: AppColors.amberSoft
        ),
      _ => (
          label: 'QC Pending',
          fg: AppColors.textSecondary,
          bg: const Color(0xFFEDF0F6)
        ),
    };
