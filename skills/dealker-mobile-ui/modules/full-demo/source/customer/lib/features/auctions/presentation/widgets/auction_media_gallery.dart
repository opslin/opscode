import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

import 'package:dealker_app/shared/widgets/app_image.dart';

const Color _ink = Color(0xFF001F5F);
const Color _accent = Color(0xFF1558E8);
const Color _good = Color(0xFF1FB454);

enum _Tab { photos, video, qc }

/// The seller's QC report as the server sends it (`qc_report`): ticked checks, condition
/// details, proof photos and a note. Nothing here is Dealkr's own QC verdict.
class AuctionQc {
  const AuctionQc({
    this.checklist = const <String, String>{},
    this.checks = const <String, bool>{},
    this.photos = const <String>[],
    this.notes = '',
  });

  final Map<String, String> checklist;
  final Map<String, bool> checks;
  final List<String> photos;
  final String notes;

  bool get isEmpty =>
      checklist.isEmpty && checks.isEmpty && photos.isEmpty && notes.isEmpty;

  static AuctionQc? from(Object? raw) {
    if (raw is! Map) return null;
    Map<String, T> map<T>(Object? m, T Function(Object?) f) => <String, T>{
          if (m is Map)
            for (final MapEntry<dynamic, dynamic> e in m.entries)
              '${e.key}': f(e.value),
        };
    final AuctionQc q = AuctionQc(
      checklist: map<String>(raw['checklist'], (Object? v) => '$v'),
      checks: map<bool>(raw['checks'], (Object? v) => v == true),
      photos: <String>[
        if (raw['photos'] is List)
          for (final dynamic p in raw['photos'] as List)
            if ('$p'.isNotEmpty) '$p',
      ],
      notes: '${raw['notes'] ?? ''}'.trim(),
    );
    return q.isEmpty ? null : q;
  }
}

/// Photos / Video / QC viewer for an auction lot. [overlay] sits on the top-right of the photo
/// card (the watch heart).
class AuctionMediaGallery extends StatefulWidget {
  const AuctionMediaGallery({
    required this.images,
    this.videoUrl,
    this.qc,
    this.overlay,
    super.key,
  });

  final List<String> images;
  final String? videoUrl;
  final AuctionQc? qc;
  final Widget? overlay;

  @override
  State<AuctionMediaGallery> createState() => _AuctionMediaGalleryState();
}

class _AuctionMediaGalleryState extends State<AuctionMediaGallery> {
  _Tab _tab = _Tab.photos;
  int _page = 0;
  final PageController _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _hasVideo => widget.videoUrl != null && widget.videoUrl!.isNotEmpty;
  bool get _hasQc => widget.qc != null;

