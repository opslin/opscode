import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/demand/application/demand_providers.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/demand_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// Home banner: live buying requirements, on the brand artwork.
class DemandBanner extends ConsumerWidget {
  const DemandBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(demandSummaryProvider).asData?.value;
    final line = s == null
        ? 'Bulk order · Better price · More profit'
        : [
            '${s.open} open',
            if (s.matched > 0) '${s.matched} match your stock',
            if (s.urgent > 0) '${s.urgent} urgent',
          ].join('  ·  ');
    final fresh = s?.newCount ?? 0;

    return GestureDetector(
      onTap: () async {
        await context.push(Routes.demand);
        ref.invalidate(demandSummaryProvider);
      },
      child: Container(
        height: 176,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/banners/banner_demand.jpg',
                fit: BoxFit.cover, alignment: Alignment.centerRight),
            // keeps the copy readable over the artwork
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0, 0.55, 1],
                  colors: [
                    Color(0xE6001F5F),
                    Color(0x80001F5F),
                    Color(0x00001F5F)
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.amber.withValues(alpha: 0.6))),
                    child: Text(
                      fresh > 0
                          ? '$fresh NEW REQUIREMENT${fresh == 1 ? '' : 'S'}'
                          : 'BUYING REQUIREMENTS',
                      style: const TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w800,
                          color: AppColors.amber),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text('Buyers are\nasking for stock',
                      style: heading(
                          size: 21, color: Colors.white, w: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.82))),
                  const Spacer(),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                          color: AppColors.amber,
                          borderRadius: BorderRadius.circular(11)),
                      child: const Text('View demand',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.push(Routes.wholesale),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.65))),
                        child: const Text('Marketplace',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
