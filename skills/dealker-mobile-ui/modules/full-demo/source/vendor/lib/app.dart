import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/realtime/live_service.dart';
import 'package:dealker_vendor/core/theme/app_theme.dart';
import 'package:dealker_vendor/routing/app_router.dart';
import 'package:dealker_vendor/shared/widgets/live_banner.dart';

class VendorApp extends ConsumerWidget {
  const VendorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(liveServiceProvider); // keeps the live connection alive while signed in
    return MaterialApp.router(
      title: 'DM Vendor Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => LiveBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
