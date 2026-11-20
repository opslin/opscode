import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_helpers.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_ui.dart';
import 'package:dealker_app/features/repair/repair_models.dart';
import 'package:dealker_app/features/repair/repair_providers.dart';

enum _Tab { active, completed, cancelled }

const Color _pageBg = Color(0xFFF5F8FF);

/// Every repair request, grouped Active / Completed / Cancelled, each card showing exactly where it is.
class RepairMyScreen extends ConsumerStatefulWidget {
  const RepairMyScreen({super.key});

  @override
  ConsumerState<RepairMyScreen> createState() => _RepairMyScreenState();
}

class _RepairMyScreenState extends ConsumerState<RepairMyScreen> {
  _Tab _tab = _Tab.active;
  final TextEditingController _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _newRepair() {
    ref.read(repairDraftProvider.notifier).reset();
    context.push('/repair/new');
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RepairList> async = ref.watch(repairMineProvider);
    final RepairList? list = async.asData?.value;
    final String q = _q.text.trim().toLowerCase();

    bool match(RepairRequest r) =>
        q.isEmpty ||
        r.deviceName.toLowerCase().contains(q) ||
        r.code.toLowerCase().contains(q) ||
        (r.serviceCenter ?? '').toLowerCase().contains(q);

    final List<RepairRequest> rows = list == null
        ? const <RepairRequest>[]
        : (switch (_tab) {
            _Tab.active => list.active,
            _Tab.completed => list.completed,
            _Tab.cancelled => list.cancelled,
          })
            .where(match)
            .toList();

    return RepairShell(
      title: 'My repairs',
      onBack: () => context.canPop() ? context.pop() : context.go('/repair'),
      body: ColoredBox(
        color: _pageBg,
        child: list == null
            ? (async.hasError
                ? RErrorView(
                    offline: isOfflineError(async.error!),
                    onRetry: () => ref.invalidate(repairMineProvider),
                  )
                : const RSkeletonCards(count: 3))
            : RefreshIndicator(
                color: RT.indigo,
                onRefresh: () async {
                  ref.invalidate(repairMineProvider);
                  await ref.read(repairMineProvider.future).catchError(
                        (Object _) => const RepairList(<RepairRequest>[]),
                      );
                },
                child: ListView(
                  padding:
                      const EdgeInsets.fromLTRB(RT.gutter, 14, RT.gutter, 32),
                  children: <Widget>[
                    _Summary(list: list, onNew: _newRepair),
                    const SizedBox(height: 16),
                    _Tabs(
                      tab: _tab,
                      counts: <int>[
                        list.active.length,
                        list.completed.length,
                        list.cancelled.length,
                      ],
                      onChanged: (_Tab t) => setState(() => _tab = t),
                    ),
                    const SizedBox(height: 12),
                    _Search(controller: _q, onChanged: () => setState(() {})),
                    const SizedBox(height: 16),
                    if (rows.isEmpty)
                      _Empty(
                        searching: q.isNotEmpty,
                        tab: _tab,
                        onNew: _newRepair,
                      )
                    else
                      for (final RepairRequest r in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _Row(request: r),
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Top card: friendly 3D picture, how many repairs are running, and the one big action.
class _Summary extends StatelessWidget {
  const _Summary({required this.list, required this.onNew});

  final RepairList list;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final int active = list.active.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFFFFF), Color(0xFFE3ECFF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD6E2FA)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A1B3C8C),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  active == 0
                      ? 'No repairs running'
                      : '$active repair${active == 1 ? '' : 's'} in progress',
                  style: rtHead(19),
                ),
                const SizedBox(height: 4),
                Text(
                  '${list.completed.length} finished · ${list.cancelled.length} cancelled',
                  style: rtBody(13, color: RT.grey),
                ),
                const SizedBox(height: 14),
                RButton(
                  label: 'Repair a phone',
                  expand: false,
                  height: 44,
                  onTap: onNew,
                ),
              ],
            ),
          ),
          Image.asset('assets/repair/technician.png', width: 112, height: 112),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tab,
    required this.counts,
    required this.onChanged,
  });

