import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/features/repair_book/repair_tokens.dart';
import 'package:dealker_vendor/features/repair_book/shims/env.dart' show currentUserProvider;
import 'package:dealker_vendor/features/repair_book/presentation/widgets/repair_art.dart';
import 'package:dealker_vendor/features/repair_book/presentation/widgets/repair_guide.dart';
import 'package:dealker_vendor/features/repair_book/presentation/widgets/repair_ui.dart';
import 'package:dealker_vendor/features/repair_book/repair_models.dart';
import 'package:dealker_vendor/features/repair_book/repair_providers.dart';

/// Issues shown as tiles on the first page, in the design's order.
const List<String> _tileKeys = <String>[
  'SCREEN',
  'BATTERY',
  'CHARGING',
  'WATER_DAMAGE',
  'CAMERA',
  'AUDIO',
  'SOFTWARE',
  'OTHER',
];

/// Screen 01 — Repair Mobile: explains the service, starts a request, resumes an
/// active repair.
class RepairHomeScreen extends ConsumerStatefulWidget {
  const RepairHomeScreen({super.key});

  @override
  ConsumerState<RepairHomeScreen> createState() => _RepairHomeScreenState();
}

class _RepairHomeScreenState extends ConsumerState<RepairHomeScreen> {
  @override
  void initState() {
    super.initState();
    // First time this customer opens Repair: show the walkthrough once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dynamic user = ref.read(currentUserProvider);
      RepairGuide.maybeShow(context, user?.id as String?);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RepairList> mine = ref.watch(repairMineProvider);
    final AsyncValue<RepairConfig> config = ref.watch(repairConfigProvider);
    final RepairList? list = mine.asData?.value;
    final RepairRequest? active =
        list == null || list.active.isEmpty ? null : list.active.first;

    return RepairShell(
      title: 'Repair Mobile',
      onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      body: RefreshIndicator(
        color: RT.indigo,
        onRefresh: () async {
          ref.invalidate(repairMineProvider);
          await ref
              .read(repairMineProvider.future)
              .catchError((Object _) => const RepairList(<RepairRequest>[]));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(RT.gutter, 14, RT.gutter, 28),
          children: <Widget>[
            _Hero(
              onStart: () => _start(context, ref),
              onGuide: () => RepairGuide.show(context),
            ),
            if (mine.hasError && list == null) ...<Widget>[
              const SizedBox(height: RT.gap),
              RBand(
                isOfflineError(mine.error!)
                    ? 'You’re offline. Pull down to retry.'
                    : 'Couldn’t load your repairs. Pull down to retry.',
                kind: BandKind.warn,
              ),
            ],
            if (active != null) ...<Widget>[
              const SizedBox(height: RT.gap + 2),
              _ActiveCard(request: active),
            ],
            const SizedBox(height: 26),
            Text('How it works', style: rtHead(19)),
            const SizedBox(height: 12),
            const _HowItWorks(),
            const SizedBox(height: 26),
            RHeading(
              'What is wrong?',
              action: 'See all',
              onAction: () => _start(context, ref),
            ),
            const SizedBox(height: 4),
            Text('Tap the problem to start', style: rtBody(13)),
            const SizedBox(height: 12),
            _IssueGrid(
              keys: _tileKeys
                  .where(
                    (String k) =>
                        config.asData?.value.issues
                            .any((RepairIssue i) => i.key == k) ??
                        true,
                  )
                  .toList(),
              onTap: (String k) => _start(context, ref, issue: k),
            ),
            const SizedBox(height: 26),
            Text('Why Dealkr Repair?', style: rtHead(19)),
            const SizedBox(height: 12),
            const _Trust(),
            const SizedBox(height: RT.gap + 4),
            _MyRepairsRow(count: list?.items.length),
          ],
        ),
      ),
    );
  }

  void _start(BuildContext context, WidgetRef ref, {String? issue}) {
    ref
        .read(repairDraftProvider.notifier)
        .reset(issues: issue == null ? const <String>[] : <String>[issue]);
    context.push('/repair/new');
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onStart, required this.onGuide});

  final VoidCallback onStart;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 8, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF001F5F), Color(0xFF14409A)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF001F5F).withValues(alpha: .25),
            blurRadius: 22,
            offset: const Offset(0, 10),
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
                  'Fix your phone,\nthe easy way',
                  style: rtHead(24, color: Colors.white, h: 1.15),
                ),
                const SizedBox(height: 8),
                Text(
                  'See shops near you with their price, then pick one.',
                  style: rtBody(13.5, color: Colors.white70, h: 1.4),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 13),
                    decoration: BoxDecoration(
                      color: RT.gold,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('Start repair',
                            style: rtHead(16, color: RT.indigo)),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 18, color: RT.indigo),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onGuide,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.play_circle_outline_rounded,
                          size: 18, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text('How does it work?',
                          style: rtBody(13,
                              color: Colors.white70, w: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          RArt(kRepairTechnician, size: 124, float: true),
        ],
      ),
    );
  }
}

