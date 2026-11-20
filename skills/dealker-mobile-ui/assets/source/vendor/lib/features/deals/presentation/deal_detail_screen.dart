import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/deals/application/deal_providers.dart';
import 'package:dealker_vendor/features/deals/presentation/deals_screen.dart';

/// One deal: its terms, the vendor's entered products with review status, and a picker to add more.
class DealDetailScreen extends ConsumerWidget {
  const DealDetailScreen({super.key, required this.id});
  final String id;

  void _toast(BuildContext c, String m) =>
      showAppToast(c, m);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(openDealProvider(id));
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AuctionAppBar(title: async.value?.deal.name ?? 'Deal'),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e, 'Could not load this deal.'),
            onRetry: () => ref.invalidate(openDealProvider(id))),
        data: (d) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (d.deal.discountPercent != null)
                  Text('${d.deal.discountPercent!.toStringAsFixed(d.deal.discountPercent! % 1 == 0 ? 0 : 1)}% off your price',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.rose)),
                const SizedBox(height: 6),
                Text('${formatDateTime(d.deal.startsAt)}  →  ${formatDateTime(d.deal.endsAt)}',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(tierLabel(d.deal.minTier), style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 10),
                Text(
                    d.deal.requiresApproval
                        ? 'Dealkr reviews each product you enter. Approved products get the discount when the deal starts, and your price returns when it ends.'
                        : 'Products you enter join the deal automatically. Your price drops when it starts and returns when it ends.',
                    style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
                if (d.deal.maxEntries != null)
                  Text('\nYou can enter up to ${d.deal.maxEntries} products.',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Your products (${d.entries.length})',
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            if (d.entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('You have not entered any product yet.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
              ),
            for (final e in d.entries)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('Your price ${formatInr(e.price)}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                      if (e.status == 'REJECTED' && (e.rejectReason ?? '').isNotEmpty)
                        Text(e.rejectReason!, style: const TextStyle(fontSize: 12.5, color: AppColors.rose)),
                    ]),
                  ),
                  _StatusPill(e.status),
                  if ((e.status == 'PENDING' || e.status == 'APPROVED') && d.deal.status != 'ACTIVE')
                    IconButton(
                      tooltip: 'Withdraw',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () async {
                        try {
                          await ref.read(dealRepositoryProvider).withdraw(id, e.id);
                          ref.invalidate(openDealProvider(id));
                          ref.invalidate(openDealsProvider);
                          ref.invalidate(dealListingsProvider(id));
                        } catch (err) {
                          if (context.mounted) _toast(context, errorText(err, 'Could not withdraw.'));
                        }
                      },
                    ),
                ]),
              ),
          ],
        ),
      ),
      bottomNavigationBar: async.value == null || !async.value!.deal.canJoin
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.violet,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () => _pick(context, ref),
                  child: const Text('Add my products', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                ),
              ),
            ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final chosen = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PickSheet(dealId: id),
    );
    if (chosen == null || chosen.isEmpty || !context.mounted) return;
    try {
      final status = await ref.read(dealRepositoryProvider).apply(id, chosen);
      ref.invalidate(openDealProvider(id));
      ref.invalidate(openDealsProvider);
      ref.invalidate(dealListingsProvider(id));
      if (context.mounted) {
        _toast(context, status == 'PENDING' ? '${chosen.length} sent for approval' : '${chosen.length} added to the deal');
      }
    } catch (err) {
      if (context.mounted) _toast(context, errorText(err, 'Could not add products.'));
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'APPROVED' => ('Approved', AppColors.mintSoft, AppColors.mint),
      'REJECTED' => ('Rejected', AppColors.roseSoft, AppColors.rose),
      _ => ('In review', AppColors.amberSoft, const Color(0xFF8A5A00)),
    };
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

class _PickSheet extends ConsumerStatefulWidget {
  const _PickSheet({required this.dealId});
  final String dealId;

  @override
  ConsumerState<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends ConsumerState<_PickSheet> {
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(dealListingsProvider(widget.dealId));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(children: [
          const SizedBox(height: 12),
          const Text('Pick products for this deal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('Only live, approved products that are in stock can join.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ),
          Expanded(
            child: listings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                  message: errorText(e, 'Could not load your products.'),
                  onRetry: () => ref.invalidate(dealListingsProvider(widget.dealId))),
              data: (rows) => rows.isEmpty
                  ? const Center(child: Text('You have no live products to enter.', style: TextStyle(color: AppColors.textMuted)))
                  : ListView(children: [
                      for (final l in rows)
                        CheckboxListTile(
                          value: l.inDeal || _picked.contains(l.id),
                          onChanged: l.inDeal
                              ? null
                              : (v) => setState(() => v == true ? _picked.add(l.id) : _picked.remove(l.id)),
                          activeColor: AppColors.violet,
                          title: Text(l.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${formatInr(l.price)} · ${l.stock} in stock${l.inDeal ? ' · already entered' : ''}'),
                        ),
                    ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: _picked.isEmpty ? null : () => Navigator.pop(context, _picked.toList()),
              child: Text(_picked.isEmpty ? 'Select products' : 'Add ${_picked.length} to deal',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}
