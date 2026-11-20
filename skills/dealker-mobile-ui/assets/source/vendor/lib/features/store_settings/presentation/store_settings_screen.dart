import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show heading, errorText;
import 'package:dealker_vendor/features/store_settings/data/store_settings_repository.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

String _pretty(String hhmm) {
  final p = hhmm.split(':');
  final h = int.tryParse(p.first) ?? 0;
  final m = p.length > 1 ? p[1] : '00';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m ${h >= 12 ? 'PM' : 'AM'}';
}

/// Profile → Store settings: opening hours, pickup, auto-accept and where order alerts go.
class StoreSettingsScreen extends ConsumerStatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  ConsumerState<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends ConsumerState<StoreSettingsScreen> {
  StoreSettings? _s;
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  bool _dirty = false;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _adopt(StoreSettings s) {
    if (_s != null) return;
    _s = s;
    _email.text = s.email;
    _phone.text = s.phone;
  }

  void _edit(StoreSettings Function(StoreSettings) f) => setState(() {
        _s = f(_s!);
        _dirty = true;
      });

  Future<void> _pickTime(String day, bool opening) async {
    final cur = _s!.days[day]!;
    final src = (opening ? cur.open : cur.close).split(':');
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: int.tryParse(src[0]) ?? 9, minute: int.tryParse(src[1]) ?? 0));
    if (t == null) return;
    final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    _edit((s) => s.copyWith(days: {...s.days, day: opening ? cur.copyWith(open: v) : cur.copyWith(close: v)}));
  }

  Future<void> _save() async {
    final s = _s!.copyWith(email: _email.text, phone: _phone.text);
    setState(() => _saving = true);
    try {
      await ref.read(storeSettingsRepositoryProvider).save(s);
      ref.invalidate(storeSettingsProvider);
      if (!mounted) return;
      setState(() {
        _s = s;
        _dirty = false;
      });
      showAppToast(context, 'Store settings saved.');
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e, 'Could not save.'), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _card(List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _switchRow(String asset, String title, String sub, bool v, ValueChanged<bool> on) => Row(children: [
        Image.asset(asset, width: 40, height: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
            Text(sub, style: const TextStyle(fontSize: 12.5, height: 1.3, color: AppColors.textMuted)),
          ]),
        ),
        Switch(value: v, onChanged: on, activeTrackColor: AppColors.primary),
      ]);

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
        filled: true,
        fillColor: const Color(0xFFF7F9FD),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(storeSettingsProvider);
    async.whenData(_adopt);
    final s = _s;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft, color: AppColors.navy),
            onPressed: () => context.pop()),
        title: Text('Store settings', style: heading(size: 20)),
      ),
      body: s == null
          ? Center(
              child: async.hasError
                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(errorText(async.error!, 'Could not load your settings.')),
                      TextButton(onPressed: () => ref.invalidate(storeSettingsProvider), child: const Text('Retry')),
                    ])
                  : const CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 110 + MediaQuery.viewInsetsOf(context).bottom),
              children: [
                _card([
                  _switchRow('assets/3d/help/store.png', 'Auto-accept orders',
                      'New paid orders are accepted for you, so you can go straight to packing.', s.autoAccept,
                      (v) => _edit((x) => x.copyWith(autoAccept: v))),
                  const Divider(height: 24),
                  _switchRow('assets/icons/wholesale.png', 'Store pickup',
                      'Let customers collect their order from your shop.', s.pickup,
                      (v) => _edit((x) => x.copyWith(pickup: v))),
                ]),
                _card([
                  Row(children: [
                    Image.asset('assets/3d/help/hours.png', width: 40, height: 40),
                    const SizedBox(width: 10),
                    Text('Opening hours', style: heading(size: 17)),
                  ]),
                  const SizedBox(height: 8),
                  for (final d in storeDays) _dayRow(d, s.days[d]!),
                ]),
                _card([
                  Row(children: [
                    Image.asset('assets/3d/help/bell.png', width: 40, height: 40),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Order alerts', style: heading(size: 17))),
                  ]),
                  const SizedBox(height: 4),
                  const Text('Where we send new-order and payout alerts, besides this app.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() => _dirty = true),
                      decoration: _dec('Alert phone number', PhosphorIconsRegular.phone)),
                  const SizedBox(height: 10),
                  TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() => _dirty = true),
                      decoration: _dec('Alert email', PhosphorIconsRegular.envelopeSimple)),
                ]),
              ],
            ),
      bottomNavigationBar: s == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: (_saving || !_dirty) ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : const Text('Save changes', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _dayRow(String d, DayHours h) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 92, child: Text(storeDayNames[d]!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.navy))),
          Expanded(
            child: h.closed
                ? const Text('Closed', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600))
                : Row(children: [
                    _timeChip(_pretty(h.open), () => _pickTime(d, true)),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
                    _timeChip(_pretty(h.close), () => _pickTime(d, false)),
                  ]),
          ),
          Switch(
              value: !h.closed,
              onChanged: (open) => _edit((s) => s.copyWith(days: {...s.days, d: h.copyWith(closed: !open)})),
              activeTrackColor: AppColors.primary),
        ]),
      );

  Widget _timeChip(String t, VoidCallback tap) => GestureDetector(
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: const Color(0xFFF2F6FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
          child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
      );
}
