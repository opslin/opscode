import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/demand/application/demand_providers.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/demand_common.dart';
import 'package:dealker_vendor/features/products/data/device_catalogue.dart';
import 'package:dealker_vendor/features/products/data/product_catalog.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/shared/widgets/premium_ui.dart';

const _storages = ['64GB', '128GB', '256GB', '512GB', '1TB'];
const _batteries = [80, 85, 90, 95];
const _bulk = [10, 20, 50, 100];
const _windows = [
  (6, '6 hours'),
  (24, '24 hours'),
  (48, '2 days'),
  (72, '3 days'),
  (168, '7 days')
];

/// Post a buying requirement: what you need, how many, at what price. Verified sellers are alerted —
/// the ones who hold matching stock get a personal "you can supply this" notification.
class PostDemandScreen extends ConsumerStatefulWidget {
  const PostDemandScreen({super.key});

  @override
  ConsumerState<PostDemandScreen> createState() => _PostDemandScreenState();
}

class _PostDemandScreenState extends ConsumerState<PostDemandScreen> {
  ProductType _type = ProductType.mobile;
  String _brand = '';
  String _model = '';
  String? _storage;
  int _qty = 10;
  String _min = '';
  String _max = '';
  String _condition = 'ANY';
  int? _battery;
  String _display = 'ANY';
  String _fulfil = 'ANY';
  String _city = '';
  String _pin = '';
  DateTime? _needBy;
  int _hours = 48;
  bool _urgent = false;
  String _notes = '';
  bool _busy = false;
  int _modelKey = 0;

  bool get _usesSpecs => _type.hasStorage;

  String get _productName {
    final m = _model.trim();
    if (m.isEmpty) return '';
    final b = _brand.trim();
    final named =
        b.isEmpty || b == 'Apple' || m.toLowerCase().contains(b.toLowerCase())
            ? m
            : '$b $m';
    return _storage == null ? named : '$named $_storage';
  }

