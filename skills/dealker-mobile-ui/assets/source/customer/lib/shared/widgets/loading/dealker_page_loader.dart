import 'package:flutter/material.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_loading_screen.dart';

/// Drop-in replacement for `Center(child: CircularProgressIndicator())` on a
/// whole page. Waits a beat before showing (fast loads never flash it), scales
/// down to fit tight spaces, and picks the creative loader for [kind].
class DealkerPageLoader extends StatefulWidget {
  const DealkerPageLoader({
    this.kind = DealkerLoadingKind.page,
    this.message,
    this.delay = const Duration(milliseconds: 220),
    super.key,
  });

  final DealkerLoadingKind kind;
  final String? message;
  final Duration delay;

  @override
  State<DealkerPageLoader> createState() => _DealkerPageLoaderState();
}

class _DealkerPageLoaderState extends State<DealkerPageLoader> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Widget loader = AnimatedOpacity(
          opacity: _show ? 1 : 0,
          duration: const Duration(milliseconds: 240),
          child: _show
              ? DealkerLoader(kind: widget.kind, message: widget.message)
              : const SizedBox.shrink(),
        );
        final bool bounded = constraints.hasBoundedHeight &&
            constraints.hasBoundedWidth;
        return Center(
          child: bounded
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 300,
                    child: Center(child: loader),
                  ),
                )
              : loader,
        );
      },
    );
  }
}
