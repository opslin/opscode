import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/core/theme/remote_theme_provider.dart';
import 'package:dealker_app/core/theme/section_manifest_provider.dart';
import 'package:dealker_app/features/home/presentation/widgets/section_registry.dart';

/// Mounts the same section renderer used by DynamicHomeSections.
class DemoSectionScreen extends ConsumerWidget {
  const DemoSectionScreen({required this.type, super.key});

  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(sectionManifestProvider('all'));
    final theme = ref.watch(activeTabThemeProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Customer home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          type
              .split('_')
              .map((word) => word[0].toUpperCase() + word.substring(1))
              .join(' '),
        ),
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: OutlinedButton(
            onPressed: () => ref.invalidate(sectionManifestProvider('all')),
            child: const Text('Retry section'),
          ),
        ),
        data: (manifest) {
          final entry = manifest.sections
              .where((entry) => entry.type.value == type)
              .firstOrNull;
          final renderer = entry == null ? null : sectionRegistry[entry.type];
          if (entry == null || renderer == null) {
            return const Center(child: Text('Section is unavailable'));
          }
          return ListView(
            children: [RepaintBoundary(child: renderer(entry, theme, ref))],
          );
        },
      ),
    );
  }
}
