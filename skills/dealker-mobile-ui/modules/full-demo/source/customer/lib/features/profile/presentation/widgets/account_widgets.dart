import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart';

const List<BoxShadow> _cardShadow = <BoxShadow>[
  BoxShadow(color: Color(0x0F0A1B4D), blurRadius: 18, offset: Offset(0, 8)),
];

/// "Account" title with search / notifications / cart on the right.
class AccountTopBar extends StatelessWidget {
  const AccountTopBar({
    required this.onSearch,
    required this.onNotifications,
    required this.onCart,
    required this.unreadNotifications,
    required this.cartCount,
    super.key,
  });

  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onCart;
  final int unreadNotifications;
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16.w,
        MediaQuery.paddingOf(context).top + 8.h,
        12.w,
        10.h,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text('Account', style: jakarta(26.sp)),
          ),
          _BarIcon(
            label: 'Search',
            onTap: onSearch,
            child: PhosphorIcon(
              PhosphorIcons.magnifyingGlassBold,
              size: 20.sp,
              color: AppColors.brandNavy,
            ),
          ),
          Gap(8.w),
          _BarIcon(
            label: 'Notifications',
            onTap: onNotifications,
            dot: unreadNotifications > 0,
            child: CartArtImage(CartArt.bell, size: 26.sp),
          ),
          Gap(8.w),
          _BarIcon(
            label: 'Cart',
            onTap: onCart,
            count: cartCount,
            child: CartArtImage(CartArt.cart, size: 26.sp),
          ),
        ],
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.child,
    required this.label,
    required this.onTap,
    this.dot = false,
    this.count = 0,
  });

  final Widget child;
  final String label;
  final VoidCallback onTap;
  final bool dot;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 44.w,
          height: 44.w,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: AU.indigoSoft,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Center(child: child),
              ),
              if (dot)
                Positioned(
                  top: 2.w,
                  right: 2.w,
                  child: Container(
                    width: 11.r,
                    height: 11.r,
                    decoration: BoxDecoration(
                      color: AppColors.brandRose,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              if (count > 0)
                Positioned(
                  top: -4.w,
                  right: -4.w,
                  child: _CountBadge(count: count),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: 18.r, minHeight: 18.r),
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      decoration: BoxDecoration(
        color: AppColors.brandRose,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.white, width: 1.8),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 9.5.sp,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

/// One tile of the quick actions row. [subtitle] is hidden when null so no
/// number is ever invented.
class QuickActionData {
  const QuickActionData({
    required this.art,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final CartArt art;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
}

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({required this.actions, super.key});

  final List<QuickActionData> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (var i = 0; i < actions.length; i++) ...<Widget>[
          if (i > 0) Gap(12.w),
          Expanded(child: _QuickActionTile(data: actions[i])),
        ],
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.data});

  final QuickActionData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          padding: EdgeInsets.fromLTRB(14.w, 12.h, 12.w, 12.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.orderCardBorder),
            boxShadow: _cardShadow,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: jakarta(15.5.sp),
                    ),
                    Gap(3.h),
                    Text(
                      data.subtitle ?? 'View',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dm(12.5.sp, color: AU.muted),
                    ),
                  ],
                ),
              ),
              CartArtImage(data.art, size: 46.w, float: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled group of rows inside one white card with hairline dividers.
class AccountSection extends StatelessWidget {
  const AccountSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(left: 72.w, right: 14.w),
            child: const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.divider,
            ),
          ),
        );
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(left: 6.w, bottom: 10.h),
          child: Text(
            title.toUpperCase(),
            style: jakarta(12.sp, w: FontWeight.w800, color: AU.muted)
                .copyWith(letterSpacing: 1.1),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.orderCardBorder),
            boxShadow: _cardShadow,
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

/// Grouped-list row: 3D icon in a soft tile, title, optional subtitle,
/// optional count badge and a chevron. Full-row tap target.
class AccountRow extends StatelessWidget {
  const AccountRow({
    required this.title,
    required this.onTap,
    this.art,
    this.icon,
    this.subtitle,
    this.badge = 0,
    this.iconWidget,
    this.isDanger = false,
    super.key,
  });

  /// 3D artwork for the tile (preferred).
  final CartArt? art;

  /// Fallback line icon when there is no artwork (e.g. admin-defined rows).
  final IconData? icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final int badge;

  /// Replaces the icon, e.g. an admin-uploaded custom icon image.
  final Widget? iconWidget;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final Color color = isDanger ? AppColors.errorRed : AU.ink;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 64.h),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
          child: Row(
            children: <Widget>[
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  color: isDanger ? const Color(0xFFFDECEE) : AU.indigoSoft,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Center(
                  child: iconWidget ??
                      (art != null
                          ? CartArtImage(art!, size: 32.w)
                          : PhosphorIcon(
                              icon ?? PhosphorIcons.linkLight,
                              size: 22.sp,
                              color: color,
                            )),
                ),
              ),
              Gap(14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: jakarta(15.sp, w: FontWeight.w700, color: color),
                    ),
                    if (subtitle != null) ...<Widget>[
                      Gap(2.h),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dm(12.5.sp, color: AU.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge > 0) ...<Widget>[
                _CountBadge(count: badge),
                Gap(8.w),
              ],
              PhosphorIcon(
                PhosphorIcons.caretRight,
                size: 16.sp,
                color: AU.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Need help?" card: opens the in-app support chat; call / email sit beside it.
class SupportCard extends StatelessWidget {
  const SupportCard({
    required this.onChat,
    required this.onCall,
    required this.onEmail,
    super.key,
  });

  final VoidCallback onChat;
  final VoidCallback onCall;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF001F5F), Color(0xFF123A8F)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF001F5F).withValues(alpha: .25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 58.w,
                height: 58.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(18.r),
                ),
                child: Center(
                  child: CartArtImage(CartArt.headset, size: 40.w, float: true),
                ),
              ),
              Gap(14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Need help?',
                        style: jakarta(17.sp, color: Colors.white)),
                    Gap(3.h),
                    Text(
                      'Our support team replies fast',
                      style: dm(12.5.sp,
                          color: Colors.white.withValues(alpha: .75)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap(14.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: FilledButton.icon(
              onPressed: onChat,
              icon: CartArtImage(CartArt.chat, size: 22.sp),
              label: Text(
                'Chat with Support',
                style: jakarta(15.sp, color: AppColors.brandNavy),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandYellow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ),
          Gap(10.h),
          Row(
            children: <Widget>[
              Expanded(
                child: _LinkButton(
                  art: CartArt.call,
                  label: 'Call us',
                  onTap: onCall,
                ),
              ),
              Gap(10.w),
              Expanded(
                child: _LinkButton(
                  art: CartArt.mail,
                  label: 'Email us',
                  onTap: onEmail,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.art,
    required this.label,
    required this.onTap,
  });

  final CartArt art;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        height: 46.h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white.withValues(alpha: .16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CartArtImage(art, size: 24.sp),
            Gap(8.w),
            Text(label, style: dm(13.5.sp, color: Colors.white, w: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Full-width log-out button.
class LogoutButton extends StatelessWidget {
  const LogoutButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          height: 58.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CartArtImage(CartArt.logout, size: 28.sp),
              Gap(10.w),
              Text('Log out',
                  style: jakarta(15.5.sp, color: AppColors.errorRed)),
            ],
          ),
        ),
      ),
    );
  }
}
