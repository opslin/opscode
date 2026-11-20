import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/models/store_model.dart';
import 'package:dealker_app/core/providers/store_provider.dart';
import 'package:dealker_app/core/theme/remote_theme_model.dart';
import 'package:dealker_app/core/theme/remote_theme_provider.dart';
import 'package:dealker_app/core/theme/store_tab_palette.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';

/// Palette of the currently selected store tab (by its position in the list).
final Provider<StoreTabPalette> selectedStorePaletteProvider =
    Provider<StoreTabPalette>((Ref ref) {
  final List<StoreModel> stores =
      ref.watch(storesProvider).asData?.value ?? const <StoreModel>[];
  final String selectedId = ref.watch(selectedStoreProvider).id;
  final int index = stores.indexWhere((StoreModel s) => s.id == selectedId);
  final HomeLookTheme look = ref.watch(
    activeTabThemeProvider.select((RemoteTheme t) => t.sections.homeLook),
  );
  return StoreTabPalette.fromLook(look, index);
});

/// Cross-fades [builder]'s palette whenever the selected store changes, so
/// every part of the header that uses it fades in step with the tab slide.
class StorePaletteScope extends ConsumerWidget {
  const StorePaletteScope({super.key, required this.builder, this.child});

  static const Duration duration = Duration(milliseconds: 420);

  final Widget Function(
    BuildContext context,
    StoreTabPalette palette,
    Widget? child,
  ) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StoreTabPalette target = ref.watch(selectedStorePaletteProvider);
    return TweenAnimationBuilder<StoreTabPalette>(
      tween: StoreTabPaletteTween(end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (BuildContext context, StoreTabPalette palette, Widget? c) =>
          builder(context, palette, c),
    );
  }
}

/// Top-of-home store switcher: a row of "folder" tabs. The selected tab is a
/// raised, outlined shape with curved shoulders that slides between tabs; its
/// icon pops up and its label turns bold. Data: `GET /theme/stores`.
class StoreTilesRow extends ConsumerWidget {
  const StoreTilesRow({super.key, required this.palette});

  final StoreTabPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<StoreModel>> stores = ref.watch(storesProvider);
    final String selectedId = ref.watch(selectedStoreProvider).id;

    return stores.when(
      data: (List<StoreModel> items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final int selected = math.max(
          0,
          items.indexWhere((StoreModel s) => s.id == selectedId),
        );
        return _StoreTabBar(
          stores: items,
          selectedIndex: selected,
          palette: palette,
          onSelect: (StoreModel store) {
            HapticFeedback.selectionClick();
            if (store.id == selectedId) return;
            ref.read(selectedStoreProvider.notifier).select(store);
            ref.read(selectedCategoryIdProvider.notifier).select('');
          },
        );
      },
      loading: () => const SizedBox(height: _StoreTabBar.height),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _StoreTabBar extends StatefulWidget {
  const _StoreTabBar({
    required this.stores,
    required this.selectedIndex,
    required this.palette,
    required this.onSelect,
  });

  // Measured from the reference: 4pt above the tabs + 73pt tabs.
  static const double height = 77;

  /// Side margin of the tab row; tabs share the rest evenly.
  static const double margin = 8;

  final List<StoreModel> stores;
  final int selectedIndex;
  final StoreTabPalette palette;
  final ValueChanged<StoreModel> onSelect;

  @override
  State<_StoreTabBar> createState() => _StoreTabBarState();
}

class _StoreTabBarState extends State<_StoreTabBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _pos;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _from = widget.selectedIndex.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _pos = AlwaysStoppedAnimation<double>(_from);
  }

  @override
  void didUpdateWidget(_StoreTabBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      // Start from wherever the indicator currently is so quick taps chain
      // smoothly instead of snapping back.
      final double start = _pos.value;
      final double end = widget.selectedIndex.toDouble();
      _pos = Tween<double>(begin: start, end: end).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final StoreTabPalette p = widget.palette;
    final int n = widget.stores.length;
    return SizedBox(
      height: _StoreTabBar.height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double tabW = (c.maxWidth - 2 * _StoreTabBar.margin) / n;
          return AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, _) {
              final double pos = _pos.value;
              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TabShapePainter(
                        pos: pos,
                        count: n,
                        margin: _StoreTabBar.margin,
                        palette: p,
                      ),
                    ),
                  ),
                  for (int i = 0; i < n; i++)
                    Positioned(
                      left: _StoreTabBar.margin + i * tabW,
                      width: tabW,
                      top: 0,
                      bottom: 0,
                      child: _TabItem(
                        store: widget.stores[i],
                        // 1 when the indicator is exactly on this tab,
                        // fading to 0 as it moves a full tab away.
                        t: (1 - (pos - i).abs()).clamp(0.0, 1.0),
                        palette: p,
                        onTap: () => widget.onSelect(widget.stores[i]),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.store,
    required this.t,
    required this.palette,
    required this.onTap,
  });

