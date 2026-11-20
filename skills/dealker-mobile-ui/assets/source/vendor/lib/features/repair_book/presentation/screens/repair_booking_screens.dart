import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/features/repair_book/repair_tokens.dart';
import 'package:dealker_vendor/features/repair_book/shims/server_error.dart';
import 'package:dealker_vendor/features/repair_book/presentation/screens/repair_shop_screen.dart';
import 'package:dealker_vendor/features/repair_book/presentation/widgets/repair_helpers.dart';
import 'package:dealker_vendor/features/repair_book/presentation/widgets/repair_ui.dart';
import 'package:dealker_vendor/features/repair_book/repair_models.dart';
import 'package:dealker_vendor/features/repair_book/repair_providers.dart';

/// What every booking screen needs: the request and the shop's quote.
class _Ctx {
  const _Ctx(this.request, this.offer);

  final RepairRequest? request;
  final RepairOffer? offer;
}

_Ctx _ctx(WidgetRef ref, String repairId, String offerId) => _Ctx(
      ref.watch(repairRequestProvider(repairId)).asData?.value,
      offerById(
        ref.watch(repairOffersProvider('$repairId|best')).asData?.value,
        offerId,
      ),
    );

Widget _missing(WidgetRef ref, String repairId, String title) => RepairShell(
      title: title,
      step: RepairStep.book,
      body: ref.watch(repairOffersProvider('$repairId|best')).hasError
          ? RErrorView(
              onRetry: () =>
                  ref.invalidate(repairOffersProvider('$repairId|best')),
            )
          : const RSkeletonCards(count: 2, cardHeight: 200),
    );

/// The shop the customer picked: tile, name, area, rating and price.
class _SelectedShop extends StatelessWidget {
  const _SelectedShop({
    required this.offer,
    this.onChange,
    this.compact = false,
    this.bare = false,
  });

  final RepairOffer offer;
  final VoidCallback? onChange;
  final bool compact;

  /// Draw only the content (the parent already is a card).
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final String sub = <String>[
      if (offer.distanceLabel != null) offer.distanceLabel!,
      if (shopArea(offer.address).isNotEmpty) shopArea(offer.address),
    ].join(' · ');
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ShopTile(size: 60),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    offer.vendorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: rtHead(16.5),
                  ),
                  if (sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: <Widget>[
                          const PhosphorIcon(
                            PhosphorIconsRegular.mapPin,
                            size: 14,
                            color: RT.grey,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: rtBody(13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (offer.hasRating)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: <Widget>[
                          const PhosphorIcon(
                            PhosphorIconsFill.star,
                            size: 14,
                            color: RT.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            offer.rating!.toStringAsFixed(1),
                            style: rtHead(13.5, color: RT.green),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '(${compactCount(offer.ratingCount)} reviews)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: rtBody(13),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (!compact) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text(rupees(offer.total), style: rtHead(21)),
              const Spacer(),
              if (onChange != null) RLink('Change shop', onTap: onChange!),
            ],
          ),
        ],
      ],
    );
    return bare
        ? content
        : RCard(padding: const EdgeInsets.all(14), child: content);
  }
}

// ── 08: choose the appointment type ────────────────────────────────────────

class RepairAppointmentTypeScreen extends ConsumerStatefulWidget {
  const RepairAppointmentTypeScreen({
    required this.repairId,
    required this.offerId,
    super.key,
  });

  final String repairId;
  final String offerId;

  @override
  ConsumerState<RepairAppointmentTypeScreen> createState() =>
      _AppointmentTypeState();
}

class _AppointmentTypeState extends ConsumerState<RepairAppointmentTypeScreen> {
  String? _picked; // 'store' | 'pickup'

