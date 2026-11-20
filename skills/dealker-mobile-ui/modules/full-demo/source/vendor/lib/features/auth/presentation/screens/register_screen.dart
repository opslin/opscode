import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_theme.dart';
import 'package:dealker_vendor/core/utils/phone_input.dart';
import 'package:dealker_vendor/core/utils/validators.dart';
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';
import 'package:dealker_vendor/features/auth/presentation/screens/otp_screen.dart';
import 'package:dealker_vendor/features/auth/presentation/widgets/brand_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _business = TextEditingController();
  final _phone = TextEditingController();
  VendorRole _role = VendorRole.vendor;
  bool _agreed = true;
  bool _busy = false;

  @override
  void dispose() {
    _business.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      showAppToast(
          context, 'Please accept the Terms & Privacy Policy to continue.',
          error: true);
      return;
    }
    final phone = indianMobileDigits(_phone.text);
    setState(() => _busy = true);
    try {
      final auth = ref.read(authControllerProvider.notifier);
      auth.saveDraft(RegistrationDraft(
          role: _role, businessName: _business.text.trim(), phone: phone));
      await auth.sendOtp(phone);
      if (!mounted) return;
      context.push(Routes.otp, extra: OtpArgs(phone: phone, registering: true));
    } catch (e) {
      if (mounted) showAppToast(context, failureMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      heroFraction: 0.30,
      onBack: () => context.pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthHeading('Create your account',
                subtitle: 'Start selling on Dealkr in a few minutes.'),
            const SizedBox(height: 18),
            const Text('I am a',
                style: TextStyle(
                    fontFamily: AppTheme.headingFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: Brand.navy)),
            const SizedBox(height: 8),
            Row(children: [
              for (final r in VendorRole.values) ...[
                Expanded(
                    child: _RoleChip(
                        role: r,
                        selected: _role == r,
                        onTap: () => setState(() => _role = r))),
                if (r != VendorRole.values.last) const SizedBox(width: 8),
              ],
            ]),
            const SizedBox(height: 18),
            BrandField(
              label: 'Business name',
              controller: _business,
              icon: PhosphorIconsRegular.storefront,
              hint: 'e.g. Sharma Mobile Store',
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Enter your business name.'
                  : null,
            ),
            const SizedBox(height: 16),
            BrandField(
              label: 'Mobile number',
              controller: _phone,
              prefixText: '+91',
              hint: '98765 43210',
              keyboardType: TextInputType.phone,
              formatters: const [IndianMobileFormatter()],
              validator: Validators.validatePhone,
            ),
            const SizedBox(height: 14),
            Row(children: [
              SizedBox(
                width: 26,
                height: 26,
                child: Checkbox(
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                  activeColor: Brand.navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text.rich(TextSpan(
                  style: TextStyle(fontSize: 14, color: Brand.muted),
                  children: [
                    TextSpan(text: 'I agree to the '),
                    TextSpan(
                        text: 'Terms',
                        style: TextStyle(
                            color: Brand.navy, fontWeight: FontWeight.w700)),
                    TextSpan(text: ' & '),
                    TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                            color: Brand.navy, fontWeight: FontWeight.w700)),
                  ],
                )),
              ),
            ]),
            const SizedBox(height: 20),
            BrandButton(
                label: 'Continue', loading: _busy, onPressed: _continue),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: () => context.pushReplacement(Routes.login),
                child: const Text.rich(TextSpan(
                  style: TextStyle(fontSize: 15, color: Brand.muted),
                  children: [
                    TextSpan(text: 'Already have an account? '),
                    TextSpan(
                        text: 'Log in',
                        style: TextStyle(
                            color: Brand.navy, fontWeight: FontWeight.w800)),
                  ],
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip(
      {required this.role, required this.selected, required this.onTap});
  final VendorRole role;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (role) {
        VendorRole.vendor => PhosphorIconsFill.usersThree,
        VendorRole.retailer => PhosphorIconsFill.storefront,
        VendorRole.repairPartner => PhosphorIconsFill.wrench,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? Brand.cream : const Color(0xFFFBFAF6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? Brand.yellow : Brand.line,
              width: selected ? 2 : 1.4),
        ),
        child: Column(children: [
          Icon(_icon, size: 24, color: selected ? Brand.navy : Brand.muted),
          const SizedBox(height: 6),
          Text(role.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Brand.navy : Brand.muted)),
          Text(role.subtitle,
              style: const TextStyle(fontSize: 11, color: Brand.muted)),
        ]),
      ),
    );
  }
}
