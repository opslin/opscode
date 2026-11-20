import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_draft.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/data/product_models.dart';
import 'package:dealker_vendor/features/products/presentation/steps/checklist_step.dart';
import 'package:dealker_vendor/features/products/presentation/steps/details_step.dart';
import 'package:dealker_vendor/features/products/presentation/steps/device_qc_step.dart';
import 'package:dealker_vendor/features/products/presentation/steps/media_step.dart';
import 'package:dealker_vendor/features/products/presentation/steps/photo_qc_step.dart';
import 'package:dealker_vendor/features/products/presentation/steps/pricing_steps.dart';
import 'package:dealker_vendor/features/products/presentation/steps/summary_step.dart';
import 'package:dealker_vendor/features/products/presentation/steps/video_qc_step.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

const _titles = {
  AddStep.details: 'Add Product',
  AddStep.media: 'Upload Photos & Videos',
  AddStep.checklist: 'QC Checklist',
  AddStep.deviceQc: 'Device QC',
  AddStep.photoQc: 'Photo QC',
  AddStep.videoQc: 'Video QC',
  AddStep.b2b: 'B2B Update',
  AddStep.b2c: 'B2C Update',
  AddStep.summary: 'Product Summary',
};

/// The 8-step Add Product flow. All state lives in [addDraftProvider]; this
/// shell owns navigation, per-step validation and the final submit.
class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  bool _submitting = false;
  bool _returnToSummary =
      false; // after "Edit" on the summary, Next goes straight back

  Future<bool> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Discard this product?'),
        content: const Text('The details and photos you added will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep editing')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Discard',
                  style: TextStyle(color: AppColors.rose))),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _back() async {
    final d = ref.read(addDraftProvider);
    final n = ref.read(addDraftProvider.notifier);
    if (d.stepIndex > 0) {
      n.go(d.steps[d.stepIndex - 1]);
      return;
    }
    final touched =
        d.brand.isNotEmpty || d.model.isNotEmpty || d.images.isNotEmpty;
    if (!touched || await _confirmExit()) {
      if (mounted) context.pop();
    }
  }

  void _next() {
    final d = ref.read(addDraftProvider);
    final err = d.errorFor(d.step);
    if (err != null) {
      showAppToast(context, err, error: true, bottom: 96);
      return;
    }
    FocusScope.of(context).unfocus();
    final n = ref.read(addDraftProvider.notifier);
    if (_returnToSummary && d.step != AddStep.summary) {
      n.go(AddStep.summary);
      return;
    }
    n.go(d.steps[d.stepIndex + 1]);
  }

  Future<void> _submit() async {
    final d = ref.read(addDraftProvider);
    // Re-check every step so a jump-back edit can't leave something invalid.
    for (final s in d.steps) {
      final e = d.errorFor(s);
      if (e != null) {
        ref.read(addDraftProvider.notifier).go(s);
        showAppToast(context, e, error: true, bottom: 96);
        return;
      }
    }
    setState(() => _submitting = true);
    try {
      final cats = await ref.read(categoriesProvider.future);
      final cat = categoryFor(d.type, cats);
      if (cat == null) {
        throw StateError('No product category is available yet.');
      }
      final item = await ref
          .read(productRepositoryProvider)
          .create(d.toRequest(categoryId: cat.id));
      if (!mounted) return;
      refreshProducts(ref);
      ref.read(addDraftProvider.notifier).reset();
      context.pushReplacement(Routes.productSubmitted, extra: item);
    } catch (e) {
      if (mounted) {
        await showFailureDialog(
            context,
            e is StateError
                ? (title: 'Couldn’t submit', message: e.message)
                : explainFailure(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(addDraftProvider);
    final readiness = ref.watch(readinessProvider).asData?.value;
    final blocked = readiness?.blocks ?? false;
    ref.listen(addDraftProvider.select((x) => x.step), (prev, next) {
      if (next == AddStep.summary) {
        _returnToSummary = false;
      } else if (prev == AddStep.summary) {
        _returnToSummary = true;
      }
    });

    final last = d.step == AddStep.summary;
    final label = last
        ? 'Submit for Approval'
        : (d.step == AddStep.videoQc && !d.hasVideo ? 'Skip' : 'Next');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AuctionAppBar(
          title: _titles[d.step]!,
          subtitle: 'Step ${d.stepIndex + 1} of ${d.steps.length}',
          onBack: _back,
        ),
        body: Column(children: [
          _Progress(current: d.stepIndex + 1, total: d.steps.length),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(d.step),
                child: switch (d.step) {
                  AddStep.details => const DetailsStep(),
                  AddStep.media => const MediaStep(),
                  AddStep.checklist => const ChecklistStep(),
                  AddStep.deviceQc => const DeviceQcStep(),
                  AddStep.photoQc => const PhotoQcStep(),
                  AddStep.videoQc => const VideoQcStep(),
                  AddStep.b2b => const B2bStep(),
                  AddStep.b2c => const B2cStep(),
                  AddStep.summary => const SummaryStep(),
                },
              ),
            ),
          ),
          BottomActionBar(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (blocked && d.step == AddStep.details)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                      'You can’t list products until the issue above is fixed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: AppColors.rose)),
                ),
              AuctionButton(
                label: label,
                trailing: last
                    ? PhosphorIconsBold.paperPlaneTilt
                    : PhosphorIconsBold.arrowRight,
                loading: _submitting,
                onPressed: blocked && d.step == AddStep.details
                    ? null
                    : (last ? _submit : _next),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
        child: Row(children: [
          for (var i = 1; i <= total; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                margin: EdgeInsets.only(right: i == total ? 0 : 5),
                decoration: BoxDecoration(
                  color: i <= current ? kBlue : AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ]),
      );
}
