import 'dart:io';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/orders/domain/entities/order_entity.dart';
import 'package:dealker_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:dealker_app/features/refund_requests/data/return_chat_repository.dart';
import 'package:dealker_app/features/refund_requests/domain/repositories/refund_request_repository.dart';
import 'package:dealker_app/features/refund_requests/presentation/providers/refund_request_provider.dart';
import 'package:dealker_app/features/refund_requests/presentation/providers/return_providers.dart';
import 'package:dealker_app/features/refund_requests/presentation/screens/return_routes.dart';
import 'package:dealker_app/features/refund_requests/presentation/widgets/return_ui.dart';
import 'package:dealker_app/shared/widgets/safe_product_image.dart';

const int _maxVideoSeconds = 30;
const int _maxVideoBytes = 100 * 1024 * 1024;

enum _Slot { front, back, video }

class _Picked {
  _Picked(this.file);

  final XFile file;
  String get path => file.path;
  String? url;
  bool uploading = true;
  bool failed = false;
  Duration? duration;
}

/// Return wizard (`docs/design/02-return-flow.jpg`, screens 2–4): Reason → Photos & Video → Review → Submit.
class ReturnRequestScreen extends ConsumerStatefulWidget {
  const ReturnRequestScreen({required this.order, super.key});

  final OrderEntity order;

  @override
  ConsumerState<ReturnRequestScreen> createState() =>
      _ReturnRequestScreenState();
}

