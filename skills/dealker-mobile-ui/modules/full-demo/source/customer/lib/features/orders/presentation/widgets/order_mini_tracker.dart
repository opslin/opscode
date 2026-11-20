import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dealker_app/features/orders/presentation/widgets/order_theme.dart';
import 'package:dealker_app/features/orders/presentation/widgets/order_ui.dart';

/// Slim six-step progress bar for an active order: the stage the order is at
/// is marked by its 3D icon (rocket, scooter, box…) floating above the bar.
class OrderMiniTracker extends StatelessWidget {
  const OrderMiniTracker({required this.stage, super.key});

  /// 0..5 — see [OrderPhaseX.stageIndex].
  final int stage;

  @override
  Widget build(BuildContext context) {
    final double iconSize = 34.w;
    return LayoutBuilder(
      builder: (context, c) {
        final double w = c.maxWidth;
        final double seg = w / 6;
        final double left =
            (seg * stage + seg / 2 - iconSize / 2).clamp(0.0, w - iconSize);
        return SizedBox(
          height: iconSize + 14.h,
          child: Stack(
            children: <Widget>[
              Positioned(
                left: left,
                top: 0,
                child: CartArtImage(kStageArt[stage.clamp(0, 5)],
                    size: iconSize, float: true),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 2.h,
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < 6; i++)
                      Expanded(
                        child: Container(
                          height: 5.h,
                          margin: EdgeInsets.only(right: i == 5 ? 0 : 4.w),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5.r),
                            color: i <= stage
                                ? (i == stage ? AU.indigo : AU.indigo)
                                : AU.indigoSoft,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
