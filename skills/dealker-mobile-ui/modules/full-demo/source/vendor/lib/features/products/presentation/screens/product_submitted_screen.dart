import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/data/product_models.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// Shown after a successful submit — the product is waiting for admin approval.
class ProductSubmittedScreen extends StatelessWidget {
  const ProductSubmittedScreen({super.key, required this.item});
  final ListingDetail item;

  @override
  Widget build(BuildContext context) {
    final live = item.state == ListingState.live;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(children: [
                  const SizedBox(height: 4),
                  const _SuccessArt(),
                  const SizedBox(height: 14),
                  Text(live ? 'Your Product is Live!' : 'Product Submitted!',
                      style:
                          heading(size: 25, color: kBlue, w: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(
                      live
                          ? 'Customers and vendors can now see your product.'
                          : 'Your product has been sent for admin approval. It will go live once verified.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.45,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  SectionCard(
                    child: Row(children: [
                      AnyImage(item.cover, size: 62, radius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: heading(size: 15)),
                              const SizedBox(height: 6),
                              Row(children: [
                                StatePill(item.state),
                                const SizedBox(width: 8),
                                ChannelChips(
                                    b2b: item.sellB2b, b2c: item.sellB2c),
                              ]),
                            ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const _Timeline(),
                ]),
              ),
            ),
            AuctionButton(
                label: 'View Product',
                onPressed: () =>
                    context.pushReplacement(Routes.productDetail(item.id))),
            const SizedBox(height: 10),
            AuctionButton(
                label: 'Add Another Product',
                outlined: true,
                onPressed: () => context.pushReplacement(Routes.productAdd)),
            TextButton(
                onPressed: () => context.go(Routes.products),
                child: const Text('Go to My Products',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: kBlue))),
          ]),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline();

  @override
  Widget build(BuildContext context) {
    Widget row(IconData i, String t, String s, {bool done = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: done ? AppColors.mintSoft : kBlueSoft,
                  shape: BoxShape.circle),
              child: Icon(i, size: 18, color: done ? AppColors.mint : kBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy)),
                    Text(s,
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: AppColors.textSecondary)),
                  ]),
            ),
          ]),
        );
    return SectionCard(
      child: Column(children: [
        row(PhosphorIconsFill.checkCircle, 'Submitted',
            'We have your product and your quality check.',
            done: true),
        row(PhosphorIconsFill.magnifyingGlass, 'Dealkr review',
            'Our team verifies photos, details and pricing — usually within 24 hours.'),
        row(PhosphorIconsFill.storefront, 'Goes live',
            'You’ll see it as Live in My Products.'),
      ]),
    );
  }
}

class _SuccessArt extends StatelessWidget {
  const _SuccessArt();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        height: 150,
        child: Stack(alignment: Alignment.center, children: [
          Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(
                  color: kBlueSoft, shape: BoxShape.circle)),
          Container(
            width: 84,
            height: 126,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBlue, width: 3.5),
              boxShadow: [
                BoxShadow(
                    color: kBlue.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                    color: AppColors.mint, shape: BoxShape.circle),
                child: const Icon(PhosphorIconsBold.check,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(height: 12),
              for (final w in [64.0, 46.0])
                Container(
                  width: w,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(4)),
                ),
            ]),
          ),
          const Positioned(
              left: 14,
              top: 40,
              child: Icon(PhosphorIconsFill.star,
                  size: 20, color: AppColors.amber)),
          const Positioned(
              right: 12,
              top: 26,
              child: Icon(PhosphorIconsFill.star,
                  size: 26, color: AppColors.amber)),
          const Positioned(
              right: 22,
              bottom: 38,
              child: Icon(PhosphorIconsFill.star,
                  size: 16, color: AppColors.amber)),
          const Positioned(
              left: 24,
              bottom: 30,
              child: Icon(PhosphorIconsFill.sparkle, size: 20, color: kBlue)),
        ]),
      );
}
