import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show errorText;
import 'package:dealker_vendor/features/orders/application/orders_providers.dart';
import 'package:dealker_vendor/features/orders/data/order_models.dart';
import 'package:dealker_vendor/features/orders/data/orders_repository.dart';
import 'package:dealker_vendor/features/orders/presentation/widgets/invoice_sheet.dart';
import 'package:dealker_vendor/features/orders/presentation/widgets/ship_sheet.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// Packing needs the seller's own invoice. Uploads it first when the order has none; false = vendor backed out.
Future<bool> _ensureInvoice(
    BuildContext context, OrdersRepository repo, String id) async {
  final d = await repo.detail(id);
  if (d.hasInvoice) return true;
  if (!context.mounted) return false;
  final up = await showInvoiceSheet(context, orderNumber: d.number);
  if (up == null) return false;
  await repo.uploadInvoice(id, up.file, number: up.number);
  return true;
}

void refreshOrders(WidgetRef ref, {String? id}) {
  ref.invalidate(ordersProvider);
  ref.invalidate(ordersNeedActionProvider);
  if (id != null) {
    ref.invalidate(orderDetailProvider(id));
    ref.invalidate(repairDetailProvider(id));
  }
}

/// One-tap work on an order. Returns true when something changed on the server.
/// `qc` and `estimate` need more than a tap, so callers open the detail screen for those.
Future<bool> runOrderAction(
  BuildContext context,
  WidgetRef ref, {
  required OrderKind kind,
  required String id,
  required String key,
}) async {
  final repo = ref.read(ordersRepositoryProvider);
  try {
    String done;
    if (kind == OrderKind.repair) {
      await repo.repairAction(id, key);
      done = switch (key) {
        'receive' => 'Device received — inspection started.',
        'start' => 'Repair started.',
        'send-to-qc' => 'Sent to QC.',
        'ready' => 'Marked ready.',
        'deliver' => 'Handed over. Job completed.',
        _ => 'Updated.',
      };
    } else {
      switch (key) {
        case 'confirm':
          await repo.setStatus(id, 'CONFIRMED');
          done = 'Order accepted — the buyer can see it.';
        case 'pack':
          if (!await _ensureInvoice(context, repo, id)) return false;
          await repo.setStatus(id, 'PACKED');
          done = 'Packed — the buyer can see it. Ship it next.';
        case 'ship':
          // orders packed before invoices were required still need one before they leave
          if (!await _ensureInvoice(context, repo, id)) return false;
          if (!context.mounted) return false;
          final s = await showShipSheet(context);
          if (s == null) return false;
          await repo.ship(id,
              courier: s.courier, awb: s.awb, trackingUrl: s.trackingUrl);
          done = 'Shipped — tracking sent to the buyer.';
        default:
          return false;
      }
    }
    refreshOrders(ref, id: id);
    if (context.mounted) showAppToast(context, done);
    return true;
  } catch (e) {
    if (context.mounted) showAppToast(context, errorText(e), error: true);
    return false;
  }
}
