import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/core/theme/app_theme.dart';

final _inr =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String formatInr(num v) => _inr.format(v);

String timeAgo(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

TextStyle heading(
        {double size = 18,
        Color color = AppColors.navy,
        FontWeight w = FontWeight.w700}) =>
    TextStyle(
        fontFamily: AppTheme.headingFont,
        fontWeight: w,
        fontSize: size,
        color: color,
        height: 1.15);

/// White rounded card used across the home.
class HomeCard extends StatelessWidget {
  const HomeCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(14),
      this.color = Colors.white,
      this.border});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border ?? AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: child,
      );
}

/// Section heading with an optional "View all" link that always goes somewhere real.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.onViewAll});
  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: heading(size: 17.5))),
          if (onViewAll != null)
            InkWell(
              onTap: onViewAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Text('View all',
                        style: heading(
                            size: 13.5,
                            color: AppColors.primary,
                            w: FontWeight.w600)),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      );
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height = 64, this.width});
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
            color: const Color(0xFFEFF2FA),
            borderRadius: BorderRadius.circular(12)),
      );
}

class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.rose, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13.5))),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class EmptyLine extends StatelessWidget {
  const EmptyLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
            child: Text(text,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 14))),
      );
}

/// mm:ss / hh:mm:ss countdown in red; stops at 00:00:00.
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.endsAt, this.style});
  final DateTime endsAt;
  final TextStyle? style;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(
        const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.endsAt.difference(DateTime.now());
    final d = left.isNegative ? Duration.zero : left;
    String two(int n) => n.toString().padLeft(2, '0');
    final text = d.inDays >= 1
        ? '${d.inDays}d ${two(d.inHours % 24)}h'
        : '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    return Text(text,
        style:
            widget.style ?? heading(size: 14, color: AppColors.countdownRed));
  }
}
