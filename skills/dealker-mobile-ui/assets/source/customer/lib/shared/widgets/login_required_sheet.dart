import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/core/theme/app_dimensions.dart';
import 'package:dealker_app/core/theme/app_shadows.dart';
import 'package:dealker_app/core/theme/app_text_styles.dart';

class LoginRequiredSheet extends StatelessWidget {
  const LoginRequiredSheet({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final shouldContinue = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return LoginRequiredSheet(
          title: title,
          message: message,
        );
      },
    );

    return shouldContinue ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 10.h),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(28.r),
            boxShadow: const <BoxShadow>[AppShadows.floatingShadow],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(22.w, 12.h, 22.w, 14.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusFull,
                    ),
                  ),
                ),
                Gap(18.h),
                Image.asset('assets/cart/lock.png', height: 92.h),
                Gap(14.h),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.orderViolet,
                  ),
                ),
                Gap(6.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                Gap(20.h),
                const _Perk(
                  asset: 'assets/loading/shield.png',
                  text: 'Secure OTP login, no password needed',
                ),
                Gap(12.h),
                const _Perk(
                  asset: 'assets/cart/bolt.png',
                  text: 'Takes less than 30 seconds',
                ),
                Gap(12.h),
                const _Perk(
                  asset: 'assets/cart/verified.png',
                  text: 'Your details stay private and safe',
                ),
                Gap(22.h),
                SizedBox(
                  width: double.infinity,
                  height: 54.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orderViolet,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Continue to Login'),
                  ),
                ),
                Gap(4.h),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    minimumSize: Size.fromHeight(44.h),
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Not now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.asset, required this.text});

  final String asset;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Image.asset(asset, width: 30.w, height: 30.w),
        Gap(14.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
