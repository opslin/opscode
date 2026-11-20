import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart';

class DeleteAccountDialog extends StatelessWidget {
  const DeleteAccountDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const DeleteAccountDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 18.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CartArtImage(CartArt.trash, size: 76.w, float: true),
            Gap(10.h),
            Text('Delete account?',
                textAlign: TextAlign.center,
                style: jakarta(21.sp, color: AppColors.errorRed)),
            Gap(8.h),
            Text(
              'This will permanently delete your account and all your data. This action cannot be undone.',
              textAlign: TextAlign.center,
              style: dm(14.sp, color: AU.muted, h: 1.4),
            ),
            Gap(20.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.fromHeight(48.h),
                      side: const BorderSide(color: Color(0xFFD9E0F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text('Keep account',
                        style: jakarta(14.sp, color: AppColors.brandNavy)),
                  ),
                ),
                Gap(10.w),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.errorRed,
                      minimumSize: Size.fromHeight(48.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child:
                        Text('Delete', style: jakarta(14.sp, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
