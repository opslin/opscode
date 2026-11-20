import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/application/create_draft.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_media_view.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/video_widgets.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

const _maxPhotos = 10;

/// Step 5 — Photos / Video / QC report, all pre-filled from the product where it
/// has them. Photos are required-optional (falls back to listing photos); video
/// and QC are optional but shown to bidders, so they build trust.
class MediaStep extends ConsumerStatefulWidget {
  const MediaStep({super.key});

  @override
  ConsumerState<MediaStep> createState() => _MediaStepState();
}

class _MediaStepState extends ConsumerState<MediaStep> {
  MediaTab _tab = MediaTab.photos;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(createDraftProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: MediaTabBar(
          value: _tab,
          onChanged: (t) => setState(() => _tab = t),
          photoCount: d.images.length,
          hasVideo: d.videoUrl != null,
          hasQc: d.hasQc,
        ),
      ),
      Expanded(
        child: switch (_tab) {
          MediaTab.photos => const _PhotosTab(),
          MediaTab.video => const _VideoTab(),
          MediaTab.qc => const _QcTab(),
        },
      ),
    ]);
  }
}

class _PhotosTab extends ConsumerWidget {
  const _PhotosTab();

  Future<void> _add(
      BuildContext context, WidgetRef ref, ImageSource src) async {
    final n = ref.read(createDraftProvider.notifier);
    final room = _maxPhotos - ref.read(createDraftProvider).images.length;
    if (room <= 0) return;
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

    final repo = ref.read(auctionRepositoryProvider);
    for (final f in files.take(room)) {
      n.setUploading(1);
      repo.uploadImage(f.path).then(n.addImage).catchError((Object e) {
        if (context.mounted) {
          showAppToast(context, errorText(e, 'Upload failed.'), error: true);
        }
      }).whenComplete(() => n.setUploading(-1));
    }
  }

  void _chooseSource(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading:
                  const Icon(PhosphorIconsRegular.camera, color: kAuctionBlue),
              title: const Text('Take a photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(c);
                _add(context, ref, ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(PhosphorIconsRegular.images, color: kAuctionBlue),
              title: const Text('Choose from gallery',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(c);
                _add(context, ref, ImageSource.gallery);
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(createDraftProvider);
    final n = ref.read(createDraftProvider.notifier);
    final full = d.images.length >= _maxPhotos;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text('Upload Photos', style: heading(size: 20)),
        const SizedBox(height: 4),
        Text(
            '${d.images.length}/$_maxPhotos photos · the first photo is the cover. Clear, well-lit photos get more bids.',
            style: const TextStyle(
                fontSize: 13.5, height: 1.35, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        if (d.images.isEmpty && d.uploading == 0)
          GestureDetector(
            onTap: () => _chooseSource(context, ref),
            child: Container(
              height: 170,
              decoration: BoxDecoration(
                color: kAuctionBlueSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: kAuctionBlue.withValues(alpha: 0.45), width: 1.4),
              ),
              child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIconsRegular.camera,
                        size: 40, color: kAuctionBlue),
                    SizedBox(height: 8),
                    Text('Add Photos',
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: kAuctionBlue)),
                    SizedBox(height: 2),
                    Text('Up to 10 photos',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ]),
            ),
          )
        else
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final (i, url) in d.images.indexed)
                Stack(fit: StackFit.expand, children: [
                  MediaTile(url),
                  if (i == 0)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: kAuctionBlue,
                            borderRadius: BorderRadius.circular(6)),
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
                      onTap: () => n.removeImage(url),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(PhosphorIconsBold.x,
                            size: 13, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              for (var i = 0; i < d.uploading; i++)
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
              if (!full && (d.images.isNotEmpty || d.uploading > 0))
                GestureDetector(
                  onTap: () => _chooseSource(context, ref),
                  child: Container(
                    decoration: BoxDecoration(
                      color: kAuctionBlueSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: kAuctionBlue.withValues(alpha: 0.4),
                          width: 1.3),
                    ),
                    child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(PhosphorIconsRegular.camera,
                              size: 28, color: kAuctionBlue),
                          SizedBox(height: 4),
                          Text('Add photos',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: kAuctionBlue)),
                        ]),
                  ),
                ),
            ],
          ),
        if (d.images.isEmpty && d.uploading == 0)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
                'No photos added — your product’s own listing photos will be used.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ),
      ],
    );
  }
}

// ── Video ───────────────────────────────────────────────────────────────

