import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show heading, errorText;
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';
import 'package:dealker_vendor/features/demand/application/razorpay_pay.dart'
    show PayResult;
import 'package:dealker_vendor/features/profile/application/profile_providers.dart';
import 'package:dealker_vendor/features/profile/data/profile_models.dart';
import 'package:dealker_vendor/features/subscription/application/subscription_providers.dart';
import 'package:dealker_vendor/features/subscription/data/subscription_repository.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

const _rank = {'FREE': 0, 'PAID': 1, 'PREMIUM': 2, 'UNLIMITED': 3};

String _inr(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final left = s.length - i;
    b.write(s[i]);
    if (left > 1 && (left == 4 || (left > 4 && (left - 3) % 2 == 0))) b.write(',');
  }
  return '₹$b';
}

/// Settings → Subscription: your plan, and buying or renewing a higher one.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _yearly = false;
  String? _busyTier;
  SubscriptionPay? _pay;

  @override
  void dispose() {
    _pay?.dispose();
    super.dispose();
  }

  Future<void> _buy(SubPlan p) async {
    if (_busyTier != null) return;
    setState(() => _busyTier = p.tier);
    try {
      _pay ??= SubscriptionPay(ref.read(subscriptionRepositoryProvider));
      final out = await _pay!.pay(p.tier, _yearly,
          phone: ref.read(authControllerProvider).session?.phone);
      if (!mounted) return;
      ref.invalidate(membershipProvider);
      switch (out.result) {
        case PayResult.paid:
          showAppToast(context, '${p.name} plan is active. Thank you!');
        case PayResult.cancelled:
          showAppToast(context, 'Payment cancelled. You have not been charged.');
        case PayResult.failed:
          showAppToast(context, out.message ?? 'Payment failed.', error: true);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, errorText(e, 'Could not start the payment.'),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busyTier = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(membershipProvider);
    final plans = ref.watch(subPlansProvider);
    final current = m.asData?.value;
    final curTier = current?.tier ?? 'FREE';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft, color: AppColors.navy),
            onPressed: () => context.pop()),
        title: Text('Subscription', style: heading(size: 20)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(membershipProvider);
          ref.invalidate(subPlansProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _CurrentPlan(plan: current),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Text('Choose a plan', style: heading(size: 18))),
              _Cycle(yearly: _yearly, onChanged: (v) => setState(() => _yearly = v)),
            ]),
            const SizedBox(height: 12),
            plans.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Text(errorText(e, 'Could not load the plans.'),
                      textAlign: TextAlign.center),
                  TextButton(
                      onPressed: () => ref.invalidate(subPlansProvider),
                      child: const Text('Retry')),
                ]),
              ),
              data: (list) => Column(children: [
                for (final p in list)
                  _PlanCard(
                    plan: p,
                    yearly: _yearly,
                    current: curTier == p.tier,
                    higher: (_rank[p.tier] ?? 0) > (_rank[curTier] ?? 0),
                    busy: _busyTier == p.tier,
                    disabled: _busyTier != null,
                    onBuy: () => _buy(p),
                  ),
              ]),
            ),
            const SizedBox(height: 6),
            const _Note(),
          ],
        ),
      ),
    );
  }
}

class _CurrentPlan extends StatelessWidget {
  const _CurrentPlan({required this.plan});
  final Membership? plan;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    final free = p == null || p.tier == 'FREE';
    final used = p?.listingsUsed ?? 0;
    final limit = p?.listingLimit;
    final frac = (limit == null || limit == 0) ? 0.0 : (used / limit).clamp(0.0, 1.0);
    final days = p?.daysLeft;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF5B4BEA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(PhosphorIconsFill.crown, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          const Text('Your plan',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text(p?.planName.isNotEmpty == true ? p!.planName : 'Free',
            style: const TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
            free
                ? 'Upgrade to list more and unlock ads, auctions and priority support.'
                : (days == null
                    ? 'Active'
                    : days <= 0
                        ? 'Expires today — renew to keep your plan'
                        : 'Renews by paying again · $days day${days == 1 ? '' : 's'} left'),
            style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35)),
        const SizedBox(height: 14),
        Row(children: [
          Text(limit == null ? '$used listings · unlimited' : '$used of $limit listings used',
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
        if (limit != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
                value: frac,
                minHeight: 7,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white)),
          ),
        ],
      ]),
    );
  }
}

class _Cycle extends StatelessWidget {
  const _Cycle({required this.yearly, required this.onChanged});
  final bool yearly;
  final ValueChanged<bool> onChanged;

  Widget _seg(String label, bool on, VoidCallback tap) => GestureDetector(
        onTap: tap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: on ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : AppColors.navy)),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.cardBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _seg('Monthly', !yearly, () => onChanged(false)),
          _seg('Yearly', yearly, () => onChanged(true)),
        ]),
      );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.yearly,
    required this.current,
    required this.higher,
    required this.busy,
    required this.disabled,
    required this.onBuy,
  });
  final SubPlan plan;
  final bool yearly;
  final bool current;
  final bool higher;
  final bool busy;
  final bool disabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final top = plan.tier == 'UNLIMITED';
    final label = current ? 'Renew' : (higher ? 'Upgrade' : 'Switch to ${plan.name}');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: current ? AppColors.primary : AppColors.cardBorder,
            width: current ? 1.8 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(plan.name, style: heading(size: 19))),
          if (top)
            _Chip('Best for business', const Color(0xFFFFF3D6), const Color(0xFFB7791F)),
          if (current) ...[
            const SizedBox(width: 6),
            _Chip('Current', const Color(0xFFE5EEFF), AppColors.primary),
          ],
        ]),
        const SizedBox(height: 2),
        Text(plan.description,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_inr(plan.price(yearly)), style: heading(size: 28)),
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4),
            child: Text(yearly ? '/ year' : '/ month',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ),
          const Spacer(),
          if (yearly && plan.yearlySaving > 0)
            Text('Save ${_inr(plan.yearlySaving)}',
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
        ]),
        const SizedBox(height: 10),
        for (final f in plan.features)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              const Icon(PhosphorIconsFill.checkCircle, size: 17, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Expanded(child: Text(f, style: const TextStyle(fontSize: 13, color: AppColors.navy))),
            ]),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: disabled ? null : onBuy,
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text('$label · ${_inr(plan.price(yearly))}',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.bg, this.fg);
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
      );
}

class _Note extends StatelessWidget {
  const _Note();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          'Pay with UPI, card or netbanking. Renewing before your plan ends adds the new period on top of the days you have left. '
          'The green tick on your shop is for verified businesses (KYC) and is not part of a plan.',
          style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.textMuted),
        ),
      );
}
