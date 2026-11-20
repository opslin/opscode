import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/features/home/presentation/widgets/tabbed_section_parts.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';

/// Defaults of the `top_brands` section (arched brand cards). Every key is
/// editable in the dashboard theme builder.
const Map<String, dynamic> kTopBrandsDefaults = <String, dynamic>{
  'title': 'Top Brands',
  'bg_color': '#FFFFFF',
  'text_color': '#111111',
  'border_top_color': '#8FCB8A',
  'border_bottom_color': '#3E86A6',
  'fill_top_color': '#FBFFE8',
  'fill_bottom_color': '#DDF7D9',
  'band_color': '#D1F5BD',
  'ornament_color': '#CFE9B8',
};

class _BrandCard {
  const _BrandCard(
    this.name,
    this.logoUrl,
    this.imageUrl,
    this.categoryId,
    this.query,
  );
  final String name;
  final String logoUrl;
  final String imageUrl;
  final String categoryId;
  final String query;
}

List<_BrandCard> _parse(Map<String, dynamic> config) {
  final Object? raw = config['cards'];
  if (raw is! List) return const <_BrandCard>[];
  final List<_BrandCard> out = <_BrandCard>[];
  for (final Object? c in raw) {
    if (c is! Map) continue;
    final String name = '${c['brand_name'] ?? ''}'.trim();
    final String logo = '${c['logo_url'] ?? ''}'.trim();
    final String image = '${c['image_url'] ?? ''}'.trim();
    if (name.isEmpty && logo.isEmpty && image.isEmpty) continue;
    out.add(
      _BrandCard(
        name,
        logo,
        image,
        '${c['category_id'] ?? ''}'.trim(),
        '${c['search_query'] ?? ''}'.trim(),
      ),
    );
  }
  return out;
}

class TopBrandsSection extends StatelessWidget {
  const TopBrandsSection({required this.config, super.key});

  final Map<String, dynamic> config;

