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
import 'package:dealker_vendor/features/repairs/data/repairs_repository.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// One repair the customer gave to this shop. Shows who/where/what, the agreed price, progress,
/// and one big button for the next step — the screens in the mockup flow hang off this.
class RepairJobScreen extends ConsumerStatefulWidget {
  const RepairJobScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<RepairJobScreen> createState() => _RepairJobScreenState();
}

class _RepairJobScreenState extends ConsumerState<RepairJobScreen> {
  bool _busy = false;

  Future<void> _run(Future<Object?> Function() fn, {String? ok}) async {
    setState(() => _busy = true);
    try {
      await fn();
      refreshRepairs(ref, id: widget.id);
      if (mounted && ok != null) showAppToast(context, ok);
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Open a step screen; when it closes, reload this order so it shows the new state.
  Future<void> _open(String route) async {
    await context.push<Object?>(route);
    if (mounted) ref.invalidate(jobProvider(widget.id));
  }

  RepairsRepository get _repo => ref.read(repairsRepositoryProvider);

  Future<void> _schedule(RepairJob j) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: j.pickupSlot != null && j.pickupSlot!.isAfter(now)
          ? j.pickupSlot!
          : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
            j.pickupSlot ?? now.add(const Duration(hours: 2))));
    if (time == null) return;
    final slot =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await _run(() => _repo.schedulePickup(j.id, slot),
        ok: 'Pickup time saved.');
  }

  Future<void> _qc(RepairJob j, bool passed) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(passed
            ? 'Phone works fine?'
            : 'Problem found — send back to repair?'),
        content: TextField(
            controller: note,
            maxLines: 2,
            decoration: InputDecoration(
                hintText: passed ? 'Note (optional)' : 'What is still wrong?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Back')),
          TextButton(
              onPressed: () {
                if (!passed && note.text.trim().length < 3) return;
                Navigator.pop(c, true);
              },
              child: Text(passed ? 'Yes, all good' : 'Send back')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
        () => _repo.qc(j.id,
            itemIds: [for (final i in j.items) i.id],
            passed: passed,
            note: note.text.trim()),
        ok: passed ? 'Final check passed.' : 'Sent back to repair.');
  }

  Future<void> _collectAdvance(RepairJob j) async {
    final method = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Advance ${formatInr(j.advanceDue)}',
                    style: heading(size: 20)),
                const SizedBox(height: 4),
                const Text(
                    'Collect it from the customer first, then tell us how they paid.',
                    style: TextStyle(
                        fontSize: 13.5, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                for (final (m, label, icon) in const [
                  ('CASH', 'Cash in hand', PhosphorIconsFill.money),
                  ('UPI', 'UPI / PhonePe / GPay', PhosphorIconsFill.qrCode),
                  ('CARD', 'Card', PhosphorIconsFill.creditCard),
                ])
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(icon, color: RC.blue),
                      title: Text(label,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      onTap: () => Navigator.pop(c, m)),
              ]),
        ),
      ),
    );
    if (method == null) return;
    await _run(
        () => _repo.recordPayment(j.id,
            kind: 'ADVANCE',
            method: method,
            amount: j.advanceDue,
            idempotencyKey:
                'adv-${j.id}-${DateTime.now().millisecondsSinceEpoch}'),
        ok: 'Advance saved.');
  }

  Future<void> _editTechnician(RepairJob j) async {
    final name = TextEditingController(text: j.technician ?? '');
    final phone = TextEditingController(text: j.technicianPhone ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
            18, 18, 18, 18 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Who is repairing this phone?', style: heading(size: 18)),
              const SizedBox(height: 4),
              const Text(
                  'The customer sees this name and can call the technician.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: 'Technician name')),
              const SizedBox(height: 10),
              TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Phone (optional)')),
              const SizedBox(height: 16),
              AuctionButton(
                  label: 'Save', onPressed: () => Navigator.pop(c, true)),
            ]),
      ),
    );
    if (ok != true) return;
    await _run(
        () => _repo.setTechnician(j.id,
            name: name.text.trim(), phone: phone.text.trim()),
        ok: 'Technician saved.');
  }

  Future<void> _reportMismatch(RepairJob j) async {
    final title = TextEditingController();
    final note = TextEditingController();
    var itemId = j.items.length == 1 ? j.items.first.id : null;
    final photos = <String>[];
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(
              18, 18, 18, 18 + MediaQuery.of(c).viewInsets.bottom),
          child: SingleChildScrollView(
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
                        child: const Icon(PhosphorIconsFill.warning,
                            color: RC.red)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text('QC mismatch alert',
                            style: heading(size: 18))),
                  ]),
                  const SizedBox(height: 4),
                  const Text(
                      'The customer is told and can approve the repair or ask for a replacement.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 14),
                  if (j.items.length > 1) ...[
                    const Text('Which phone?',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final (n, it) in j.items.indexed)
                        ChoiceChip(
                          showCheckmark: false,
                          label: Text('${n + 1}. ${it.name}'),
                          selected: itemId == it.id,
                          onSelected: (_) => set(() => itemId = it.id),
                          selectedColor: RC.tint,
                        ),
                    ]),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                      controller: title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          labelText:
                              'What does not match? (e.g. screen colour)')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: note,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Details (optional)')),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ps = await pickPhotos(c);
                      set(() => photos.addAll(ps));
                    },
                    icon: const Icon(PhosphorIconsFill.camera),
                    label: Text(photos.isEmpty
                        ? 'Add photos'
                        : '${photos.length} photo(s) added'),
                  ),
                  const SizedBox(height: 16),
                  AuctionButton(
                      label: 'Tell the customer',
                      danger: true,
                      onPressed: () => title.text.trim().length < 3
                          ? null
                          : Navigator.pop(c, true)),
                ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final ids = <String>[
        for (final p in photos) await _repo.uploadEvidence(p)
      ];
      return _repo.reportMismatch(j.id,
          itemId: itemId,
          title: title.text.trim(),
          note: note.text,
          mediaIds: ids);
    }, ok: 'Customer told about the mismatch.');
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(jobProvider(widget.id));
    return Scaffold(
      backgroundColor: RC.canvas,
      appBar: RepairAppBar(
        title: 'Repair Order',
        subtitle: d.value == null ? null : '#${d.value!.code}',
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Routes.repairs),
        actions: [
          if (d.value != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Builder(builder: (_) {
                final st =
                    jobStatus(d.value!.status, pickup: d.value!.isPickup);
                return StatusChip(st.label, kind: st.kind);
              }),
            ),
        ],
      ),
      body: d.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e, 'Could not load this repair.'),
            onRetry: () => ref.invalidate(jobProvider(widget.id))),
        data: _body,
      ),
      bottomNavigationBar: d.maybeWhen(data: _bottom, orElse: () => null),
    );
  }

  // ── body ────────────────────────────────────────────────────────────

  Widget _body(RepairJob j) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(jobProvider(widget.id)),
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            _Banner(j),
            const SizedBox(height: 12),
            HomeCard(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                child: RepairFlowStrip(step: flowStep(j))),
            const SizedBox(height: 14),
            if (j.status == 'ACCEPTED') _NextSteps(j),
            _CustomerCard(j, onChat: () => _open(Routes.repairChat(j.id))),
            if (!const {'REJECTED', 'CANCELLED', 'COMPLETED'}
                .contains(j.status))
              _TechCard(j, onEdit: () => _editTechnician(j)),
            if (j.status == 'ACCEPTED' || j.status == 'INSPECTION')
              _WhereCard(j, onSchedule: () => _schedule(j)),
            _OrderCard(j),
            if (const {
                  'INSPECTION',
                  'ESTIMATE_APPROVED',
                  'IN_REPAIR',
                  'QC_PENDING'
                }.contains(j.status) ||
                j.timeline.any((e) => e.kind == 'QC_MISMATCH'))
              _MismatchCard(j, onReport: () => _reportMismatch(j)),
            if (j.status == 'COMPLETED') _Finished(j),
            if (const {
              'IN_REPAIR',
              'QC_PENDING',
              'REPAIRED',
              'READY_FOR_DELIVERY',
              'COMPLETED'
            }.contains(j.status))
              _ProgressSummary(j,
                  onOpen: () => _open(Routes.repairProgress(j.id))),
            if (j.status == 'ESTIMATE_APPROVED' && j.advanceDue > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: HintBox(
                    'Collect the advance of ${formatInr(j.advanceDue)} from the customer before you start. Tap the button below once you have it.',
                    icon: PhosphorIconsFill.money,
                    kind: ChipKind.amber),
              ),
            _Updates(j),
          ]),
    );
  }

  // ── next step ───────────────────────────────────────────────────────

  Widget? _bottom(RepairJob j) {
    Widget big(String label, IconData icon, VoidCallback? onTap,
            {bool outlined = false}) =>
        AuctionButton(
            label: label,
            icon: icon,
            outlined: outlined,
            loading: _busy,
            onPressed: onTap);

    switch (j.status) {
      case 'ACCEPTED':
        if (!j.isPickup) {
          return BottomActionBar(
              child: big(
                  'Customer brought the phone',
                  PhosphorIconsBold.deviceMobile,
                  () => _run(() => _repo.step(j.id, 'receive'),
                      ok: 'Phone received.')));
        }
        if (!j.has('PICKED_UP')) {
          return BottomActionBar(
              child: big(
                  'I picked up the phone',
                  PhosphorIconsBold.check,
                  () => _run(() => _repo.step(j.id, 'picked-up'),
                      ok: 'Marked as picked up.')));
        }
        return BottomActionBar(
            child: big(
                'Phone reached my shop',
                PhosphorIconsBold.storefront,
                () => _run(() => _repo.step(j.id, 'receive'),
                    ok: 'Phone received.')));
      case 'INSPECTION':
        return BottomActionBar(
            child: big('Check the phone', PhosphorIconsBold.magnifyingGlass,
                () => _open(Routes.repairCheck(j.id))));
      case 'ESTIMATE_APPROVED':
        if (j.advanceDue > 0) {
          return BottomActionBar(
              child: big('Collect advance ${formatInr(j.advanceDue)}',
                  PhosphorIconsBold.money, () => _collectAdvance(j)));
        }
        return BottomActionBar(
            child: big('Start repair', PhosphorIconsBold.wrench, () async {
          await _run(() => _repo.step(j.id, 'start'), ok: 'Repair started.');
          if (mounted) _open(Routes.repairProgress(j.id));
        }));
      case 'IN_REPAIR':
        return BottomActionBar(
            child: big('Open repair progress', PhosphorIconsBold.wrench,
                () => _open(Routes.repairProgress(j.id))));
      case 'QC_PENDING':
        return BottomActionBar(
            child: Row(children: [
          Expanded(
              child: AuctionButton(
                  label: 'Problem found',
                  outlined: true,
                  danger: true,
                  onPressed: _busy ? null : () => _qc(j, false))),
          const SizedBox(width: 10),
          Expanded(
              flex: 2,
              child: big('Phone works fine', PhosphorIconsBold.checkCircle,
                  () => _qc(j, true))),
        ]));
      case 'REPAIRED':
        return BottomActionBar(
            child: big('Mark as ready', PhosphorIconsBold.bell,
                () => _open(Routes.repairReady(j.id))));
      case 'READY_FOR_DELIVERY':
        return BottomActionBar(
            child: big(
                'Hand over & collect payment',
                PhosphorIconsBold.handshake,
                () => _open(Routes.repairHandover(j.id))));
      default:
        return null;
    }
  }
}

