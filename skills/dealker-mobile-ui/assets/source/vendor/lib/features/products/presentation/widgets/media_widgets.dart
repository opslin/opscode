import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

const kMaxPhotos = 8;
const kMaxVideoSeconds = 60;

/// Server limit for evidence videos (MAX_VIDEO_FILE_SIZE = 100 MB).
const kMaxVideoBytes = 100 * 1024 * 1024;

/// Camera or gallery.
Future<ImageSource?> chooseSource(BuildContext context,
    {required String cameraLabel, required String galleryLabel}) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(PhosphorIconsRegular.camera, color: kBlue),
            title: Text(cameraLabel,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.images, color: kBlue),
            title: Text(galleryLabel,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ]),
      ),
    ),
  );
}

/// Picks photos and uploads each one; [onUploaded] fires per finished photo and
/// [onBusy] ±1 around each upload.
Future<void> addPhotos(
  BuildContext context,
  WidgetRef ref, {
  required int room,
  required void Function(String url) onUploaded,
  required void Function(int delta) onBusy,
}) async {
  if (room <= 0) return;
  final src = await chooseSource(context,
      cameraLabel: 'Take a photo', galleryLabel: 'Choose from gallery');
  if (src == null) return;
  final picker = ImagePicker();
  // pickMultiImage rejects a limit below 2, so a single slot uses pickImage.
  final List<XFile> files = src == ImageSource.camera || room == 1
      ? [
          if (await picker.pickImage(source: src, imageQuality: 85)
              case final f?)
            f
        ]
      : await picker.pickMultiImage(imageQuality: 85, limit: room);
  if (files.isEmpty) return;

  final repo = ref.read(productRepositoryProvider);
  for (final f in files.take(room)) {
    onBusy(1);
    repo.uploadImage(f.path).then(onUploaded).catchError((Object e) {
      if (context.mounted) {
        showAppToast(context, errorText(e, 'Photo upload failed.'),
            error: true);
      }
    }).whenComplete(() => onBusy(-1));
  }
}

/// Records / picks one video (≤ 60 s) and uploads it.
Future<void> addVideo(
  BuildContext context,
  WidgetRef ref, {
  required void Function(String url) onUploaded,
  required void Function(bool busy) onBusy,
}) async {
  final src = await chooseSource(context,
      cameraLabel: 'Record a video', galleryLabel: 'Choose from gallery');
  if (src == null) return;
  final f = await ImagePicker().pickVideo(
      source: src, maxDuration: const Duration(seconds: kMaxVideoSeconds));
  if (f == null) return;
  final bytes = await f.length();
  if (bytes > kMaxVideoBytes) {
    if (context.mounted) {
      showAppToast(context,
          'This video is ${(bytes / 1048576).round()} MB. The limit is 100 MB — record a shorter clip or pick a smaller file.',
          error: true);
    }
    return;
  }
  onBusy(true);
  try {
    onUploaded(await ref.read(productRepositoryProvider).uploadVideo(f.path));
  } catch (e) {
    if (context.mounted) {
      showAppToast(context, errorText(e, 'Video upload failed.'), error: true);
    }
  } finally {
    onBusy(false);
  }
}

/// 3-column photo grid with cover badge, remove buttons and an "add" tile.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    super.key,
    required this.images,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
    this.max = kMaxPhotos,
  });
  final List<String> images;
  final int uploading;
  final VoidCallback onAdd;
  final void Function(String url) onRemove;
  final int max;

  @override
  Widget build(BuildContext context) {
    final full = images.length + uploading >= max;
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final (i, url) in images.indexed)
          Stack(fit: StackFit.expand, children: [
            Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.cardBorder),
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(4),
                child: AnyImage(url, fit: BoxFit.contain, radius: 9)),
            if (i == 0)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: kBlue, borderRadius: BorderRadius.circular(6)),
                  child: const Text('Cover',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            Positioned(
              right: 4,
              top: 4,
              child: GestureDetector(
                onTap: () => onRemove(url),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(PhosphorIconsBold.x,
                      size: 13, color: Colors.white),
                ),
              ),
            ),
          ]),
        for (var i = 0; i < uploading; i++)
          Container(
            decoration: BoxDecoration(
                color: const Color(0xFFF1F4FB),
                borderRadius: BorderRadius.circular(12)),
            child: const Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4))),
          ),
        if (!full)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              decoration: BoxDecoration(
                color: kBlueSoft,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: kBlue.withValues(alpha: 0.4), width: 1.3),
              ),
              child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIconsRegular.plus, size: 28, color: kBlue),
                    SizedBox(height: 4),
                    Text('Add Photo',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kBlue)),
                  ]),
            ),
          ),
      ],
    );
  }
}

/// Large dashed-style empty drop zone for the first photo.
class AddFirstPhoto extends StatelessWidget {
  const AddFirstPhoto({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 170,
          decoration: BoxDecoration(
            color: kBlueSoft,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: kBlue.withValues(alpha: 0.45), width: 1.4),
          ),
          child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIconsRegular.camera, size: 40, color: kBlue),
                SizedBox(height: 8),
                Text('Add Photos',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: kBlue)),
                SizedBox(height: 2),
                Text('Take or choose up to 8 photos',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
              ]),
        ),
      );
}