  @override
  Widget build(BuildContext context) {
    final List<_BrandCard> cards = _parse(config);
    if (cards.isEmpty) return const SizedBox.shrink();
    final Color bg = colorFrom(config, 'bg_color', Colors.white);
    final Color text = colorFrom(config, 'text_color', const Color(0xFF111111));
    final double w = (MediaQuery.sizeOf(context).width * 0.4).clamp(
      140.0,
      190.0,
    );
    final double h = w * 1.35;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: <Widget>[
                Text(
                  stringFrom(config, 'title', 'Top Brands'),
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DashedDivider(color: text.withValues(alpha: 0.15)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: h + 4,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              physics: const BouncingScrollPhysics(),
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int i) => _ArchCard(
                card: cards[i],
                config: config,
                width: w,
                height: h,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchCard extends StatelessWidget {
  const _ArchCard({
    required this.card,
    required this.config,
    required this.width,
    required this.height,
  });

  final _BrandCard card;
  final Map<String, dynamic> config;
  final double width;
  final double height;

  void _open(BuildContext context) {
    if (card.categoryId.isNotEmpty) {
      context.push('/categories/${card.categoryId}/products');
      return;
    }
    final String q = card.query.isNotEmpty ? card.query : card.name;
    if (q.isNotEmpty) context.push('/search?q=${Uri.encodeQueryComponent(q)}');
  }

  @override
  Widget build(BuildContext context) {
    final Color text = colorFrom(config, 'text_color', const Color(0xFF111111));
    final double bodyTop = height * 0.185;
    final double bandTop = height * 0.805;
    return GestureDetector(
      onTap: () => _open(context),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _ArchPainter(
                  borderTop: colorFrom(
                    config,
                    'border_top_color',
                    const Color(0xFF8FCB8A),
                  ),
                  borderBottom: colorFrom(
                    config,
                    'border_bottom_color',
                    const Color(0xFF3E86A6),
                  ),
                  fillTop: colorFrom(
                    config,
                    'fill_top_color',
                    const Color(0xFFFBFFE8),
                  ),
                  fillBottom: colorFrom(
                    config,
                    'fill_bottom_color',
                    const Color(0xFFDDF7D9),
                  ),
                  band: colorFrom(
                    config,
                    'band_color',
                    const Color(0xFFD1F5BD),
                  ),
                  ornament: colorFrom(
                    config,
                    'ornament_color',
                    const Color(0xFFCFE9B8),
                  ),
                ),
              ),
            ),
            if (card.imageUrl.isNotEmpty)
              Positioned(
                left: width * 0.12,
                right: width * 0.12,
                top: bodyTop + height * 0.07,
                bottom: height - bandTop + height * 0.03,
                child: AppImage(
                  imageUrl: card.imageUrl,
                  memCacheWidth: 500,
                  memCacheHeight: 600,
                  fit: BoxFit.contain,
                  placeholder: const SizedBox.shrink(),
                  errorWidget: const SizedBox.shrink(),
                ),
              ),
            Positioned(
              left: width * 0.12,
              right: width * 0.12,
              top: bandTop + 4,
              bottom: height * 0.03,
              child: Center(
                child: card.logoUrl.isNotEmpty
                    ? AppImage(
                        imageUrl: card.logoUrl,
                        memCacheWidth: 400,
                        memCacheHeight: 200,
                        fit: BoxFit.contain,
                        placeholder: const SizedBox.shrink(),
                        errorWidget: const SizedBox.shrink(),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          card.name,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: text,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchPainter extends CustomPainter {
  _ArchPainter({
    required this.borderTop,
    required this.borderBottom,
    required this.fillTop,
    required this.fillBottom,
    required this.band,
    required this.ornament,
  });

  final Color borderTop;
  final Color borderBottom;
  final Color fillTop;
  final Color fillBottom;
  final Color band;
  final Color ornament;

  Path _path(Size s) {
    final double w = s.width;
    final double h = s.height;
    const double sw = 2.4;
    final double top = h * 0.185;
    final double r = w * 0.14;
    final double x1 = w * 0.17;
    final double x2 = w * 0.83;
    final double f = w * 0.05;
    final double m = sw / 2;
    return Path()
      ..moveTo(m, top + r)
      ..quadraticBezierTo(m, top, m + r, top)
      ..lineTo(x1 - f, top)
      ..cubicTo(
        x1 - f * 0.2,
        top,
        x1,
        top - f * 0.2,
        x1 + w * 0.012,
        top - h * 0.06,
      )
      ..cubicTo(x1 + w * 0.05, top - h * 0.16, w * 0.3, m, w * 0.5, m)
      ..cubicTo(
        w * 0.7,
        m,
        x2 - w * 0.05,
        top - h * 0.16,
        x2 - w * 0.012,
        top - h * 0.06,
      )
      ..cubicTo(x2, top - f * 0.2, x2 + f * 0.2, top, x2 + f, top)
      ..lineTo(w - m - r, top)
      ..quadraticBezierTo(w - m, top, w - m, top + r)
      ..lineTo(w - m, h - m - r)
      ..quadraticBezierTo(w - m, h - m, w - m - r, h - m)
      ..lineTo(m + r, h - m)
      ..quadraticBezierTo(m, h - m, m, h - m - r)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _path(size);
    final Rect box = Offset.zero & size;
    canvas
      ..save()
      ..clipPath(path)
      ..drawRect(
        box,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[fillTop, fillBottom],
          ).createShader(box),
      )
      ..drawRect(
        Rect.fromLTWH(0, size.height * 0.805, size.width, size.height),
        Paint()..color = band,
      );
    // Faint scroll ornament + star in the dome.
    final Paint orn = Paint()
      ..color = ornament
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;
    final double cx = size.width / 2;
    final double cy = size.height * 0.15;
    final double a = size.width * 0.1;
    canvas
      ..drawArc(
        Rect.fromCircle(center: Offset(cx - a * 1.2, cy + a * 0.4), radius: a),
        3.4,
        3.6,
        false,
        orn,
      )
      ..drawArc(
        Rect.fromCircle(center: Offset(cx + a * 1.2, cy + a * 0.4), radius: a),
        -0.3,
        3.6,
        false,
        orn,
      )
      ..restore();
    final Paint star = Paint()..color = borderTop.withValues(alpha: 0.7);
    final double sx = cx;
    final double sy = size.height * 0.075;
    final double sr = size.width * 0.03;
    canvas.drawPath(
      Path()
        ..moveTo(sx, sy - sr * 1.6)
        ..quadraticBezierTo(sx, sy, sx + sr * 1.6, sy)
        ..quadraticBezierTo(sx, sy, sx, sy + sr * 1.6)
        ..quadraticBezierTo(sx, sy, sx - sr * 1.6, sy)
        ..quadraticBezierTo(sx, sy, sx, sy - sr * 1.6)
        ..close(),
      star,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[borderTop, borderBottom],
        ).createShader(box),
    );
  }

  @override
  bool shouldRepaint(_ArchPainter old) =>
      old.borderTop != borderTop ||
      old.borderBottom != borderBottom ||
      old.fillTop != fillTop ||
      old.fillBottom != fillBottom ||
      old.band != band ||
      old.ornament != ornament;
}
