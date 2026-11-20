import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/features/wholesale/application/device_selection.dart';
import 'package:dealker_vendor/features/wholesale/data/condition_report.dart';

const _blue = Color(0xFF1D4ED8);
const _ink = Color(0xFF0F1B3D);
const _muted = Color(0xFF6B7280);
const _line = Color(0xFFE6EAF2);
const _green = Color(0xFF15803D);
const _red = Color(0xFFDC2626);
const _font = 'PlusJakartaSans';

/// "Device Condition": pick exactly as many devices as the quantity. The first N available devices are ticked by default;
/// un-tick one and the next available device is ticked for you. Sold / reserved / packed devices are blurred and locked.
class DeviceConditionBlock extends StatelessWidget {
  const DeviceConditionBlock({super.key, required this.selection, required this.name});
  final DeviceSelection selection;
  final String name;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: selection,
        builder: (context, _) {
          final s = selection;
          if (!s.ready || s.total == 0) return const SizedBox.shrink();
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Select devices', style: TextStyle(fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 4),
              Text('${s.availableCount} of ${s.total} devices available. Each device has its own QC — tap View details to check it.',
                  style: const TextStyle(fontFamily: _font, fontSize: 12.5, height: 1.35, color: _muted)),
              const SizedBox(height: 10),
              _CountBanner(s),
              const SizedBox(height: 6),
              const Text('Un-tick a device and the next available one is picked for you.', style: TextStyle(fontFamily: _font, fontSize: 11.5, color: _muted)),
              const SizedBox(height: 10),
              DeviceGrid(selection: s, name: name, height: 420),
            ]),
          );
        },
      );
}

class _CountBanner extends StatelessWidget {
  const _CountBanner(this.s);
  final DeviceSelection s;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: const Color(0xFFEEF3FF), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, size: 18, color: _blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(s.quantityFollows ? '${s.selected.length} device${s.selected.length == 1 ? '' : 's'} selected · quantity ${s.selected.length}' : '${s.selected.length} of ${s.qty} devices selected',
                style: const TextStyle(fontFamily: _font, fontSize: 13.5, fontWeight: FontWeight.w800, color: _blue)),
          ),
        ]),
      );
}

/// The lazy, paged 2-column grid of device cards (Device 1 … N). Only the visible cards are built.
class DeviceGrid extends StatefulWidget {
  const DeviceGrid({super.key, required this.selection, required this.name, this.height});
  final DeviceSelection selection;
  final String name;

  /// Fixed height (inside a page); null = fill the space the parent gives it (inside the sheet).
  final double? height;

  @override
  State<DeviceGrid> createState() => _DeviceGridState();
}

class _DeviceGridState extends State<DeviceGrid> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) widget.selection.loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _tap(int unitNo) async {
    final msg = await widget.selection.toggle(unitNo);
    if (msg != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _open(int unitNo) => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DeviceReportScreen(productId: widget.selection.productId, position: unitNo, name: widget.name)));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.selection,
        builder: (context, _) {
          final s = widget.selection;
          final nos = s.loaded.keys.toList()..sort();
          final grid = GridView.builder(
            controller: _scroll,
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 178),
            itemCount: nos.length + (s.hasMore ? 2 : 0),
            itemBuilder: (context, i) {
              if (i >= nos.length) return const _Skeleton();
              final u = s.loaded[nos[i]]!;
              return _DeviceCard(u: u, selected: s.selected.contains(u.unitNo), onTap: () => _tap(u.unitNo), onView: () => _open(u.unitNo));
            },
          );
          return widget.height == null ? grid : SizedBox(height: widget.height, child: grid);
        },
      );
}

