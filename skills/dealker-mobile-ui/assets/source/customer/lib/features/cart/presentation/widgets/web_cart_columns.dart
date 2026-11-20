import 'package:flutter/material.dart';

/// Keeps cart items and the real order summary readable on wide screens.
class WebCartColumns extends StatelessWidget {
  const WebCartColumns({required this.items, required this.summary, super.key});
  final List<Widget> items;
  final List<Widget> summary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items)),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: summary)),
            ],
          ),
        ),
      ),
    );
  }
}
