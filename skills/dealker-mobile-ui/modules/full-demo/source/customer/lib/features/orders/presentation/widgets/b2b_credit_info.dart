import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/core/theme/app_dimensions.dart';
import 'package:dealker_app/core/theme/app_text_styles.dart';
import 'package:dealker_app/core/utils/extensions/datetime_extensions.dart';
import 'package:dealker_app/core/utils/extensions/double_extensions.dart';
import 'package:dealker_app/features/orders/domain/entities/order_entity.dart';

class B2BCreditInfo extends StatelessWidget {
  const B2BCreditInfo({required this.order});

  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    final pending = order.b2bAmountPending;
    final isFullySettled = pending <= 0.01;
    final dueDate = order.b2bPaymentDueDate;
    final isOverdue = dueDate != null && pending > 0.01 && dueDate.isExpired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _B2bInfoRow(
          label: 'Settled',
          value: order.b2bAmountSettled.toInrCurrency,
          valueColor: AppColors.primaryGreen,
        ),
        if (!isFullySettled)
          _B2bInfoRow(
            label: 'Pending',
            value: pending.toInrCurrency,
            valueColor: AppColors.orderStatusAmber,
          )
        else
          const _B2bInfoRow(
            label: 'Status',
            value: 'Fully settled',
            valueColor: AppColors.primaryGreen,
          ),
        if (dueDate != null && !isFullySettled) ...<Widget>[
          Gap(4.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isOverdue
                  ? const Color(0xFFFEF2F2)
                  : AppColors.orderStatusAmberBg,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Row(
              children: <Widget>[
                PhosphorIcon(
                  PhosphorIcons.calendarDots,
                  size: 16.sp,
                  color: isOverdue
                      ? AppColors.errorRed
                      : AppColors.orderStatusAmber,
                ),
                Gap(8.w),
                Expanded(
                  child: Text(
                    isOverdue
                        ? 'Payment was due ${dueDate.toIndianDate}'
                        : 'Payment due by ${dueDate.toIndianDate}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isOverdue
                          ? AppColors.errorRed
                          : AppColors.orderStatusAmber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (order.b2bSettlements.isNotEmpty) ...<Widget>[
          Gap(10.h),
          Text(
            'Collection history',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Gap(6.h),
          ...order.b2bSettlements.map(
            (settlement) => Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _settlementMethodLabel(settlement.method),
                          style: AppTextStyles.bodyMedium
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          settlement.createdAt.toIndianDateTime,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        if ((settlement.note ?? '').trim().isNotEmpty)
                          Text(
                            settlement.note!.trim(),
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    settlement.amount.toInrCurrency,
                    style: AppTextStyles.labelLarge
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _settlementMethodLabel(String method) {
    return switch (method.trim().toUpperCase()) {
      'CASH' => 'Cash',
      'UPI' => 'UPI',
      'RAZORPAY' => 'Razorpay',
      _ => 'Other',
    };
  }
}

class _B2bInfoRow extends StatelessWidget {
  const _B2bInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: AppTextStyles.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
