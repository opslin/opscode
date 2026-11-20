import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_vendor/core/utils/phone_input.dart';
import 'package:dealker_vendor/core/utils/validators.dart';
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';
import 'package:dealker_vendor/features/auth/presentation/screens/otp_screen.dart';
import 'package:dealker_vendor/features/auth/presentation/widgets/brand_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = indianMobileDigits(_phone.text);
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).sendOtp(phone);
      if (!mounted) return;
      context.push(Routes.otp,
          extra: OtpArgs(phone: phone, registering: false));
    } catch (e) {
      if (mounted) showAppToast(context, failureMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      onBack: () => context.pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthHeading('Welcome back',
                subtitle: 'Log in with your registered mobile number.'),
            const SizedBox(height: 22),
            BrandField(
              label: 'Mobile number',
              controller: _phone,
              prefixText: '+91',
              hint: '98765 43210',
              keyboardType: TextInputType.phone,
              autofocus: false,
              formatters: const [IndianMobileFormatter()],
              validator: Validators.validatePhone,
              onSubmitted: (_) => _continue(),
            ),
            const SizedBox(height: 22),
            BrandButton(
                label: 'Send OTP', loading: _busy, onPressed: _continue),
            const SizedBox(height: 18),
            Center(
              child: GestureDetector(
                onTap: () => context.pushReplacement(Routes.register),
                child: const Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 15, color: Brand.muted),
                    children: [
                      TextSpan(text: 'New to Dealkr? '),
                      TextSpan(
                          text: 'Create an account',
                          style: TextStyle(
                              color: Brand.navy, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
