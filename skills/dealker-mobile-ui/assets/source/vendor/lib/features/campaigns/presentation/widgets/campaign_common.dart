import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/core/theme/app_theme.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';

export 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
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
        errorText,
        formatInr,
        heading,
        kAuctionBlue,
        kAuctionBlueSoft,
        timeAgo;

/// Campaign accent — same blue as the rest of the vendor app's action flows.
const kAdBlue = kAuctionBlue;
const kAdBlueSoft = kAuctionBlueSoft;
const kAdGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1456D6), Color(0xFF2F7BFF), Color(0xFF5B9DFF)],
);

final _inr2 =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

/// ₹14.50 — for per-click prices, where the paise matter.
String inr2(num v) => v == v.roundToDouble() ? formatInr(v) : _inr2.format(v);

/// 18420 → 18.4K · 250000 → 2.5L · 12000000 → 1.2Cr (Indian units; the intl
/// "en_IN" compact format prints "T" for thousand, which reads as trillion).
String compact(num v) {
  String f(num x, String unit) {
    final t = (x * 10).truncate() / 10;
    return '${t == t.roundToDouble() ? t.toInt() : t}$unit';
  }

  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a < 1000) return '${v.round()}';
  if (a < 100000) return '$sign${f(a / 1000, 'K')}';
  if (a < 10000000) return '$sign${f(a / 100000, 'L')}';
  return '$sign${f(a / 10000000, 'Cr')}';
}

String percent(num ratio, {int digits = 1}) =>
    '${(ratio * 100).toStringAsFixed(digits)}%';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
];

String formatDay(DateTime? d, {bool year = true}) => d == null
    ? '—'
    : '${d.day} ${_months[d.month - 1]}${year ? ' ${d.year}' : ''}';

String dateRange(DateTime? a, DateTime? b) =>
    '${formatDay(a)} → ${b == null ? 'No end date' : formatDay(b)}';

class CampaignStatusStyle {
  const CampaignStatusStyle(this.label, this.fg, this.bg, this.icon);
  final String label;
  final Color fg;
  final Color bg;
  final IconData icon;
}

CampaignStatusStyle campaignStatus(String s) => switch (s) {
      CampaignStatus.active => const CampaignStatusStyle('Live', AppColors.mint,
          AppColors.mintSoft, PhosphorIconsFill.broadcast),
      CampaignStatus.pending => const CampaignStatusStyle('In review',
          Color(0xFFB45309), AppColors.amberSoft, PhosphorIconsFill.hourglass),
      CampaignStatus.paused => const CampaignStatusStyle('Paused',
          Color(0xFFB45309), AppColors.amberSoft, PhosphorIconsFill.pause),
      CampaignStatus.rejected => const CampaignStatusStyle('Rejected',
          AppColors.rose, AppColors.roseSoft, PhosphorIconsFill.xCircle),
      CampaignStatus.suspended => const CampaignStatusStyle('Suspended',
          AppColors.rose, AppColors.roseSoft, PhosphorIconsFill.prohibit),
      CampaignStatus.ended => const CampaignStatusStyle(
          'Ended',
          AppColors.textSecondary,
          Color(0xFFEFF1F6),
          PhosphorIconsFill.flagCheckered),
      _ => const CampaignStatusStyle('Draft', AppColors.textSecondary,
          Color(0xFFEFF1F6), PhosphorIconsFill.pencilSimple),
    };

class CampaignStatusPill extends StatelessWidget {
  const CampaignStatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final st = campaignStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (status == CampaignStatus.active) ...[
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: st.fg, shape: BoxShape.circle)),
          const SizedBox(width: 5),
        ],
        Text(st.label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: st.fg)),
      ]),
    );
  }
}

/// "Automatic" / "Keywords" badge.
class TargetingChip extends StatelessWidget {
  const TargetingChip(this.t, {super.key});
  final Targeting t;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.violetSoft,
            borderRadius: BorderRadius.circular(7)),
        child: Text(t.label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.violet)),
      );
}

/// Small label/value tile used in stat rows.
class StatTile extends StatelessWidget {
  const StatTile(
      {super.key,
      required this.label,
      required this.value,
      this.icon,
      this.color = kAdBlue,
      this.bg = kAdBlueSoft,
      this.hint});
  final String label;
  final String value;
  final String? hint;
  final IconData? icon;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 15, color: color),
              ),
            if (icon != null) const SizedBox(width: 7),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary)),
            ),
          ]),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: heading(size: 19)),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10.5, color: AppColors.textMuted)),
          ],
        ]),
      );
}

/// White card with a title row, used to group blocks on the detail screen.
class AdSection extends StatelessWidget {
  const AdSection(
      {super.key,
      required this.title,
      required this.child,
      this.trailing,
      this.icon});
  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => HomeCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: kAdBlue),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(title, style: heading(size: 16))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

/// Thin progress bar (today's budget used, etc.).
class UsageBar extends StatelessWidget {
  const UsageBar(this.value,
      {super.key, this.color = kAdBlue, this.height = 7});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: height,
          color: value >= 1 ? AppColors.amber : color,
          backgroundColor: const Color(0xFFE8EEFB),
        ),
      );
}

/// Daily bars for the last N days — dependency-free, accessible via [label].
class DailyBars extends StatelessWidget {
  const DailyBars(
      {super.key,
      required this.values,
      required this.labelFor,
      this.height = 96});
  final List<num> values;
  final String Function(int index) labelFor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<num>(0, (a, b) => b > a ? b : a);
    return Semantics(
      label: 'Daily chart, ${values.length} days',
      child: SizedBox(
        height: height,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final (i, v) in values.indexed)
            Expanded(
              child: Tooltip(
                message: labelFor(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor:
                          max == 0 ? 0.04 : (v / max).clamp(0.04, 1).toDouble(),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xFF2F7BFF), Color(0xFF8DB8FF)]),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Soft pill used for chips/filters inside the campaign screens.
class AdChip extends StatelessWidget {
  const AdChip(this.text,
      {super.key, this.color = kAdBlue, this.bg = kAdBlueSoft});
  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      );
}

/// Info / warning strip.
class AdNotice extends StatelessWidget {
  const AdNotice(
      {super.key,
      required this.message,
      this.icon = PhosphorIconsFill.info,
      this.color = kAdBlue,
      this.bg = kAdBlueSoft,
      this.title,
      this.action});
  final String? title;
  final String message;
  final IconData icon;
  final Color color;
  final Color bg;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (title != null)
                Text(title!,
                    style: TextStyle(
                        fontFamily: AppTheme.headingFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.navy)),
              if (title != null) const SizedBox(height: 2),
              Text(message,
                  style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary)),
              if (action != null) ...[const SizedBox(height: 8), action!],
            ]),
          ),
        ]),
      );
}
