import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/abandoned_carts/application/cart_providers.dart';
import 'package:dealker_vendor/features/abandoned_carts/data/cart_models.dart';
import 'package:dealker_vendor/features/abandoned_carts/presentation/widgets/cart_common.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// Pick what to remind about and which message to send. The preview is rendered by the
/// server with the same code that sends it, so it is exactly what the customer receives.
class SendReminderScreen extends ConsumerStatefulWidget {
  const SendReminderScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<SendReminderScreen> createState() => _SendReminderScreenState();
}

class _SendReminderScreenState extends ConsumerState<SendReminderScreen> {
  String? _template;
  Set<String>? _products; // null until the cart loads → all ticked
  bool _sending = false;

  Future<void> _send(CartDetail d) async {
    setState(() => _sending = true);
    try {
      final ids = _selected(d);
      await ref.read(cartRepositoryProvider).remind(
          d.id, _template!, ids.length == d.items.length ? const [] : ids);
      if (!mounted) return;
      refreshCarts(ref, id: d.id);
      context.pop();
      showAppToast(context, 'Reminder sent to ${d.customer}.');
    } catch (e) {
      if (mounted) {
        showAppToast(context, errorText(e), error: true, bottom: 90);
        refreshCarts(ref, id: d.id);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<String> _selected(CartDetail d) {
    final all = d.items.map((i) => i.productId).toList();
    final s = _products ?? all.toSet();
    return all.where(s.contains).toList();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(cartDetailProvider(widget.id));
    return detail.when(skipLoadingOnReload: true, skipError: true, 
      loading: () => const Scaffold(
          appBar: AuctionAppBar(title: 'Send Reminder'),
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          appBar: const AuctionAppBar(title: 'Send Reminder'),
          body: ErrorState(
              message: errorText(e, 'Could not load this cart.'),
              onRetry: () => ref.invalidate(cartDetailProvider(widget.id)))),
      data: (d) {
        final templates = d.reminder.templates;
        final firstAvailable = templates.where((t) => t.available).firstOrNull;
        final template = _template ?? (firstAvailable?.key);
        final selected = _selected(d);
        final canSend =
            d.reminder.canRemind && template != null && selected.isNotEmpty;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: const AuctionAppBar(title: 'Send Reminder'),
          bottomNavigationBar: BottomActionBar(
            child: CartButton(
              label: 'Send Reminder Now',
              icon: PhosphorIconsBold.paperPlaneTilt,
              loading: _sending,
              onPressed: canSend
                  ? () {
                      _template = template;
                      _send(d);
                    }
                  : null,
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              Text('Send to', style: heading(size: 16)),
              const SizedBox(height: 8),
              Row(children: [
                CartAvatar(d.customer, size: 38),
                const SizedBox(width: 10),
                Text(d.customer, style: heading(size: 16)),
                const SizedBox(width: 8),
                ChannelChip(d.channel),
              ]),
              const SizedBox(height: 18),
              Text('Channel', style: heading(size: 16)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.violetGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(children: [
                  Icon(PhosphorIconsFill.bellRinging,
                      color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Push notification',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                          SizedBox(height: 2),
                          Text('Appears on their phone and in the Dealkr app',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12.5)),
                        ]),
                  ),
                  Icon(PhosphorIconsFill.checkCircle, color: Colors.white),
                ]),
              ),
              if (d.items.length > 1) ...[
                const SizedBox(height: 18),
                Text('Remind about', style: heading(size: 16)),
                const SizedBox(height: 8),
                HomeCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  // ListTiles paint their ink on the nearest Material; the card's own
                  // background would hide it.
                  child: Material(
                    color: Colors.transparent,
                    child: Column(children: [
                      for (final (i, l) in d.items.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: kCartViolet,
                          value: selected.contains(l.productId),
                          onChanged: (v) => setState(() {
                            final s = (_products ??
                                    d.items.map((x) => x.productId).toSet())
                                .toSet();
                            v == true
                                ? s.add(l.productId)
                                : s.remove(l.productId);
                            _products = s;
                          }),
                          title: Text(l.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${formatInr(l.lineTotal)} · Qty ${l.quantity}',
                              style: const TextStyle(fontSize: 12)),
                          secondary:
                              ProductThumb(l.thumbnail, size: 40, radius: 8),
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text('Choose a message', style: heading(size: 16)),
              const SizedBox(height: 8),
              for (final t in templates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TemplateTile(
                    t: t,
                    selected: template == t.key,
                    onTap: t.available
                        ? () => setState(() => _template = t.key)
                        : null,
                    // The exact message sits right under the option, never off-screen.
                    preview: template == t.key
                        ? _Preview(
                            k: PreviewKey(
                                d.id,
                                t.key,
                                selected.length == d.items.length
                                    ? const []
                                    : selected),
                            enabled: selected.isNotEmpty)
                        : null,
                  ),
                ),
              const SizedBox(height: 14),
              AdNotice(
                title: 'Fair to shoppers',
                message:
                    'One reminder per cart every 24 hours, up to ${d.reminder.max} per cart. '
                    'It only mentions your products, and customers who turned off promotions are not messaged.',
                icon: PhosphorIconsFill.shieldCheck,
                color: kCartViolet,
                bg: AppColors.violetSoft,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile(
      {required this.t,
      required this.selected,
      required this.onTap,
      this.preview});
  final ReminderTemplate t;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? preview;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: t.available ? 1 : 0.55,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? AppColors.violetSoft : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? kCartViolet : AppColors.border,
                  width: selected ? 1.6 : 1.2),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(
                    selected
                        ? PhosphorIconsFill.radioButton
                        : PhosphorIconsRegular.circle,
                    color: selected ? kCartViolet : AppColors.border,
                    size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.label, style: heading(size: 15)),
                        const SizedBox(height: 2),
                        Text(
                            t.available
                                ? t.hint
                                : (t.unavailableReason ?? t.hint),
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary)),
                      ]),
                ),
              ]),
              if (preview != null) ...[const SizedBox(height: 12), preview!],
            ]),
          ),
        ),
      );
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.k, required this.enabled});
  final PreviewKey k;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) {
      return const Text('Tick at least one product.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13));
    }
    final p = ref.watch(reminderPreviewProvider(k));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4DEFF)),
      ),
      child: p.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const Padding(
            padding: EdgeInsets.all(10),
            child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4)))),
        error: (e, _) => Text(errorText(e, 'Could not build the preview.'),
            style: const TextStyle(color: AppColors.rose, fontSize: 13)),
        data: (v) =>
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                  color: kCartViolet, borderRadius: BorderRadius.circular(6)),
              child: const Icon(PhosphorIconsFill.shoppingBag,
                  size: 13, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text('DEALKR · now',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 8),
          Text(v.title, style: heading(size: 15)),
          const SizedBox(height: 4),
          Text(v.body,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.4, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}