// ── sections ──────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  const _Banner(this.j);
  final RepairJob j;

  @override
  Widget build(BuildContext context) {
    final (icon, title, sub, kind) = switch (j.status) {
      'ACCEPTED' => (
          PhosphorIconsFill.checkCircle,
          'Offer accepted!',
          '${j.customerName.isEmpty ? 'The customer' : j.customerName} chose your shop for ${formatInr(j.agreedTotal)}.',
          ChipKind.green
        ),
      'INSPECTION' => (
          PhosphorIconsFill.magnifyingGlass,
          'Phone is with you',
          'Check the phone, then confirm the agreed price.',
          ChipKind.blue
        ),
      'ESTIMATE_APPROVED' => (
          PhosphorIconsFill.wrench,
          'Ready to repair',
          'Price confirmed at ${formatInr(j.agreedTotal)}.',
          ChipKind.blue
        ),
      'IN_REPAIR' => (
          PhosphorIconsFill.wrench,
          'Repair in progress',
          'Update each repair as you finish it.',
          ChipKind.blue
        ),
      'QC_PENDING' => (
          PhosphorIconsFill.clipboardText,
          'Final check',
          'Make sure everything works before you hand over.',
          ChipKind.amber
        ),
      'REPAIRED' => (
          PhosphorIconsFill.sealCheck,
          'Repair complete',
          'Tell the customer their phone is ready.',
          ChipKind.green
        ),
      'READY_FOR_DELIVERY' => (
          PhosphorIconsFill.package,
          'Ready for handover',
          j.amountDue > 0
              ? '${formatInr(j.amountDue)} still to collect.'
              : 'Fully paid.',
          ChipKind.green
        ),
      'COMPLETED' => (
          PhosphorIconsFill.sealCheck,
          'Order completed',
          'Payment received. Thank you!',
          ChipKind.green
        ),
      _ => (
          PhosphorIconsFill.info,
          jobStatus(j.status).label,
          '',
          ChipKind.grey
        ),
    };
    final (fg, bg) = switch (kind) {
      ChipKind.green => (RC.green, RC.greenTint),
      ChipKind.amber => (RC.amber, RC.amberTint),
      ChipKind.grey => (RC.grey, const Color(0xFFEFF1F6)),
      _ => (RC.blue, RC.tint),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24)),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: heading(size: 17, color: fg)),
            if (sub.isNotEmpty)
              Text(sub,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: fg,
                      fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard(this.j, {required this.onChat});
  final RepairJob j;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) => RepairSection(
        title: 'Customer',
        art: A3.profile('user'),
        child: Column(children: [
          Row(children: [
            InitialsAvatar(j.customerName, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(j.customerName.isEmpty ? 'Customer' : j.customerName,
                        style: heading(size: 16)),
                    if (j.businessName != null)
                      Text(j.businessName!,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: RC.blue,
                              fontWeight: FontWeight.w700)),
                    Text(j.customerPhone,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ]),
            ),
            if (j.customerPhone.isNotEmpty)
              GestureDetector(
                onTap: () => callPhone(context, j.customerPhone),
                child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                        color: RC.green, shape: BoxShape.circle),
                    child: const Icon(PhosphorIconsFill.phone,
                        color: Colors.white, size: 22)),
              ),
          ]),
          const SizedBox(height: 12),
          Stack(clipBehavior: Clip.none, children: [
            AuctionButton(
                label: 'Chat with customer',
                height: 44,
                outlined: true,
                icon: PhosphorIconsFill.chatCircleText,
                onPressed: onChat),
            if (j.unreadMessages > 0)
              Positioned(
                right: 10,
                top: -6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: RC.red, borderRadius: BorderRadius.circular(12)),
                  child: Text('${j.unreadMessages} new',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
        ]),
      );
}

