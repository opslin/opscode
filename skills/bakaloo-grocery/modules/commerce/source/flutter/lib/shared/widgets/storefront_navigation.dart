import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Bakaloo's bottom navigation artwork and tab treatment for the local routes.
class StorefrontNavigation extends StatelessWidget {
  const StorefrontNavigation({
    super.key,
    required this.browsing,
    required this.count,
    required this.onHome,
    required this.onBrowse,
    required this.onCart,
  });

  final bool browsing;
  final int count;
  final VoidCallback onHome;
  final VoidCallback onBrowse;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 3,
    child: SafeArea(
      top: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavTabButton(
            label: 'Home',
            asset: browsing
                ? 'assets/icon/footer_icon/bakaloo-home-outline-icon.png'
                : 'assets/icon/footer_icon/bakaloo-home-filled-icon.png',
            selected: !browsing,
            onTap: onHome,
          ),
          _NavTabButton(
            label: 'Browse',
            asset: browsing
                ? 'assets/icon/footer_icon/bakaloo-categories-filled-icon.png'
                : 'assets/icon/footer_icon/bakaloo-categories-outline-icon.png',
            selected: browsing,
            onTap: onBrowse,
          ),
          _NavTabButton(
            label: 'Cart',
            count: count,
            selected: false,
            onTap: onCart,
          ),
        ],
      ),
    ),
  );
}

class _NavTabButton extends StatelessWidget {
  const _NavTabButton({
    required this.label,
    this.asset,
    this.count = 0,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? asset;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color activeColor = Color(0xFF6C4DFF);
    const Color inactiveColor = Color(0xFF1A1A1A);
    final Color labelColor = selected ? activeColor : inactiveColor;

    final artwork = asset;
    final icon = artwork == null
        ? Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: PhosphorIcon(
              PhosphorIcons.shoppingCartSimpleBold,
              size: 24.sp,
            ),
          )
        : Image.asset(
            artwork,
            width: 36.w,
            height: 36.h,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            color: selected ? null : inactiveColor,
          );

    return Semantics(
      button: true,
      selected: selected,
      label: count == 0 ? label : '$label ($count)',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 6.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 56.w,
                  height: 38.h,
                  child: Center(
                    child: AnimatedScale(
                      scale: selected ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: icon,
                    ),
                  ),
                ),
                Gap(3.h),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: labelColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12.sp,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
