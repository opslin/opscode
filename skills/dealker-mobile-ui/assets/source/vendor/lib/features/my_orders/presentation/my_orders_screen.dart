import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show formatInr, heading, timeAgo;
import 'package:dealker_vendor/features/my_orders/application/my_orders_providers.dart';
import 'package:dealker_vendor/features/my_orders/data/my_orders_models.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart'
    show AnyImage;
import 'package:dealker_vendor/routing/route_names.dart';

/// "My orders": everything the vendor BOUGHT or sent for repair, in one place — wholesale stock,
/// auction lots won and repair requests. Each line opens the screen that already handles it
/// (order timeline, the lot / cart, the repair). Orders the vendor SELLS stay under "Orders".
class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  MyOrderKind? _filter; // null = all

  Future<void> _refresh() async {
    ref.invalidate(myOrdersProvider);
    await ref.read(myOrdersProvider.future).catchError((_) => const MyOrdersData(entries: []));
  }

  void _open(MyOrderEntry e) {
    switch (e.kind) {
      case MyOrderKind.wholesale:
        context.push(Routes.demandOrder(e.id)).then((_) => _refresh());
      case MyOrderKind.auction:
        if (e.needsPayment) {
          ref.read(dismissedWinsProvider.notifier).restore(e.id);
          context.push(Routes.wholesaleCart).then((_) => _refresh());
        } else {
          context.push(Routes.lotDetail(e.id));
        }
      case MyOrderKind.repair:
        context.push('/repair/${e.id}').then((_) => _refresh());
    }
  }

  void _repairSheet(MyOrderEntry e) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/3d/repair/toolbox.png', height: 84),
            const SizedBox(height: 8),
            Text(e.title, style: heading(size: 18, w: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Request ${e.code}',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            _StatusChip(e.status, e.tone),
            if (e.amount != null && e.amount! > 0) ...[
              const SizedBox(height: 12),
              Text('Approved estimate ${formatInr(e.amount!)}',
                  style: heading(size: 15)),
            ],
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(myOrdersProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(Routes.home),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy)),
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('My orders', style: heading(size: 19, w: FontWeight.w800)),
          const Text('What you bought or sent for repair',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.cardBorder)),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: data.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            Center(
              child: TextButton(
                  onPressed: () => ref.invalidate(myOrdersProvider),
                  child: const Text('Could not load your orders. Tap to retry.')),
            ),
          ]),
          data: (d) {
            final shown = d.entries
                .where((e) => _filter == null || e.kind == _filter)
                .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
              children: [
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final (k, label) in <(MyOrderKind?, String)>[
                        (null, 'All'),
                        (MyOrderKind.wholesale, 'Wholesale'),
                        (MyOrderKind.auction, 'Auctions'),
                        (MyOrderKind.repair, 'Repairs'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: '$label ${d.count(k)}',
                            selected: _filter == k,
                            onTap: () => setState(() => _filter = k),
                          ),
                        ),
                    ],
                  ),
                ),
                if (d.failed.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.amberSoft,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                        '${d.failed.join(', ')} could not be loaded. Pull down to retry.',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF92580A))),
                  ),
                ],
                const SizedBox(height: 12),
                if (shown.isEmpty)
                  _Empty(filter: _filter)
                else
                  for (final e in shown) ...[
                    _OrderCard(e, onTap: () => _open(e)),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.cardBorder),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary)),
        ),
      );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.e, {required this.onTap});
  final MyOrderEntry e;
  final VoidCallback onTap;

  (String, String, Color, Color) get _kind => switch (e.kind) {
        MyOrderKind.wholesale => (
            'WHOLESALE',
            'assets/3d/new/cartons.png',
            AppColors.roleB2b,
            AppColors.roleB2bBg
          ),
        MyOrderKind.auction => (
            'AUCTION',
            'assets/3d/auction/trophy.png',
            AppColors.violet,
            AppColors.violetSoft
          ),
        MyOrderKind.repair => (
            'REPAIR',
            'assets/3d/repair/toolbox.png',
            AppColors.roleRepair,
            AppColors.roleRepairBg
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (kindLabel, asset, kindFg, kindBg) = _kind;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: e.needsPayment ? const Color(0xFFF6B726) : AppColors.cardBorder,
              width: e.needsPayment ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: const Color(0xFFF4F6FB),
                borderRadius: BorderRadius.circular(14)),
            child: e.imageUrl != null && e.imageUrl!.isNotEmpty
                ? AnyImage(e.imageUrl, fit: BoxFit.contain, radius: 8)
                : Image.asset(asset, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: kindBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(kindLabel,
                      style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w800,
                          color: kindFg)),
                ),
                const SizedBox(width: 8),
                if (e.date != null)
                  Text(timeAgo(e.date!),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
              ]),
              const SizedBox(height: 5),
              Text(e.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: heading(size: 14, w: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(e.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary)),
              const SizedBox(height: 7),
              Row(children: [
                _StatusChip(e.status, e.tone),
                const Spacer(),
                if (e.amount != null && e.amount! > 0)
                  Text(formatInr(e.amount!),
                      style: heading(size: 14.5, w: FontWeight.w800)),
              ]),
            ]),
          ),
          const SizedBox(width: 4),
          const Icon(PhosphorIconsBold.caretRight,
              size: 16, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.text, this.tone);
  final String text;
  final MoTone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      MoTone.green => (AppColors.mint, AppColors.mintSoft),
      MoTone.amber => (const Color(0xFFB45309), AppColors.amberSoft),
      MoTone.blue => (AppColors.primary, const Color(0xFFE5EEFF)),
      MoTone.red => (AppColors.rose, AppColors.roseSoft),
      MoTone.grey => (AppColors.textSecondary, const Color(0xFFEFF1F6)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filter});
  final MyOrderKind? filter;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
        child: SizedBox(
          width: double.infinity,
          child: Column(children: [
            Image.asset('assets/icons/my_orders.png', height: 130),
            const SizedBox(height: 10),
            Text('No orders here yet', style: heading(size: 18, w: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
                'Buy stock from the marketplace, win an auction or send a device for repair — it all shows up here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    height: 1.4, fontSize: 13.5, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go(Routes.wholesale),
              icon: const Icon(PhosphorIconsFill.storefront, size: 18),
              label: const Text('Browse marketplace'),
            ),
          ]),
        ),
      );
}
