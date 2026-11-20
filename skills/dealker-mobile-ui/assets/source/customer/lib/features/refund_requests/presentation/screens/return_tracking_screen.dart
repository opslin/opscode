import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/orders/domain/entities/order_entity.dart';
import 'package:dealker_app/features/reviews/presentation/screens/order_review_screen.dart';
import 'package:dealker_app/features/refund_requests/data/return_chat_repository.dart';
import 'package:dealker_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';
import 'package:dealker_app/features/refund_requests/presentation/providers/return_providers.dart';
import 'package:dealker_app/features/refund_requests/presentation/widgets/return_stage_cards.dart';
import 'package:dealker_app/features/refund_requests/presentation/providers/refund_request_provider.dart';
import 'package:dealker_app/features/refund_requests/presentation/screens/return_routes.dart';
import 'package:dealker_app/features/refund_requests/presentation/widgets/return_ui.dart';
import 'package:dealker_app/routing/route_names.dart';
import 'package:dealker_app/shared/widgets/marketplace_product_box.dart';

const List<String> _stepLabels = <String>[
  'Requested',
  'Approved',
  'Picked Up',
  'In Transit',
  'Received',
];

/// Where a pending return is: index of the last finished step on the 5-step tracker (0 = only Requested).
int _doneUpTo(RefundRequestStatusEntity r) {
  final String? ps = r.pickup?.status;
  if (ps == 'RECEIVED' || r.qc != null) return 4;
  if (ps == 'IN_TRANSIT') return 3;
  if (ps == 'PICKED_UP') return 2;
  if (r.returnApprovedAt != null || r.pickup != null) return 1;
  return 0;
}

/// Headline + sentence for a pending return, from what the server really knows.
({String title, String sub, bool bad}) _pendingStage(
  RefundRequestStatusEntity r,
) {
  final ReturnQc? q = r.qc;
  if (q != null) {
    switch (q.priceStatus) {
      case 'PROPOSED':
        return (
          title: 'Confirm the New Price',
          sub:
              'We checked your item and the refund amount changed. Please accept it or ask us a question.',
          bad: false
        );
      case 'CLARIFICATION':
        return (
          title: 'We Got Your Question',
          sub:
              'Our team will answer in chat. After that you can accept the price.',
          bad: false
        );
      case 'ACCEPTED':
        return (
          title: 'New Price Accepted',
          sub: 'Thanks! Your refund is being processed.',
          bad: false
        );
      default:
        return (
          title: 'Quality Check Passed',
          sub: 'Your item passed the check. Your refund is being processed.',
          bad: false
        );
    }
  }
  final ReturnPickup? p = r.pickup;
  if (p != null) {
    switch (p.status) {
      case 'PICKED_UP':
        return (
          title: 'Item Picked Up',
          sub: 'Your item has been picked up and is heading to our centre.',
          bad: false
        );
      case 'IN_TRANSIT':
        return (
          title: 'Item On Its Way',
          sub: 'Your item is on its way to our centre for the quality check.',
          bad: false
        );
      case 'RECEIVED':
        return (
          title: 'Item Received',
          sub: 'We received your item and will inspect it shortly.',
          bad: false
        );
      case 'FAILED':
      case 'CANCELLED':
        return (
          title: 'Pickup Problem',
          sub:
              'The pickup could not be completed. Chat with us and we will arrange it again.',
          bad: true
        );
      default:
        return (
          title: 'Return Approved',
          sub: 'Your return is approved. The pickup is scheduled.',
          bad: false
        );
    }
  }
  if (r.returnApprovedAt != null) {
    return (
      title: 'Return Approved',
      sub: 'Your return is approved. We are arranging the pickup.',
      bad: false
    );
  }
  return (
    title: 'Return Review In Progress',
    sub:
        'Your return request has been received. Our team is reviewing it and will update you here.',
    bad: false
  );
}

