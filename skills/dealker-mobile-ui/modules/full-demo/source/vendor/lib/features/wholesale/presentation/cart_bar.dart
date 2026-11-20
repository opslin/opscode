import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/features/wholesale/application/cart_provider.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// Sticky "N items · ₹total — View cart" bar. Shows only while the cart has something in it.
class CartBar extends ConsumerWidget {
  const CartBar({super.key, this.safeBottom = true});
  final bool safeBottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(wholesaleCartProvider);
    if (lines.isEmpty) return const SizedBox.shrink();
    final total = lines.fold<num>(0, (s, l) => s + l.total);
    final units = lines.fold<int>(0, (s, l) => s + l.qty);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        bottom: safeBottom,
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      '${lines.length} item${lines.length == 1 ? '' : 's'} · $units units',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  Text(formatInr(total),
                      style: heading(size: 18, w: FontWeight.w800)),
                ]),
          ),
          GestureDetector(
            onTap: () => context.push(Routes.wholesaleCart),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(13)),
              child: Row(children: [
                Text('View cart',
                    style: heading(
                        size: 14, color: Colors.white, w: FontWeight.w700)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded,
                    size: 18, color: Colors.white),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
