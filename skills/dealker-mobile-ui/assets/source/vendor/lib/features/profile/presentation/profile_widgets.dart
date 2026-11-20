import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/core/theme/app_theme.dart';
import 'package:dealker_vendor/features/profile/data/profile_models.dart';

/// Profile page palette: one ink, one accent, flat surfaces.
class ProfileColors {
  ProfileColors._();

  static const canvas = Color(0xFFF7F8FA);
  static const surface = Colors.white;
  static const ink = Color(0xFF0B1220);
  static const muted = Color(0xFF6B7280);
  static const faint = Color(0xFF9CA3AF);
  static const line = Color(0xFFE9EDF3);
  static const accent = AppColors.violet;
  static const accentSoft = AppColors.violetSoft;
  static const danger = Color(0xFFD92D20);
  static const warning = Color(0xFFB45309);
  static const gold = Color(0xFF8A5A00);
  static const goldBorder = Color(0xFFE7C873);
  static const goldSoft = Color(0xFFFFF8E8);
}

class ProfileText {
  ProfileText._();

  static TextStyle heading({
    double size = 16,
    FontWeight weight = FontWeight.w700,
    Color color = ProfileColors.ink,
    double height = 1.2,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: AppTheme.headingFont,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle body({
    double size = 12.5,
    Color color = ProfileColors.muted,
    FontWeight weight = FontWeight.w400,
    double height = 1.35,
  }) =>
      TextStyle(
        fontFamily: AppTheme.bodyFont,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );
}

BoxDecoration profileCardDecoration({double radius = 18}) => BoxDecoration(
      color: ProfileColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: ProfileColors.line),
    );

String formatCompactInr(num value) {
  final negative = value < 0;
  final v = value.abs().toDouble();
  String trim(String s) => s.replaceFirst(RegExp(r'\.?0+$'), '');
  final String body;
  if (v >= 10000000) {
    body = '₹${trim((v / 10000000).toStringAsFixed(2))}Cr';
  } else if (v >= 100000) {
    body = '₹${trim((v / 100000).toStringAsFixed(2))}L';
  } else if (v >= 1000) {
    body = '₹${trim((v / 1000).toStringAsFixed(1))}K';
  } else {
    body = '₹${v.toStringAsFixed(0)}';
  }
  return negative ? '-$body' : body;
}

/// Flat, typographic plan badge. No crown, no shield, no gradient.
class PlanBadge extends StatelessWidget {
  const PlanBadge({super.key, required this.tier});

  final String tier;

  @override
  Widget build(BuildContext context) {
    final t = tier.toUpperCase();
    final (label, foreground, background, border) = switch (t) {
      'PAID' => (
          'PRO',
          ProfileColors.accent,
          ProfileColors.accentSoft,
          ProfileColors.accent.withValues(alpha: 0.24),
        ),
      'PREMIUM' => (
          'PREMIUM',
          ProfileColors.gold,
          ProfileColors.goldSoft,
          ProfileColors.goldBorder,
        ),
      'UNLIMITED' => (
          'UNLIMITED',
          Colors.white,
          ProfileColors.ink,
          ProfileColors.ink,
        ),
      _ => (
          'FREE',
          ProfileColors.muted,
          Colors.transparent,
          ProfileColors.line,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: ProfileText.heading(
          size: 9.5,
          weight: FontWeight.w800,
          color: foreground,
          height: 1,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.verified,
    this.size = 64,
    this.imageUrl,
    this.onPhoto,
  });

  final String name;
  final bool verified;
  final double size;

  /// Shop profile photo; the initials show until one is set.
  final String? imageUrl;

  /// Tap target on the small camera badge — change the shop photo.
  final VoidCallback? onPhoto;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.toList();
    return (list.first[0] +
            (list.length > 1
                ? list[1][0]
                : (list.first.length > 1 ? list.first[1] : '')))
        .toUpperCase();
  }

  Widget _initialsText() => Text(
        _initials,
        style: ProfileText.heading(
          size: size * 0.31,
          weight: FontWeight.w800,
          color: ProfileColors.ink,
          height: 1,
        ),
      );

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF1F3F7),
              border: Border.all(color: ProfileColors.line),
            ),
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            child: (imageUrl ?? '').isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    memCacheWidth: (size * 3).round(),
                    fadeInDuration: const Duration(milliseconds: 120),
                    placeholder: (_, __) => _initialsText(),
                    errorWidget: (_, __, ___) => _initialsText())
                : _initialsText(),
          ),
          if (onPhoto != null)
            Positioned(
              left: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: onPhoto,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: ProfileColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: ProfileColors.surface, width: 2),
                  ),
                  child: Icon(PhosphorIconsFill.camera,
                      size: size * 0.2, color: Colors.white),
                ),
              ),
            ),
          if (verified)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: ProfileColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIconsFill.sealCheck,
                  size: size * 0.30,
                  color: ProfileColors.accent,
                ),
              ),
            ),
        ]),
      );
}

