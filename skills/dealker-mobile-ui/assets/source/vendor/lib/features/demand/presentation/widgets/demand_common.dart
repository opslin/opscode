import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';

export 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart'
    show
        AuctionAppBar,
        AuctionButton,
        AuctionField,
        BottomActionBar,
        EmptyState,
        ErrorState,
        FieldLabel,
        HomeCard,
        PickerField,
        ProductThumb,
        Segmented,
        SummaryRow,
        compact,
        errorText,
        formatDay,
        formatInr,
        heading,
        kAuctionBlue,
        kAuctionBlueSoft,
        timeAgo;

/// Demand accent — the same blue as the rest of the vendor app's action flows.
const kDemandBlue = kAuctionBlue;
const kDemandBlueSoft = kAuctionBlueSoft;
const kDemandNavy = Color(0xFF0B2559);
const kDemandNavy2 = Color(0xFF123A8C);
const kDemandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0B2559), Color(0xFF14419A), Color(0xFF1F6FEB)],
);
const kAmberText = Color(0xFFB45309);
const kGreySoft = Color(0xFFEFF1F6);

/// "₹29,000 – ₹30,000", "₹29,000" or null when the buyer gave no price.
String? priceRange(Requirement r) {
  final lo = r.targetPrice;
  final hi = r.targetPriceMax;
  if (lo != null && hi != null && hi != lo) {
    return '${formatInr(lo)} – ${formatInr(hi)}';
  }
  final one = lo ?? hi;
  return one == null ? null : formatInr(one);
}

String pcs(int n) => '$n pc${n == 1 ? '' : 's'}';

String conditionPrefLabel(String v) => switch (v) {
      'NEW' => 'New only',
      'USED_OR_REFURBISHED' => 'Used / Refurbished',
      _ => 'Any condition',
    };

String displayPrefLabel(String v) => switch (v) {
      'ORIGINAL' => 'Original preferred',
      'GRADE_AB' => 'Grade A / B',
      _ => 'Any',
    };

String fulfilmentPrefLabel(String v) => switch (v) {
      'PICKUP' => 'Pickup',
      'DELIVERY' => 'Delivery',
      _ => 'Pickup or delivery',
    };

String conditionLabel(String? api) => switch (api) {
      'NEW' => 'New',
      'OPEN_BOX' => 'Open box',
      'REFURBISHED' => 'Refurbished',
      'USED_LIKE_NEW' => 'Like new',
      'USED_GOOD' => 'Used – good',
      'USED_FAIR' => 'Used – fair',
      _ => api ?? '—',
    };

/// "Closes in 1d 23h" / "Closes in 3h 10m" / "Closed".
String closesIn(DateTime? t) {
  if (t == null) return '';
  final d = t.difference(DateTime.now());
  if (d.isNegative) return 'Closed';
  if (d.inDays >= 1) return 'Closes in ${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours >= 1) return 'Closes in ${d.inHours}h ${d.inMinutes % 60}m';
  return 'Closes in ${d.inMinutes}m';
}

String dateTimeShort(DateTime? t) {
  if (t == null) return '—';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${formatDay(t, year: false)}, $h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
}

/// "iPhone 15 128GB" — the product name already carries the storage when the buyer typed it.
String requirementTitle(Requirement r) {
  final s = r.storage;
  if (s == null ||
      r.productName
          .toUpperCase()
          .replaceAll(' ', '')
          .contains(s.toUpperCase())) {
    return r.productName;
  }
  return '${r.productName} $s';
}

// ── pills & tags ───────────────────────────────────────────────────────────

class Pill extends StatelessWidget {
  const Pill(this.label,
      {super.key,
      required this.fg,
      required this.bg,
      this.icon,
      this.dot = false});
  final String label;
  final Color fg;
  final Color bg;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot) ...[
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4)
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ]),
      );
}

class TagChip extends StatelessWidget {
  const TagChip(this.tag, {super.key});
  final String tag;

