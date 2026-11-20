import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/auth/presentation/widgets/brand_ui.dart';
import 'package:dealker_vendor/features/business_profile/application/business_providers.dart';
import 'package:dealker_vendor/features/business_profile/data/business_models.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/media_widgets.dart'
    show chooseSource;
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// KYC documents: what is on file, what is missing, upload / replace, view, and submit for review.
class KycDocumentsSection extends ConsumerStatefulWidget {
  const KycDocumentsSection({super.key, required this.profile});
  final BusinessProfile profile;

  @override
  ConsumerState<KycDocumentsSection> createState() =>
      _KycDocumentsSectionState();
}

class _KycDocumentsSectionState extends ConsumerState<KycDocumentsSection> {
  String? _busyType;
  bool _submitting = false;

  KycDocument? _doc(String type) {
    final all = widget.profile.documents.where((d) => d.type == type).toList();
    if (all.isEmpty) return null;
    all.sort((a, b) => (b.status == 'VERIFIED' ? 1 : 0)
        .compareTo(a.status == 'VERIFIED' ? 1 : 0));
    return all.first;
  }

  Future<void> _upload(String type) async {
    final id = ref.read(businessVendorIdProvider);
    if (id == null) return;
    final src = await chooseSource(context,
        cameraLabel: 'Take a photo', galleryLabel: 'Choose from gallery');
    if (src == null || !mounted) return;
    final file = await ImagePicker()
        .pickImage(source: src, imageQuality: 85, maxWidth: 2200);
    if (file == null || !mounted) return;
    final number = await _askNumber(type);
    if (number == null || !mounted) return; // cancelled
    setState(() => _busyType = type);
    final repo = ref.read(businessRepositoryProvider);
    try {
      final key = await repo.uploadDocumentFile(id, file.path);
      await repo.attachDocument(id, type: type, fileKey: key, number: number);
      refreshBusinessProfile(ref);
      if (mounted) {
        showAppToast(context, '${KycDocument.labelOf(type)} uploaded.');
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, errorText(e, 'Upload failed. Please try again.'),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busyType = null);
    }
  }

  /// Optional document number; returns null only when the vendor cancels.
  Future<String?> _askNumber(String type) async {
    final c = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(KycDocument.labelOf(type)),
        content: TextField(
          controller: c,
          textCapitalization: TextCapitalization.characters,
          decoration:
              const InputDecoration(labelText: 'Document number (optional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(d, c.text.trim()),
              child: const Text('Upload')),
        ],
      ),
    );
    c.dispose();
    return res;
  }

  Future<void> _view(KycDocument d) async {
    final id = ref.read(businessVendorIdProvider);
    if (id == null || d.id.isEmpty) return;
    try {
      final url =
          await ref.read(businessRepositoryProvider).documentLink(id, d.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(children: [
                  Expanded(child: Text(d.label, style: heading(size: 16))),
                  IconButton(
                      onPressed: () => Navigator.pop(c),
                      icon: const Icon(PhosphorIconsBold.x)),
                ])),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                            'This file is a PDF or cannot be previewed here. Our team can see it.',
                            textAlign: TextAlign.center))),
              ),
            ),
          ]),
        ),
      );
    } catch (e) {
      if (mounted) {
        showAppToast(context, errorText(e, 'Could not open the document.'),
            error: true);
      }
    }
  }

  Future<void> _submit() async {
    final id = ref.read(businessVendorIdProvider);
    if (id == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(businessRepositoryProvider).submitForReview(id);
      refreshBusinessProfile(ref);
      if (mounted) {
        showAppToast(
            context, 'Sent for review. We will notify you once it is checked.');
      }
    } catch (e) {
      // Stop the spinner before the dialog opens (the dialog is awaited, `finally` would run only after it closes).
      if (mounted) setState(() => _submitting = false);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Not ready yet'),
            content: Text(errorText(e, 'Could not submit. Please try again.')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c), child: const Text('OK'))
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final types = [...KycDocument.required, ...KycDocument.optional];
    final underReview =
        p.status == 'KYC_SUBMITTED' || p.status == 'UNDER_REVIEW';
    return HomeCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(PhosphorIconsFill.fileText, size: 20, color: Brand.navy),
          const SizedBox(width: 8),
          Text('KYC documents', style: heading(size: 15.5)),
        ]),
        if (p.canSubmit)
          const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                  'Upload clear photos of your PAN card and GSTIN certificate, fill in your business details above, then submit for review.',
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: AppColors.textMuted))),
        if (underReview)
          const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                  'Your application is with our team. You can still add documents.',
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: AppColors.textMuted))),
        const SizedBox(height: 4),
        for (final t in types) _row(t, _doc(t)),
        if (p.canSubmit) ...[
          const SizedBox(height: 12),
          BrandButton(
              label: p.status == 'CORRECTION_REQUIRED'
                  ? 'Re-submit for review'
                  : 'Submit for review',
              loading: _submitting,
              onPressed: _submit),
        ],
      ]),
    );
  }

  Widget _row(String type, KycDocument? d) {
    final required = KycDocument.required.contains(type);
    final busy = _busyType == type;
    final (label, fg, bg) = switch (d?.status) {
      'VERIFIED' => ('Verified', AppColors.success, const Color(0xFFE3F6EA)),
      'REJECTED' => ('Rejected', AppColors.rose, AppColors.roseSoft),
      'PENDING' => (
          'In review',
          const Color(0xFFB45309),
          const Color(0xFFFFF1D6)
        ),
      _ => (
          required ? 'Required' : 'Not added',
          AppColors.textMuted,
          const Color(0xFFF1F4FB)
        ),
    };
    final canUpload = d?.status != 'VERIFIED';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(KycDocument.labelOf(type),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (d?.reason != null)
              Text(d!.reason!,
                  style: const TextStyle(fontSize: 12, color: AppColors.rose))
            else if (d?.number != null)
              Text(d!.number!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 6),
            Wrap(spacing: 10, children: [
              if (d != null && d.viewable)
                GestureDetector(
                    onTap: () => _view(d),
                    child: const Text('View',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kAuctionBlue))),
              if (canUpload)
                GestureDetector(
                    onTap: busy ? null : () => _upload(type),
                    child: Text(
                        busy
                            ? 'Uploading…'
                            : d == null
                                ? 'Upload'
                                : 'Replace',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: busy ? AppColors.textMuted : Brand.navy))),
            ]),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          child: Text(label,
              style: TextStyle(
                  color: fg, fontWeight: FontWeight.w800, fontSize: 11.5)),
        ),
      ]),
    );
  }
}
