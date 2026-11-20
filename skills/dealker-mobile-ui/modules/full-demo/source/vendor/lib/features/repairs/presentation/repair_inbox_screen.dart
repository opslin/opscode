import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show AuctionButton, ErrorState, errorText;
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/features/repairs/application/repairs_providers.dart';
import 'package:dealker_vendor/features/repairs/data/repair_models.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/shared/widgets/premium_ui.dart';

enum _Tab { all, pending, accepted, rejected }

enum _Sort { newest, nearest }

/// Step 1 of the mockup — "Repair Requests: manage incoming repair orders" with Accept / Reject on every card.
class RepairInboxScreen extends ConsumerStatefulWidget {
  const RepairInboxScreen({super.key});

  @override
  ConsumerState<RepairInboxScreen> createState() => _RepairInboxScreenState();
}

class _RepairInboxScreenState extends ConsumerState<RepairInboxScreen> {
  _Tab _tab = _Tab.pending;
  _Sort _sort = _Sort.newest;
  num? _maxKm;
  String _q = '';

  Future<void> _reject(IncomingRequest r) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => const _RejectSheet(),
    );
    if (reason == null) return;
    try {
      await ref.read(repairsRepositoryProvider).decline(r.id, reason: reason);
      refreshRepairs(ref, id: r.id);
      if (mounted)
        showAppToast(
            context, 'Request rejected. You can find it under Rejected.');
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    }
  }

  Future<void> _reconsider(IncomingRequest r) async {
    try {
      await ref.read(repairsRepositoryProvider).undecline(r.id);
      refreshRepairs(ref, id: r.id);
      if (mounted) showAppToast(context, 'Moved back to Pending.');
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    }
  }

  List<IncomingRequest> _filter(List<IncomingRequest> list) {
    var out = list.where((r) {
      if (_maxKm != null && (r.distanceKm ?? 0) > _maxKm!) return false;
      if (_q.isEmpty) return true;
      final hay =
          '${r.firstName} ${r.code} ${r.items.map((i) => i.name).join(' ')}'
              .toLowerCase();
      return hay.contains(_q.toLowerCase());
    }).toList();
    if (_sort == _Sort.nearest) {
      out.sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
    }
    return out;
  }

  List<JobRow> _filterJobs(List<JobRow> list) => list.where((j) {
        if (_q.isEmpty) return true;
        return '${j.customerName} ${j.code} ${j.device}'
            .toLowerCase()
            .contains(_q.toLowerCase());
      }).toList();

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(incomingProvider('all'));
    final counts = pending.value?.counts ?? const IncomingCounts();
    final wantRejected = _tab == _Tab.rejected;
    final wantJobs = _tab == _Tab.accepted || _tab == _Tab.all;
    final rejected =
        wantRejected ? ref.watch(incomingProvider('rejected')) : null;
    final active = wantJobs ? ref.watch(jobsProvider('active')) : null;
    final done =
        _tab == _Tab.accepted ? ref.watch(jobsProvider('completed')) : null;

    return Scaffold(
      backgroundColor: RC.canvas,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: DealkrHeader(
            bellCount: counts.pending,
            onBell: () => setState(() => _tab = _Tab.pending)),
      ),
      bottomNavigationBar: const RepairBottomNav(),
      body: RefreshIndicator(
        onRefresh: () async => refreshRepairs(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            HeroBanner(
              title: 'Repair Requests',
              subtitle: 'Customers near you need repairs. Send a quote and win the job.',
              art: A3.repair('technician'),
              colors: const [Color(0xFF3D8BFF), Color(0xFF1B5FE8)],
              artSize: 120,
              cta: HeroButton('My repair prices',
                  icon: PhosphorIconsFill.tag,
                  color: RC.blueDark,
                  onTap: () => context.push(Routes.repairPrices)),
            ),
            const SizedBox(height: 14),
            _SendRepairCard(
              onSend: () => context.push('/repair/new'),
              onMine: () => context.push('/repair/mine'),
            ),
            const SizedBox(height: 14),
            _Stats(counts, _tab, (t) => setState(() => _tab = t)),
            const SizedBox(height: 14),
            _Tabs(_tab, (t) => setState(() => _tab = t)),
            const SizedBox(height: 12),
            _Filters(
              onSearch: (v) => setState(() => _q = v),
              sort: _sort,
              onSort: (s) => setState(() => _sort = s),
              maxKm: _maxKm,
              onKm: (k) => setState(() => _maxKm = k),
            ),
            const SizedBox(height: 12),
            ..._content(pending, rejected, active, done),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(
    AsyncValue<IncomingPage> pending,
    AsyncValue<IncomingPage>? rejected,
    AsyncValue<List<JobRow>>? active,
    AsyncValue<List<JobRow>>? done,
  ) {
    Widget wrap(Widget w) => SizedBox(height: 360, child: w);
    Widget err(Object e, VoidCallback retry) => wrap(ErrorState(
        message: errorText(e, 'Could not load requests.'), onRetry: retry));
    const spin = SizedBox(
        height: 200, child: Center(child: CircularProgressIndicator()));

    switch (_tab) {
      case _Tab.pending:
        return pending.when(skipLoadingOnReload: true, skipError: true, 
          loading: () => [spin],
          error: (e, _) =>
              [err(e, () => ref.invalidate(incomingProvider('all')))],
          data: (p) => _requestList(_filter(p.items), _Tab.pending),
        );
      case _Tab.rejected:
        return rejected!.when(skipLoadingOnReload: true, skipError: true, 
          loading: () => [spin],
          error: (e, _) =>
              [err(e, () => ref.invalidate(incomingProvider('rejected')))],
          data: (p) => _requestList(_filter(p.items), _Tab.rejected),
        );
      case _Tab.accepted:
        final rows = [...?active?.value, ...?done?.value];
        if ((active!.isLoading && !active.hasValue) || (done!.isLoading && !done.hasValue)) return [spin];
        if (active.hasError)
          return [
            err(active.error!, () => ref.invalidate(jobsProvider('active')))
          ];
        return _jobList(_filterJobs(rows));
      case _Tab.all:
        if ((pending.isLoading && !pending.hasValue) || (active!.isLoading && !active.hasValue)) return [spin];
        if (pending.hasError)
          return [
            err(pending.error!, () => ref.invalidate(incomingProvider('all')))
          ];
        final reqs = _filter(pending.value?.items ?? const []);
        final jobs = _filterJobs(active.value ?? const []);
        if (reqs.isEmpty && jobs.isEmpty) return _empty(_Tab.all);
        return [
          for (final r in reqs)
            _RequestCard(r, onReject: () => _reject(r), onReconsider: null),
          for (final j in jobs) _JobCard(j),
        ];
    }
  }

  List<Widget> _requestList(List<IncomingRequest> list, _Tab tab) {
    if (list.isEmpty) return _empty(tab);
    return [
      for (final r in list)
        _RequestCard(r,
            onReject: tab == _Tab.rejected ? null : () => _reject(r),
            onReconsider: tab == _Tab.rejected ? () => _reconsider(r) : null),
    ];
  }

  List<Widget> _jobList(List<JobRow> list) => list.isEmpty
      ? _empty(_Tab.accepted)
      : [for (final j in list) _JobCard(j)];

  List<Widget> _empty(_Tab tab) {
    final (title, msg) = switch (tab) {
      _Tab.pending => (
          'No new repair requests',
          'When a customer near you needs a repair, it shows up here. Make sure your prices are set so you can quote fast.'
        ),
      _Tab.accepted => (
          'No accepted repairs yet',
          'Repairs customers give to your shop will appear here.'
        ),
      _Tab.rejected => (
          'Nothing rejected',
          'Requests you reject are kept here in case you change your mind.'
        ),
      _Tab.all => (
          'No repair requests',
          'New requests and your running repairs will appear here.'
        ),
    };
    return [
      ArtEmpty(
        art: switch (tab) {
          _Tab.accepted => A3.repair('repaired'),
          _Tab.rejected => A3.repair('toolbox'),
          _ => A3.repair('technician'),
        },
        title: title,
        message: msg,
        action: tab == _Tab.pending || tab == _Tab.all
            ? SizedBox(
                width: 220,
                child: AuctionButton(
                    label: 'Set my repair prices',
                    height: 46,
                    icon: PhosphorIconsFill.tag,
                    onPressed: () => context.push(Routes.repairPrices)))
            : null,
      ),
    ];
  }
}

// ── header widgets ────────────────────────────────────────────────────

class _Stats extends StatelessWidget {
  const _Stats(this.c, this.tab, this.onTap);
  final IncomingCounts c;
  final _Tab tab;
  final ValueChanged<_Tab> onTap;

  @override
  Widget build(BuildContext context) {
    Widget tile(String n, String label, String art, Color fg, Color bg,
            _Tab t) =>
        Expanded(
          child: GestureDetector(
            onTap: () => onTap(t),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: tab == t ? fg : Colors.transparent, width: 1.4),
              ),
              child: Row(children: [
                Art3D(art, size: 38),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.padLeft(2, '0'),
                            style: heading(size: 20, color: fg)),
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(label,
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: fg))),
                      ]),
                ),
              ]),
            ),
          ),
        );
    return Row(children: [
      tile('${c.pending}', 'Pending', A3.sell('timer'), RC.blue, RC.tint,
          _Tab.pending),
      const SizedBox(width: 8),
      tile('${c.accepted + c.completed}', 'Accepted', A3.repair('repaired'),
          RC.green, RC.greenTint, _Tab.accepted),
      const SizedBox(width: 8),
      tile('${c.rejected}', 'Rejected', A3.repair('body'), RC.red, RC.redTint,
          _Tab.rejected),
    ]);
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs(this.tab, this.onTap);
  final _Tab tab;
  final ValueChanged<_Tab> onTap;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _Tab.all: 'All Requests',
      _Tab.pending: 'Pending',
      _Tab.accepted: 'Accepted',
      _Tab.rejected: 'Rejected',
    };
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: const Color(0xFFE9EFFB),
          borderRadius: BorderRadius.circular(26)),
      child: Row(children: [
        for (final t in _Tab.values)
          Expanded(
            child: GestureDetector(
              onTap: () => onTap(t),
              child: Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: tab == t ? RC.blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(22)),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(labels[t]!,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: tab == t
                              ? Colors.white
                              : AppColors.textSecondary)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters(
      {required this.onSearch,
      required this.sort,
      required this.onSort,
      required this.maxKm,
      required this.onKm});
  final ValueChanged<String> onSearch;
  final _Sort sort;
  final ValueChanged<_Sort> onSort;
  final num? maxKm;
  final ValueChanged<num?> onKm;

  @override
  Widget build(BuildContext context) {
    Widget menu<T>(String label, IconData icon, T value, Map<T, String> options,
            ValueChanged<T> onPick) =>
        PopupMenuButton<T>(
          onSelected: onPick,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          itemBuilder: (_) => [
            for (final e in options.entries)
              PopupMenuItem<T>(
                  value: e.key,
                  child: Text(e.value,
                      style: TextStyle(
                          fontWeight: e.key == value
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: e.key == value ? RC.blue : AppColors.navy))),
          ],
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: RC.line)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 17, color: RC.blue),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              const Icon(PhosphorIconsBold.caretDown,
                  size: 12, color: AppColors.textMuted),
            ]),
          ),
        );

    return Row(children: [
      Expanded(
        child: SizedBox(
          height: 46,
          child: TextField(
            onChanged: onSearch,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search customer, phone or order ID',
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                  size: 19, color: AppColors.textMuted),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: RC.line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: RC.blue)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      menu<_Sort>(
          sort == _Sort.newest ? 'Newest' : 'Nearest',
          PhosphorIconsBold.arrowsDownUp,
          sort,
          const {_Sort.newest: 'Newest first', _Sort.nearest: 'Nearest first'},
          onSort),
      const SizedBox(width: 6),
      menu<num?>(
          maxKm == null ? 'Nearby' : '≤ ${maxKm!.toInt()} km',
          PhosphorIconsFill.mapPin,
          maxKm,
          const {
            null: 'Any distance',
            3: 'Within 3 km',
            5: 'Within 5 km',
            10: 'Within 10 km',
          },
          onKm),
    ]);
  }
}

