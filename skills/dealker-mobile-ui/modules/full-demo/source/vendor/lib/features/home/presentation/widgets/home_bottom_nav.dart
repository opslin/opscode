import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// Bar tabs: home, products, marketplace, auction, repair. `campaigns` and `profile` are screens that
/// keep the bar (nothing highlighted) but are reached from Home (Quick actions / header).
enum NavTab { home, products, marketplace, auction, repair, campaigns, profile }

class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({super.key, this.current = NavTab.home});

  final NavTab current;

  static const _tabs = [
    (NavTab.home, PhosphorIconsFill.house, PhosphorIconsRegular.house, 'Home'),
    (
      NavTab.products,
      PhosphorIconsFill.cube,
      PhosphorIconsRegular.cube,
      'Products'
    ),
    (
      NavTab.marketplace,
      PhosphorIconsFill.storefront,
      PhosphorIconsRegular.storefront,
      'Marketplace'
    ),
    (
      NavTab.auction,
      PhosphorIconsFill.gavel,
      PhosphorIconsRegular.gavel,
      'Auction'
    ),
    (
      NavTab.repair,
      PhosphorIconsFill.wrench,
      PhosphorIconsRegular.wrench,
      'Repair'
    ),
  ];

  void _open(BuildContext context, NavTab tab, String label) {
    if (tab == current) return;
    switch (tab) {
      case NavTab.home:
        context.go(Routes.home);
      case NavTab.products:
        context.go(Routes.products);
      case NavTab.marketplace:
        context.go(Routes.wholesale);
      case NavTab.auction:
        context.go(Routes.auctions);
      case NavTab.repair:
        context.go(Routes.repairs);
      case NavTab.campaigns:
      case NavTab.profile:
        break; // not bar tabs
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.cardBorder)),
        boxShadow: [
          BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Row(
            children: [
              for (final (tab, filled, regular, label) in _tabs)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _open(context, tab, label),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tab == current ? filled : regular,
                            size: 25,
                            color: tab == current
                                ? AppColors.violet
                                : AppColors.textSecondary),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                                fontSize: 9.5,
                                color: tab == current
                                    ? AppColors.violet
                                    : AppColors.textSecondary,
                                fontWeight: tab == current
                                    ? FontWeight.w700
                                    : FontWeight.w500),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                            width: 38,
                            height: 2.5,
                            color: tab == current
                                ? AppColors.violet
                                : Colors.transparent),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
