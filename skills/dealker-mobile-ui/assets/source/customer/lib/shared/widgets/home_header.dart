import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/providers/store_provider.dart';
import 'package:dealker_app/core/theme/remote_theme_model.dart';

/// Home top row (design `01-home.jpg`, block 1): `⚡ N minutes` + tappable
/// address line on the left, circular profile button on the right.
/// Sizes are design pixels (914 px wide reference) scaled to the device width.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({
    required this.addressText,
    required this.onAddressTap,
    required this.onProfileTap,
    this.topBarTheme,
    this.deliveryEtaMinutes,
    this.topPaddingOverride,
    super.key,
  });

  final String addressText;
  final VoidCallback onAddressTap;
  final VoidCallback onProfileTap;
  final TopBarTheme? topBarTheme;

  /// Admin-set delivery-time badge (`fee_settings.delivery_eta_minutes`).
  final int? deliveryEtaMinutes;

  /// When something already occupies the status-bar area above this header
  /// (e.g. the order-tracking banner) it passes 0 here to avoid a doubled gap.
  final double? topPaddingOverride;

  static const double _designWidth = 914;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double k = MediaQuery.sizeOf(context).width / _designWidth;
    final double topInset =
        topPaddingOverride ?? MediaQuery.paddingOf(context).top;
    final String subtitle = ref.watch(selectedStoreProvider).subtitle;
    final String etaText =
        deliveryEtaMinutes != null ? '$deliveryEtaMinutes minutes' : subtitle;
    final Color textColor = topBarTheme?.textColor ?? Colors.black;
    // Follows the store palette's header text so it stays visible on dark tabs.
    final Color avatarColor = topBarTheme?.textColor ?? Colors.black;

    return Container(
      width: double.infinity,
      color: topBarTheme?.backgroundColor,
      padding: EdgeInsets.fromLTRB(38 * k, topInset + 6 * k, 38 * k, 14 * k),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (etaText.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.bolt, size: 46 * k, color: textColor),
                      SizedBox(width: 6 * k),
                      Flexible(
                        child: Text(
                          etaText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 44 * k,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                            letterSpacing: -0.5 * k,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 2 * k),
                GestureDetector(
                  onTap: onAddressTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          addressText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 25 * k,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ),
                      SizedBox(width: 14 * k),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 34 * k, color: textColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12 * k),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onProfileTap();
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 68 * k,
              height: 68 * k,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: avatarColor, width: 4 * k),
              ),
              child: Icon(Icons.person, size: 44 * k, color: avatarColor),
            ),
          ),
        ],
      ),
    );
  }
}
