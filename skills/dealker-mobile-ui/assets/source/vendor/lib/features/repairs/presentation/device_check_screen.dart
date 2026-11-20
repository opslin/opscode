import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show AuctionButton, BottomActionBar, ErrorState, errorText;
import 'package:dealker_vendor/features/repairs/application/repairs_providers.dart';
import 'package:dealker_vendor/features/repairs/data/offer_draft.dart'
    show groupDevices;
import 'package:dealker_vendor/features/repairs/data/repair_models.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/shared/widgets/premium_ui.dart' show A3;

enum _R { pass, low, issue }

const _checks = [
  ('SCREEN', 'Screen', PhosphorIconsFill.deviceMobile),
  ('TOUCH', 'Touch', PhosphorIconsFill.handTap),
  ('BATTERY', 'Battery health', PhosphorIconsFill.batteryHigh),
  ('CHARGING', 'Charging port', PhosphorIconsFill.plugCharging),
  ('BIOMETRIC', 'Face ID / fingerprint', PhosphorIconsFill.fingerprint),
  ('CAMERA', 'Camera', PhosphorIconsFill.camera),
  ('AUDIO', 'Speaker / mic', PhosphorIconsFill.speakerHigh),
  ('NETWORK', 'Network / SIM', PhosphorIconsFill.cellSignalFull),
];

/// "Device Check / Diagnosis": tick how each part of the phone is, add a note, then confirm the agreed price.
class DeviceCheckScreen extends ConsumerStatefulWidget {
  const DeviceCheckScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<DeviceCheckScreen> createState() => _DeviceCheckScreenState();
}

class _DeviceCheckScreenState extends ConsumerState<DeviceCheckScreen> {
  final Map<String, Map<String, _R>> _state =
      {}; // first itemId of a group → check → result
  bool _imeiOk = true;
  bool _physicalOk = true;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Map<String, _R> _forItem(RepairItem it) => _state.putIfAbsent(
      it.id,
      () => {
            for (final (k, _, _) in _checks)
              k: it.issues.contains(k) ? _R.issue : _R.pass,
          });

  Future<void> _save(RepairJob j) async {
    setState(() => _busy = true);
    final repo = ref.read(repairsRepositoryProvider);
    try {
      var first = true;
      for (final g in groupDevices(j.items)) {
        final m = _forItem(g.first);
        for (final it in g.items) {
          await repo.update(j.id,
              stage: 'DIAGNOSING',
              itemId: it.id,
              note: first ? _note.text : null,
              checks: [
                for (final (k, label, _) in _checks)
                  (
                    key: k,
                    label: label,
                    result: switch (m[k]!) {
                      _R.pass => 'PASS',
                      _R.low => 'LOW',
                      _R.issue => 'ISSUE'
                    }
                  ),
                if (j.isBulk)
                  (
                    key: 'IMEI_VERIFIED',
                    label: 'IMEI verified',
                    result: _imeiOk ? 'PASS' : 'ISSUE'
                  ),
                if (j.isBulk)
                  (
                    key: 'PHYSICAL_CHECK',
                    label: 'Physical check',
                    result: _physicalOk ? 'PASS' : 'ISSUE'
                  ),
              ]);
          first = false;
        }
      }
      if (j.selectedOffer == null) {
        // Nobody agreed a price (e.g. assigned from the dashboard): the shop quotes its own price next.
        refreshRepairs(ref, id: j.id);
        if (mounted) {
          showAppToast(context, 'Check saved. Now set your price.');
          context.pushReplacement(Routes.repairQuote(j.id));
        }
        return;
      }
      await repo.step(j.id, 'confirm-price');
      refreshRepairs(ref, id: j.id);
      if (mounted) {
        showAppToast(context,
            'Check saved. Price confirmed — you can start the repair.');
        context.canPop() ? context.pop() : context.go(Routes.repairJob(j.id));
      }
    } catch (e) {
      refreshRepairs(ref, id: j.id);
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(jobProvider(widget.id));
    return Scaffold(
      backgroundColor: RC.canvas,
      appBar: RepairAppBar(
          title: 'Check & Diagnose',
          subtitle: 'How is each part of the phone?',
          art: A3.repair('toolbox'),
          onBack: () => context.canPop()
              ? context.pop()
              : context.go(Routes.repairJob(widget.id))),
      body: d.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e),
            onRetry: () => ref.invalidate(jobProvider(widget.id))),
        data: (j) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              if (j.isBulk)
                RepairSection(
                  title: 'Receive devices',
                  art: A3.repair('handover'),
                  child: Column(children: [
                    for (final (label, on, set) in [
                      ('Devices received (${j.items.length})', true, null),
                      (
                        'IMEI verified',
                        _imeiOk,
                        (bool v) => setState(() => _imeiOk = v)
                      ),
                      (
                        'Physical check done',
                        _physicalOk,
                        (bool v) => setState(() => _physicalOk = v)
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: GestureDetector(
                          onTap: set == null ? null : () => set(!on),
                          child: Row(children: [
                            Icon(
                                on
                                    ? PhosphorIconsFill.checkCircle
                                    : PhosphorIconsRegular.circle,
                                color: on ? RC.green : AppColors.textMuted,
                                size: 24),
                            const SizedBox(width: 10),
                            Text(label,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                  ]),
                ),
              for (final g in groupDevices(j.items))
                _DeviceChecks(g.first, _forItem(g.first), () => setState(() {}),
                    j.items.length > 1,
                    qty: g.qty),
              RepairSection(
                title: 'What you found',
                art: A3.cart('notepad'),
                child: TextField(
                  controller: _note,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. Battery health low, charging port loose. Needs battery replacement.',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
                    counterText: '',
                    filled: true,
                    fillColor: RC.canvas,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: RC.line)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: RC.line)),
                  ),
                ),
              ),
              const HintBox(
                  'Saving confirms the price the customer already agreed to. If no price was agreed, you set your own price next. If you find a bigger problem, call the customer before you start.',
                  icon: PhosphorIconsFill.info),
            ]),
      ),
      bottomNavigationBar: d.maybeWhen(
        data: (j) => BottomActionBar(
            child: AuctionButton(
                label: 'Save & Continue',
                icon: PhosphorIconsBold.arrowRight,
                loading: _busy,
                onPressed: () => _save(j))),
        orElse: () => null,
      ),
    );
  }
}

