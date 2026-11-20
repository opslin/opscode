import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dealker_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';
import 'package:dealker_app/features/refund_requests/presentation/widgets/return_ui.dart';
import 'package:dealker_app/shared/widgets/marketplace_product_box.dart';

/// Courier pickup of the returned item (design 7). Status steps from Shiprocket / Porter / our team — no live map.
class ReturnPickupCard extends StatelessWidget {
  const ReturnPickupCard({required this.pickup, super.key});

  final ReturnPickup pickup;

  static const Map<String, String> _title = <String, String>{
    'PICKUP_SCHEDULED': 'Pickup Scheduled',
    'PICKED_UP': 'Item Picked Up',
    'IN_TRANSIT': 'Item On Its Way',
    'RECEIVED': 'Item Received',
    'FAILED': 'Pickup Problem',
    'CANCELLED': 'Pickup Cancelled',
  };

  String _sub() {
    final String by = pickup.courierName ?? _partner(pickup.provider);
    switch (pickup.status) {
      case 'PICKUP_SCHEDULED':
        return pickup.scheduledAt == null
            ? 'Our courier will collect the item from your address. Keep it packed with all accessories.'
            : 'Pickup is planned for ${returnDate(pickup.scheduledAt)}. Keep the item packed with all accessories.';
      case 'PICKED_UP':
        return 'Your item has been picked up${by.isEmpty ? '' : ' by $by'}.';
      case 'IN_TRANSIT':
        return 'Your item is on its way to our centre.';
      case 'RECEIVED':
        return 'We received your item at our centre.';
      default:
        return 'The pickup could not be completed. Our team will contact you.';
    }
  }

  static String _partner(String? p) => switch (p) {
        'SHIPROCKET' => 'Shiprocket',
        'PORTER' => 'Porter',
        'BLUEDART' => 'Blue Dart',
        _ => '',
      };

