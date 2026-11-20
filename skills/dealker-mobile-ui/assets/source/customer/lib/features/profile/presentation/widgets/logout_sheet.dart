import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:dealker_app/routing/route_names.dart';

class LogoutSheet extends ConsumerWidget {
  const LogoutSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28.r),
        ),
      ),
      builder: (context) => const LogoutSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22.w, 2.h, 22.w, 22.h),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(child: CartArtImage(CartArt.logout, size: 84.w, float: true)),
            Gap(10.h),
            Text('Log out?',
                textAlign: TextAlign.center, style: jakarta(22.sp)),
            Gap(8.h),
            Text(
              'You will need to sign in again with your phone number to place orders.',
              textAlign: TextAlign.center,
              style: dm(14.sp, color: AU.muted, h: 1.4),
            ),
            Gap(20.h),
            SizedBox(
              height: 52.h,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.errorRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (!context.mounted) {
                    return;
                  }
                  context.go(RouteNames.phone);
                },
                child: Text('Log out',
                    style: jakarta(15.5.sp, color: Colors.white)),
              ),
            ),
            Gap(8.h),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Stay signed in',
                  style: jakarta(14.5.sp, color: AppColors.brandNavy)),
            ),
          ],
        ),
      ),
    );
  }
}
