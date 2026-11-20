import 'package:flutter/material.dart';

/// Assets are supplied by the fixture or bundled source and loaded locally.
class ApiConstants {
  static String? resolveMediaUrl(String? path) =>
      path != null && path.startsWith('assets/') ? path : null;
}

class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.imageUrl,
    required this.memCacheWidth,
    required this.memCacheHeight,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.high,
    this.placeholder = const ColoredBox(color: Color(0xFFF5F5F5)),
    this.errorWidget = const ColoredBox(color: Color(0xFFF5F5F5)),
  });

  final String imageUrl;
  final int memCacheWidth;
  final int memCacheHeight;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final Widget placeholder;
  final Widget errorWidget;

  @override
  Widget build(BuildContext context) {
    final path = ApiConstants.resolveMediaUrl(imageUrl);
    if (path == null) return errorWidget;
    return Image.asset(
      path,
      cacheWidth: memCacheWidth,
      cacheHeight: memCacheHeight,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      frameBuilder: (context, child, frame, loaded) =>
          frame == null && !loaded ? placeholder : child,
      errorBuilder: (context, error, stack) => errorWidget,
    );
  }
}

class AnyImage extends StatelessWidget {
  const AnyImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.radius = 0,
  });

  final String? path;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: AppImage(
      imageUrl: path ?? '',
      memCacheWidth: 360,
      memCacheHeight: 420,
      fit: fit,
    ),
  );
}
