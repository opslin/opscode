import 'package:flutter/material.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/shared/widgets/loading/jumping_items_loader.dart';
import 'package:dealker_app/shared/widgets/loading/order_placing_loader.dart';
import 'package:dealker_app/shared/widgets/loading/payment_loader.dart';
import 'package:dealker_app/shared/widgets/loading/spin_showcase_loader.dart';

/// Which creative loader to show — each situation gets its own animation.
enum DealkerLoadingKind { page, product, payment, order }

class DealkerLoader extends StatelessWidget {
  const DealkerLoader({required this.kind, this.message, super.key});

  final DealkerLoadingKind kind;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final Widget loader = switch (kind) {
      DealkerLoadingKind.page => const JumpingItemsLoader(),
      DealkerLoadingKind.product => const SpinShowcaseLoader(),
      DealkerLoadingKind.payment => const PaymentLoader(),
      DealkerLoadingKind.order => const OrderPlacingLoader(),
    };
    final String? text = message ??
        switch (kind) {
          DealkerLoadingKind.page => 'Loading…',
          DealkerLoadingKind.product => 'Opening product…',
          DealkerLoadingKind.payment => null, // the payment loader has its own
          DealkerLoadingKind.order => 'Placing your order…',
        };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        loader,
        if (text != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(text, style: kLoaderTitle),
        ],
      ],
    );
  }
}

/// Full-screen branded loading page.
class DealkerLoadingScreen extends StatelessWidget {
  const DealkerLoadingScreen({
    this.kind = DealkerLoadingKind.page,
    this.message,
    super.key,
  });

  final DealkerLoadingKind kind;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandCream,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Colors.white, AppColors.brandCream],
          ),
        ),
        child: Center(child: DealkerLoader(kind: kind, message: message)),
      ),
    );
  }
}

/// Blocks the screen with a loader while [task] runs (e.g. payment, order).
/// Closes itself when the task completes or throws.
Future<T> runWithDealkerLoader<T>(
  BuildContext context, {
  required DealkerLoadingKind kind,
  required Future<T> Function() task,
  String? message,
}) async {
  final NavigatorState nav = Navigator.of(context, rootNavigator: true);
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xB3FFFFFF),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x26001F5F), blurRadius: 40, offset: Offset(0, 12)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: DealkerLoader(kind: kind, message: message),
          ),
        ),
      ),
    ),
  );
  try {
    return await task();
  } finally {
    if (nav.mounted) nav.pop();
  }
}

/// Dimmed full-screen overlay holding the creative payment / order loader.
/// Stack it above a screen while an order or payment is being processed.
class DealkerProcessingOverlay extends StatelessWidget {
  const DealkerProcessingOverlay({required this.kind, super.key});

  final DealkerLoadingKind kind;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: Container(
        color: const Color(0xE6FFFFFF),
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: DealkerLoader(kind: kind),
        ),
      ),
    );
  }
}
