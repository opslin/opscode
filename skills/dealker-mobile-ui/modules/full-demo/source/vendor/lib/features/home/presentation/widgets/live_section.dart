import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/home/application/home_providers.dart';
import 'package:dealker_vendor/features/home/data/home_models.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';

class LiveAuctionsAndCampaigns extends ConsumerWidget {
  const LiveAuctionsAndCampaigns({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auctions = ref.watch(liveAuctionsProvider);
    final campaigns = ref.watch(activeCampaignsProvider);

    final cards = <Widget>[];
    String? error;
    var loading = false;

    auctions.when(skipLoadingOnReload: true, skipError: true, 
      loading: () => loading = true,
      error: (e, _) =>
          error = e is Failure ? e.message : 'Could not load auctions.',
      data: (list) => cards.addAll(list.map((a) => _AuctionCard(a))),
    );
    campaigns.when(skipLoadingOnReload: true, skipError: true, 
      loading: () => loading = true,
      error: (e, _) =>
          error ??= e is Failure ? e.message : 'Could not load campaigns.',
      data: (list) => cards.addAll(list.map((c) => _CampaignCard(c))),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'Live auctions & campaigns',
          onViewAll: () => context.go(Routes.auctions),
        ),
        const SizedBox(height: 10),
        if (loading && cards.isEmpty)
          const Row(children: [
            Expanded(child: SkeletonBox(height: 150)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 150))
          ])
        else if (cards.isEmpty && error != null)
          InlineError(
            message: error!,
            onRetry: () => ref
              ..invalidate(liveAuctionsProvider)
              ..invalidate(activeCampaignsProvider),
          )
        else if (cards.isEmpty)
          const HomeCard(
              child: EmptyLine('No live auctions or campaigns right now.'))
        else
          SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 42) / 2,
                  child: cards[i]),
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.text, this.fg, this.bg);
  final IconData icon;
  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 3),
            Text(text,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    letterSpacing: 0.2)),
          ],
        ),
      );
}

class _CtaBar extends StatelessWidget {
  const _CtaBar(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 34,
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label,
                  style: heading(
                      size: 12.5, color: Colors.white, w: FontWeight.w600)),
              const Icon(Icons.chevron_right, size: 16, color: Colors.white),
            ],
          ),
        ),
      );
}

class _AuctionCard extends StatelessWidget {
  const _AuctionCard(this.a);
  final AuctionRow a;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      color: const Color(0xFFFFF1F1),
      border: const Color(0xFFFFD5D5),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 50,
                    height: 64,
                    color: const Color(0xFFF1F2F8),
                    child: a.imageUrl == null || a.imageUrl!.isEmpty
                        ? const Icon(PhosphorIconsRegular.image,
                            color: AppColors.textMuted)
                        : CachedNetworkImage(
                            imageUrl: a.imageUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 200,
                            fadeInDuration: const Duration(milliseconds: 120),
                            placeholder: (_, __) => const SizedBox.shrink(),
                            errorWidget: (_, __, ___) => const Icon(
                                PhosphorIconsRegular.image,
                                color: AppColors.textMuted)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Badge(PhosphorIconsFill.circle, 'LIVE',
                          Colors.white, AppColors.countdownRed),
                      const SizedBox(height: 4),
                      Text(a.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: heading(size: 13.5)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(PhosphorIconsRegular.users,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text('${a.bidCount} bids',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                      if (a.endsAt != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(PhosphorIconsRegular.timer,
                                size: 13, color: AppColors.countdownRed),
                            const SizedBox(width: 3),
                            Countdown(
                                endsAt: a.endsAt!,
                                style: heading(
                                    size: 11, color: AppColors.countdownRed)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _CtaBar(PhosphorIconsFill.gavel, 'Manage Auction',
              () => context.push(Routes.auctionDetail(a.id))),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard(this.c);
  final CampaignRow c;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      color: const Color(0xFFF5EEFF),
      border: const Color(0xFFE2D2FF),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Badge(PhosphorIconsFill.lightning, 'AD CAMPAIGN',
              Color(0xFF7C3AED), Color(0xFFF1E8FF)),
          const SizedBox(height: 6),
          Text(c.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: heading(size: 14.5)),
          const SizedBox(height: 4),
          Text(
            '${formatInr(c.spentToday)} of ${formatInr(c.dailyBudget)} today',
            style:
                const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const Spacer(),
          _CtaBar(PhosphorIconsRegular.play, 'View Campaign',
              () => context.push(Routes.campaignDetail(c.id))),
        ],
      ),
    );
  }
}
