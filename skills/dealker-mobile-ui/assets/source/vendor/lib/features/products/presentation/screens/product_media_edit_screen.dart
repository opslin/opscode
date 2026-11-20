import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/data/product_models.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/media_widgets.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/video_widgets.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// "Update Photos / Videos" — changing media sends the product for review again.
class ProductMediaEditScreen extends ConsumerStatefulWidget {
  const ProductMediaEditScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ProductMediaEditScreen> createState() => _State();
}

class _State extends ConsumerState<ProductMediaEditScreen> {
  List<String>? _images;
  String? _video;
  bool _videoInit = false;
  int _uploading = 0;
  bool _videoBusy = false;
  bool _saving = false;

  void _seed(ListingDetail p) {
    if (_images != null) return;
    _images = [...p.images];
    if (!_videoInit) {
      _video = p.videoUrl;
      _videoInit = true;
    }
  }

  Future<void> _save(ListingDetail p) async {
    final imgs = _images!;
    if (_uploading > 0 || _videoBusy) {
      showAppToast(context, 'Wait for uploads to finish.',
          error: true, bottom: 96);
      return;
    }
    if (imgs.length < 3) {
      showAppToast(context, 'Keep at least 3 photos (${imgs.length}/3).',
          error: true, bottom: 96);
      return;
    }
    final photosChanged = imgs.length != p.images.length ||
        [for (var i = 0; i < imgs.length; i++) imgs[i] != p.images[i]]
            .contains(true);
    final videoChanged = _video != p.videoUrl;
    if (!photosChanged && !videoChanged) {
      context.pop();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(productRepositoryProvider).update(p.id, {
        if (photosChanged) 'images': imgs,
        if (videoChanged) 'videoUrl': _video,
      });
      if (!mounted) return;
      ref.invalidate(productDetailProvider(p.id));
      refreshProducts(ref);
      showAppToast(
          context,
          photosChanged
              ? 'Saved. Your product will be reviewed again.'
              : 'Video saved.');
      context.pop();
    } catch (e) {
      if (mounted) {
        showAppToast(context, explainFailure(e).message, error: true);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(productDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AuctionAppBar(title: 'Photos & Video'),
      body: async.when(
        skipLoadingOnReload: true,
        skipError: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e),
            onRetry: () => ref.invalidate(productDetailProvider(widget.id))),
        data: (p) {
          _seed(p);
          final imgs = _images!;
          return Column(children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Text('Photos (${imgs.length}/$kMaxPhotos)',
                      style: heading(size: 18)),
                  const SizedBox(height: 4),
                  const Text('At least 3 photos. The first photo is the cover.',
                      style: TextStyle(
                          fontSize: 13.5, color: AppColors.textSecondary)),
                  const SizedBox(height: 14),
                  PhotoGrid(
                    images: imgs,
                    uploading: _uploading,
                    onAdd: () => addPhotos(context, ref,
                        room: kMaxPhotos - imgs.length - _uploading,
                        onUploaded: (u) => setState(() => imgs.add(u)),
                        onBusy: (d) => setState(
                            () => _uploading = (_uploading + d).clamp(0, 99))),
                    onRemove: (u) => setState(() => imgs.remove(u)),
                  ),
                  const SizedBox(height: 24),
                  Text('Video', style: heading(size: 18)),
                  const SizedBox(height: 12),
                  if (_videoBusy)
                    const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: CircularProgressIndicator()))
                  else if (_video != null) ...[
                    VideoBox(_video!),
                    const SizedBox(height: 10),
                    AuctionButton(
                        label: 'Remove video',
                        outlined: true,
                        danger: true,
                        height: 46,
                        icon: PhosphorIconsRegular.trash,
                        onPressed: () => setState(() => _video = null)),
                  ] else
                    AuctionButton(
                        label: 'Add video',
                        outlined: true,
                        height: 50,
                        icon: PhosphorIconsRegular.videoCamera,
                        onPressed: () => addVideo(context, ref,
                            onUploaded: (u) => setState(() => _video = u),
                            onBusy: (b) => setState(() => _videoBusy = b))),
                  const SizedBox(height: 20),
                  const NoteBanner(
                      'Changing photos sends this product for review again, and it is hidden from buyers until it is approved.',
                      icon: PhosphorIconsFill.info),
                ],
              ),
            ),
            BottomActionBar(
                child: AuctionButton(
                    label: 'Save Changes',
                    loading: _saving,
                    onPressed: () => _save(p))),
          ]);
        },
      ),
    );
  }
}
