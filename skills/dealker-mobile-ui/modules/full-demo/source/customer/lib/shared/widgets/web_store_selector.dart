import 'package:flutter/material.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/models/store_model.dart';
import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';

/// Displays the actual stores configured by the marketplace dashboard.
class WebStoreSelector extends StatelessWidget {
  const WebStoreSelector({
    required this.stores,
    required this.selectedId,
    required this.onSelect,
    super.key,
  });

  final List<StoreModel> stores;
  final String selectedId;
  final ValueChanged<StoreModel> onSelect;

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Shop by store',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 4 : 2;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final store in stores)
              SizedBox(
                  width: width,
                  height: 90,
                  child: _StoreTile(
                      store: store,
                      selected: store.id == selectedId,
                      onTap: () => onSelect(store))),
          ]);
        }),
      ]),
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile(
      {required this.store, required this.selected, required this.onTap});
  final StoreModel store;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = ApiConstants.resolveMediaUrl(store.iconUrl);
    const fallback = Icon(Icons.storefront_outlined,
        size: 28, color: AppColors.textSecondary);
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? AppColors.accentYellowLight : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected
                      ? AppColors.accentYellowDark
                      : AppColors.borderLight),
            ),
            child: Row(children: [
              SizedBox(
                  width: 48,
                  height: 48,
                  child: imageUrl == null
                      ? fallback
                      : AppImage(
                          imageUrl: imageUrl,
                          memCacheWidth: 160,
                          memCacheHeight: 160,
                          fit: BoxFit.contain,
                          errorWidget: fallback)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(store.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              Icon(selected ? Icons.check_circle : Icons.chevron_right,
                  size: 20,
                  color: selected ? AppColors.accentYellowDark : null),
            ]),
          ),
        ),
      ),
    );
  }
}
