import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:dealker_app/shared/widgets/loading/order_placing_loader.dart';

/// Shown right after an order is placed: only the branded "packing" animation
/// (products drop into a parcel, the box closes and hops away), then the order
/// details open on their own.
class OrderSuccessScreen extends ConsumerStatefulWidget {
  const OrderSuccessScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends ConsumerState<OrderSuccessScreen> {
  static const Duration _animation = Duration(milliseconds: 3800);

  final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 900));
  Timer? _timer;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    // Warm the details so they are ready the moment the animation ends.
    ref.read(orderDetailProvider(widget.orderId));
    _timer = Timer(_animation + const Duration(milliseconds: 250), () {
      if (mounted) {
        context.go('/orders/${widget.orderId}');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  void _onClosed() {
    _confetti.play();
    if (mounted) {
      setState(() => _closed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Colors.white, AppColors.brandCream],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  OrderPlacingLoader(
                    size: 170,
                    duration: _animation,
                    repeat: false,
                    onClosed: _onClosed,
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(
                      _closed ? 'Order placed!' : 'Packing your order…',
                      key: ValueKey<bool>(_closed),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandNavy,
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: const Alignment(0, -0.1),
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirection: -math.pi / 2,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0.0,
                  numberOfParticles: 28,
                  maxBlastForce: 22,
                  minBlastForce: 8,
                  gravity: 0.25,
                  colors: const <Color>[
                    AppColors.brandYellow,
                    AppColors.brandNavy,
                    AppColors.brandRose,
                    Color(0xFF8FB4FF),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
