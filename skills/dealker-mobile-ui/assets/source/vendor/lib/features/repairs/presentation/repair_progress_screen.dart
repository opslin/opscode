import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/shared/widgets/premium_ui.dart' show A3;
import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show AuctionButton, BottomActionBar, ErrorState, errorText;
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/features/repairs/application/repairs_providers.dart';
import 'package:dealker_vendor/features/repairs/data/offer_draft.dart'
    show DeviceGroup, groupDevices;
import 'package:dealker_vendor/features/repairs/data/repair_models.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// "Repairing Progress": one tile per repair — Start, then Mark done with the part used, photos and a note.
class RepairProgressScreen extends ConsumerStatefulWidget {
  const RepairProgressScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<RepairProgressScreen> createState() =>
      _RepairProgressScreenState();
}

class _RepairProgressScreenState extends ConsumerState<RepairProgressScreen> {
  bool _busy = false;
  bool _photosTab = false;
  final _techNote = TextEditingController();

  @override
  void dispose() {
    _techNote.dispose();
    super.dispose();
  }

  Future<void> _sendNote(RepairJob j) async {
    final t = _techNote.text.trim();
    if (t.length < 2) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(repairsRepositoryProvider)
          .update(j.id, stage: 'REPAIR_IN_PROGRESS', note: t);
      _techNote.clear();
      refreshRepairs(ref, id: j.id);
      if (mounted) showAppToast(context, 'Update sent to the customer.');
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start(RepairJob j, DeviceGroup g, String issue) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(repairsRepositoryProvider);
      for (final it in g.items) {
        if (j.issueState(it.id, issue) == null) {
          await repo.update(j.id,
              stage: 'REPAIR_IN_PROGRESS',
              issue: issue,
              issueStatus: 'STARTED',
              itemId: it.id);
        }
      }
      refreshRepairs(ref, id: j.id);
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _done(RepairJob j, DeviceGroup g, String issue) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _DoneSheet(job: j, group: g, issue: issue),
    );
    if (ok == true) refreshRepairs(ref, id: j.id);
  }

  Future<void> _note(RepairJob j) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _NoteSheet(job: j),
    );
    if (ok == true) refreshRepairs(ref, id: j.id);
  }

  Future<void> _toQc(RepairJob j) async {
    setState(() => _busy = true);
    try {
      await ref.read(repairsRepositoryProvider).step(j.id, 'send-to-qc');
      refreshRepairs(ref, id: j.id);
      if (mounted) {
        showAppToast(context, 'Sent for final check.');
        context.canPop() ? context.pop() : context.go(Routes.repairJob(j.id));
      }
    } catch (e) {
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
          title: 'Repairing Progress',
          subtitle: d.value == null ? null : '#${d.value!.code}',
          onBack: () => context.canPop()
              ? context.pop()
              : context.go(Routes.repairJob(widget.id)),
          actions: [
            if (d.value != null)
              IconButton(
                  tooltip: 'Add a note or photos',
                  onPressed: () => _note(d.value!),
                  icon: const Icon(PhosphorIconsFill.camera, color: RC.blue)),
          ]),
      body: d.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e),
            onRetry: () => ref.invalidate(jobProvider(widget.id))),
        data: _body,
      ),
      bottomNavigationBar: d.maybeWhen(
          data: (j) {
            final all =
                _rows(j).every((r) => r.$3 == 'DONE' || r.$3 == 'NOT_NEEDED');
            if (j.status != 'IN_REPAIR') return null;
            return BottomActionBar(
                child: AuctionButton(
                    label: all
                        ? 'All done — send for final check'
                        : 'Finish every repair first',
                    icon: PhosphorIconsBold.checkCircle,
                    loading: _busy,
                    onPressed: all ? () => _toQc(j) : null));
          },
          orElse: () => null),
    );
  }

  String? _groupState(RepairJob j, DeviceGroup g, String issue) {
    final st = [for (final it in g.items) j.issueState(it.id, issue)];
    if (st.every((e) => e == null)) return null;
    if (st.every((e) => e == 'DONE')) return 'DONE';
    if (st.every((e) => e == 'NOT_NEEDED')) return 'NOT_NEEDED';
    if (st.every((e) => e == 'DONE' || e == 'NOT_NEEDED')) return 'DONE';
    return 'STARTED';
  }

  List<(DeviceGroup, String, String?)> _rows(RepairJob j) => [
        for (final g in groupDevices(j.items))
          for (final i in g.first.issues)
            if (j.inQuote(g.first.id, i)) (g, i, _groupState(j, g, i))
      ];

  Widget _body(RepairJob j) {
    final rows = _rows(j);
    final done =
        rows.where((r) => r.$3 == 'DONE' || r.$3 == 'NOT_NEEDED').length;
    final updates = j.timeline
        .where((e) => e.kind == 'TECH_UPDATE')
        .toList()
        .reversed
        .take(8)
        .toList();
    final current = rows.where((r) => r.$3 == 'STARTED').firstOrNull;
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: const Color(0xFFE9EFFB),
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              for (final (photos, label) in const [
                (false, 'Updates'),
                (true, 'Photos')
              ])
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _photosTab = photos),
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: _photosTab == photos
                              ? RC.blue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11)),
                      child: Text(label,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _photosTab == photos
                                  ? Colors.white
                                  : AppColors.textSecondary)),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          if (_photosTab)
            _PhotosTab(j)
          else ...[
            HomeCard(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Row(children: [
                  Text('Repair progress', style: heading(size: 16)),
                  const Spacer(),
                  Text('$done of ${rows.length}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: RC.blue)),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                      value: rows.isEmpty ? 0 : done / rows.length,
                      minHeight: 10,
                      backgroundColor: RC.tint,
                      valueColor: const AlwaysStoppedAnimation(RC.green)),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            for (final (g, issue, st) in rows)
              _IssueTile(
                  job: j,
                  group: g,
                  issue: issue,
                  state: st,
                  busy: _busy,
                  showDevice: j.items.length > 1,
                  onStart: () => _start(j, g, issue),
                  onDone: () => _done(j, g, issue)),
            if (current != null)
              RepairSection(
                title: 'Current step',
                art: A3.repair('toolbox'),
                child: Row(children: [
                  IssueBadge(current.$2, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          '${issueMeta(current.$2).label} — in progress',
                          style: heading(size: 14.5))),
                ]),
              ),
            if (j.status == 'IN_REPAIR')
              RepairSection(
                title: 'Add technician note',
                art: A3.cart('notepad'),
                child: Column(children: [
                  TextField(
                    controller: _techNote,
                    maxLines: 2,
                    maxLength: 300,
                    decoration: InputDecoration(
                        hintText:
                            'e.g. Old battery removed. New battery fitting in progress.',
                        counterText: '',
                        filled: true,
                        fillColor: RC.canvas,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: RC.line))),
                  ),
                  const SizedBox(height: 10),
                  AuctionButton(
                      label: 'Update progress',
                      height: 46,
                      icon: PhosphorIconsFill.paperPlaneTilt,
                      loading: _busy,
                      onPressed: () => _sendNote(j)),
                ]),
              ),
            if (updates.isNotEmpty)
              RepairSection(
                title: 'Recent updates',
                art: A3.cart('clock'),
                child: Column(children: [
                  for (final e in updates)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                                e.issueStatus == 'DONE'
                                    ? PhosphorIconsFill.checkCircle
                                    : PhosphorIconsFill.circle,
                                size: 16,
                                color: e.issueStatus == 'DONE'
                                    ? RC.green
                                    : RC.blue),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(e.label,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600))),
                            Text(clock(e.at),
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted)),
                          ]),
                    ),
                ]),
              ),
            const HintBox(
                'Tap "Mark done" after each repair. The customer sees your updates on their phone.',
                icon: PhosphorIconsFill.bellRinging),
          ],
        ]);
  }
}

