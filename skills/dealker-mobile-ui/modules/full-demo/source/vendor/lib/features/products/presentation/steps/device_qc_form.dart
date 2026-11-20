import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/data/unit_qc.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';

/// QC of ONE device on its own page: screen, body, battery and 15 function checks.
/// Starts as "everything fine" so the vendor only changes what is different on this device,
/// but a device counts as done only after the vendor saves it.
class DeviceQcForm extends StatefulWidget {
  const DeviceQcForm({
    super.key,
    required this.deviceNo,
    required this.total,
    this.initial,
    this.copyFrom = const {},
    this.hasNext = false,
    this.readOnlyNote,
    this.autoFilled = false,
  });
  final int deviceNo;
  final int total;
  final UnitQc? initial;

  /// Other devices already done (number -> QC) the vendor can copy from.
  final Map<int, UnitQc> copyFrom;
  final bool hasNext;
  final String? readOnlyNote;

  /// true when the values were filled in automatically from the listing and not inspected yet.
  final bool autoFilled;

  @override
  State<DeviceQcForm> createState() => _DeviceQcFormState();
}

class _DeviceQcFormState extends State<DeviceQcForm> {
  late UnitQc _q = widget.initial ?? UnitQc.allGood();
  late final _notes = TextEditingController(text: _q.notes);
  late final _battery = TextEditingController(text: '${_q.battery}');

  @override
  void dispose() {
    _notes.dispose();
    _battery.dispose();
    super.dispose();
  }

  void _set(UnitQc q) => setState(() => _q = q);

  void _copy(UnitQc from) {
    setState(() {
      _q = from;
      _notes.text = from.notes;
      _battery.text = '${from.battery}';
    });
  }

  bool get _batteryOk {
    final b = int.tryParse(_battery.text.trim());
    return b != null && b >= 40 && b <= 100;
  }

  void _save() {
    final b = int.tryParse(_battery.text.trim());
    if (b == null || b < 40 || b > 100) return;
    Navigator.of(context).pop(_q.copyWith(battery: b, notes: _notes.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final defects = _q.copyWith(battery: int.tryParse(_battery.text.trim()) ?? _q.battery).defects;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
        title: Text('Device ${widget.deviceNo} of ${widget.total}', style: heading(size: 18)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: Text(defects == 0 ? 'No issues found' : '$defects issue${defects == 1 ? '' : 's'} noted',
                  style: TextStyle(fontWeight: FontWeight.w700, color: defects == 0 ? AppColors.mint : const Color(0xFFB45309))),
            ),
            FilledButton(
              onPressed: _batteryOk ? _save : null,
              style: FilledButton.styleFrom(minimumSize: const Size(190, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text(widget.hasNext ? 'Save & next device' : 'Save device QC'),
            ),
          ]),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        if (widget.autoFilled)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
            child: const Text('These values were filled in automatically from your listing. Check this device and save to confirm them.', style: TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFFB45309))),
          ),
        const Text('Check this device in your hand. Everything starts as "working" — change only what is different.',
            style: TextStyle(fontSize: 13.5, height: 1.35, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _set(UnitQc.allGood(battery: int.tryParse(_battery.text.trim()) ?? 90)),
              icon: const Icon(PhosphorIconsBold.checks, size: 18),
              label: const Text('All working'),
            ),
          ),
          if (widget.copyFrom.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final pick = await showModalBottomSheet<int>(
                    context: context,
                    builder: (c) => SafeArea(
                      child: ListView(shrinkWrap: true, children: [
                        const Padding(padding: EdgeInsets.all(16), child: Text('Copy QC from', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                        for (final n in widget.copyFrom.keys.toList()..sort())
                          ListTile(title: Text('Device $n'), subtitle: Text('${widget.copyFrom[n]!.defects} issue(s)'), onTap: () => Navigator.pop(c, n)),
                      ]),
                    ),
                  );
                  if (pick != null) _copy(widget.copyFrom[pick]!);
                },
                icon: const Icon(PhosphorIconsBold.copy, size: 18),
                label: const Text('Copy from…'),
              ),
            ),
          ],
        ]),
        _Section('Screen', [
          _Choice('LCD / display', kLcdOptions, _q.lcd, (v) => _set(_q.copyWith(lcd: v))),
          _Choice('Screen condition', kScreenOptions, _q.screen, (v) => _set(_q.copyWith(screen: v))),
        ]),
        _Section('Physical condition', [
          _Choice('Body', kBodyOptions, _q.body, (v) => _set(_q.copyWith(body: v))),
          _Choice('Back panel', kBodyOptions, _q.back, (v) => _set(_q.copyWith(back: v))),
          _Choice('Frame', kFrameOptions, _q.frame, (v) => _set(_q.copyWith(frame: v))),
        ]),
        _Section('Battery', [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextField(
              controller: _battery,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Battery health',
                suffixText: '%',
                helperText: 'From Settings → Battery. 40 to 100.',
                errorText: _batteryOk ? null : 'Enter 40 to 100',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
        _Section('Functional checks', [
          for (final f in kFunctions) _FunctionRow(f.$2, _q.functional[f.$1] ?? 'PASS', (v) => _set(_q.copyWith(functional: {..._q.functional, f.$1: v}))),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _notes,
          maxLength: 300,
          maxLines: 2,
          decoration: InputDecoration(labelText: 'Note about this device (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: heading(size: 17)),
          const SizedBox(height: 8),
          ...children,
        ]),
      );
}

class _Choice extends StatelessWidget {
  const _Choice(this.label, this.options, this.value, this.onChanged);
  final String label;
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in options)
              ChoiceChip(
                label: Text(o.$2),
                selected: value == o.$1,
                onSelected: (_) => onChanged(o.$1),
                selectedColor: o.$1 == options.first.$1 ? AppColors.mintSoft : const Color(0xFFFFF1CF),
              ),
          ]),
        ]),
      );
}

class _FunctionRow extends StatelessWidget {
  const _FunctionRow(this.label, this.value, this.onChanged);
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: 'PASS', label: Text('OK')),
              ButtonSegment(value: 'FAIL', label: Text('Fault')),
              ButtonSegment(value: 'NA', label: Text('N/A')),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ]),
      );
}