class _ActiveCard extends ConsumerWidget {
  const _ActiveCard({required this.request});

  final RepairRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool quoting = request.awaitingOffers;
    final RepairTracking? tr = quoting
        ? null
        : ref.watch(repairTrackingProvider(request.id)).asData?.value;
    final int total = tr?.steps.length ?? 0;
    final int done =
        tr == null ? 0 : tr.steps.where((TrackStep s) => s.done).length;
    final PillKind kind = quoting
        ? (request.offerCount > 0 ? PillKind.green : PillKind.indigo)
        : PillKind.indigo;

    return RCard(
      onTap: () => context.push('/repair/${request.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Your active repair', style: rtHead(16))),
              RPill(repairStatusLabel(request), kind: kind),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              RDeviceThumb(request.device, size: 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      request.deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rtHead(16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quoting
                          ? (request.device?.issuesLabel ?? '')
                          : (request.serviceCenter ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rtBody(13.5),
                    ),
                    if (!quoting && total > 0) ...<Widget>[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (done / total).clamp(0.0, 1.0),
                          minHeight: 6,
                          color: RT.indigo,
                          backgroundColor: RT.tint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Step ${(done + 1).clamp(1, total)} of $total · ${repairStatusLabel(request)}',
                        style: rtBody(12.5),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RButton(
            label: quoting
                ? (request.offerCount > 0 ? 'Pick a shop' : 'See shops')
                : 'Track repair',
            outline: true,
            onTap: () => context.push(
              quoting
                  ? '/repair/${request.id}/quotes'
                  : '/repair/${request.id}',
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const List<(String, String, String)> steps = <(String, String, String)>[
      ('assets/3d/repair/screen.png', '1', 'Tell us what is wrong'),
      ('assets/3d/shops/shop1.png', '2', 'Pick a shop near you'),
      ('assets/3d/repair/repaired.png', '3', 'Get your phone fixed'),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < steps.length; i++) ...<Widget>[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.only(top: 38),
              child: Icon(Icons.arrow_forward_rounded,
                  size: 18, color: RT.muted),
            ),
          Expanded(
            child: Column(
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: RT.tint,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(steps[i].$1, fit: BoxFit.contain),
                    ),
                    Positioned(
                      left: -4,
                      top: -4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: RT.gold,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(steps[i].$2,
                            style: rtHead(13, color: RT.indigo)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    steps[i].$3,
                    textAlign: TextAlign.center,
                    style: rtHead(13, w: FontWeight.w700, h: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _IssueGrid extends StatelessWidget {
  const _IssueGrid({required this.keys, required this.onTap});

  final List<String> keys;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        const double gap = 8;
        final double w = (c.maxWidth - gap * 3) / 4;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final String k in keys)
              GestureDetector(
                onTap: () => onTap(k),
                child: Container(
                  width: w,
                  height: 94,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: RT.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      RArt(repairIssueArt(k), size: 48),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            issueTileName(k),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: rtHead(12, w: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Trust extends StatelessWidget {
  const _Trust();

  @override
  Widget build(BuildContext context) {
    const List<(String, String, String)> items = <(String, String, String)>[
      ('assets/3d/cart/verified.png', 'Trusted shops', 'Checked by Dealkr'),
      ('assets/3d/sell/placeholder', 'Price first', 'See it before you book'),
      (kRepairSafe, 'Safe repair', 'Warranty on the work'),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: RT.border),
              ),
              child: Column(
                children: <Widget>[
                  RArt(
                    i == 1 ? 'assets/3d/profile/sellPhone.png' : items[i].$1,
                    size: 46,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    items[i].$2,
                    textAlign: TextAlign.center,
                    style: rtHead(13, w: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items[i].$3,
                    textAlign: TextAlign.center,
                    style: rtBody(11.5, color: RT.muted, h: 1.3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MyRepairsRow extends StatelessWidget {
  const _MyRepairsRow({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    return RCard(
      onTap: () => context.push('/repair/mine'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          const RArt('assets/3d/sell/parcel.png', size: 30),
          const SizedBox(width: 12),
          Expanded(child: Text('My repairs', style: rtHead(16))),
          if ((count ?? 0) > 0) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: RT.tint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: rtHead(12, color: RT.indigo)),
            ),
            const SizedBox(width: 8),
          ],
          const PhosphorIcon(
            PhosphorIconsRegular.caretRight,
            size: 18,
            color: RT.ink,
          ),
        ],
      ),
    );
  }
}
