import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/video_widgets.dart';

enum MediaTab { photos, video, qc }

/// Pill switcher for Photos / Video / QC Report. [counts] shows a badge,
/// a tab with no content is dimmed but stays tappable (it explains itself).
class MediaTabBar extends StatelessWidget {
  const MediaTabBar({
    super.key,
    required this.value,
    required this.onChanged,
    required this.photoCount,
    required this.hasVideo,
    required this.hasQc,
  });
  final MediaTab value;
  final ValueChanged<MediaTab> onChanged;
  final int photoCount;
  final bool hasVideo;
  final bool hasQc;

  @override
  Widget build(BuildContext context) {
    Widget chip(
        MediaTab t, IconData icon, String label, String? badge, bool filled) {
      final on = value == t;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 44,
            decoration: BoxDecoration(
              color: on ? kAuctionBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon,
                  size: 18,
                  color: on
                      ? Colors.white
                      : filled
                          ? kAuctionBlue
                          : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: on
                          ? Colors.white
                          : filled
                              ? AppColors.navy
                              : AppColors.textMuted)),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: on ? Colors.white24 : kAuctionBlueSoft,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: on ? Colors.white : kAuctionBlue)),
                ),
              ],
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: const Color(0xFFF1F4FB),
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        chip(MediaTab.photos, PhosphorIconsRegular.image, 'Photos',
            photoCount > 0 ? '$photoCount' : null, photoCount > 0),
        chip(MediaTab.video, PhosphorIconsRegular.videoCamera, 'Video',
            hasVideo ? '1' : null, hasVideo),
        chip(MediaTab.qc, PhosphorIconsRegular.sealCheck, 'QC',
            hasQc ? '✓' : null, hasQc),
      ]),
    );
  }
}

/// Read-only Photos / Video / QC viewer for the seller's own auction and for
/// B2B lots a vendor is bidding on.
class AuctionMediaView extends StatefulWidget {
  const AuctionMediaView({
    super.key,
    required this.images,
    this.videoUrl,
    this.qc,
  });
  final List<String> images;
  final String? videoUrl;
  final QcReport? qc;

  @override
  State<AuctionMediaView> createState() => _AuctionMediaViewState();
}

class _AuctionMediaViewState extends State<AuctionMediaView> {
  MediaTab _tab = MediaTab.photos;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MediaTabBar(
        value: _tab,
        onChanged: (t) => setState(() => _tab = t),
        photoCount: imgs.length,
        hasVideo: widget.videoUrl != null,
        hasQc: widget.qc != null,
      ),
      const SizedBox(height: 12),
      switch (_tab) {
        MediaTab.photos => imgs.isEmpty
            ? const _NoMedia(PhosphorIconsRegular.image, 'No photos added')
            : Column(children: [
                AspectRatio(
                  aspectRatio: 1.25,
                  child: PageView.builder(
                    itemCount: imgs.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: () => _fullscreen(context, imgs, i),
                        child: MediaTile(imgs[i]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < imgs.length; i++)
                    Container(
                      width: i == _page ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                          color:
                              i == _page ? kAuctionBlue : AppColors.cardBorder,
                          borderRadius: BorderRadius.circular(3)),
                    ),
                ]),
              ]),
        MediaTab.video => widget.videoUrl == null
            ? const _NoMedia(PhosphorIconsRegular.videoCamera, 'No video added')
            : VideoBox(widget.videoUrl!, height: 220),
        MediaTab.qc => widget.qc == null
            ? const _NoMedia(
                PhosphorIconsRegular.sealCheck, 'No QC report added')
            : QcReportView(widget.qc!),
      },
    ]);
  }

  void _fullscreen(BuildContext context, List<String> imgs, int i) =>
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
            itemBuilder: (_, k) => InteractiveViewer(
                child: Center(
                    child: MediaTile(imgs[k], radius: 0, fit: BoxFit.contain))),
          ),
        ),
      ));
}

class _NoMedia extends StatelessWidget {
  const _NoMedia(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
            color: const Color(0xFFF7F9FD),
            borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 34, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 13.5, color: AppColors.textSecondary)),
        ]),
      );
}

/// The QC report: condition checklist, ticked checks, evidence photos, note.
class QcReportView extends StatelessWidget {
  const QcReportView(this.qc, {super.key});
  final QcReport qc;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, {String? value, required bool ok}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Icon(
                ok
                    ? PhosphorIconsFill.checkCircle
                    : PhosphorIconsRegular.circle,
                size: 20,
                color: ok ? AppColors.mint : AppColors.borderStrong),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy))),
            if (value != null)
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
          ]),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(PhosphorIconsFill.sealCheck,
              size: 20, color: kAuctionBlue),
          const SizedBox(width: 8),
          Text('Seller QC report', style: heading(size: 15.5)),
        ]),
        const SizedBox(height: 6),
        for (final e in qc.checks.entries) row(e.key, ok: e.value),
        for (final e in qc.checklist.entries)
          row(e.key, value: e.value, ok: true),
        if (qc.photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: qc.photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) =>
                  SizedBox(width: 74, child: MediaTile(qc.photos[i])),
            ),
          ),
        ],
        if (qc.notes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(qc.notes,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.4, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 8),
        const Text(
            'Self-declared by the seller. Dealkr’s own QC decision is separate.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
      ]),
    );
  }
}