/// Before / after photos of every finished repair.
class _PhotosTab extends StatelessWidget {
  const _PhotosTab(this.j);
  final RepairJob j;

  @override
  Widget build(BuildContext context) {
    final withPhotos = j.timeline
        .where((e) => e.before.isNotEmpty || e.after.isNotEmpty)
        .toList()
        .reversed
        .toList();
    if (withPhotos.isEmpty) {
      return const HintBox(
          'No photos yet. Add before and after photos when you mark a repair as done.',
          icon: PhosphorIconsFill.images);
    }
    Widget col(String title, List<String> ids) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final id in ids)
                if (j.mediaById(id) != null)
                  EvidenceImage(j.mediaById(id)!.url, size: 72),
              if (ids.isEmpty)
                const Text('—', style: TextStyle(color: AppColors.textMuted)),
            ]),
          ]),
        );
    return Column(children: [
      for (final e in withPhotos)
        RepairSection(
          title: e.issue == null
              ? e.label
              : '${issueMeta(e.issue!).label} — ${e.issueStatus == 'DONE' ? 'completed' : 'update'}',
          icon: PhosphorIconsFill.camera,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              col('Before', e.before),
              const SizedBox(width: 10),
              col('After', e.after)
            ]),
            if (e.partName != null) ...[
              const Divider(height: 22, color: RC.line),
              KV('Part', e.partName!),
              if (e.partPrice != null)
                KV('Part price', formatInr(e.partPrice!)),
              if ((e.partWarrantyDays ?? 0) > 0)
                KV('Warranty', '${e.partWarrantyDays} days'),
            ],
          ]),
        ),
    ]);
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({
    required this.job,
    required this.group,
    required this.issue,
    required this.state,
    required this.busy,
    required this.showDevice,
    required this.onStart,
    required this.onDone,
  });
  final RepairJob job;
  final DeviceGroup group;
  final String issue;
  final String? state;
  final bool busy;
  final bool showDevice;
  final VoidCallback onStart;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final m = issueMeta(issue);
    final item = group.first;
    final ev = job.issueEvent(item.id, issue);
    final price = job.priceOf(item.id, issue) * group.qty;
    final pct = switch (state) {
      'DONE' || 'NOT_NEEDED' => 100,
      'STARTED' => 50,
      _ => 0
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HomeCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IssueBadge(issue, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.label, style: heading(size: 16)),
                    if (showDevice)
                      Text(
                          group.qty > 1
                              ? '${item.name} × ${group.qty}'
                              : item.name,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textMuted)),
                  ]),
            ),
            if (price > 0)
              Text(formatInr(price), style: heading(size: 15, color: RC.blue)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 8,
                    backgroundColor: RC.tint,
                    valueColor: AlwaysStoppedAnimation(
                        pct == 100 ? RC.green : RC.blue)),
              ),
            ),
            const SizedBox(width: 10),
            Text('$pct%',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            StatusChip(
                switch (state) {
                  'DONE' => 'Completed',
                  'STARTED' => 'In progress',
                  'NOT_NEEDED' => 'Not needed',
                  _ => 'Waiting'
                },
                kind: switch (state) {
                  'DONE' => ChipKind.green,
                  'STARTED' => ChipKind.blue,
                  'NOT_NEEDED' => ChipKind.grey,
                  _ => ChipKind.amber
                },
                icon: switch (state) {
                  'DONE' => PhosphorIconsFill.checkCircle,
                  'STARTED' => PhosphorIconsFill.wrench,
                  _ => PhosphorIconsFill.clock
                }),
            const Spacer(),
            if (state == null)
              SizedBox(
                  width: 130,
                  child: AuctionButton(
                      label: 'Start',
                      height: 42,
                      icon: PhosphorIconsBold.play,
                      onPressed: busy ? null : onStart)),
            if (state == 'STARTED')
              SizedBox(
                  width: 150,
                  child: AuctionButton(
                      label: 'Mark done',
                      height: 42,
                      icon: PhosphorIconsBold.check,
                      onPressed: busy ? null : onDone)),
          ]),
          if (state == 'DONE' && ev?.partName != null) ...[
            const Divider(height: 22, color: RC.line),
            KV('Part used', ev!.partName!),
            if (ev.partPrice != null)
              KV('Part price', formatInr(ev.partPrice!)),
            if ((ev.partWarrantyDays ?? 0) > 0)
              KV('Part warranty', '${ev.partWarrantyDays} days'),
          ],
        ]),
      ),
    );
  }
}

