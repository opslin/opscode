import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/business_account/presentation/providers/price_mode_provider.dart';

/// Quick "B2B Store is on" indicator + one-tap disable, shown directly on
/// the Profile page's summary right below the order-stats row — only ever
/// while wholesale pricing is actually ACTIVE (`isWholesalePricingActiveProvider`,
/// which is already exactly "business account APPROVED and its b2bEnabled
/// toggle is on" — see PriceModeNotifier).
///
/// This card only ever turns things OFF. A B2C customer, an approved
/// account that hasn't turned wholesale on yet, and (the moment this
/// card's own switch flips it off) that same account a second later — all
/// render nothing here at all: the whole widget returns a zero-size
/// SizedBox.shrink() rather than a disabled/explanatory placeholder.
/// Turning it back ON is a deliberate trip to the dedicated Business
/// Account screen, not something this shortcut offers.
class B2BModeCard extends ConsumerStatefulWidget {
  const B2BModeCard({super.key});

  @override
  ConsumerState<B2BModeCard> createState() => _B2BModeCardState();
}

class _B2BModeCardState extends ConsumerState<B2BModeCard> {
  bool _toggling = false;

  Future<void> _onChanged(bool _) async {
    setState(() => _toggling = true);
    final result = await ref.read(priceModeProvider.notifier).toggle();
    if (!mounted) return;
    setState(() => _toggling = false);
    if (!result.isSuccess) {
      AppToast.show(context, result.failure!.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wholesaleActive = ref.watch(isWholesalePricingActiveProvider);
    if (!wholesaleActive) {
      return const SizedBox.shrink();
    }

    // Top spacing lives here (not in the parent layout) so a B2C customer
    // — for whom this whole widget renders as a zero-size SizedBox.shrink()
    // above — never ends up with an orphaned empty gap between the stats
    // row and MY ACTIVITY.
    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFFFF4CC), Colors.white],
          ),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
              color: AppColors.brandYellow.withValues(alpha: .55)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x14FFC400),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 50.w,
              height: 50.w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15.r),
              ),
              child: Center(
                child: CartArtImage(CartArt.briefcase, size: 34.w, float: true),
              ),
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text('B2B Store', style: jakarta(16.sp)),
                      Gap(6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandNavy,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'PRO',
                          style: dm(9.sp,
                              color: AppColors.brandYellow,
                              w: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  Gap(2.h),
                  Text(
                    'Wholesale pricing is active across the app.',
                    style: dm(12.5.sp, color: AU.muted),
                  ),
                ],
              ),
            ),
            Gap(8.w),
            _toggling
                ? SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: const CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : DealkerCoinToggle(value: wholesaleActive, onChanged: _onChanged),
          ],
        ),
      ),
    );
  }
}
