import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/application/order_razorpay.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';
import 'package:dealker_vendor/features/demand/application/demand_providers.dart';
import 'package:dealker_vendor/features/demand/application/razorpay_pay.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/features/profile/application/profile_providers.dart';
import 'package:dealker_vendor/features/wallet/application/wallet_providers.dart';
import 'package:dealker_vendor/features/wholesale/application/cart_provider.dart';
import 'package:dealker_vendor/features/wholesale/application/device_selection.dart';
import 'package:dealker_vendor/features/wholesale/presentation/device_condition.dart';
import 'package:dealker_vendor/features/wholesale/application/wholesale_providers.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// Checkout for wholesale stock: lines grouped by seller, exact quantities (never below a listing's
/// minimum), one payment. Each line becomes its own order on the server; they are paid together.
class WholesaleCartScreen extends ConsumerStatefulWidget {
  const WholesaleCartScreen({super.key});

  @override
  ConsumerState<WholesaleCartScreen> createState() =>
      _WholesaleCartScreenState();
}

class _WholesaleCartScreenState extends ConsumerState<WholesaleCartScreen> {
  bool _busy = false;
  String _method = 'RAZORPAY'; // RAZORPAY | WALLET
  RazorpayPayment? _rzp;
  OrderRazorpay? _orderRzp; // pays an auction win's order

  @override
  void dispose() {
    _rzp?.dispose();
    _orderRzp?.dispose();
    super.dispose();
  }

  Future<void> _checkout(List<CartLine> lines) async {
    setState(() => _busy = true);
    final repo = ref.read(wholesaleRepositoryProvider);
    final cart = ref.read(wholesaleCartProvider.notifier);
    final reqIds = <String>[];
    String? failure;
    // 1) one order per line; a placed line leaves the cart so it can never be ordered twice
    for (final l in lines) {
      try {
        final o = await repo.buy(l.item.id, l.qty, unitNos: l.unitNos);
        reqIds.add(o.requirementId);
        cart.remove(l.item.id);
      } catch (e) {
        failure = '${l.item.name}: ${errorText(e)}';
        break;
      }
    }
    if (!mounted) return;
    ref.invalidate(wholesaleListProvider);
    if (reqIds.isEmpty) {
      setState(() => _busy = false);
      if (failure != null) showAppToast(context, failure, error: true);
      return;
    }
    if (failure != null) showAppToast(context, failure, error: true);
    await _pay(reqIds, placed: reqIds.length);
  }