  @override
  Widget build(BuildContext context) {
    final _Ctx c = _ctx(ref, widget.repairId, widget.offerId);
    final RepairOffer? o = c.offer;
    if (o == null) return _missing(ref, widget.repairId, 'Choose appointment');
    // Pre-select when only one is offered.
    final String? first =
        o.shopVisit ? 'store' : (o.pickupDelivery ? 'pickup' : null);
    final String? sel = _picked ?? first;

    return RepairShell(
      title: 'Choose appointment',
      step: RepairStep.book,
      bottom: RButton(
        label: 'Continue',
        onTap: sel == null || !o.usable
            ? null
            : () => context.push(
                  '/repair/${widget.repairId}/book/${widget.offerId}/${sel == 'store' ? 'store' : 'pickup'}',
                ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(RT.gutter, 16, RT.gutter, 24),
        children: <Widget>[
          Text('Selected shop', style: rtHead(18)),
          const SizedBox(height: 12),
          _SelectedShop(offer: o, onChange: () => context.pop()),
          const SizedBox(height: 22),
          Text(
            'How will the shop get your phone?',
            style: rtHead(20, h: 1.2),
          ),
          const SizedBox(height: 6),
          Text('Pick the easiest way for you.', style: rtBody(14)),
          const SizedBox(height: 16),
          _TypeCard(
            icon: PhosphorIconsRegular.storefront,
            title: 'I will go to the shop',
            sub: 'You choose the day and time.',
            bullets: const <String>[
              'Pick a day and time',
              'Take your phone to the shop',
              'Collect it when it is fixed',
            ],
            enabled: o.shopVisit,
            disabledNote: 'This shop doesn’t take store visits.',
            selected: sel == 'store',
            onTap: () => setState(() => _picked = 'store'),
          ),
          const SizedBox(height: RT.gap),
          _TypeCard(
            icon: PhosphorIconsRegular.truck,
            title: 'Pick it up from my home',
            sub: 'The shop collects it and brings it back.',
            bullets: const <String>[
              'Pick a time',
              'It is collected from your address',
              'Brought back to you fixed',
            ],
            enabled: o.pickupDelivery,
            disabledNote: 'This shop doesn’t offer pickup.',
            selected: sel == 'pickup',
            onTap: () => setState(() => _picked = 'pickup'),
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.bullets,
    required this.enabled,
    required this.disabledNote,
    required this.selected,
    required this.onTap,
  });

  final PhosphorIconData icon;
  final String title;
  final String sub;
  final List<String> bullets;
  final bool enabled;
  final String disabledNote;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: RCard(
        onTap: enabled ? onTap : null,
        color: selected ? const Color(0xFFF3F7FF) : Colors.white,
        borderColor: selected ? RT.indigo : RT.border,
        borderWidth: selected ? 1.6 : 1,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                RIconTile(icon, size: 48, iconSize: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: rtHead(16.5)),
                      const SizedBox(height: 3),
                      Text(sub, style: rtBody(13.5, h: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? RT.indigo : RT.border,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: RT.indigo,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const Divider(height: 24, color: RT.border),
            if (!enabled)
              Text(disabledNote, style: rtBody(13.5, color: RT.muted))
            else
              for (final String b in bullets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      const PhosphorIcon(
                        PhosphorIconsBold.check,
                        size: 15,
                        color: RT.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(b, style: rtBody(14, color: RT.ink)),
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

// ── day / time pickers shared by 09A and 09B ───────────────────────────────

class _DayChips extends StatelessWidget {
  const _DayChips({
    required this.days,
    required this.selected,
    required this.onTap,
  });

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onTap;

  static const List<String> _wd = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();
    return SizedBox(
      height: 76,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final DateTime d in days)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onTap(d),
                child: Container(
                  width: 62,
                  decoration: BoxDecoration(
                    color: d.day == selected.day && d.month == selected.month
                        ? RT.tint
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: d.day == selected.day && d.month == selected.month
                          ? RT.indigo
                          : RT.border,
                      width: d.day == selected.day && d.month == selected.month
                          ? 1.6
                          : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        d.day == today.day && d.month == today.month
                            ? 'Today'
                            : _wd[d.weekday - 1],
                        style: rtBody(
                          12.5,
                          color:
                              d.day == selected.day && d.month == selected.month
                                  ? RT.indigo
                                  : RT.grey,
                          w: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.day}',
                        style: rtHead(
                          20,
                          color:
                              d.day == selected.day && d.month == selected.month
                                  ? RT.indigo
                                  : RT.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<DateTime> _nextDays([int n = 7]) {
  final DateTime t = DateTime.now();
  return <DateTime>[
    for (int i = 0; i < n; i++) DateTime(t.year, t.month, t.day + i),
  ];
}

class _Slot {
  const _Slot(this.label, this.start, this.end);

  final String label;
  final int start; // hour
  final int end;
}

// ── 09A: store appointment ─────────────────────────────────────────────────

class RepairStoreBookingScreen extends ConsumerStatefulWidget {
  const RepairStoreBookingScreen({
    required this.repairId,
    required this.offerId,
    super.key,
  });

  final String repairId;
  final String offerId;

  @override
  ConsumerState<RepairStoreBookingScreen> createState() => _StoreBookingState();
}

class _StoreBookingState extends ConsumerState<RepairStoreBookingScreen> {
  late final List<DateTime> _days = _nextDays();
  late DateTime _day = _days.firstWhere(
    (DateTime d) => _groups.any(
      ((String, List<int>) g) => g.$2.any(
        (int h) => DateTime(d.year, d.month, d.day, h)
            .isAfter(DateTime.now().add(const Duration(minutes: 30))),
      ),
    ),
    orElse: () => _days.first,
  );
  int? _hour;
  bool _busy = false;
  String? _error;

  static const List<(String, List<int>)> _groups = <(String, List<int>)>[
    ('Morning', <int>[10, 11, 12]),
    ('Afternoon', <int>[14, 15, 16]),
    ('Evening', <int>[17, 18, 19]),
  ];

  static String _label(int h) =>
      '${h > 12 ? h - 12 : h}:00 ${h >= 12 ? 'PM' : 'AM'}';

  bool _past(int h) => DateTime(_day.year, _day.month, _day.day, h)
      .isBefore(DateTime.now().add(const Duration(minutes: 30)));

  Future<void> _confirm() async {
    if (_hour == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repairApiProvider).selectStoreVisit(
            requestId: widget.repairId,
            offerId: widget.offerId,
            appointmentAt: DateTime(_day.year, _day.month, _day.day, _hour!),
          );
      ref.invalidate(repairRequestProvider(widget.repairId));
      ref.invalidate(repairMineProvider);
      ref.invalidate(repairOffersProvider('${widget.repairId}|best'));
      if (mounted) context.go('/repair/${widget.repairId}/confirmed');
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = isOfflineError(e)
              ? 'You’re offline. Try again when you’re connected.'
              : ServerError.from(e).message,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final _Ctx c = _ctx(ref, widget.repairId, widget.offerId);
    final RepairOffer? o = c.offer;
    if (o == null) return _missing(ref, widget.repairId, 'Book a visit');
    final bool allPastToday =
        _groups.every(((String, List<int>) g) => g.$2.every(_past));

    return RepairShell(
      title: 'Book a visit',
      step: RepairStep.book,
      bottom: RButton(
        label: 'Confirm appointment',
        loading: _busy,
        onTap: _hour == null ? null : _confirm,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(RT.gutter, 16, RT.gutter, 24),
        children: <Widget>[
          Text('Book your visit', style: rtHead(22)),
          const SizedBox(height: 6),
          Text(
            'Choose when you’ll bring your phone to the shop.',
            style: rtBody(14),
          ),
          const SizedBox(height: 16),
          RCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SelectedShop(offer: o, compact: true, bare: true),
                if ((o.address ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(o.address!, style: rtBody(13.5, h: 1.35)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: RLink(
                      'Directions',
                      icon: PhosphorIconsRegular.arrowBendUpRight,
                      onTap: () =>
                          openMaps(context, '${o.vendorName}, ${o.address}'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Choose a day', style: rtHead(18)),
          const SizedBox(height: 12),
          _DayChips(
            days: _days,
            selected: _day,
            onTap: (DateTime d) => setState(() {
              _day = d;
              _hour = null;
            }),
          ),
          const SizedBox(height: 22),
          Text('Available time slots', style: rtHead(18)),
          const SizedBox(height: 10),
          if (allPastToday)
            const RBand(
              'No slots left today. Pick another day.',
              kind: BandKind.warn,
            )
          else
            for (final (String name, List<int> hours) in _groups) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(name, style: rtBody(13.5)),
              ),
              Row(
                children: <Widget>[
                  for (int i = 0; i < hours.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _SlotChip(
                        label: _label(hours[i]),
                        selected: _hour == hours[i],
                        disabled: _past(hours[i]),
                        onTap: () => setState(() => _hour = hours[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          const SizedBox(height: 14),
          Text(
            'The shop will confirm your time.',
            style: rtBody(12.5, color: RT.muted),
          ),
          if (_hour != null) ...<Widget>[
            const SizedBox(height: 18),
            _Summary(
              rows: <(String, String)>[
                ('Device', c.request?.deviceName ?? ''),
                ('Shop', o.vendorName),
                ('Repair price', rupees(o.total)),
                ('Appointment', '${fmtDay(_day)} · ${_label(_hour!)}'),
              ],
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: RT.gap),
            RBand(_error!, kind: BandKind.danger),
          ],
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled ? RT.field : (selected ? RT.tint : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? RT.indigo : RT.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Text(
          label,
          style: rtHead(
            13.5,
            color: disabled ? RT.muted : (selected ? RT.indigo : RT.ink),
            w: FontWeight.w700,
          ).copyWith(
            decoration: disabled ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return RCard(
      color: const Color(0xFFF5F8FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Summary', style: rtHead(15.5)),
          const SizedBox(height: 8),
          for (final (String k, String v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(width: 110, child: Text(k, style: rtBody(13.5))),
                  Expanded(
                    child: Text(
                      v,
                      textAlign: TextAlign.right,
                      style: rtHead(14, w: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── 09B: pickup & delivery ─────────────────────────────────────────────────

class RepairPickupBookingScreen extends ConsumerStatefulWidget {
  const RepairPickupBookingScreen({
    required this.repairId,
    required this.offerId,
    super.key,
  });

  final String repairId;
  final String offerId;

  @override
  ConsumerState<RepairPickupBookingScreen> createState() =>
      _PickupBookingState();
}

class _PickupBookingState extends ConsumerState<RepairPickupBookingScreen> {
  late final List<DateTime> _days = _nextDays();
  late DateTime _day = _days.firstWhere(
    (DateTime d) => _windows.any(
      (_Slot w) => DateTime(d.year, d.month, d.day, w.end)
          .isAfter(DateTime.now().add(const Duration(minutes: 30))),
    ),
    orElse: () => _days.first,
  );
  int? _window;
  String? _addressId;
  bool _busy = false;
  String? _error;

  static const List<_Slot> _windows = <_Slot>[
    _Slot('10 AM–1 PM', 10, 13),
    _Slot('1 PM–4 PM', 13, 16),
    _Slot('4 PM–7 PM', 16, 19),
  ];

  bool _past(_Slot s) => DateTime(_day.year, _day.month, _day.day, s.end)
      .isBefore(DateTime.now().add(const Duration(minutes: 30)));

  DateTime _start(_Slot s) {
    final DateTime start = DateTime(_day.year, _day.month, _day.day, s.start);
    // A window already under way today starts a little from now.
    return start.isBefore(DateTime.now().add(const Duration(minutes: 30)))
        ? DateTime.now().add(const Duration(minutes: 45))
        : start;
  }

  Future<void> _confirm(SavedAddress a) async {
    if (_window == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repairApiProvider).selectPickup(
            requestId: widget.repairId,
            offerId: widget.offerId,
            addressId: a.id,
            slot: _start(_windows[_window!]),
          );
      ref.invalidate(repairRequestProvider(widget.repairId));
      ref.invalidate(repairMineProvider);
      ref.invalidate(repairOffersProvider('${widget.repairId}|best'));
      if (mounted) context.go('/repair/${widget.repairId}/confirmed');
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = isOfflineError(e)
              ? 'You’re offline. Try again when you’re connected.'
              : ServerError.from(e).message,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final _Ctx c = _ctx(ref, widget.repairId, widget.offerId);
    final RepairOffer? o = c.offer;
    if (o == null) return _missing(ref, widget.repairId, 'Schedule pickup');
    final AsyncValue<List<SavedAddress>> addrs =
        ref.watch(repairAddressesProvider);
    final List<SavedAddress> list =
        addrs.asData?.value ?? const <SavedAddress>[];
    final SavedAddress? chosen =
        list.where((SavedAddress a) => a.id == _addressId).firstOrNull ??
            list.where((SavedAddress a) => a.isDefault).firstOrNull ??
            list.firstOrNull;
    final _Slot? w = _window == null ? null : _windows[_window!];

    return RepairShell(
      title: 'Schedule pickup',
      step: RepairStep.book,
      bottom: RButton(
        label: 'Confirm pickup',
        loading: _busy,
        onTap: chosen == null || w == null ? null : () => _confirm(chosen),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(RT.gutter, 16, RT.gutter, 24),
        children: <Widget>[
          Text('Schedule pickup', style: rtHead(22)),
          const SizedBox(height: 6),
          Text('We’ll collect the phone from your address.', style: rtBody(14)),
          const SizedBox(height: 16),
          if (addrs.isLoading && list.isEmpty)
            const RSkeleton(height: 90, radius: 16)
          else if (chosen == null)
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Pickup address', style: rtHead(15.5)),
                  const SizedBox(height: 6),
                  Text(
                    'Add the address where the courier should collect your phone.',
                    style: rtBody(13.5),
                  ),
                  const SizedBox(height: 12),
                  RButton(
                    label: 'Add address',
                    outline: true,
                    onTap: () async {
                      await context.push('/profile/addresses/add');
                      ref.invalidate(repairAddressesProvider);
                    },
                  ),
                ],
              ),
            )
          else
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text('Pickup address', style: rtHead(15.5)),
                      ),
                      RLink(
                        'Change',
                        onTap: () async {
                          final String? id =
                              await pickAddress(context, list, chosen.id);
                          if (id == null || !mounted) return;
                          if (id == '__new') {
                            await context.push('/profile/addresses/add');
                            ref.invalidate(repairAddressesProvider);
                          } else {
                            setState(() => _addressId = id);
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: PhosphorIcon(
                          PhosphorIconsRegular.mapPin,
                          size: 21,
                          color: RT.indigo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(chosen.label, style: rtHead(15.5)),
                            Text(
                              chosen.full,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: rtBody(13.5, h: 1.3),
                            ),
                            if (chosen.area.isNotEmpty)
                              Text(chosen.area, style: rtBody(13.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),
          Text('Choose pickup time', style: rtHead(18)),
          const SizedBox(height: 12),
          _DayChips(
            days: _days,
            selected: _day,
            onTap: (DateTime d) => setState(() {
              _day = d;
              _window = null;
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              for (int i = 0; i < _windows.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _SlotChip(
                    label: _windows[i].label,
                    selected: _window == i,
                    disabled: _past(_windows[i]),
                    onTap: () => setState(() => _window = i),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Keep the phone switched on and take it out of its case. Back up your data first.',
            style: rtBody(12.5, color: RT.muted, h: 1.4),
          ),
          if (w != null && chosen != null) ...<Widget>[
            const SizedBox(height: 18),
            _Summary(
              rows: <(String, String)>[
                ('Device', c.request?.deviceName ?? ''),
                ('Shop', o.vendorName),
                ('Repair price', rupees(o.total)),
                ('Pickup', '${fmtDay(_day)} · ${w.label}'),
                (
                  'From',
                  '${chosen.label} · ${chosen.area.isEmpty ? chosen.line1 : chosen.area}'
                ),
              ],
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: RT.gap),
            RBand(_error!, kind: BandKind.danger),
          ],
        ],
      ),
    );
  }
}

// ── 10: booking confirmed ──────────────────────────────────────────────────

class RepairConfirmedScreen extends ConsumerWidget {
  const RepairConfirmedScreen({required this.repairId, super.key});

  final String repairId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RepairRequest> async =
        ref.watch(repairRequestProvider(repairId));
    final RepairRequest? r = async.asData?.value;
    if (r == null) {
      return RepairShell(
        title: 'Booking confirmed',
        step: RepairStep.book,
        onBack: () => context.go('/repair/$repairId'),
        body: async.hasError
            ? RErrorView(
                onRetry: () => ref.invalidate(repairRequestProvider(repairId)),
              )
            : const RSkeletonCards(count: 2),
      );
    }
    final bool store = r.isStore;
    final DateTime? when = store ? r.appointmentAt : r.pickupSlot;
    final List<(String, String)> next = store
        ? const <(String, String)>[
            ('Visit the shop', 'At your chosen time'),
            ('Shop checks and confirms price', 'You approve any change'),
            ('Repair', 'The shop updates you here'),
            ('Collect your phone', 'When it’s ready'),
          ]
        : const <(String, String)>[
            ('Courier picks up your phone', 'At your chosen time'),
            ('Shop checks and confirms price', 'You approve any change'),
            ('Repair', 'The shop updates you here'),
            ('Delivery back to you', 'After quality check'),
          ];

    return RepairShell(
      title: 'Booking confirmed',
      step: RepairStep.book,
      onBack: () => context.go('/repair/$repairId'),
      bottom: RButton(
        label: 'Track repair',
        onTap: () => context.go('/repair/$repairId'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(RT.gutter, 22, RT.gutter, 24),
        children: <Widget>[
          const Center(
            child: RIconTile(
              PhosphorIconsBold.check,
              size: 62,
              iconSize: 28,
              circle: true,
              color: RT.green,
              bg: RT.greenTint,
            ),
          ),
          const SizedBox(height: 14),
          Text('You’re booked', textAlign: TextAlign.center, style: rtHead(22)),
          const SizedBox(height: 6),
          Text(
            '${r.serviceCenter ?? 'The shop'} is expecting ${store ? 'you' : 'your phone'}.',
            textAlign: TextAlign.center,
            style: rtBody(14),
          ),
          const SizedBox(height: 20),
          RCard(
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text('Booking ${r.code}', style: rtHead(15.5)),
                    ),
                    RPill(store ? 'Store appointment' : 'Pickup & delivery'),
                  ],
                ),
                const Divider(height: 24, color: RT.border),
                _row('Device', r.deviceName),
                if (r.serviceCenter != null) _row('Shop', r.serviceCenter!),
                if (when != null)
                  _row(
                    store ? 'Appointment' : 'Pickup',
                    '${fmtDay(when)} · ${fmtTime(when)}',
                  ),
                if (!store && (r.pickupAddress ?? '').isNotEmpty)
                  _row('Address', r.pickupAddress!),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('What happens next', style: rtHead(18)),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < next.length; i++)
                  Padding(
                    padding:
                        EdgeInsets.only(bottom: i == next.length - 1 ? 0 : 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: i == 0 ? RT.indigo : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  i == 0 ? RT.indigo : const Color(0xFFC9CDE0),
                              width: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                next[i].$1,
                                style: rtHead(
                                  15,
                                  color: i == 0 ? RT.indigo : RT.ink,
                                ),
                              ),
                              Text(next[i].$2, style: rtBody(12.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(width: 92, child: Text(k, style: rtBody(14))),
            Expanded(
              child: Text(
                v,
                textAlign: TextAlign.right,
                style: rtHead(14.5, w: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