  final _Tab tab;
  final List<int> counts;
  final ValueChanged<_Tab> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<String> labels = <String>['Active', 'Completed', 'Cancelled'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6ECF9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          for (final _Tab t in _Tab.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(t),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tab == t ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: tab == t
                        ? const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '${labels[t.index]} (${counts[t.index]})',
                    style: rtHead(
                      13.5,
                      color: tab == t ? RT.indigo : RT.grey,
                      w: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: RT.border),
        ),
        child: Row(
          children: <Widget>[
            const PhosphorIcon(
              PhosphorIconsRegular.magnifyingGlass,
              size: 20,
              color: RT.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: (_) => onChanged(),
                style: rtBody(15, color: RT.ink, w: FontWeight.w500),
                cursorColor: RT.indigo,
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Search device or booking ID',
                  hintStyle: rtBody(15, color: RT.muted),
                ),
              ),
            ),
          ],
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.searching,
    required this.tab,
    required this.onNew,
  });

  final bool searching;
  final _Tab tab;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final String art = searching
        ? 'assets/sell/looking.png'
        : switch (tab) {
            _Tab.active => 'assets/repair/toolbox.png',
            _Tab.completed => 'assets/repair/repaired.png',
            _Tab.cancelled => 'assets/repair/other.png',
          };
    final String title = searching
        ? 'Nothing found'
        : switch (tab) {
            _Tab.active => 'No repairs running',
            _Tab.completed => 'No finished repairs yet',
            _Tab.cancelled => 'Nothing cancelled',
          };
    final String msg = searching
        ? 'Try another device name or booking ID.'
        : switch (tab) {
            _Tab.active =>
              'Tell us what is wrong with your phone and pick a nearby shop.',
            _Tab.completed => 'Repairs that are done will show up here.',
            _Tab.cancelled => 'Requests you cancel are kept here.',
          };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      child: Column(
        children: <Widget>[
          Image.asset(art, width: 130, height: 130),
          const SizedBox(height: 10),
          Text(title, style: rtHead(18)),
          const SizedBox(height: 6),
          Text(msg, textAlign: TextAlign.center, style: rtBody(14, h: 1.4)),
          if (!searching && tab == _Tab.active) ...<Widget>[
            const SizedBox(height: 18),
            RButton(
              label: 'Repair my phone',
              expand: false,
              height: 48,
              onTap: onNew,
            ),
          ],
        ],
      ),
    );
  }
}

/// Where a repair is, in the same five words as the screens it leads to.
int _stepOf(RepairRequest r) {
  if (r.completed) return 4;
  if (r.awaitingOffers) return 1;
  if (r.ready) return 3;
  return 3;
}

class _Row extends StatelessWidget {
  const _Row({required this.request});

  final RepairRequest request;

  @override
  Widget build(BuildContext context) {
    final RepairRequest r = request;
    final PillKind kind = r.completed || r.ready
        ? PillKind.green
        : r.awaitingOffers
            ? (r.offerCount > 0 ? PillKind.green : PillKind.indigo)
            : r.cancelled ||
                    r.status == 'FAILED' ||
                    r.status == 'ESTIMATE_REJECTED'
                ? PillKind.red
                : r.revisedPricePending
                    ? PillKind.amber
                    : PillKind.indigo;
    final String action = r.awaitingOffers
        ? 'Choose a shop'
        : r.revisedPricePending
            ? 'Review new price'
            : r.completed
                ? (r.ratingStars == null ? 'Rate repair' : 'View repair')
                : r.cancelled
                    ? 'View details'
                    : r.ready
                        ? 'View repair'
                        : 'Track repair';
    final String sub = r.awaitingOffers
        ? (r.offerCount > 0
            ? '${r.offerCount} shop${r.offerCount == 1 ? '' : 's'} sent a price'
            : 'Waiting for nearby shops to send a price')
        : (r.serviceCenter ?? '');
    final bool urgent = r.awaitingOffers || r.revisedPricePending;
    final String issues = r.device?.issuesLabel ?? '';
    return GestureDetector(
      onTap: () => context.push(
        r.awaitingOffers ? '/repair/${r.id}/quotes' : '/repair/${r.id}',
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x141B3C8C),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      RPill(repairStatusLabel(r), kind: kind),
                      const Spacer(),
                      Text(
                        fmtDate(r.createdAt),
                        style: rtBody(12.5, color: RT.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5FD),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: RDeviceThumb(r.device, size: 62),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              r.deviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: rtHead(16.5),
                            ),
                            if (issues.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                issues,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: rtBody(13),
                              ),
                            ],
                            if (sub.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 6),
                              Row(
                                children: <Widget>[
                                  PhosphorIcon(
                                    r.awaitingOffers
                                        ? PhosphorIconsFill.hourglassMedium
                                        : PhosphorIconsFill.storefront,
                                    size: 14,
                                    color: RT.indigo,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      sub,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: rtBody(
                                        12.5,
                                        color: RT.indigo,
                                        w: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!r.cancelled) ...<Widget>[
                    const SizedBox(height: 14),
                    _Progress(step: _stepOf(r)),
                  ],
                ],
              ),
            ),
            Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: urgent ? RT.indigo : const Color(0xFFEEF3FD),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(22)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    action,
                    style: rtHead(
                      14.5,
                      color: urgent ? Colors.white : RT.indigo,
                      w: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  PhosphorIcon(
                    PhosphorIconsBold.arrowRight,
                    size: 15,
                    color: urgent ? Colors.white : RT.indigo,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Five dots: Request → Shops → Book → Repair → Done, filled up to where the repair is.
class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const List<String> labels = <String>[
      'Request',
      'Shops',
      'Book',
      'Repair',
      'Done',
    ];
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int i = 0; i < labels.length; i++) ...<Widget>[
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i <= step ? RT.indigo : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i <= step ? RT.indigo : RT.border,
                    width: 2,
                  ),
                ),
                child: i < step
                    ? const PhosphorIcon(
                        PhosphorIconsBold.check,
                        size: 10,
                        color: Colors.white,
                      )
                    : (i == step
                        ? Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null),
              ),
              if (i < labels.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i < step ? RT.indigo : RT.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            for (int i = 0; i < labels.length; i++)
              Text(
                labels[i],
                style: rtBody(
                  10.5,
                  color: i == step ? RT.indigo : RT.muted,
                  w: i == step ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
