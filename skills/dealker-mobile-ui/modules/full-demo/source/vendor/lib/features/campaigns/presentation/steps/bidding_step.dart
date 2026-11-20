import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/campaigns/application/campaign_providers.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// Step 4 — what the vendor will pay per click, and (for keyword campaigns)
/// which search words to target.
class BiddingStep extends ConsumerStatefulWidget {
  const BiddingStep({super.key, required this.rules});
  final AdRules rules;

  @override
  ConsumerState<BiddingStep> createState() => _BiddingStepState();
}

class _BiddingStepState extends ConsumerState<BiddingStep> {
  int _bidKey = 0; // forces the bid field to show a tapped suggestion
  int _kwKey = 0; // clears the keyword field after Add
  String _kw = '';
  String _match = 'BROAD';
  bool _negative = false;
  String? _estimateFor;

  void _setBid(num v) {
    ref.read(campaignDraftProvider.notifier).bid(_clean(v));
    setState(() => _bidKey++);
  }

  void _add() {
    final k = _kw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (k.isEmpty) return;
    if (k.split(' ').length > 10) {
      showAppToast(context, 'A keyword can have at most 10 words.',
          error: true);
      return;
    }
    ref
        .read(campaignDraftProvider.notifier)
        .addKeyword(KeywordDraft(k, matchType: _match, negative: _negative));
    setState(() {
      _kw = '';
      _kwKey++;
      _estimateFor = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(campaignDraftProvider);
    final n = ref.read(campaignDraftProvider.notifier);
    final r = widget.rules;
    final bid = d.bidN;
    final daily = d.dailyN;
    final maxClicks = (bid != null && bid > 0 && daily != null)
        ? (daily / bid).floor()
        : null;
    final suggestions = <num>{
      r.minCpc,
      _round(r.minCpc * 2),
      _round(r.minCpc * 4),
      _round(r.minCpc * 8),
    }.where((v) => v <= r.maxCpc).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Text('Set your bid', style: heading(size: 20)),
        const SizedBox(height: 4),
        const Text(
            'The most you are willing to pay when a shopper taps your ad.',
            style: TextStyle(
                fontSize: 13.5, height: 1.4, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        const FieldLabel('Maximum cost per click'),
        AuctionField(
          fieldKey: ValueKey('bid$_bidKey'),
          initial: d.bid,
          prefix: '₹',
          number: true,
          hint: '${_clean(r.minCpc)} – ${_clean(r.maxCpc)}',
          onChanged: n.bid,
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in suggestions)
            GestureDetector(
              onTap: () => _setBid(v),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: bid == v ? kAdBlue : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: bid == v ? kAdBlue : AppColors.border),
                ),
                child: Text('₹${_clean(v)}',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color:
                            bid == v ? Colors.white : AppColors.textSecondary)),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        AdNotice(
          message:
              'You pay the lowest price that keeps your position — usually less than your bid — plus ${_clean(r.gstPct)}% GST.'
              '${maxClicks == null ? '' : ' With ${formatInr(daily!)} a day you can get up to about $maxClicks clicks.'}',
          icon: PhosphorIconsFill.lightbulb,
        ),
        if (d.isManual) ...[
          const SizedBox(height: 22),
          Text('Keywords', style: heading(size: 18)),
          const SizedBox(height: 4),
          const Text(
              'Words a shopper might type into search. Add words to avoid as negative keywords.',
              style: TextStyle(
                  fontSize: 13.5, height: 1.4, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: AuctionField(
                fieldKey: ValueKey('kw$_kwKey'),
                initial: _kw,
                hint: 'e.g. iphone 15 128gb',
                maxLength: 80,
                onChanged: (v) => setState(() {
                  _kw = v;
                  _estimateFor = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 86,
              child: AuctionButton(
                  label: 'Add',
                  height: 50,
                  onPressed: _kw.trim().isEmpty ? null : _add),
            ),
          ]),
          const SizedBox(height: 12),
          if (d.keywords.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('No keywords yet',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            )
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in d.keywords)
                _KeywordChip(k, onRemove: () => n.removeKeyword(k)),
            ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in const [
              ('BROAD', 'Broad'),
              ('PHRASE', 'Phrase'),
              ('EXACT', 'Exact'),
            ])
              _Pill(
                  label: m.$2,
                  selected: _match == m.$1,
                  onTap: () => setState(() => _match = m.$1)),
            _Pill(
                label: 'Negative',
                selected: _negative,
                danger: true,
                onTap: () => setState(() => _negative = !_negative)),
          ]),
          const SizedBox(height: 8),
          Text(
              switch (_match) {
                'EXACT' => 'Exact: only when the search is exactly this.',
                'PHRASE' =>
                  'Phrase: when the search contains these words in order.',
                _ =>
                  'Broad: when the search contains these words in any order.',
              },
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          if (_kw.trim().length >= 2 && !_negative) ...[
            const SizedBox(height: 8),
            if (_estimateFor == _kw.trim())
              _EstimateCard(
                  keyword: _kw.trim().toLowerCase(),
                  onUse: (v) => _setBid(v.clamp(r.minCpc, r.maxCpc)))
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _estimateFor = _kw.trim()),
                  icon: const Icon(PhosphorIconsRegular.chartLineUp, size: 18),
                  label: const Text('Check typical cost'),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

num _round(num v) => (v * 100).round() / 100;
String _clean(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.danger = false});
  final String label;
  final bool selected;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = danger ? AppColors.rose : kAdBlue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip(this.k, {required this.onRemove});
  final KeywordDraft k;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = k.negative ? AppColors.rose : kAdBlue;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: k.negative ? AppColors.roseSoft : kAdBlueSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: Text('${k.negative ? '− ' : ''}${k.keyword}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: c)),
        ),
        const SizedBox(width: 6),
        Text(k.matchType.toLowerCase(),
            style: TextStyle(fontSize: 11, color: c.withValues(alpha: 0.7))),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: onRemove,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(PhosphorIconsBold.x, size: 13, color: c),
          ),
        ),
      ]),
    );
  }
}

class _EstimateCard extends ConsumerWidget {
  const _EstimateCard({required this.keyword, required this.onUse});
  final String keyword;
  final ValueChanged<num> onUse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final est = ref.watch(bidEstimateProvider(keyword));
    return est.when(skipLoadingOnReload: true, skipError: true, 
      loading: () => const Padding(
          padding: EdgeInsets.all(12),
          child: Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4)))),
      error: (e, _) => Text(errorText(e, 'Could not check this keyword.'),
          style: const TextStyle(color: AppColors.rose, fontSize: 13)),
      data: (e) {
        final (label, color, bg) = switch (e.competition) {
          'HIGH' => ('High competition', AppColors.rose, AppColors.roseSoft),
          'MEDIUM' => (
              'Medium competition',
              const Color(0xFFB45309),
              AppColors.amberSoft
            ),
          _ => ('Low competition', AppColors.mint, AppColors.mintSoft),
        };
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AdChip(label, color: color, bg: bg),
              const Spacer(),
              Text('${e.competing} competing',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Text(
                    'Suggested bid ${inr2(e.suggested)}'
                    '${e.avgCpc == null ? '' : '  ·  last 30 days avg ${inr2(e.avgCpc!)}'}',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                  onPressed: () => onUse(e.suggested),
                  child: const Text('Use this')),
            ]),
          ]),
        );
      },
    );
  }
}