/// Return tracking (`docs/design/02-return-flow.jpg` screens 6, 9, 10, 11): where the request is, the
/// vendor's answer, the refund once approved, and the journey so far. Refreshes itself while open.
class ReturnTrackingScreen extends ConsumerStatefulWidget {
  const ReturnTrackingScreen({required this.order, super.key});

  final OrderEntity order;

  @override
  ConsumerState<ReturnTrackingScreen> createState() =>
      _ReturnTrackingScreenState();
}

class _ReturnTrackingScreenState extends ConsumerState<ReturnTrackingScreen> {
  Timer? _poll;
  bool _cancelling = false;
  bool _answering = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      ref.invalidate(refundRequestByOrderProvider(widget.order.id));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _cancel(RefundRequestStatusEntity r) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Cancel this return?'),
        content: const Text(
          'Your return request will be withdrawn. You can raise a new one later.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _cancelling = true);
    final RefundRequestActionResult res =
        await ref.read(refundRequestProvider.notifier).cancelRequest(r.id);
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (!res.isSuccess) {
      AppToast.show(context, res.failure!.message);
      return;
    }
    ref.invalidate(refundRequestByOrderProvider(widget.order.id));
  }

  Future<void> _acceptPrice(RefundRequestStatusEntity r) async {
    setState(() => _answering = true);
    try {
      await ref.read(returnPolicyRepositoryProvider).acceptPrice(r.id);
      ref.invalidate(refundRequestByOrderProvider(widget.order.id));
      if (mounted) {
        AppToast.show(context, 'New price accepted', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) AppToast.show(context, ReturnChatRepository.errorMessage(e));
    } finally {
      if (mounted) setState(() => _answering = false);
    }
  }

  Future<void> _askAboutPrice(RefundRequestStatusEntity r) async {
    final TextEditingController text = TextEditingController();
    final String? msg = await showDialog<String>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Ask about the new price'),
        content: TextField(
          controller: text,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'What would you like to know?',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(text.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    text.dispose();
    if (msg == null || !mounted) return;
    setState(() => _answering = true);
    try {
      await ref.read(returnPolicyRepositoryProvider).askAboutPrice(
            r.id,
            msg.isEmpty ? 'I would like to understand the new price.' : msg,
          );
      ref.invalidate(refundRequestByOrderProvider(widget.order.id));
      if (mounted) {
        AppToast.show(
          context,
          'Question sent to the team',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) AppToast.show(context, ReturnChatRepository.errorMessage(e));
    } finally {
      if (mounted) setState(() => _answering = false);
    }
  }

  void _openChat(RefundRequestStatusEntity r) {
    context.push(ReturnRoutes.chat(widget.order.id));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RefundRequestStatusEntity?> async =
        ref.watch(refundRequestByOrderProvider(widget.order.id));
    final RefundRequestStatusEntity? r = async.asData?.value;
    final String title =
        r?.isApproved == true ? 'Refund Summary' : 'Return Tracking';
    return ReturnScaffold(
      title: title,
      child: RefreshIndicator(
        color: ReturnColors.indigo,
        onRefresh: () async {
          ref.invalidate(refundRequestByOrderProvider(widget.order.id));
          await ref.read(refundRequestByOrderProvider(widget.order.id).future);
        },
        child: async.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => r != null
              ? _content(r)
              : const DealkerPageLoader(),
          error: (Object e, StackTrace _) => r != null
              ? _content(r)
              : ListView(
                  children: <Widget>[
                    SizedBox(height: 120.h),
                    Center(
                      child: Column(
                        children: <Widget>[
                          const Text('Could not load your return.'),
                          TextButton(
                            onPressed: () => ref.invalidate(
                              refundRequestByOrderProvider(widget.order.id),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          data: (RefundRequestStatusEntity? v) => v == null
              ? ListView(
                  children: <Widget>[
                    SizedBox(height: 120.h),
                    const Center(
                      child: Text('No return request for this order.'),
                    ),
                  ],
                )
              : _content(v),
        ),
      ),
    );
  }

  Widget _content(RefundRequestStatusEntity r) {
    final bool tracked = r.isPending;
    final int doneUpTo = _doneUpTo(r);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      children: <Widget>[
        if (tracked) ...<Widget>[
          ReturnStepper(
            labels: _stepLabels,
            current: doneUpTo + 1,
            allDoneUpTo: doneUpTo,
            useTicks: true,
          ),
          SizedBox(height: 16.h),
        ],
        // The pickup card carries its own headline (design 7), so skip the generic status card there.
        if (!(r.isPending && r.pickup != null && r.qc == null)) ...<Widget>[
          _StatusCard(request: r),
          SizedBox(height: 12.h),
        ],
        if (r.pickup != null && !r.isApproved && r.qc == null) ...<Widget>[
          ReturnPickupCard(pickup: r.pickup!),
          SizedBox(height: 12.h),
        ],
        if (r.qc != null) ...<Widget>[
          ReturnQcCard(
            qc: r.qc!,
            canAnswer: r.isPending,
            refunded: r.isApproved,
            busy: _answering,
            onAccept: () => _acceptPrice(r),
            onClarify: () => _askAboutPrice(r),
          ),
          SizedBox(height: 12.h),
        ],
        if (r.isApproved) ..._refundDetails(r) else ..._trackingInfo(r),
        if (r.evidence.isNotEmpty) ...<Widget>[
          SizedBox(height: 12.h),
          _EvidenceCard(evidence: r.evidence),
        ],
        SizedBox(height: 14.h),
        ..._actions(r),
        if (r.timeline.isNotEmpty) ...<Widget>[
          SizedBox(height: 18.h),
          _JourneyCard(steps: r.timeline),
        ],
      ],
    );
  }

  List<Widget> _trackingInfo(RefundRequestStatusEntity r) {
    return <Widget>[
      ReturnCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _kv('Tracking ID', r.returnNumber ?? '', big: true),
            SizedBox(height: 12.h),
            _kv('Requested On', returnDate(r.createdAt), big: true),
            if (r.reasonCode != null) ...<Widget>[
              SizedBox(height: 12.h),
              _kv(
                'Reason',
                ReturnReason.byCode(r.reasonCode)?.title ?? r.description,
                big: true,
              ),
            ],
          ],
        ),
      ),
      SizedBox(height: 12.h),
      ReturnCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.storefront_rounded,
                  size: 18,
                  color: ReturnColors.indigo,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Vendor Response',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: ReturnColors.ink,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: ReturnColors.indigoSoft.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 18.r,
                    backgroundColor: ReturnColors.indigoLine,
                    child: const Icon(
                      Icons.person_rounded,
                      color: ReturnColors.indigo,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          r.sellerName ?? 'Dealkr Support',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: ReturnColors.ink,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          r.isPending
                              ? 'Reviewing your return request'
                              : (r.adminNote ??
                                  (r.isRejected
                                      ? 'Your return request was not approved.'
                                      : 'You cancelled this return request.')),
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
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _refundDetails(RefundRequestStatusEntity r) {
    final String to =
        r.refundTo == 'wallet' ? 'Wallet' : 'Original payment method';
    return <Widget>[
      ReturnCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Refund Details',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: ReturnColors.ink,
              ),
            ),
            SizedBox(height: 12.h),
            _row('Order ID', r.orderNumber ?? widget.order.orderNumber),
            if (r.refundAmount != null)
              _row(
                'Refund Amount',
                MarketplaceProductBox.inr(r.refundAmount!),
                bold: true,
              ),
            if (r.refundReference != null)
              _row('Transaction ID', _transactionId(r.refundReference!)),
            _row('Refund Date', returnDate(r.refundedAt ?? r.resolvedAt)),
          ],
        ),
      ),
      SizedBox(height: 12.h),
      ReturnCard(
        color: ReturnColors.indigoSoft.withValues(alpha: 0.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Amount Credited To',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: ReturnColors.muted,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: <Widget>[
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 22.sp,
                  color: ReturnColors.indigo,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    to,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: ReturnColors.ink,
                    ),
                  ),
                ),
                if (r.refundAmount != null)
                  Text(
                    MarketplaceProductBox.inr(r.refundAmount!),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: ReturnColors.ink,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _actions(RefundRequestStatusEntity r) {
    return <Widget>[
      if (r.isApproved) ...<Widget>[
        if (r.refundTo == 'wallet') ...<Widget>[
          ReturnPrimaryButton(
            label: 'View Wallet',
            onPressed: () => GoRouter.of(context).push(RouteNames.wallet),
          ),
          SizedBox(height: 10.h),
        ],
        ReturnPrimaryButton(
          label: 'Write a Review',
          outlined: r.refundTo == 'wallet',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<bool>(
              builder: (_) => OrderReviewScreen(order: widget.order),
            ),
          ),
        ),
      ] else
        ReturnPrimaryButton(
          label: 'Chat with Support',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: () => _openChat(r),
        ),
      if (r.isPending) ...<Widget>[
        SizedBox(height: 10.h),
        ReturnPrimaryButton(
          label: 'Cancel Return',
          outlined: true,
          busy: _cancelling,
          onPressed: () => _cancel(r),
        ),
      ],
      SizedBox(height: 10.h),
      ReturnPrimaryButton(
        label: 'View Order Details',
        outlined: true,
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go('/orders/${widget.order.id}'),
      ),
      if (r.isApproved) ...<Widget>[
        SizedBox(height: 10.h),
        Center(
          child: TextButton.icon(
            onPressed: () => _openChat(r),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
            label: const Text('Chat with Support'),
            style: TextButton.styleFrom(foregroundColor: ReturnColors.indigo),
          ),
        ),
      ],
    ];
  }

  /// Wallet credits are stored as `wallet:<request id>`; show a short code instead of the raw id.
  static String _transactionId(String ref) {
    if (!ref.startsWith('wallet:')) return ref;
    final String id = ref.substring(7).replaceAll('-', '');
    return 'WLT${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}';
  }

  Widget _kv(String k, String v, {bool big = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(k, style: TextStyle(fontSize: 11.sp, color: ReturnColors.muted)),
          SizedBox(height: 2.h),
          Text(
            v,
            style: TextStyle(
              fontSize: big ? 15.sp : 12.sp,
              fontWeight: FontWeight.w800,
              color: ReturnColors.ink,
            ),
          ),
        ],
      );

  Widget _row(String k, String v, {bool bold = false}) => Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              k,
              style: TextStyle(fontSize: 12.sp, color: ReturnColors.muted),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                v,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: bold ? 15.sp : 11.5.sp,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: ReturnColors.ink,
                ),
              ),
            ),
          ],
        ),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.request});

  final RefundRequestStatusEntity request;

  @override
  Widget build(BuildContext context) {
    final RefundRequestStatusEntity r = request;
    final bool stageBad = r.isPending && _pendingStage(r).bad;
    final Color color = r.isApproved
        ? ReturnColors.green
        : r.isPending
            ? (stageBad ? ReturnColors.red : ReturnColors.green)
            : r.isRejected
                ? ReturnColors.red
                : ReturnColors.muted;
    final Color bg = r.isApproved || (r.isPending && !stageBad)
        ? ReturnColors.greenSoft
        : stageBad
            ? ReturnColors.redSoft
            : r.isRejected
                ? ReturnColors.redSoft
                : const Color(0xFFF3F4F8);
    final stage = _pendingStage(r);
    final String title = r.isApproved
        ? 'Return Completed Successfully!'
        : r.isPending
            ? stage.title
            : r.isRejected
                ? 'Return Not Approved'
                : 'Return Cancelled';
    final String sub = r.isApproved
        ? (r.refundTo == 'wallet'
            ? 'Your return has been processed and refund has been credited to your wallet.'
            : 'Your return has been processed and the refund is on its way to your original payment method.')
        : r.isPending
            ? stage.sub
            : r.isRejected
                ? (r.adminNote ?? 'Your return request was not approved.')
                : 'You withdrew this return request.';
    final IconData icon = r.isApproved || r.isPending
        ? Icons.check_circle_rounded
        : r.isRejected
            ? Icons.cancel_rounded
            : Icons.remove_circle_rounded;
    if (r.isApproved) {
      return Column(
        children: <Widget>[
          SizedBox(height: 4.h),
          Icon(icon, size: 56.sp, color: color),
          SizedBox(height: 10.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: ReturnColors.green,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5.sp,
              height: 1.4,
              color: ReturnColors.muted,
            ),
          ),
        ],
      );
    }
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 26.sp, color: color),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w800,
                    color: ReturnColors.ink,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 11.sp,
                    height: 1.4,
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

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.steps});

  final List<ReturnTimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return ReturnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Return Journey',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: ReturnColors.ink,
            ),
          ),
          SizedBox(height: 14.h),
          for (int i = 0; i < steps.length; i++)
            _JourneyRow(step: steps[i], last: i == steps.length - 1),
        ],
      ),
    );
  }
}