  /// 2) pay every placed order with the chosen method
  Future<void> _pay(List<String> reqIds, {required int placed}) async {
    try {
      if (_method == 'RAZORPAY') {
        _rzp ??= RazorpayPayment(ref.read(demandRepositoryProvider));
        final out = await _rzp!.pay(reqIds,
            phone: ref.read(authControllerProvider).session?.phone);
        if (!mounted) return;
        if (out.result == PayResult.paid) {
          await _paid(placed);
        } else {
          await _unpaid(reqIds, placed,
              out.result == PayResult.failed ? out.message : null);
        }
      } else {
        final demand = ref.read(demandRepositoryProvider);
        for (final id in reqIds) {
          await demand.pay(id);
        }
        if (mounted) await _paid(placed);
      }
    } catch (e) {
      if (mounted) await _unpaid(reqIds, placed, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _paid(int placed) async {
    refreshDemand(ref);
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: AppColors.mintSoft, shape: BoxShape.circle),
            child: const Icon(PhosphorIconsFill.checkCircle,
                size: 38, color: AppColors.mint),
          ),
          const SizedBox(height: 16),
          Text('Payment received',
              style: heading(size: 21, w: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              '$placed order${placed == 1 ? '' : 's'} placed. The money is held safely until you confirm delivery.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(height: 1.4, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          AuctionButton(
              label: 'Track my orders', onPressed: () => Navigator.pop(c)),
        ]),
      ),
    );
    if (mounted) context.go(Routes.wholesaleOrders);
  }

  Future<void> _unpaid(List<String> reqIds, int placed, String? why) async {
    refreshDemand(ref);
    final retry = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Payment not completed'),
        content: Text(
            '${why ?? 'You closed the payment.'} Your $placed order${placed == 1 ? ' is' : 's are'} saved — nothing has been charged. You can pay now or later from Wholesale orders.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Pay later')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Try again')),
        ],
      ),
    );
    if (!mounted) return;
    if (retry == true) {
      setState(() => _busy = true);
      await _pay(reqIds, placed: placed);
      return;
    }
    context.go(Routes.wholesaleOrders);
  }

  /// What the wallet must hold for this checkout: wholesale lines plus wins that are paid from the wallet
  /// (a win whose online order already exists is resumed online instead).
  num _walletNeed(List<CartLine> lines, List<LotView> wins) =>
      lines.fold<num>(0, (s, l) => s + l.total) +
      wins
          .where((l) => l.my.orderId == null)
          .fold<num>(0, (s, l) => s + (l.my.amountDue ?? l.finalPrice ?? l.currentPrice));

  /// One checkout for the whole cart, with the method the vendor picked (Razorpay: UPI / cards / netbanking,
  /// or the Dealkr wallet). Auction wins go first (their deadline is the tightest), each as its own payment;
  /// then the wholesale lines. If any step is cancelled or fails, nothing further is charged.
  Future<void> _checkoutAll(List<CartLine> lines, List<LotView> wins) async {
    setState(() => _busy = true);
    final repo = ref.read(auctionRepositoryProvider);
    final phone = ref.read(authControllerProvider).session?.phone;
    var paidWins = 0;
    var handedOver = false; // _checkout() resets the busy flag itself
    try {
      if (_method == 'WALLET') {
        final need = _walletNeed(lines, wins);
        if (need > 0) {
          final w = await ref.read(walletRepositoryProvider).balances();
          final short = need - w.wallet;
          if (short > 0) {
            if (w.earnings < short) {
              if (mounted) {
                showAppToast(context,
                    'Your wallet and earnings are ${formatInr(short - w.earnings)} short of this cart. Pay with UPI / cards instead.',
                    error: true);
              }
              return;
            }
            // top the wallet up with exactly what is missing (one key per tap: a retry can't move money twice)
            await ref.read(walletRepositoryProvider).transfer(
                num.parse(short.toStringAsFixed(2)),
                idempotencyKey: 'cart-${DateTime.now().millisecondsSinceEpoch}');
          }
        }
      }
      for (final l in wins) {
        try {
          final viaWallet = _method == 'WALLET' && l.my.orderId == null;
          if (viaWallet) {
            await repo.checkoutLot(l.id);
          } else {
            final orderId =
                l.my.orderId ?? (await repo.checkoutLotOnline(l.id)).orderId;
            _orderRzp ??= OrderRazorpay(repo);
            final out =
                await _orderRzp!.pay(orderId, description: l.title, phone: phone);
            if (out.result != PayResult.paid) {
              if (mounted) {
                showAppToast(
                    context,
                    out.result == PayResult.cancelled
                        ? 'Payment cancelled — nothing was charged. The lot is still in your cart.'
                        : (out.message ?? 'The payment did not go through.'),
                    error: out.result == PayResult.failed);
              }
              break;
            }
          }
          paidWins++;
        } catch (e) {
          if (mounted) {
            showAppToast(context, '${l.title}: ${errorText(e)}', error: true);
          }
          break;
        }
      }
      ref
        ..invalidate(wonLotsToPayProvider)
        ..invalidate(wonLotIdsProvider)
        ..invalidate(myLotsProvider);
      invalidateWallet(ref);
      if (!mounted) return;
      if (paidWins < wins.length) return;
      if (lines.isNotEmpty) {
        handedOver = true;
        await _checkout(lines);
        return;
      }
      await _paid(paidWins);
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted && !handedOver) setState(() => _busy = false);
    }
  }

  Future<void> _editQty(CartLine l) async {
    final c = TextEditingController(text: '${l.qty}');
    final max = l.item.stock;
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quantity'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
                suffixText: 'units',
                helperText: 'Minimum ${l.item.moq} · ${l.item.stock} in stock'),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final m in {l.item.moq, l.item.moq * 2, l.item.moq * 5})
              if (m <= max)
                ActionChip(label: Text('$m'), onPressed: () => c.text = '$m'),
          ]),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)),
              child: const Text('Update')),
        ],
      ),
    );
    if (v == null || !mounted) return;
    if (v < l.item.moq) {
      showAppToast(context, 'Minimum order is ${l.item.moq} units',
          error: true);
      return;
    }
    if (v > max) {
      showAppToast(context, 'Only $max units are in stock', error: true);
    }
    ref.read(wholesaleCartProvider.notifier).changeQty(l.item.id, v);
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(wholesaleCartProvider);
    final won = ref.watch(cartWinsProvider);
    final vw = ref.watch(vendorWalletProvider).asData?.value;
    final wallet = vw?.wallet;
    final bizName = ref.watch(vendorInfoProvider).asData?.value.name;
    final linesTotal = lines.fold<num>(0, (s, l) => s + l.total);
    final winsTotal = won.fold<num>(
        0, (s, l) => s + (l.my.amountDue ?? l.finalPrice ?? l.currentPrice));
    final total = linesTotal + winsTotal;
    final method = _method;
    final walletNeed = _walletNeed(lines, won);
    final coverable = vw == null || (vw.wallet + vw.earnings) >= walletNeed;
    final units = lines.fold<int>(0, (s, l) => s + l.qty);
    final num short =
        wallet == null ? 0 : (walletNeed - wallet).clamp(0, double.infinity);

    final groups = <String, List<CartLine>>{};
    for (final l in lines) {
      groups.putIfAbsent(l.item.seller.id, () => []).add(l);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy)),
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cart', style: heading(size: 19, w: FontWeight.w800)),
          Text(
              '${lines.length + won.length} item${lines.length + won.length == 1 ? '' : 's'}${won.isEmpty ? '' : ' · ${won.length} auction win${won.length == 1 ? '' : 's'}'}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ]),
        actions: [
          if (lines.isNotEmpty)
            TextButton(
                onPressed: () {
                  final saved = [...lines];
                  final cart = ref.read(wholesaleCartProvider.notifier);
                  cart.clear();
                  showUndoBar(context, 'Cart cleared', () {
                    for (final l in saved) {
                      cart.add(l.item, l.qty, l.unitNos);
                    }
                  });
                },
                child: const Text('Clear')),
        ],
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.cardBorder)),
      ),
      body: (lines.isEmpty && won.isEmpty)
          ? EmptyState(
              icon: PhosphorIconsRegular.shoppingCart,
              title: 'Your cart is empty',
              message:
                  'Add wholesale stock from the B2B Marketplace and pay for it in one go.',
              action: TextButton(
                  onPressed: () => context.go(Routes.wholesale),
                  child: const Text('Browse marketplace')))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                _Card(
                  child: Row(children: [
                    const Icon(PhosphorIconsFill.fileText,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('GST invoice in the name of',
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary)),
                            Text(
                                (bizName == null || bizName.isEmpty)
                                    ? 'your business'
                                    : bizName,
                                style: heading(size: 14.5)),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                for (final g in groups.values) ...[
                  _SellerGroup(g, onEditQty: _editQty),
                  const SizedBox(height: 12),
                ],
                if (won.isNotEmpty) ...[
                  _AuctionWinsGroup(won),
                  const SizedBox(height: 12),
                ],
                _Card(
                  child: Column(children: [
                    if (lines.isNotEmpty)
                      _Row('Wholesale items ($units units)', formatInr(linesTotal)),
                    if (won.isNotEmpty)
                      _Row('Auction wins (${won.length})', formatInr(winsTotal)),
                    const _Row('Delivery', 'Arranged by each seller'),
                    const Divider(height: 22, color: AppColors.cardBorder),
                    _Row('Total', formatInr(total), bold: true),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          'GST is shown on each seller\'s invoice. The final amount is confirmed when your orders are placed.',
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: AppColors.textMuted)),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                _Card(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pay with', style: heading(size: 15)),
                        const SizedBox(height: 10),
                        _Method(
                          icon: PhosphorIconsFill.creditCard,
                          title: 'UPI, cards & netbanking',
                          subtitle: 'Secure checkout by Razorpay',
                          selected: method == 'RAZORPAY',
                          badge: 'Recommended',
                          onTap: () => setState(() => _method = 'RAZORPAY'),
                        ),
                        const SizedBox(height: 8),
                        _Method(
                          icon: PhosphorIconsFill.wallet,
                          title: 'Dealkr wallet',
                          subtitle: wallet == null
                              ? 'Checking balance…'
                              : !coverable
                                  ? 'Balance ${formatInr(wallet)} · earnings ${formatInr(vw.earnings)} · short by ${formatInr(walletNeed - wallet - vw.earnings)}'
                                  : short > 0
                                      ? 'Balance ${formatInr(wallet)} · ${formatInr(short)} moves from your earnings automatically'
                                      : 'Balance ${formatInr(wallet)}',
                          selected: method == 'WALLET',
                          onTap: () => setState(() => _method = 'WALLET'),
                        ),
                      ]),
                ),
                const SizedBox(height: 14),
                const _Trust(),
              ],
            ),
      bottomNavigationBar: (lines.isEmpty && won.isEmpty)
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.cardBorder))),
              child: SafeArea(
                top: false,
                child: Row(children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                        Text(formatInr(total),
                            style: heading(size: 21, w: FontWeight.w800)),
                      ]),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AuctionButton(
                        label: method == 'RAZORPAY'
                            ? 'Pay ${formatInr(total)}'
                            : 'Pay ${formatInr(total)} from wallet',
                        icon: PhosphorIconsBold.lockKey,
                        loading: _busy,
                        onPressed: method == 'WALLET' && !coverable
                            ? null
                            : () => _checkoutAll(lines, won)),
                  ),
                ]),
              ),
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: child,
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: bold ? 15 : 13.5,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                      color: bold ? AppColors.navy : AppColors.textSecondary))),
          Text(value,
              style: TextStyle(
                  fontSize: bold ? 17 : 13.5,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: AppColors.navy)),
        ]),
      );
}

