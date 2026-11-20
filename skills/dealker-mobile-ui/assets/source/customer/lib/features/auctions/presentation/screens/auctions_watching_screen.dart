import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/features/auctions/application/auction_browse.dart';
import 'package:dealker_app/features/auctions/data/auction_view.dart';
import 'package:dealker_app/features/auctions/presentation/widgets/auction_actions.dart';
import 'package:dealker_app/features/auctions/presentation/widgets/auction_cards.dart';
import 'package:dealker_app/features/auctions/presentation/widgets/auction_ui.dart';

/// Auctions the customer is watching (the heart in the Auctions app bar).
class AuctionsWatchingScreen extends ConsumerWidget {
  const AuctionsWatchingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AuctionView>> list =
        ref.watch(auctionWatchingProvider);
    final AuctionActions actions =
        buildAuctionActions(context, ref, refresh: () async {
      ref.invalidate(auctionWatchingProvider);
      await ref.read(auctionBrowseProvider.notifier).refresh();
    });
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft, color: AU.ink),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/auctions')),
        title: Text('Watching', style: jakarta(18.sp)),
      ),
      body: list.when(
        loading: () =>
            const DealkerPageLoader(),
        error: (Object e, _) => StateView(
          art: const CloudArt(offline: false),
          title: "Couldn't load auctions",
          body: 'Please check your connection and try again.',
          button: StateButton(
              label: 'Retry',
              icon: PhosphorIconsRegular.arrowClockwise,
              onTap: () => ref.invalidate(auctionWatchingProvider)),
        ),
        data: (List<AuctionView> items) => items.isEmpty
            ? StateView(
                art: const EmptyBoxArt(),
                title: 'Nothing watched yet',
                body:
                    'Tap the heart on an auction to keep an eye on it. We remind you when it starts and when it is about to end.',
                button: StateButton(
                    label: 'Browse auctions',
                    onTap: () => context.go('/auctions')),
              )
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(auctionWatchingProvider.future),
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (_, int i) =>
                      AuctionRowCard(a: items[i], actions: actions),
                ),
              ),
      ),
    );
  }
}
