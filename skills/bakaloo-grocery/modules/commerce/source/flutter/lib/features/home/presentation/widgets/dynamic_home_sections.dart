import 'package:bakaloo_flutter_app/demo/storefront.dart';
import 'package:flutter/material.dart';

import 'merchandising_sections.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/theme/section_manifest_model.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/section_registry.dart';

class DynamicHomeSections extends ConsumerWidget {
  const DynamicHomeSections({
    super.key,
    required this.storefront,
    required this.onCategory,
    required this.onProduct,
  });

  final Storefront storefront;
  final ValueChanged<String> onCategory;
  final ValueChanged<ProductEntity> onProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use .select() to avoid rebuilding the full list on unrelated theme changes.
    final int sectionCount = ref.watch(
      activeSectionManifestProvider.select((m) => m.sections.length),
    );

    if (sectionCount == 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final List<SectionManifestEntry> sections = ref.watch(
      activeSectionManifestProvider.select((m) => m.sections),
    );

    // Pass theme down only when sections actually need it; each slot will
    // read the theme itself via ref so it only rebuilds when its own section
    // data changes (not when unrelated theme fields change).
    return SliverList(
      delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
        final SectionManifestEntry entry = sections[index];
        return _DynamicSectionSlot(
          key: ValueKey<String>('${entry.type}_${entry.id}'),
          entry: entry,
          storefront: storefront,
          onCategory: onCategory,
          onProduct: onProduct,
        );
      }, childCount: sections.length),
    );
  }
}

class _DynamicSectionSlot extends ConsumerWidget {
  const _DynamicSectionSlot({
    required this.entry,
    required this.storefront,
    required this.onCategory,
    required this.onProduct,
    super.key,
  });

  final SectionManifestEntry entry;
  final Storefront storefront;
  final ValueChanged<String> onCategory;
  final ValueChanged<ProductEntity> onProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!entry.visible) {
      return const SizedBox.shrink();
    }

    final builder = sectionRegistry[entry.type];
    return RepaintBoundary(
      child:
          builder?.call(entry) ??
          MerchandisingSection(
            entry: entry,
            storefront: storefront,
            onCategory: onCategory,
            onProduct: onProduct,
          ),
    );
  }
}
