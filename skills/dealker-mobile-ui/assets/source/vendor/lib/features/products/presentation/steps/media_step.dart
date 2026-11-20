import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_draft.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/media_widgets.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/video_widgets.dart';

/// Step 2 — photos (min 3, max 8) and an optional video.
class MediaStep extends ConsumerStatefulWidget {
  const MediaStep({super.key});

  @override
  ConsumerState<MediaStep> createState() => _MediaStepState();
}

class _MediaStepState extends ConsumerState<MediaStep> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(addDraftProvider);
    final n = ref.read(addDraftProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        _Tabs(
          index: _tab,
          labels: [
            'Photos (${d.images.length})',
            d.hasVideo ? 'Video (1)' : 'Video'
          ],
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 18),
        if (_tab == 0) ...[
          Text('Upload Photos', style: heading(size: 19)),
          const SizedBox(height: 4),
          Text(
              '${d.images.length}/$kMaxPhotos photos · at least 3 required. The first photo is the cover.',
              style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          if (d.images.isEmpty && d.uploading == 0)
            AddFirstPhoto(
                onTap: () => addPhotos(context, ref,
                    room: kMaxPhotos,
                    onUploaded: n.addImage,
                    onBusy: n.setUploading))
          else
            PhotoGrid(
              images: d.images,
              uploading: d.uploading,
              onAdd: () => addPhotos(context, ref,
                  room: kMaxPhotos - d.images.length - d.uploading,
                  onUploaded: n.addImage,
                  onBusy: n.setUploading),
              onRemove: n.removeImage,
            ),
          const SizedBox(height: 18),
          const NoteBanner(
            'Use good light and a plain background. Show the front, back and sides clearly — buyers trust products with clear photos.',
            icon: PhosphorIconsFill.lightbulb,
          ),
        ] else ...[
          Row(children: [
            Text('Add Video', style: heading(size: 19)),
            const SizedBox(width: 8),
            const Text('(Optional)',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 4),
          const Text(
              'A short walk-around video (up to 60 seconds) shows buyers the real condition.',
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          if (d.videoUploading)
            Container(
              height: 170,
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F4FB),
                  borderRadius: BorderRadius.circular(16)),
              child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.6)),
                    SizedBox(height: 12),
                    Text('Uploading video…',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ]),
            )
          else if (d.videoUrl != null) ...[
            VideoBox(d.videoUrl!),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: AuctionButton(
                    label: 'Replace',
                    outlined: true,
                    height: 48,
                    icon: PhosphorIconsRegular.arrowsClockwise,
                    onPressed: () => _pickVideo(n)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AuctionButton(
                    label: 'Remove',
                    outlined: true,
                    danger: true,
                    height: 48,
                    icon: PhosphorIconsRegular.trash,
                    onPressed: () => n.set((x) =>
                        x.copyWith(videoUrl: null, videoChecks: const {}))),
              ),
            ]),
          ] else
            GestureDetector(
              onTap: () => _pickVideo(n),
              child: Container(
                height: 170,
                decoration: BoxDecoration(
                  color: kBlueSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: kBlue.withValues(alpha: 0.45), width: 1.4),
                ),
                child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIconsRegular.videoCamera,
                          size: 40, color: kBlue),
                      SizedBox(height: 8),
                      Text('Add Video',
                          style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: kBlue)),
                      SizedBox(height: 2),
                      Text('MP4 / MOV · up to 60 sec',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.textSecondary)),
                    ]),
              ),
            ),
        ],
      ],
    );
  }

  void _pickVideo(ProductDraftNotifier n) => addVideo(context, ref,
      onUploaded: (u) => n.set(
          (x) => x.copyWith(videoUrl: u, videoChecks: const <String, bool>{})),
      onBusy: (b) => n.set((x) => x.copyWith(videoUploading: b)));
}

/// Underlined two-tab switch (Photos | Videos).
class _Tabs extends StatelessWidget {
  const _Tabs(
      {required this.index, required this.labels, required this.onChanged});
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF3FB),
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          for (final (i, l) in labels.indexed)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? kBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(l,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: i == index
                              ? Colors.white
                              : AppColors.textSecondary)),
                ),
              ),
            ),
        ]),
      );
}
