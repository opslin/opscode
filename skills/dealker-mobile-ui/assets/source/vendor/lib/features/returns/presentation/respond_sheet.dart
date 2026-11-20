import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show AuctionButton, ProductThumb, errorText;
import 'package:dealker_vendor/features/products/presentation/widgets/media_widgets.dart' show chooseSource;
import 'package:dealker_vendor/features/returns/application/returns_providers.dart';
import 'package:dealker_vendor/features/returns/data/return_models.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

const _maxProofs = 6;

/// "Tell Dealkr what you think": agree to the return, or dispute it with a note and proof photos.
/// The answer is advice to the Dealkr team — it does not approve, reject or refund anything.
/// Returns the refreshed detail through [Navigator.pop] when sent.
Future<ReturnDetail?> showRespondSheet(BuildContext context, {required String returnId, ReturnResponse? previous}) {
  return showModalBottomSheet<ReturnDetail>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => RespondSheet(returnId: returnId, previous: previous),
  );
}

class RespondSheet extends ConsumerStatefulWidget {
  const RespondSheet({super.key, required this.returnId, this.previous});
  final String returnId;
  final ReturnResponse? previous;

  @override
  ConsumerState<RespondSheet> createState() => _RespondSheetState();
}

class _RespondSheetState extends ConsumerState<RespondSheet> {
  late final TextEditingController _note = TextEditingController(text: widget.previous?.note ?? '');
  late String? _stance = widget.previous?.stance;
  late final List<String> _photos = [
    for (final e in widget.previous?.evidence ?? const <ReturnEvidence>[])
      if (!e.isVideo) e.url
  ];
  int _uploading = 0;
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _ready => _stance != null && _note.text.trim().length >= 3 && _uploading == 0 && !_sending;

  Future<void> _addPhotos() async {
    final room = _maxProofs - _photos.length - _uploading;
    if (room <= 0) return;
    final src = await chooseSource(context, cameraLabel: 'Take a photo', galleryLabel: 'Choose from gallery');
    if (src == null) return;
    final picker = ImagePicker();
    final files = src == ImageSource.camera || room == 1
        ? [if (await picker.pickImage(source: src, imageQuality: 85) case final f?) f]
        : await picker.pickMultiImage(imageQuality: 85, limit: room);
    final repo = ref.read(returnsRepositoryProvider);
    for (final f in files.take(room)) {
      setState(() => _uploading++);
      repo.uploadImage(f.path).then((u) {
        if (mounted) setState(() => _photos.add(u));
      }).catchError((Object e) {
        if (mounted) showAppToast(context, errorText(e, 'Photo upload failed.'), error: true);
      }).whenComplete(() {
        if (mounted) setState(() => _uploading--);
      });
    }
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final d = await ref.read(returnsRepositoryProvider).respond(widget.returnId,
          stance: _stance!, note: _note.text.trim(), evidence: [for (final u in _photos) ReturnEvidence(u, 'IMAGE')]);
      if (mounted) Navigator.of(context).pop(d);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showAppToast(context, errorText(e), error: true);
      }
    }
  }

  Widget _choice(String value, String title, String sub, IconData icon, Color color) {
    final on = _stance == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _stance = value),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? color : AppColors.cardBorder, width: on ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 14),
            const Text('Your answer', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 4),
            const Text(
                'Tell Dealkr what you think. The Dealkr team reads this and makes the final decision — your answer does not refund or reject anything by itself.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35)),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _choice('AGREE', 'I agree', 'The customer is right. Take the item back.', PhosphorIconsFill.checkCircle,
                  AppColors.mint),
              const SizedBox(width: 10),
              _choice('DISPUTE', 'I dispute', 'I sent it fine. I can show proof.', PhosphorIconsFill.shieldWarning,
                  AppColors.rose),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _stance == 'DISPUTE'
                    ? 'What happened? For example: the screen was perfect when I packed it.'
                    : 'A short note for the Dealkr team',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 6),
            Text('Proof photos (${_photos.length}/$_maxProofs) — packing photos, serial number, invoice',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            SizedBox(
              height: 66,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final u in _photos)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(children: [
                      ProductThumb(u, size: 66),
                      Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _photos.remove(u)),
                            child: const CircleAvatar(
                                radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 13, color: Colors.white)),
                          )),
                    ]),
                  ),
                if (_uploading > 0)
                  Container(
                      width: 66,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: const Color(0xFFF1F4FB), borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))),
                if (_photos.length + _uploading < _maxProofs)
                  InkWell(
                    onTap: _addPhotos,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 66,
                      decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderStrong), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(PhosphorIconsRegular.cameraPlus, color: AppColors.primary),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            AuctionButton(label: 'Send answer', loading: _sending, onPressed: _ready ? _send : null),
          ]),
        ),
      ),
    );
  }
}
