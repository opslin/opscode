import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/data/product_catalog.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';

/// Step 4 — tell Dealkr which photo shows which side, and declare scratches.
/// Front and Back are mandatory; the rest are recommended.
class PhotoQcStep extends ConsumerStatefulWidget {
  const PhotoQcStep({super.key});

  @override
  ConsumerState<PhotoQcStep> createState() => _PhotoQcStepState();
}

class _PhotoQcStepState extends ConsumerState<PhotoQcStep> {
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(addDraftProvider);
    final n = ref.read(addDraftProvider.notifier);
    if (d.images.isEmpty) {
      return const EmptyState(
          icon: PhosphorIconsRegular.camera,
          title: 'No photos yet',
          message: 'Go back and add photos first.');
    }
    final sel = _sel.clamp(0, d.images.length - 1);
    final url = d.images[sel];
    final current = d.angles[url];
    String? labelOf(String key) =>
        kPhotoAngles.where((a) => a.key == key).firstOrNull?.label;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        Text('Mark each side', style: heading(size: 19)),
        const SizedBox(height: 4),
        const Text(
            'Pick a photo, then tap the side it shows. Front and Back are required.',
            style: TextStyle(
                fontSize: 13.5, height: 1.35, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        AspectRatio(
          aspectRatio: 1.25,
          child: Stack(fit: StackFit.expand, children: [
            Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.cardBorder),
                    borderRadius: BorderRadius.circular(18)),
                child: AnyImage(url, fit: BoxFit.contain, radius: 18)),
            if (current != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(9)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(PhosphorIconsBold.check,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(labelOf(current) ?? current,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5)),
                  ]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 62,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: d.images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => _sel = i),
              child: Container(
                width: 62,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: i == sel ? kBlue : Colors.transparent, width: 2),
                ),
                child: Stack(fit: StackFit.expand, children: [
                  AnyImage(d.images[i], radius: 9),
                  if (d.angles[d.images[i]] != null)
                    const Positioned(
                      right: 2,
                      top: 2,
                      child: Icon(PhosphorIconsFill.checkCircle,
                          size: 17, color: AppColors.mint),
                    ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in kPhotoAngles)
            GestureDetector(
              onTap: () => n.tagAngle(url, a.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: current == a.key
                      ? kBlue
                      : (d.angles.containsValue(a.key)
                          ? AppColors.mintSoft
                          : Colors.white),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: current == a.key
                          ? kBlue
                          : (d.angles.containsValue(a.key)
                              ? AppColors.mint
                              : AppColors.border),
                      width: 1.3),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (d.angles.containsValue(a.key) && current != a.key)
                      const Padding(
                        padding: EdgeInsets.only(right: 5),
                        child: Icon(PhosphorIconsBold.check,
                            size: 13, color: AppColors.mint),
                      ),
                    Text(a.required ? '${a.label} *' : a.label,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: current == a.key
                                ? Colors.white
                                : AppColors.navy)),
                  ]),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 22),
        Text('Scratches & marks', style: heading(size: 17)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _Choice(
              icon: PhosphorIconsFill.sealCheck,
              label: 'No major scratches',
              selected: d.scratchChoice == true,
              color: AppColors.mint,
              onTap: () => n.set((x) => x.copyWith(scratchChoice: true)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Choice(
              icon: PhosphorIconsFill.warning,
              label: 'Has marks',
              selected: d.scratchChoice == false,
              color: const Color(0xFFB45309),
              onTap: () => n.set((x) => x.copyWith(scratchChoice: false)),
            ),
          ),
        ]),
        if (d.scratchChoice == false) ...[
          const SizedBox(height: 12),
          AuctionField(
            initial: d.photoNote,
            maxLines: 2,
            maxLength: 200,
            hint: 'Where are the marks? e.g. small dent on the top-left',
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) => n.set((x) => x.copyWith(photoNote: v)),
          ),
        ],
        const SizedBox(height: 14),
        NoteBanner(
            '${d.taggedAngles} of ${kPhotoAngles.length} sides marked'
            '${d.frontBackTagged ? '' : ' — Front and Back are still needed'}.',
            icon: d.frontBackTagged
                ? PhosphorIconsFill.checkCircle
                : PhosphorIconsFill.info,
            fg: d.frontBackTagged ? AppColors.mint : kBlue,
            bg: d.frontBackTagged ? AppColors.mintSoft : kBlueSoft),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? color : AppColors.border,
                width: selected ? 1.8 : 1.2),
          ),
          child: Row(children: [
            Icon(icon, size: 22, color: selected ? color : AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color:
                          selected ? AppColors.navy : AppColors.textSecondary)),
            ),
          ]),
        ),
      );
}
