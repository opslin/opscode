import 'package:flutter/widgets.dart';

/// Whether a screen should spend a network request on a periodic refresh right now.
///
/// False while the app is in the background, and while another screen is on top of this one (Flutter turns tickers
/// off for covered routes). Without this, every screen in the navigation stack kept polling in parallel - a vendor
/// four screens deep was refreshing all four, and pocketed phones kept polling too.
///
/// Call from a timer callback of a State: `if (mounted && screenActive(context)) ...`.
bool screenActive(BuildContext context) {
  final life = WidgetsBinding.instance.lifecycleState;
  if (life != null && life != AppLifecycleState.resumed) return false;
  return TickerMode.getValuesNotifier(context).value.enabled;
}
