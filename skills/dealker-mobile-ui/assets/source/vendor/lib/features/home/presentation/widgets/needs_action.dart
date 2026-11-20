import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/home/application/home_providers.dart';
import 'package:dealker_vendor/features/home/data/home_models.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';

class NeedsAction extends ConsumerStatefulWidget {
  const NeedsAction({super.key});

  @override
  ConsumerState<NeedsAction> createState() => _NeedsActionState();
}

class _NeedsActionState extends ConsumerState<NeedsAction> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final quotes = ref.watch(openRequirementsProvider);
    final sells = ref.watch(pendingSellRequestsProvider);
    final orders = ref.watch(newOrdersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeCard(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: SectionTitle(
                  title: 'Needs your action',
                  onViewAll: () => switch (_tab) {
                    0 => context.push(Routes.demand),
                    1 => context.push(Routes.sellLeads),
                    _ => context.push(Routes.orders),
                  },
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: AppColors.cardBorder))),
                child: Row(
                  children: [
                    for (final (i, label, n) in [
                      (0, 'Quotes', quotes),
                      (1, 'Sell phone', sells),
                      (2, 'Orders', orders),
                    ])
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _tab = i),
                          child: Container(
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: _tab == i
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      width: 2.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(label,
                                    style: heading(
                                        size: 13.5,
                                        color: _tab == i
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                        w: FontWeight.w700)),
                                if (_total(n) > 0) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: AppColors.rose,
                                        borderRadius: BorderRadius.circular(9)),
                                    child: Text('${_total(n)}',
                                        style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              switch (_tab) {
                0 => _quotesList(quotes),
                1 => _sellList(sells),
                _ => _ordersList(orders),
              },
            ],
          ),
        ),
      ],
    );
  }

  int _total(AsyncValue<Object?> v) {
    final d = v.asData?.value;
    return d is PagedTotal ? d.total : 0;
  }

  Widget _async<T>(AsyncValue<PagedTotal<T>> v, String empty,
      VoidCallback retry, List<Widget> Function(List<T>) rows) {
    return v.when(skipLoadingOnReload: true, skipError: true, 
      loading: () => const Padding(
          padding: EdgeInsets.only(top: 8), child: SkeletonBox(height: 150)),
      error: (e, _) => InlineError(
          message: e is Failure ? e.message : 'Could not load.',
          onRetry: retry),
      data: (d) =>
          d.items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                Image.asset('assets/3d/cart/empty_cart.png', height: 84),
                const SizedBox(height: 6),
                Text(empty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                ]),
              ),
            )
          : Column(children: rows(d.items)),
    );
  }

  Widget _quotesList(AsyncValue<PagedTotal<B2bRequirementRow>> v) => _async(
        v,
        'No open bulk requests right now.',
        () => ref.invalidate(openRequirementsProvider),
        (rows) => [
          for (final r in rows)
            ActionRow(
              icon: PhosphorIconsFill.cube,
              asset: 'assets/3d/new/cartons.png',
              title: 'Bulk Request',
              subtitle: r.productName,
              meta: [
                (PhosphorIconsRegular.package, '${r.quantity} units'),
                if (r.city.isNotEmpty) (PhosphorIconsRegular.mapPin, r.city),
              ],
              ago: timeAgo(r.createdAt),
              chip: ('New', ChipTone.violet),
              button: 'Review',
              onTap: () => context.push(Routes.demandView(r.id)),
            ),
        ],
      );

  Widget _sellList(AsyncValue<PagedTotal<SellRequestRow>> v) => _async(
        v,
        'No pending sell-phone requests.',
        () => ref.invalidate(pendingSellRequestsProvider),
        (rows) => [
          for (final r in rows)
            ActionRow(
              icon: PhosphorIconsFill.deviceMobile,
              asset: 'assets/3d/profile/sellPhone.png',
              imageUrl: r.imageUrl,
              iconColor: AppColors.mint,
              title: 'Sell phone',
              subtitle: r.model,
              meta: [
                if (r.condition.isNotEmpty)
                  (PhosphorIconsRegular.sealCheck, r.condition),
                if (r.expectedPrice != null)
                  (
                    PhosphorIconsRegular.currencyInr,
                    '${formatInr(r.expectedPrice!)} expected'
                  ),
              ],
              ago: timeAgo(r.createdAt),
              chip: ('Pending', ChipTone.amber),
              button: 'Review',
              onTap: () => context.push(Routes.sellLeadView(r.id)),
            ),
        ],
      );

  Widget _ordersList(AsyncValue<PagedTotal<SellerOrderRow>> v) => _async(
        v,
        'No new orders to confirm.',
        () => ref.invalidate(newOrdersProvider),
        (rows) => [
          for (final r in rows)
            ActionRow(
              icon: PhosphorIconsFill.truck,
              asset: 'assets/3d/cart/van.png',
              title: 'Order #${r.number}',
              subtitle: '${r.itemCount} item${r.itemCount == 1 ? '' : 's'}',
              meta: const [],
              ago: timeAgo(r.createdAt),
              chip: ('New', ChipTone.violet),
              button: 'Review',
              onTap: () => context.push(Routes.orderDetail(r.id)),
            ),
        ],
      );
}

enum ChipTone { violet, mint, amber }

class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.icon,
    this.iconColor = AppColors.violet,
    this.asset,
    this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.ago,
    required this.chip,
    required this.button,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String? asset;
  final String? imageUrl; // a real photo wins over the 3D icon
  final String title;
  final String subtitle;
  final List<(IconData, String)> meta;
  final String ago;
  final (String, ChipTone) chip;
  final String button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (chipText, tone) = chip;
    final (chipFg, chipBg) = switch (tone) {
      ChipTone.violet => (AppColors.primary, const Color(0xFFE5EEFF)),
      ChipTone.mint => (AppColors.mint, AppColors.mintSoft),
      ChipTone.amber => (const Color(0xFFD97706), AppColors.amberSoft),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: const Color(0xFFF7F9FE),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder)),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: iconColor.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 160, // shown ~50px: don't decode a full-size photo
                              fadeInDuration: const Duration(milliseconds: 120),
                              placeholder: (_, __) => const SizedBox.shrink(),
                              errorWidget: (_, __, ___) => asset != null
                                  ? Image.asset(asset!, fit: BoxFit.contain)
                                  : Icon(icon, color: iconColor, size: 26)),
                        )
                      : asset != null
                          ? Image.asset(asset!, fit: BoxFit.contain)
                          : Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(7)),
                          child: Text(chipText,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: chipFg)),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                        ),
                      ]),
                      const SizedBox(height: 5),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: heading(size: 14.5, w: FontWeight.w800)),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Wrap(spacing: 10, runSpacing: 2, children: [
                          for (final m in meta)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(m.$1, size: 13, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Text(m.$2,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary)),
                            ]),
                        ]),
                      ],
                      if (ago.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(ago,
                              style: const TextStyle(
                                  fontSize: 10.5, color: AppColors.textMuted)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF5B4BEA)]),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(button,
                      style: heading(
                          size: 12.5, color: Colors.white, w: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
