import 'package:flutter/material.dart';

import 'storefront_icon_button.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

const String _defaultLogoAsset = 'assets/icon/brand_logo.png';

/// Premium white-lavender top header.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.addressText,
    required this.onAddressTap,
    required this.onNotificationTap,
    this.onWalletTap,
    this.onCartTap,
    this.cartCount = 0,
    this.headerColor,
    required this.brandName,
    this.searchZoneColor,
    this.deliveryEtaMinutes,
    this.topPaddingOverride,
    this.walletBalance,
    this.unreadCount = 0,
    super.key,
  });

  final String addressText;
  final VoidCallback onAddressTap;
  final VoidCallback onNotificationTap;
  final VoidCallback? onWalletTap;
  final VoidCallback? onCartTap;
  final int cartCount;
  final Color? headerColor;
  final String brandName;
  final double? walletBalance;
  final int unreadCount;

  /// Color used by the curved bottom strip so it matches the search zone
  /// background beneath it. Defaults to white when not provided.
  final Color? searchZoneColor;

  /// Admin-set delivery-time badge (e.g. 45 → "45 mins delivery"), shown
  /// only on the main Zepto store front in place of its static "6 mins"
  /// tagline. Other store fronts keep their own static taglines.
  final int? deliveryEtaMinutes;

  /// When something is already occupying the status-bar area above this
  /// header (e.g. [OrderTrackingTopBanner]), that widget passes 0 here so
  /// the header doesn't also pad for it — avoiding a doubled gap. Null
  /// (the default) keeps the normal behavior of padding by the device's
  /// own top safe-area inset.
  final double? topPaddingOverride;

  static const Color _lavenderTop = Color(0xFFEDE4FB);
  static const Color _lavenderBottom = Color(0xFFF6F1FD);

  @override
  Widget build(BuildContext context) {
    final topInset = topPaddingOverride ?? MediaQuery.paddingOf(context).top;
    final themeColor = headerColor;

    final Decoration headerDecoration = themeColor != null
        ? BoxDecoration(color: themeColor)
        : const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[_lavenderTop, _lavenderBottom],
            ),
          );

    return Container(
      width: double.infinity,
      decoration: headerDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, topInset + 0.h, 16.w, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Centered brand logo on top.
                SizedBox(
                  height: 40.h,
                  child: brandName == 'Bakaloo'
                      ? Image.asset(
                          _defaultLogoAsset,
                          semanticLabel: brandName,
                          height: 40.h,
                          cacheHeight: 160,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        )
                      : Center(
                          child: Text(
                            brandName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 24.sp,
                              color: const Color(0xFF29174F),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
                // Pull the bottom row up so it sits tight under the logo.
                Transform.translate(
                  offset: Offset(0, -10.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              deliveryEtaMinutes != null
                                  ? '$deliveryEtaMinutes mins delivery'
                                  : 'Groceries delivered',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w700,
                                height: 1.05,
                                letterSpacing: -0.5,
                                color: Colors.black,
                              ),
                            ),
                            Gap(4.h),
                            GestureDetector(
                              onTap: onAddressTap,
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.location_on_outlined,
                                    color: Colors.black,
                                    size: 17.sp,
                                  ),
                                  Gap(4.w),
                                  Flexible(
                                    child: Text(
                                      addressText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'DMSans',
                                        fontSize:
                                            (onCartTap == null ? 13 : 11.5).sp,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Gap(2.w),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.black,
                                    size: 18.sp,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Gap(10.w),
                      _HeaderActions(
                        onWalletTap: onWalletTap,
                        onCartTap: onCartTap,
                        cartCount: cartCount,
                        onNotificationTap: onNotificationTap,
                        walletBalance: walletBalance,
                        unreadCount: unreadCount,
                      ),
                    ],
                  ),
                ),
                Gap(2.h),
              ],
            ),
          ),
          // Downward curved divider into the content below.
          // The color matches the search-zone background so the curve
          // blends seamlessly regardless of the active theme color.
          ClipPath(
            clipper: const _HeaderBottomCurveClipper(),
            child: Container(
              height: 10.h,
              color: searchZoneColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded top-left and top-right corners that divide the lavender header
/// from the white content area below.
class _HeaderBottomCurveClipper extends CustomClipper<Path> {
  const _HeaderBottomCurveClipper();

  @override
  Path getClip(Size size) {
    const double r = 16.0; // corner radius
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Wallet + profile circular actions kept on a shared baseline so both
/// circles align, while the wallet balance pill overhangs below.
class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.onWalletTap,
    required this.onCartTap,
    required this.cartCount,
    required this.onNotificationTap,
    required this.walletBalance,
    required this.unreadCount,
  });

  final VoidCallback? onWalletTap;
  final VoidCallback? onCartTap;
  final int cartCount;
  final VoidCallback onNotificationTap;
  final double? walletBalance;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final double circle = 46.w;
    final double gap = onCartTap == null ? 12.w : 7.w;

    return SizedBox(
      width: onCartTap == null ? circle * 2 + gap : circle * 3 + gap * 2,
      height: circle + 14.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Both circles aligned on the same top baseline.
          Positioned(
            top: 0,
            left: 0,
            child: Row(
              children: <Widget>[
                _CircleIconButton(
                  asset: 'assets/icon/wallet_icon.png',
                  size: circle,
                  iconSize: 38.w,
                  onTap: onWalletTap,
                ),
                Gap(gap),
                _CircleNotificationButton(
                  size: circle,
                  onTap: onNotificationTap,
                  unread: unreadCount,
                ),
                if (onCartTap case final openCart?) ...[
                  Gap(gap),
                  StorefrontIconButton(
                    icon: PhosphorIcons.shoppingCartSimpleBold,
                    semanticLabel: 'Open cart',
                    badgeCount: cartCount,
                    onTap: openCart,
                  ),
                ],
              ],
            ),
          ),
          // Balance pill, centered under the wallet (left) circle.
          Positioned(
            bottom: 0,
            left: -10.w,
            width: circle + 20.w,
            child: Center(child: _WalletPill(balance: walletBalance)),
          ),
        ],
      ),
    );
  }
}