/// "Technician" card of the mockup: who is on the job, with call and chat.
class _TechCard extends StatelessWidget {
  const _TechCard(this.j, {required this.onEdit});
  final RepairJob j;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => RepairSection(
        title: 'Technician',
        art: A3.repair('technician'),
        trailing: GestureDetector(
          onTap: onEdit,
          child: Text(j.technician == null ? 'Add' : 'Change',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: RC.blue)),
        ),
        child: j.technician == null
            ? const Text('Tell the customer who is repairing their phone.',
                style:
                    TextStyle(fontSize: 13.5, color: AppColors.textSecondary))
            : Row(children: [
                InitialsAvatar(j.technician!, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(j.technician!, style: heading(size: 15.5)),
                        const Text('Repair technician',
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.textMuted)),
                      ]),
                ),
                if ((j.technicianPhone ?? '').isNotEmpty)
                  GestureDetector(
                    onTap: () => callPhone(context, j.technicianPhone!),
                    child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                            color: RC.tint, shape: BoxShape.circle),
                        child: const Icon(PhosphorIconsFill.phone,
                            color: RC.blue, size: 20)),
                  ),
              ]),
      );
}

/// "Next Step" checklist of the Offer Accepted screen.
class _NextSteps extends StatelessWidget {
  const _NextSteps(this.j);
  final RepairJob j;

