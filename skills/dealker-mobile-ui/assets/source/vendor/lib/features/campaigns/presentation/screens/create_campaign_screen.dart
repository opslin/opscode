import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/campaigns/application/campaign_draft.dart';
import 'package:dealker_vendor/features/campaigns/application/campaign_providers.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';
import 'package:dealker_vendor/features/campaigns/presentation/steps/bidding_step.dart';
import 'package:dealker_vendor/features/campaigns/presentation/steps/details_step.dart';
import 'package:dealker_vendor/features/campaigns/presentation/steps/products_step.dart';
import 'package:dealker_vendor/features/campaigns/presentation/steps/review_step.dart';
import 'package:dealker_vendor/features/campaigns/presentation/steps/type_step.dart';
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

const _titles = {
  CampaignStep.type: 'Create Campaign',
  CampaignStep.details: 'Campaign Details',
  CampaignStep.products: 'Choose Products',
  CampaignStep.bidding: 'Bid & Keywords',
  CampaignStep.review: 'Review & Launch',
};

/// 5-step create flow. All state lives in [campaignDraftProvider]; this shell
/// owns navigation, validation and submit.
class CreateCampaignScreen extends ConsumerStatefulWidget {
  const CreateCampaignScreen({super.key});

  @override
  ConsumerState<CreateCampaignScreen> createState() =>
      _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends ConsumerState<CreateCampaignScreen> {
  bool _submitting = false;

  Future<bool> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Discard this campaign?'),
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

  bool _touched(CampaignDraft d) =>
      d.name.trim().isNotEmpty ||
      d.products.isNotEmpty ||
      d.dailyBudget.isNotEmpty;

  Future<void> _back() async {
    final d = ref.read(campaignDraftProvider);
    if (d.step.index > 0) {
      ref
          .read(campaignDraftProvider.notifier)
          .go(CampaignStep.values[d.step.index - 1]);
      return;
    }
    if (!_touched(d) || await _confirmExit()) {
      if (mounted) context.pop();
    }
  }

  void _next(CampaignDraft d, AdRules rules) {
    final err = switch (d.step) {
      CampaignStep.details => d.detailsError(rules),
      CampaignStep.products => d.productsError(rules),
      CampaignStep.bidding => d.biddingError(rules),
      _ => null,
    };
    if (err != null) {
      showAppToast(context, err, error: true, bottom: 90);
      return;
    }
    FocusScope.of(context).unfocus();
    final n = ref.read(campaignDraftProvider.notifier);
    final next = CampaignStep.values[d.step.index + 1];
    if (next == CampaignStep.details) n.ensureStart();
    n.go(next);
  }

  Future<void> _submit({required bool submit}) async {
    final d = ref.read(campaignDraftProvider);
    setState(() => _submitting = true);
    try {
      final created = await ref
          .read(campaignRepositoryProvider)
          .create(d.toRequest(submit: submit));
      if (!mounted) return;
      refreshCampaigns(ref);
      // The draft provider auto-disposes when this screen leaves, so a new
      // campaign always starts empty — and a failed save keeps the draft.
      context.pushReplacement(Routes.campaignCreated, extra: created);
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true, bottom: 90);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(campaignDraftProvider);
    final rules = ref.watch(adRulesProvider);
    final total = CampaignStep.values.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AuctionAppBar(
          title: _titles[d.step]!,
          subtitle: 'Step ${d.step.index + 1} of $total',
          onBack: _back,
        ),
        body: rules.when(skipLoadingOnReload: true, skipError: true, 
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
              message: errorText(e, 'Could not load advertising rules.'),
              onRetry: () => ref.invalidate(adRulesProvider)),
          data: (r) => !r.enabled
              ? const EmptyState(
                  icon: PhosphorIconsRegular.megaphone,
                  title: 'Advertising is paused',
                  message:
                      'Dealkr has temporarily switched sponsored ads off. Please try again later.')
              : Column(children: [
                  _Progress(d.step.index + 1, total),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: KeyedSubtree(
                        key: ValueKey(d.step),
                        child: switch (d.step) {
                          CampaignStep.type => const TypeStep(),
                          CampaignStep.details => DetailsStep(rules: r),
                          CampaignStep.products => ProductsStep(rules: r),
                          CampaignStep.bidding => BiddingStep(rules: r),
                          CampaignStep.review => ReviewStep(rules: r),
                        },
                      ),
                    ),
                  ),
                  BottomActionBar(
                    child: d.step == CampaignStep.review
                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                            AuctionButton(
                                label: r.requiresApproval
                                    ? 'Submit for approval'
                                    : 'Launch campaign',
                                icon: PhosphorIconsBold.rocketLaunch,
                                loading: _submitting,
                                onPressed: () => _submit(submit: true)),
                            const SizedBox(height: 6),
                            TextButton(
                                onPressed: _submitting
                                    ? null
                                    : () => _submit(submit: false),
                                child: const Text('Save as draft',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: kAdBlue))),
                          ])
                        : AuctionButton(
                            label: 'Next',
                            trailing: PhosphorIconsBold.arrowRight,
                            onPressed: () => _next(d, r),
                          ),
                  ),
                ]),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress(this.current, this.total);
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
        child: Row(children: [
          for (var i = 1; i <= total; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == total ? 0 : 5),
                decoration: BoxDecoration(
                  color: i <= current ? kAdBlue : AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ]),
      );
}