// ── cards ─────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard(this.r,
      {required this.onReject, required this.onReconsider});
  final IncomingRequest r;
  final VoidCallback? onReject;
  final VoidCallback? onReconsider;

  @override
  Widget build(BuildContext context) {
    final first = r.items.isEmpty ? null : r.items.first;
    final where = [
      if (r.distanceKm != null) kmLabel(r.distanceKm),
      if (r.pincode.isNotEmpty) r.pincode
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => context.push(Routes.repairRequest(r.id)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x141B2A6B), blurRadius: 16, offset: Offset(0, 6))
            ],
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: RC.canvas, borderRadius: BorderRadius.circular(18)),
                  child: DeviceThumb(
                      brand: first?.brand ?? '',
                      model: first?.model ?? '',
                      size: 68),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(first?.name ?? 'Device',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: heading(size: 16)),
                          ),
                          if (r.isBulk)
                            const StatusChip('BULK', icon: PhosphorIconsFill.stack),
                        ]),
                        if (r.isBulk)
                          Text(
                              '${r.items.length} devices${r.businessName == null ? '' : ' • ${r.businessName}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: RC.blue,
                                  fontWeight: FontWeight.w700))
                        else if (r.items.length > 1)
                          Text(
                              '+ ${r.items.length - 1} more device${r.items.length > 2 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: RC.blue,
                                  fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 5, runSpacing: 5, children: [
                          for (final i in r.allIssues.take(3)) IssueChip(i),
                          if (r.allIssues.length > 3)
                            StatusChip('+${r.allIssues.length - 3}',
                                kind: ChipKind.grey),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(PhosphorIconsFill.mapPin,
                              size: 13, color: RC.blue),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                                '${r.firstName}${where.isEmpty ? '' : ' · $where'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ),
                          const SizedBox(width: 8),
                          Text(clock(r.createdAt),
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.textMuted)),
                        ]),
                      ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: r.quoted
                  ? _QuotedStrip(r.offer!)
                  : Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Estimated price',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textMuted)),
                              Text(
                                  r.estimateTotal == null
                                      ? 'Set your price'
                                      : '${r.estimateComplete ? '' : 'from '}${formatInr(r.estimateTotal!)}',
                                  style: heading(
                                      size: 20,
                                      color: r.estimateTotal == null
                                          ? RC.amber
                                          : RC.blueDark)),
                            ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: RC.amberTint,
                            borderRadius: BorderRadius.circular(14)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(PhosphorIconsFill.timer,
                              size: 14, color: RC.amber),
                          const SizedBox(width: 5),
                          Text(
                              r.offersCloseAt == null
                                  ? 'Open'
                                  : 'Reply by ${shortDate(r.offersCloseAt)}',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: RC.amber)),
                        ]),
                      ),
                    ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: onReconsider != null
                  ? AuctionButton(
                      label: 'Move back to Pending',
                      height: 46,
                      outlined: true,
                      icon: PhosphorIconsBold.arrowUUpLeft,
                      onPressed: onReconsider)
                  : Row(children: [
                      Expanded(
                        flex: 3,
                        child: AuctionButton(
                            label: r.quoted ? 'Change price' : 'Accept',
                            height: 46,
                            icon: r.quoted
                                ? PhosphorIconsBold.pencilSimple
                                : PhosphorIconsBold.check,
                            onPressed: () =>
                                context.push(Routes.repairPrice(r.id))),
                      ),
                      if (onReject != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: AuctionButton(
                              label: 'Reject',
                              height: 46,
                              outlined: true,
                              danger: true,
                              onPressed: onReject),
                        ),
                      ],
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _QuotedStrip extends StatelessWidget {
  const _QuotedStrip(this.o);
  final MyOffer o;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
            color: RC.greenTint, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(PhosphorIconsFill.paperPlaneTilt,
              size: 17, color: RC.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                'Your price ${formatInr(o.total)} sent — waiting for the customer',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: RC.green)),
          ),
        ]),
      );
}

