import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/di/providers.dart';

class ConditionCheck {
  const ConditionCheck(this.label, this.value, this.ok);
  final String label;
  final String value;
  final bool ok;
}

class ProductQc {
  const ProductQc(
      {required this.score, required this.checkedAt, required this.checks});
  final int? score;
  final DateTime? checkedAt;
  final List<ConditionCheck> checks;

  String get verdict {
    final int s = score ?? 0;
    if (s >= 90) return 'Excellent';
    if (s >= 80) return 'Very good';
    return 'Good';
  }
}

/// `GET /product-page/condition/:id` — condition, skin, battery, warranty and QC for one listing.
class ProductCondition {
  const ProductCondition({
    required this.shopId,
    required this.condition,
    required this.label,
    required this.isUsed,
    required this.grades,
    required this.notes,
    required this.usageDuration,
    required this.batteryHealth,
    required this.warranty,
    required this.accessories,
    required this.hasInvoice,
    required this.checklist,
    required this.specs,
    required this.qc,
  });

  final String? shopId;
  final String condition;
  final String label;
  final bool isUsed;
  final List<({String key, String label})> grades;
  final String? notes;
  final String? usageDuration;
  final int? batteryHealth;
  final String? warranty;
  final List<String> accessories;
  final bool hasInvoice;
  final List<({String label, String value})> checklist;
  final List<({String label, String value})> specs;
  final ProductQc? qc;

  /// 'NEW' | 'USED_*' | 'OPEN_BOX' | 'REFURBISHED' → short tag for the gallery corner.
  String get tag => condition == 'NEW' ? 'BRAND NEW' : label.toUpperCase();

  factory ProductCondition.fromJson(Map<String, dynamic> j) {
    List<({String label, String value})> pairs(Object? v) =>
        (v as List? ?? <Object?>[])
            .whereType<Map>()
            .map((Map m) => (
                  label: '${m['label'] ?? m['name'] ?? ''}',
                  value: '${m['value'] ?? ''}'
                ))
            .where((p) => p.label.isNotEmpty && p.value.isNotEmpty)
            .toList();

    ProductQc? qc;
    final Object? q = j['qc'];
    if (q is Map) {
      qc = ProductQc(
        score: (q['score'] as num?)?.toInt(),
        checkedAt: DateTime.tryParse('${q['checkedAt'] ?? ''}'),
        checks: (q['checks'] as List? ?? <Object?>[])
            .whereType<Map>()
            .map((Map c) => ConditionCheck(
                '${c['label']}', '${c['value']}', c['ok'] == true))
            .toList(),
      );
    }
    return ProductCondition(
      shopId: j['shopId'] as String?,
      condition: '${j['condition'] ?? 'NEW'}',
      label: '${j['label'] ?? ''}',
      isUsed: j['isUsed'] == true,
      grades: (j['grades'] as List? ?? <Object?>[])
          .whereType<Map>()
          .map((Map g) => (key: '${g['key']}', label: '${g['label']}'))
          .toList(),
      notes: j['notes'] as String?,
      usageDuration: j['usageDuration'] as String?,
      batteryHealth: (j['batteryHealth'] as num?)?.toInt(),
      warranty: j['warranty'] as String?,
      accessories: (j['accessories'] as List? ?? <Object?>[])
          .map((Object? e) => '$e')
          .toList(),
      hasInvoice: j['hasInvoice'] == true,
      checklist: pairs(j['checklist']),
      specs: pairs(j['specs']),
      qc: qc,
    );
  }
}

final productConditionProvider = FutureProvider.autoDispose
    .family<ProductCondition?, String>((Ref ref, String id) async {
  try {
    final Response<dynamic> r = await ref
        .watch(dioClientProvider)
        .get<dynamic>('/product-page/condition/$id');
    final Object? d = (r.data as Map)['data'];
    return d is Map
        ? ProductCondition.fromJson(Map<String, dynamic>.from(d))
        : null;
  } catch (_) {
    return null;
  }
});

/// `GET /product-page/layout` — block order/visibility set in the dashboard theme builder.
const List<String> kDefaultProductBlocks = <String>[
  'gallery',
  'title_price',
  'condition',
  'qc',
  'in_box',
  'highlights',
  'specs',
  'description',
  'vendor',
  'similar',
];

final productPageLayoutProvider = FutureProvider<List<String>>((Ref ref) async {
  try {
    final Response<dynamic> r =
        await ref.watch(dioClientProvider).get<dynamic>('/product-page/layout');
    final List<dynamic> blocks =
        ((r.data as Map)['data'] as Map)['blocks'] as List<dynamic>;
    return blocks
        .whereType<Map>()
        .where((Map b) => b['visible'] != false)
        .map((Map b) => '${b['key']}')
        .toList();
  } catch (_) {
    return kDefaultProductBlocks;
  }
});