  @override
  Widget build(BuildContext context) => RepairSection(
        title: 'Order summary',
        art: A3.cart('receipt'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final g in groupDevices(j.items))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                DeviceThumb(
                    brand: g.first.brand, model: g.first.model, size: 40),
                const SizedBox(width: 10),
                Expanded(child: Text(g.first.name, style: heading(size: 14.5))),
                if (g.qty > 1) StatusChip('× ${g.qty}'),
              ]),
            ),
          const Divider(height: 18, color: RC.line),
          KV('Total price', formatInr(j.agreedTotal),
              bold: true, color: RC.blue),
          const SizedBox(height: 8),
          Text('Next step', style: heading(size: 14.5)),
          const SizedBox(height: 6),
          for (final (done, label) in [
            (
              j.has('PICKED_UP') || !j.isPickup,
              j.isPickup
                  ? 'Location & address confirmed'
                  : 'Customer visit time confirmed'
            ),
            (false, 'Repair start'),
            (
              false,
              j.isPickup
                  ? 'Pickup / drop (as per plan)'
                  : 'Phone received at your shop'
            ),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Icon(
                    done
                        ? PhosphorIconsFill.checkCircle
                        : PhosphorIconsRegular.circle,
                    size: 20,
                    color: done ? RC.green : AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600))),
              ]),
            ),
        ]),
      );
}

