import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/data/product_catalog.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';

/// Step 3 — the vendor's physical self-check. Answers start at the best value
/// (as in the design) and every row can be changed; the vendor confirms them.
class ChecklistStep extends ConsumerWidget {
  const ChecklistStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(addDraftProvider);
    final n = ref.read(addDraftProvider.notifier);
    final items = checklistFor(d.type);
    String value(QcItem i) => d.checklist[i.label] ?? i.best;
    final issues = items.where((i) => value(i) != i.best).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        Text('Physical Check', style: heading(size: 19)),
        const SizedBox(height: 4),
        const Text(
            'Check the device in your hand and set each answer honestly. Tap a row to change it.',
            style: TextStyle(
                fontSize: 13.5, height: 1.35, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        SectionCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (final (i, it) in items.indexed) ...[
              _Row(
                item: it,
                value: value(it),
                onTap: () async {
                  final v = await pickOption(context,
                      title: it.label,
                      options: it.options,
                      selected: value(it));
                  if (v != null) n.answer(it.label, v);
                },
              ),
              if (i != items.length - 1)
                const Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: AppColors.cardBorder),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        if (issues > 0)
          NoteBanner.warning(
              '$issues item${issues == 1 ? '' : 's'} not perfect. That’s fine — honest listings get approved faster and see fewer returns.')
        else
          const NoteBanner(
              'Everything checks out. Your answers are saved with the product and shown to Dealkr’s reviewers.',
              icon: PhosphorIconsFill.sealCheck),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => n.set(
              (x) => x.copyWith(checklistConfirmed: !x.checklistConfirmed)),
          behavior: HitTestBehavior.opaque,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(
                d.checklistConfirmed
                    ? PhosphorIconsFill.checkSquare
                    : PhosphorIconsRegular.square,
                size: 26,
                color: d.checklistConfirmed ? kBlue : AppColors.borderStrong),
            const SizedBox(width: 10),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                    'I have physically checked this product and the details above are accurate.',
                    style: TextStyle(
                        fontSize: 14, height: 1.4, color: AppColors.navy)),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.value, required this.onTap});
  final QcItem item;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final good = value == item.best;
    final bad = item.options.length > 2 && value == item.options.last;
    final color = good
        ? AppColors.mint
        : (bad ? AppColors.rose : const Color(0xFFB45309));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(children: [
          Icon(
              good
                  ? PhosphorIconsFill.checkCircle
                  : PhosphorIconsFill.warningCircle,
              size: 22,
              color: color),
          const SizedBox(width: 12),
          Expanded(
              child: Text(item.label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy))),
          Text(value,
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 4),
          const Icon(PhosphorIconsRegular.caretRight,
              size: 16, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}
