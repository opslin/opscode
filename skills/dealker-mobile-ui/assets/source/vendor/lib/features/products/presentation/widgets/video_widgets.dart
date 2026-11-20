import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:video_player/video_player.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';

/// Inline player for the product video (network URL, or a local file in demo).
class VideoBox extends StatefulWidget {
  const VideoBox(this.source, {super.key, this.height = 200});
  final String source;
  final double height;

  @override
  State<VideoBox> createState() => _VideoBoxState();
}

class _VideoBoxState extends State<VideoBox> {
  VideoPlayerController? _c;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    final c = s.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(s))
        : VideoPlayerController.file(File(s));
    _c = c;
    c.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e);
    });
    c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = _c!;
    final ready = c.value.isInitialized;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: widget.height,
        color: Colors.black,
        child: _error != null
            ? const Center(
                child: Text('This video can’t be previewed on this device.',
                    style: TextStyle(color: Colors.white70)))
            : !ready
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : Stack(alignment: Alignment.center, children: [
                    Center(
                      child: AspectRatio(
                          aspectRatio: c.value.aspectRatio,
                          child: VideoPlayer(c)),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => c.value.isPlaying ? c.pause() : c.play(),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: c.value.isPlaying ? 0 : 1,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(PhosphorIconsFill.play,
                              color: AppColors.navy, size: 28),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 8,
                      child: Row(children: [
                        Text(
                            '${_fmt(c.value.position)} / ${_fmt(c.value.duration)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: VideoProgressIndicator(c,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                  playedColor: kBlue,
                                  bufferedColor: Colors.white30,
                                  backgroundColor: Colors.white24)),
                        ),
                      ]),
                    ),
                  ]),
      ),
    );
  }
}