  final StoreModel store;
  final double t;
  final StoreTabPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Icon pops up (with a small overshoot) as the tab becomes active.
    final double scale = 1 + 0.2 * Curves.easeOutBack.transform(t);
    final double lift = -4 * t;
    final Color labelColor = Color.lerp(
      palette.onBackgroundMuted,
      palette.onBackground,
      t,
    )!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Transform.translate(
              offset: Offset(0, lift),
              child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: store.iconUrl == null
                      ? const SizedBox.shrink()
                      : AppImage(
                          imageUrl:
                              ApiConstants.resolveMediaUrl(store.iconUrl) ??
                                  store.iconUrl!,
                          memCacheWidth: 200,
                          memCacheHeight: 200,
                          fit: BoxFit.contain,
                          placeholder: const SizedBox.shrink(),
                          errorWidget: const SizedBox.shrink(),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              store.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                height: 1.1,
                fontWeight: t > 0.5 ? FontWeight.w700 : FontWeight.w500,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the tabs as layered folder tabs, measured from the reference video:
/// trapezoids (sides lean 0.21 of the height, 14pt top corners) whose bottoms
/// overlap their neighbours. Resting tabs are stacked so the one nearer the
/// selected tab sits in front, which leaves each tab's far edge lit and its
/// near edge hidden. The raised tab at fractional index [pos] is drawn last
/// with a small concave foot and melts into the panel below.
///
/// Outlines fade and thin towards the bottom like the reference: the raised
/// tab's edge goes 100% -> ~75% halfway -> ~35% near the foot -> 0, and is
/// ~1.5pt at the top tapering to ~0.8pt.
class _TabShapePainter extends CustomPainter {
  _TabShapePainter({
    required this.pos,
    required this.count,
    required this.margin,
    required this.palette,
  });

  final double pos;
  final int count;
  final double margin;
  final StoreTabPalette palette;

  static const double _top = 4;
  static const double _lean = 0.21;
  static const double _radius = 14;
  static const double _foot = 7;

  /// Half the bottom width as a share of the tab pitch (157px bottom on a
  /// 138px pitch in the reference), so neighbouring bottoms overlap.
  static const double _halfBottom = 0.57;

  /// Open outline (no bottom edge) of the tab centred at [cx].
  Path _outline(double cx, double half, double bottom, {required double foot}) {
    final double h = bottom - _top;
    final double s = h * _lean;
    const double r = _radius;
    final double x0 = cx - half;
    final double x1 = cx + half;
    final Path p = Path();
    if (foot > 0) {
      p
        ..moveTo(x0 - foot, bottom)
        ..quadraticBezierTo(
          x0 + foot * 0.1,
          bottom,
          x0 + s * foot / h,
          bottom - foot,
        );
    } else {
      p.moveTo(x0, bottom);
    }
    p
      ..lineTo(x0 + s * (h - r) / h, _top + r)
      ..quadraticBezierTo(x0 + s, _top, x0 + s + r, _top)
      ..lineTo(x1 - s - r, _top)
      ..quadraticBezierTo(x1 - s, _top, x1 - s * (h - r) / h, _top + r);
    if (foot > 0) {
      p
        ..lineTo(x1 - s * foot / h, bottom - foot)
        ..quadraticBezierTo(x1 - foot * 0.1, bottom, x1 + foot, bottom);
    } else {
      p.lineTo(x1, bottom);
    }
    return p;
  }

  /// Top edge + far side of a resting tab (the side away from the raised
  /// tab). [right] = the far side is on the right.
  Path _farEdge(double cx, double half, double bottom, {required bool right}) {
    final double h = bottom - _top;
    final double s = h * _lean;
    const double r = _radius;
    final double dir = right ? 1 : -1;
    final double near = cx - dir * (half - s - r);
    final double far = cx + dir * half;
    return Path()
      ..moveTo(near, _top)
      ..lineTo(far - dir * (s + r), _top)
      ..quadraticBezierTo(
        far - dir * s,
        _top,
        far - dir * s * (h - r) / h,
        _top + r,
      )
      ..lineTo(far, bottom);
  }

  /// Vertical fade shader for an outline: [alphas] at [stops] (0 = top).
  Shader _fade(
    Color c,
    double bottom,
    List<double> alphas,
    List<double> stops,
  ) =>
      LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[for (final double a in alphas) c.withValues(alpha: a)],
        stops: stops,
      ).createShader(Rect.fromLTRB(0, _top, 1, bottom));

  /// Two passes give the taper: a thin line along the whole edge plus a
  /// wider one that only shows near the top.
  void _strokeTapered(
    Canvas canvas,
    Path path,
    Color color,
    double bottom, {
    required double strength,
  }) {
    canvas
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..strokeJoin = StrokeJoin.round
          ..shader = _fade(
            color,
            bottom,
            <double>[
              1,
              0.85,
              0.75,
              0.5,
              0.25,
              0.1,
              0,
            ].map((double a) => a * strength).toList(),
            const <double>[0, 0.1, 0.45, 0.7, 0.85, 0.95, 1],
          ),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..shader = _fade(
            color,
            bottom,
            <double>[0.7 * strength, 0.25 * strength, 0],
            const <double>[0, 0.3, 0.55],
          ),
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double pitch = (size.width - 2 * margin) / count;
    final double half = pitch * _halfBottom;
    final double bottom = size.height;
    double centre(double i) => margin + pitch * (i + 0.5);

    // Line along the bottom of the bar; the raised tab covers its part.
    canvas.drawLine(
      Offset(0, bottom - 0.6),
      Offset(size.width, bottom - 0.6),
      Paint()
        ..strokeWidth = 1.2
        ..color = palette.baseLine,
    );

    // Resting tabs, farthest from the raised tab first so nearer ones overlap.
    final List<int> order = <int>[for (int i = 0; i < count; i++) i]
      ..sort((int a, int b) => (b - pos).abs().compareTo((a - pos).abs()));
    final Shader restFill = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      // Dark tabs stay even and dim only near the foot; light tabs clear
      // gradually from a tinted top to near-white (as measured).
      colors: <Color>[palette.restTop, palette.restTop, palette.restBottom],
      stops: palette.isDark
          ? const <double>[0, 0.8, 1]
          : const <double>[0, 0.1, 1],
    ).createShader(Rect.fromLTRB(0, _top, 1, bottom - 1.2));
    for (final int i in order) {
      if ((i - pos).abs() < 0.001) continue;
      final double c = centre(i.toDouble());
      final double b = bottom - 1.2;
      canvas.drawPath(
        _outline(c, half, b, foot: 0)..close(),
        Paint()..shader = restFill,
      );
      // Only the top and far side are lit; the top line fades in from the
      // near corner, like the reference.
      final bool right = i > pos;
      final Rect band = Rect.fromLTRB(c - half - 2, 0, c + half + 2, bottom);
      canvas.saveLayer(band, Paint());
      _strokeTapered(
        canvas,
        _farEdge(c, half, b, right: right),
        palette.tabEdge,
        b,
        strength: palette.isDark ? 0.4 : 0.32,
      );
      canvas
        ..drawRect(
          band,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = LinearGradient(
              begin: right ? Alignment.centerLeft : Alignment.centerRight,
              end: right ? Alignment.centerRight : Alignment.centerLeft,
              colors: const <Color>[
                Color(0x00000000),
                Color(0x55000000),
                Color(0xFF000000),
              ],
              stops: const <double>[0.2, 0.5, 0.8],
            ).createShader(band),
        )
        ..restore();
    }

    // Raised tab: panel colour with a bloom of light at the top, so it flows
    // straight into the panel below.
    final double cx = centre(pos);
    final Path outline = _outline(cx, half, bottom, foot: _foot);
    final Path body = Path.from(outline)..close();
    canvas
      ..drawPath(body, Paint()..color = palette.tabFill)
      ..save()
      ..clipPath(body)
      ..drawOval(
        Rect.fromCenter(
          center: Offset(cx, _top),
          width: half * 1.6,
          height: (bottom - _top) * 1.2,
        ),
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              palette.bloom,
              palette.bloom.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCenter(
              center: Offset(cx, _top),
              width: half * 1.6,
              height: (bottom - _top) * 1.2,
            ),
          ),
      )
      ..restore();
    _strokeTapered(canvas, outline, palette.tabEdge, bottom, strength: 1);
  }

  @override
  bool shouldRepaint(_TabShapePainter old) =>
      old.pos != pos ||
      old.count != count ||
      old.margin != margin ||
      old.palette != palette;
}
