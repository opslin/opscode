import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';

OverlayEntry? _current;

/// Every message (success, error, undo) slides in from the TOP of the screen, over the app bar, so it never
/// hides — or sits next to — the sticky action buttons at the bottom. [bottom] is kept for old call sites.
void showAppToast(BuildContext context, String message,
    {bool error = false, double bottom = 16}) {
  _show(context, message, error: error);
}

/// Toast with an UNDO action (remove from cart, delete…). Replaces the previous toast if one is showing.
void showUndoBar(BuildContext context, String message, VoidCallback onUndo,
    {double bottom = 16}) {
  _show(context, message,
      undo: onUndo, duration: const Duration(seconds: 5));
}

void _show(BuildContext context, String message,
    {bool error = false,
    VoidCallback? undo,
    Duration duration = const Duration(milliseconds: 3500)}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _current?.remove();
  _current = null;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastOverlay(
      message: message,
      error: error,
      undo: undo,
      duration: duration,
      onDone: () {
        if (entry.mounted) entry.remove();
        if (_current == entry) _current = null;
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.message,
    required this.error,
    required this.undo,
    required this.duration,
    required this.onDone,
  });

  final String message;
  final bool error;
  final VoidCallback? undo;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  late final Animation<Offset> _slide = Tween<Offset>(
          begin: const Offset(0, -1.4), end: Offset.zero)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _c.reverse();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.error ? AppColors.error : AppColors.success;
    final icon = widget.error
        ? PhosphorIconsFill.warningCircle
        : PhosphorIconsFill.checkCircle;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: SlideTransition(
                position: _slide,
                child: Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.up,
                  onDismissed: (_) => widget.onDone(),
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                            accent.withValues(alpha: 0.10), Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.35), width: 1.2),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 18,
                              offset: Offset(0, 6)),
                        ],
                      ),
                      child: Row(children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: accent, shape: BoxShape.circle),
                          child: Icon(icon, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(widget.message,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  height: 1.3,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (widget.undo != null)
                          TextButton(
                            onPressed: () {
                              widget.undo!();
                              _dismiss();
                            },
                            child: const Text('UNDO',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800)),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
