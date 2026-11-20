import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Duration kAppRouteLoadingFadeDuration = Duration(milliseconds: 120);

enum AppRouteLoadingPhase {
  hidden,
  fadingIn,
  covered,
  fadingOut,
}

class AppRouteLoadingState {
  const AppRouteLoadingState({
    this.phase = AppRouteLoadingPhase.hidden,
  });

  final AppRouteLoadingPhase phase;

  bool get isVisible => phase != AppRouteLoadingPhase.hidden;

  AppRouteLoadingState copyWith({
    AppRouteLoadingPhase? phase,
  }) {
    return AppRouteLoadingState(
      phase: phase ?? this.phase,
    );
  }
}

class AppRouteLoadingNotifier extends Notifier<AppRouteLoadingState> {

  @override
  AppRouteLoadingState build() {
    return const AppRouteLoadingState();
  }

  /// Switches the footer tab immediately. This used to fade a cover over the
  /// screen (~0.5s of fixed delays) on every tab tap, which made going back
  /// to a tab feel slow even though the tab was already built and cached by
  /// the IndexedStack. The overlay phases remain for API compatibility.
  Future<void> playForFooterNavigation(
    FutureOr<void> Function() onNavigate,
  ) async {
    await onNavigate();
  }
}

final appRouteLoadingProvider =
    NotifierProvider<AppRouteLoadingNotifier, AppRouteLoadingState>(
  AppRouteLoadingNotifier.new,
);

class AppRouteLoadingGate extends ConsumerWidget {
  const AppRouteLoadingGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadingState = ref.watch(appRouteLoadingProvider);
    final phase = loadingState.phase;
    final showOverlay = loadingState.isVisible;
    final targetOpacity = switch (phase) {
      AppRouteLoadingPhase.fadingOut => 0.0,
      AppRouteLoadingPhase.hidden => 0.0,
      AppRouteLoadingPhase.fadingIn => 1.0,
      AppRouteLoadingPhase.covered => 1.0,
    };

    return Stack(
      children: <Widget>[
        child,
        if (showOverlay)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: targetOpacity,
                duration: kAppRouteLoadingFadeDuration,
                curve: Curves.easeInOutCubic,
                // Plain background — no animation widget.
                child: const ColoredBox(
                  color: Color.fromARGB(255, 241, 244, 249),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