class ProfileStat {
  const ProfileStat({required this.label, required this.value});

  final String label;
  final String? value;
}

class ProfileStatStrip extends StatelessWidget {
  const ProfileStatStrip({super.key, required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) => Container(
        decoration: profileCardDecoration(),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: ProfileColors.line,
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            stats[i].value ?? '—',
                            maxLines: 1,
                            style: ProfileText.heading(
                              size: 17,
                              weight: FontWeight.w800,
                              color: stats[i].value == null
                                  ? ProfileColors.muted
                                  : ProfileColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            stats[i].label,
                            maxLines: 1,
                            style: ProfileText.body(
                              size: 10.5,
                              color: ProfileColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class ProfileSectionLabel extends StatelessWidget {
  const ProfileSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: ProfileText.body(
            size: 10.5,
            color: ProfileColors.faint,
            weight: FontWeight.w700,
          ).copyWith(letterSpacing: 1.1),
        ),
      );
}

class ProfileItem {
  const ProfileItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.meta,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? meta;
  final VoidCallback? onTap;
}

class ProfileGroup extends StatelessWidget {
  const ProfileGroup({super.key, required this.items});

  final List<ProfileItem> items;

  @override
  Widget build(BuildContext context) => Container(
        decoration: profileCardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _ProfileRow(item: items[i]),
                if (i < items.length - 1)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.only(left: 50),
                    color: ProfileColors.line,
                  ),
              ],
            ],
          ),
        ),
      );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.item});

  final ProfileItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        child: Row(children: [
          Icon(
            item.icon,
            size: 20,
            color: ProfileColors.ink,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ProfileText.body(
                    size: 14,
                    color: ProfileColors.ink,
                    weight: FontWeight.w600,
                  ),
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ProfileText.body(
                      size: 11.5,
                      color: ProfileColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.meta != null) ...[
            const SizedBox(width: 8),
            Text(
              item.meta!,
              style: ProfileText.body(
                size: 11.5,
                color: ProfileColors.accent,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class IdentityCard extends StatelessWidget {
  const IdentityCard({
    super.key,
    required this.name,
    required this.owner,
    required this.verified,
    required this.tier,
    required this.onEdit,
    this.logoUrl,
    this.onPhoto,
  });

  final String name;
  final String? owner;
  final bool verified;
  final String tier;
  final VoidCallback onEdit;
  final String? logoUrl;
  final VoidCallback? onPhoto;

  @override
  Widget build(BuildContext context) {
    final ownerLine =
        (owner ?? '').trim().isNotEmpty ? owner!.trim() : 'Business account';
    return Container(
      decoration: profileCardDecoration(radius: 20),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileAvatar(
                    name: name,
                    verified: verified,
                    imageUrl: logoUrl,
                    onPhoto: onPhoto),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ProfileText.heading(
                          size: 19,
                          weight: FontWeight.w800,
                          color: ProfileColors.ink,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ownerLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ProfileText.body(
                          size: 12,
                          color: ProfileColors.muted,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(children: [
                        PlanBadge(tier: tier),
                        if (!verified) ...[
                          const SizedBox(width: 7),
                          Text(
                            'KYC pending',
                            style: ProfileText.body(
                              size: 10.5,
                              color: ProfileColors.warning,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Edit profile',
                    style: ProfileText.body(
                      size: 11.5,
                      color: ProfileColors.accent,
                      weight: FontWeight.w700,
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
}

class CompleteProfileCard extends StatelessWidget {
  const CompleteProfileCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: profileCardDecoration(radius: 16),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: ProfileColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete your business profile',
                        style: ProfileText.body(
                          size: 13.5,
                          color: ProfileColors.ink,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add GSTIN and address to unlock payouts.',
                        style: ProfileText.body(
                          size: 11.5,
                          color: ProfileColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 15,
                  color: ProfileColors.faint,
                ),
              ]),
            ),
          ),
        ),
      );
}

String planTitle(Membership plan) {
  final raw = plan.planName.trim();
  if (plan.isFree) return 'Free plan';
  if (raw.isEmpty) {
    final tier = switch (plan.tier.toUpperCase()) {
      'PAID' => 'Pro',
      'PREMIUM' => 'Premium',
      'UNLIMITED' => 'Unlimited',
      _ => 'Free',
    };
    return '$tier plan';
  }
  return raw.toLowerCase().contains('plan') ? raw : '$raw plan';
}

class MembershipSummaryCard extends StatelessWidget {
  const MembershipSummaryCard({
    super.key,
    required this.plan,
    required this.onDetails,
    required this.onRetry,
  });

  final Membership? plan;
  final VoidCallback onDetails;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    if (p == null) {
      return Container(
        decoration: profileCardDecoration(),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan details unavailable',
                  style: ProfileText.heading(size: 15, weight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pull to refresh to try again.',
                  style: ProfileText.body(size: 11.5),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
    }

    final limit = p.listingLimit;
    final used = p.listingsUsed ?? 0;
    final usage = limit == null
        ? '$used listings · Unlimited'
        : '$used of $limit listings used';
    final progress =
        limit != null && limit > 0 ? (used / limit).clamp(0.0, 1.0) : null;

    return Container(
      decoration: profileCardDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            PlanBadge(tier: p.tier),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                planTitle(p),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ProfileText.heading(size: 16, weight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: onDetails,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Plan details',
                style: ProfileText.body(
                  size: 11.5,
                  color: ProfileColors.accent,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            !p.isFree && p.daysLeft != null
                ? '$usage · ${p.daysLeft} days left'
                : usage,
            style: ProfileText.body(size: 12),
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFEDF0F4),
                    color: ProfileColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progress * 100).round()}%',
                style: ProfileText.body(
                  size: 11,
                  color: ProfileColors.muted,
                  weight: FontWeight.w600,
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class PlanDetailsSheet extends StatelessWidget {
  const PlanDetailsSheet({super.key, required this.plan});

  final Membership? plan;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    return Container(
      decoration: const BoxDecoration(
        color: ProfileColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9DEE7),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Text(
                  'Plan details',
                  style: ProfileText.heading(size: 18, weight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ]),
              if (p == null)
                Text(
                  'Plan details are unavailable right now. Pull to refresh on the profile page.',
                  style: ProfileText.body(size: 13),
                )
              else ...[
                Row(children: [
                  PlanBadge(tier: p.tier),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      planTitle(p),
                      style: ProfileText.heading(
                        size: 16,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                _PlanSheetRow(
                  label: 'Listings used',
                  value: p.listingLimit == null
                      ? '${p.listingsUsed ?? 0} · Unlimited'
                      : '${p.listingsUsed ?? 0} of ${p.listingLimit}',
                ),
                if (!p.isFree && p.daysLeft != null)
                  _PlanSheetRow(
                    label: 'Days left',
                    value: '${p.daysLeft}',
                  ),
                _PlanSheetRow(
                  label: 'Status',
                  value: p.isFree ? 'Active' : 'Active · managed by support',
                ),
                const SizedBox(height: 14),
                Text(
                  'Plan upgrades and renewals are managed by Dealkr support.',
                  style: ProfileText.body(size: 11.5),
                ),
              ],
              const SizedBox(height: 18),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: ProfileColors.ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Done',
                  style: ProfileText.heading(
                    size: 14,
                    weight: FontWeight.w700,
                    color: Colors.white,
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

class _PlanSheetRow extends StatelessWidget {
  const _PlanSheetRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(
            child: Text(label, style: ProfileText.body(size: 12.5)),
          ),
          Text(
            value,
            style: ProfileText.body(
              size: 12.5,
              color: ProfileColors.ink,
              weight: FontWeight.w700,
            ),
          ),
        ]),
      );
}
