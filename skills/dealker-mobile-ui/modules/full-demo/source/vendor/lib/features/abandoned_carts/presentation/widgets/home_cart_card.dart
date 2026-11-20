import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/abandoned_carts/application/cart_providers.dart';
import 'package:dealker_vendor/features/abandoned_carts/data/cart_models.dart';
import 'package:dealker_vendor/features/abandoned_carts/presentation/widgets/cart_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// Home shortcut: how many shoppers left this vendor's products behind, and their value.
/// Stays quiet (no card) when the call fails — it must never break the home screen.
class HomeCartCard extends ConsumerWidget {
  const HomeCartCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(cartSummaryProvider(CartChannel.all));
    final data = s.asData?.value;
    if (s.hasError && data == null) return const SizedBox.shrink();

    final open = data?.openCarts ?? 0;
    final loading = data == null;
    return GestureDetector(
      onTap: () => context.push(Routes.abandonedCarts),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD9AE)),
        ),
        child: Row(children: [
          const Icon(PhosphorIconsFill.shoppingCart,
              color: Color(0xFFF08A1C), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Abandoned carts', style: heading(size: 15.5)),
              const SizedBox(height: 3),
              Text(
                  loading
                      ? 'Checking…'
                      : open == 0
                          ? 'No one is waiting right now'
                          : '$open ${open == 1 ? 'cart needs' : 'carts need'} follow-up · ${formatInr(data.pendingValue)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xFFF08A1C),
                borderRadius: BorderRadius.circular(11)),
            child: Text(open > 0 ? 'View all' : 'Open',
                style: heading(
                    size: 12.5, color: Colors.white, w: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}
