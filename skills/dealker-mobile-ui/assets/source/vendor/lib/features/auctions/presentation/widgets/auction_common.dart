import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/core/theme/app_theme.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';

export 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart'
    show formatInr, heading, timeAgo, HomeCard;

/// Auction accent (matches the mockup's blue).
const kAuctionBlue = Color(0xFF1F6FEB);
const kAuctionBlueSoft = Color(0xFFE9F1FF);

/// "1 unit" / "20 units".
String unitsLabel(int n) => n == 1 ? '1 unit' : '$n units';

String errorText(Object e, [String fallback = 'Something went wrong.']) =>
    e is Failure ? e.message : fallback;

String formatDateTime(DateTime? t) {
  if (t == null) return '—';
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${m[t.month - 1]} ${t.year}, '
      '${h.toString().padLeft(2, '0')}:$mm ${t.hour >= 12 ? 'PM' : 'AM'}';
}

/// White app bar with back arrow + title, used by every auction screen.
class AuctionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AuctionAppBar(
      {super.key,
      required this.title,
      this.onBack,
      this.actions,
      this.subtitle});
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 56 : 60);

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: subtitle == null ? 56 : 60,
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  icon: const Icon(PhosphorIconsRegular.arrowLeft,
                      color: AppColors.navy, size: 24),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: heading(size: 18)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                ...?actions,
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      );
}

class AudienceChip extends StatelessWidget {
  const AudienceChip(this.audience, {super.key});
  final AuctionAudience audience;

  @override
  Widget build(BuildContext context) {
    final b2b = audience == AuctionAudience.b2b;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: b2b ? AppColors.roleB2bBg : AppColors.roleB2cBg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(audience.short,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: b2b ? AppColors.roleB2b : AppColors.roleB2c)),
    );
  }
}

class StatusStyle {
  const StatusStyle(this.label, this.fg, this.bg);
  final String label;
  final Color fg;
  final Color bg;
}

StatusStyle statusStyle(String s) => switch (s) {
      'LIVE' => const StatusStyle('Live', AppColors.mint, AppColors.mintSoft),
      'PAUSED' =>
        const StatusStyle('Paused', Color(0xFFB45309), AppColors.amberSoft),
      'SCHEDULED' =>
        const StatusStyle('Upcoming', kAuctionBlue, kAuctionBlueSoft),
      'PENDING_APPROVAL' =>
        const StatusStyle('In review', Color(0xFFB45309), AppColors.amberSoft),
      'DRAFT' =>
        const StatusStyle('Draft', AppColors.textSecondary, Color(0xFFEFF1F6)),
      'REJECTED' =>
        const StatusStyle('Rejected', AppColors.rose, AppColors.roseSoft),
      'AWAITING_PAYMENT' => const StatusStyle(
          'Awaiting payment', Color(0xFFB45309), AppColors.amberSoft),
      'SOLD' => const StatusStyle('Sold', AppColors.mint, AppColors.mintSoft),
      'UNSOLD' =>
        const StatusStyle('Unsold', AppColors.textSecondary, Color(0xFFEFF1F6)),
      'DEFAULTED' =>
        const StatusStyle('Defaulted', AppColors.rose, AppColors.roseSoft),
      'CANCELLED' => const StatusStyle(
          'Cancelled', AppColors.textSecondary, Color(0xFFEFF1F6)),
      _ => StatusStyle(s, AppColors.textSecondary, const Color(0xFFEFF1F6)),
    };

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final st = statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (status == 'LIVE') ...[
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

/// Product photo with a neutral placeholder.
class ProductThumb extends StatelessWidget {
  const ProductThumb(this.url, {super.key, this.size = 56, this.radius = 12});
  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: const Color(0xFFF1F4FB),
      child: Icon(PhosphorIconsRegular.deviceMobile,
          size: size * 0.5, color: AppColors.textMuted),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null || url!.isEmpty
          ? placeholder
          : url!.startsWith('http')
              ? CachedNetworkImage(
                  imageUrl: url!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => placeholder,
                  errorWidget: (_, __, ___) => placeholder,
                )
              : placeholder,
    );
  }
}

