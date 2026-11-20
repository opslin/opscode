import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_draft.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/data/device_catalogue.dart';
import 'package:dealker_vendor/features/products/data/product_catalog.dart';
import 'package:dealker_vendor/features/products/data/product_models.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/media_widgets.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

enum _Result { waiting, creating, done, failed }

class _Variant {
  _Variant(this.id);
  final int id;
  String storage = '';
  String qty = '1';
  String price = '';
  String mrp = '';
  String wholesale = '';
  String moq = '1';
  _Result result = _Result.waiting;
  String? error;
}

/// Bulk add — one model, several variants (storage / price / stock), shared
/// photos. Creates one listing per variant, each reviewed like a normal product.
class BulkAddScreen extends ConsumerStatefulWidget {
  const BulkAddScreen(
      {super.key, @visibleForTesting this.initialImages = const []});

  /// Photos can't be picked in tests, so they can be pre-seeded there.
  final List<String> initialImages;

  @override
  ConsumerState<BulkAddScreen> createState() => _State();
}

class _State extends ConsumerState<BulkAddScreen> {
  ProductType type = ProductType.mobile;
  String brand = '';
  String model = '';
  final ProductCondition condition = ProductCondition.newItem;
  String notes = '';
  bool b2b = false;
  bool b2c = true;
  final List<String> images = [];
  int uploading = 0;
  final List<_Variant> rows = [];
  int _seq = 0;
  bool running = false;
  bool started = false;

  @override
  void initState() {
    super.initState();
    images.addAll(widget.initialImages);
    rows.add(_Variant(_seq++));
  }

  ProductDraft _draftFor(_Variant v) => ProductDraft(
        type: type,
        brand: brand,
        model: model,
        storage: v.storage,
        condition: condition,
        conditionNotes: notes,
        quantity: v.qty,
        sellB2b: b2b,
        sellB2c: b2c,
        images: images,
        price: v.price,
        mrp: v.mrp,
        wholesale: v.wholesale,
        moq: v.moq,
      );

  String? _validate() {
    if (!b2b && !b2c) return 'Choose B2B, B2C or both.';
    if (brand.isEmpty) return 'Select a brand.';
    if (model.trim().isEmpty) return 'Enter or select the model.';
    if (condition.isUsed && notes.trim().length < 10) {
      return 'Describe the condition — at least 10 characters.';
    }
    if (uploading > 0) return 'Wait for photos to finish uploading.';
    if (images.length < 3) return 'Add at least 3 photos (${images.length}/3).';
    final seen = <String>{};
    for (final (i, v) in rows.indexed) {
      final d = _draftFor(v);
      final label = 'Variant ${i + 1}';
      if (type.hasStorage && v.storage.isEmpty) {
        return '$label: select the storage.';
      }
      if (!seen.add(v.storage)) {
        return '$label repeats a storage you already added.';
      }
      final e = d.detailsError() ??
          (b2b ? d.b2bError() : null) ??
          (b2c ? d.b2cError() : null);
      if (e != null) return '$label: $e';
    }
    return null;
  }

