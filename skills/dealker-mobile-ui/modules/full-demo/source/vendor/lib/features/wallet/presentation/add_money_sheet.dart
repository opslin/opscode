import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';
import 'package:dealker_vendor/features/demand/application/razorpay_pay.dart'
    show PayResult;
import 'package:dealker_vendor/features/wallet/application/topup_razorpay.dart';
import 'package:dealker_vendor/features/wallet/application/wallet_providers.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

Future<void> showAddMoneySheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const AddMoneySheet(),
    );

/// "Add money": type or pick an amount, pay with Razorpay (UPI / cards / netbanking), and the wallet is credited.
class AddMoneySheet extends ConsumerStatefulWidget {
  const AddMoneySheet({super.key});

  @override
  ConsumerState<AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends ConsumerState<AddMoneySheet> {
  final _c = TextEditingController();
  bool _busy = false;
  String? _error;
  WalletTopUp? _topUp;

  static const _presets = <int>[500, 1000, 2000, 5000];

  @override
  void dispose() {
    _c.dispose();
    _topUp?.dispose();
    super.dispose();
  }

  num? get _amount => num.tryParse(_c.text.trim());

  String? _validate() {
    final v = _amount;
    if (v == null || v <= 0) return 'Enter an amount.';
    if (v < 10) return 'The minimum is ₹10.';
    if (v > 10000) return 'The maximum per top-up is ₹10,000.';
    return null;
  }

  Future<void> _go() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      _topUp ??= WalletTopUp(ref.read(walletRepositoryProvider));
      final out = await _topUp!
          .pay(_amount!, phone: ref.read(authControllerProvider).session?.phone);
      if (!mounted) return;
      switch (out.result) {
        case PayResult.paid:
          invalidateWallet(ref);
          Navigator.pop(context);
          showAppToast(context, '${formatInr(_amount!)} added to your wallet.');
        case PayResult.cancelled:
          showAppToast(context, 'Payment cancelled — nothing was charged.');
        case PayResult.failed:
          setState(() => _error = out.message ?? 'The payment did not go through.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amt = _amount;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          Image.asset('assets/3d/cart/piggy.png', height: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Add money', style: heading(size: 20, w: FontWeight.w800)),
              const Text('Pay with UPI, card or netbanking',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _c,
          autofocus: true,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() => _error = null),
          style: heading(size: 26, w: FontWeight.w800),
          decoration: InputDecoration(
            prefixText: '₹ ',
            prefixStyle: heading(size: 26, w: FontWeight.w800),
            hintText: '0',
            errorText: _error,
            filled: true,
            fillColor: const Color(0xFFF4F7FF),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in _presets)
            ActionChip(
              label: Text('₹$p'),
              onPressed: _busy ? null : () => setState(() { _c.text = '$p'; _error = null; }),
            ),
        ]),
        const SizedBox(height: 6),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Between ₹10 and ₹10,000 per top-up.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
        const SizedBox(height: 14),
        AuctionButton(
          label: amt == null || amt <= 0 ? 'Add money' : 'Add ${formatInr(amt)}',
          icon: PhosphorIconsBold.lockKey,
          loading: _busy,
          onPressed: _go,
        ),
      ]),
    );
  }
}
