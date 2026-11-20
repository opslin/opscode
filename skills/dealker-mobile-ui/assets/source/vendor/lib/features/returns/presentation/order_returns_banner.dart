import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/returns/application/returns_providers.dart';
import 'package:dealker_vendor/features/returns/data/return_models.dart';
import 'package:dealker_vendor/features/returns/presentation/returns_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// On the vendor's order screen: one tappable card per return the customer raised on this parcel.
/// Renders nothing while loading, on error, or when there is no return (the order screen never waits on it).
class OrderReturnsBanner extends ConsumerWidget {
  const OrderReturnsBanner({super.key, required this.sellerOrderId});
  final String sellerOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(orderReturnsProvider(sellerOrderId)).asData?.value ?? const <ReturnRow>[];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push(Routes.returnDetail(r.id)),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: stageColors(r.stage).bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Icon(PhosphorIconsFill.arrowUUpLeft, color: stageColors(r.stage).fg, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        r.stage == ReturnStage.needsResponse
                            ? 'Customer asked to return this order'
                            : 'Return ${r.returnNumber}',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: stageColors(r.stage).fg)),
                    const SizedBox(height: 2),
                    Text(r.stage.label,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  ]),
                ),
                Icon(PhosphorIconsRegular.caretRight, color: stageColors(r.stage).fg),
              ]),
            ),
          ),
        ),
    ]);
  }
}