class _JourneyRow extends StatelessWidget {
  const _JourneyRow({required this.step, required this.last});

  final ReturnTimelineStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final bool bad = step.key == 'REJECTED';
    final bool muted = step.key == 'CANCELLED';
    final Color c = step.current
        ? ReturnColors.amber
        : bad
            ? ReturnColors.red
            : muted
                ? ReturnColors.muted
                : ReturnColors.green;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 24.w,
            child: Column(
              children: <Widget>[
                Container(
                  width: 20.w,
                  height: 20.w,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c),
                  child: Icon(
                    step.current
                        ? Icons.more_horiz_rounded
                        : bad
                            ? Icons.close_rounded
                            : Icons.check_rounded,
                    size: 13.sp,
                    color: Colors.white,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: ReturnColors.line),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: ReturnColors.ink,
                    ),
                  ),
                  if (step.at != null)
                    Text(
                      returnDate(step.at),
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        color: ReturnColors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.evidence});

  final List<ReturnEvidence> evidence;

  @override
  Widget build(BuildContext context) {
    return ReturnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Photos & video you sent',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: ReturnColors.ink,
            ),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            height: 74.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: evidence.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (BuildContext c, int i) {
                final ReturnEvidence e = evidence[i];
                final String url = ApiConstants.resolveMediaUrl(e.url) ?? e.url;
                return GestureDetector(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => e.isVideo
                        ? _VideoDialog(url: url)
                        : _ImageDialog(url: url),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: SizedBox(
                      width: 74.h,
                      height: 74.h,
                      child: e.isVideo
                          ? ColoredBox(
                              color: Colors.black,
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                size: 30.sp,
                                color: Colors.white,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: webImageSource(url),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const ColoredBox(
                                color: ReturnColors.line,
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageDialog extends StatelessWidget {
  const _ImageDialog({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.all(12.w),
      child: InteractiveViewer(
        child: CachedNetworkImage(
            imageUrl: webImageSource(url), fit: BoxFit.contain),
      ),
    );
  }
}

class _VideoDialog extends StatefulWidget {
  const _VideoDialog({required this.url});

  final String url;

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  late final VideoPlayerController _c =
      VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _c.play();
          }
        });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.all(12.w),
      child: _c.value.isInitialized
          ? GestureDetector(
              onTap: () =>
                  setState(() => _c.value.isPlaying ? _c.pause() : _c.play()),
              child: AspectRatio(
                aspectRatio: _c.value.aspectRatio,
                child: VideoPlayer(_c),
              ),
            )
          : SizedBox(
              height: 200.h,
              child: const DealkerPageLoader(),
            ),
    );
  }
}