/// Square, grid-filling photo (network URL, or a local file in demo mode).
class MediaTile extends StatelessWidget {
  const MediaTile(this.url,
      {super.key, this.radius = 12, this.fit = BoxFit.cover});
  final String url;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
        color: const Color(0xFFF1F4FB),
        child:
            const Icon(PhosphorIconsRegular.image, color: AppColors.textMuted));
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.startsWith('http')
          ? CachedNetworkImage(
              imageUrl: url,
              fit: fit,
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback)
          : Image.file(File(url),
              fit: fit, errorBuilder: (_, __, ___) => fallback),
    );
  }
}

/// hh : mm : ss boxes counting down to [endsAt] using the server's clock.
class CountdownBoxes extends StatefulWidget {
  const CountdownBoxes(
      {super.key,
      required this.endsAt,
      this.offset = Duration.zero,
      this.compact = false});
  final DateTime? endsAt;
  final Duration offset;
  final bool compact;

  @override
  State<CountdownBoxes> createState() => _CountdownBoxesState();
}

class _CountdownBoxesState extends State<CountdownBoxes> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Duration get _left {
    final e = widget.endsAt;
    if (e == null) return Duration.zero;
    final d = e.difference(DateTime.now().add(widget.offset));
    return d.isNegative ? Duration.zero : d;
  }

  @override
  Widget build(BuildContext context) {
    final d = _left;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final c = widget.compact;
    Widget box(String v, String l) => Container(
          width: c ? 44 : 62,
          padding: EdgeInsets.symmetric(vertical: c ? 6 : 9),
          decoration: BoxDecoration(
              color: kAuctionBlueSoft, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(v,
                style: heading(
                    size: c ? 18 : 26,
                    color: AppColors.navy,
                    w: FontWeight.w800)),
            Text(l,
                style:
                    const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ]),
        );
    Widget sep() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Text(':',
            style: heading(size: c ? 16 : 22, color: AppColors.textMuted)));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      box(h, 'Hours'),
      sep(),
      box(m, 'Minutes'),
      sep(),
      box(s, 'Seconds'),
    ]);
  }
}

/// Plain text countdown ("1h 32m", "24m 16s", "Ended").
String shortCountdown(DateTime? end, [Duration offset = Duration.zero]) {
  if (end == null) return '—';
  final d = end.difference(DateTime.now().add(offset));
  if (d.isNegative || d == Duration.zero) return 'Ended';
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m ${d.inSeconds % 60}s';
}

// ── form widgets ──────────────────────────────────────────────────────

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.optional = false});
  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7, top: 2),
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: text,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          if (optional)
            const TextSpan(
                text: '  (Optional)',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ])),
      );
}

class AuctionField extends StatelessWidget {
  const AuctionField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.hint,
    this.prefix,
    this.number = false,
    this.maxLength,
    this.suffix,
    this.fieldKey,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
  });
  final int maxLines;
  final TextCapitalization textCapitalization;
  final String initial;
  final ValueChanged<String> onChanged;
  final String? hint;
  final String? prefix;
  final bool number;
  final int? maxLength;
  final Widget? suffix;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => TextFormField(
        key: fieldKey,
        initialValue: initial,
        onChanged: onChanged,
        maxLength: maxLength,
        maxLines: maxLines,
        minLines: maxLines > 1 ? maxLines : null,
        textCapitalization: textCapitalization,
        keyboardType: number
            ? TextInputType.number
            : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
        inputFormatters:
            number ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: const TextStyle(
            fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.navy),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: const TextStyle(
              color: AppColors.textMuted, fontWeight: FontWeight.w400),
          // prefixIcon (not prefixText) so the ₹ stays visible while empty.
          prefixIcon: prefix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 14, right: 6),
                  child: Text(prefix!,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy)),
                ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: suffix,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          filled: true,
          fillColor: Colors.white,
          border: _border(AppColors.border),
          enabledBorder: _border(AppColors.border),
          focusedBorder: _border(kAuctionBlue, 1.6),
        ),
      );

  static OutlineInputBorder _border(Color c, [double w = 1.2]) =>
      OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w));
}