class _Method extends StatelessWidget {
  const _Method(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.selected,
      required this.onTap,
      this.badge,
      this.enabled = true});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF3F7FF) : Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.cardBorder,
                width: selected ? 1.6 : 1),
          ),
          child: Row(children: [
            Icon(icon,
                size: 24,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(title, style: heading(size: 14.5))),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.mintSoft,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(badge!,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.mint)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ]),
            ),
            Icon(
                selected
                    ? PhosphorIconsFill.radioButton
                    : PhosphorIconsRegular.circle,
                size: 22,
                color: selected ? AppColors.primary : AppColors.borderStrong),
          ]),
        ),
        ),
      );
}

class _Trust extends StatelessWidget {
  const _Trust();
  @override
  Widget build(BuildContext context) => const Row(children: [
        _TrustItem(
            PhosphorIconsFill.shieldCheck, 'Held in escrow\nuntil delivery'),
        _TrustItem(PhosphorIconsFill.sealCheck, 'Verified\nsellers'),
        _TrustItem(PhosphorIconsFill.fileText, 'GST invoice\non every order'),
      ]);
}

class _TrustItem extends StatelessWidget {
  const _TrustItem(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11, height: 1.3, color: AppColors.textSecondary)),
        ]),
      );
}

/// Opens "Select Device Condition" for a cart line: the devices the buyer takes; the line's quantity follows the selection.
Future<void> _openDevices(BuildContext context, WidgetRef ref, CartLine l) async {
  final cart = ref.read(wholesaleCartProvider.notifier);
  final sel = DeviceSelection(ref.read(dioProvider), l.item.productId!, l.qty,
      initial: l.unitNos, quantityFollows: true, minQty: l.item.moq, maxQty: l.item.stock, onChanged: (nos) => cart.setSelection(l.item.id, nos));
  await sel.init();
  if (!context.mounted) return;
  // a device choice that is no longer valid (taken by someone else) is replaced by the first available ones
  await showDeviceSheet(context, selection: sel, name: l.item.name);
  sel.dispose();
}

