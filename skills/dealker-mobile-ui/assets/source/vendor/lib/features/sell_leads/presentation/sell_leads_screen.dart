import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/sell_leads/application/sell_lead_providers.dart';
import 'package:dealker_vendor/features/sell_leads/data/sell_lead_models.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/premium_ui.dart';

const _tabs = <(String, String)>[
  ('Open to offer', 'pending'),
  ('Accepted', 'progress')
];

/// Phones customers want to sell. Vendors offer, then chat with the seller.
class SellLeadsScreen extends ConsumerStatefulWidget {
  const SellLeadsScreen({super.key});

  @override
  ConsumerState<SellLeadsScreen> createState() => _SellLeadsScreenState();
}

class _SellLeadsScreenState extends ConsumerState<SellLeadsScreen> {
  String _tab = 'pending';

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(sellLeadsProvider(_tab));
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AuctionAppBar(
          title: 'Sell-Phone Requests', subtitle: 'Buy phones from customers'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sellLeadsProvider(_tab));
          await ref
              .read(sellLeadsProvider(_tab).future)
              .catchError((_) => const SellLeadPage(items: [], total: 0));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            HeroBanner(
              title: 'Buy phones from customers',
              subtitle: 'Browse phones people want to sell, make your best offer and chat with the seller.',
              art: A3.sell('hero'),
              colors: const [Color(0xFF6A5AF5), Color(0xFF3B2FBF)],
              bottom: Row(children: [
                HeroStat(page.value == null ? '—' : '${page.value!.total}',
                    _tab == 'pending' ? 'Open requests' : 'Accepted deals'),
                const HeroStat('Pay first', 'Funds held safely'),
              ]),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: AppColors.violetSoft,
                  borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                for (final (label, value) in _tabs)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _tab == value ? AppColors.violet : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: _tab == value ? Colors.white : AppColors.violet)),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            page.when(skipLoadingOnReload: true, skipError: true, 
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SizedBox(
                  height: 320,
                  child: ErrorState(
                      message: errorText(e, 'Could not load requests.'),
                      onRetry: () => ref.invalidate(sellLeadsProvider(_tab)))),
              data: (p) => p.items.isEmpty
                  ? ArtEmpty(
                      art: _tab == 'pending' ? A3.sell('looking') : A3.sell('deal'),
                      title: _tab == 'pending'
                          ? 'No requests right now'
                          : 'No accepted offers yet',
                      message: _tab == 'pending'
                          ? 'When a customer lists a phone, it appears here so you can make an offer.'
                          : 'Phones whose seller accepted your offer show up here.',
                    )
                  : Column(children: [for (final x in p.items) _LeadCard(x)]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colour + label for a phone's condition so buyers can scan quality at a glance.
(Color, Color) conditionColors(String c) {
  switch (c.toUpperCase()) {
    case 'EXCELLENT':
    case 'LIKE_NEW':
    case 'NEW':
      return (const Color(0xFF15803D), const Color(0xFFDDF5E4));
    case 'GOOD':
      return (const Color(0xFF1558E8), const Color(0xFFEAF1FF));
    case 'FAIR':
      return (const Color(0xFF9A5B00), const Color(0xFFFFF0C2));
    default:
      return (const Color(0xFFB42318), const Color(0xFFFDECEE));
  }
}

String conditionLabel(String c) {
  final t = c.replaceAll('_', ' ').toLowerCase();
  return t.isEmpty ? '' : '${t[0].toUpperCase()}${t.substring(1)}';
}

class LeadChip extends StatelessWidget {
  const LeadChip(this.text, {super.key, this.fg = AppColors.textSecondary, this.bg = AppColors.canvas, this.icon});
  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
        ]),
      );
}

class _LeadCard extends StatelessWidget {
  const _LeadCard(this.lead);
  final SellLead lead;

  @override
  Widget build(BuildContext context) {
    final (cFg, cBg) = conditionColors(lead.condition);
    final accepted = lead.myOfferStatus == 'ACCEPTED';
    final offered = lead.myOffer != null;
    final ask = lead.askingPrice;
    final val = lead.systemValue;
    final diff = (ask != null && val != null) ? val - ask : null;
    final (stLabel, stFg, stBg) = accepted
        ? ('Accepted', const Color(0xFF15803D), const Color(0xFFDDF5E4))
        : offered
            ? ('Offer sent', AppColors.violet, AppColors.violetSoft)
            : ('New', const Color(0xFF9A5B00), const Color(0xFFFFF0C2));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(Routes.sellLeadView(lead.id)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x143B2FBF), blurRadius: 14, offset: Offset(0, 5))],
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 56,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7C6CFF), AppColors.violet]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(PhosphorIconsFill.deviceMobile, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(lead.model.isEmpty ? 'Phone' : lead.model,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: heading(size: 16)),
                      ),
                      LeadChip(stLabel, fg: stFg, bg: stBg),
                    ]),
                    if (lead.variant.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(lead.variant,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (lead.color.isNotEmpty) LeadChip(lead.color, icon: PhosphorIconsFill.circle),
                      LeadChip(conditionLabel(lead.condition), fg: cFg, bg: cBg, icon: PhosphorIconsFill.sealCheck),
                      if (lead.imageCount > 0)
                        LeadChip('${lead.imageCount} photo${lead.imageCount == 1 ? '' : 's'}',
                            icon: PhosphorIconsFill.image),
                    ]),
                  ]),
                ),
              ]),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Expanded(child: _Price('Seller asks', ask, AppColors.navy)),
                Container(width: 1, height: 34, color: AppColors.cardBorder),
                const SizedBox(width: 12),
                Expanded(child: _Price('Dealkr value', val, AppColors.textSecondary)),
                if (diff != null && diff.abs() >= 1)
                  LeadChip(
                    diff > 0 ? '${formatInr(diff)} below' : '${formatInr(-diff)} above',
                    fg: diff > 0 ? const Color(0xFF15803D) : const Color(0xFF9A5B00),
                    bg: diff > 0 ? const Color(0xFFDDF5E4) : const Color(0xFFFFF0C2),
                    icon: diff > 0 ? PhosphorIconsBold.trendDown : PhosphorIconsBold.trendUp,
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(children: [
                Icon(PhosphorIconsRegular.clock, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text('${timeAgo(lead.createdAt)} · ${lead.code}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const Spacer(),
                if (offered)
                  Text('Your offer ${formatInr(lead.myOffer!)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.violet))
                else
                  const Row(children: [
                    Text('Make offer',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.violet)),
                    SizedBox(width: 4),
                    Icon(PhosphorIconsBold.arrowRight, size: 14, color: AppColors.violet),
                  ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price(this.label, this.value, this.color);
  final String label;
  final num? value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          Text(value == null ? '—' : formatInr(value!),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}
