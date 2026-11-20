import 'package:flutter/widgets.dart';

/// Tells [onChanged] whether this subtree is on screen: false while another opaque route (a pushed screen) covers
/// it, true again when it is uncovered. Flutter turns tickers off for covered routes, which is exactly the signal
/// needed, and it costs nothing (no observers, no timers).
class VisibilityReporter extends StatefulWidget {
  const VisibilityReporter(
      {super.key, required this.onChanged, required this.child});

  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  State<VisibilityReporter> createState() => _VisibilityReporterState();
}

class _VisibilityReporterState extends State<VisibilityReporter> {
  bool? _last;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on = TickerMode.valuesOf(context).enabled;
    if (on == _last) return;
    _last = on;
    // Not during build: providers must not change while the tree is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _last == on) widget.onChanged(on);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
