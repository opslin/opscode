import 'package:flutter/material.dart';
import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/shared/widgets/dealker_product_grid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/core/theme/app_text_styles.dart';
import 'package:dealker_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:dealker_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(wishlistProvider);
    final wishlist = wishlistAsync.asData?.value;
    final hasItems = (wishlist?.items.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('My Wishlist', style: AppTextStyles.h2),
        actions: <Widget>[
          TextButton(
            onPressed: hasItems
                ? () async {
                    final result = await ref
                        .read(wishlistProvider.notifier)
                        .moveAllToCart();
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result.isSuccess
                              ? '${result.movedCount} items moved to cart.'
                              : result.failure!.message,
                        ),
                        backgroundColor: result.isSuccess
                            ? AppColors.successGreen
                            : AppColors.outOfStockRed,
                      ),
                    );
                  }
                : null,
            child: Text(
              'Move all to cart',
              style: AppTextStyles.buttonMedium.copyWith(
                color:
                    hasItems ? AppColors.primaryGreen : AppColors.textTertiary,
              ),
            ),
          ),
          Gap(4.w),
        ],
      ),
      body: wishlistAsync.when(
        loading: () => const DealkerPageLoader(),
        error: (error, _) => _WishlistErrorState(
          message: error.toString().replaceFirst('Bad state: ', ''),
          onRetry: () => ref.invalidate(wishlistProvider),
        ),
        data: (wishlistData) {
          if (wishlistData.items.isEmpty) {
            return const _WishlistEmptyState();
          }

          // Piggybacks on the wishlist fetch that's already happening — no
          // extra per-card network call. Cheap no-op once already known.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(purchaseLimitsNotifierProvider.notifier).ensureLoaded(
                  wishlistData.items.map((item) => item.product.id).toList(),
                );
          });

          return RefreshIndicator(
            color: AppColors.primaryGreen,
            onRefresh: () async {
              ref.read(wishlistProvider.notifier).refresh();
              await ref.read(wishlistProvider.future);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                  sliver: SliverDealkerProductGrid(
                    products: wishlistData.items
                        .map((item) => item.product)
                        .toList(growable: false),
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 14.h,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WishlistEmptyState extends StatelessWidget {
  const _WishlistEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 160.w,
              height: 160.w,
              child: Lottie.network(
                'https://assets4.lottiefiles.com/packages/lf20_lj9x0wdj.json',
                repeat: true,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  PhosphorIcons.heart,
                  size: 80.sp,
                  color: AppColors.textDisabled,
                ),
              ),
            ),
            Gap(12.h),
            Text(
              'Your wishlist is empty',
              style: AppTextStyles.h3,
            ),
            Gap(6.h),
            Text(
              'Tap the heart icon on products to save them here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistErrorState extends StatelessWidget {
  const _WishlistErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            Gap(10.h),
            FilledButton(
              onPressed: onRetry,
              child: Text('Retry', style: AppTextStyles.buttonMedium),
            ),
          ],
        ),
      ),
    );
  }
}