  Future<void> _run() async {
    final err = _validate();
    if (err != null) {
      showAppToast(context, err, error: true, bottom: 96);
      return;
    }
    final readiness =
        await ref.read(readinessProvider.future).catchError((_) => null);
    if (readiness != null && readiness.blocks) {
      if (mounted) {
        await showFailureDialog(context,
            (title: 'Can’t list products', message: readiness.message));
      }
      return;
    }
    setState(() {
      running = true;
      started = true;
    });
    final repo = ref.read(productRepositoryProvider);
    final cats = await ref
        .read(categoriesProvider.future)
        .catchError((_) => <CategoryOption>[]);
    final cat = categoryFor(type, cats);
    for (final v in rows) {
      if (v.result == _Result.done) continue;
      if (cat == null) {
        v.result = _Result.failed;
        v.error = 'No product category is available yet.';
        continue;
      }
      setState(() => v.result = _Result.creating);
      try {
        await repo.create(
            _draftFor(v).toRequest(categoryId: cat.id, selfChecked: false));
        v.result = _Result.done;
        v.error = null;
      } catch (e) {
        v.result = _Result.failed;
        v.error = explainFailure(e).message;
        // Plan limit / KYC will fail every remaining row the same way.
        if (e is Failure && (e is ServerFailure || e is AuthFailure)) {
          final low = e.message.toLowerCase();
          if (low.contains('plan allows') ||
              low.contains('kyc') ||
              low.contains('store is not active')) {
            for (final r in rows.where((r) => r.result == _Result.waiting)) {
              r.result = _Result.failed;
              r.error = v.error;
            }
            if (mounted) setState(() {});
            break;
          }
        }
      }
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    refreshProducts(ref);
    setState(() => running = false);
  }

  String _name(_Variant v) => _draftFor(v).title;

  @override
  Widget build(BuildContext context) {
    final readiness = ref.watch(readinessProvider).asData?.value;
    final done = rows.where((r) => r.result == _Result.done).length;
    final failed = rows.where((r) => r.result == _Result.failed).length;
    final finished = started && !running;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AuctionAppBar(
        title: 'Bulk Add Products',
        subtitle: 'One model, many variants',
        onBack: () => running ? null : context.pop(),
      ),
      body: Column(children: [
        Expanded(
          child: started ? _resultsView(done, failed) : _form(readiness),
        ),
        BottomActionBar(
          child: finished
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  if (failed > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AuctionButton(
                          label: 'Retry $failed failed',
                          outlined: true,
                          onPressed: _run),
                    ),
                  AuctionButton(
                      label: 'Go to My Products',
                      onPressed: () => context.go(Routes.products)),
                ])
              : AuctionButton(
                  label: rows.length == 1
                      ? 'Create Product'
                      : 'Create ${rows.length} Products',
                  icon: PhosphorIconsBold.stack,
                  loading: running,
                  onPressed: readiness?.blocks == true ? null : _run),
        ),
      ]),
    );
  }

  // ── results ────────────────────────────────────────────────────────────

  Widget _resultsView(int done, int failed) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (!running)
            NoteBanner(
                failed == 0
                    ? '$done ${done == 1 ? 'product was' : 'products were'} sent for approval. They’ll go live once Dealkr verifies them.'
                    : '$done created, $failed need attention. Fix the problem and retry — products already created are not repeated.',
                title: failed == 0 ? 'All done' : 'Finished with errors',
                icon: failed == 0
                    ? PhosphorIconsFill.checkCircle
                    : PhosphorIconsFill.warning,
                fg: failed == 0 ? AppColors.mint : const Color(0xFFB45309),
                bg: failed == 0 ? AppColors.mintSoft : AppColors.amberSoft),
          if (!running) const SizedBox(height: 14),
          for (final v in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SectionCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: switch (v.result) {
                          _Result.creating => const Padding(
                              padding: EdgeInsets.all(3),
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.4)),
                          _Result.done => const Icon(
                              PhosphorIconsFill.checkCircle,
                              color: AppColors.mint,
                              size: 26),
                          _Result.failed => const Icon(
                              PhosphorIconsFill.xCircle,
                              color: AppColors.rose,
                              size: 26),
                          _Result.waiting => const Icon(
                              PhosphorIconsRegular.circle,
                              color: AppColors.borderStrong,
                              size: 26),
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_name(v),
                                  style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy)),
                              const SizedBox(height: 2),
                              Text(
                                  switch (v.result) {
                                    _Result.waiting => 'Waiting…',
                                    _Result.creating => 'Creating…',
                                    _Result.done => 'Sent for approval',
                                    _Result.failed => v.error ?? 'Failed',
                                  },
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      color: v.result == _Result.failed
                                          ? AppColors.rose
                                          : AppColors.textSecondary)),
                            ]),
                      ),
                    ]),
              ),
            ),
        ],
      );

  // ── form ───────────────────────────────────────────────────────────────

  Widget _form(Readiness? readiness) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          if (readiness != null) ...[
            ReadinessBanner(readiness),
            const SizedBox(height: 14)
          ],
          const NoteBanner(
              'Add one model in several variants at once. Photos are shared, and each variant becomes its own product that Dealkr reviews.',
              icon: PhosphorIconsFill.stack),
          const SizedBox(height: 18),
          Text('Sell to', style: heading(size: 17)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _Toggle(
                    'B2B · Wholesale',
                    b2b,
                    () => setState(() {
                          final c =
                              nextChannels(b2b: b2b, b2c: b2c, tapB2b: !b2b);
                          b2b = c.b2b;
                          b2c = c.b2c;
                        }))),
            const SizedBox(width: 10),
            Expanded(
                child: _Toggle(
                    'B2C · Retail',
                    b2c,
                    () => setState(() {
                          final c =
                              nextChannels(b2b: b2b, b2c: b2c, tapB2c: !b2c);
                          b2b = c.b2b;
                          b2c = c.b2c;
                        }))),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                b2b && !b2c
                    ? 'B2B only — customers will not see these. Tap B2C to also sell to customers (optional).'
                    : b2b && b2c
                        ? 'Selling to vendors and customers. Tap B2C to switch customers off.'
                        : 'Choose B2B to sell wholesale — retail to customers stays optional.',
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textMuted)),
          ),
          const SizedBox(height: 22),
          Text('Product', style: heading(size: 17)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in ref.watch(productTypesProvider))
              _Toggle(
                  t.label,
                  type == t,
                  () => setState(() {
                        type = t;
                        brand = '';
                        model = '';
                        for (final r in rows) {
                          r.storage = '';
                        }
                      }),
                  width: null),
          ]),
          const SizedBox(height: 14),
          const FieldLabel('Brand'),
          PickerField(
            value: brand.isEmpty ? null : brand,
            hint: 'Select brand',
            onTap: () async {
              final v = await pickOption(context,
                  title: 'Select brand',
                  options: await ref.read(deviceBrandsProvider(type).future),
                  selected: brand,
                  allowCustom: true,
                  searchable: true);
              if (v != null) {
                setState(() {
                  brand = v;
                  model = '';
                });
              }
            },
          ),
          const SizedBox(height: 14),
          const FieldLabel('Model'),
          PickerField(
            value: model.isEmpty ? null : model,
            hint: brand.isEmpty ? 'Select a brand first' : 'Select model',
            onTap: () async {
              if (brand.isEmpty) {
                showAppToast(context, 'Select a brand first.', error: true);
                return;
              }
              final catalogue =
                  await ref.read(deviceModelsProvider((type, brand)).future);
              if (!context.mounted) return;
              final v = await pickOption(context,
                  title: 'Select model',
                  options: catalogue.map((m) => m.name).toList(),
                  selected: model,
                  allowCustom: true,
                  searchable: true);
              if (v != null) setState(() => model = v);
            },
          ),
          const SizedBox(height: 14),
          const FieldLabel('Condition'),
          const NoteBanner(
              'Bulk add is for brand-new stock. Open box, refurbished and used devices need a QC report for every unit — add them one by one with Add Product.',
              icon: PhosphorIconsFill.info),
          if (condition.isUsed) ...[
            const SizedBox(height: 14),
            const FieldLabel('Describe the condition'),
            AuctionField(
              initial: notes,
              maxLines: 3,
              maxLength: 500,
              hint: 'Scratches, dents, usage…',
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) => notes = v,
            ),
          ],
          const SizedBox(height: 22),
          Row(children: [
            Expanded(
                child: Text('Photos (${images.length}/$kMaxPhotos)',
                    style: heading(size: 17))),
          ]),
          const SizedBox(height: 4),
          const Text(
              'Shared by every variant · at least 3 · first is the cover.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          if (images.isEmpty && uploading == 0)
            AddFirstPhoto(onTap: _addPhotos)
          else
            PhotoGrid(
              images: images,
              uploading: uploading,
              onAdd: _addPhotos,
              onRemove: (u) => setState(() => images.remove(u)),
            ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: Text('Variants (${rows.length})',
                    style: heading(size: 17))),
          ]),
          const SizedBox(height: 12),
          for (final (i, v) in rows.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _variantCard(i, v),
            ),
          AuctionButton(
              label: 'Add Variant',
              outlined: true,
              height: 48,
              icon: PhosphorIconsBold.plus,
              onPressed: rows.length >= 20
                  ? null
                  : () => setState(() {
                        final n = _Variant(_seq++);
                        if (rows.isNotEmpty) {
                          n.price = '';
                          n.moq = rows.last.moq;
                        }
                        rows.add(n);
                      })),
        ],
      );

  void _addPhotos() => addPhotos(context, ref,
      room: kMaxPhotos - images.length - uploading,
      onUploaded: (u) => setState(() {
            if (!images.contains(u)) images.add(u);
          }),
      onBusy: (d) => setState(() => uploading = (uploading + d).clamp(0, 99)));

  Widget _variantCard(int i, _Variant v) {
    const single = false;
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration:
                const BoxDecoration(color: kBlueSoft, shape: BoxShape.circle),
            child: Text('${i + 1}',
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800, color: kBlue)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                brand.isEmpty && model.isEmpty ? 'Variant ${i + 1}' : _name(v),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
          ),
          if (rows.length > 1)
            IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => rows.remove(v)),
                icon: const Icon(PhosphorIconsRegular.trash,
                    size: 20, color: AppColors.rose)),
        ]),
        const SizedBox(height: 12),
        if (type.hasStorage) ...[
          const FieldLabel('Storage'),
          PickerField(
            value: v.storage.isEmpty ? null : v.storage,
            hint: 'Select storage',
            onTap: () async {
              final catalogue = brand.isEmpty
                  ? const <DeviceModel>[]
                  : await ref.read(deviceModelsProvider((type, brand)).future);
              if (!context.mounted) return;
              final s = await pickOption(context,
                  title: 'Select storage',
                  options: storagesFor(catalogue, model),
                  selected: v.storage,
                  allowCustom: true);
              if (s != null) setState(() => v.storage = s);
            },
          ),
          const SizedBox(height: 12),
        ],
        FieldLabel(single ? 'Units' : 'Units available'),
        if (single)
          const Text('1 — used phones sold to customers are single units.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
        else
          AuctionField(
              fieldKey: ValueKey('qty-${v.id}'),
              initial: v.qty,
              number: true,
              maxLength: 6,
              hint: '0',
              onChanged: (x) => v.qty = x),
        if (b2c) ...[
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: _money('Selling price', v.price, (x) => v.price = x,
                    'price-${v.id}')),
            const SizedBox(width: 10),
            Expanded(
                child: _money('MRP', v.mrp, (x) => v.mrp = x, 'mrp-${v.id}',
                    optional: true)),
          ]),
        ],
        if (b2b) ...[
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: _money('Wholesale price', v.wholesale,
                    (x) => v.wholesale = x, 'wh-${v.id}')),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('MOQ'),
                    AuctionField(
                        fieldKey: ValueKey('moq-${v.id}'),
                        initial: v.moq,
                        number: true,
                        maxLength: 5,
                        hint: '1',
                        onChanged: (x) => v.moq = x),
                  ]),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _money(String label, String value, ValueChanged<String> on, String key,
          {bool optional = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FieldLabel(label, optional: optional),
        AuctionField(
            fieldKey: ValueKey(key),
            initial: value,
            number: true,
            maxLength: 9,
            prefix: '₹',
            hint: '0',
            onChanged: on),
      ]);
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.label, this.selected, this.onTap,
      {this.width = double.infinity});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width,
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? kBlueSoft : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? kBlue : AppColors.border,
                width: selected ? 1.8 : 1.2),
          ),
          child: Center(
            widthFactor: width == null ? 1 : null,
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? kBlue : AppColors.textSecondary)),
          ),
        ),
      );
}