  @override
  Widget build(BuildContext context) {
    final bool tabs = _hasVideo || _hasQc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Photo / Video / QC are always offered when there is more than photos, so a bidder
        // can see at a glance what the seller provided (a tab with nothing says so).
        if (tabs) ...<Widget>[_tabBar(), SizedBox(height: 10.h)],
        switch (_tab) {
          _Tab.photos => _photos(),
          _Tab.video => _hasVideo
              ? _AuctionVideo(widget.videoUrl!)
              : _empty(
                  Icons.videocam_off_outlined, 'No video added by the seller'),
          _Tab.qc => _hasQc
              ? _qcCard(widget.qc!)
              : _empty(Icons.fact_check_outlined,
                  'No QC report added by the seller'),
        },
      ],
    );
  }

  Widget _tabBar() {
    Widget chip(_Tab t, IconData icon, String label, bool has) {
      final bool on = _tab == t;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _tab = t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 40.h,
            decoration: BoxDecoration(
              color: on ? _accent : Colors.transparent,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon,
                    size: 17.sp,
                    color:
                        on ? Colors.white : (has ? _accent : Colors.black38)),
                SizedBox(width: 5.w),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: on ? Colors.white : (has ? _ink : Colors.black38),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
      child: Row(
        children: <Widget>[
          chip(_Tab.photos, Icons.photo_library_outlined, 'Photos',
              widget.images.isNotEmpty),
          chip(_Tab.video, Icons.play_circle_outline_rounded, 'Video',
              _hasVideo),
          chip(_Tab.qc, Icons.verified_outlined, 'QC Report', _hasQc),
        ],
      ),
    );
  }

  Widget _photos() {
    final List<String> images = widget.images;
    if (images.isEmpty)
      return _empty(Icons.image_not_supported_outlined, 'No photos added');
    return Stack(
      children: <Widget>[
        Container(
          height: 280.h,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(18.r)),
          child: PageView.builder(
            controller: _pages,
            itemCount: images.length,
            onPageChanged: (int i) => setState(() => _page = i),
            itemBuilder: (BuildContext c, int i) => GestureDetector(
              onTap: () => _fullscreen(c, images, i),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: AppImage(
                    imageUrl: images[i],
                    memCacheWidth: 900,
                    memCacheHeight: 900,
                    fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        if (widget.overlay != null)
          Positioned(right: 10.w, top: 10.h, child: widget.overlay!),
        if (images.length > 1)
          Positioned(
            bottom: 8.h,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < images.length; i++)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    width: i == _page ? 14.w : 6.w,
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: i == _page ? _accent : Colors.black26,
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _fullscreen(BuildContext context, List<String> imgs, int i) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0),
        body: PageView.builder(
          controller: PageController(initialPage: i),
          itemCount: imgs.length,
          itemBuilder: (_, int k) => InteractiveViewer(
            child: Center(
                child: AppImage(
                    imageUrl: imgs[k],
                    memCacheWidth: 1600,
                    memCacheHeight: 1600,
                    fit: BoxFit.contain)),
          ),
        ),
      ),
    ));
  }

  Widget _empty(IconData icon, String text) => Container(
        height: 200.h,
        width: double.infinity,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18.r)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 36.sp, color: Colors.black38),
            SizedBox(height: 8.h),
            Text(text,
                style: TextStyle(fontSize: 13.sp, color: Colors.black54)),
          ],
        ),
      );

  Widget _qcCard(AuctionQc qc) {
    Widget row(String label, {String? value, required bool ok}) => Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: Row(
            children: <Widget>[
              Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20.sp, color: ok ? _good : Colors.black26),
              SizedBox(width: 10.w),
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: _ink))),
              if (value != null)
                Text(value,
                    style: TextStyle(fontSize: 13.sp, color: Colors.black54)),
            ],
          ),
        );

    final int passed = qc.checks.values.where((bool v) => v).length;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.verified_rounded, size: 22.sp, color: _accent),
              SizedBox(width: 8.w),
              Expanded(
                  child: Text('Seller QC report',
                      style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: _ink))),
              if (qc.checks.isNotEmpty)
                Text('$passed/${qc.checks.length} passed',
                    style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: _good)),
            ],
          ),
          SizedBox(height: 6.h),
          for (final MapEntry<String, bool> e in qc.checks.entries)
            row(e.key, ok: e.value),
          for (final MapEntry<String, String> e in qc.checklist.entries)
            row(e.key, value: e.value, ok: true),
          if (qc.photos.isNotEmpty) ...<Widget>[
            SizedBox(height: 12.h),
            SizedBox(
              height: 84.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: qc.photos.length,
                separatorBuilder: (_, int __) => SizedBox(width: 8.w),
                itemBuilder: (BuildContext c, int i) => GestureDetector(
                  onTap: () => _fullscreen(c, qc.photos, i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: SizedBox(
                      width: 84.h,
                      child: AppImage(
                          imageUrl: qc.photos[i],
                          memCacheWidth: 300,
                          memCacheHeight: 300),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (qc.notes.isNotEmpty) ...<Widget>[
            SizedBox(height: 12.h),
            Text(qc.notes,
                style: TextStyle(
                    fontSize: 13.sp, height: 1.4, color: Colors.black87)),
          ],
          SizedBox(height: 10.h),
          Text(
            'Declared by the seller. Look at the photos and video before you bid.',
            style: TextStyle(fontSize: 11.5.sp, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

/// Inline player with play / pause and a scrub bar.
class _AuctionVideo extends StatefulWidget {
  const _AuctionVideo(this.url);
  final String url;

  @override
  State<_AuctionVideo> createState() => _AuctionVideoState();
}

class _AuctionVideoState extends State<_AuctionVideo> {
  late final VideoPlayerController _c =
      VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
    _c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final bool ready = _c.value.isInitialized;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        height: 280.h,
        color: Colors.black,
        child: _failed
            ? const Center(
                child: Text('This video could not be played.',
                    style: TextStyle(color: Colors.white70)))
            : !ready
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Center(
                          child: AspectRatio(
                              aspectRatio: _c.value.aspectRatio,
                              child: VideoPlayer(_c))),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            _c.value.isPlaying ? _c.pause() : _c.play(),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: _c.value.isPlaying ? 0 : 1,
                          child: Container(
                            width: 60.w,
                            height: 60.w,
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: Icon(Icons.play_arrow_rounded,
                                size: 34.sp, color: _ink),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12.w,
                        right: 12.w,
                        bottom: 8.h,
                        child: Row(
                          children: <Widget>[
                            Text(
                              '${_fmt(_c.value.position)} / ${_fmt(_c.value.duration)}',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: VideoProgressIndicator(
                                _c,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: _accent,
                                  bufferedColor: Colors.white30,
                                  backgroundColor: Colors.white24,
                                ),
                              ),
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