  String _next() {
    switch (pickup.status) {
      case 'PICKUP_SCHEDULED':
        return 'Hand the item over to the pickup person. We will update the status here once it is collected.';
      case 'PICKED_UP':
      case 'IN_TRANSIT':
        return 'The item will be received at our centre for a quality check and final verification.';
      case 'RECEIVED':
        return 'Our team is inspecting the item. You will see the quality report here shortly.';
      default:
        return 'Chat with support and we will arrange the pickup again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool bad = pickup.isFailed;
    final Color tone = bad ? ReturnColors.red : ReturnColors.green;
    return Column(
      children: <Widget>[
        ReturnCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    bad ? Icons.error_rounded : Icons.check_circle_rounded,
                    size: 28.sp,
                    color: tone,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _title[pickup.status] ?? 'Pickup',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: ReturnColors.ink,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          _sub(),
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
              if (pickup.awb != null) ...<Widget>[
                SizedBox(height: 12.h),
                const Divider(height: 1, color: ReturnColors.line),
                SizedBox(height: 12.h),
                _kv('Tracking ID', pickup.awb!),
              ],
              if (pickup.scheduledAt != null ||
                  pickup.pickedUpAt != null) ...<Widget>[
                SizedBox(height: 10.h),
                _kv(
                  'Pickup Date',
                  returnDate(pickup.pickedUpAt ?? pickup.scheduledAt),
                ),
              ],
              if (pickup.trackingUrl != null) ...<Widget>[
                SizedBox(height: 12.h),
                ReturnPrimaryButton(
                  label: 'Track Shipment',
                  icon: Icons.open_in_new_rounded,
                  onPressed: () => launchUrl(
                    Uri.parse(pickup.trackingUrl!),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 12.h),
        ReturnCard(
          color: ReturnColors.indigoSoft.withValues(alpha: 0.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.info_outline_rounded,
                size: 18.sp,
                color: ReturnColors.indigo,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Next Step',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: ReturnColors.ink,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _next(),
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
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(k, style: TextStyle(fontSize: 11.sp, color: ReturnColors.muted)),
          SizedBox(height: 2.h),
          Text(
            v,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: ReturnColors.ink,
            ),
          ),
        ],
      );
}

/// Quality-check report + price update (design 8). The customer accepts the new price or asks a question.
class ReturnQcCard extends StatelessWidget {
  const ReturnQcCard({
    required this.qc,
    required this.canAnswer,
    required this.refunded,
    required this.busy,
    required this.onAccept,
    required this.onClarify,
    super.key,
  });

  final ReturnQc qc;

  /// The request is still open, so the customer can still answer.
  final bool canAnswer;

  /// The refund was already paid: no stepper, no "will be processed" wording.
  final bool refunded;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onClarify;

  @override
  Widget build(BuildContext context) {
    final int step =
        qc.priceStatus == 'PROPOSED' || qc.priceStatus == 'CLARIFICATION'
            ? 1
            : qc.priceStatus == 'ACCEPTED'
                ? 2
                : 0;
    return Column(
      children: <Widget>[
        if (!refunded) ...<Widget>[
          ReturnStepper(
            labels: const <String>['QC Check', 'Price Update', 'Confirm'],
            current: step,
          ),
          SizedBox(height: 14.h),
        ],
        ReturnCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 26.sp,
                    color: ReturnColors.green,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Device QC Check',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: ReturnColors.ink,
                          ),
                        ),
                        Text(
                          qc.summary ?? 'We have checked your item.',
                          style: TextStyle(
                            fontSize: 11.sp,
                            height: 1.35,
                            color: ReturnColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Text(
                'QC Report',
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w800,
                  color: ReturnColors.ink,
                ),
              ),
              SizedBox(height: 8.h),
              for (final ReturnQcCheck c in qc.checks) _QcRow(check: c),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        ReturnCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Price Update',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: ReturnColors.ink,
                ),
              ),
              SizedBox(height: 10.h),
              _price(
                'Original Price',
                qc.originalPrice,
                strike: qc.hasPriceChange,
              ),
              SizedBox(height: 6.h),
              _price(
                'Price After Inspection',
                qc.revisedPrice ?? qc.originalPrice,
                bold: true,
              ),
              SizedBox(height: 10.h),
              _priceMessage(),
              if (canAnswer && qc.needsAnswer) ...<Widget>[
                SizedBox(height: 12.h),
                ReturnPrimaryButton(
                  label: 'Accept New Price',
                  busy: busy,
                  onPressed: onAccept,
                ),
                SizedBox(height: 8.h),
                ReturnPrimaryButton(
                  label: 'Request Clarification',
                  outlined: true,
                  onPressed: busy ? null : onClarify,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _priceMessage() {
    switch (qc.priceStatus) {
      case 'PROPOSED':
        return const ReturnNote(
          icon: Icons.error_outline_rounded,
          color: ReturnColors.red,
          background: ReturnColors.redSoft,
          text: 'Price changed after QC. Please confirm the updated price.',
        );
      case 'CLARIFICATION':
        return const ReturnNote(
          icon: Icons.chat_bubble_outline_rounded,
          text:
              'We got your question. Our team will reply in chat, after which you can accept the price.',
        );
      case 'ACCEPTED':
        return const ReturnNote(
          icon: Icons.check_circle_outline_rounded,
          color: ReturnColors.green,
          background: ReturnColors.greenSoft,
          text:
              'You accepted the new price. Your refund will be processed shortly.',
        );
      default:
        return const ReturnNote(
          icon: Icons.check_circle_outline_rounded,
          color: ReturnColors.green,
          background: ReturnColors.greenSoft,
          text:
              'Your item passed the quality check. Your refund will be processed shortly.',
        );
    }
  }

  Widget _price(String k, double v, {bool bold = false, bool strike = false}) =>
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              k,
              style: TextStyle(fontSize: 12.sp, color: ReturnColors.muted),
            ),
          ),
          Text(
            MarketplaceProductBox.inr(v),
            style: TextStyle(
              fontSize: bold ? 15.sp : 12.sp,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: strike ? ReturnColors.muted : ReturnColors.ink,
              decoration: strike ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      );
}

class _QcRow extends StatelessWidget {
  const _QcRow({required this.check});

  final ReturnQcCheck check;

  @override
  Widget build(BuildContext context) {
    final (Color c, IconData i, String t) = switch (check.status) {
      'MINOR_ISSUE' => (
          ReturnColors.amber,
          Icons.warning_amber_rounded,
          'Minor Issue'
        ),
      'FAILED' => (ReturnColors.red, Icons.cancel_rounded, 'Failed'),
      _ => (ReturnColors.green, Icons.check_circle_outline_rounded, 'OK'),
    };
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  check.label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: ReturnColors.ink,
                  ),
                ),
                if (check.note != null)
                  Text(
                    check.note!,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: ReturnColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          Icon(i, size: 16.sp, color: c),
          SizedBox(width: 4.w),
          Text(
            t,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}
