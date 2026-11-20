import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/features/home/presentation/widgets/tabbed_section_parts.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dealker_app/shared/widgets/dealker_product_card.dart'
    show splitNameAndVariant;

/// Defaults of the `oval_spotlight` section ("Best in Bread & Buns"): an oval
/// cream panel with corner artwork, an elegant title and wide product cards
/// (name + photo + price + Add). Every key is editable in the dashboard.
const Map<String, dynamic> kOvalSpotlightDefaults = <String, dynamic>{
  'title': 'Best in Collection',
  'subtitle': '',
  'title_font': 'serif',
  'art_left_url': '',
  'art_right_url': '',
  'add_label': 'Add',
  'bg_color': '#FFFFFF',
  'oval_start_color': '#FFF3E8',
  'oval_end_color': '#FDE7D6',
  'oval_border_color': '#E2BFA2',
  'title_color': '#8C3F2B',
  'subtitle_color': '#6B4A44',
  'card_start_color': '#FFF9F3',
  'card_end_color': '#FBE3D1',
  'card_border_color': '#E8C3A6',
  'name_color': '#A0706A',
  'price_color': '#2A1A17',
  'accent_color': '#E8175D',
};

String _rupees(double v) => formatRupees(v);

class OvalSpotlightSection extends StatelessWidget {
  const OvalSpotlightSection({
    required this.config,
    required this.products,
    super.key,
  });

  final Map<String, dynamic> config;
  final List<ProductEntity> products;

