import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_theme.dart';
import 'package:dealker_vendor/shared/widgets/dm_logo.dart';

/// Dealkr brand tokens used by the sign-in, onboarding and location screens
/// (navy + golden yellow + rose, from the logo).
class Brand {
  Brand._();
  static const navy = Color(0xFF001F5F);
  static const navyDeep = Color(0xFF00123A);
  static const yellow = Color(0xFFFFC400);
  static const yellowLight = Color(0xFFFFD84D);
  static const rose = Color(0xFFFF2D55);
  static const cream = Color(0xFFFFF8E7);
  static const ink = Color(0xFF0B1033);
  static const muted = Color(0xFF5B6478);
  static const line = Color(0xFFE6E1D3);
  static const green = Color(0xFF16A34A);
}

/// Hero artwork on top, rounded white card below — the layout of the Dealkr login pages.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.child,
    this.hero = 'assets/auth/login_hero.jpg',
    this.onBack,
    this.heroFraction = 0.42,
  });

  final Widget child;
  final String hero;
  final VoidCallback? onBack;
  final double heroFraction;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final heroH = (size.height * heroFraction).clamp(300.0, 420.0);
    return Scaffold(
      backgroundColor: Brand.cream,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroH + 40,
            child: Image.asset(hero,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.72),
                filterQuality: FilterQuality.high),
          ),
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(
                  height: heroH,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Stack(
                        children: [
                          if (onBack != null)
                            Align(
                              alignment: Alignment.topLeft,
                              child: _RoundIconButton(
                                  icon: PhosphorIconsRegular.arrowLeft,
                                  onTap: onBack!),
                            ),
                          const Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: DmLogo(size: 58))),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x1A001F5F),
                            blurRadius: 30,
                            offset: Offset(0, -8)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(22, 26, 22,
                            22 + MediaQuery.paddingOf(context).bottom),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: Brand.line)),
        elevation: 2,
        shadowColor: Brand.navy.withValues(alpha: 0.2),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: Brand.navy, size: 22)),
        ),
      );
}

/// Screen title + subtitle used inside [AuthShell].
class AuthHeading extends StatelessWidget {
  const AuthHeading(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: AppTheme.headingFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 27,
                  height: 1.15,
                  color: Brand.navy)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 15.5, height: 1.4, color: Brand.muted)),
          ],
        ],
      );
}

/// Primary call to action: golden pill with navy text. [outlined] is the quiet secondary.
class BrandButton extends StatelessWidget {
  const BrandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.outlined = false,
    this.icon,
    this.dark = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final IconData? icon;

  /// Navy fill with white text (used on light-yellow surfaces).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final fg = dark ? Colors.white : Brand.navy;
    return Opacity(
      opacity: onPressed == null && !loading ? 0.5 : 1,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                      color: (dark ? Brand.navy : Brand.yellow)
                          .withValues(alpha: 0.38),
                      blurRadius: 18,
                      offset: const Offset(0, 8)),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: outlined
                  ? null
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: dark
                          ? const [Color(0xFF0A3384), Brand.navy]
                          : const [Brand.yellowLight, Brand.yellow]),
              color: outlined ? Colors.white : null,
              borderRadius: BorderRadius.circular(28),
              border: outlined
                  ? Border.all(
                      color: Brand.navy.withValues(alpha: 0.25), width: 1.5)
                  : null,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: enabled ? onPressed : null,
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: outlined ? Brand.navy : fg))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon,
                                color: outlined ? Brand.navy : fg, size: 21),
                            const SizedBox(width: 9),
                          ],
                          Text(label,
                              style: TextStyle(
                                  fontFamily: AppTheme.headingFont,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17.5,
                                  color: outlined ? Brand.navy : fg)),
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

/// Rounded text field with a small label, optional "+91" style prefix.
class BrandField extends StatelessWidget {
  const BrandField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.prefixText,
    this.keyboardType,
    this.formatters,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final String? prefixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1.4]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(label,
              style: const TextStyle(
                  fontFamily: AppTheme.headingFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: Brand.navy)),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          validator: validator,
          autofocus: autofocus,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          cursorColor: Brand.navy,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: Brand.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: Color(0xFFA3AABB), fontWeight: FontWeight.w500),
            prefixIcon: prefixText != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 16, right: 10),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(prefixText!,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Brand.navy)),
                      const SizedBox(width: 10),
                      Container(width: 1.4, height: 24, color: Brand.line),
                    ]),
                  )
                : (icon != null
                    ? Padding(
                        padding: const EdgeInsets.only(left: 16, right: 10),
                        child: Icon(icon, color: Brand.muted, size: 22))
                    : null),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: const Color(0xFFFBFAF6),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            enabledBorder: border(Brand.line),
            focusedBorder: border(Brand.navy, 1.8),
            errorBorder: border(Brand.rose),
            focusedErrorBorder: border(Brand.rose, 1.8),
          ),
        ),
      ],
    );
  }
}

/// "1 Store · 2 Location · 3 KYC" progress shown through the onboarding pages.
class OnboardingSteps extends StatelessWidget {
  const OnboardingSteps({super.key, required this.current});

  /// 0-based index of the active step.
  final int current;

  static const _labels = ['Store', 'Location', 'KYC'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          _Step(index: i, label: _labels[i], current: current),
          if (i < _labels.length - 1)
            Expanded(
              child: Container(
                height: 2.5,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: i < current ? Brand.yellow : Brand.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(
      {required this.index, required this.label, required this.current});
  final int index;
  final String label;
  final int current;

  @override
  Widget build(BuildContext context) {
    final done = index < current;
    final active = index == current;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done || active ? Brand.yellow : Colors.white,
          border: Border.all(
              color: done || active ? Brand.yellow : Brand.line, width: 1.6),
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: Brand.navy)
              : Text('${index + 1}',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: active ? Brand.navy : Brand.muted)),
        ),
      ),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active || done ? Brand.navy : Brand.muted)),
    ]);
  }
}