/// Tap-to-open row styled like a dropdown/field.
class PickerField extends StatelessWidget {
  const PickerField(
      {super.key,
      required this.value,
      required this.onTap,
      this.icon,
      this.hint});
  final String? value;
  final String? hint;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: AppColors.textSecondary),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(value ?? hint ?? '',
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight:
                          value == null ? FontWeight.w400 : FontWeight.w600,
                      color: value == null
                          ? AppColors.textMuted
                          : AppColors.navy)),
            ),
            const Icon(PhosphorIconsRegular.caretDown,
                size: 17, color: AppColors.textSecondary),
          ]),
        ),
      );
}

/// Two-option segmented control (BTO|BTOC, Start now|Schedule).
class Segmented extends StatelessWidget {
  const Segmented(
      {super.key,
      required this.labels,
      required this.index,
      required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
        for (final (i, l) in labels.indexed)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 46,
                margin: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == index ? kAuctionBlue : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: i == index ? kAuctionBlue : AppColors.border,
                      width: 1.2),
                ),
                child: Text(l,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: i == index
                            ? Colors.white
                            : AppColors.textSecondary)),
              ),
            ),
          ),
      ]);
}

/// Solid blue CTA used by the auction screens.
class AuctionButton extends StatelessWidget {
  const AuctionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.outlined = false,
    this.danger = false,
    this.icon,
    this.trailing,
    this.height = 54,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final bool danger;
  final IconData? icon;
  final IconData? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    final base = danger ? AppColors.rose : kAuctionBlue;
    final fg = outlined ? base : Colors.white;
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: onPressed == null && !loading ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onPressed : null,
          child: Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: outlined ? Colors.white : null,
              gradient: outlined
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: danger
                          ? [const Color(0xFFFF5A5F), base]
                          : [const Color(0xFF3B82F6), base, const Color(0xFF1553C7)]),
              border: outlined ? Border.all(color: base, width: 1.4) : null,
              boxShadow: outlined
                  ? null
                  : [
                      BoxShadow(
                          color: base.withValues(alpha: 0.32),
                          blurRadius: 14,
                          offset: const Offset(0, 6))
                    ],
            ),
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child:
                        CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[
                      Icon(icon, size: 19, color: fg),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppTheme.headingFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 16.5,
                              color: fg)),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      Icon(trailing, size: 19, color: fg),
                    ],
                  ]),
          ),
        ),
      ),
    );
  }
}

/// Sticky bottom bar that hosts the screen's primary action.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.cardBorder)),
          boxShadow: [
            BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, -4))
          ],
        ),
        child: SafeArea(top: false, child: child),
      );
}

/// Label ↔ value row used in summaries.
class SummaryRow extends StatelessWidget {
  const SummaryRow(this.label, this.value,
      {super.key, this.bold = false, this.valueColor});
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(
              flex: 2,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary))),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                    color: valueColor ?? AppColors.navy)),
          ),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message,
      this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                  color: kAuctionBlueSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: kAuctionBlue),
            ),
            const SizedBox(height: 16),
            Text(title, style: heading(size: 18), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, height: 1.4, color: AppColors.textSecondary)),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ]),
        ),
      );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: PhosphorIconsRegular.warningCircle,
        title: 'Could not load',
        message: message,
        action: SizedBox(
            width: 140,
            child:
                AuctionButton(label: 'Retry', height: 46, onPressed: onRetry)),
      );
}
