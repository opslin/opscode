import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/core/theme/app_theme.dart';

/// Labelled rounded input used on the register / login forms.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.labelIcon,
    required this.fieldIcon,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.formatters,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.onChanged,
  });

  final String label;
  final IconData labelIcon;
  final IconData fieldIcon;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1.3]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(labelIcon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTheme.headingFont,
                fontWeight: FontWeight.w500,
                fontSize: 14.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          validator: validator,
          autofocus: autofocus,
          onChanged: onChanged,
          textCapitalization: textCapitalization,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.navy),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: AppColors.textMuted, fontWeight: FontWeight.w400),
            prefixIcon:
                Icon(fieldIcon, color: AppColors.textSecondary, size: 24),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
            enabledBorder: border(AppColors.border),
            focusedBorder: border(AppColors.primary, 1.6),
            errorBorder: border(AppColors.error),
            focusedErrorBorder: border(AppColors.error, 1.6),
          ),
        ),
      ],
    );
  }
}
