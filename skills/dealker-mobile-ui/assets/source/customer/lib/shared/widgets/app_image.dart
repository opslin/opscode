import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:dealker_app/core/constants/api_constants.dart';

String appImageSource(String url, {required bool isWeb}) =>
    isWeb ? (ApiConstants.proxyMediaUrl(url, isWeb: true) ?? url) : url;

/// Use for network images that need their existing widget-specific sizing.
String webImageSource(String url) => appImageSource(url, isWeb: kIsWeb);

/// Scroll-aware image widget.
///
/// Defers network image decoding during fast scroll to prevent main-thread
/// frame spikes in horizontally and vertically scrolling product surfaces.
class AppImage extends StatefulWidget {
  const AppImage({
    required this.imageUrl,
    required this.memCacheWidth,
    required this.memCacheHeight,
    super.key,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.high,
    this.alignment = Alignment.center,
    this.placeholder = const ColoredBox(
      color: Color(0xFFF5F5F5),
      child: SizedBox.expand(),
    ),
    this.errorWidget = const ColoredBox(
      color: Color(0xFFF5F5F5),
      child: SizedBox.expand(),
    ),
  });

  final String imageUrl;
  final int memCacheWidth;
  final int memCacheHeight;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final AlignmentGeometry alignment;
  final Widget placeholder;
  final Widget errorWidget;

  @override
  State<AppImage> createState() => _AppImageState();
}

class _AppImageState extends State<AppImage> {
  late final DisposableBuildContext<_AppImageState> _scrollAwareContext;

  @override
  void initState() {
    super.initState();
    _scrollAwareContext = DisposableBuildContext<_AppImageState>(this);
  }

  @override
  void dispose() {
    _scrollAwareContext.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CachedNetworkImageProvider can render transparent PNGs as black boxes
    // on web. NetworkImage still uses Flutter's image cache and the API proxy.
    final ImageProvider<Object> source = kIsWeb
        ? NetworkImage(appImageSource(widget.imageUrl, isWeb: true))
        : CachedNetworkImageProvider(
            widget.imageUrl,
            maxWidth: widget.memCacheWidth,
            maxHeight: widget.memCacheHeight,
          );
    final provider = ScrollAwareImageProvider<Object>(
      context: _scrollAwareContext,
      imageProvider: source,
    );

    return Image(
      image: provider,
      fit: widget.fit,
      filterQuality: widget.filterQuality,
      alignment: widget.alignment,
      frameBuilder: (
        BuildContext context,
        Widget child,
        int? frame,
        bool wasSynchronouslyLoaded,
      ) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return widget.placeholder;
      },
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return widget.errorWidget;
      },
    );
  }
}
