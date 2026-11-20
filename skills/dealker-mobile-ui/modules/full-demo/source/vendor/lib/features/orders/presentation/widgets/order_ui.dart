import 'package:flutter/material.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/orders/data/order_models.dart';

/// Colour + label for a kind (Product / Auction / Repair).
({Color fg, Color bg}) kindColors(OrderKind k) => switch (k) {
      OrderKind.product => (
          fg: const Color(0xFF1F6FEB),
          bg: const Color(0xFFE9F1FF)
        ),
      OrderKind.auction => (
          fg: const Color(0xFF7C3AED),
          bg: const Color(0xFFF1EAFF)
        ),
      OrderKind.repair => (
          fg: const Color(0xFFD97706),
          bg: const Color(0xFFFFF1DC)
        ),
    };

class KindBadge extends StatelessWidget {
  const KindBadge(this.kind, {super.key});
  final OrderKind kind;

  @override
  Widget build(BuildContext context) {
    final c = kindColors(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(7)),
      child: Text(kind.label.toUpperCase(),
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
              color: c.fg)),
    );
  }
}

/// Human wording for a raw status.
String statusLabel(String status, {bool awaitingPayment = false}) {
  if (awaitingPayment) return 'Awaiting payment';
  return switch (status.toUpperCase()) {
    'ORDER_PLACED' => 'New order',
    'CONFIRMED' => 'Confirmed',
    'PACKED' => 'Packed',
    'READY_TO_SHIP' => 'Ready to ship',
    'SHIPPED' => 'Shipped',
    'OUT_FOR_DELIVERY' => 'Out for delivery',
    'DELIVERED' => 'Delivered',
    'CANCELLED' => 'Cancelled',
    'RETURNED' => 'Returned',
    'REQUESTED' => 'New request',
    'ACCEPTED' => 'Accepted — receive device',
    'INSPECTION' => 'Inspection',
    'ESTIMATE_SENT' => 'Estimate sent',
    'ESTIMATE_APPROVED' => 'Estimate approved',
    'IN_REPAIR' => 'In repair',
    'QC_PENDING' => 'Waiting for QC',
    'REPAIRED' => 'Repaired',
    'READY_FOR_DELIVERY' => 'Ready for pickup',
    'COMPLETED' => 'Completed',
    'ESTIMATE_REJECTED' => 'Estimate rejected',
    'FAILED' => 'Could not repair',
    'REJECTED' => 'Rejected',
    final s => s.replaceAll('_', ' ').toLowerCase(),
  };
}

({Color fg, Color bg}) stageColors(String stage) => switch (stage) {
      'NEW' => (fg: const Color(0xFFB45309), bg: AppColors.amberSoft),
      'ACTIVE' => (fg: const Color(0xFF1F6FEB), bg: const Color(0xFFE9F1FF)),
      'SHIPPED' => (fg: const Color(0xFF7C3AED), bg: const Color(0xFFF1EAFF)),
      'DONE' => (fg: AppColors.mint, bg: AppColors.mintSoft),
      _ => (fg: AppColors.textSecondary, bg: const Color(0xFFEFF1F6)),
    };

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, this.stage, {super.key});
  final String label;
  final String stage;

  @override
  Widget build(BuildContext context) {
    final c = stageColors(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: c.fg)),
    );
  }
}