class _VideoTab extends ConsumerWidget {
  const _VideoTab();

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(PhosphorIconsRegular.videoCamera,
                  color: kAuctionBlue),
              title: const Text('Record a video',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(PhosphorIconsRegular.images, color: kAuctionBlue),
              title: const Text('Choose from gallery',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ]),
        ),
      ),
    );
    if (src == null) return;
    final f = await ImagePicker()
        .pickVideo(source: src, maxDuration: const Duration(seconds: 60));
    if (f == null) return;
    final n = ref.read(createDraftProvider.notifier);
    n.setVideoUploading(true);
    try {
      n.setVideo(await ref.read(auctionRepositoryProvider).uploadVideo(f.path));
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, errorText(e, 'Video upload failed.'),
            error: true);
      }
    } finally {
      n.setVideoUploading(false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(createDraftProvider);
    final n = ref.read(createDraftProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text('Product Video', style: heading(size: 20)),
        const SizedBox(height: 4),
        const Text(
            'A short walk-around (up to 60 seconds) showing the screen, buttons and camera. Bidders watch it before they bid.',
            style: TextStyle(
                fontSize: 13.5, height: 1.35, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        if (d.videoUploading)
          Container(
            height: 170,
            decoration: BoxDecoration(
                color: kAuctionBlueSoft,
                borderRadius: BorderRadius.circular(16)),
            child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.6),
                  SizedBox(height: 12),
                  Text('Uploading video…',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: kAuctionBlue)),
                ]),
          )
        else if (d.videoUrl == null)
          GestureDetector(
            onTap: () => _pick(context, ref),
            child: Container(
              height: 170,
              decoration: BoxDecoration(
                color: kAuctionBlueSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: kAuctionBlue.withValues(alpha: 0.45), width: 1.4),
              ),
              child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIconsRegular.videoCamera,
                        size: 40, color: kAuctionBlue),
                    SizedBox(height: 8),
                    Text('Add Video',
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: kAuctionBlue)),
                    SizedBox(height: 2),
                    Text('Record or choose from gallery',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ]),
            ),
          )
        else ...[
          VideoBox(d.videoUrl!, height: 220),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(context, ref),
                icon:
                    const Icon(PhosphorIconsRegular.arrowsClockwise, size: 18),
                label: const Text('Replace'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: kAuctionBlue,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => n.setVideo(null),
                icon: const Icon(PhosphorIconsRegular.trash, size: 18),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rose,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ]),
        ],
        if (d.videoUrl == null && !d.videoUploading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Optional — auctions with a video get more bids.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ),
      ],
    );
  }
}

// ── QC report ───────────────────────────────────────────────────────────

class _QcTab extends ConsumerStatefulWidget {
  const _QcTab();

  @override
  ConsumerState<_QcTab> createState() => _QcTabState();
}

class _QcTabState extends ConsumerState<_QcTab> {
  late final TextEditingController _notes =
      TextEditingController(text: ref.read(createDraftProvider).qcNotes);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final n = ref.read(createDraftProvider.notifier);
    final room = 6 - ref.read(createDraftProvider).qcPhotos.length;
    if (room <= 0) return;
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading:
                  const Icon(PhosphorIconsRegular.camera, color: kAuctionBlue),
              title: const Text('Take a photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(PhosphorIconsRegular.images, color: kAuctionBlue),
              title: const Text('Choose from gallery',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ]),
        ),
      ),
    );
    if (src == null) return;
    final picker = ImagePicker();
    final List<XFile> files = src == ImageSource.camera || room == 1
        ? [
            if (await picker.pickImage(source: src, imageQuality: 85)
                case final f?)
              f
          ]
        : await picker.pickMultiImage(imageQuality: 85, limit: room);
    if (!mounted) return;
    final repo = ref.read(auctionRepositoryProvider);
    for (final f in files.take(room)) {
      n.setQcUploading(1);
      repo.uploadImage(f.path).then(n.addQcPhoto).catchError((Object e) {
        if (mounted) {
          showAppToast(context, errorText(e, 'Upload failed.'), error: true);
        }
      }).whenComplete(() => n.setQcUploading(-1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(createDraftProvider);
    final n = ref.read(createDraftProvider.notifier);
    final ticked = d.qcChecks.values.where((v) => v).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text('QC Report', style: heading(size: 20)),
        const SizedBox(height: 4),
        const Text(
            'Tick what you have checked and add proof photos (IMEI screen, battery health, any marks). Bidders see this on the lot.',
            style: TextStyle(
                fontSize: 13.5, height: 1.35, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.cardBorder),
              borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            for (final (i, c) in qcCheckItems.indexed) ...[
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => n.toggleQc(c),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(children: [
                    Icon(
                        d.qcChecks[c] == true
                            ? PhosphorIconsFill.checkCircle
                            : PhosphorIconsRegular.circle,
                        size: 24,
                        color: d.qcChecks[c] == true
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
              if (i != qcCheckItems.length - 1)
                const Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: AppColors.cardBorder),
            ],
          ]),
        ),
        const SizedBox(height: 8),
        Text('$ticked of ${qcCheckItems.length} ticked',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        if (d.qcChecklist.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
              '${d.qcChecklist.length} condition details carried over from the product listing.',
              style: const TextStyle(fontSize: 12.5, color: kAuctionBlue)),
        ],
        const SizedBox(height: 18),
        Text('QC proof photos', style: heading(size: 16)),
        const SizedBox(height: 4),
        Text('${d.qcPhotos.length}/6 photos',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final url in d.qcPhotos)
              Stack(fit: StackFit.expand, children: [
                MediaTile(url),
                Positioned(
                  right: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: () => n.removeQcPhoto(url),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(PhosphorIconsBold.x,
                          size: 13, color: Colors.white),
                    ),
                  ),
                ),
              ]),
            for (var i = 0; i < d.qcUploading; i++)
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
            if (d.qcPhotos.length + d.qcUploading < 6)
              GestureDetector(
                onTap: _addPhoto,
                child: Container(
                  decoration: BoxDecoration(
                    color: kAuctionBlueSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: kAuctionBlue.withValues(alpha: 0.4), width: 1.3),
                  ),
                  child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIconsRegular.camera,
                            size: 28, color: kAuctionBlue),
                        SizedBox(height: 4),
                        Text('Add photo',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kAuctionBlue)),
                      ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Notes for bidders', style: heading(size: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: _notes,
          maxLines: 3,
          maxLength: 500,
          onChanged: n.setQcNotes,
          decoration: InputDecoration(
            hintText: 'e.g. Tiny scratch on the frame, battery health 91%',
            filled: true,
            fillColor: const Color(0xFFF7F9FD),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
