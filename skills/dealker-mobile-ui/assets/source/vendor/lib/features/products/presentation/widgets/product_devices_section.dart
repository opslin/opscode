import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/data/unit_qc.dart';
import 'package:dealker_vendor/features/products/presentation/steps/device_qc_form.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

class _Dev {
  const _Dev(this.no, this.sold, this.defects, this.battery, this.score, this.auto, this.status);
  final bool auto;
  final String status;
  final int no;
  final bool sold;
  final int defects;
  final int? battery;
  final int score;
}

final _devicesProvider = FutureProvider.autoDispose.family<List<_Dev>, String>((ref, id) async {
  final r = await ref.watch(dioProvider).get<dynamic>('/vendor/listings/$id/units');
  final rows = ((r.data as Map)['data'] as List?) ?? const [];
  return [
    for (final u in rows.whereType<Map>())
      _Dev((u['unit_no'] as num).toInt(), u['status'] != 'AVAILABLE', (u['defects'] as num?)?.toInt() ?? 0, (u['battery_health'] as num?)?.toInt(), (u['score'] as num?)?.toInt() ?? 0, u['auto_filled'] == true, '${u['status']}')
  ];
});

/// The vendor's own devices of a used / refurbished / open-box listing: which are sold, which are still for sale,
/// and a way to correct a device's QC report.
class ProductDevicesSection extends ConsumerStatefulWidget {
  const ProductDevicesSection({super.key, required this.listingId});
  final String listingId;

  @override
  ConsumerState<ProductDevicesSection> createState() => _ProductDevicesSectionState();
}

class _ProductDevicesSectionState extends ConsumerState<ProductDevicesSection> {
  bool _all = false;
  String get listingId => widget.listingId;

  Future<void> _edit(BuildContext context, _Dev d, int total) async {
    try {
      final dio = ref.read(dioProvider);
      final r = await dio.get<dynamic>('/vendor/listings/$listingId/units/${d.no}');
      final data = ((r.data as Map)['data'] as Map).cast<String, dynamic>();
      if (!context.mounted) return;
      final res = await Navigator.of(context).push<UnitQc>(MaterialPageRoute(
        builder: (_) => DeviceQcForm(deviceNo: d.no, total: total, initial: UnitQc.fromJson((data['qc'] as Map).cast<String, dynamic>()), autoFilled: d.auto),
      ));
      if (res == null) return;
      await dio.put<dynamic>('/vendor/listings/$listingId/units/${d.no}', data: {'qc': res.toJson()});
      ref.invalidate(_devicesProvider(listingId));
      if (context.mounted) showAppToast(context, 'Device ${d.no} QC updated');
    } catch (_) {
      if (context.mounted) showAppToast(context, 'Could not update this device', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devs = ref.watch(_devicesProvider(listingId)).asData?.value ?? const <_Dev>[];
    if (devs.isEmpty) return const SizedBox.shrink();
    final sold = devs.where((d) => d.sold).length;
    final toReview = devs.where((d) => d.auto && !d.sold).length;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Devices & QC', style: heading(size: 17)),
            const Spacer(),
            Text('${devs.length - sold} for sale · $sold sold / in orders', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 4),
          const Text('Each device has its own QC report. Devices are sold in order, Device 1 first.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          if (toReview > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
              child: Text('$toReview device${toReview == 1 ? ' has' : 's have'} default QC filled in from your listing. Tap a device to inspect it and confirm.',
                  style: const TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFFB45309))),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final d in (_all ? devs : devs.take(24)))
              GestureDetector(
                onTap: d.sold ? null : () => _edit(context, d, devs.length),
                child: Container(
                  width: 96,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: d.sold ? const Color(0xFFF1F3F9) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: d.sold ? Colors.transparent : (d.defects == 0 ? AppColors.mint : AppColors.amber)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Device ${d.no}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: d.sold ? AppColors.textMuted : AppColors.navy)),
                    const SizedBox(height: 4),
                    Text(d.sold ? (d.status == 'RESERVED' ? 'In an order' : d.status == 'PACKED' ? 'Packed' : 'Sold') : (d.auto ? 'Default QC' : 'Score ${d.score}'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: d.sold ? AppColors.textMuted : AppColors.mint)),
                    Text(d.sold ? '' : (d.defects == 0 ? 'No issues' : '${d.defects} issue${d.defects == 1 ? '' : 's'}'), style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    if (!d.sold) const Icon(PhosphorIconsRegular.pencilSimple, size: 15, color: AppColors.primary),
                  ]),
                ),
              ),
          ]),
          if (!_all && devs.length > 24)
            Center(child: TextButton(onPressed: () => setState(() => _all = true), child: Text('Show all ${devs.length} devices'))),
        ]),
      ),
    );
  }
}
