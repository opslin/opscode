import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class StorefrontIconButton extends StatelessWidget {
  const StorefrontIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.badgeCount = 0,
  });

  final PhosphorIconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: badgeCount == 0 ? semanticLabel : '$semanticLabel ($badgeCount)',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46.w,
          height: 46.w,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Center(
                  child: PhosphorIcon(
                    icon,
                    size: 19.sp,
                    color: AppColors.orderViolet,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 2.w,
                  top: 2.h,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5.w,
                      vertical: 1.h,
                    ),
                    constraints: BoxConstraints(minWidth: 16.w),
                    decoration: BoxDecoration(
                      color: AppColors.orderViolet,
                      borderRadius: BorderRadius.circular(100.r),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
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
