import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';
import 'package:dealker_vendor/features/demand/application/demand_providers.dart';
import 'package:dealker_vendor/features/demand/application/razorpay_pay.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/demand_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// Pay for the sellers picked on a requirement. The amount leaves the Dealkr wallet now and is held
/// in escrow; each seller is paid only after the buyer confirms receipt of their order.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.requirementId});
  final String requirementId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _busy = false;
  bool _expanded = true;
  String _method = 'RAZORPAY'; // RAZORPAY | WALLET
  RazorpayPayment? _rzp;

  @override
  void dispose() {
    _rzp?.dispose();
    super.dispose();
  }

  void _done(List<DemandOrder> orders) {
    refreshDemand(ref);
    showAppToast(
        context, 'Payment secured in escrow. The seller can now dispatch.');
    if (orders.length == 1) {
      context.pushReplacement(Routes.demandOrder(orders.first.id));
    } else {
      context.go(Routes.wholesaleOrders);
    }
  }

  Future<void> _pay(List<DemandOrder> orders) async {
    setState(() => _busy = true);
    try {
      if (_method == 'RAZORPAY') {
        _rzp ??= RazorpayPayment(ref.read(demandRepositoryProvider));
        final out = await _rzp!.pay([widget.requirementId],
            phone: ref.read(authControllerProvider).session?.phone);
        if (!mounted) return;
        switch (out.result) {
          case PayResult.paid:
            _done(orders);
          case PayResult.cancelled:
            break; // closed Checkout: nothing to say, nothing was charged
          case PayResult.failed:
            showAppToast(
                context, out.message ?? 'The payment did not go through.',
                error: true, bottom: 100);
        }
      } else {
        await ref.read(demandRepositoryProvider).pay(widget.requirementId);
        if (!mounted) return;
        _done(orders);
      }
    } catch (e) {
      ref.invalidate(demandWalletProvider);
      if (mounted) {
        showAppToast(
            context, errorText(e, 'Payment failed. You have not been charged.'),
            error: true, bottom: 100);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(requirementDetailProvider(widget.requirementId));
    final wallet = ref.watch(demandWalletProvider);
    final err = detail.error ?? wallet.error;
    if (err != null) {
      return Scaffold(
        appBar: const AuctionAppBar(title: 'Payment'),
        body: ErrorState(
          message: errorText(err, 'Could not load your payment details.'),
          onRetry: () {
            ref
              ..invalidate(requirementDetailProvider(widget.requirementId))
              ..invalidate(demandWalletProvider);
          },
        ),
      );
    }
    if (!detail.hasValue || !wallet.hasValue) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FE),
        appBar: const AuctionAppBar(title: 'Payment'),
        body: ListView(padding: const EdgeInsets.all(16), children: const [
          CardSkeleton(height: 190),
          CardSkeleton(height: 150)
        ]),
      );
    }

    final d = detail.requireValue;
    final w = wallet.requireValue;
    final r = d.requirement;
    final orders = d.unpaidOrders;
    final total = orders.fold<double>(0, (s, o) => s + o.subtotal);
    final units = orders.fold<int>(0, (s, o) => s + o.quantity);
    final short = total - w.balance;
    final enough = short <= 0;

    if (orders.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FE),
        appBar: AuctionAppBar(title: 'Payment', subtitle: r.number),
        body: EmptyState(
          icon: PhosphorIconsRegular.checkCircle,
          title: 'Nothing to pay',
          message:
              'All orders for this requirement are already paid or cancelled.',
          action: SizedBox(
              width: 200,
              child: AuctionButton(
                  label: 'View orders',
                  height: 46,
                  onPressed: () => context.go(Routes.demandTab('orders')))),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AuctionAppBar(title: 'Payment', subtitle: r.number),
      bottomNavigationBar: BottomActionBar(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AuctionButton(
            label: 'Pay ${formatInr(total)}',
            icon: PhosphorIconsBold.lockKey,
            loading: _busy,
            onPressed: _method == 'RAZORPAY' || (enough && !w.onHold)
                ? () => _pay(orders)
                : null,
          ),
          const SizedBox(height: 8),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(PhosphorIconsFill.shieldCheck,
                size: 14, color: AppColors.mint),
            SizedBox(width: 5),
            Text('Secure payment · held in escrow until you receive it',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ]),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Section(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ProductThumb(r.thumbnail, size: 52, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(requirementTitle(r), style: heading(size: 16)),
                        Text(
                            '${pcs(units)} from ${orders.length} seller${orders.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary)),
                      ]),
                ),
              ]),
              const Divider(height: 24, color: AppColors.cardBorder),
              Row(children: [
                const Expanded(
                    child: Text('Total amount',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textSecondary))),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Hide details' : 'View details',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: kDemandBlue)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(formatInr(total),
                  style: heading(size: 30, w: FontWeight.w800)),
              if (_expanded) ...[
                const SizedBox(height: 10),
                for (final o in orders)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Initials(o.sellerName, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.sellerName, style: heading(size: 14)),
                              Text(
                                  '${pcs(o.quantity)} × ${formatInr(o.unitPrice)}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ]),
                      ),
                      Text(formatInr(o.subtotal),
                          style: heading(size: 14.5, w: FontWeight.w800)),
                    ]),
                  ),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: 'Payment method',
            child: Column(children: [
              GestureDetector(
                onTap: () => setState(() => _method = 'RAZORPAY'),
                child: _Method(
                  icon: PhosphorIconsFill.creditCard,
                  title: 'UPI, cards & netbanking',
                  subtitle: 'Pay securely with Razorpay',
                  selected: _method == 'RAZORPAY',
                  trailing: const Text('Recommended',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.mint)),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap:
                    w.onHold ? null : () => setState(() => _method = 'WALLET'),
                child: _Method(
                  icon: PhosphorIconsFill.wallet,
                  title: 'Dealkr wallet',
                  subtitle: w.onHold
                      ? 'Your wallet is on hold — contact support'
                      : 'Balance ${formatInr(w.balance)}',
                  selected: _method == 'WALLET',
                  disabled: w.onHold,
                  trailing: enough
                      ? null
                      : Text('Short ${formatInr(short)}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.rose)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (_method == 'WALLET' && !enough && !w.onHold)
            Notice(
              icon: PhosphorIconsFill.warningCircle,
              title: 'Not enough wallet balance',
              text:
                  'You need ${formatInr(short)} more in your wallet. Pay with UPI, card or netbanking instead, or wait for your sales to add to the wallet.',
              color: AppColors.rose,
              bg: AppColors.roseSoft,
            )
          else
            const Notice(
              icon: PhosphorIconsFill.shieldCheck,
              title: 'Your money is protected',
              text:
                  'Dealkr holds the payment in escrow. The seller is paid only after you confirm that you received the order. If something is wrong, report it and we step in.',
              color: AppColors.mint,
              bg: AppColors.mintSoft,
            ),
        ],
      ),
    );
  }
}

class _Method extends StatelessWidget {
  const _Method(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.selected,
      this.disabled = false,
      this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool disabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF3F8FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? kDemandBlue : AppColors.border,
                width: selected ? 1.6 : 1.2),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: selected ? kDemandBlueSoft : kGreySoft,
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(icon,
                  color: selected ? kDemandBlue : AppColors.textSecondary,
                  size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: heading(size: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ]),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
            Icon(
                selected
                    ? PhosphorIconsFill.radioButton
                    : PhosphorIconsRegular.circle,
                color: selected ? kDemandBlue : AppColors.borderStrong,
                size: 24),
          ]),
        ),
      );
}