  static const double _headerH = 150;
  static const double _cardH = 176;
  static const double _arc = 16;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final Color bg = colorFrom(config, 'bg_color', Colors.white);
    final Color titleC = colorFrom(
      config,
      'title_color',
      const Color(0xFF8C3F2B),
    );
    final Color subC = colorFrom(
      config,
      'subtitle_color',
      const Color(0xFF6B4A44),
    );
    final String left = stringFrom(config, 'art_left_url', '');
    final String right = stringFrom(config, 'art_right_url', '');
    final bool serif = stringFrom(config, 'title_font', 'serif') == 'serif';
    final double cardW = (MediaQuery.sizeOf(context).width * 0.44).clamp(
      160.0,
      200.0,
    );
    final double total = _headerH + _cardH + 44;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: bg,
      height: total,
      clipBehavior: Clip.none,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            top: 28,
            bottom: 0,
            child: CustomPaint(
              painter: _OvalPainter(
                start: colorFrom(
                  config,
                  'oval_start_color',
                  const Color(0xFFFFF3E8),
                ),
                end: colorFrom(
                  config,
                  'oval_end_color',
                  const Color(0xFFFDE7D6),
                ),
                border: colorFrom(
                  config,
                  'oval_border_color',
                  const Color(0xFFE2BFA2),
                ),
                arc: _arc,
              ),
            ),
          ),
          if (left.isNotEmpty)
            Positioned(
              left: -4,
              top: 0,
              width: 84,
              height: 80,
              child: AppImage(
                imageUrl: left,
                memCacheWidth: 400,
                memCacheHeight: 400,
                fit: BoxFit.contain,
                alignment: Alignment.topLeft,
                placeholder: const SizedBox.shrink(),
                errorWidget: const SizedBox.shrink(),
              ),
            ),
          if (right.isNotEmpty)
            Positioned(
              right: -4,
              top: 0,
              width: 84,
              height: 80,
              child: AppImage(
                imageUrl: right,
                memCacheWidth: 400,
                memCacheHeight: 400,
                fit: BoxFit.contain,
                alignment: Alignment.topRight,
                placeholder: const SizedBox.shrink(),
                errorWidget: const SizedBox.shrink(),
              ),
            ),
          Positioned(
            left: 76,
            right: 76,
            top: 58,
            child: Column(
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    stringFrom(config, 'title', 'Best in Collection'),
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: serif ? 'Georgia' : 'PlusJakartaSans',
                      fontFamilyFallback: const <String>['serif'],
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: titleC,
                    ),
                  ),
                ),
                if (stringFrom(config, 'subtitle', '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    stringFrom(config, 'subtitle', ''),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: subC,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _headerH,
            height: _cardH + 4,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              physics: const BouncingScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int i) => _OvalCard(
                product: products[i],
                config: config,
                width: cardW,
                height: _cardH,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OvalCard extends StatelessWidget {
  const _OvalCard({
    required this.product,
    required this.config,
    required this.width,
    required this.height,
  });

  final ProductEntity product;
  final Map<String, dynamic> config;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Color nameC = colorFrom(
      config,
      'name_color',
      const Color(0xFFA0706A),
    );
    final Color priceC = colorFrom(
      config,
      'price_color',
      const Color(0xFF2A1A17),
    );
    final Color accent = colorFrom(
      config,
      'accent_color',
      const Color(0xFFE8175D),
    );
    final ({String name, String? variant}) split = splitNameAndVariant(
      product.name,
    );
    final String? option = product.optionLabel?.trim().isNotEmpty == true
        ? product.optionLabel
        : split.variant;
    final String unitLine = <String?>[
      product.unit.trim().isEmpty ? null : '1 ${product.unit.trim()}',
      option == null ? null : '($option)',
    ].whereType<String>().join(' ');
    final String? imageUrl = product.thumbnailUrl?.isNotEmpty == true
        ? product.thumbnailUrl
        : (product.images.isNotEmpty ? product.images.first : null);

    return GestureDetector(
      onTap: () => context.push('/product/${product.id}'),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorFrom(
              config,
              'card_border_color',
              const Color(0xFFE8C3A6),
            ),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              colorFrom(config, 'card_start_color', const Color(0xFFFFF9F3)),
              colorFrom(config, 'card_end_color', const Color(0xFFFBE3D1)),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 11,
                    child: Text(
                      split.name,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: nameC,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 9,
                    child: imageUrl == null
                        ? const SizedBox.shrink()
                        // Modulate: a photo with a white background melts into the
                        // card tint; transparent PNGs are untouched.
                        : ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              Color.lerp(
                                colorFrom(
                                  config,
                                  'card_start_color',
                                  const Color(0xFFFFF9F3),
                                ),
                                colorFrom(
                                  config,
                                  'card_end_color',
                                  const Color(0xFFFBE3D1),
                                ),
                                0.6,
                              )!,
                              BlendMode.modulate,
                            ),
                            child: AppImage(
                              imageUrl: imageUrl,
                              memCacheWidth: 300,
                              memCacheHeight: 300,
                              fit: BoxFit.contain,
                              alignment: Alignment.topCenter,
                              placeholder: const SizedBox.shrink(),
                              errorWidget: const SizedBox.shrink(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (unitLine.isNotEmpty)
                        Text(
                          unitLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: priceC.withValues(alpha: 0.8),
                          ),
                        ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              _rupees(product.effectivePrice),
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: priceC,
                              ),
                            ),
                            if (product.isOnSale) ...<Widget>[
                              const SizedBox(width: 5),
                              Text(
                                _rupees(product.price),
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 10.5,
                                  color: priceC.withValues(alpha: 0.45),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                AddPill(
                  product: product,
                  accent: accent,
                  label: stringFrom(config, 'add_label', 'Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The oval cream panel: arched top and bottom edges, gradient fill, thin outline.
class _OvalPainter extends CustomPainter {
  _OvalPainter({
    required this.start,
    required this.end,
    required this.border,
    required this.arc,
  });

  final Color start;
  final Color end;
  final Color border;
  final double arc;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    // Wider than the box so only the curved top/bottom edges show (an oval
    // that bleeds off the sides, like the reference).
    final double x0 = -w * 0.15;
    final double x1 = w * 1.15;
    final Path path = Path()
      ..moveTo(x0, arc * 2.6)
      ..quadraticBezierTo(w / 2, -arc * 1.9, x1, arc * 2.6)
      ..lineTo(x1, h - arc * 2.6)
      ..quadraticBezierTo(w / 2, h + arc * 1.9, x0, h - arc * 2.6)
      ..close();
    final Rect box = Offset.zero & size;
    canvas
      ..drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[start, end],
          ).createShader(box),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = border,
      );
  }

  @override
  bool shouldRepaint(_OvalPainter old) =>
      old.start != start ||
      old.end != end ||
      old.border != border ||
      old.arc != arc;
}