class _JobCard extends StatelessWidget {
  const _JobCard(this.j);
  final JobRow j;

  @override
  Widget build(BuildContext context) {
    final st = jobStatus(j.status, pickup: j.fulfilment == 'PICKUP_DELIVERY');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => context.push(Routes.repairJob(j.id)),
        child: HomeCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            DeviceThumb(
                brand: j.device.split(' ').first,
                model: j.device.split(' ').skip(1).join(' '),
                size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              j.customerName.isEmpty
                                  ? 'Customer'
                                  : j.customerName,
                              style: heading(size: 15.5))),
                      StatusChip(st.label, kind: st.kind),
                    ]),
                    Text('#${j.code}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text(
                        '${j.device}${j.deviceCount > 1 ? ' + ${j.deviceCount - 1} more' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy)),
                    const SizedBox(height: 4),
                    Text(formatInr(j.total),
                        style: heading(size: 16, color: RC.blue)),
                  ]),
            ),
            const Icon(PhosphorIconsBold.caretRight,
                size: 16, color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }
}

class _RejectSheet extends StatefulWidget {
  const _RejectSheet();

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  static const _reasons = [
    'Customer is too far',
    'We are too busy',
    'Cannot repair this problem',
    'Spare part not available',
  ];
  String? _pick;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            18, 18, 18, 18 + MediaQuery.of(context).padding.bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                      color: RC.redTint, shape: BoxShape.circle),
                  child: const Icon(PhosphorIconsBold.x, color: RC.red),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child:
                        Text('Reject this request?', style: heading(size: 18))),
              ]),
              const SizedBox(height: 6),
              const Text(
                  'The customer is not told. You can move it back to Pending later.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in _reasons)
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text(r),
                    selected: _pick == r,
                    onSelected: (_) =>
                        setState(() => _pick = _pick == r ? null : r),
                    selectedColor: RC.tint,
                    labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _pick == r ? RC.blue : AppColors.navy),
                  ),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                    child: AuctionButton(
                        label: 'Keep it',
                        height: 48,
                        outlined: true,
                        onPressed: () => Navigator.pop(context))),
                const SizedBox(width: 10),
                Expanded(
                    child: AuctionButton(
                        label: 'Reject',
                        height: 48,
                        danger: true,
                        onPressed: () => Navigator.pop(context, _pick ?? ''))),
              ]),
            ]),
      );
}

/// Vendors can also SEND their own devices (one phone or a bulk lot) to repair shops — same journey as customers.
class _SendRepairCard extends StatelessWidget {
  const _SendRepairCard({required this.onSend, required this.onMine});
  final VoidCallback onSend;
  final VoidCallback onMine;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: RC.line),
          boxShadow: [
            BoxShadow(
                color: RC.blue.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Need a device repaired?',
                  style: TextStyle(
                      fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.navy)),
              const SizedBox(height: 4),
              Text('Send one phone or a bulk lot. Nearby shops quote, you pick the best.',
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: RC.grey)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: onSend,
                  icon: const Icon(PhosphorIconsFill.paperPlaneTilt, size: 16),
                  label: const Text('Send request'),
                  style: FilledButton.styleFrom(
                      backgroundColor: RC.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                OutlinedButton(
                  onPressed: onMine,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: RC.blue,
                      side: const BorderSide(color: RC.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('My requests'),
                ),
              ]),
            ]),
          ),
          Image.asset('assets/3d/repair/toolbox.png', height: 76),
        ]),
      );
}
