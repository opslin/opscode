import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/campaigns/application/campaign_providers.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart';
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_sheets.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// One campaign: status, today's spend, results, products, keywords, history.
class CampaignDetailScreen extends ConsumerStatefulWidget {
  const CampaignDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<CampaignDetailScreen> createState() =>
      _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends ConsumerState<CampaignDetailScreen> {
  bool _busy = false;

  /// Runs a lifecycle/edit call, refreshes every list, and toasts server errors.
  Future<void> _run(Future<Object?> Function() call, {String? done}) async {
    setState(() => _busy = true);
    try {
      await call();
      if (!mounted) return;
      refreshCampaigns(ref, id: widget.id);
      if (done != null) showAppToast(context, done, bottom: 90);
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true, bottom: 90);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end(CampaignItem c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('End this campaign?'),
        content: const Text(
            'Your ads will stop for good and it cannot be restarted. Results and billing history stay in your account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Keep running')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('End campaign',
                  style: TextStyle(color: AppColors.rose))),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => ref.read(campaignRepositoryProvider).end(c.id),
          done: 'Campaign ended.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(campaignDetailProvider(widget.id));
    final repo = ref.read(campaignRepositoryProvider);

    return detail.when(skipLoadingOnReload: true, skipError: true, 
      loading: () => Scaffold(
          appBar: const AuctionAppBar(title: 'Campaign'),
          body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          appBar: const AuctionAppBar(title: 'Campaign'),
          body: ErrorState(
              message: errorText(e, 'Could not load this campaign.'),
              onRetry: () =>
                  ref.invalidate(campaignDetailProvider(widget.id)))),
      data: (d) {
        final c = d.item;
        final editable = c.status != CampaignStatus.ended;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AuctionAppBar(
            title: c.name,
            subtitle: c.number,
            actions: [
              if (editable)
                IconButton(
                    tooltip: 'Edit',
                    onPressed: () => showEditCampaignSheet(context, ref, d),
                    icon: const Icon(PhosphorIconsRegular.pencilSimple,
                        color: AppColors.navy)),
            ],
          ),
          bottomNavigationBar: _ActionBar(
              c: c,
              busy: _busy,
              onPause: () =>
                  _run(() => repo.pause(c.id), done: 'Campaign paused.'),
              onResume: () =>
                  _run(() => repo.resume(c.id), done: 'Campaign resumed.'),
              onSubmit: () => _run(() => repo.submit(c.id),
                  done: 'Submitted for approval.'),
              onEnd: () => _end(c)),
          body: RefreshIndicator(
            onRefresh: () async {
              refreshCampaigns(ref, id: widget.id);
              await ref
                  .read(campaignDetailProvider(widget.id).future)
                  .catchError((_) => d);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                _StatusHeader(
                    d: d, onAddMoney: () => context.push(Routes.adWallet)),
                const SizedBox(height: 14),
                _Results(id: widget.id, d: d),
                const SizedBox(height: 14),
                _Products(
                  d: d,
                  editable: editable,
                  onToggle: (p) => _run(() =>
                      repo.setProductPaused(c.id, p.productId, !p.paused)),
                  onRemove: (p) => _run(
                      () => repo.removeProduct(c.id, p.productId),
                      done: 'Product removed from this campaign.'),
                  onAdd: () => showAddProductsSheet(context, ref, d),
                ),
                if (c.targeting == Targeting.manual) ...[
                  const SizedBox(height: 14),
                  _Keywords(
                    d: d,
                    editable: editable,
                    onRemove: (k) => _run(() => repo.removeKeyword(c.id, k.id)),
                    onAdd: () => showAddKeywordsSheet(context, ref, d),
                  ),
                ],
                const SizedBox(height: 14),
                _Settings(c: c),
                const SizedBox(height: 14),
                _History(events: d.events),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── status ────────────────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.d, required this.onAddMoney});
  final CampaignDetail d;
  final VoidCallback onAddMoney;

  @override
  Widget build(BuildContext context) {
    final c = d.item;
    final st = campaignStatus(c.status);
    final outOfFunds =
        c.status == CampaignStatus.paused && c.pausedReason == 'OUT_OF_FUNDS';

    final (title, msg) = switch (c.status) {
      CampaignStatus.active => (
          'Your ads are live',
          'Shoppers can see your products in search results.'
        ),
      CampaignStatus.pending => (
          'Waiting for approval',
          'Dealkr is reviewing this campaign. It goes live once approved.'
        ),
      CampaignStatus.paused when outOfFunds => (
          'Paused — wallet is empty',
          'Add money to your ad wallet, then resume the campaign.'
        ),
      CampaignStatus.paused => (
          'Paused',
          'Your ads are not showing. Resume any time.'
        ),
      CampaignStatus.rejected => (
          'Rejected',
          c.rejectedReason?.isNotEmpty == true
              ? c.rejectedReason!
              : 'Fix the issue and submit again.'
        ),
      CampaignStatus.suspended => (
          'Suspended by Dealkr',
          c.suspendedReason?.isNotEmpty == true
              ? c.suspendedReason!
              : 'Contact support to find out why.'
        ),
      CampaignStatus.ended => (
          'Campaign ended',
          'This campaign has finished. Its results stay here.'
        ),
      _ => ('Draft', 'Submit this campaign for approval when you are ready.'),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(13)),
            child: Icon(st.icon, color: st.fg, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: heading(size: 16.5)),
              const SizedBox(height: 3),
              Text(msg,
                  style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary)),
            ]),
          ),
        ]),
        if (c.status == CampaignStatus.active ||
            c.status == CampaignStatus.paused) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: UsageBar(c.todayUsed, color: st.fg)),
            const SizedBox(width: 10),
            Text(
                '${formatInr(c.spentToday)} of ${formatInr(c.dailyBudget)} today',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ]),
        ],
        if (outOfFunds) ...[
          const SizedBox(height: 8),
          TextButton(
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
              onPressed: onAddMoney,
              child: const Text('Add money to ad wallet')),
        ],
      ]),
    );
  }
}

