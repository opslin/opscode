import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/features/addresses/domain/entities/address_entity.dart';
import 'package:dealker_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:dealker_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:dealker_app/routing/route_names.dart';

/// Opens the delivery address bottom sheet.
///
/// Guests have no addresses, so tapping the header's address line sends them
/// straight to login (and back to Home afterwards) instead of showing an
/// empty sheet. Logged-in customers see their current address with actions to
/// change or add one. Hides the floating cart pill while the sheet is open.
void showAddressSheet(BuildContext context, WidgetRef ref) {
  final gate = ref.read(authGateControllerProvider);
  if (!gate.isAuthenticated) {
    gate.rememberRouteIntent(RouteNames.home);
    context.push(RouteNames.phone);
    return;
  }

  addressSheetVisible.value = true;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const AddressBottomSheet(),
  ).whenComplete(() {
    addressSheetVisible.value = false;
  });
}

/// Delivery-address sheet: current address card + change / add actions.
class AddressBottomSheet extends ConsumerWidget {
  const AddressBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressProvider).asData?.value;
    final AddressEntity? current = addresses != null && addresses.isNotEmpty
        ? addresses.firstWhere(
            (a) => a.isDefault,
            orElse: () => addresses.first,
          )
        : null;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 38.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E2E2),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Gap(16.h),
            Row(
              children: <Widget>[
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: const BoxDecoration(
                    color: AppColors.brandYellow,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      PhosphorIcons.mapPinFill,
                      size: 22.sp,
                      color: AppColors.brandNavy,
                    ),
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'DELIVER TO',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Gap(2.h),
                      Text(
                        'Your delivery address',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandNavy,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF2F4F8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            Gap(18.h),
            if (current != null)
              _CurrentAddressCard(address: current)
            else
              const _NoAddressCard(),
            Gap(18.h),
            _SheetButton(
              label: current != null ? 'Change address' : 'Add address',
              icon: current != null
                  ? PhosphorIcons.arrowsLeftRightBold
                  : PhosphorIcons.plusBold,
              filled: true,
              onTap: () {
                Navigator.pop(context);
                context.go(
                  current != null ? RouteNames.addresses : RouteNames.addAddress,
                );
              },
            ),
            if (current != null) ...<Widget>[
              Gap(10.h),
              _SheetButton(
                label: 'Add new address',
                icon: PhosphorIcons.plusBold,
                filled: false,
                onTap: () {
                  Navigator.pop(context);
                  context.go(RouteNames.addAddress);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrentAddressCard extends StatelessWidget {
  const _CurrentAddressCard({required this.address});

  final AddressEntity address;

  @override
  Widget build(BuildContext context) {
    final String label = address.label.trim();
    final String line2 = (address.addressLine2 ?? '').trim();
    final String street = <String>[
      address.addressLine1.trim(),
      if (line2.isNotEmpty) line2,
    ].where((s) => s.isNotEmpty).join(', ');
    final String area = <String>[
      address.city.trim(),
      address.state.trim(),
      address.pincode.trim(),
    ].where((s) => s.isNotEmpty).join(', ');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.brandCream,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.brandYellow.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppColors.brandNavy,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: PhosphorIcon(
                PhosphorIcons.houseLineFill,
                size: 20.sp,
                color: AppColors.brandYellow,
              ),
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (label.isNotEmpty)
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandNavy,
                          ),
                        ),
                      ),
                    if (address.isDefault) ...<Widget>[
                      Gap(8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandYellow,
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          'DEFAULT',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.brandNavy,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Gap(4.h),
                if (street.isNotEmpty)
                  Text(
                    street,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1A1A),
                      height: 1.35,
                    ),
                  ),
                if (area.isNotEmpty)
                  Text(
                    area,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5.sp,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoAddressCard extends StatelessWidget {
  const _NoAddressCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: AppColors.brandCream,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: SizedBox(
              height: 140.h,
              width: double.infinity,
              child: Image.asset(
                'assets/images/dealker-location-permission-illustration.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.55),
              ),
            ),
          ),
          Gap(10.h),
          Text(
            'No delivery address yet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.brandNavy,
            ),
          ),
          Gap(2.h),
          Text(
            'Add one for faster checkout and accurate delivery.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5.sp,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final PhosphorIconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = filled ? Colors.white : AppColors.brandNavy;
    return Material(
      color: filled ? AppColors.brandNavy : Colors.white,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          width: double.infinity,
          height: 52.h,
          decoration: filled
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: AppColors.brandNavy, width: 1.4),
                ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              PhosphorIcon(icon, size: 18.sp, color: fg),
              Gap(8.w),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
