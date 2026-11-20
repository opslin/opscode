import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show formatDateTime;
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart';
import 'package:dealker_vendor/features/wallet/application/wallet_providers.dart';
import 'package:dealker_vendor/features/wallet/data/wallet_models.dart';
import 'package:dealker_vendor/features/wallet/presentation/add_money_sheet.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// Dealkr wallet: the money auction registration fees and winning bids are
/// charged to. Vendors fund it from their sales earnings.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    invalidateWallet(ref);
    await ref
        .read(vendorWalletProvider.future)
        .catchError((_) => const VendorWallet());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(vendorWalletProvider);
    final txns = ref.watch(walletTxnsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AuctionAppBar(
          title: 'Dealkr Wallet', subtitle: 'Used for auction fees and bids'),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: wallet.when(skipLoadingOnReload: true, skipError: true, 
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            SizedBox(
                height: 420,
                child: ErrorState(
                    message: errorText(e, 'Could not load your wallet.'),
                    onRetry: () => ref.invalidate(vendorWalletProvider))),
          ]),
          data: (w) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              _Hero(w: w, onAdd: () => showAddMoneySheet(context)),
              const SizedBox(height: 14),
              AuctionButton(
                  label: 'Move earnings to wallet',
                  icon: PhosphorIconsBold.arrowDown,
                  onPressed: w.earnings < 1
                      ? null
                      : () => showMoveToWalletSheet(context, w)),
              const SizedBox(height: 14),
              const AdNotice(
                title: 'How it works',
                message:
                    'Auction registration fees and winning-bid payments are charged to this wallet. Tap + to add money with UPI, card or netbanking, or move it here from your sales earnings — both are instant.',
                icon: PhosphorIconsFill.info,
              ),
              const SizedBox(height: 18),
              Text('Transactions', style: heading(size: 17)),
              const SizedBox(height: 10),
              txns.when(skipLoadingOnReload: true, skipError: true, 
                loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2.4))),
                error: (e, _) => AdNotice(
                    message: errorText(e, 'Could not load transactions.'),
                    icon: PhosphorIconsFill.warningCircle,
                    color: AppColors.rose,
                    bg: AppColors.roseSoft,
                    action: TextButton(
                        onPressed: () => ref.invalidate(walletTxnsProvider),
                        child: const Text('Retry'))),
                data: (items) => items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                            child: Text('No transactions yet.',
                                style: TextStyle(color: AppColors.textMuted))))
                    : HomeCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        child: Column(children: [
                          for (final (i, t) in items.indexed) ...[
                            if (i > 0) const Divider(height: 1),
                            _TxnRow(t),
                          ],
                        ]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the transfer sheet. Also used by the auction screens when a vendor
/// is short of wallet money.
Future<void> showMoveToWalletSheet(BuildContext context, VendorWallet w) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => MoveToWalletSheet(wallet: w),
    );

class _Hero extends StatelessWidget {
  const _Hero({required this.w, required this.onAdd});
  final VendorWallet w;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: kAdGradient,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Wallet balance',
                    style: TextStyle(color: Colors.white70, fontSize: 13.5)),
                const SizedBox(height: 4),
                Text(inr2(w.wallet),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
            // the one way to add money: tap +, pick an amount, pay with Razorpay
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onAdd,
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(PhosphorIconsBold.plus, size: 26, color: AppColors.primary),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(PhosphorIconsFill.coins,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Sales earnings ${inr2(w.earnings)}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600))),
            ]),
          ),
        ]),
      );
}

class _TxnRow extends StatelessWidget {
  const _TxnRow(this.t);
  final WalletTxn t;

  @override
  Widget build(BuildContext context) {
    final color = t.credit ? AppColors.success : AppColors.rose;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(
              t.credit
                  ? PhosphorIconsBold.arrowDown
                  : PhosphorIconsBold.arrowUp,
              size: 16,
              color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          const SizedBox(height: 2),
          Text(t.createdAt == null ? '' : formatDateTime(t.createdAt),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${t.credit ? '+' : '−'}${inr2(t.amount)}',
              style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          Text('Bal ${inr2(t.balanceAfter)}',
              style:
                  const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }
}

class MoveToWalletSheet extends ConsumerStatefulWidget {
  const MoveToWalletSheet({super.key, required this.wallet});
  final VendorWallet wallet;

  @override
  ConsumerState<MoveToWalletSheet> createState() => _MoveToWalletSheetState();
}

class _MoveToWalletSheetState extends ConsumerState<MoveToWalletSheet> {
  String _amount = '';
  int _fieldKey = 0;
  bool _busy = false;
  // One key per sheet so a double-tap or a retry can never move money twice.
  final String _idem = 'app-${DateTime.now().microsecondsSinceEpoch}';

  num? get _n => num.tryParse(_amount.trim());

  List<num> get _presets => <num>[500, 1000, 2500, 5000, 10000]
      .where((v) => v <= widget.wallet.earnings)
      .toList();

  String? _error() {
    final v = _n;
    if (v == null || v <= 0) return 'Enter an amount.';
    if (v < 1) return 'The minimum is ₹1.';
    if (v > 500000) return 'The maximum per transfer is ₹5,00,000.';
    if (v > widget.wallet.earnings) {
      return 'You only have ${formatInr(widget.wallet.earnings)} in earnings.';
    }
    return null;
  }

  Future<void> _go() async {
    final err = _error();
    if (err != null) {
      showAppToast(context, err, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(walletRepositoryProvider)
          .transfer(_n!, idempotencyKey: _idem);
      if (!mounted) return;
      invalidateWallet(ref);
      final moved = _n!;
      final ctx = Navigator.of(context).context;
      Navigator.of(context).pop();
      showAppToast(ctx, '${formatInr(moved)} added to your Dealkr wallet.');
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wallet;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 14),
                Text('Move earnings to wallet', style: heading(size: 20)),
                const SizedBox(height: 16),
                const FieldLabel('Amount'),
                AuctionField(
                  fieldKey: ValueKey('amt$_fieldKey'),
                  initial: _amount,
                  prefix: '₹',
                  number: true,
                  hint: '0',
                  onChanged: (v) => setState(() => _amount = v),
                ),
                if (_presets.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final v in _presets)
                      GestureDetector(
                        onTap: () => setState(() {
                          _amount = '$v';
                          _fieldKey++;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _n == v ? kAdBlue : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _n == v ? kAdBlue : AppColors.border),
                          ),
                          child: Text(formatInr(v),
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: _n == v
                                      ? Colors.white
                                      : AppColors.textSecondary)),
                        ),
                      ),
                  ]),
                ],
                const SizedBox(height: 12),
                Text(
                    'Taken from your sales earnings (${formatInr(w.earnings)} available). It is added to your wallet instantly and can be used for auction fees and bids.',
                    style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.textMuted)),
                const SizedBox(height: 16),
                AuctionButton(
                    label: _n == null
                        ? 'Move to wallet'
                        : 'Move ${formatInr(_n!)}',
                    loading: _busy,
                    onPressed: _go),
              ]),
        ),
      ),
    );
  }
}
