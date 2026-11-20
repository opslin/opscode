import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/returns/application/returns_providers.dart';
import 'package:dealker_vendor/features/returns/data/return_models.dart';
import 'package:dealker_vendor/features/returns/presentation/returns_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';

const _filters = <(String, String)>[
  ('All', ''),
  ('Needs answer', 'needs_response'),
  ('Open', 'open'),
  ('Closed', 'closed'),
];

/// Returns customers asked for on this vendor's orders, newest first; the ones waiting for an answer come first.
class ReturnsScreen extends ConsumerStatefulWidget {
  const ReturnsScreen({super.key, this.initialState = ''});
  final String initialState;

  @override
  ConsumerState<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends ConsumerState<ReturnsScreen> {
  late String _state = widget.initialState;

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(returnsListProvider(_state));
    final sum = ref.watch(returnsSummaryProvider).asData?.value;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AuctionAppBar(title: 'Returns', subtitle: 'Customer return requests'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(returnsSummaryProvider);
          ref.invalidate(returnsListProvider(_state));
          await ref.read(returnsListProvider(_state).future).catchError((_) => const ReturnPage(items: [], total: 0));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _Header(sum),
            const SizedBox(height: 14),
            SizedBox(
              height: 38,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final (label, value) in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _state == value,
                      onSelected: (_) => setState(() => _state = value),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            page.when(
              skipLoadingOnReload: true,
              skipError: true,
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SizedBox(
                  height: 320,
                  child: ErrorState(
                      message: errorText(e, 'Could not load your returns.'),
                      onRetry: () => ref.invalidate(returnsListProvider(_state)))),
              data: (p) => p.items.isEmpty
                  ? SizedBox(
                      height: 320,
                      child: EmptyState(
                        icon: PhosphorIconsRegular.arrowUUpLeft,
                        title: _state.isEmpty ? 'No returns' : 'Nothing here',
                        message: _state.isEmpty
                            ? 'When a customer asks to return something they bought from you, it shows up here and you get a notification.'
                            : 'No returns in this view.',
                      ))
                  : Column(children: [for (final r in p.items) _ReturnCard(r)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.s);
  final ReturnSummary? s;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value, Color color) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: AppColors.violetGradient, borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        cell('Need your answer', s == null ? '—' : '${s!.needsResponse}', const Color(0xFFFFD66B)),
        Container(width: 1, height: 44, color: Colors.white24),
        const SizedBox(width: 16),
        cell('With Dealkr', s == null ? '—' : '${s!.withTeam}', Colors.white),
        Container(width: 1, height: 44, color: Colors.white24),
        const SizedBox(width: 16),
        cell('Closed', s == null ? '—' : '${s!.closed}', Colors.white),
      ]),
    );
  }
}

class _ReturnCard extends StatelessWidget {
  const _ReturnCard(this.r);
  final ReturnRow r;

  @override
  Widget build(BuildContext context) {
    final first = r.itemsPreview.isEmpty ? null : r.itemsPreview.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(Routes.returnDetail(r.id)),
        child: HomeCard(
          border: r.stage == ReturnStage.needsResponse ? const Color(0xFFF6B726) : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(r.returnNumber,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textMuted))),
              StagePill(r.stage),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              ProductThumb(first?.image, size: 54),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    r.itemsPreview.length > 1 || r.itemCount > 1
                        ? '${first?.name ?? 'Items'} + more'
                        : (first?.name ?? 'Items'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.navy)),
                const SizedBox(height: 3),
                Text('Order ${r.orderNumber} · ${r.itemCount} item${r.itemCount == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(height: 3),
                Text(r.reasonLabel ?? r.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(formatInr(r.atRisk),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy)),
                Text(shortDate(r.createdAt), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ]),
            ]),
            if (r.chatUnread > 0) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(PhosphorIconsFill.chatCircleDots, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('${r.chatUnread} new message${r.chatUnread == 1 ? '' : 's'} from Dealkr',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
