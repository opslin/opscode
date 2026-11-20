import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/application/create_draft.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auctions/presentation/steps/details_step.dart';
import 'package:dealker_vendor/features/auctions/presentation/steps/media_step.dart';
import 'package:dealker_vendor/features/auctions/presentation/steps/product_step.dart';
import 'package:dealker_vendor/features/auctions/presentation/steps/review_step.dart';
import 'package:dealker_vendor/features/auctions/presentation/steps/settings_step.dart';
import 'package:dealker_vendor/features/auctions/presentation/steps/type_step.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

const _titles = {
  CreateStep.type: 'Add Auction',
  CreateStep.product: 'Add Auction · Product',
  CreateStep.details: 'Add Auction · Details',
  CreateStep.settings: 'Add Auction · Settings',
  CreateStep.media: 'Add Auction · Photo, Video & QC',
  CreateStep.review: 'Add Auction · Review',
};

/// 6-step create flow (mockup screens 1–6). All state lives in
/// [createDraftProvider]; this shell owns navigation, validation and submit.
class CreateAuctionScreen extends ConsumerStatefulWidget {
  const CreateAuctionScreen({super.key});

  @override
  ConsumerState<CreateAuctionScreen> createState() =>
      _CreateAuctionScreenState();
}

class _CreateAuctionScreenState extends ConsumerState<CreateAuctionScreen> {
  bool _submitting = false;

  Future<bool> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Discard this auction?'),
        content: const Text('The details you entered will be lost.'),
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
    final draft = ref.read(createDraftProvider);
    final notifier = ref.read(createDraftProvider.notifier);
    if (draft.step.index > 0) {
      notifier.go(CreateStep.values[draft.step.index - 1]);
      return;
    }
    if (draft.product == null || await _confirmExit()) {
      if (mounted) context.pop();
    }
  }

  void _next(CreateDraft d, AuctionRules rules) {
    final n = ref.read(createDraftProvider.notifier);
    final err = switch (d.step) {
      CreateStep.product => d.product == null ? 'Choose a product.' : null,
      CreateStep.details => d.detailsError(),
      CreateStep.settings => d.settingsError(rules),
      CreateStep.media => d.mediaBusy ? 'Uploads are still in progress.' : null,
      _ => null,
    };
    if (err != null) {
      showAppToast(context, err, error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    if (d.step == CreateStep.details) n.defaultFee(rules);
    n.go(CreateStep.values[d.step.index + 1]);
  }

  Future<void> _submit({required bool draft}) async {
    final d = ref.read(createDraftProvider);
    setState(() => _submitting = true);
    try {
      final item = await ref
          .read(auctionRepositoryProvider)
          .create(d.toRequest(draft: draft));
      if (!mounted) return;
      refreshMyAuctions(ref);
      ref.read(createDraftProvider.notifier).reset();
      context.pushReplacement(Routes.auctionCreated, extra: item);
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(createDraftProvider);
    final rules = ref.watch(auctionRulesProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AuctionAppBar(
          title: _titles[d.step]!,
          subtitle: 'Step ${d.step.index + 1} of ${CreateStep.values.length}',
          onBack: _back,
        ),
        body: rules.when(skipLoadingOnReload: true, skipError: true, 
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
              message: errorText(e, 'Could not load auction rules.'),
              onRetry: () => ref.invalidate(auctionRulesProvider)),
          data: (r) => !r.enabled
              ? const EmptyState(
                  icon: PhosphorIconsRegular.gavel,
                  title: 'Auctions are paused',
                  message:
                      'Dealkr has temporarily switched auctions off. Please try again later.')
              : Column(children: [
                  _Progress(d.step.index + 1),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: KeyedSubtree(
                        key: ValueKey(d.step),
                        child: switch (d.step) {
                          CreateStep.type => const TypeStep(),
                          CreateStep.product => const ProductStep(),
                          CreateStep.details => const DetailsStep(),
                          CreateStep.settings => SettingsStep(rules: r),
                          CreateStep.media => const MediaStep(),
                          CreateStep.review =>
                            ReviewStep(rules: r, busy: _submitting),
                        },
                      ),
                    ),
                  ),
                  BottomActionBar(
                    child: d.step == CreateStep.review
                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                            AuctionButton(
                                label: 'Publish Auction',
                                loading: _submitting,
                                onPressed: () => _submit(draft: false)),
                            const SizedBox(height: 8),
                            TextButton(
                                onPressed: _submitting
                                    ? null
                                    : () => _submit(draft: true),
                                child: const Text('Save as draft',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: kAuctionBlue))),
                          ])
                        : AuctionButton(
                            label: 'Next',
                            trailing: PhosphorIconsBold.arrowRight,
                            onPressed: d.step == CreateStep.product &&
                                    d.product == null
                                ? null
                                : () => _next(d, r),
                          ),
                  ),
                ]),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress(this.current);
  final int current;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
        child: Row(children: [
          for (var i = 1; i <= CreateStep.values.length; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(
                    right: i == CreateStep.values.length ? 0 : 5),
                decoration: BoxDecoration(
                  color: i <= current ? kAuctionBlue : AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ]),
      );
}