class _DeviceChecks extends StatelessWidget {
  const _DeviceChecks(this.item, this.m, this.onChanged, this.showName,
      {this.qty = 1});
  final int qty;
  final RepairItem item;
  final Map<String, _R> m;
  final VoidCallback onChanged;
  final bool showName;

  @override
  Widget build(BuildContext context) => RepairSection(
        title: showName
            ? (qty > 1 ? '${item.name} × $qty' : item.name)
            : 'Phone check',
        art: A3.repair('technician'),
        child: Column(children: [
          for (final (k, label, _) in _checks)
            _CheckRow(
                issueKey: k,
                label: label,
                value: m[k]!,
                onChanged: (v) {
                  m[k] = v;
                  onChanged();
                }),
        ]),
      );
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(
      {required this.issueKey,
      required this.label,
      required this.value,
      required this.onChanged});
  final String issueKey;
  final String label;
  final _R value;
  final ValueChanged<_R> onChanged;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, word) = switch (value) {
      _R.pass => (RC.green, RC.greenTint, 'Good'),
      _R.low => (RC.amber, RC.amberTint, 'Low / weak'),
      _R.issue => (RC.red, RC.redTint, 'Problem'),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(bg.withValues(alpha: 0.55), Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IssueBadge(issueKey, size: 44),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: fg, borderRadius: BorderRadius.circular(20)),
            child: Text(word,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 10),
        _Seg(value, onChanged),
      ]),
    );
  }
}

/// Three big labelled buttons: Good · Low · Problem.
class _Seg extends StatelessWidget {
  const _Seg(this.value, this.onChanged);
  final _R value;
  final ValueChanged<_R> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget opt(_R r, IconData icon, String text, Color fg) {
      final on = value == r;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 42,
            margin: EdgeInsets.only(right: r == _R.issue ? 0 : 8),
            decoration: BoxDecoration(
              color: on ? fg : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? fg : RC.line, width: 1.4),
              boxShadow: on
                  ? [
                      BoxShadow(
                          color: fg.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                  : null,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 17, color: on ? Colors.white : fg),
              const SizedBox(width: 5),
              Text(text,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: on ? Colors.white : AppColors.textSecondary)),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      opt(_R.pass, PhosphorIconsBold.check, 'Good', RC.green),
      opt(_R.low, PhosphorIconsBold.warning, 'Low', const Color(0xFFD97706)),
      opt(_R.issue, PhosphorIconsBold.x, 'Problem', RC.red),
    ]);
  }
}
