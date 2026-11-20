import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/campaigns/application/campaign_providers.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// The ad wallet: what ads spend from. Funded from the vendor's settlement
/// balance (earnings), and unused money can be moved back.
class AdWalletScreen extends ConsumerWidget {
  const AdWalletScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(adWalletProvider)
      ..invalidate(walletStatementProvider)
      ..invalidate(adsOverviewProvider);
    await ref.read(adWalletProvider.future).catchError((_) => const AdWallet());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(adWalletProvider);
    final statement = ref.watch(walletStatementProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AuctionAppBar(
          title: 'Ad Wallet', subtitle: 'Money your ads spend from'),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: wallet.when(skipLoadingOnReload: true, skipError: true, 
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            SizedBox(
                height: 420,
                child: ErrorState(
                    message: errorText(e, 'Could not load your ad wallet.'),
                    onRetry: () => ref.invalidate(adWalletProvider))),
          ]),
          data: (w) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              _Hero(w: w),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: AuctionButton(
                        label: 'Add money',
                        icon: PhosphorIconsBold.plus,
                        onPressed: () => _openTopUp(context, ref, w))),
                const SizedBox(width: 10),
                Expanded(
                    child: AuctionButton(
                        label: 'Withdraw',
                        outlined: true,
                        icon: PhosphorIconsBold.arrowUUpLeft,
                        onPressed: w.withdrawable <= 0
                            ? null
                            : () => _openWithdraw(context, ref, w))),
              ]),
              const SizedBox(height: 14),
              AdNotice(
                title: 'How the ad wallet works',
                message:
                    'Add money from your sales earnings (settlement balance). Each click on your ad is charged here, plus ${_clean(w.gstPct)}% GST. Unused money you added can be moved back any time.',
                icon: PhosphorIconsFill.info,
              ),
              const SizedBox(height: 18),
              Text('Transactions', style: heading(size: 17)),
              const SizedBox(height: 10),
              statement.when(skipLoadingOnReload: true, skipError: true, 
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
                        onPressed: () =>
                            ref.invalidate(walletStatementProvider),
                        child: const Text('Retry'))),
                data: (s) => s.items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                            child: Text('No transactions yet.',
                                style: TextStyle(color: AppColors.textMuted))))
                    : HomeCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        child: Column(children: [
                          for (final (i, e) in s.items.indexed) ...[
                            if (i > 0) const Divider(height: 1),
                            _EntryRow(e),
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

  Future<void> _openTopUp(BuildContext context, WidgetRef ref, AdWallet w) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _MoneySheet(wallet: w, withdraw: false),
      );

  Future<void> _openWithdraw(BuildContext context, WidgetRef ref, AdWallet w) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _MoneySheet(wallet: w, withdraw: true),
      );
}

String _clean(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

class _Hero extends StatelessWidget {
  const _Hero({required this.w});
  final AdWallet w;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: kAdGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: kAdBlue.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(PhosphorIconsFill.wallet, color: Colors.white70, size: 18),
            SizedBox(width: 8),
            Text('Available balance',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Text(formatInr(w.balance),
              style:
                  heading(size: 36, color: Colors.white, w: FontWeight.w800)),
          if (w.lowBalance) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(PhosphorIconsFill.warning,
                    size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                      w.activeCampaigns > 0
                          ? 'Low — your live campaigns need ${formatInr(w.dailyCommitment)} a day.'
                          : 'Balance is low.',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            _Pair('Total added', formatInr(w.lifetimeTopup)),
            _Pair('Total spent', formatInr(w.lifetimeSpend)),
            _Pair('Earnings available', formatInr(w.settlementBalance)),
          ]),
        ]),
      );
}

class _Pair extends StatelessWidget {
  const _Pair(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800))),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );
}

const _typeLabels = {
  'TOPUP_SETTLEMENT': 'Added from earnings',
  'TOPUP_ADMIN': 'Added by Dealkr',
  'PROMO_CREDIT': 'Promotional credit',
  'CLICK_CHARGE': 'Ad clicks',
  'CLICK_REFUND': 'Invalid click refund',
  'WITHDRAW_SETTLEMENT': 'Moved back to earnings',
  'ADJUSTMENT': 'Adjustment',
};

