import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart';

/// "About Dealkr" bottom sheet (replaces the stock Flutter about dialog).
class AboutSheet extends StatelessWidget {
  const AboutSheet({required this.version, super.key});

  final String version;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
        padding: EdgeInsets.fromLTRB(22.w, 14.h, 22.w, 22.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AU.border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Gap(18.h),
            Image.asset(
              'assets/branding/dealker-logo.png',
              height: 56.h,
              fit: BoxFit.contain,
            ),
            Gap(12.h),
            Text(
              'Mobiles • Electronics • More',
              style: jakarta(14.sp, w: FontWeight.w700, color: AU.muted),
            ),
            Gap(16.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AU.indigoSoft,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                'Version $version',
                style: dm(12.5.sp, color: AppColors.brandNavy, w: FontWeight.w700),
              ),
            ),
            Gap(16.h),
            Text(
              '© ${DateTime.now().year} Dealkr. All rights reserved.',
              style: dm(12.5.sp, color: AU.grey),
            ),
            Gap(18.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandNavy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: Text('Close', style: jakarta(15.sp, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
