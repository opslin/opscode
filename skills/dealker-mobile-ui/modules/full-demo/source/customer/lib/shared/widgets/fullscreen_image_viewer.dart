import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen, swipeable photo viewer with pinch-to-zoom and double-tap zoom.
/// Open it with [FullscreenImageViewer.open] from any product image.
class FullscreenImageViewer extends StatefulWidget {
  const FullscreenImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  final List<String> images;
  final int initialIndex;

  static Future<void> open(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
  }) {
    if (images.isEmpty) return Future<void>.value();
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => FullscreenImageViewer(
          images: images,
          initialIndex: initialIndex.clamp(0, images.length - 1),
        ),
        transitionsBuilder: (_, Animation<double> a, __, Widget child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late final PageController _pc =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            PageView.builder(
              controller: _pc,
              // While an image is zoomed in, the drag pans the image instead of paging.
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              itemCount: widget.images.length,
              onPageChanged: (int i) => setState(() => _index = i),
              itemBuilder: (BuildContext c, int i) => _ZoomablePage(
                url: widget.images[i],
                onZoomChanged: (bool z) {
                  if (z != _zoomed) setState(() => _zoomed = z);
                },
              ),
            ),
            Positioned(
              top: top + 8,
              right: 12,
              child: Material(
                color: Colors.white24,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + 18,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

class _ZoomablePage extends StatefulWidget {
  const _ZoomablePage({
    required this.url,
    required this.onZoomChanged,
  });

  final String url;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage>
    with SingleTickerProviderStateMixin {
  final TransformationController _tc = TransformationController();
  Offset _doubleTapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _tc.addListener(
        () => widget.onZoomChanged(_tc.value.getMaxScaleOnAxis() > 1.02));
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_tc.value.getMaxScaleOnAxis() > 1.02) {
      _tc.value = Matrix4.identity();
    } else {
      const double s = 2.6;
      final Offset p = _doubleTapAt;
      _tc.value = Matrix4.identity()
        ..translateByDouble(-p.dx * (s - 1), -p.dy * (s - 1), 0, 1)
        ..scaleByDouble(s, s, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (TapDownDetails d) => _doubleTapAt = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            fadeInDuration: const Duration(milliseconds: 120),
            filterQuality: FilterQuality.high,
            placeholder: (BuildContext c, String u) => const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white70,
                ),
              ),
            ),
            errorWidget: (BuildContext c, String u, Object e) => const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
