import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/features/auth/application/auth_controller.dart';
import 'package:dealker_vendor/features/home/application/home_providers.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_bottom_nav.dart';
import 'package:dealker_vendor/features/profile/application/profile_providers.dart';
import 'package:dealker_vendor/features/returns/application/returns_providers.dart';
import 'package:dealker_vendor/features/profile/presentation/profile_widgets.dart';
import 'package:dealker_vendor/features/subscription/application/shop_photo.dart';
import 'package:dealker_vendor/features/subscription/application/subscription_providers.dart';
import 'package:dealker_vendor/features/subscription/data/subscription_repository.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/dm_logo.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _preferencesKey = GlobalKey();

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Log out?'),
        content: const Text(
            'You will need to verify your phone number to sign in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Stay')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              'Log out',
              style: TextStyle(color: ProfileColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  void _scrollToPreferences() {
    final target = _preferencesKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  String? _text<T>(AsyncValue<T> value, String Function(T) format) =>
      value.hasValue ? format(value.requireValue) : null;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    if (session != null && !session.hasVendorAccess) return const _NotLinked();

    final info = ref.watch(vendorInfoProvider);
    final membership = ref.watch(membershipProvider);
    final growth = ref.watch(growthProvider);
    final listings = ref.watch(listingCountsProvider);
    final orders = ref.watch(allOrdersProvider);
    final newOrders = ref.watch(newOrdersProvider);
    final wallet = ref.watch(walletSummaryProvider);

    final sessionName = session?.name?.trim();
    final name = (info.value?.name.trim().isNotEmpty ?? false)
        ? info.value!.name.trim()
        : (sessionName?.isNotEmpty == true ? sessionName! : 'Your business');
    final owner = (sessionName != null &&
            sessionName.isNotEmpty &&
            sessionName.toLowerCase() != name.toLowerCase())
        ? sessionName
        : null;
    final tier = membership.value?.tier ?? 'FREE';
    final verified = info.value?.verified ?? false;
    final incomplete = info.hasValue && !info.value!.profileComplete;
    final newCount = newOrders.value?.total ?? 0;
    final returnsNeedAnswer = ref.watch(returnsSummaryProvider).value?.needsResponse ?? 0;

    final walletValue = wallet.value;
    final stats = [
      ProfileStat(
        label: 'Orders',
        value: _text(orders, (d) => '${d.total}') ?? '—',
      ),
      ProfileStat(
        label: 'Live',
        value: _text(listings, (d) => '${d.live}') ?? '—',
      ),
      ProfileStat(
        label: 'Earnings',
        value:
            walletValue == null ? '—' : formatCompactInr(walletValue.available),
      ),
      ProfileStat(
        label: 'Paid out',
        value: walletValue == null ? '—' : formatCompactInr(walletValue.paid),
      ),
    ];

    return Scaffold(
      backgroundColor: ProfileColors.canvas,
      bottomNavigationBar: const HomeBottomNav(current: NavTab.profile),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: ProfileColors.accent,
          onRefresh: () async => refreshProfile(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    'Profile',
                    style: ProfileText.heading(
                      size: 28,
                      weight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                _HeaderAction(
                  icon: PhosphorIconsRegular.bell,
                  tooltip: 'New orders',
                  showDot: newCount > 0,
                  onTap: () => context.push('${Routes.orders}?tab=new'),
                ),
                _HeaderAction(
                  icon: PhosphorIconsRegular.gear,
                  tooltip: 'Preferences',
                  onTap: _scrollToPreferences,
                ),
              ]),
              const SizedBox(height: 14),
              IdentityCard(
                name: name,
                owner: owner,
                verified: verified,
                tier: tier,
                logoUrl: growth.asData?.value.logoUrl,
                onPhoto: () => changeShopPhoto(context, ref),
                onEdit: () => context.push(Routes.businessProfile),
              ),
              const SizedBox(height: 12),
              _FollowersCard(growth: growth.asData?.value),
              if (incomplete) ...[
                const SizedBox(height: 12),
                CompleteProfileCard(
                  onTap: () => context.push(Routes.businessProfile),
                ),
              ],
              const SizedBox(height: 14),
              ProfileStatStrip(stats: stats),
              const SizedBox(height: 14),
              MembershipSummaryCard(
                plan: membership.value,
                onDetails: () => context.push(Routes.subscription),
                onRetry: () => ref.invalidate(membershipProvider),
              ),
              const SizedBox(height: 24),
              const ProfileSectionLabel('Business'),
              ProfileGroup(items: [
                ProfileItem(
                  icon: PhosphorIconsRegular.storefront,
                  title: 'Business profile',
                  subtitle: 'Store details, address and policies',
                  onTap: () => context.push(Routes.businessProfile),
                ),
                ProfileItem(
                  icon: PhosphorIconsRegular.shieldCheck,
                  title: 'KYC documents',
                  subtitle: 'PAN, GSTIN and trade licence',
                  onTap: () => context.push(Routes.businessProfile),
                ),
                ProfileItem(
                  icon: PhosphorIconsRegular.slidersHorizontal,
                  title: 'Store settings',
                  subtitle: 'Hours, pickup and auto-accept',
                  onTap: () => context.push(Routes.storeSettings),
                ),
              ]),
              const SizedBox(height: 24),
              const ProfileSectionLabel('Operations'),
              ProfileGroup(items: [
                ProfileItem(
                  icon: PhosphorIconsRegular.package,
                  title: 'Orders',
                  meta: newCount > 0 ? '$newCount new' : null,
                  onTap: () => context.push(Routes.orders),
                ),
                ProfileItem(
                  icon: PhosphorIconsRegular.arrowUUpLeft,
                  title: 'Returns',
                  meta: returnsNeedAnswer > 0 ? '$returnsNeedAnswer need answer' : null,
                  onTap: () => context.push(Routes.returns),
                ),
                ProfileItem(
                  icon: PhosphorIconsRegular.shoppingBag,
                  title: 'My orders',
                  onTap: () => context.push(Routes.myOrders),
                ),
                ProfileItem(
                  icon: PhosphorIconsRegular.cube,
                  title: 'Products',
                  onTap: () => context.go(Routes.products),
                ),
                ProfileItem(
                  icon: PhosphorIconsRegular.receipt,
                  title: 'Payouts',
                  onTap: () => context.push(Routes.payouts),
                ),
                ProfileItem(
                  icon: PhosphorIconsRegular.wallet,
                  title: 'Wallet',
                  onTap: () => context.push(Routes.wallet),
                ),
              ]),
              const SizedBox(height: 24),
              const ProfileSectionLabel('Growth'),
              ProfileGroup(items: [
                ProfileItem(
                  icon: PhosphorIconsRegular.megaphone,
                  title: 'Campaigns',
                  onTap: () => context.go(Routes.campaigns),
                ),
                ProfileItem(
                  icon: PhosphorIconsRegular.gavel,
                  title: 'Auctions',
                  onTap: () => context.go(Routes.auctions),
                ),
                ProfileItem(
                  icon: PhosphorIconsRegular.usersThree,
                  title: 'Demand & wholesale',
                  onTap: () => context.push(Routes.demand),
                ),
                ProfileItem(
                  icon: PhosphorIconsRegular.wrench,
                  title: 'Repairs',
                  onTap: () => context.push(Routes.repairs),
                ),
              ]),
              const SizedBox(height: 24),
              KeyedSubtree(
                key: _preferencesKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ProfileSectionLabel('Preferences'),
                    ProfileGroup(items: [
                      ProfileItem(
                        icon: PhosphorIconsRegular.bell,
                        title: 'Notifications',
                        subtitle: 'Orders, payments and support replies',
                        onTap: () => context.push(Routes.notifications),
                      ),
                      ProfileItem(
                        icon: PhosphorIconsRegular.headset,
                        title: 'Help & support',
                        subtitle: 'Chat, call and quick answers',
                        onTap: () => context.push(Routes.help),
                      ),
                      ProfileItem(
                        icon: PhosphorIconsRegular.gear,
                        title: 'Settings',
                        subtitle: 'Subscription, shop photo and business',
                        onTap: () => context.push(Routes.settings),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _logout,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    foregroundColor: ProfileColors.danger,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(PhosphorIconsRegular.signOut, size: 18),
                  label: Text(
                    'Log out',
                    style: ProfileText.body(
                      size: 14,
                      color: ProfileColors.danger,
                      weight: FontWeight.w600,
                    ),
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

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool showDot;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              onPressed: onTap,
              tooltip: tooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: Icon(icon, size: 21, color: ProfileColors.ink),
            ),
            if (showDot)
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: ProfileColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      );
}

class _NotLinked extends ConsumerWidget {
  const _NotLinked();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        backgroundColor: ProfileColors.canvas,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DmLogo(size: 64),
                  const SizedBox(height: 22),
                  Text(
                    'Number verified',
                    textAlign: TextAlign.center,
                    style: ProfileText.heading(
                      size: 24,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your phone is verified, but it is not linked to an approved vendor account yet. Vendor onboarding and KYC will be connected next.',
                    textAlign: TextAlign.center,
                    style: ProfileText.body(size: 14, height: 1.5),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () =>
                          ref.read(authControllerProvider.notifier).logout(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ProfileColors.ink,
                        side: const BorderSide(color: ProfileColors.line),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Log out',
                        style: ProfileText.body(
                          size: 14,
                          color: ProfileColors.ink,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// How many customers follow the shop, and how many joined recently.
class _FollowersCard extends StatelessWidget {
  const _FollowersCard({required this.growth});
  final Growth? growth;

  @override
  Widget build(BuildContext context) {
    final g = growth;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: profileCardDecoration(radius: 20),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: const Color(0xFFFFEEF3), borderRadius: BorderRadius.circular(13)),
          child: const Icon(PhosphorIconsFill.heart, color: Color(0xFFE5484D), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g == null ? '—' : '${g.followers}',
                style: ProfileText.heading(
                    size: 22, weight: FontWeight.w800, color: ProfileColors.ink, height: 1.1)),
            const SizedBox(height: 2),
            Text('Followers',
                style: ProfileText.body(size: 12, color: ProfileColors.muted)),
          ]),
        ),
        if (g != null)
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('+${g.thisWeek} this week',
                style: ProfileText.body(
                    size: 12.5, color: const Color(0xFF16A34A), weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('+${g.thisMonth} this month',
                style: ProfileText.body(size: 11.5, color: ProfileColors.muted)),
          ]),
      ]),
    );
  }
}
