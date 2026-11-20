// Bakaloo's checkout bill row and bottom bar, adapted for demo orders.
part of 'checkout_screen.dart';

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.value,
    this.isFree = false,
  });

  final String label;
  final double value;
  final bool isFree;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          isFree ? 'FREE' : _money(value),
          style: AppTextStyles.labelLarge.copyWith(
            color: isFree ? AppColors.successGreen : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CheckoutBottomBar extends StatelessWidget {
  const _CheckoutBottomBar({
    required this.total,
    required this.isLoading,
    required this.onPlaceOrder,
  });

  final double total;
  final bool isLoading;
  final VoidCallback? onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: <BoxShadow>[AppShadows.floatingShadow],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Total payable',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _money(total),
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(12.w),
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    onPressed: isLoading ? null : onPlaceOrder,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      disabledBackgroundColor: AppColors.borderLight,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Place demo order',
                            style: AppTextStyles.buttonMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
