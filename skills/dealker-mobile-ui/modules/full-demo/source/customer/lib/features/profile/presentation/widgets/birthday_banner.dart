import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart';

class BirthdayBanner extends StatelessWidget {
  const BirthdayBanner({
    required this.birthday,
    required this.onSelectBirthday,
    super.key,
  });

  final DateTime? birthday;
  final ValueChanged<DateTime> onSelectBirthday;

  @override
  Widget build(BuildContext context) {
    if (birthday != null) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final selected = await showDatePicker(
          context: context,
          initialDate: DateTime(now.year - 20, now.month, now.day),
          firstDate: DateTime(1950),
          lastDate: now,
        );
        if (selected != null) {
          onSelectBirthday(selected);
        }
      },
      borderRadius: BorderRadius.circular(20.r),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFFFF1F4), Colors.white],
          ),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.brandRose.withValues(alpha: .25)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Add your birthday', style: jakarta(15.5.sp)),
                    Gap(3.h),
                    Text(
                      'Optional · get a surprise on your day',
                      style: dm(12.5.sp, color: AU.muted),
                    ),
                  ],
                ),
              ),
              CartArtImage(CartArt.cake, size: 50.w, float: true),
            ],
          ),
        ),
      ),
    );
  }
}
