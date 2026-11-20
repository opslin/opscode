import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:dealker_app/core/theme/app_colors.dart';

/// Presents the existing sign-in flow as a bounded card on wide web screens.
class WebAuthFrame extends StatelessWidget {
  const WebAuthFrame({required this.child, this.isWeb = kIsWeb, super.key});
  final Widget child;
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    if (!isWeb || MediaQuery.sizeOf(context).width < 700) return child;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: LayoutBuilder(builder: (context, constraints) {
        final width = math.min(480.0, math.max(0.0, constraints.maxWidth - 48));
        final height = math.min(760.0, math.max(0.0, constraints.maxHeight - 48));
        return Center(
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: width,
              height: height,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(size: Size(width, height), padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
                child: child,
              ),
            ),
          ),
        );
      }),
    );
  }
}
