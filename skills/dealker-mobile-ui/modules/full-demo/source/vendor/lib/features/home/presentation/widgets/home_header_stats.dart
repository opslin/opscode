import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';
import 'package:dealker_vendor/features/home/application/home_providers.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/features/profile/application/profile_providers.dart';
import 'package:dealker_vendor/features/subscription/application/subscription_providers.dart';
import 'package:dealker_vendor/features/wholesale/application/cart_provider.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/dm_logo.dart';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning,';
  if (h < 17) return 'Good afternoon,';
  return 'Good evening,';
}

/// Blue → violet band: greeting, inbox icons and the stats card.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    final info = ref.watch(vendorInfoProvider).asData?.value;
    final business = (info?.name ?? '').trim().isNotEmpty
        ? info!.name.trim()
        : (session?.name?.trim().isNotEmpty == true
            ? session!.name!.trim()
            : 'Partner Hub');
    // Cart = wholesale lines + auction lots won and not yet paid.
    final int a = ref.watch(cartCountProvider);
    final int b = ref.watch(cartWinsCountProvider);
    final cartCount = a + b;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.paddingOf(context).top + 12, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF5B4BEA)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                // Long-press the store tile to log out (kept from the old header).
                onLongPress: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                onTap: () => context.go(Routes.profile),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))
                    ],
                  ),
                  child: const DmLogo(size: 42),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(),
                        style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: business),
                        if (info?.verified == true)
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Icon(PhosphorIconsFill.sealCheck,
                                  size: 17, color: Colors.white),
                            ),
                          ),
                      ]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: heading(
                          size: business.length > 18 ? 17 : 19,
                          color: Colors.white,
                          w: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              _HeaderIcon(
                icon: PhosphorIconsRegular.shoppingCart,
                count: cartCount,
                onTap: () async {
                  await context.push(Routes.wholesaleCart);
                  ref
                    ..invalidate(wonLotsToPayProvider)
                    ..invalidate(wonLotIdsProvider);
                },
              ),
              const SizedBox(width: 4),
              _ProfileButton(
                  logoUrl: ref.watch(growthProvider).asData?.value.logoUrl,
                  initial: business.isEmpty ? 'D' : business[0].toUpperCase(),
                  onTap: () => context.go(Routes.profile)),
            ],
          ),
          const SizedBox(height: 16),
          const StatsRow(),
        ],
      ),
    );
  }
}

/// Square glass button for the header: the icon is centred in a 44px tile and the count sits on its
/// top-right corner as a white-ringed pill, so nothing overlaps or drifts off-centre.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon(
      {required this.icon, required this.count, required this.onTap});
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.only(top: 4, right: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 23, color: Colors.white),
              ),
            ),
            if (count > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.rose,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3B5BE8), width: 2),
                  ),
                  child: Text(count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
          ]),
        ),
      );
}

/// Round profile button: the business initial on a white disc.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton(
      {required this.initial, required this.onTap, this.logoUrl});
  final String initial;
  final VoidCallback onTap;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: (logoUrl ?? '').isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: logoUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  memCacheWidth: 132,
                  fadeInDuration: const Duration(milliseconds: 120),
                  placeholder: (_, __) => Text(initial,
                      style: heading(size: 18, color: AppColors.primary, w: FontWeight.w800)),
                  errorWidget: (_, __, ___) => Text(initial,
                      style: heading(size: 18, color: AppColors.primary, w: FontWeight.w800)))
              : Text(initial,
                  style: heading(size: 18, color: AppColors.primary, w: FontWeight.w800)),
        ),
      );
}

class StatsRow extends ConsumerWidget {
  const StatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(allOrdersProvider);
    final live = ref.watch(auctionStatsProvider);
    final quoted = ref.watch(quotedRequirementsProvider);
    final wallet = ref.watch(walletSummaryProvider);

    return HomeCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _stat(
              icon: PhosphorIconsFill.cube,
              color: AppColors.primary,
              label: 'Orders',
              value: orders.whenOrNull(data: (d) => '${d.total}'),
              failed: orders.hasError,
              onTap: () => context.push(Routes.orders),
            ),
            _divider(),
            _stat(
              icon: PhosphorIconsFill.gavel,
              color: const Color(0xFFF08A1C),
              label: 'Live lots',
              value: live.whenOrNull(data: (d) => '${d.live}'),
              failed: live.hasError,
              onTap: () => context.go(Routes.auctions),
            ),
            _divider(),
            _stat(
              icon: PhosphorIconsFill.clipboardText,
              color: AppColors.violet,
              label: 'Quotes',
              value: quoted.whenOrNull(data: (d) => '${d.total}'),
              failed: quoted.hasError,
              onTap: () => context.push(Routes.demand),
            ),
            _divider(),
            _stat(
              icon: PhosphorIconsFill.wallet,
              color: AppColors.mint,
              label: 'Earnings',
              value: wallet.whenOrNull(data: (d) => formatInr(d.available)),
              failed: wallet.hasError,
              onTap: () => context.push(Routes.wallet),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, color: AppColors.cardBorder);

  Widget _stat({
    required IconData icon,
    required Color color,
    required String label,
    required String? value,
    required bool failed,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 5),
                SizedBox(
                  height: 26,
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value ?? (failed ? '—' : '···'),
                        style: heading(size: 21, w: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
}