// ── results ───────────────────────────────────────────────────────────

class _Results extends ConsumerWidget {
  const _Results({required this.id, required this.d});
  final String id;
  final CampaignDetail d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(campaignReportProvider(id));
    return AdSection(
      title: 'Results',
      icon: PhosphorIconsFill.chartBar,
      trailing: const Text('Last 30 days',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      child: report.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4))),
        error: (e, _) => Row(children: [
          Expanded(
              child: Text(errorText(e, 'Could not load results.'),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13.5))),
          TextButton(
              onPressed: () => ref.invalidate(campaignReportProvider(id)),
              child: const Text('Retry')),
        ]),
        data: (r) {
          final t = r.totals;
          final hasData = t.impressions > 0 || t.clicks > 0;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Expanded(
                          child: StatTile(
                              label: 'Views',
                              value: compact(t.impressions),
                              icon: PhosphorIconsFill.eye)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: StatTile(
                              label: 'Clicks',
                              value: compact(t.clicks),
                              hint: hasData
                                  ? '${percent(t.ctr)} click rate'
                                  : null,
                              icon: PhosphorIconsFill.cursorClick,
                              color: AppColors.violet,
                              bg: AppColors.violetSoft)),
                    ])),
                const SizedBox(height: 10),
                IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Expanded(
                          child: StatTile(
                              label: 'Ad spend',
                              value: formatInr(t.spend),
                              hint: t.clicks > 0
                                  ? '${inr2(t.avgCpc)} per click'
                                  : 'before GST',
                              icon: PhosphorIconsFill.coins,
                              color: const Color(0xFFB45309),
                              bg: AppColors.amberSoft)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: StatTile(
                              label: 'Orders',
                              value: '${t.orders}',
                              hint: t.sales > 0
                                  ? '${formatInr(t.sales)} sales'
                                  : 'within ${r.attributionDays} days of a click',
                              icon: PhosphorIconsFill.shoppingBag,
                              color: AppColors.mint,
                              bg: AppColors.mintSoft)),
                    ])),
                if (t.roas != null) ...[
                  const SizedBox(height: 10),
                  AdNotice(
                    message:
                        'Every ₹1 spent on ads brought back ${inr2(t.roas!)} in sales (${percent(t.acos ?? 0)} of sales spent on ads).',
                    icon: PhosphorIconsFill.trendUp,
                    color: AppColors.mint,
                    bg: AppColors.mintSoft,
                  ),
                ],
                if (hasData) ...[
                  const SizedBox(height: 16),
                  Text('Clicks per day',
                      style: heading(
                          size: 13.5,
                          w: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  DailyBars(
                    values: [for (final s in r.daily) s.clicks],
                    labelFor: (i) =>
                        '${formatDay(r.daily[i].day, year: false)}: ${r.daily[i].clicks} clicks',
                  ),
                  const SizedBox(height: 6),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatDay(r.daily.first.day, year: false),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                        Text('Today',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ]),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: Text(
                        'Results appear here once your ads start getting views.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textMuted)),
                  ),
              ]);
        },
      ),
    );
  }
}