// ── sheets ────────────────────────────────────────────────────────────

class _PhotoRow extends StatelessWidget {
  const _PhotoRow(this.paths, {required this.onAdd, required this.onRemove});
  final List<String> paths;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 76,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 76,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                  color: RC.tint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RC.blue.withValues(alpha: 0.4))),
              child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIconsFill.camera, color: RC.blue),
                    SizedBox(height: 2),
                    Text('Add photo',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: RC.blue)),
                  ]),
            ),
          ),
          for (final p in paths)
            Stack(children: [
              Container(
                width: 76,
                margin: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(p),
                        fit: BoxFit.cover, width: 76, height: 76)),
              ),
              Positioned(
                right: 12,
                top: 4,
                child: GestureDetector(
                  onTap: () => onRemove(p),
                  child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(PhosphorIconsBold.x,
                          size: 11, color: Colors.white)),
                ),
              ),
            ]),
        ]),
      );
}

InputDecoration _field(String hint, {String? prefix}) => InputDecoration(
      hintText: hint,
      prefixText: prefix,
      hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
      filled: true,
      fillColor: RC.canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RC.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RC.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RC.blue, width: 1.6)),
    );

class _DoneSheet extends ConsumerStatefulWidget {
  const _DoneSheet(
      {required this.job, required this.group, required this.issue});
  final RepairJob job;
  final DeviceGroup group;
  final String issue;

