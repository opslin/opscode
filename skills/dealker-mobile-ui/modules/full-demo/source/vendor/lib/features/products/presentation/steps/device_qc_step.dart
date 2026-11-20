import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/data/unit_qc.dart';
import 'package:dealker_vendor/features/products/presentation/steps/device_qc_form.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';

/// Step "Device QC": one QC report for EACH unit (Device 1 … Device N). New stock skips this step.
class DeviceQcStep extends ConsumerWidget {
  const DeviceQcStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(addDraftProvider);
    final n = ref.read(addDraftProvider.notifier);
    final total = d.stock;
    final done = d.devicesDone;

    Future<void> open(int no) async {
      var cur = no;
      while (cur <= total) {
        final res = await Navigator.of(context).push<UnitQc>(MaterialPageRoute(
          builder: (_) => DeviceQcForm(
            deviceNo: cur,
            total: total,
            initial: ref.read(addDraftProvider).unitQc[cur],
            copyFrom: {for (final e in ref.read(addDraftProvider).unitQc.entries) if (e.key != cur) e.key: e.value},
            hasNext: cur < total,
          ),
        ));
        if (res == null) return;
        n.saveUnit(cur, res);
        // "Save & next": go straight to the next device that is not done yet.
        final next = [for (var i = cur + 1; i <= total; i++) if (!ref.read(addDraftProvider).unitQc.containsKey(i)) i];
        if (next.isEmpty) return;
        cur = next.first;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        Text('Device QC', style: heading(size: 19)),
        const SizedBox(height: 4),
        Text(
            '${d.condition.label} stock needs a QC report for every device. You listed $total unit${total == 1 ? '' : 's'}, so complete $total report${total == 1 ? '' : 's'} — Device 1 to Device $total.',
            style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        SectionCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('$done of $total devices done', style: heading(size: 16)),
              const Spacer(),
              if (done < total)
                TextButton(
                  onPressed: () => open([for (var i = 1; i <= total; i++) if (!d.unitQc.containsKey(i)) i].first),
                  child: const Text('Continue'),
                ),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 8, backgroundColor: AppColors.cardBorder, valueColor: const AlwaysStoppedAnimation(AppColors.mint)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          const gap = 10.0;
          final w = (c.maxWidth - gap) / 2;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (var i = 1; i <= total; i++)
              SizedBox(
                width: w,
                child: _DeviceCard(no: i, qc: d.unitQc[i], onTap: () => open(i)),
              ),
          ]);
        }),
        const SizedBox(height: 14),
        const NoteBanner('Buyers see each device’s QC before they buy, and customers see the first available device. Honest reports mean fewer returns.',
            icon: PhosphorIconsFill.sealCheck),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.no, required this.qc, required this.onTap});
  final int no;
  final UnitQc? qc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = qc != null;
    final issues = qc?.defects ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: done ? AppColors.mintSoft.withValues(alpha: 0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: done ? AppColors.mint : AppColors.cardBorder, width: done ? 1.5 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(done ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle, color: done ? AppColors.mint : AppColors.textMuted, size: 20),
            const SizedBox(width: 6),
            Text('Device $no', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
          const SizedBox(height: 8),
          Text(done ? (issues == 0 ? 'No issues' : '$issues issue${issues == 1 ? '' : 's'}') : 'QC pending',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: done ? (issues == 0 ? AppColors.mint : const Color(0xFFB45309)) : AppColors.textMuted)),
          if (done) Text('Battery ${qc!.battery}%', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(done ? 'Edit' : 'Start QC', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
        ]),
      ),
    );
  }
}
