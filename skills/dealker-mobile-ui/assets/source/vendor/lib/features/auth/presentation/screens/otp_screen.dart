import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:pinput/pinput.dart';

import 'package:dealker_vendor/core/constants/app_constants.dart';
import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/core/theme/app_theme.dart';
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';
import 'package:dealker_vendor/features/auth/presentation/widgets/brand_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/shared/widgets/gradient_button.dart';
import 'package:dealker_vendor/shared/widgets/soft_background.dart';

class OtpArgs {
  const OtpArgs({required this.phone, required this.registering});
  final String phone;
  final bool registering;
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.args});
  final OtpArgs args;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _pin = TextEditingController();
  Timer? _timer;
  int _left = AppConstants.otpResendSeconds;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pin.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _left = AppConstants.otpResendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
      }
      if (mounted) setState(() => _left = (_left - 1).clamp(0, 999));
    });
  }

  Future<void> _verify() async {
    if (_pin.text.length != AppConstants.otpLength || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(widget.args.phone, _pin.text);
      if (mounted) context.go(Routes.home);
    } catch (e) {
      if (mounted) {
        _pin.clear();
        showAppToast(context, failureMessage(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref
          .read(authControllerProvider.notifier)
          .sendOtp(widget.args.phone);
      if (!mounted) return;
      _startTimer();
      showAppToast(context, 'A new OTP has been sent.');
    } catch (e) {
      if (mounted) showAppToast(context, failureMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = PinTheme(
      width: 50,
      height: 58,
      textStyle: const TextStyle(
          fontSize: 23, fontWeight: FontWeight.w800, color: Brand.navy),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAF6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Brand.line, width: 1.4),
      ),
    );
    return AuthShell(
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthHeading(
              widget.args.registering ? 'Verify your number' : 'Enter the code',
              subtitle: 'We sent a 6-digit code to +91 ${widget.args.phone}'),
          const SizedBox(height: 24),
          Center(
            child: Pinput(
              length: AppConstants.otpLength,
              controller: _pin,
              autofocus: true,
              defaultPinTheme: theme,
              focusedPinTheme: theme.copyWith(
                decoration: theme.decoration!.copyWith(
                    color: Colors.white,
                    border: Border.all(color: Brand.navy, width: 1.9)),
              ),
              submittedPinTheme: theme.copyWith(
                decoration: theme.decoration!.copyWith(
                    color: Brand.cream,
                    border: Border.all(color: Brand.yellow, width: 1.6)),
              ),
              onCompleted: (_) => _verify(),
            ),
          ),
          const SizedBox(height: 24),
          BrandButton(
              label: 'Verify & continue',
              loading: _busy,
              onPressed:
                  _pin.text.length == AppConstants.otpLength ? _verify : null),
          const SizedBox(height: 18),
          Center(
            child: _left > 0
                ? Text('Resend code in 0:${_left.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Brand.muted, fontSize: 15))
                : TextButton(
                    onPressed: _resend,
                    child: const Text('Resend code',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            color: Brand.navy)),
                  ),
          ),
        ],
      ),
    );
  }
}
