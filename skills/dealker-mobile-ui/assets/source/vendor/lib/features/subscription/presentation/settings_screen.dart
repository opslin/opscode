import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show heading;
import 'package:dealker_vendor/features/profile/application/profile_providers.dart';
import 'package:dealker_vendor/features/subscription/application/shop_photo.dart';
import 'package:dealker_vendor/features/subscription/application/subscription_providers.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// Profile → Settings: subscription, shop photo and business details in one place.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(membershipProvider).asData?.value;
    final g = ref.watch(growthProvider).asData?.value;
    final plan = (m?.planName.isNotEmpty ?? false) ? m!.planName : 'Free';
    final days = m?.daysLeft;
    final subLine = (m == null || m.tier == 'FREE')
        ? 'Free plan · upgrade for more listings'
        : '$plan${days == null ? '' : ' · $days day${days == 1 ? '' : 's'} left'}';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft, color: AppColors.navy),
            onPressed: () => context.pop()),
        title: Text('Settings', style: heading(size: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Row(
            icon: PhosphorIconsFill.crown,
            color: const Color(0xFF7C3AED),
            title: 'Subscription',
            subtitle: subLine,
            onTap: () => context.push(Routes.subscription),
          ),
          _Row(
            icon: PhosphorIconsFill.camera,
            color: AppColors.primary,
            title: 'Shop photo',
            subtitle: (g?.logoUrl == null) ? 'Add your shop profile picture' : 'Change your shop profile picture',
            onTap: () => changeShopPhoto(context, ref),
          ),
          _Row(
            icon: PhosphorIconsFill.storefront,
            color: const Color(0xFF0E7490),
            title: 'Business profile',
            subtitle: 'Store details and address',
            onTap: () => context.push(Routes.businessProfile),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder)),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
          subtitle: Text(subtitle,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          trailing: const Icon(PhosphorIconsRegular.caretRight, size: 18, color: AppColors.textMuted),
        ),
      );
}