  String? _problem() {
    if (_model.trim().length < 2) return 'Tell us which model you need.';
    if (_qty < 1) return 'Quantity must be at least 1.';
    final lo = int.tryParse(_min);
    final hi = int.tryParse(_max);
    if (lo != null && hi != null && hi < lo) {
      return 'The highest price cannot be lower than the lowest.';
    }
    if (_city.trim().isEmpty) {
      return 'Add the city where you want it delivered or picked up.';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _needBy ?? DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (d != null) setState(() => _needBy = d);
  }

  Future<void> _submit() async {
    final p = _problem();
    if (p != null) {
      showAppToast(context, p, error: true, bottom: 90);
      return;
    }
    final lo = int.tryParse(_min);
    final hi = int.tryParse(_max);
    final body = <String, dynamic>{
      'productName': _productName,
      if (_brand.isNotEmpty) 'brand': _brand,
      if (_storage != null) 'storage': _storage,
      'quantity': _qty,
      if (lo != null) 'targetPrice': lo,
      if (hi != null) 'targetPriceMax': hi,
      'conditionPref': _condition,
      if (_battery != null && _usesSpecs) 'minBatteryHealth': _battery,
      'displayPref': _usesSpecs ? _display : 'ANY',
      'fulfilmentPref': _fulfil,
      'deliveryCity': _city.trim(),
      if (_pin.trim().isNotEmpty) 'deliveryPincode': _pin.trim(),
      if (_needBy != null)
        'requiredBy':
            '${_needBy!.year}-${_needBy!.month.toString().padLeft(2, '0')}-${_needBy!.day.toString().padLeft(2, '0')}',
      'responseDeadline':
          DateTime.now().add(Duration(hours: _hours)).toUtc().toIso8601String(),
      'isUrgent': _urgent,
      if (_notes.trim().isNotEmpty) 'description': _notes.trim(),
    };
    setState(() => _busy = true);
    try {
      final r = await ref.read(demandRepositoryProvider).create(body);
      if (!mounted) return;
      refreshDemand(ref);
      showAppToast(
          context, 'Demand posted! Matching sellers have been alerted.');
      context.pushReplacement(Routes.demandView(r.id));
    } catch (e) {
      if (mounted) {
        showAppToast(context, errorText(e, 'Could not post your demand.'),
            error: true, bottom: 90);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> brands = ref
        .watch(deviceBrandsProvider(_type))
        .maybeWhen(data: (List<String> v) => v, orElse: () => brandsFor(_type));
    final List<String> models = _brand.isEmpty
        ? modelsFor(_type, null)
        : ref.watch(deviceModelsProvider((_type, _brand))).maybeWhen(
              data: (List<DeviceModel> v) =>
                  v.map((DeviceModel m) => m.name).toList(),
              orElse: () => modelsFor(_type, _brand),
            );
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: const AuctionAppBar(
          title: 'Post Demand', subtitle: 'Tell sellers what you need'),
      bottomNavigationBar: BottomActionBar(
        child: AuctionButton(
            label: 'Post demand',
            icon: PhosphorIconsBold.megaphoneSimple,
            loading: _busy,
            onPressed: _submit),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const HeroBanner(
            title: 'Post a bulk demand',
            subtitle:
                'Tell verified sellers what you need. Those with matching stock are alerted and send you their best price.',
            art: 'assets/3d/new/cartons.png',
            colors: [Color(0xFF123A8C), Color(0xFF0B2559)],
          ),
          const SizedBox(height: 14),
          Section(
            title: 'What do you need?',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Type'),
              Row(children: [
                for (final (i, t) in ProductType.values.indexed)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 3 ? 0 : 8),
                      child: ArtChoiceTile(
                        art: switch (t.key) {
                          'mobile' => A3.exchange('phone'),
                          'laptop' => A3.exchange('laptop'),
                          'tablet' => A3.exchange('tablet'),
                          _ => A3.exchange('headphones'),
                        },
                        label: t.label,
                        selected: _type == t,
                        artSize: 42,
                        accent: kDemandBlue,
                        onTap: () => setState(() {
                          _type = t;
                          _brand = '';
                          _model = '';
                          _modelKey++;
                          if (!t.hasStorage) _storage = null;
                        }),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              const FieldLabel('Brand'),
              ChoiceChips<String>(
                options: brands,
                value: _brand.isEmpty ? null : _brand,
                label: (b) => b,
                onChanged: (b) => setState(() {
                  _brand = _brand == b ? '' : b;
                  _model = '';
                  _modelKey++;
                }),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Model'),
              AuctionField(
                fieldKey: ValueKey('model-$_modelKey'),
                initial: _model,
                hint: _type == ProductType.mobile
                    ? 'e.g. iPhone 15'
                    : 'e.g. MacBook Air M2',
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                onChanged: (v) => setState(() => _model = v),
              ),
              if (models.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: models.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 7),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => setState(() {
                        _model = models[i];
                        _modelKey++;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: _model == models[i]
                                ? kDemandBlueSoft
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _model == models[i]
                                    ? kDemandBlue
                                    : AppColors.border)),
                        child: Text(models[i],
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _model == models[i]
                                    ? kDemandBlue
                                    : AppColors.textSecondary)),
                      ),
                    ),
                  ),
                ),
              ],
              if (_type.hasStorage) ...[
                const SizedBox(height: 14),
                const FieldLabel('Storage', optional: true),
                ChoiceChips<String>(
                    options: _storages,
                    value: _storage,
                    label: (s) => s,
                    onChanged: (s) =>
                        setState(() => _storage = _storage == s ? null : s)),
              ],
              if (_productName.isNotEmpty) ...[
                const SizedBox(height: 14),
                Notice(
                    icon: PhosphorIconsFill.magnifyingGlass,
                    text: 'Sellers will see this as “$_productName”.'),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: 'How many, at what price?',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Quantity (pieces)'),
              Row(children: [
                QtyStepper(
                    value: _qty,
                    min: 1,
                    max: 100000,
                    onChanged: (v) => setState(() => _qty = v)),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final n in _bulk)
                      GestureDetector(
                        onTap: () => setState(() => _qty = n),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                              color: _qty == n ? kDemandBlueSoft : Colors.white,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                  color: _qty == n
                                      ? kDemandBlue
                                      : AppColors.border)),
                          child: Text('$n',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: _qty == n
                                      ? kDemandBlue
                                      : AppColors.textSecondary)),
                        ),
                      ),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              const FieldLabel('Price you want to pay (per pc)',
                  optional: true),
              Row(children: [
                Expanded(
                    child: AuctionField(
                        initial: _min,
                        prefix: '₹',
                        hint: 'Lowest',
                        number: true,
                        maxLength: 8,
                        onChanged: (v) => _min = v)),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('to',
                        style: TextStyle(color: AppColors.textMuted))),
                Expanded(
                    child: AuctionField(
                        initial: _max,
                        prefix: '₹',
                        hint: 'Highest',
                        number: true,
                        maxLength: 8,
                        onChanged: (v) => _max = v)),
              ]),
              const SizedBox(height: 6),
              const Text(
                  'Sellers see this range. Leave it empty to simply ask for offers.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: 'Quality you expect',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Condition'),
              ChoiceChips<String>(
                options: const ['ANY', 'NEW', 'USED_OR_REFURBISHED'],
                value: _condition,
                label: conditionPrefLabel,
                onChanged: (v) => setState(() => _condition = v),
              ),
              if (_usesSpecs) ...[
                const SizedBox(height: 14),
                const FieldLabel('Minimum battery health', optional: true),
                ChoiceChips<int>(
                    options: _batteries,
                    value: _battery,
                    label: (b) => '$b%+',
                    onChanged: (b) =>
                        setState(() => _battery = _battery == b ? null : b)),
                const SizedBox(height: 14),
                const FieldLabel('Display'),
                ChoiceChips<String>(
                    options: const ['ANY', 'ORIGINAL', 'GRADE_AB'],
                    value: _display,
                    label: displayPrefLabel,
                    onChanged: (v) => setState(() => _display = v)),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: 'Delivery & timing',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Where do you need it?'),
              Row(children: [
                Expanded(
                    flex: 3,
                    child: AuctionField(
                        initial: _city,
                        hint: 'City / area',
                        maxLength: 80,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (v) => _city = v)),
                const SizedBox(width: 10),
                Expanded(
                    flex: 2,
                    child: AuctionField(
                        initial: _pin,
                        hint: 'Pincode',
                        number: true,
                        maxLength: 6,
                        onChanged: (v) => _pin = v)),
              ]),
              const SizedBox(height: 14),
              const FieldLabel('Pickup or delivery'),
              ChoiceChips<String>(
                  options: const ['ANY', 'PICKUP', 'DELIVERY'],
                  value: _fulfil,
                  label: fulfilmentPrefLabel,
                  onChanged: (v) => setState(() => _fulfil = v)),
              const SizedBox(height: 14),
              const FieldLabel('Need it by', optional: true),
              PickerField(
                  value: _needBy == null ? null : formatDay(_needBy),
                  hint: 'Pick a date',
                  icon: PhosphorIconsRegular.calendarBlank,
                  onTap: _pickDate),
              const SizedBox(height: 14),
              const FieldLabel('Collect offers for'),
              ChoiceChips<int>(
                  options: [for (final w in _windows) w.$1],
                  value: _hours,
                  label: (h) => _windows.firstWhere((w) => w.$1 == h).$2,
                  onChanged: (v) => setState(() => _hours = v)),
            ]),
          ),
          const SizedBox(height: 12),
          Section(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.roseSoft,
                      borderRadius: BorderRadius.circular(11)),
                  child: const Icon(PhosphorIconsFill.lightning,
                      color: AppColors.rose, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mark as urgent', style: heading(size: 15)),
                        const Text(
                            'Every seller gets an instant alert, not only those with matching stock.',
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.3,
                                color: AppColors.textSecondary)),
                      ]),
                ),
                Switch(
                    value: _urgent,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.rose,
                    onChanged: (v) => setState(() => _urgent = v)),
              ]),
              const SizedBox(height: 14),
              const FieldLabel('Notes for sellers', optional: true),
              AuctionField(
                  initial: _notes,
                  maxLines: 3,
                  maxLength: 500,
                  hint: 'Box, GST bill, warranty, delivery in lots…',
                  onChanged: (v) => _notes = v),
            ]),
          ),
        ],
      ),
    );
  }
}
