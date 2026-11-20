import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/products/domain/entities/product_entity.dart';
import 'preview/customer_preview.dart';
import 'preview/fixtures.dart';
import 'preview/store_state.dart';
import 'preview/vendor_preview.dart';
import 'vendor/routing/route_names.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = jsonDecode(
    await rootBundle.loadString('assets/preview.json'),
  ) as Map<String, dynamic>;
  runApp(ProviderScope(child: PreviewApp(brand: config['brand'] as String)));
}

class PreviewApp extends StatefulWidget {
  const PreviewApp({super.key, required this.brand});

  final String brand;

  @override
  State<PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<PreviewApp> {
  late final _router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const CustomerPreview()),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const VendorPreview(),
      ),
      GoRoute(
        path: Routes.wholesaleCart,
        builder: (context, state) => const VendorCartPreview(),
      ),
      GoRoute(
        path: Routes.wholesale,
        builder: (context, state) => const VendorMarketplace(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const CustomerCatalog(),
      ),
      GoRoute(
        path: '/customer-cart',
        builder: (context, state) => const CustomerCart(),
      ),
      GoRoute(
        path: '/categories/:id/products',
        builder: (context, state) =>
            CustomerCatalog(category: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) => ProductPreview(
          product: catalog
              .where((p) => p.id == state.pathParameters['id'])
              .firstOrNull,
        ),
      ),
    ],
    errorBuilder: (context, state) => PreviewDestination(path: state.uri.path),
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (context, _) => MaterialApp.router(
      title: widget.brand,
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final width = media.size.width.clamp(0.0, 460.0);
        return PreviewBrand(
          brand: widget.brand,
          child: ColoredBox(
            color: const Color(0xFFEAEDF8),
            child: Center(
              child: SizedBox(
                height: media.size.height,
                width: width,
                child: MediaQuery(
                  data: media.copyWith(size: Size(width, media.size.height)),
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class ProductPreview extends StatelessWidget {
  const ProductPreview({super.key, required this.product});

  final ProductEntity? product;

  @override
  Widget build(BuildContext context) {
    final item = product;
    return Scaffold(
      appBar: AppBar(title: const Text('Product details')),
      body: item == null
          ? const Center(child: Text('Product unavailable'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Image.asset(
                  item.thumbnailUrl!,
                  height: 184,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 18),
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '₹${item.effectivePrice.toStringAsFixed(0)} · ${item.soldBy}',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push('/customer-cart'),
                  child: const Text('View cart'),
                ),
              ],
            ),
    );
  }
}

class PreviewDestination extends StatelessWidget {
  const PreviewDestination({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final title = path
        .split('/')
        .where((part) => part.isNotEmpty)
        .join(' / ')
        .replaceAll('-', ' ');
    return Scaffold(
      appBar: AppBar(title: Text(title.isEmpty ? 'Screen preview' : title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.widgets_outlined, size: 42),
              const SizedBox(height: 12),
              const Text(
                'Find this screen in the UI kit’s source index.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(Routes.home),
                child: const Text('Vendor home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
