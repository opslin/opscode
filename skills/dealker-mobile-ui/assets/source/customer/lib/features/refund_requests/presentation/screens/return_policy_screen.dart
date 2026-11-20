import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/features/refund_requests/data/return_policy_repository.dart';
import 'package:dealker_app/features/refund_requests/presentation/providers/return_providers.dart';
import 'package:dealker_app/features/refund_requests/presentation/screens/return_routes.dart';
import 'package:dealker_app/features/refund_requests/presentation/widgets/return_ui.dart';

const List<IconData> _icons = <IconData>[
  Icons.inventory_2_outlined,
  Icons.account_balance_wallet_outlined,
  Icons.local_shipping_outlined,
  Icons.info_outline_rounded,
  Icons.verified_outlined,
  Icons.rule_rounded,
];

/// "Our Return Policy" (design 12). Window days, pickup and the rules come from the dashboard's Returns Policy settings.
class ReturnPolicyScreen extends ConsumerWidget {
  const ReturnPolicyScreen({this.orderId, super.key});

  /// When opened from a return, "Contact Support" opens that return's chat.
  final String? orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ReturnPolicy> policy = ref.watch(returnPolicyProvider);
    return ReturnScaffold(
      title: 'Return Policy',
      bottom: orderId == null
          ? null
          : SizedBox(
              height: 52.h,
              child: ElevatedButton.icon(
                onPressed: () => context.push(ReturnRoutes.chat(orderId!)),
                icon: const Icon(Icons.headset_mic_outlined),
                label: Text(
                  'Need Help? Contact Support',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ReturnColors.indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
            ),
      child: policy.when(
        loading: () => const DealkerPageLoader(),
        error: (Object e, StackTrace _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Could not load the return policy.'),
              TextButton(
                onPressed: () => ref.invalidate(returnPolicyProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (ReturnPolicy p) {
          final List<({String title, String text, IconData icon})> rows =
              <({String title, String text, IconData icon})>[
            (
              title: 'Return within ${p.windowDays} days',
              text: 'Counted from the delivery date.',
              icon: Icons.schedule_rounded,
            ),
            for (int i = 0; i < p.points.length; i++)
              (
                title: p.points[i].title,
                text: p.points[i].text,
                icon: _icons[i % _icons.length],
              ),
          ];
          return ListView(
            padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 24.h),
            children: <Widget>[
              Center(
                child: Container(
                  width: 84.w,
                  height: 84.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: ReturnColors.indigoSoft,
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    size: 42.sp,
                    color: ReturnColors.indigo,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Center(
                child: Text(
                  'Our Return Policy',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: ReturnColors.ink,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              for (final row in rows) ...<Widget>[
                ReturnCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 38.w,
                        height: 38.w,
                        decoration: BoxDecoration(
                          color: ReturnColors.indigoSoft,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          row.icon,
                          size: 20.sp,
                          color: ReturnColors.indigo,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              row.title,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: ReturnColors.ink,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              row.text,
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                height: 1.4,
                                color: ReturnColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
              ],
            ],
          );
        },
      ),
    );
  }
}
