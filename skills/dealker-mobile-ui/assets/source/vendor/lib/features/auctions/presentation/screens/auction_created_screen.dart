import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// Screen 7 — confirmation after the auction is created.
class AuctionCreatedScreen extends StatelessWidget {
  const AuctionCreatedScreen({super.key, required this.auction});
  final AuctionItem auction;

  ({String title, String body}) get _copy => switch (auction.status) {
        'DRAFT' => (
            title: 'Draft saved',
            body:
                'Your auction is saved. Publish it from My Auctions when you are ready.'
          ),
        'PENDING_APPROVAL' => (
            title: 'Sent for approval',
            body:
                'Your auction has been created. It will go live once Dealkr approves it.'
          ),
        'LIVE' => (
            title: 'Auction is live!',
            body: 'Your auction is live now. Bidders can join and place bids.'
          ),
        _ => (
            title: 'Auction Added!',
            body:
                'Your auction has been created successfully. It will go live at the scheduled time.'
          ),
      };

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.auctions);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(children: [
              Expanded(
                child: ListView(children: [
                  const SizedBox(height: 36),
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.mintSoft,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.mint.withValues(alpha: 0.25),
                            width: 8),
                      ),
                      child: const Icon(PhosphorIconsBold.check,
                          size: 44, color: AppColors.mint),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Center(
                      child: Text(copy.title,
                          style: heading(size: 24, color: AppColors.mint))),
                  const SizedBox(height: 8),
                  Text(copy.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.45,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 26),
                  HomeCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      Row(children: [
                        ProductThumb(auction.cover, size: 56),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(auction.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                        color: AppColors.navy)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  AudienceChip(auction.audience),
                                  const SizedBox(width: 8),
                                  StatusPill(auction.status),
                                ]),
                              ]),
                        ),
                      ]),
                      const Divider(height: 22, color: AppColors.cardBorder),
                      SummaryRow(
                          'Start time', formatDateTime(auction.startsAt)),
                      SummaryRow(
                          'Starting price', formatInr(auction.startPrice)),
                      Row(children: [
                        const Expanded(
                            child: Text('Auction ID',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary))),
                        Text(auction.number,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: auction.number));
                            showAppToast(context, 'Auction ID copied');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(7)),
                            child: const Text('Copy',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: kAuctionBlue)),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
              AuctionButton(
                  label: 'View Auction',
                  onPressed: () {
                    context.go(Routes.auctions);
                    context.push(Routes.auctionDetail(auction.id));
                  }),
              const SizedBox(height: 10),
              AuctionButton(
                  label: 'Go to My Auctions',
                  outlined: true,
                  onPressed: () => context.go(Routes.auctions)),
            ]),
          ),
        ),
      ),
    );
  }
}