class _ReturnRequestScreenState extends ConsumerState<ReturnRequestScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _details = TextEditingController();
  int _step = 0;
  String? _reason;
  late final Set<String> _items =
      widget.order.items.map((OrderItemEntity i) => i.productId).toSet();
  final Map<_Slot, _Picked> _media = <_Slot, _Picked>{};
  bool _submitting = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  bool get _uploading => _media.values.any((_Picked m) => m.uploading);

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      context.pop();
    }
  }

  void _next() {
    if (_step == 0) {
      if (_items.isEmpty) {
        AppToast.show(context, 'Select the item you want to return');
        return;
      }
      if (_reason == null) {
        AppToast.show(context, 'Select a reason for the return');
        return;
      }
      if (_reason == 'OTHER' && _details.text.trim().length < 3) {
        AppToast.show(context, 'Please describe the problem');
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      if (_media[_Slot.front] == null ||
          _media[_Slot.back] == null ||
          _media[_Slot.video] == null) {
        AppToast.show(
          context,
          'Add the front photo, back photo and a short video',
        );
        return;
      }
      if (_uploading) {
        AppToast.show(context, 'Please wait, files are still uploading');
        return;
      }
      if (_media.values.any((_Picked m) => m.failed)) {
        AppToast.show(context, 'A file failed to upload. Remove it and retry.');
        return;
      }
      setState(() => _step = 2);
    }
  }

  Future<void> _pick(_Slot slot) async {
    final bool video = slot == _Slot.video;
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (BuildContext c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(
                video ? Icons.videocam_rounded : Icons.photo_camera_rounded,
                color: ReturnColors.indigo,
              ),
              title: Text(video ? 'Record a video' : 'Take a photo'),
              onTap: () => Navigator.of(c).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: ReturnColors.indigo,
              ),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(c).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final XFile? file = video
          ? await _picker.pickVideo(
              source: source,
              maxDuration: const Duration(seconds: _maxVideoSeconds),
            )
          : await _picker.pickImage(
              source: source,
              imageQuality: 80,
              maxWidth: 1600,
            );
      if (file == null || !mounted) return;

      final _Picked picked = _Picked(file);
      if (video) {
        if (await file.length() > _maxVideoBytes) {
          if (mounted)
            AppToast.show(context, 'Video is too large (max 100 MB)');
          return;
        }
        final VideoPlayerController probe = kIsWeb
            ? VideoPlayerController.networkUrl(Uri.parse(file.path))
            : VideoPlayerController.file(File(file.path));
        await probe.initialize();
        picked.duration = probe.value.duration;
        await probe.dispose();
        if (picked.duration!.inSeconds > _maxVideoSeconds + 1) {
          if (mounted) {
            AppToast.show(
              context,
              'Video must be $_maxVideoSeconds seconds or shorter',
            );
          }
          return;
        }
      }
      if (!mounted) return;
      setState(() => _media[slot] = picked);
      try {
        final repo = ref.read(returnMediaRepositoryProvider);
        picked.url = video
            ? await repo.uploadVideo(file)
            : await repo.uploadImage(file);
      } catch (e) {
        picked.failed = true;
        if (mounted)
          AppToast.show(context, ReturnChatRepository.errorMessage(e));
      } finally {
        picked.uploading = false;
        if (mounted) setState(() {});
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          'Could not open the camera or gallery. Check permissions.',
        );
      }
    }
  }

  Future<void> _submit() async {
    final ReturnReason reason = ReturnReason.byCode(_reason)!;
    final bool all = _items.length == widget.order.items.length;
    final String details = _details.text.trim();
    setState(() => _submitting = true);
    final RefundRequestActionResult result =
        await ref.read(refundRequestProvider.notifier).createRequest(
              RefundRequestCreateParams(
                orderId: widget.order.id,
                itemScope: all ? 'ALL' : 'SPECIFIC',
                description: details.isEmpty
                    ? reason.title
                    : '${reason.title}: $details',
                productIds: all ? null : _items.toList(),
                reasonCode: reason.code,
                evidence: <Map<String, String>>[
                  for (final _Slot s in <_Slot>[_Slot.front, _Slot.back])
                    <String, String>{'url': _media[s]!.url!, 'kind': 'IMAGE'},
                  <String, String>{
                    'url': _media[_Slot.video]!.url!,
                    'kind': 'VIDEO',
                  },
                ],
              ),
            );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!result.isSuccess) {
      AppToast.show(context, result.failure!.message);
      return;
    }
    ref.invalidate(refundRequestByOrderProvider(widget.order.id));
    AppToast.show(context, 'Return request submitted', type: ToastType.success);
    context.pushReplacement(ReturnRoutes.tracking(widget.order.id));
  }

  @override
  Widget build(BuildContext context) {
    final String cta = _step == 2 ? 'Submit Return Request' : 'Next Step';
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _back();
      },
      child: ReturnScaffold(
        title: 'Return Request',
        onBack: _back,
        bottom: ReturnPrimaryButton(
          label: cta,
          icon: _step == 2 ? null : Icons.arrow_forward_rounded,
          busy: _submitting,
          onPressed: _step == 2 ? _submit : _next,
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
          children: <Widget>[
            ReturnStepper(
              labels: const <String>[
                'Reason',
                'Photos & Video',
                'Review',
                'Submit',
              ],
              current: _step,
            ),
            SizedBox(height: 16.h),
            if (_step == 0) ..._reasonStep(),
            if (_step == 1) ..._evidenceStep(),
            if (_step == 2) ..._reviewStep(),
          ],
        ),
      ),
    );
  }

  // ── Step 1 ────────────────────────────────────────────────────────────
  List<Widget> _reasonStep() {
    final List<OrderItemEntity> items = widget.order.items;
    return <Widget>[
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => context.push(ReturnRoutes.policy()),
          icon: Icon(Icons.rule_rounded, size: 16.sp),
          label: const Text('Return policy'),
          style: TextButton.styleFrom(
            foregroundColor: ReturnColors.indigo,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
      if (items.length > 1) ...<Widget>[
        ReturnCard(
          color: ReturnColors.indigoSoft.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Select item to return',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: ReturnColors.ink,
                ),
              ),
              SizedBox(height: 8.h),
              for (final OrderItemEntity item in items)
                InkWell(
                  onTap: () => setState(() {
                    if (!_items.remove(item.productId)) {
                      _items.add(item.productId);
                    }
                  }),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.h),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          _items.contains(item.productId)
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: _items.contains(item.productId)
                              ? ReturnColors.indigo
                              : ReturnColors.muted,
                        ),
                        SizedBox(width: 10.w),
                        SafeProductImage(
                          url: item.thumbnailUrl,
                          size: 38.w,
                          borderRadius: BorderRadius.circular(8.r),
                          fit: BoxFit.contain,
                          backgroundColor: Colors.white,
                          iconSize: 16.sp,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: ReturnColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 14.h),
      ],
      ReturnCard(
        color: ReturnColors.indigoSoft.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Select Return Reason',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: ReturnColors.ink,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Why do you want to return this product?',
              style: TextStyle(fontSize: 11.sp, color: ReturnColors.red),
            ),
            SizedBox(height: 12.h),
            for (final ReturnReason r in ReturnReason.all)
              _ReasonTile(
                reason: r,
                selected: _reason == r.code,
                onTap: () => setState(() => _reason = r.code),
              ),
            SizedBox(height: 4.h),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 12.sp),
              decoration: InputDecoration(
                hintText: _reason == 'OTHER'
                    ? 'Describe the problem'
                    : 'Add more details (optional)',
                hintStyle:
                    TextStyle(fontSize: 12.sp, color: ReturnColors.muted),
                filled: true,
                fillColor: Colors.white,
                counterText: '',
                contentPadding: EdgeInsets.all(12.w),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: ReturnColors.indigoLine),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: ReturnColors.indigoLine),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: ReturnColors.indigo),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ── Step 2 ────────────────────────────────────────────────────────────
  List<Widget> _evidenceStep() {
    final List<MapEntry<_Slot, _Picked>> picked = <_Slot>[
      _Slot.front,
      _Slot.back,
      _Slot.video,
    ]
        .where((_Slot s) => _media[s] != null)
        .map((_Slot s) => MapEntry<_Slot, _Picked>(s, _media[s]!))
        .toList();
    return <Widget>[
      ReturnCard(
        color: ReturnColors.indigoSoft.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Upload Evidence',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: ReturnColors.ink,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Please upload clear photos and a short video ($_maxVideoSeconds seconds max) of the issue.',
              style: TextStyle(
                fontSize: 11.sp,
                height: 1.35,
                color: ReturnColors.muted,
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SlotTile(
                    icon: Icons.photo_camera_outlined,
                    title: 'Front Photo',
                    caption: '(Required)',
                    done: _media[_Slot.front] != null,
                    onTap: () => _pick(_Slot.front),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _SlotTile(
                    icon: Icons.photo_camera_back_outlined,
                    title: 'Back Photo',
                    caption: '(Required)',
                    done: _media[_Slot.back] != null,
                    onTap: () => _pick(_Slot.back),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _SlotTile(
                    icon: Icons.videocam_outlined,
                    title: 'Video',
                    caption: '(Required)',
                    extra: 'Max $_maxVideoSeconds sec',
                    done: _media[_Slot.video] != null,
                    onTap: () => _pick(_Slot.video),
                  ),
                ),
              ],
            ),
            if (picked.isNotEmpty) ...<Widget>[
              SizedBox(height: 14.h),
              Row(
                children: <Widget>[
                  for (final MapEntry<_Slot, _Picked> e in picked) ...<Widget>[
                    Expanded(
                      child: _Thumb(
                        picked: e.value,
                        isVideo: e.key == _Slot.video,
                        onRemove: () => setState(() => _media.remove(e.key)),
                      ),
                    ),
                    if (e.key != picked.last.key) SizedBox(width: 8.w),
                  ],
                  for (int i = picked.length; i < 3; i++) ...<Widget>[
                    SizedBox(width: 8.w),
                    const Expanded(child: SizedBox()),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
      SizedBox(height: 14.h),
      const ReturnNote(
        icon: Icons.access_time_rounded,
        text:
            'Make sure your images and video are clear and show the actual issue.',
      ),
    ];
  }

  // ── Step 3 ────────────────────────────────────────────────────────────
  List<Widget> _reviewStep() {
    final ReturnReason reason = ReturnReason.byCode(_reason)!;
    final List<OrderItemEntity> chosen = widget.order.items
        .where((OrderItemEntity i) => _items.contains(i.productId))
        .toList();
    final OrderItemEntity first = chosen.first;
    final Duration? vd = _media[_Slot.video]?.duration;
    return <Widget>[
      ReturnCard(
        color: ReturnColors.indigoSoft.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Review Your Return Request',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: ReturnColors.ink,
              ),
            ),
            SizedBox(height: 12.h),
            ReturnCard(
              child: Row(
                children: <Widget>[
                  SafeProductImage(
                    url: first.thumbnailUrl,
                    size: 52.w,
                    borderRadius: BorderRadius.circular(10.r),
                    fit: BoxFit.contain,
                    backgroundColor: Colors.white,
                    iconSize: 20.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          chosen.length > 1
                              ? '${first.name} +${chosen.length - 1} more'
                              : first.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: ReturnColors.ink,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: <Widget>[
                            Text(
                              'Issue:  ',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: ReturnColors.ink,
                              ),
                            ),
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: ReturnColors.indigoSoft,
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  reason.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: ReturnColors.indigo,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            _SummaryRow(
              icon: Icons.assignment_late_outlined,
              title: 'Reason',
              value: _details.text.trim().isEmpty
                  ? reason.title
                  : '${reason.title}\n${_details.text.trim()}',
            ),
            SizedBox(height: 10.h),
            const _SummaryRow(
              icon: Icons.image_outlined,
              title: 'Photos',
              value: '2 images uploaded',
            ),
            SizedBox(height: 10.h),
            _SummaryRow(
              icon: Icons.videocam_outlined,
              title: 'Video',
              value: vd == null
                  ? '1 video uploaded'
                  : '${vd.inSeconds} seconds uploaded',
            ),
          ],
        ),
      ),
      SizedBox(height: 14.h),
      const ReturnNote(
        icon: Icons.check_circle_rounded,
        text:
            'Your request will be sent to the vendor for review. You can track the status in your orders.',
      ),
    ];
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final ReturnReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: selected ? ReturnColors.indigo : ReturnColors.indigoLine,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 20.w,
                height: 20.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? ReturnColors.indigo
                        : ReturnColors.indigoLine,
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? Container(
                        width: 10.w,
                        height: 10.w,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: ReturnColors.indigo,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      reason.title,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                        color: ReturnColors.ink,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      reason.hint,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: ReturnColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.icon,
    required this.title,
    required this.caption,
    required this.onTap,
    required this.done,
    this.extra,
  });

  final IconData icon;
  final String title;
  final String caption;
  final String? extra;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: _DashedRRectPainter(
          color: done ? ReturnColors.green : ReturnColors.indigo,
          radius: 12.r,
        ),
        child: Container(
          height: 104.h,
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          color: Colors.white,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              SizedBox(height: 14.h),
              Icon(
                done ? Icons.check_circle_rounded : icon,
                size: 28.sp,
                color: done ? ReturnColors.green : ReturnColors.indigo,
              ),
              SizedBox(height: 6.h),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w700,
                  color: ReturnColors.ink,
                ),
              ),
              Text(
                caption,
                style: TextStyle(
                  fontSize: 9.sp,
                  color: done ? ReturnColors.green : ReturnColors.red,
                ),
              ),
              if (extra != null)
                Text(
                  extra!,
                  style: TextStyle(fontSize: 9.sp, color: ReturnColors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatefulWidget {
  const _Thumb({
    required this.picked,
    required this.isVideo,
    required this.onRemove,
  });

  final _Picked picked;
  final bool isVideo;
  final VoidCallback onRemove;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _video = (kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(widget.picked.path))
          : VideoPlayerController.file(File(widget.picked.path)))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  String get _length {
    final int s = widget.picked.duration?.inSeconds ?? 0;
    return '00:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final _Picked p = widget.picked;
    return AspectRatio(
      aspectRatio: 0.8,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: widget.isVideo
                ? (_video != null && _video!.value.isInitialized
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _video!.value.size.width,
                          height: _video!.value.size.height,
                          child: VideoPlayer(_video!),
                        ),
                      )
                    : const ColoredBox(color: Colors.black))
                : kIsWeb
                    ? Image.network(p.path, fit: BoxFit.cover)
                    : Image.file(File(p.path), fit: BoxFit.cover),
          ),
          if (widget.isVideo) ...<Widget>[
            Center(
              child: Container(
                padding: EdgeInsets.all(6.w),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 18.sp,
                  color: ReturnColors.ink,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 4.h,
              child: Text(
                _length,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          if (p.uploading)
            ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: ColoredBox(
                color: Colors.black45,
                child: Center(
                  child: SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          if (p.failed)
            ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: ColoredBox(
                color: ReturnColors.red.withValues(alpha: 0.55),
                child: const Center(
                  child: Icon(Icons.error_outline_rounded, color: Colors.white),
                ),
              ),
            ),
          Positioned(
            top: 4.w,
            right: 4.w,
            child: GestureDetector(
              onTap: widget.onRemove,
              child: Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: ReturnColors.line),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 14.sp,
                  color: ReturnColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ReturnCard(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22.sp, color: ReturnColors.indigo),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: ReturnColors.ink,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11.sp,
                    height: 1.3,
                    color: ReturnColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.6),
          Radius.circular(radius),
        ),
      );
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final PathMetric m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
