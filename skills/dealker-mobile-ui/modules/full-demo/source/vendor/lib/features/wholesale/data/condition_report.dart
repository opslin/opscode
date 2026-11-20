import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';

class ConditionCheck {
  const ConditionCheck(this.label, this.value, this.ok);
  final String label;
  final String value;
  final bool ok;
}

class ProductQc {
  const ProductQc({required this.score, required this.checkedAt, required this.checks});
  final int? score;
  final DateTime? checkedAt;
  final List<ConditionCheck> checks;

  String get verdict {
    final s = score ?? 0;
    if (s >= 90) return 'Excellent';
    if (s >= 80) return 'Very good';
    return 'Good';
  }
}

/// `GET /product-page/condition/:productId` (public) — condition, skin, battery, warranty, in-the-box and the Dealkr QC report.
class ConditionReport {
  const ConditionReport({
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
    required this.qc,
  });

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
  final ProductQc? qc;

  factory ConditionReport.fromJson(Map<String, dynamic> j) {
    List<({String label, String value})> pairs(Object? v) => (v as List? ?? const [])
        .whereType<Map>()
        .map((m) => (label: '${m['label'] ?? ''}', value: '${m['value'] ?? ''}'))
        .where((p) => p.label.isNotEmpty && p.value.isNotEmpty)
        .toList();
    ProductQc? qc;
    final q = j['qc'];
    if (q is Map) {
      qc = ProductQc(
        score: (q['score'] as num?)?.toInt(),
        checkedAt: DateTime.tryParse('${q['checkedAt'] ?? ''}'),
        checks: (q['checks'] as List? ?? const [])
            .whereType<Map>()
            .map((c) => ConditionCheck('${c['label']}', '${c['value']}', c['ok'] == true))
            .toList(),
      );
    }
    return ConditionReport(
      condition: '${j['condition'] ?? 'NEW'}',
      label: '${j['label'] ?? ''}',
      isUsed: j['isUsed'] == true,
      grades: (j['grades'] as List? ?? const [])
          .whereType<Map>()
          .map((g) => (key: '${g['key']}', label: '${g['label']}'))
          .toList(),
      notes: j['notes'] as String?,
      usageDuration: j['usageDuration'] as String?,
      batteryHealth: (j['batteryHealth'] as num?)?.toInt(),
      warranty: j['warranty'] as String?,
      accessories: (j['accessories'] as List? ?? const []).map((e) => '$e').toList(),
      hasInvoice: j['hasInvoice'] == true,
      checklist: pairs(j['checklist']),
      qc: qc,
    );
  }
}

final conditionReportProvider =
    FutureProvider.autoDispose.family<ConditionReport?, String>((ref, productId) async {
  try {
    final r = await ref.watch(dioProvider).get<dynamic>('/product-page/condition/$productId');
    final d = (r.data as Map)['data'];
    return d is Map ? ConditionReport.fromJson(Map<String, dynamic>.from(d)) : null;
  } on DioException {
    return null;
  } catch (_) {
    return null;
  }
});

// ── Per-device QC (Device 1 … K of a used / refurbished / open-box listing) ──

class QcRow {
  const QcRow(this.label, this.value, this.ok);
  final String label;
  final String value;
  final bool? ok; // null = not applicable

  factory QcRow.fromJson(Map<String, dynamic> j) =>
      QcRow('${j['label'] ?? ''}', '${j['value'] ?? ''}', j['ok'] as bool?);
}

class UnitBrief {
  const UnitBrief({required this.unitNo, required this.status, required this.score, required this.battery, required this.defects, required this.chips, this.autoFilled = false});
  final int unitNo;
  final String status; // AVAILABLE | RESERVED | PACKED | SOLD
  final int score;
  final int? battery;
  final int defects;
  final List<QcRow> chips;
  final bool autoFilled;

  bool get available => status == 'AVAILABLE';

  factory UnitBrief.fromJson(Map<String, dynamic> j) => UnitBrief(
        unitNo: (j['unit_no'] as num?)?.toInt() ?? 0,
        status: '${j['status'] ?? 'AVAILABLE'}',
        score: (j['score'] as num?)?.toInt() ?? 0,
        battery: (j['battery_health'] as num?)?.toInt(),
        defects: (j['defects'] as num?)?.toInt() ?? 0,
        autoFilled: j['auto_filled'] == true,
        chips: [for (final c in (j['chips'] as List? ?? const [])) QcRow.fromJson((c as Map).cast<String, dynamic>())],
      );
}

class UnitReport {
  const UnitReport({required this.brief, required this.sections, this.notes, this.autoNote});
  final UnitBrief brief;
  final Map<String, List<QcRow>> sections; // screen | functional | battery | physical
  final String? notes;
  final String? autoNote;

  factory UnitReport.fromJson(Map<String, dynamic> j) {
    final r = (j['report'] as Map?)?.cast<String, dynamic>() ?? const {};
    List<QcRow> rows(String k) => [for (final c in (r[k] as List? ?? const [])) QcRow.fromJson((c as Map).cast<String, dynamic>())];
    return UnitReport(
      brief: UnitBrief.fromJson(j),
      sections: {for (final k in const ['screen', 'functional', 'battery', 'physical']) k: rows(k)},
      notes: r['notes'] as String?,
      autoNote: r['auto_note'] as String?,
    );
  }
}

final unitReportProvider = FutureProvider.autoDispose.family<UnitReport?, (String, int)>((ref, k) async {
  try {
    final r = await ref.watch(dioProvider).get<dynamic>('/product-page/units/${k.$1}/${k.$2}'); // k.$2 = device number
    return UnitReport.fromJson(((r.data as Map)['data'] as Map).cast<String, dynamic>());
  } catch (_) {
    return null;
  }
});
