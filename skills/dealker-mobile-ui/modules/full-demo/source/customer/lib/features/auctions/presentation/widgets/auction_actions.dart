import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/auctions/application/auction_browse.dart';
import 'package:dealker_app/features/auctions/data/auction_view.dart';
import 'package:dealker_app/features/auctions/presentation/widgets/auction_cards.dart';
import 'package:dealker_app/features/auctions/presentation/widgets/auction_ui.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_gate_controller.dart';

/// Wires the card buttons to real calls. [refresh] runs after something changed on the server.
AuctionActions buildAuctionActions(BuildContext context, WidgetRef ref,
    {required Future<void> Function() refresh}) {
  Future<bool> login(String what) =>
      ref.read(authGateControllerProvider).protectRoute(
            context,
            route: '/auctions',
            title: 'Log in to $what',
            message: 'Please log in to take part in auctions.',
          );

  Future<void> open(AuctionView a) async {
    await context.push('/auctions/${a.id}');
    await refresh();
  }

  return AuctionActions(
    open: (AuctionView a) => open(a),
    // Joining needs the consent + fee screen on the detail page.
    register: (AuctionView a) => open(a),
    expired: () => refresh(),
    watch: (AuctionView a) async {
      if (!await login('watch auctions') || !context.mounted) return;
      final bool ok =
          await ref.read(auctionBrowseProvider.notifier).toggleWatch(a.id);
      if (!context.mounted) return;
      if (!ok) {
        AppToast.show(context, 'Could not update. Please try again.');
      } else if (a.isUpcoming && !a.watching) {
        AppToast.show(context, "We'll remind you when it starts.");
      }
    },
    bid: (AuctionView a) async {
      if (!await login('place a bid') || !context.mounted) return;
      final num? next = a.minNextBid;
      if (next == null) return;
      final bool yes = await showModalBottomSheet<bool>(
            context: context,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(22.r))),
            builder: (BuildContext c) => Padding(
              padding: EdgeInsets.fromLTRB(
                  20.w, 20.h, 20.w, 20.h + MediaQuery.paddingOf(c).bottom),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Confirm your bid', style: jakarta(19.sp)),
                    SizedBox(height: 6.h),
                    Text('${inr(next)} on ${a.title}',
                        style: dm(14.sp, color: AU.ink, w: FontWeight.w600)),
                    SizedBox(height: 6.h),
                    Text(
                        "You'll lead unless another bidder already has a higher maximum. You can raise your bid on the auction page.",
                        style: dm(13.sp, h: 1.4)),
                    SizedBox(height: 18.h),
                    StateButton(
                        label: 'Place bid ${inr(next)}',
                        onTap: () => Navigator.pop(c, true)),
                    SizedBox(height: 6.h),
                    Center(
                        child: TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text('Cancel',
                                style: dm(14.sp,
                                    color: AU.muted, w: FontWeight.w700)))),
                  ]),
            ),
          ) ??
          false;
      if (!yes || !context.mounted) return;
      try {
        final bool leading =
            await ref.read(auctionRepositoryProvider).bid(a.id, next);
        if (context.mounted) {
          AppToast.show(
              context,
              leading
                  ? 'You are the highest bidder'
                  : 'Bid placed, but someone has a higher maximum. Bid higher to lead.');
        }
      } catch (e) {
        if (context.mounted) AppToast.show(context, _message(e));
      }
      await refresh();
    },
  );
}

String _message(Object e) {
  try {
    final dynamic d = (e as dynamic).response?.data;
    if (d is Map && d['message'] is String) return d['message'] as String;
  } catch (_) {}
  return 'Could not place the bid. Please try again.';
}

/// Radio-style bottom sheet; returns the picked value (null = dismissed, [clear] = cleared).
Future<T?> pickOne<T>(BuildContext context,
    {required String title,
    required List<({T value, String label, String? trailing})> options,
    T? selected,
    String? clearLabel}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r))),
    builder: (BuildContext c) => SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .7),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 6.h),
                  child: Text(title, style: jakarta(18.sp))),
              Flexible(
                child: ListView(shrinkWrap: true, children: <Widget>[
                  for (final ({T value, String label, String? trailing}) o
                      in options)
                    ListTile(
                      title: Text(o.label,
                          style: dm(15.sp,
                              color: AU.ink,
                              w: o.value == selected
                                  ? FontWeight.w800
                                  : FontWeight.w600)),
                      trailing: o.value == selected
                          ? const Icon(Icons.check_rounded, color: AU.indigo)
                          : (o.trailing == null
                              ? null
                              : Text(o.trailing!, style: dm(13.sp))),
                      onTap: () => Navigator.pop(c, o.value),
                    ),
                ]),
              ),
              if (clearLabel != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
                  child: TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text(clearLabel,
                          style:
                              dm(14.sp, color: AU.muted, w: FontWeight.w700))),
                ),
            ]),
      ),
    ),
  );
}

Future<void> showFeePolicy(BuildContext context, String policy) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r))),
      builder: (BuildContext c) => Padding(
        padding: EdgeInsets.fromLTRB(
            20.w, 20.h, 20.w, 24.h + MediaQuery.paddingOf(c).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Registration fee policy', style: jakarta(18.sp)),
              SizedBox(height: 10.h),
              Text(policy,
                  style: dm(14.sp, color: const Color(0xFF3F4663), h: 1.5)),
            ]),
      ),
    );
