import 'package:flutter/material.dart';
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
    show groupDevices;
import 'package:dealker_vendor/features/repairs/data/repair_models.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

enum _Option { pickup, vendorDelivery, courier }

/// "Ready for Pickup / Delivery": choose how the phone goes back, when, add a note and tell the customer.
class RepairReadyScreen extends ConsumerStatefulWidget {
  const RepairReadyScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<RepairReadyScreen> createState() => _RepairReadyScreenState();
}

class _RepairReadyScreenState extends ConsumerState<RepairReadyScreen> {
  _Option? _opt;
  DateTime _when = DateTime.now().add(const Duration(hours: 3));
  final _note =
      TextEditingController(text: 'Device ready. Please confirm pickup.');
  bool _busy = false;
  RepairJob? _done;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context,
        initialDate: _when.isBefore(now) ? now : _when,
        firstDate: now,
        lastDate: now.add(const Duration(days: 30)));
    if (d != null)
      setState(() =>
          _when = DateTime(d.year, d.month, d.day, _when.hour, _when.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (t != null)
      setState(() => _when =
          DateTime(_when.year, _when.month, _when.day, t.hour, t.minute));
  }

  Future<void> _notify(RepairJob j) async {
    final opt = _opt ?? (j.isPickup ? _Option.vendorDelivery : _Option.pickup);
    setState(() => _busy = true);
    try {
      final repo = ref.read(repairsRepositoryProvider);
      var job = await repo.step(j.id, 'ready');
      final label = switch (opt) {
        _Option.pickup => 'Ready for pickup at the shop',
        _Option.vendorDelivery => 'Ready — we will deliver it ourselves',
        _Option.courier => 'Ready — it will go by courier'
      };
      job = await repo.update(j.id,
          stage: 'OTHER',
          note:
              '$label on ${shortDate(_when)}${_note.text.trim().isEmpty ? '' : ' — ${_note.text.trim()}'}');
      refreshRepairs(ref, id: j.id);
      if (mounted) setState(() => _done = job);
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(jobProvider(widget.id));
    final j = d.value;
    if (_done != null) return _Notified(_done!);
    return Scaffold(
      backgroundColor: RC.canvas,
      appBar: RepairAppBar(
          title: 'Ready for Pickup / Delivery',
          subtitle: j == null ? null : '#${j.code}',
          onBack: () => context.canPop()
              ? context.pop()
              : context.go(Routes.repairJob(widget.id))),
      body: d.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e),
            onRetry: () => ref.invalidate(jobProvider(widget.id))),
        data: (j) {
          final opts = [
            (
              _Option.pickup,
              'Customer pickup (shop visit)',
              'Customer will collect it from your shop',
              PhosphorIconsFill.storefront,
              !j.isPickup
            ),
            (
              _Option.vendorDelivery,
              'Vendor delivery (your delivery)',
              'You deliver it to the customer',
              PhosphorIconsFill.truck,
              j.isPickup
            ),
            (
              _Option.courier,
              'Courier delivery',
              'Send via courier / delivery partner',
              PhosphorIconsFill.package,
              j.isPickup
            ),
          ];
          final sel =
              _opt ?? (j.isPickup ? _Option.vendorDelivery : _Option.pickup);
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                RepairSection(
                  title: 'Select handover option',
                  art: A3.sell('deal'),
                  child: Column(children: [
                    for (final (o, title, sub, icon, enabled) in opts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap:
                              enabled ? () => setState(() => _opt = o) : null,
                          child: Opacity(
                            opacity: enabled ? 1 : 0.45,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: sel == o && enabled
                                      ? RC.tint
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: sel == o && enabled
                                          ? RC.blue
                                          : RC.line,
                                      width: sel == o && enabled ? 1.4 : 1)),
                              child: Row(children: [
                                Icon(
                                    sel == o && enabled
                                        ? PhosphorIconsFill.radioButton
                                        : PhosphorIconsRegular.circle,
                                    color: sel == o && enabled
                                        ? RC.blue
                                        : AppColors.textMuted),
                                const SizedBox(width: 10),
                                Icon(icon, color: RC.blue, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: heading(size: 14)),
                                        Text(
                                            enabled
                                                ? sub
                                                : (j.isPickup
                                                    ? 'The customer chose delivery'
                                                    : 'The customer chose a shop visit'),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.textSecondary)),
                                      ]),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
                RepairSection(
                  title: 'Schedule date & time',
                  art: A3.cart('calendar'),
                  child: Row(children: [
                    Expanded(
                        child: _Pill(
                            icon: PhosphorIconsRegular.calendarBlank,
                            text: '${_when.day}/${_when.month}/${_when.year}',
                            onTap: _pickDate)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _Pill(
                            icon: PhosphorIconsRegular.clock,
                            text: clock(_when),
                            onTap: _pickTime)),
                  ]),
                ),
                RepairSection(
                  title: 'Add note',
                  art: A3.cart('notepad'),
                  child: TextField(
                    controller: _note,
                    maxLines: 2,
                    maxLength: 300,
                    decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: RC.canvas,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: RC.line))),
                  ),
                ),
              ]);
        },
      ),
      bottomNavigationBar: j == null
          ? null
          : BottomActionBar(
              child: AuctionButton(
                  label: 'Notify customer',
                  icon: PhosphorIconsFill.bellRinging,
                  loading: _busy,
                  onPressed: () => _notify(j))),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RC.line)),
          child: Row(children: [
            Icon(icon, size: 19, color: RC.blue),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w700))
          ]),
        ),
      );
}

/// "Repairing Ready!" — the customer has been told.
class _Notified extends StatelessWidget {
  const _Notified(this.j);
  final RepairJob j;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 24),
            Center(
                child: Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(
                        color: RC.greenTint, shape: BoxShape.circle),
                    child: const Icon(PhosphorIconsFill.checkCircle,
                        color: RC.green, size: 62))),
            const SizedBox(height: 20),
            Center(child: Text('Repairing ready!', style: heading(size: 26))),
            const SizedBox(height: 6),
            const Center(
                child: Text(
                    'Your device is repaired and ready.\nWe have told the customer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        color: AppColors.textSecondary))),
            const SizedBox(height: 22),
            HomeCard(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                for (final g in groupDevices(j.items))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      DeviceThumb(
                          brand: g.first.brand, model: g.first.model, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              g.qty > 1
                                  ? '${g.first.name} × ${g.qty}'
                                  : g.first.name,
                              style: heading(size: 15))),
                    ]),
                  ),
                KV('Order', '#${j.code}'),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: StatusChip('Ready', kind: ChipKind.green)),
              ]),
            ),
            const SizedBox(height: 18),
            AuctionButton(
                label: 'View details',
                outlined: true,
                icon: PhosphorIconsFill.receipt,
                onPressed: () => context.go(Routes.repairJob(j.id))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: AuctionButton(
                      label: 'Call',
                      outlined: true,
                      icon: PhosphorIconsFill.phone,
                      onPressed: j.customerPhone.isEmpty
                          ? null
                          : () => callPhone(context, j.customerPhone))),
              const SizedBox(width: 10),
              Expanded(
                  child: AuctionButton(
                      label: 'Chat',
                      outlined: true,
                      icon: PhosphorIconsFill.chatCircleText,
                      onPressed: () => context.go(Routes.repairChat(j.id)))),
            ]),
            const SizedBox(height: 10),
            AuctionButton(
                label: 'Hand over & collect payment',
                icon: PhosphorIconsBold.handshake,
                onPressed: () => context.go(Routes.repairHandover(j.id))),
          ]),
        ),
      );
}