/// "Select Device Condition" bottom sheet (opened from a cart line): pick the devices; the quantity follows the selection.
Future<void> showDeviceSheet(BuildContext context, {required DeviceSelection selection, required String name}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SizedBox(
        height: MediaQuery.of(c).size.height * 0.86,
        child: ListenableBuilder(
          listenable: selection,
          builder: (c, _) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Select Device Condition', style: TextStyle(fontFamily: _font, fontSize: 18, fontWeight: FontWeight.w800, color: _ink))),
                IconButton(onPressed: () => Navigator.of(c).pop(), icon: const Icon(Icons.close_rounded)),
              ]),
              Text('Tap devices to add or remove them — your quantity follows. ${selection.availableCount} of ${selection.total} available.',
                  style: const TextStyle(fontFamily: _font, fontSize: 12.5, height: 1.35, color: _muted)),
              const SizedBox(height: 10),
              _CountBanner(selection),
              const SizedBox(height: 10),
              Expanded(child: DeviceGrid(selection: selection, name: name)),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(c).pop(),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text('Continue'),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: const Color(0xFFF1F3F9), borderRadius: BorderRadius.circular(14)));
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.u, required this.selected, required this.onTap, required this.onView});
  final UnitBrief u;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEEF3FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? _blue : _line, width: selected ? 1.6 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 18, color: selected ? _blue : _muted),
          const SizedBox(width: 6),
          Text('Device ${u.unitNo}', style: const TextStyle(fontFamily: _font, fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: u.score >= 85 ? const Color(0xFFE7F8EE) : const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
            child: Text('${u.score}', style: TextStyle(fontFamily: _font, fontSize: 11.5, fontWeight: FontWeight.w800, color: u.score >= 85 ? _green : const Color(0xFFB45309))),
          ),
        ]),
        const SizedBox(height: 8),
        for (final c in u.chips)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(c.ok == true ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 14, color: c.ok == true ? _green : _red),
              const SizedBox(width: 5),
              Expanded(child: Text('${c.label}: ${c.value}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: _font, fontSize: 11.5, color: _ink))),
            ]),
          ),
        const Spacer(),
        Center(
          child: GestureDetector(
            onTap: onView,
            child: const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('View details', style: TextStyle(fontFamily: _font, fontSize: 12.5, fontWeight: FontWeight.w800, color: _blue)),
            ),
          ),
        ),
      ]),
    );
    if (u.available) return GestureDetector(onTap: onTap, child: card);
    // sold / reserved / packed: blurred and locked
    return Stack(children: [
      Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(14), child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2), child: Opacity(opacity: 0.5, child: card)))),
      Positioned.fill(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _ink.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(20)),
            child: Text(u.status == 'SOLD' ? 'Sold' : u.status == 'PACKED' ? 'Packed' : 'Reserved', style: const TextStyle(fontFamily: _font, color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    ]);
  }
}

/// One device's full QC report: screen, functional, battery and physical condition. "Show defects only" filters to the faults.
class DeviceReportScreen extends ConsumerStatefulWidget {
  const DeviceReportScreen({super.key, required this.productId, required this.position, required this.name});
  final String productId;
  final int position;
  final String name;

  @override
  ConsumerState<DeviceReportScreen> createState() => _DeviceReportScreenState();
}

class _DeviceReportScreenState extends ConsumerState<DeviceReportScreen> {
  bool _defectsOnly = false;

  static const _titles = {
    'screen': 'Screen Condition',
    'functional': 'Functional Condition',
    'battery': 'Battery',
    'physical': 'Physical Condition',
  };

  @override
  Widget build(BuildContext context) {
    final rep = ref.watch(unitReportProvider((widget.productId, widget.position)));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text('QC Report · Device ${widget.position}', style: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w800, fontSize: 18, color: _ink)),
      ),
      body: rep.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load the report')),
        data: (r) {
          if (r == null) return const Center(child: Text('No report for this device'));
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F1B3D), Color(0xFF1D3A8A)]), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF34D399), width: 4)),
                  child: Text('${r.brief.score}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: _font)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.brief.score >= 90 ? 'Excellent' : r.brief.score >= 80 ? 'Very good' : 'Good', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, fontFamily: _font)),
                    const SizedBox(height: 2),
                    Text(r.brief.defects == 0 ? 'No defects found' : '${r.brief.defects} defect${r.brief.defects == 1 ? '' : 's'} noted',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5, fontFamily: _font)),
                  ]),
                ),
              ]),
            ),
            if (r.autoNote != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                child: Text(r.autoNote!, style: const TextStyle(fontFamily: _font, fontSize: 12, height: 1.35, color: Color(0xFFB45309))),
              ),
            if (widget.name.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(widget.name, style: const TextStyle(fontFamily: _font, fontSize: 13, color: _muted))),
            Row(children: [
              const Expanded(child: Text('Show defects only', style: TextStyle(fontFamily: _font, fontWeight: FontWeight.w700, color: _ink))),
              Switch(value: _defectsOnly, onChanged: (v) => setState(() => _defectsOnly = v)),
            ]),
            for (final e in _titles.entries) ..._section(e.value, r.sections[e.key] ?? const []),
            if ((r.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Note', style: TextStyle(fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 6),
              Text(r.notes!, style: const TextStyle(fontFamily: _font, fontSize: 13, height: 1.4, color: _muted)),
            ],
          ]);
        },
      ),
    );
  }

  List<Widget> _section(String title, List<QcRow> rows) {
    final shown = _defectsOnly ? rows.where((r) => r.ok == false).toList() : rows;
    if (shown.isEmpty) return const [];
    return [
      const SizedBox(height: 14),
      Text(title, style: const TextStyle(fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: const Color(0xFFF6F7FB), borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(children: [
          for (final r in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 4, child: Text(r.label, style: const TextStyle(fontFamily: _font, fontSize: 13, color: _muted))),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Flexible(
                      child: Text(r.value, textAlign: TextAlign.right, style: TextStyle(fontFamily: _font, fontSize: 13, fontWeight: FontWeight.w700, color: r.ok == false ? _red : _ink)),
                    ),
                    const SizedBox(width: 6),
                    if (r.ok != null) Icon(r.ok! ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 17, color: r.ok! ? _green : _red),
                  ]),
                ),
              ]),
            ),
        ]),
      ),
    ];
  }
}
