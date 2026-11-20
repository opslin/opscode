import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/shared/widgets/premium_ui.dart' show A3;
import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show
        AuctionButton,
        BottomActionBar,
        EmptyState,
        ErrorState,
        errorText;
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/features/repairs/application/repairs_providers.dart';
import 'package:dealker_vendor/features/repairs/data/repair_models.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// "My repair prices": the price list that lets Dealkr quote for you automatically,
/// plus the switch that turns repair requests on or off.
class RepairPricesScreen extends ConsumerWidget {
  const RepairPricesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(servicesProvider);
    final profile = ref.watch(repairProfileProvider);
    return Scaffold(
      backgroundColor: RC.canvas,
      appBar: RepairAppBar(
          title: 'My Repair Prices',
          subtitle: 'Set once — quote faster',
          onBack: () =>
              context.canPop() ? context.pop() : context.go(Routes.repairs)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(servicesProvider);
          ref.invalidate(repairProfileProvider);
        },
        child: list.when(skipLoadingOnReload: true, skipError: true, 
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
              message: errorText(e),
              onRetry: () => ref.invalidate(servicesProvider)),
          data: (rows) {
            final groups = <String, List<ServiceRow>>{};
            for (final r in rows) {
              groups.putIfAbsent('${r.brand}|${r.model}', () => []).add(r);
            }
            return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                children: [
                  _AcceptSwitch(profile, total: rows.length),
                  const SizedBox(height: 14),
                  if (rows.isEmpty)
                    SizedBox(
                      height: 340,
                      child: EmptyState(
                        icon: PhosphorIconsFill.tag,
                        title: 'No prices yet',
                        message:
                            'Add the phones you repair and what you charge. Dealkr then sends customers your price automatically.',
                        action: SizedBox(
                            width: 210,
                            child: AuctionButton(
                                label: 'Add repair service',
                                height: 46,
                                icon: PhosphorIconsBold.plus,
                                onPressed: () =>
                                    context.push(Routes.repairPriceAdd))),
                      ),
                    ),
                  for (final g in groups.values) ...[
                    // a small brand header when this device is the first of its brand
                    if (g.first.brand != lastBrand(groups, g))
                      _BrandHeader(g.first.brand,
                          groups.values.where((x) => x.first.brand == g.first.brand).length),
                    _DeviceGroup(g),
                  ],
                ]);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: RC.blue,
        onPressed: () => context.push(Routes.repairPriceAdd),
        icon: const Icon(PhosphorIconsBold.plus, color: Colors.white),
        label: const Text('Add repair service',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// Brand of the group just before [g] (null for the first), so a brand header is drawn once per brand.
String? lastBrand(Map<String, List<ServiceRow>> groups, List<ServiceRow> g) {
  String? prev;
  for (final x in groups.values) {
    if (identical(x, g)) return prev;
    prev = x.first.brand;
  }
  return prev;
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader(this.brand, this.models);
  final String brand;
  final int models;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: RC.tint, borderRadius: BorderRadius.circular(10)),
            child: Text(brand.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11.5, letterSpacing: 0.7, fontWeight: FontWeight.w800, color: RC.blue)),
          ),
          const SizedBox(width: 8),
          Text('$models model${models == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ]),
      );
}