/// QC mismatch alerts and the customer's answer.
class _MismatchCard extends StatelessWidget {
  const _MismatchCard(this.j, {required this.onReport});
  final RepairJob j;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final list = j.timeline.where((e) => e.kind == 'QC_MISMATCH').toList();
    return RepairSection(
      title: 'QC check',
      art: A3.cart('notepad'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in list) ...[
          Builder(builder: (_) {
            final resp = j.timeline
                .where((r) =>
                    r.kind == 'QC_MISMATCH_RESPONSE' && r.mismatchId == e.id)
                .firstOrNull;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: resp == null ? RC.redTint : RC.greenTint,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                          resp == null
                              ? PhosphorIconsFill.warning
                              : PhosphorIconsFill.checkCircle,
                          size: 18,
                          color: resp == null ? RC.red : RC.green),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(e.title ?? e.label,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: resp == null ? RC.red : RC.green))),
                    ]),
                    if ((e.note ?? '').isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(e.note!,
                              style: const TextStyle(fontSize: 13))),
                    const SizedBox(height: 6),
                    Text(
                        resp == null
                            ? 'Waiting for the customer to decide'
                            : (resp.choice == 'APPROVE'
                                ? 'Customer approved the repair'
                                : 'Customer wants the device replaced'),
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ]),
            );
          }),
        ],
        if (const {'INSPECTION', 'ESTIMATE_APPROVED', 'IN_REPAIR', 'QC_PENDING'}
            .contains(j.status))
          AuctionButton(
              label: 'Report a mismatch',
              height: 44,
              outlined: true,
              danger: true,
              icon: PhosphorIconsFill.warning,
              onPressed: onReport),
      ]),
    );
  }
}

/// Completed order: invoice and the customer's review.
class _Finished extends ConsumerWidget {
  const _Finished(this.j);
  final RepairJob j;