  @override
  Widget build(BuildContext context) {
    final urgent = tag == 'URGENT';
    return Pill(urgent ? 'Urgent' : 'Bulk order',
        fg: urgent ? AppColors.rose : kAmberText,
        bg: urgent ? AppColors.roseSoft : AppColors.amberSoft,
        icon: urgent ? PhosphorIconsFill.lightning : PhosphorIconsFill.stack);
  }
}

class OfferStatePill extends StatelessWidget {
  const OfferStatePill(this.state, {super.key});
  final String? state;

  @override
  Widget build(BuildContext context) => switch (state) {
        OfferState.pending =>
          const Pill('Pending', fg: kAmberText, bg: AppColors.amberSoft),
        OfferState.viewed => const Pill('Viewed',
            fg: kDemandBlue, bg: kDemandBlueSoft, icon: PhosphorIconsFill.eye),
        OfferState.accepted => const Pill('Accepted',
            fg: AppColors.mint,
            bg: AppColors.mintSoft,
            icon: PhosphorIconsFill.checkCircle),
        OfferState.partial => const Pill('Partly accepted',
            fg: AppColors.mint,
            bg: AppColors.mintSoft,
            icon: PhosphorIconsFill.checkCircle),
        OfferState.notSelected => const Pill('Not selected',
            fg: AppColors.textSecondary, bg: kGreySoft),
        OfferState.withdrawn =>
          const Pill('Withdrawn', fg: AppColors.textSecondary, bg: kGreySoft),
        OfferState.expired =>
          const Pill('Expired', fg: AppColors.textSecondary, bg: kGreySoft),
        _ => const SizedBox.shrink(),
      };
}

class ReqStatusPill extends StatelessWidget {
  const ReqStatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) => switch (status) {
        ReqStatus.open => const Pill('Open',
            fg: AppColors.mint, bg: AppColors.mintSoft, dot: true),
        ReqStatus.awarded => const Pill('Awaiting payment',
            fg: kAmberText, bg: AppColors.amberSoft),
        ReqStatus.inFulfilment =>
          const Pill('In progress', fg: kDemandBlue, bg: kDemandBlueSoft),
        ReqStatus.completed => const Pill('Completed',
            fg: AppColors.mint,
            bg: AppColors.mintSoft,
            icon: PhosphorIconsFill.checkCircle),
        ReqStatus.cancelled =>
          const Pill('Cancelled', fg: AppColors.textSecondary, bg: kGreySoft),
        ReqStatus.expired =>
          const Pill('Expired', fg: AppColors.textSecondary, bg: kGreySoft),
        _ => Pill(status, fg: AppColors.textSecondary, bg: kGreySoft),
      };
}

({String label, Color fg, Color bg}) orderStatusStyle(DemandOrder o,
    {required bool buyer}) {
  switch (o.status) {
    case OrderStatus.pendingPayment:
      return (
        label: buyer ? 'Payment due' : 'Awaiting payment',
        fg: kAmberText,
        bg: AppColors.amberSoft
      );
    case OrderStatus.paid:
      return (
        label: buyer ? 'Paid · seller packing' : 'Paid · pack it',
        fg: kDemandBlue,
        bg: kDemandBlueSoft
      );
    case OrderStatus.packed:
      return (label: 'Packed', fg: kDemandBlue, bg: kDemandBlueSoft);
    case OrderStatus.dispatched:
      return (
        label: o.isPickup ? 'Ready for pickup' : 'In transit',
        fg: kDemandBlue,
        bg: kDemandBlueSoft
      );
    case OrderStatus.delivered:
      return (label: 'Delivered', fg: AppColors.mint, bg: AppColors.mintSoft);
    case OrderStatus.completed:
      return (label: 'Completed', fg: AppColors.mint, bg: AppColors.mintSoft);
    case OrderStatus.disputed:
      return (
        label: 'Issue reported',
        fg: AppColors.rose,
        bg: AppColors.roseSoft
      );
    case OrderStatus.cancelled:
      return (label: 'Cancelled', fg: AppColors.textSecondary, bg: kGreySoft);
    case OrderStatus.refunded:
      return (label: 'Refunded', fg: AppColors.textSecondary, bg: kGreySoft);
    default:
      return (label: o.status, fg: AppColors.textSecondary, bg: kGreySoft);
  }
}