class _EntryRow extends StatelessWidget {
  const _EntryRow(this.e);
  final WalletEntry e;

  @override
  Widget build(BuildContext context) {
    final label = _typeLabels[e.type] ?? e.type;
    final sub = e.type == 'CLICK_CHARGE'
        ? [
            if (e.campaignName != null) e.campaignName!,
            if (e.tax > 0) 'incl. ${inr2(e.tax)} GST'
          ].join('  ·  ')
        : (e.reason ?? '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: e.credit ? AppColors.mintSoft : const Color(0xFFEFF1F6),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(
              e.credit
                  ? PhosphorIconsBold.arrowDown
                  : PhosphorIconsBold.arrowUp,
              size: 17,
              color: e.credit ? AppColors.mint : AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            if (sub.isNotEmpty)
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            Text(timeAgo(e.at),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textMuted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${e.credit ? '+' : '−'}${inr2(e.amount.abs())}',
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: e.credit ? AppColors.mint : AppColors.navy)),
          Text('Bal ${formatInr(e.balanceAfter)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }
}

/// Add money / withdraw. The same sheet, two directions.
class _MoneySheet extends ConsumerStatefulWidget {
  const _MoneySheet({required this.wallet, required this.withdraw});
  final AdWallet wallet;
  final bool withdraw;

  @override
  ConsumerState<_MoneySheet> createState() => _MoneySheetState();
}

class _MoneySheetState extends ConsumerState<_MoneySheet> {
  String _amount = '';
  int _fieldKey = 0;
  bool _busy = false;
  // One key per sheet so a double-tap or retry cannot move money twice.
  final String _idem = 'app-${DateTime.now().microsecondsSinceEpoch}';

  num? get _n => num.tryParse(_amount.trim());

  List<num> get _presets {
    final w = widget.wallet;
    final base =
        widget.withdraw ? <num>[] : <num>[500, 1000, 2500, 5000, 10000];
    return base.where((v) => v >= w.minTopup && v <= w.maxTopup).toList();
  }

  String? _error() {
    final w = widget.wallet;
    final v = _n;
    if (v == null || v <= 0) return 'Enter an amount.';
    if (widget.withdraw) {
      if (v > w.withdrawable) {
        return 'You can move back up to ${formatInr(w.withdrawable)}.';
      }
      return null;
    }
    if (v < w.minTopup) return 'The minimum is ${formatInr(w.minTopup)}.';
    if (v > w.maxTopup) return 'The maximum is ${formatInr(w.maxTopup)}.';
    if (v > w.settlementBalance) {
      return 'You only have ${formatInr(w.settlementBalance)} in earnings to add.';
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
    final repo = ref.read(campaignRepositoryProvider);
    try {
      if (widget.withdraw) {
        await repo.withdraw(_n!);
      } else {
        await repo.topUp(_n!, idempotencyKey: _idem);
      }
      if (!mounted) return;
      ref
        ..invalidate(adWalletProvider)
        ..invalidate(walletStatementProvider)
        ..invalidate(adsOverviewProvider);
      final nav = Navigator.of(context);
      final ctx = nav.context;
      nav.pop();
      showAppToast(ctx, widget.withdraw ? '${formatInr(_n!)} moved back to your earnings.' : '${formatInr(_n!)} added to your ad wallet.');
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wallet;
    final gstNote = widget.withdraw
        ? 'You can move back up to ${formatInr(w.withdrawable)} — money you added from earnings and have not spent.'
        : 'Taken from your earnings (${formatInr(w.settlementBalance)} available). Min ${formatInr(w.minTopup)}, max ${formatInr(w.maxTopup)}.';
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
                Text(
                    widget.withdraw
                        ? 'Move money back'
                        : 'Add money to ad wallet',
                    style: heading(size: 20)),
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
                          _amount = _clean(v);
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
                Text(gstNote,
                    style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.textMuted)),
                const SizedBox(height: 16),
                AuctionButton(
                    label: widget.withdraw
                        ? (_n == null
                            ? 'Move back'
                            : 'Move ${formatInr(_n!)} back')
                        : (_n == null ? 'Add money' : 'Add ${formatInr(_n!)}'),
                    loading: _busy,
                    onPressed: _go),
              ]),
        ),
      ),
    );
  }
}