class _SellerGroup extends ConsumerWidget {
  const _SellerGroup(this.lines, {required this.onEditQty});
  final List<CartLine> lines;
  final Future<void> Function(CartLine) onEditQty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seller = lines.first.item.seller;
    final cart = ref.read(wholesaleCartProvider.notifier);
    return _Card(
      child: Column(children: [
        Row(children: [
          const Icon(PhosphorIconsFill.storefront,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  seller.city == null
                      ? seller.name
                      : '${seller.name} · ${seller.city}',
                  style: heading(size: 14))),
          const Icon(PhosphorIconsFill.sealCheck,
              size: 16, color: AppColors.primary),
        ]),
        const Divider(height: 20, color: AppColors.cardBorder),
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _Line(
            lines[i],
            onMinus: () {
              final l = lines[i];
              if (l.qty > l.item.moq) {
                cart.changeQty(l.item.id, l.qty - 1);
              } else {
                cart.remove(l.item.id);
                showUndoBar(context, 'Removed ${l.item.name}',
                    () => cart.add(l.item, l.qty, l.unitNos));
              }
            },
            onPlus: () async {
              final id = lines[i].item.id;
              await cart.changeQty(id, lines[i].qty + 1);
              // device-tracked stock: pressing + opens the device sheet so the buyer can pick which devices
              if (lines[i].item.deviceTracked && context.mounted) {
                final fresh = ref.read(wholesaleCartProvider).where((x) => x.item.id == id).firstOrNull;
                if (fresh != null) await _openDevices(context, ref, fresh);
              }
            },
            onDevices: lines[i].item.deviceTracked ? () => _openDevices(context, ref, lines[i]) : null,
            onEdit: () => onEditQty(lines[i]),
            onRemove: () {
              final l = lines[i];
              cart.remove(l.item.id);
              showUndoBar(context, 'Removed ${l.item.name}',
                  () => cart.add(l.item, l.qty, l.unitNos));
            },
          ),
        ],
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.l,
      {required this.onMinus,
      required this.onPlus,
      required this.onEdit,
      required this.onRemove,
      this.onDevices});
  final VoidCallback? onDevices;
  final CartLine l;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    Widget step(IconData i, VoidCallback? t) => GestureDetector(
          onTap: t,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(i,
                  size: 18,
                  color:
                      t == null ? AppColors.borderStrong : AppColors.primary)),
        );
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
            color: const Color(0xFFF4F6FB),
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(4),
        child: AnyImage(l.item.thumbnail, fit: BoxFit.contain, radius: 8),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(l.item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: heading(size: 13.5))),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 6),
                child: Icon(PhosphorIconsRegular.trash,
                    size: 19, color: AppColors.textMuted),
              ),
            ),
          ]),
          const SizedBox(height: 2),
          Text('${formatInr(l.item.price)} / unit · MOQ ${l.item.moq}',
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.textSecondary)),
          if (onDevices != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: GestureDetector(
                onTap: onDevices,
                behavior: HitTestBehavior.opaque,
                child: Text(
                    l.unitNos == null || l.unitNos!.isEmpty
                        ? 'View Device Condition'
                        : l.unitNos!.length <= 4
                            ? 'Devices ${l.unitNos!.map((n) => '#$n').join(', ')} · View Device Condition'
                            : '${l.unitNos!.length} devices picked · View Device Condition',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, decoration: TextDecoration.underline)),
              ),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.cardBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                step(PhosphorIconsBold.minus, onMinus),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('${l.qty}', style: heading(size: 15)),
                  ),
                ),
                step(PhosphorIconsBold.plus,
                    l.qty < l.item.stock ? onPlus : null),
              ]),
            ),
            const Spacer(),
            Text(formatInr(l.total),
                style: heading(size: 15.5, w: FontWeight.w800)),
          ]),
        ]),
      ),
    ]);
  }
}

