import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/realtime/live_service.dart';
import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/routing/app_router.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// Slides a banner in from the top when the server pushes something over the live socket (a new order, a sell
/// offer, a chat message ...). Until now those events only refetched lists silently: the vendor got no sign that
/// anything had arrived unless that exact list happened to be open.
///
/// Wrap the app with it via `MaterialApp.router(builder: ...)`. Shows for 5 s, tap opens the relevant list.
class LiveBanner extends ConsumerStatefulWidget {
  const LiveBanner({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LiveBanner> createState() => _LiveBannerState();
}

class _LiveBannerState extends ConsumerState<LiveBanner> {
  Map<String, dynamic>? _shown;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _show(Map<String, dynamic> e) {
    _hide?.cancel();
    setState(() => _shown = e);
    _hide = Timer(const Duration(seconds: 5), _dismiss);
  }

  void _dismiss() {
    _hide?.cancel();
    if (mounted && _shown != null) {
      setState(() => _shown = null);
    }
  }

  void _open(Map<String, dynamic> e) {
    final route = switch ('${e['kind'] ?? ''}') {
      'order' => Routes.orders,
      'sell' => Routes.sellLeads,
      'chat' when '${e['requestId'] ?? ''}'.isNotEmpty =>
        Routes.repairChat('${e['requestId']}'),
      _ => Routes.notifications,
    };
    _dismiss();
    ref.read(routerProvider).push(route);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Map<String, dynamic>?>(liveEventProvider, (_, e) {
      if (e != null) _show(e);
    });
    final e = _shown;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 12,
          right: 12,
          top: MediaQuery.paddingOf(context).top + 8,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, -0.4), end: Offset.zero)
                    .animate(a),
                child: c,
              ),
            ),
            child: e == null
                ? const SizedBox.shrink(key: ValueKey('none'))
                : _BannerCard(
                    key: ValueKey('${e['title']}|${e['body']}|${e['at']}'),
                    title: '${e['title'] ?? 'New update'}',
                    body: '${e['body'] ?? ''}',
                    onTap: () => _open(e),
                    onClose: _dismiss,
                  ),
          ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard(
      {super.key,
      required this.title,
      required this.body,
      required this.onTap,
      required this.onClose});
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 18,
                    offset: Offset(0, 8))
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: AppColors.amber, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5)),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12.5)),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 20),
                ),
              ],
            ),
          ),
        ),
      );
}
