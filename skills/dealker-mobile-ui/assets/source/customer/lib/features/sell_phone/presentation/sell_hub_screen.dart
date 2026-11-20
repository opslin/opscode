import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/features/sell_phone/data/sell_models.dart';
import 'package:dealker_app/features/sell_phone/data/sell_repository.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_providers.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_ui.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';

/// "Sell your phone": a friendly start page — what this is, 4 simple steps, and the customer's sales
/// with a plain sentence saying what is happening to each one.
class SellHubScreen extends ConsumerStatefulWidget {
  const SellHubScreen({super.key});

  @override
  ConsumerState<SellHubScreen> createState() => _SellHubScreenState();
}

class _SellHubScreenState extends ConsumerState<SellHubScreen>
    with WidgetsBindingObserver {
  bool _showAll = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // New offers and chat messages arrive while this page is open: keep the cards current.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.invalidate(mySalesProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(mySalesProvider);
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static const int _preview = 3;

  static const List<(String, String, String)> _steps = <(String, String, String)>[
    ('Tell us about your phone', 'Pick the model and say how it looks. Takes one minute.', SellArt.tell),
    ('Buyers send offers', 'Trusted buyers near you see your phone and make offers. We tell you when one comes.', SellArt.offer),
    ('Pick the best price', 'You choose the offer you like. We collect your phone from your home.', SellArt.courier),
    ('Get your money', 'The buyer checks your phone. Then your money is sent to you.', SellArt.paid),
  ];

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<SellListItem>> sales = ref.watch(mySalesProvider);
    final AsyncValue<SellConfig> cfg = ref.watch(sellConfigProvider);
    final bool enabled = cfg.asData?.value.enabled ?? true;
    return SellScaffold(
      title: 'Sell your phone',
      onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      bottom: SellButton(
        'Sell my phone',
        icon: Icons.add_rounded,
        onPressed: enabled ? () => context.push('/sell/new') : null,
      ),
      child: RefreshIndicator(
        color: ReturnColors.indigo,
        onRefresh: () async {
          ref
            ..invalidate(sellConfigProvider)
            ..invalidate(mySalesProvider);
          await ref.read(mySalesProvider.future);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
          children: <Widget>[
            _hero(),
            if (!enabled) ...<Widget>[
              SizedBox(height: 12.h),
              const SellInlineMessage(
                'Selling is paused for now. Please come back a little later.',
                tone: SellTone.warn,
              ),
            ],
            SizedBox(height: 20.h),
            sales.when(
              loading: () => Padding(
                padding: EdgeInsets.all(24.w),
                child: const DealkerPageLoader(),
              ),
              error: (Object e, _) => Column(
                children: <Widget>[
                  Text(sellErrorMessage(e, 'Could not load your sales.'), style: sellBody(13.5)),
                  TextButton(
                    onPressed: () => ref.invalidate(mySalesProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ),
              data: (List<SellListItem> all) => all.isEmpty
                  ? _howItWorks()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _listings(all),
                        SizedBox(height: 24.h),
                        _howItWorks(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── hero ─────────────────────────────────────────────────────────────────

  Widget _hero() => Container(
        padding: EdgeInsets.fromLTRB(18.w, 18.h, 8.w, 18.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF001F5F), Color(0xFF0B3A8C)],
          ),
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Sell your old phone', style: sellHead(23, color: Colors.white)),
                  SizedBox(height: 6.h),
                  Text(
                    'Get the best price from trusted buyers near you. We pick up your phone from your home.',
                    style: sellBody(13.5, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  SizedBox(height: 12.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: const <Widget>[
                      _Pill('Free pickup'),
                      _Pill('Safe payment'),
                    ],
                  ),
                ],
              ),
            ),
            SellImage(SellArt.hero, size: 118.w),
          ],
        ),
      );

  // ── how it works ─────────────────────────────────────────────────────────

  Widget _howItWorks() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('How it works', style: sellHead(19)),
          SizedBox(height: 12.h),
          for (int i = 0; i < _steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: SellCard(
                padding: EdgeInsets.all(12.w),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 66.w,
                      height: 66.w,
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: ReturnColors.indigoSoft,
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      child: Image.asset(_steps[i].$3, fit: BoxFit.contain),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                width: 22.w,
                                height: 22.w,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(color: ReturnColors.indigo, shape: BoxShape.circle),
                                child: Text('${i + 1}', style: sellHead(11.5, color: Colors.white)),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(child: Text(_steps[i].$1, style: sellHead(15))),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(_steps[i].$2, style: sellBody(13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 4.h),
          SellCard(
            tint: const Color(0xFFFFF8E1),
            border: const Color(0xFFFFE08A),
            padding: EdgeInsets.all(14.w),
            child: Row(
              children: <Widget>[
                SellImage(SellArt.shield, size: 48.w),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Your money is safe. The buyer pays Dealkr first, and we pay you after the buyer checks your phone.',
                    style: sellBody(13.5, color: ReturnColors.ink, w: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  // ── listings ─────────────────────────────────────────────────────────────

  Widget _listings(List<SellListItem> all) {
    final List<SellListItem> list = _showAll ? all : all.take(_preview).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text('Your phones', style: sellHead(19))),
            if (all.length > _preview)
              TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll ? 'Show less' : 'See all ${all.length}',
                  style: sellBody(14, color: ReturnColors.indigo, w: FontWeight.w800),
                ),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        ...list.map(
          (SellListItem s) => Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _isActive(s) ? _activeCard(s) : _compactCard(s),
          ),
        ),
      ],
    );
  }

  String _day(DateTime? d) => d == null ? '' : DateFormat('d MMM yyyy').format(d.toLocal());

  bool _isActive(SellListItem s) =>
      const <String>['PENDING', 'IN_PROGRESS', 'APPROVED'].contains(s.status);

  void _open(SellListItem s) => context
      .push(
        s.stage == 'LISTED' && s.status == 'PENDING' ? '/sell/${s.id}/offers' : '/sell/${s.id}',
      )
      .then((_) => ref.invalidate(mySalesProvider));

  Widget _photo(SellListItem s, double size) {
    final String? url = ApiConstants.resolveMediaUrl(s.imageUrl);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ReturnColors.indigoSoft,
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.all(size * 0.1),
      child: url == null
          ? Image.asset(SellArt.tell, fit: BoxFit.contain)
          : CachedNetworkImage(
              imageUrl: webImageSource(url),
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => Image.asset(SellArt.tell, fit: BoxFit.contain),
            ),
    );
  }

  /// A sale still in play: phone, price, a plain sentence about what is happening, and one clear button.
  Widget _activeCard(SellListItem s) {
    final bool collecting = s.stage == 'LISTED' || s.stage == null;
    final SellGuide g = sellGuide(stage: s.stage, status: s.status, offers: s.offerCount, offersOpen: s.offersOpen);
    final double price = collecting ? (s.askingPrice ?? s.quote) : (s.finalPrice ?? s.askingPrice ?? s.quote);
    final Color tone = g.needsAction ? const Color(0xFF8A5A00) : ReturnColors.indigo;
    return InkWell(
      borderRadius: BorderRadius.circular(20.r),
      onTap: () => _open(s),
      child: SellCard(
        padding: EdgeInsets.all(14.w),
        border: g.needsAction ? kSellGold : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _photo(s, 70.w),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        deviceTitle(s.model, s.variant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: sellHead(15.5),
                      ),
                      SizedBox(height: 3.h),
                      Text('${inr(price)} · ${collecting ? 'your price' : 'agreed price'}', style: sellBody(13, color: ReturnColors.ink, w: FontWeight.w700)),
                      SizedBox(height: 2.h),
                      Text(_day(s.createdAt), style: sellBody(11.5)),
                    ],
                  ),
                ),
                if (s.unreadMessages > 0) _messagesChip(s.unreadMessages),
              ],
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: g.needsAction ? const Color(0xFFFFF6D6) : kSellCanvas,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Row(
                children: <Widget>[
                  SellImage(g.art, size: 40.w),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(g.title, style: sellHead(14, color: tone)),
                        SizedBox(height: 2.h),
                        Text(
                          g.needsAction ? 'Tap to continue' : 'Nothing to do now',
                          style: sellBody(12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: tone, size: 24.sp),
                ],
              ),
            ),
            if (collecting && s.bestOffer != null) ...<Widget>[
              SizedBox(height: 8.h),
              Text.rich(
                TextSpan(children: <InlineSpan>[
                  TextSpan(text: 'Highest offer so far: ', style: sellBody(12.5)),
                  TextSpan(text: inr(s.bestOffer!), style: sellHead(14, color: ReturnColors.green)),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _messagesChip(int n) => Container(
        padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
        decoration: BoxDecoration(color: ReturnColors.redSoft, borderRadius: BorderRadius.circular(10.r)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.chat_bubble_rounded, size: 12.sp, color: ReturnColors.red),
            SizedBox(width: 5.w),
            Text('$n new', style: sellBody(11.5, color: ReturnColors.red, w: FontWeight.w800)),
          ],
        ),
      );

  /// Finished / closed sales: one tight row.
  Widget _compactCard(SellListItem s) {
    final Color c = stageColor(s.stage, s.status);
    final double price = s.finalPrice ?? s.askingPrice ?? s.quote;
    return InkWell(
      borderRadius: BorderRadius.circular(18.r),
      onTap: () => _open(s),
      child: SellCard(
        padding: EdgeInsets.all(10.w),
        child: Row(
          children: <Widget>[
            _photo(s, 52.w),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(deviceTitle(s.model, s.variant), maxLines: 1, overflow: TextOverflow.ellipsis, style: sellHead(14)),
                  SizedBox(height: 2.h),
                  Text(_day(s.createdAt), style: sellBody(11.5)),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(inr(price), style: sellHead(14)),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10.r)),
                  child: Text(
                    s.stage == 'PAID' ? 'Completed' : stageLabel(s.stage, s.status),
                    style: sellBody(10.5, color: c, w: FontWeight.w800),
                  ),
                ),
              ],
            ),
            Icon(Icons.chevron_right_rounded, size: 20.sp, color: ReturnColors.muted),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_circle_rounded, size: 14.sp, color: kSellGold),
            SizedBox(width: 5.w),
            Text(text, style: sellBody(11.5, color: Colors.white, w: FontWeight.w700)),
          ],
        ),
      );
}
