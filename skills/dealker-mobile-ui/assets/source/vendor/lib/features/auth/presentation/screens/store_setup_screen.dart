import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_theme.dart';
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';
import 'package:dealker_vendor/features/auth/presentation/widgets/brand_ui.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// First sign-in with a number that has no vendor account yet: create the store, then the Business
/// Profile / location / KYC steps follow from the home page and an admin approves the application.
class StoreSetupScreen extends ConsumerStatefulWidget {
  const StoreSetupScreen({super.key});

  @override
  ConsumerState<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends ConsumerState<StoreSetupScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
      text: ref.read(authControllerProvider).draft?.businessName ?? '');
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .registerVendor(name: _name.text.trim(), email: _email.text.trim());
      // The session now has a vendor id, so the home page rebuilds into the dashboard.
    } catch (e) {
      if (mounted) showAppToast(context, failureMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OnboardingSteps(current: 0),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: AspectRatio(
                    aspectRatio: 1.9,
                    child: Image.asset('assets/auth/store_setup.jpg',
                        fit: BoxFit.cover, alignment: Alignment.center),
                  ),
                ),
                const SizedBox(height: 20),
                const AuthHeading('Set up your store',
                    subtitle:
                        'Your number is verified. Tell us about your business — next you will pin your shop on the map and upload KYC for approval.'),
                const SizedBox(height: 20),
                BrandField(
                  label: 'Store / business name',
                  controller: _name,
                  icon: PhosphorIconsRegular.storefront,
                  hint: 'e.g. Sharma Mobile Store',
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v ?? '').trim().length < 2
                      ? 'Enter your store name.'
                      : null,
                ),
                const SizedBox(height: 16),
                BrandField(
                  label: 'Business email',
                  controller: _email,
                  icon: PhosphorIconsRegular.envelopeSimple,
                  hint: 'you@business.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch((v ?? '').trim())
                      ? null
                      : 'Enter a valid email.',
                  onSubmitted: (_) => _create(),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Brand.cream,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(children: [
                    Icon(PhosphorIconsFill.info, size: 18, color: Brand.navy),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          'Approval usually takes 1–2 working days after you submit KYC.',
                          style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 13,
                              color: Brand.navy)),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                BrandButton(
                    label: 'Create my store',
                    loading: _busy,
                    onPressed: _create),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () =>
                            ref.read(authControllerProvider.notifier).logout(),
                    child: const Text('Use a different number',
                        style: TextStyle(
                            color: Brand.muted, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