class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill(this.order, {super.key, required this.buyer});
  final DemandOrder order;
  final bool buyer;

  @override
  Widget build(BuildContext context) {
    final s = orderStatusStyle(order, buyer: buyer);
    return Pill(s.label, fg: s.fg, bg: s.bg);
  }
}

// ── small building blocks ───────────────────────────────────────────────────

class Initials extends StatelessWidget {
  const Initials(this.name, {super.key, this.size = 44});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final text = words.isEmpty
        ? '?'
        : words.take(2).map((w) => w.characters.first.toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
          gradient: AppColors.violetGradient, shape: BoxShape.circle),
      child: Text(text,
          style: heading(
              size: size * 0.38, color: Colors.white, w: FontWeight.w800)),
    );
  }
}

class StarRating extends StatelessWidget {
  const StarRating(this.rating, {super.key});
  final double? rating;

  @override
  Widget build(BuildContext context) {
    if (rating == null) {
      return const Text('New seller',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(PhosphorIconsFill.star, size: 13, color: AppColors.amber),
      const SizedBox(width: 3),
      Text(rating!.toStringAsFixed(1),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.navy)),
    ]);
  }
}

/// Titled white card used by the detail screens.
class Section extends StatelessWidget {
  const Section(
      {super.key,
      this.title,
      required this.child,
      this.trailing,
      this.padding = const EdgeInsets.all(14),
      this.color = Colors.white,
      this.border});
  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) => HomeCard(
        padding: padding,
        color: color,
        border: border,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) ...[
            Row(children: [
              Expanded(child: Text(title!, style: heading(size: 15.5))),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 10),
          ],
          child,
        ]),
      );
}

/// Icon + label + value tile used in the requirement spec grid.
class SpecTile extends StatelessWidget {
  const SpecTile(
      {super.key,
      required this.icon,
      required this.label,
      required this.value,
      this.accent});
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: kDemandBlueSoft, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: kDemandBlue),
        ),
        const SizedBox(width: 9),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textMuted)),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: accent ?? AppColors.navy)),
            ),
          ]),
        ),
      ]);
}

/// Soft coloured notice (info / success / warning).
class Notice extends StatelessWidget {
  const Notice(
      {super.key,
      required this.icon,
      required this.text,
      this.color = kDemandBlue,
      this.bg = kDemandBlueSoft,
      this.title,
      this.action});
  final IconData icon;
  final String text;
  final String? title;
  final Color color;
  final Color bg;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (title != null)
                Text(title!,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color)),
              if (title != null) const SizedBox(height: 2),
              Text(text,
                  style: const TextStyle(
                      fontSize: 13, height: 1.35, color: AppColors.navy)),
              if (action != null) ...[const SizedBox(height: 6), action!],
            ]),
          ),
        ]),
      );
}

class PillTab extends StatelessWidget {
  const PillTab(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap,
      this.count,
      this.badge = false});
  final String label;
  final int? count;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? kDemandBlue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? kDemandBlue : AppColors.border, width: 1.2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(count == null ? label : '$label ($count)',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary)),
            if (badge && !selected) ...[
              const SizedBox(width: 6),
              Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: AppColors.rose, shape: BoxShape.circle)),
            ],
          ]),
        ),
      );
}

/// A vertical progress timeline ("Offer accepted → Payment done → … → Delivered").
class TimelineStep {
  const TimelineStep(
      {required this.title,
      this.subtitle,
      this.time,
      this.done = false,
      this.current = false,
      this.trailing});
  final String title;
  final String? subtitle;
  final DateTime? time;
  final bool done;
  final bool current;
  final Widget? trailing;
}

