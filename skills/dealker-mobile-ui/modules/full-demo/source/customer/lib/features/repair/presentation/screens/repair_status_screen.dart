import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/features/repair/presentation/screens/repair_complete_view.dart';
import 'package:dealker_app/features/repair/presentation/screens/repair_quotes_screen.dart';
import 'package:dealker_app/features/repair/presentation/screens/repair_revised_view.dart';
import 'package:dealker_app/features/repair/presentation/screens/repair_tracking_view.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_ui.dart';
import 'package:dealker_app/features/repair/repair_models.dart';
import 'package:dealker_app/features/repair/repair_providers.dart';

/// `/repair/:id` — opens the right page for where the request is: choosing a
/// shop (nearby shops list), revised price (13), completed (14) or tracking (11 / 12).
/// Refreshes itself every 25 seconds while it is open.
class RepairStatusScreen extends ConsumerStatefulWidget {
  const RepairStatusScreen({required this.repairId, super.key});

  final String repairId;

  @override
  ConsumerState<RepairStatusScreen> createState() => _RepairStatusScreenState();
}

class _RepairStatusScreenState extends ConsumerState<RepairStatusScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 25), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    ref.invalidate(repairRequestProvider(widget.repairId));
    ref.invalidate(repairTrackingProvider(widget.repairId));
    ref.invalidate(repairOffersProvider('${widget.repairId}|best'));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RepairRequest> req =
        ref.watch(repairRequestProvider(widget.repairId));
    // Keep showing the last page while a background refresh runs.
    final RepairRequest? r = req.asData?.value;
    if (r != null) {
      if (r.awaitingOffers) {
        return RepairQuotesScreen(repairId: r.id);
      }
      if (r.revisedPricePending) return RepairRevisedView(request: r);
      if (r.completed) return RepairCompleteView(request: r);
      return RepairTrackingView(request: r, onRefresh: _refresh);
    }
    return RepairShell(
      title: 'Repair',
      body: req.hasError
          ? RErrorView(
              offline: isOfflineError(req.error!),
              onRetry: () =>
                  ref.invalidate(repairRequestProvider(widget.repairId)),
            )
          : const RSkeletonCards(),
    );
  }
}
