import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/features/exchange/data/exchange_models.dart';
import 'package:dealker_app/features/exchange/presentation/exchange_art.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dealker_app/shared/widgets/marketplace_product_box.dart';

const _navy = Color(0xFF001F5F);
const _navyLight = Color(0xFF0B3C9E);

/// The offer's types are already scoped to this product's exchange programme.
/// Keep that list authoritative, including categories added by the dashboard.
class ProductExchangeCard extends StatefulWidget {
  const ProductExchangeCard({
    required this.product,
    required this.offer,
    required this.onCheckValue,
    super.key,
  });

  final ProductEntity product;
  final ExchangeOffer offer;
  final ValueChanged<String?> onCheckValue;

  @override
  State<ProductExchangeCard> createState() => _ProductExchangeCardState();
}

class _ProductExchangeCardState extends State<ProductExchangeCard> {
  String? _selectedKey;

  @override
  void didUpdateWidget(covariant ProductExchangeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) _selectedKey = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.offer.eligible) return const SizedBox.shrink();
    final types = widget.offer.types;
    final selected = types.where((t) => t.key == _selectedKey).firstOrNull ??
        types.firstOrNull;
    // An unknown valuation must not inherit another device type's maximum.
    final value = selected?.upTo ?? widget.offer.maxValue;

    final hasValue = value > 0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navyLight, _navy],
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      RT.gold.withValues(alpha: 0.32),
                      RT.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _OfferChip(),
                            const SizedBox(height: 8),
                            Text(
                              hasValue
                                  ? 'Exchange your old device & get up to'
                                  : 'Exchange your old device & discover its value',
                              style: _text(
                                12,
                                color: Colors.white.withValues(alpha: 0.78),
                                weight: FontWeight.w600,
                              ),
                            ),
                            if (hasValue) ...[
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  MarketplaceProductBox.inr(value),
                                  style: _text(30, color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _DeviceTile(
                        product: widget.product,
                        type: selected,
                      ),
                    ],
                  ),
                  if (types.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final type in types)
                          _DevicePill(
                            type: type,
                            selected: type.key == selected?.key,
                            onTap: () =>
                                setState(() => _selectedKey = type.key),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Material(
                    color: RT.gold,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => widget.onCheckValue(selected?.key),
                      child: SizedBox(
                        height: 46,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Check My Exchange Value',
                                  style: _text(14, weight: FontWeight.w800),
                                ),
                              ),
                              Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                  color: _navy,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      _TrustItem('assets/cart/verified.png', 'Safe & Secure'),
                      _TrustItem('assets/cart/bolt.png', 'Instant Value'),
                      _TrustItem(null, 'Hassle-Free'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _text(
  double size, {
  Color color = _navy,
  FontWeight weight = FontWeight.w900,
}) =>
    TextStyle(
      fontFamily: RT.head,
      fontSize: size,
      height: 1.2,
      fontWeight: weight,
      color: color,
    );

class _OfferChip extends StatelessWidget {
  const _OfferChip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
        decoration: BoxDecoration(
          color: RT.gold,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsFill.crown, color: _navy, size: 12),
            const SizedBox(width: 4),
            Flexible(
                child: Text('Best Exchange Value',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(10, weight: FontWeight.w800))),
          ],
        ),
      );
}

/// White tile holding the device art; the product's own photo is used only
/// when it matches the selected device type.
class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.product, required this.type});
  final ProductEntity product;
  final ExchangeType? type;

  String? _productImage(ExchangeType type) {
    // A product photo only illustrates its own device type, never another pill.
    final category =
        '${product.categoryName ?? ''} ${product.name}'.toLowerCase();
    final tablet =
        RegExp(r'\b(ipad|tablet|tab)\b').hasMatch(product.name.toLowerCase());
    final matches = switch (type.icon) {
      'phone' => !tablet && RegExp(r'phone|mobile|galaxy').hasMatch(category),
      'tablet' => tablet || category.trim() == 'tablets',
      'laptop' => RegExp(r'laptop|macbook|notebook').hasMatch(category),
      _ => category.contains(type.label.toLowerCase()) ||
          category.contains(type.key.toLowerCase()),
    };
    if (!matches) return null;
    return product.images.where((url) => url.trim().isNotEmpty).firstOrNull ??
        product.thumbnailUrl;
  }

  @override
  Widget build(BuildContext context) {
    final type = this.type;
    final art = type == null ? kExSwap : exchangeTypeArt(type.icon);
    final fallback = ExArt(art, size: 66);
    final url = type == null ? null : _productImage(type);
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 84,
            height: 84,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFDCE7FF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(type?.key ?? 'none'),
                child: url == null || url.isEmpty
                    ? fallback
                    : AppImage(
                        imageUrl: url,
                        memCacheWidth: 240,
                        memCacheHeight: 240,
                        fit: BoxFit.contain,
                        placeholder: fallback,
                        errorWidget: fallback,
                      ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 30,
              height: 30,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: RT.gold,
                shape: BoxShape.circle,
                border: Border.all(color: _navy, width: 2),
              ),
              child: const ExArt(kExSwap, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevicePill extends StatelessWidget {
  const _DevicePill({
    required this.type,
    required this.selected,
    required this.onTap,
  });
  final ExchangeType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type.icon) {
      'phone' => Icons.smartphone_rounded,
      'tablet' => Icons.tablet_mac_rounded,
      'laptop' => Icons.laptop_mac_rounded,
      'headphones' => Icons.headphones_rounded,
      'earbuds' => Icons.earbuds_rounded,
      'watch' => Icons.watch_rounded,
      'speaker' => Icons.speaker_rounded,
      'camera' => Icons.camera_alt_rounded,
      'console' => Icons.sports_esports_rounded,
      _ => Icons.devices_other_rounded,
    };
    final label = type.icon == 'phone' ? 'Mobile' : type.label;
    final fg = selected ? _navy : Colors.white;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
        shape: StadiumBorder(
          side: BorderSide(
            color:
                selected ? Colors.white : Colors.white.withValues(alpha: 0.28),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: _text(13, color: fg, weight: FontWeight.w700),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle_rounded,
                        size: 16, color: _navy),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem(this.asset, this.label);
  final String? asset;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (asset != null)
              Image.asset(asset!, width: 16, height: 16)
            else
              const Icon(PhosphorIconsFill.handshake, color: RT.gold, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(
                  10,
                  color: Colors.white.withValues(alpha: 0.85),
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}