class StepTimeline extends StatelessWidget {
  const StepTimeline({super.key, required this.steps});
  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (i, s) in steps.indexed)
          IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 30,
                child: Column(children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: s.done
                          ? AppColors.mint
                          : (s.current ? kDemandBlue : Colors.white),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: s.done
                              ? AppColors.mint
                              : (s.current
                                  ? kDemandBlue
                                  : AppColors.borderStrong),
                          width: 1.6),
                    ),
                    child: s.done
                        ? const Icon(PhosphorIconsBold.check,
                            size: 14, color: Colors.white)
                        : (s.current
                            ? const Icon(PhosphorIconsFill.circle,
                                size: 8, color: Colors.white)
                            : null),
                  ),
                  if (i != steps.length - 1)
                    Expanded(
                        child: Container(
                            width: 2,
                            color: s.done ? AppColors.mint : AppColors.border)),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      left: 6, bottom: i == steps.length - 1 ? 0 : 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(s.title,
                                style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: s.done || s.current
                                        ? AppColors.navy
                                        : AppColors.textMuted)),
                          ),
                          if (s.trailing != null) s.trailing!,
                        ]),
                        if (s.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(s.subtitle!,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.3,
                                  color: AppColors.textSecondary)),
                        ],
                        if (s.time != null) ...[
                          const SizedBox(height: 2),
                          Text(dateTimeShort(s.time),
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.textMuted)),
                        ],
                      ]),
                ),
              ),
            ]),
          ),
      ]);
}

class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key, this.height = 92});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F4FB),
            borderRadius: BorderRadius.circular(16)),
      );
}

/// Yes/No dialog in the app's style. Returns true only when the vendor confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
  String cancelLabel = 'Not now',
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: heading(size: 18)),
      content: Text(message,
          style: const TextStyle(
              fontSize: 14, height: 1.4, color: AppColors.textSecondary)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel,
              style: TextStyle(
                  color: danger ? AppColors.rose : kDemandBlue,
                  fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// Bottom sheet with a drag handle, rounded top and keyboard-safe padding.
Future<T?> showDemandSheet<T>(BuildContext context,
        {required Widget Function(BuildContext) builder}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(4))),
                  ),
                  builder(ctx),
                ]),
          ),
        ),
      ),
    );

/// − 6 + stepper for quantities.
class QtyStepper extends StatelessWidget {
  const QtyStepper(
      {super.key,
      required this.value,
      required this.onChanged,
      this.min = 1,
      this.max = 100000,
      this.compact = false});
  final int value;
  final int min;
  final int max;
  final bool compact;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, bool enabled, VoidCallback tap) =>
        GestureDetector(
          onTap: enabled ? tap : null,
          child: Container(
            width: compact ? 32 : 40,
            height: compact ? 32 : 40,
            decoration: BoxDecoration(
              color: enabled ? kDemandBlueSoft : const Color(0xFFF3F4F8),
              borderRadius: BorderRadius.circular(compact ? 9 : 11),
            ),
            child: Icon(icon,
                size: compact ? 16 : 19,
                color: enabled ? kDemandBlue : AppColors.textMuted),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(PhosphorIconsBold.minus, value > min, () => onChanged(value - 1)),
      SizedBox(
        width: compact ? 40 : 54,
        child: Text('$value',
            textAlign: TextAlign.center,
            style: heading(size: compact ? 16 : 19, w: FontWeight.w800)),
      ),
      btn(PhosphorIconsBold.plus, value < max, () => onChanged(value + 1)),
    ]);
  }
}

/// Single-select chips (condition, lead time …).
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips(
      {super.key,
      required this.options,
      required this.value,
      required this.onChanged,
      required this.label});
  final List<T> options;
  final T? value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options)
          GestureDetector(
            onTap: () => onChanged(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: o == value ? kDemandBlueSoft : Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                    color: o == value ? kDemandBlue : AppColors.border,
                    width: 1.3),
              ),
              child: Text(label(o),
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color:
                          o == value ? kDemandBlue : AppColors.textSecondary)),
            ),
          ),
      ]);
}

/// Label on the left, value on the right — each takes the room it needs (unlike [SummaryRow]'s fixed split).
class KV extends StatelessWidget {
  const KV(this.label, this.value,
      {super.key, this.bold = false, this.valueColor});
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      color: bold ? AppColors.navy : AppColors.textSecondary,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
          const SizedBox(width: 14),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: bold ? 16 : 14.5,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                    color: valueColor ?? AppColors.navy)),
          ),
        ]),
      );
}
