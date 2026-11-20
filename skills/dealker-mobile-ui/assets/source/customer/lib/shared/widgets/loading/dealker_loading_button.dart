import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/app_colors.dart';

enum DealkerButtonStatus { idle, loading, success }

/// Brand button with built-in loading + success states, so a press shows
/// feedback inside the button instead of freezing the screen.
class DealkerLoadingButton extends StatelessWidget {
  const DealkerLoadingButton({
    required this.label,
    required this.onPressed,
    this.status = DealkerButtonStatus.idle,
    this.loadingLabel,
    this.successLabel,
    this.yellow = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final DealkerButtonStatus status;
  final String? loadingLabel;
  final String? successLabel;

  /// Yellow CTA (navy text) instead of navy (white text).
  final bool yellow;
  final PhosphorIconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color bg = yellow ? AppColors.brandYellow : AppColors.brandNavy;
    final Color fg = yellow ? AppColors.brandNavy : Colors.white;
    final bool busy = status == DealkerButtonStatus.loading;
    final bool ok = status == DealkerButtonStatus.success;

    final Widget child = switch (status) {
      DealkerButtonStatus.idle => Row(
          key: const ValueKey<String>('idle'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              PhosphorIcon(icon!, size: 18, color: fg),
              const SizedBox(width: 8),
            ],
            Text(label, style: _style(fg)),
          ],
        ),
      DealkerButtonStatus.loading => Row(
          key: const ValueKey<String>('loading'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DealkerBounceDots(color: fg),
            if (loadingLabel != null) ...<Widget>[
              const SizedBox(width: 12),
              Text(loadingLabel!, style: _style(fg)),
            ],
          ],
        ),
      DealkerButtonStatus.success => Row(
          key: const ValueKey<String>('success'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              builder: (context, v, _) => Transform.scale(
                scale: v,
                child: Icon(Icons.check_circle_rounded, color: fg, size: 22),
              ),
            ),
            if (successLabel != null) ...<Widget>[
              const SizedBox(width: 8),
              Text(successLabel!, style: _style(fg)),
            ],
          ],
        ),
    };

    return AnimatedScale(
      scale: busy ? 0.985 : 1,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: ok ? const Color(0xFF1E9E55) : bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: (busy || ok) ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 54,
            width: double.infinity,
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutBack,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _style(Color c) => TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        color: c,
      );
}

/// Three bouncing dots — drop-in replacement for a spinner inside a button.
class DealkerBounceDots extends StatefulWidget {
  const DealkerBounceDots({required this.color, super.key});

  final Color color;

  @override
  State<DealkerBounceDots> createState() => _DealkerBounceDotsState();
}

class _DealkerBounceDotsState extends State<DealkerBounceDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(3, (int i) {
          final double p = (_c.value - i * 0.15) % 1;
          final double up = p < 0.5 ? math.sin(p * 2 * math.pi) : 0;
          return Transform.translate(
            offset: Offset(0, -up * 7),
            child: Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.6 + 0.4 * up),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}
