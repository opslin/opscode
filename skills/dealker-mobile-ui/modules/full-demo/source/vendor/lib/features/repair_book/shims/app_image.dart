import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The customer app proxied media through its API on web; native just uses the URL.
String webImageSource(String url) => url;
String appImageSource(String url, {required bool isWeb}) => url;

/// Network image with a quiet placeholder (the customer app's AppImage, minus the web proxy).
class AppImage extends StatelessWidget {
  const AppImage({
    required this.imageUrl,
    this.memCacheWidth,
    this.memCacheHeight,
    super.key,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.high,
    this.alignment = Alignment.center,
    this.placeholder = const ColoredBox(color: Color(0xFFF5F5F5), child: SizedBox.expand()),
    this.errorWidget = const ColoredBox(color: Color(0xFFF5F5F5), child: SizedBox.expand()),
  });

  final String imageUrl;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final Alignment alignment;
  final Widget placeholder;
  final Widget errorWidget;

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
        imageUrl: imageUrl,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => errorWidget,
      );
}
