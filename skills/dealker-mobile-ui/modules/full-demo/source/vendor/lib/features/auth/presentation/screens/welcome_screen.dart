import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_theme.dart';
import 'package:dealker_vendor/features/auth/presentation/widgets/brand_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      heroFraction: 0.48,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthHeading('Grow your business with Dealkr',
              subtitle:
                  'One app for wholesale, retail, auctions and repairs — all in one place.'),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(PhosphorIconsFill.usersThree, 'B2B deals'),
              _Pill(PhosphorIconsFill.storefront, 'B2C store'),
              _Pill(PhosphorIconsFill.gavel, 'Auctions'),
              _Pill(PhosphorIconsFill.wrench, 'Repairs'),
            ],
          ),
          const SizedBox(height: 24),
          BrandButton(
              label: 'Get started',
              icon: PhosphorIconsBold.rocketLaunch,
              onPressed: () => context.push(Routes.register)),
          const SizedBox(height: 12),
          BrandButton(
              label: 'I already have an account',
              outlined: true,
              onPressed: () => context.push(Routes.login)),
          const SizedBox(height: 16),
          const Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(PhosphorIconsFill.shieldCheck, size: 16, color: Brand.green),
              SizedBox(width: 6),
              Text('Verified sellers · Secure payouts',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Brand.muted)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Brand.cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Brand.yellow.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: Brand.navy),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontFamily: AppTheme.headingFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Brand.navy)),
        ]),
      );
}
