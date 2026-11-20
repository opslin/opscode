import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/core/theme/app_theme.dart';

/// Primary CTA (gradient pill) and its outlined secondary variant.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.showArrow = true,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showArrow;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final fg = outlined ? AppColors.navy : Colors.white;
    return Opacity(
      opacity: onPressed == null && !loading ? 0.55 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                    color: AppColors.brandIndigo.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: outlined ? null : AppColors.brandGradient,
              color: outlined ? Colors.white : null,
              borderRadius: BorderRadius.circular(27),
              border: outlined
                  ? Border.all(color: AppColors.border, width: 1.4)
                  : null,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(27),
              onTap: enabled ? onPressed : null,
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: fg),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontFamily: AppTheme.headingFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: fg,
                            ),
                          ),
                          if (showArrow) ...[
                            const SizedBox(width: 10),
                            Icon(PhosphorIconsRegular.arrowRight,
                                color: fg, size: 20),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