  @override
  ConsumerState<_DoneSheet> createState() => _DoneSheetState();
}

class _DoneSheetState extends ConsumerState<_DoneSheet> {
  final _part = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();
  final List<String> _before = [];
  final List<String> _photos = []; // after
  late int _warranty = widget.job.selectedOffer?.warrantyDays ?? 90;
  bool _notify = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _part.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(repairsRepositoryProvider);
      final after = <String>[
        for (final p in _photos) await repo.uploadEvidence(p)
      ];
      final before = <String>[
        for (final p in _before) await repo.uploadEvidence(p)
      ];
      var first = true;
      for (final it in widget.group.items) {
        if (widget.job.issueState(it.id, widget.issue) == 'DONE') continue;
        await repo.update(widget.job.id,
            stage: 'REPAIR_IN_PROGRESS',
            issue: widget.issue,
            issueStatus: 'DONE',
            itemId: it.id,
            note: _note.text,
            notify: _notify,
            mediaIds: first ? after : const [],
            beforeMediaIds: first ? before : const [],
            part: _part.text.trim().isEmpty
                ? null
                : (
                    name: _part.text.trim(),
                    price: num.tryParse(_price.text),
                    warrantyDays: _warranty
                  ));
        first = false;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = issueMeta(widget.issue);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                IssueBadge(widget.issue, size: 42),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        '${m.label} — done${widget.group.qty > 1 ? ' (${widget.group.qty} phones)' : ''}',
                        style: heading(size: 18))),
              ]),
              const SizedBox(height: 16),
              const Text('Part you used (optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                  controller: _part,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _field('e.g. Battery (original)')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(7)
                    ],
                    decoration: _field('Part price', prefix: '₹ '),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              const Text('Part warranty',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                for (final (days, label) in const [
                  (0, 'None'),
                  (30, '1 month'),
                  (90, '3 months'),
                  (180, '6 months'),
                  (365, '1 year')
                ])
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text(label),
                    selected: _warranty == days,
                    onSelected: (_) => setState(() => _warranty = days),
                    selectedColor: RC.tint,
                    labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _warranty == days ? RC.blue : AppColors.navy),
                  ),
              ]),
              const SizedBox(height: 12),
              const Text('Before photos',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _PhotoRow(_before,
                  onAdd: () async {
                    final ps = await pickPhotos(context);
                    if (ps.isNotEmpty && mounted)
                      setState(() => _before.addAll(ps));
                  },
                  onRemove: (p) => setState(() => _before.remove(p))),
              const SizedBox(height: 12),
              const Text('After photos',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _PhotoRow(_photos,
                  onAdd: () async {
                    final ps = await pickPhotos(context);
                    if (ps.isNotEmpty && mounted)
                      setState(() => _photos.addAll(ps));
                  },
                  onRemove: (p) => setState(() => _photos.remove(p))),
              const SizedBox(height: 12),
              const Text('Note for the customer (optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                  controller: _note,
                  maxLines: 2,
                  maxLength: 500,
                  decoration:
                      _field('e.g. Old battery removed, new battery fitted')
                          .copyWith(counterText: '')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
                activeThumbColor: RC.blue,
                title: const Text('Tell the customer',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: HintBox(_error!,
                      icon: PhosphorIconsFill.warning, kind: ChipKind.red),
                ),
              AuctionButton(
                  label: 'Save — repair done',
                  icon: PhosphorIconsBold.check,
                  loading: _busy,
                  onPressed: _save),
            ]),
      ),
    );
  }
}