/// Auction lots the vendor has won and still has to pay for, shown like any other cart item
/// (same card, photo, name and price) with an "Auction" tag. They can be removed from the cart (undo
/// is offered); the win itself stays payable from the lot page until its deadline.
class _AuctionWinsGroup extends ConsumerWidget {
  const _AuctionWinsGroup(this.wins);
  final List<LotView> wins;

  String _left(LotView l) {
    final d = l.my.paymentDeadline;
    if (d == null) return 'Pay soon';
    final r = d.difference(DateTime.now().add(l.serverOffset));
    if (r.isNegative) return 'Payment window closed';
    if (r.inHours >= 1) return 'Pay within ${r.inHours}h ${r.inMinutes % 60}m';
    return 'Pay within ${r.inMinutes}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Card(
        child: Column(children: [
          Row(children: [
            const Icon(PhosphorIconsFill.gavel,
                color: AppColors.violet, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Auction wins', style: heading(size: 14))),
          ]),
          const Divider(height: 20, color: AppColors.cardBorder),
          for (var i = 0; i < wins.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _WinLine(wins[i], _left(wins[i]), onRemove: () {
              final id = wins[i].id;
              final dismiss = ref.read(dismissedWinsProvider.notifier);
              dismiss.dismiss(id);
              showUndoBar(context, 'Removed ${wins[i].title} from cart',
                  () => dismiss.restore(id));
            }),
          ],
        ]),
      );
}

class _WinLine extends StatelessWidget {
  const _WinLine(this.l, this.left, {required this.onRemove});
  final LotView l;
  final String left;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final due = l.my.amountDue ?? l.finalPrice ?? l.currentPrice;
    final urgent = left.contains('closed') ||
        (l.my.paymentDeadline != null &&
            l.my.paymentDeadline!
                    .difference(DateTime.now().add(l.serverOffset))
                    .inHours <
                6);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
            color: const Color(0xFFF4F6FB),
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(4),
        child: AnyImage(l.imageUrl, fit: BoxFit.contain, radius: 8),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(l.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: heading(size: 13.5))),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 6),
                child: Icon(PhosphorIconsRegular.trash,
                    size: 19, color: AppColors.textMuted),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.violetSoft,
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('AUCTION WIN',
                  style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w800,
                      color: AppColors.violet)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text('${l.quantity} ${l.quantity == 1 ? 'unit' : 'units'} · ${l.sellerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(PhosphorIconsFill.clock,
                size: 14,
                color: urgent ? AppColors.countdownRed : const Color(0xFFD97706)),
            const SizedBox(width: 4),
            Text(left,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: urgent ? AppColors.countdownRed : const Color(0xFFD97706))),
            const Spacer(),
            Text(formatInr(due), style: heading(size: 15.5, w: FontWeight.w800)),
          ]),
        ]),
      ),
    ]);
  }
}
