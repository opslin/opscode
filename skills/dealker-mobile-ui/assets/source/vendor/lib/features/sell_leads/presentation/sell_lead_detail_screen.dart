import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/sell_leads/application/sell_lead_providers.dart';
import 'package:dealker_vendor/features/sell_leads/data/sell_lead_models.dart';
import 'package:dealker_vendor/features/sell_leads/presentation/sell_deal_panel.dart';
import 'package:dealker_vendor/features/sell_leads/presentation/sell_leads_screen.dart' show LeadChip, conditionColors, conditionLabel;
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/core/utils/polling.dart';

/// One customer phone: what they ask, what Dealkr suggests, your offer, and the chat with the seller.
class SellLeadDetailScreen extends ConsumerStatefulWidget {
  const SellLeadDetailScreen({required this.id, super.key});
  final String id;

  @override
  ConsumerState<SellLeadDetailScreen> createState() =>
      _SellLeadDetailScreenState();
}

class _SellLeadDetailScreenState extends ConsumerState<SellLeadDetailScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  bool _seeded = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // The seller can accept, pay-side steps can move: keep the page current without a manual refresh.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_busy && screenActive(context)) {
        ref.invalidate(sellLeadProvider(widget.id));
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _offer() async {
    final amount = num.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (amount == null || amount <= 0) {
      showAppToast(context, 'Enter your offer in rupees.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(sellLeadRepositoryProvider)
          .placeOffer(widget.id, amount, _note.text);
      ref
        ..invalidate(sellLeadProvider(widget.id))
        ..invalidate(sellLeadsProvider('pending'));
      if (mounted) showAppToast(context, 'Offer sent to the seller.');
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    setState(() => _busy = true);
    try {
      await ref.read(sellLeadRepositoryProvider).withdrawOffer(widget.id);
      ref
        ..invalidate(sellLeadProvider(widget.id))
        ..invalidate(sellLeadsProvider('pending'));
      _seeded = false;
      if (mounted) showAppToast(context, 'Offer withdrawn.');
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(sellLeadProvider(widget.id));
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AuctionAppBar(title: 'Sell-Phone Request'),
      body: q.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e, 'Could not load this request.'),
            onRetry: () => ref.invalidate(sellLeadProvider(widget.id))),
        data: _body,
      ),
    );
  }

  void _quickPrice(num v) => setState(() => _amount.text = v.round().toString());

  Widget _body(SellLead l) {
    if (!_seeded) {
      _seeded = true;
      if (l.myOffer != null) _amount.text = l.myOffer!.round().toString();
      if (l.note != null) _note.text = l.note!;
    }
    final canOffer = l.status == 'PENDING';
    final accepted = l.deal != null && l.myOfferStatus == 'ACCEPTED';
    final (cFg, cBg) = conditionColors(l.condition);
    return RefreshIndicator(
        onRefresh: () async => ref.refresh(sellLeadProvider(widget.id).future),
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              // ── phone hero ──
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6A5AF5), Color(0xFF3B2FBF)]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Color(0x333B2FBF), blurRadius: 18, offset: Offset(0, 8))],
                ),
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(PhosphorIconsFill.deviceMobile, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.model.isEmpty ? 'Phone' : l.model,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        if (l.variant.isNotEmpty)
                          Text(l.variant,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Request ${l.code}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (l.color.isNotEmpty) LeadChip(l.color, fg: Colors.white, bg: Colors.white24, icon: PhosphorIconsFill.palette),
                    LeadChip('${conditionLabel(l.condition)} condition', fg: cFg, bg: cBg, icon: PhosphorIconsFill.sealCheck),
                    if (l.imageCount > 0)
                      LeadChip('${l.imageCount} photo${l.imageCount == 1 ? '' : 's'}',
                          fg: Colors.white, bg: Colors.white24, icon: PhosphorIconsFill.image),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      Expanded(child: _price('Seller is asking', l.askingPrice, AppColors.navy)),
                      Container(width: 1, height: 40, color: AppColors.cardBorder),
                      const SizedBox(width: 14),
                      Expanded(child: _price('Dealkr suggests', l.systemValue, AppColors.violet)),
                    ]),
                  ),
                ]),
              ),
              if (l.description.isNotEmpty) ...[
                const SizedBox(height: 14),
                _card(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(PhosphorIconsFill.notePencil, size: 18, color: AppColors.violet),
                      const SizedBox(width: 8),
                      Text('Seller says', style: heading(size: 14.5)),
                    ]),
                    const SizedBox(height: 8),
                    Text(l.description,
                        style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.textSecondary)),
                  ]),
                ),
              ],
              if (accepted) ...[
                const SizedBox(height: 14),
                SellDealPanel(lead: l),
              ],
              if (!accepted) ...[
                const SizedBox(height: 14),
                _card(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(PhosphorIconsFill.currencyInr, size: 18, color: AppColors.violet),
                      const SizedBox(width: 8),
                      Text(l.myOffer == null ? 'Make an offer' : 'Your offer', style: heading(size: 15)),
                    ]),
                    const SizedBox(height: 12),
                    if (canOffer) ...[
                      TextField(
                        controller: _amount,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.navy),
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          filled: true,
                          fillColor: AppColors.canvas,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (l.systemValue != null)
                          _pill('Dealkr ${formatInr(l.systemValue!)}', () => _quickPrice(l.systemValue!)),
                        if (l.askingPrice != null) ...[
                          _pill('Asking ${formatInr(l.askingPrice!)}', () => _quickPrice(l.askingPrice!)),
                          _pill('5% less', () => _quickPrice(l.askingPrice! * 0.95)),
                          _pill('10% less', () => _quickPrice(l.askingPrice! * 0.90)),
                        ],
                      ]),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _note,
                        maxLength: 200,
                        decoration: InputDecoration(
                          labelText: 'Note for the seller (optional)',
                          hintText: 'e.g. Can pick up today',
                          filled: true,
                          fillColor: AppColors.canvas,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FilledButton(
                        onPressed: _busy ? null : _offer,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: AppColors.violet,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: Text(l.myOffer == null ? 'Send offer' : 'Update offer',
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                      ),
                      if (l.myOffer != null)
                        Center(
                          child: TextButton(
                              onPressed: _busy ? null : _withdraw, child: const Text('Withdraw my offer')),
                        ),
                    ] else
                      Text(
                          l.myOffer != null
                              ? 'Your offer of ${formatInr(l.myOffer!)} was ${l.myOfferStatus == 'ACCEPTED' ? 'accepted' : 'not selected'}.'
                              : 'This request is no longer open to offers.',
                          style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
                  ]),
                ),
              ],
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push(Routes.sellLeadChat(l.id)),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppColors.violetSoft, borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: AppColors.violet, shape: BoxShape.circle),
                      child: const Icon(PhosphorIconsFill.chatCircleText, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Chat with the seller', style: heading(size: 14.5)),
                        const Text('Ask about battery, warranty, photos',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                    ),
                    const Icon(PhosphorIconsBold.caretRight, size: 18, color: AppColors.violet),
                  ]),
                ),
              ),
              if (!accepted) ...[
                const SizedBox(height: 12),
                const Text(
                    'Phone numbers can be shared only after the seller accepts an offer. If yours is accepted you will pay Dealkr first, then arrange pickup.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ]));
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x123B2FBF), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: child,
      );

  Widget _pill(String text, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: AppColors.violetSoft, borderRadius: BorderRadius.circular(20)),
          child: Text(text,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.violet)),
        ),
      );

  Widget _price(String label, num? v, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(v == null ? '—' : formatInr(v),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      ]);
}