class _WalletPill extends StatelessWidget {
  const _WalletPill({required this.balance});

  final double? balance;

  @override
  Widget build(BuildContext context) {
    final balance = this.balance;
    if (balance == null || balance <= 0) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFF6B3FA0),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF6B3FA0).withValues(alpha: 0.32),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '\u20b9${_formatBalance(balance)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }

  String _formatBalance(double value) {
    final intVal = value.round();
    final str = intVal.toString();
    if (str.length <= 3) return str;
    final lastThree = str.substring(str.length - 3);
    var rest = str.substring(0, str.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '${groups.join(',')},$lastThree';
  }
}

class _CircleNotificationButton extends StatelessWidget {
  const _CircleNotificationButton({
    required this.size,
    required this.onTap,
    required this.unread,
  });

  final double size;
  final VoidCallback? onTap;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x242A1A47),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: PhosphorIcon(
                      PhosphorIcons.bell,
                      size: 22.sp,
                      color: const Color(0xFF2A1A47),
                    ),
                  ),
                ),
              ),
            ),
            if (unread > 0)
              Positioned(
                top: -2.h,
                right: -2.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  constraints: BoxConstraints(minWidth: 18.w, minHeight: 18.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE23744),
                    borderRadius: BorderRadius.circular(999.r),
                    border: Border.all(color: Colors.white, width: 1.5.w),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                      fontFamily: 'DMSans',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.asset,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  final String asset;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x242A1A47),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: ColoredBox(
            color: Colors.white,
            child: Center(
              child: Image.asset(
                asset,
                width: iconSize,
                height: iconSize,
                cacheWidth: (iconSize * 6).round(),
                cacheHeight: (iconSize * 6).round(),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
