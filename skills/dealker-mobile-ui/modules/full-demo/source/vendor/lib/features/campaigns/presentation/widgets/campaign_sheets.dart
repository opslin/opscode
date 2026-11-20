import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/campaigns/application/campaign_providers.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

Future<void> _sheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => child,
    );

Future<void> showEditCampaignSheet(
        BuildContext context, WidgetRef ref, CampaignDetail d) =>
    _sheet(context, _EditSheet(detail: d));

Future<void> showAddProductsSheet(
        BuildContext context, WidgetRef ref, CampaignDetail d) =>
    _sheet(context, _AddProductsSheet(detail: d));

Future<void> showAddKeywordsSheet(
        BuildContext context, WidgetRef ref, CampaignDetail d) =>
    _sheet(context, _AddKeywordsSheet(detail: d));

class _Grab extends StatelessWidget {
  const _Grab(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 10),
        Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: heading(size: 20))),
        ),
        const SizedBox(height: 14),
      ]);
}

String _clean(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

// ── edit ──────────────────────────────────────────────────────────────

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.detail});
  final CampaignDetail detail;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late String _name = widget.detail.item.name;
  late String _bid = _clean(widget.detail.item.defaultBid);
  late String _daily = _clean(widget.detail.item.dailyBudget);
  late String _total = widget.detail.item.totalBudget == null
      ? ''
      : _clean(widget.detail.item.totalBudget!);
  late DateTime? _ends = widget.detail.item.endsOn;
  bool _saving = false;

  Future<void> _save(AdRules r) async {
    final c = widget.detail.item;
    final bid = num.tryParse(_bid.trim());
    final daily = num.tryParse(_daily.trim());
    final total = _total.trim().isEmpty ? null : num.tryParse(_total.trim());
    String? err;
    if (_name.trim().length < 3) {
      err = 'Give the campaign a name (at least 3 letters).';
    } else if (bid == null || bid < r.minCpc || bid > r.maxCpc) {
      err =
          'Your bid must be between ₹${_clean(r.minCpc)} and ₹${_clean(r.maxCpc)}.';
    } else if (daily == null || daily < r.minDailyBudget) {
      err = 'Daily budget must be at least ₹${_clean(r.minDailyBudget)}.';
    } else if (_total.trim().isNotEmpty && (total == null || total < daily)) {
      err = 'Total budget cannot be lower than the daily budget.';
    } else if (_ends != null &&
        c.startsOn != null &&
        _ends!.isBefore(c.startsOn!)) {
      err = 'The end date must be on or after the start date.';
    }
    if (err != null) {
      showAppToast(context, err, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(campaignRepositoryProvider).update(c.id, {
        'name': _name.trim(),
        'defaultBid': bid,
        'dailyBudget': daily,
        'totalBudget': total,
        'endsOn': _ends == null ? null : isoDay(_ends!),
      });
      if (!mounted) return;
      refreshCampaigns(ref, id: c.id);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(adRulesProvider).asData?.value ?? const AdRules();
    final c = widget.detail.item;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _Grab('Edit campaign'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Campaign name'),
              AuctionField(
                  initial: _name, maxLength: 120, onChanged: (v) => _name = v),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const FieldLabel('Max cost per click'),
                      AuctionField(
                          initial: _bid,
                          prefix: '₹',
                          number: true,
                          onChanged: (v) => _bid = v),
                    ])),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const FieldLabel('Daily budget'),
                      AuctionField(
                          initial: _daily,
                          prefix: '₹',
                          number: true,
                          onChanged: (v) => _daily = v),
                    ])),
              ]),
              const SizedBox(height: 14),
              const FieldLabel('Total budget', optional: true),
              AuctionField(
                  initial: _total,
                  prefix: '₹',
                  number: true,
                  hint: 'No overall limit',
                  onChanged: (v) => _total = v),
              const SizedBox(height: 14),
              const FieldLabel('End date', optional: true),
              PickerField(
                value: _ends == null ? null : formatDay(_ends),
                hint: 'No end date',
                icon: PhosphorIconsRegular.calendarCheck,
                onTap: () async {
                  final first = c.startsOn ?? DateTime.now();
                  final p = await showDatePicker(
                    context: context,
                    initialDate: (_ends ?? first).isBefore(first)
                        ? first
                        : (_ends ?? first),
                    firstDate: first,
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (p != null) setState(() => _ends = p);
                },
              ),
              if (_ends != null)
                TextButton(
                    onPressed: () => setState(() => _ends = null),
                    child: const Text('Remove end date')),
              const SizedBox(height: 8),
              Text(
                  c.status == CampaignStatus.active
                      ? 'Changes apply to new clicks straight away.'
                      : 'Changes are saved to this campaign.',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              AuctionButton(
                  label: 'Save changes',
                  loading: _saving,
                  onPressed: () => _save(rules)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── add products ──────────────────────────────────────────────────────

class _AddProductsSheet extends ConsumerStatefulWidget {
  const _AddProductsSheet({required this.detail});
  final CampaignDetail detail;

  @override
  ConsumerState<_AddProductsSheet> createState() => _AddProductsSheetState();
}

class _AddProductsSheetState extends ConsumerState<_AddProductsSheet> {
  String _q = '';
  final Set<String> _picked = {};
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(campaignRepositoryProvider)
          .addProducts(widget.detail.item.id, _picked.toList());
      if (!mounted) return;
      refreshCampaigns(ref, id: widget.detail.item.id);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inCampaign = widget.detail.products.map((p) => p.productId).toSet();
    final list = ref.watch(adProductSearchProvider(_q));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(children: [
        const _Grab('Add products'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search your products',
              prefixIcon:
                  const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF3F6FC),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: list.when(skipLoadingOnReload: true, skipError: true, 
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(
                message: errorText(e, 'Could not load your products.'),
                onRetry: () => ref.invalidate(adProductSearchProvider)),
            data: (items) {
              final free =
                  items.where((p) => !inCampaign.contains(p.id)).toList();
              if (free.isEmpty) {
                return const EmptyState(
                    icon: PhosphorIconsRegular.cube,
                    title: 'Nothing to add',
                    message:
                        'All your live products are already in this campaign.');
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                itemCount: free.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = free[i];
                  final on = _picked.contains(p.id);
                  return GestureDetector(
                    onTap: () => setState(
                        () => on ? _picked.remove(p.id) : _picked.add(p.id)),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: on ? kAdBlueSoft : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: on ? kAdBlue : AppColors.cardBorder,
                            width: on ? 1.6 : 1.2),
                      ),
                      child: Row(children: [
                        ProductThumb(p.thumbnail, size: 50, radius: 10),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700))),
                        Icon(
                            on
                                ? PhosphorIconsFill.checkCircle
                                : PhosphorIconsRegular.circle,
                            color: on ? kAdBlue : AppColors.border,
                            size: 24),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        BottomActionBar(
          child: AuctionButton(
              label: _picked.isEmpty
                  ? 'Select products'
                  : 'Add ${_picked.length} ${_picked.length == 1 ? 'product' : 'products'}',
              loading: _saving,
              onPressed: _picked.isEmpty ? null : _save),
        ),
      ]),
    );
  }
}

// ── add keyword ───────────────────────────────────────────────────────

class _AddKeywordsSheet extends ConsumerStatefulWidget {
  const _AddKeywordsSheet({required this.detail});
  final CampaignDetail detail;

  @override
  ConsumerState<_AddKeywordsSheet> createState() => _AddKeywordsSheetState();
}

class _AddKeywordsSheetState extends ConsumerState<_AddKeywordsSheet> {
  String _kw = '';
  String _match = 'BROAD';
  bool _negative = false;
  bool _saving = false;

  Future<void> _save() async {
    final k = _kw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (k.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(campaignRepositoryProvider).addKeywords(
          widget.detail.item.id,
          [KeywordDraft(k, matchType: _match, negative: _negative)]);
      if (!mounted) return;
      refreshCampaigns(ref, id: widget.detail.item.id);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const _Grab('Add keyword'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Search words'),
                    AuctionField(
                        initial: _kw,
                        hint: 'e.g. iphone 15 128gb',
                        maxLength: 80,
                        onChanged: (v) => setState(() => _kw = v)),
                    const SizedBox(height: 14),
                    const FieldLabel('Match type'),
                    Segmented(
                      labels: const ['Broad', 'Phrase', 'Exact'],
                      index: const ['BROAD', 'PHRASE', 'EXACT'].indexOf(_match),
                      onChanged: (i) => setState(
                          () => _match = const ['BROAD', 'PHRASE', 'EXACT'][i]),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.rose,
                      value: _negative,
                      onChanged: (v) => setState(() => _negative = v),
                      title: const Text('Negative keyword',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14.5)),
                      subtitle: const Text('Never show my ads for this search',
                          style: TextStyle(fontSize: 12.5)),
                    ),
                    const SizedBox(height: 10),
                    AuctionButton(
                        label: 'Add keyword',
                        loading: _saving,
                        onPressed: _kw.trim().isEmpty ? null : _save),
                  ]),
            ),
          ]),
        ),
      );
}
