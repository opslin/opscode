import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/data/product_catalog.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/media_widgets.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/video_widgets.dart';

/// Step 5 — review the video and tick what it proves. The video is optional.
class VideoQcStep extends ConsumerWidget {
  const VideoQcStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(addDraftProvider);
    final n = ref.read(addDraftProvider.notifier);

    if (d.videoUploading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (d.videoUrl == null) {
      return EmptyState(
        icon: PhosphorIconsRegular.videoCamera,
        title: 'No video added',
        message:
            'A video is optional, but products with one get more trust. You can skip this step.',
        action: SizedBox(
          width: 190,
          child: AuctionButton(
              label: 'Add Video',
              height: 48,
              icon: PhosphorIconsRegular.videoCamera,
              onPressed: () => addVideo(context, ref,
                  onUploaded: (u) => n.set((x) => x.copyWith(videoUrl: u)),
                  onBusy: (b) => n.set((x) => x.copyWith(videoUploading: b)))),
        ),
      );
    }

    final ticked = kVideoChecks.where((c) => d.videoChecks[c] == true).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        VideoBox(d.videoUrl!, height: 210),
        const SizedBox(height: 20),
        Text('What does the video show?', style: heading(size: 17)),
        const SizedBox(height: 4),
        const Text('Tick everything the video proves.',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        SectionCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (final (i, c) in kVideoChecks.indexed) ...[
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => n.toggleVideoCheck(c),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                  child: Row(children: [
                    Icon(
                        d.videoChecks[c] == true
                            ? PhosphorIconsFill.checkCircle
                            : PhosphorIconsRegular.circle,
                        size: 24,
                        color: d.videoChecks[c] == true
                            ? AppColors.mint
                            : AppColors.borderStrong),
                    const SizedBox(width: 12),
                    Text(c,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy)),
                  ]),
                ),
              ),
              if (i != kVideoChecks.length - 1)
                const Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: AppColors.cardBorder),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        Text('$ticked of ${kVideoChecks.length} ticked',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
      ],
    );
  }
}