class _AcceptSwitch extends ConsumerWidget {
  const _AcceptSwitch(this.profile, {required this.total});
  final AsyncValue<({bool accepting, int activeServices})> profile;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile.value;
    final on = p?.accepting ?? true;
    final live = p?.activeServices ?? 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: on
                ? const [Color(0xFF0E7C45), Color(0xFF22A861)]
                : const [Color(0xFF59627A), Color(0xFF8A93AB)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: (on ? const Color(0xFF16A34A) : const Color(0xFF59627A)).withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Icon(on ? PhosphorIconsFill.mapPinArea : PhosphorIconsFill.eyeSlash, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Service available nearby',
                style: heading(size: 15.5, color: Colors.white, w: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(on ? 'Customers around you can see your shop' : 'You are hidden — no new requests',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.88))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
              child: Text('$live of $total repairs live',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: p == null
              ? null
              : () async {
                  try {
                    await ref.read(repairsRepositoryProvider).setAccepting(!on);
                    ref.invalidate(repairProfileProvider);
                    ref.invalidate(incomingProvider);
                  } catch (e) {
                    if (context.mounted) showAppToast(context, errorText(e), error: true);
                  }
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 62,
            height: 36,
            padding: const EdgeInsets.all(4),
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: on ? 0.95 : 0.35),
                borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: on ? const Color(0xFF16A34A) : Colors.white, shape: BoxShape.circle),
              child: Icon(on ? PhosphorIconsBold.check : PhosphorIconsBold.x,
                  size: 15, color: on ? Colors.white : const Color(0xFF59627A)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _DeviceGroup extends ConsumerWidget {
  const _DeviceGroup(this.rows);
  final List<ServiceRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = rows.first;
    return RepairSection(
      title: deviceName(first.brand, first.model),
      icon: null,
      trailing: DeviceThumb(brand: first.brand, model: first.model, size: 40),
      child: Column(children: [
        for (final (n, r) in rows.indexed) ...[
          if (n > 0) const Divider(height: 18, color: RC.line),
          Row(children: [
            IssueBadge(r.problem, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(issueMeta(r.problem).label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: r.isActive
                                ? AppColors.navy
                                : AppColors.textMuted)),
                    Text(
                        'Part ${formatInr(r.partsPrice)} + Work ${formatInr(r.labourPrice)} • '
                        '${daysLabel(r.estDaysMin, r.estDaysMax)}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary)),
                  ]),
            ),
            Text(formatInr(r.total),
                style: heading(
                    size: 15,
                    color: r.isActive ? RC.blue : AppColors.textMuted)),
            PopupMenuButton<String>(
              icon: const Icon(PhosphorIconsBold.dotsThreeVertical, size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: (v) async {
                try {
                  final repo = ref.read(repairsRepositoryProvider);
                  if (v == 'toggle') await repo.setActive(r.id, !r.isActive);
                  if (v == 'delete') await repo.deleteService(r.id);
                  ref.invalidate(servicesProvider);
                } catch (e) {
                  if (context.mounted)
                    showAppToast(context, errorText(e), error: true);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'toggle',
                    child: Text(r.isActive ? 'Pause this price' : 'Turn on')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Remove', style: TextStyle(color: RC.red))),
              ],
            ),
          ]),
        ],
      ]),
    );
  }
}

// ── add a repair service ─────────────────────────────────────────────

/// "Add Repair Service": pick the phone, tick what you repair, set price + time + warranty.
class AddRepairServiceScreen extends ConsumerStatefulWidget {
  const AddRepairServiceScreen({super.key});

  @override
  ConsumerState<AddRepairServiceScreen> createState() =>
      _AddRepairServiceScreenState();
}

class _AddRepairServiceScreenState
    extends ConsumerState<AddRepairServiceScreen> {
  CatalogBrand? _brand;
  CatalogModel? _model;
  String _q = '';
  final Map<String,
          ({TextEditingController parts, TextEditingController labour})>
      _price = {};
  final Set<String> _on = {};
  final Map<String, TextEditingController> _partName = {};
  int _min = 1;
  int _max = 2;
  int _warranty = 90;
  bool _pickup = true;
  bool _busy = false;

  static const _keys = [
    'SCREEN',
    'BATTERY',
    'CHARGING',
    'WATER_DAMAGE',
    'SOFTWARE',
    'CAMERA',
    'AUDIO',
    'BODY',
    'BOARD',
    'BIOMETRIC',
    'DATA',
    'TOUCH',
    'NETWORK',
    'OTHER',
  ];

  @override
  void dispose() {
    for (final p in _price.values) {
      p.parts.dispose();
      p.labour.dispose();
    }
    for (final c in _partName.values) {
      c.dispose();
    }
    super.dispose();
  }

  ({
    TextEditingController parts,
    TextEditingController labour
  }) _ctl(String k) => _price.putIfAbsent(k,
      () => (parts: TextEditingController(), labour: TextEditingController()));

  Future<void> _save() async {
    final services = <Map<String, dynamic>>[];
    for (final k in _on) {
      final c = _ctl(k);
      final parts = num.tryParse(c.parts.text) ?? 0;
      final labour = num.tryParse(c.labour.text) ?? 0;
      if (parts + labour <= 0) {
        showAppToast(context, 'Set a price for ${issueMeta(k).label}.',
            error: true);
        return;
      }
      services.add({
        'problemCategory': k,
        'partsPrice': parts,
        'labourPrice': labour,
        'estDaysMin': _min,
        'estDaysMax': _max,
        'warrantyDays': _warranty,
        if ((_partName[k]?.text ?? '').trim().isNotEmpty) 'title': _partName[k]!.text.trim(),
      });
    }
    if (services.isEmpty) {
      showAppToast(context, 'Tick at least one repair.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(repairsRepositoryProvider).saveServices(
            deviceCategory:
                _model!.category.isEmpty ? 'Smartphone' : _model!.category,
            brand: _brand!.name,
            model: _model!.name,
            services: services,
            pickupDelivery: _pickup,
          );
      ref.invalidate(servicesProvider);
      ref.invalidate(repairProfileProvider);
      if (mounted) {
        showAppToast(context, 'Prices saved.');
        context.pop();
      }
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _brand == null ? 0 : (_model == null ? 1 : 2);
    return Scaffold(
      backgroundColor: RC.canvas,
      appBar: RepairAppBar(
        title: 'Add Repair Service',
        subtitle: [
          '1 of 3 — Choose brand',
          '2 of 3 — Choose phone',
          '3 of 3 — Set prices'
        ][step],
        onBack: () {
          if (step == 2) {
            setState(() => _model = null);
          } else if (step == 1) {
            setState(() {
              _brand = null;
              _q = '';
            });
          } else {
            context.pop();
          }
        },
      ),
      body: switch (step) {
        0 => _brands(),
        1 => _models(),
        _ => _form(),
      },
      bottomNavigationBar: step != 2
          ? null
          : BottomActionBar(
              child: AuctionButton(
                  label: 'Save prices',
                  icon: PhosphorIconsBold.check,
                  loading: _busy,
                  onPressed: _save)),
    );
  }

  /// Small text prompt used for "Other brand" and "my model isn't listed".
  Future<String?> _ask(String title, String hint) async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: c,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: hint, counterText: '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Use this')),
        ],
      ),
    );
    c.dispose();
    return (v != null && v.length >= 2) ? v : null;
  }

  Future<void> _addOwnModel() async {
    final typed = await _ask('Model name or number', 'e.g. Galaxy A54  /  SM-A546E');
    if (typed != null) setState(() => _model = CatalogModel(typed, 'Smartphone', null));
  }

  Widget _brands() {
    final b = ref.watch(catalogBrandsProvider);
    return b.when(skipLoadingOnReload: true, skipError: true, 
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
          message: errorText(e),
          onRetry: () => ref.invalidate(catalogBrandsProvider)),
      data: (list) => GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
        children: [
          for (final br in [...list, const CatalogBrand('Other brand', null)])
            GestureDetector(
              onTap: () async {
                if (br.name == 'Other brand') {
                  final typed = await _ask('Brand name', 'e.g. Nothing, Motorola, Lava');
                  if (typed != null) setState(() => _brand = CatalogBrand(typed, null));
                } else {
                  setState(() => _brand = br);
                }
              },
              child: HomeCard(
                padding: const EdgeInsets.all(10),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (br.logoUrl != null && br.logoUrl!.isNotEmpty)
                        SizedBox(
                            height: 34,
                            child: CachedNetworkImage(
                                imageUrl: absoluteUrl(br.logoUrl!),
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => const Icon(
                                    PhosphorIconsFill.deviceMobile,
                                    color: RC.blue)))
                      else
                        const Icon(PhosphorIconsFill.deviceMobile,
                            color: RC.blue, size: 30),
                      const SizedBox(height: 8),
                      Text(br.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                    ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _models() {
    final m = ref.watch(catalogModelsProvider(_brand!.name));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: 'Search ${_brand!.name} phone',
            prefixIcon:
                const Icon(PhosphorIconsRegular.magnifyingGlass, size: 19),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: RC.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: RC.blue)),
          ),
        ),
      ),
      Expanded(
        child: m.when(skipLoadingOnReload: true, skipError: true, 
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
              message: errorText(e),
              onRetry: () =>
                  ref.invalidate(catalogModelsProvider(_brand!.name))),
          data: (list) {
            final f = list
                .where((x) => x.name.toLowerCase().contains(_q.toLowerCase()))
                .toList();
            if (f.isEmpty) {
              return EmptyState(
                  icon: PhosphorIconsFill.deviceMobile,
                  title: 'Phone not found',
                  message: 'Try another spelling, or add your model by name or number.',
                  action: TextButton.icon(
                    onPressed: _addOwnModel,
                    icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                    label: const Text('Add my model'),
                  ));
            }
            return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  TextButton.icon(
                    onPressed: _addOwnModel,
                    icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                    label: const Text('My model isn’t listed — add by name or number'),
                  ),
                  for (final x in f)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _model = x),
                        child: HomeCard(
                          padding: const EdgeInsets.all(10),
                          child: Row(children: [
                            DeviceThumb(
                                brand: _brand!.name, model: x.name, size: 52),
                            const SizedBox(width: 12),
                            Expanded(
                                child:
                                    Text(x.name, style: heading(size: 15.5))),
                            const Icon(PhosphorIconsBold.caretRight,
                                size: 16, color: AppColors.textMuted),
                          ]),
                        ),
                      ),
                    ),
                ]);
          },
        ),
      ),
    ]);
  }

  Widget _form() {
    final opts = ref.watch(issueOptionsProvider).value;
    final keys =
        opts == null || opts.isEmpty ? _keys : [for (final o in opts) o.key];
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          HomeCard(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              DeviceThumb(brand: _brand!.name, model: _model!.name, size: 56),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(deviceName(_brand!.name, _model!.name),
                      style: heading(size: 16))),
            ]),
          ),
          const SizedBox(height: 14),
          RepairSection(
            title: 'What do you repair?',
            art: A3.repair('toolbox'),
            child: Column(children: [
              for (final k in keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(
                          () => _on.contains(k) ? _on.remove(k) : _on.add(k)),
                      child: Row(children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: _on.contains(k) ? RC.blue : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _on.contains(k)
                                    ? RC.blue
                                    : AppColors.borderStrong,
                                width: 1.6),
                          ),
                          child: _on.contains(k)
                              ? const Icon(PhosphorIconsBold.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        IssueBadge(k, size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(issueMeta(k).label,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800))),
                      ]),
                    ),
                    if (_on.contains(k))
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 36),
                        child: Column(children: [
                          TextField(
                            controller: _partName.putIfAbsent(k, TextEditingController.new),
                            maxLength: 60,
                            decoration: InputDecoration(
                              hintText: 'Part used, e.g. Original OLED (optional)',
                              counterText: '',
                              isDense: true,
                              filled: true,
                              fillColor: RC.canvas,
                              prefixIcon: const Icon(PhosphorIconsRegular.puzzlePiece, size: 18),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: RC.line)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: RC.blue, width: 1.6)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: _num(_ctl(k).parts, 'Part price')),
                            const SizedBox(width: 8),
                            Expanded(child: _num(_ctl(k).labour, 'Work charge')),
                          ]),
                        ]),
                      ),
                  ]),
                ),
            ]),
          ),
          RepairSection(
            title: 'Time & warranty',
            art: A3.cart('clock'),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Days to finish',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                    onPressed: _min > 0 ? () => setState(() => _min--) : null,
                    icon: const Icon(PhosphorIconsBold.minus,
                        size: 17, color: RC.blue)),
                Text('$_min – $_max',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(
                    onPressed: () => setState(() => _max++),
                    icon: const Icon(PhosphorIconsBold.plus,
                        size: 17, color: RC.blue)),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (days, label) in const [
                  (0, 'No warranty'),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _pickup,
                onChanged: (v) => setState(() => _pickup = v),
                activeThumbColor: RC.blue,
                title: const Text('I can pick up & deliver',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ]),
          ),
        ]);
  }

  Widget _num(TextEditingController c, String hint) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(7)
        ],
        style: const TextStyle(fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: '₹ ',
          isDense: true,
          filled: true,
          fillColor: RC.canvas,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: RC.line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: RC.blue, width: 1.6)),
        ),
      );
}