// ── products ──────────────────────────────────────────────────────────

class _Products extends StatelessWidget {
  const _Products(
      {required this.d,
      required this.editable,
      required this.onToggle,
      required this.onRemove,
      required this.onAdd});
  final CampaignDetail d;
  final bool editable;
  final ValueChanged<CampaignProduct> onToggle;
  final ValueChanged<CampaignProduct> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => AdSection(
        title: 'Products (${d.products.length})',
        icon: PhosphorIconsFill.cube,
        trailing: editable
            ? GestureDetector(
                onTap: onAdd,
                child: const Text('+ Add',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, color: kAdBlue)))
            : null,
        child: d.products.isEmpty
            ? const Text(
                'No products yet — add at least one to run this campaign.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.5))
            : Column(children: [
                for (final (i, p) in d.products.indexed) ...[
                  if (i > 0) const Divider(height: 20),
                  Row(children: [
                    Opacity(
                        opacity: p.paused ? 0.5 : 1,
                        child: ProductThumb(p.thumbnail, size: 50, radius: 10)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25)),
                            const SizedBox(height: 3),
                            Text(
                                p.paused
                                    ? 'Paused in this campaign'
                                    : '${compact(p.clicks)} clicks  ·  ${formatInr(p.spend)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: p.paused
                                        ? const Color(0xFFB45309)
                                        : AppColors.textSecondary)),
                            if (p.stock == 0)
                              const Padding(
                                padding: EdgeInsets.only(top: 3),
                                child: Text('Out of stock — ads are not shown',
                                    style: TextStyle(
                                        fontSize: 12, color: AppColors.rose)),
                              ),
                          ]),
                    ),
                    if (editable)
                      PopupMenuButton<String>(
                        icon: const Icon(PhosphorIconsRegular.dotsThreeVertical,
                            color: AppColors.textSecondary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        onSelected: (v) =>
                            v == 'remove' ? onRemove(p) : onToggle(p),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'toggle',
                              child:
                                  Text(p.paused ? 'Resume ads' : 'Pause ads')),
                          const PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove',
                                  style: TextStyle(color: AppColors.rose))),
                        ],
                      ),
                  ]),
                ],
              ]),
      );
}

// ── keywords ──────────────────────────────────────────────────────────

class _Keywords extends StatelessWidget {
  const _Keywords(
      {required this.d,
      required this.editable,
      required this.onRemove,
      required this.onAdd});
  final CampaignDetail d;
  final bool editable;
  final ValueChanged<CampaignKeyword> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => AdSection(
        title: 'Keywords (${d.keywords.where((k) => !k.negative).length})',
        icon: PhosphorIconsFill.magnifyingGlass,
        trailing: editable
            ? GestureDetector(
                onTap: onAdd,
                child: const Text('+ Add',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, color: kAdBlue)))
            : null,
        child: d.keywords.isEmpty
            ? const Text(
                'No keywords yet — keyword campaigns need at least one.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.5))
            : Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in d.keywords)
                  Container(
                    padding: EdgeInsets.fromLTRB(12, 6, editable ? 6 : 12, 6),
                    decoration: BoxDecoration(
                      color: k.negative ? AppColors.roseSoft : kAdBlueSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                        child: Text('${k.negative ? '− ' : ''}${k.keyword}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: k.negative ? AppColors.rose : kAdBlue)),
                      ),
                      const SizedBox(width: 6),
                      Text(k.matchType.toLowerCase(),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                      if (editable)
                        GestureDetector(
                          onTap: () => onRemove(k),
                          child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(PhosphorIconsBold.x,
                                  size: 13, color: AppColors.textSecondary)),
                        ),
                    ]),
                  ),
              ]),
      );
}