  @override
  Widget build(BuildContext context, WidgetRef ref) => RepairSection(
        title: 'Order completed',
        art: A3.repair('repaired'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (j.ratingStars != null) ...[
            Row(children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                    i <= j.ratingStars!
                        ? PhosphorIconsFill.star
                        : PhosphorIconsRegular.star,
                    size: 22,
                    color: const Color(0xFFE0A800)),
              const SizedBox(width: 8),
              Text('${j.ratingStars}/5',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            if ((j.ratingReview ?? '').isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('"${j.ratingReview}"',
                      style: const TextStyle(
                          fontSize: 14, fontStyle: FontStyle.italic))),
          ] else
            const Text('The customer has not left a review yet.',
                style:
                    TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          AuctionButton(
              label: j.invoiceId == null
                  ? 'Invoice is being prepared'
                  : 'View invoice',
              height: 46,
              outlined: true,
              icon: PhosphorIconsFill.fileText,
              onPressed: j.invoiceId == null
                  ? null
                  : () => openPdf(
                      context,
                      () => ref
                          .read(repairsRepositoryProvider)
                          .invoicePdf(j.invoiceId!),
                      'invoice-${j.code}')),
        ]),
      );
}

class _WhereCard extends StatelessWidget {
  const _WhereCard(this.j, {required this.onSchedule});
  final RepairJob j;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    if (!j.isPickup) {
      return RepairSection(
        title: 'Shop visit',
        art: A3.shop(3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KV('Customer visits', shortDate(j.appointmentAt), bold: true),
          const SizedBox(height: 4),
          const Text('The customer brings the phone to your shop at this time.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        ]),
      );
    }
    final picked = j.has('PICKED_UP');
    return RepairSection(
      title: 'Pick up from customer',
      art: A3.cart('pin'),
      trailing:
          picked ? const StatusChip('Picked up', kind: ChipKind.green) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (j.lat != null && j.lng != null) ...[
          CustomerMap(lat: j.lat!, lng: j.lng!),
          const SizedBox(height: 12),
        ],
        Text(j.address.isEmpty ? 'Address not given' : j.address,
            style: const TextStyle(
                fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const SizedBox(height: 6),
        Text('Pickup / drop mode', style: heading(size: 14)),
        const SizedBox(height: 4),
        for (final (on, label) in [
          (true, 'Pickup from customer'),
          (false, 'Customer drop / store visit')
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(
                  on
                      ? PhosphorIconsFill.radioButton
                      : PhosphorIconsRegular.circle,
                  size: 20,
                  color: on ? RC.blue : AppColors.textMuted),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                      color: on ? AppColors.navy : AppColors.textMuted)),
            ]),
          ),
        const Divider(height: 18, color: RC.line),
        KV('Pickup time',
            j.pickupSlot == null ? 'Not set yet' : shortDate(j.pickupSlot),
            bold: true, color: j.pickupSlot == null ? RC.amber : null),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: AuctionButton(
                label: 'Open in Maps',
                height: 44,
                outlined: true,
                icon: PhosphorIconsFill.navigationArrow,
                onPressed: () => openMaps(context,
                    lat: j.lat, lng: j.lng, query: j.address)),
          ),
          if (!picked) ...[
            const SizedBox(width: 10),
            Expanded(
              child: AuctionButton(
                  label: 'Set time',
                  height: 44,
                  outlined: true,
                  icon: PhosphorIconsFill.calendarBlank,
                  onPressed: onSchedule),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.j);
  final RepairJob j;

  @override
  Widget build(BuildContext context) {
    final showLines = j.agreedLines.isNotEmpty;
    return RepairSection(
      title: 'Repair details',
      art: A3.cart('receipt'),
      child: Column(children: [
        for (final (n, it) in j.items.indexed) ...[
          if (n > 0) const Divider(height: 22, color: RC.line),
          Row(children: [
            DeviceThumb(brand: it.brand, model: it.model, size: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.name, style: heading(size: 15.5)),
                    if (it.imei.isNotEmpty)
                      Text('IMEI ${it.imei}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                  ]),
            ),
          ]),
          const SizedBox(height: 10),
          for (final issue in it.issues)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                IssueBadge(issue, size: 30),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(issueMeta(issue).label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600))),
                if (j.priceOf(it.id, issue) > 0)
                  Text(formatInr(j.priceOf(it.id, issue)),
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800))
                else if (!j.inQuote(it.id, issue))
                  const StatusChip('Not in your price', kind: ChipKind.grey),
              ]),
            ),
        ],
        if (showLines) ...[
          const Divider(height: 22, color: RC.line),
          if (j.agreedTax > 0) ...[
            KV('Repair price', formatInr(j.agreedSubtotal)),
            KV('GST', formatInr(j.agreedTax)),
          ],
          KV('Total price', formatInr(j.agreedTotal),
              bold: true, color: RC.blue),
          if (j.amountPaid > 0)
            KV('Paid so far', formatInr(j.amountPaid), color: RC.green),
          if (j.amountDue > 0 && j.approvedTotal > 0)
            KV('Still to pay', formatInr(j.amountDue), color: RC.amber),
        ],
        if (j.selectedOffer != null && j.status == 'ACCEPTED') ...[
          const SizedBox(height: 4),
          KV(
              'Warranty you promised',
              j.selectedOffer!.warrantyDays == 0
                  ? 'None'
                  : '${j.selectedOffer!.warrantyDays} days'),
        ],
        if (j.warrantyUntil != null)
          KV('Warranty until', isoDay(j.warrantyUntil!)),
      ]),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary(this.j, {required this.onOpen});
  final RepairJob j;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final it in j.items)
        for (final issue in it.issues)
          if (j.inQuote(it.id, issue)) (it, issue, j.issueState(it.id, issue))
    ];
    final done =
        rows.where((r) => r.$3 == 'DONE' || r.$3 == 'NOT_NEEDED').length;
    return RepairSection(
      title: 'Repair progress',
      art: A3.repair('toolbox'),
      trailing: Text('$done / ${rows.length} done',
          style: const TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w800, color: RC.blue)),
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
              value: rows.isEmpty ? 0 : done / rows.length,
              minHeight: 8,
              backgroundColor: RC.tint,
              valueColor: const AlwaysStoppedAnimation(RC.green)),
        ),
        const SizedBox(height: 12),
        for (final (_, issue, st) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              IssueBadge(issue, size: 30),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(issueMeta(issue).label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600))),
              StatusChip(
                  switch (st) {
                    'DONE' => 'Completed',
                    'STARTED' => 'In progress',
                    'NOT_NEEDED' => 'Not needed',
                    _ => 'Waiting'
                  },
                  kind: switch (st) {
                    'DONE' => ChipKind.green,
                    'STARTED' => ChipKind.blue,
                    'NOT_NEEDED' => ChipKind.grey,
                    _ => ChipKind.amber
                  }),
            ]),
          ),
        if (j.status == 'IN_REPAIR') ...[
          const SizedBox(height: 8),
          AuctionButton(
              label: 'Update progress',
              height: 44,
              outlined: true,
              onPressed: onOpen),
        ],
      ]),
    );
  }
}

class _Updates extends StatelessWidget {
  const _Updates(this.j);
  final RepairJob j;

  @override
  Widget build(BuildContext context) {
    final list = j.timeline.reversed
        .where((e) => e.kind != 'EVIDENCE_ADDED')
        .take(12)
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return RepairSection(
      title: 'What happened',
      art: A3.cart('clock'),
      child: Column(children: [
        for (final (n, e) in list.indexed)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(
                    width: 11,
                    height: 11,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                        color: n == 0 ? RC.blue : AppColors.borderStrong,
                        shape: BoxShape.circle)),
                if (n != list.length - 1)
                  Expanded(child: Container(width: 2, color: RC.line)),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.label,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                        Text(shortDate(e.at),
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.textMuted)),
                      ]),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