class _NoteSheet extends ConsumerStatefulWidget {
  const _NoteSheet({required this.job});
  final RepairJob job;

  @override
  ConsumerState<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends ConsumerState<_NoteSheet> {
  final _note = TextEditingController();
  final List<String> _photos = [];
  String _stage = 'REPAIR_IN_PROGRESS';
  bool _notify = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(repairsRepositoryProvider);
      final ids = <String>[];
      for (final p in _photos) {
        ids.add(await repo.uploadEvidence(p));
      }
      await repo.update(widget.job.id,
          stage: _stage, note: _note.text, notify: _notify, mediaIds: ids);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add an update', style: heading(size: 18)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (k, label) in const [
                    ('REPAIR_IN_PROGRESS', 'Repairing'),
                    ('WAITING_FOR_PARTS', 'Waiting for parts'),
                    ('TESTING', 'Testing'),
                  ])
                    ChoiceChip(
                      showCheckmark: false,
                      label: Text(label),
                      selected: _stage == k,
                      onSelected: (_) => setState(() => _stage = k),
                      selectedColor: RC.tint,
                      labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _stage == k ? RC.blue : AppColors.navy),
                    ),
                ]),
                const SizedBox(height: 12),
                TextField(
                    controller: _note,
                    maxLines: 3,
                    maxLength: 500,
                    decoration:
                        _field('What is happening?').copyWith(counterText: '')),
                const SizedBox(height: 10),
                _PhotoRow(_photos,
                    onAdd: () async {
                      final ps = await pickPhotos(context);
                      if (ps.isNotEmpty && mounted)
                        setState(() => _photos.addAll(ps));
                    },
                    onRemove: (p) => setState(() => _photos.remove(p))),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _notify,
                  onChanged: (v) => setState(() => _notify = v),
                  activeThumbColor: RC.blue,
                  title: const Text('Tell the customer',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: HintBox(_error!,
                          icon: PhosphorIconsFill.warning, kind: ChipKind.red)),
                AuctionButton(
                    label: 'Send update',
                    icon: PhosphorIconsFill.paperPlaneTilt,
                    loading: _busy,
                    onPressed: _save),
              ]),
        ),
      );
}