// ── settings + history ────────────────────────────────────────────────

class _Settings extends StatelessWidget {
  const _Settings({required this.c});
  final CampaignItem c;

  @override
  Widget build(BuildContext context) => AdSection(
        title: 'Campaign settings',
        icon: PhosphorIconsFill.slidersHorizontal,
        child: Column(children: [
          SummaryRow('Targeting', c.targeting.label),
          SummaryRow('Runs', dateRange(c.startsOn, c.endsOn)),
          SummaryRow('Daily budget', formatInr(c.dailyBudget)),
          SummaryRow(
              'Total budget',
              c.totalBudget == null
                  ? 'No overall limit'
                  : formatInr(c.totalBudget!)),
          SummaryRow('Max cost per click', inr2(c.defaultBid)),
        ]),
      );
}

const _eventLabels = {
  'CREATED': 'Campaign created',
  'SUBMITTED': 'Submitted for review',
  'ACTIVATED': 'Went live',
  'APPROVED': 'Approved by Dealkr',
  'REJECTED': 'Rejected by Dealkr',
  'PAUSED': 'Paused',
  'RESUMED': 'Resumed',
  'ENDED': 'Ended',
  'SUSPENDED': 'Suspended by Dealkr',
  'UNSUSPENDED': 'Suspension lifted',
  'UPDATED': 'Details updated',
  'PRODUCTS_ADDED': 'Products added',
  'PRODUCT_UPDATED': 'Product updated',
  'PRODUCT_REMOVED': 'Product removed',
  'KEYWORDS_ADDED': 'Keywords added',
  'KEYWORD_UPDATED': 'Keyword updated',
  'KEYWORD_REMOVED': 'Keyword removed',
};

String _eventLabel(String e) =>
    _eventLabels[e] ??
    (e.isEmpty
        ? ''
        : '${e[0]}${e.substring(1).toLowerCase().replaceAll('_', ' ')}');

class _History extends StatelessWidget {
  const _History({required this.events});
  final List<CampaignEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return AdSection(
      title: 'Activity',
      icon: PhosphorIconsFill.clockCounterClockwise,
      child: Column(children: [
        for (final e in events.take(8))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: kAdBlue, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(_eventLabel(e.event),
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600))),
              Text(timeAgo(e.at),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
      ]),
    );
  }
}

// ── bottom bar ────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.c,
    required this.busy,
    required this.onPause,
    required this.onResume,
    required this.onSubmit,
    required this.onEnd,
  });
  final CampaignItem c;
  final bool busy;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSubmit;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final Widget? child = switch (c.status) {
      CampaignStatus.active => Row(children: [
          Expanded(
              child: AuctionButton(
                  label: 'Pause',
                  icon: PhosphorIconsBold.pause,
                  outlined: true,
                  loading: busy,
                  onPressed: onPause)),
          const SizedBox(width: 10),
          Expanded(
              child: AuctionButton(
                  label: 'End',
                  danger: true,
                  outlined: true,
                  onPressed: busy ? null : onEnd)),
        ]),
      CampaignStatus.paused => Row(children: [
          Expanded(
              flex: 3,
              child: AuctionButton(
                  label: 'Resume',
                  icon: PhosphorIconsBold.play,
                  loading: busy,
                  onPressed: onResume)),
          const SizedBox(width: 10),
          Expanded(
              flex: 2,
              child: AuctionButton(
                  label: 'End',
                  danger: true,
                  outlined: true,
                  onPressed: busy ? null : onEnd)),
        ]),
      CampaignStatus.draft || CampaignStatus.rejected => AuctionButton(
          label: c.status == CampaignStatus.rejected
              ? 'Fix & submit again'
              : 'Submit for approval',
          trailing: PhosphorIconsBold.arrowRight,
          loading: busy,
          onPressed: onSubmit),
      CampaignStatus.pending => AuctionButton(
          label: 'End campaign',
          danger: true,
          outlined: true,
          onPressed: busy ? null : onEnd),
      _ => null,
    };
    if (child == null) return const SizedBox.shrink();
    return BottomActionBar(child: child);
  }
}
