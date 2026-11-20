import 'package:flutter/material.dart';

import 'package:dealker_app/core/utils/app_toast.dart';

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Messages always appear at the top of the screen (see AppToast), never over the bottom action buttons.
  void showSnack(String message) => AppToast.show(this, message);

  void showErrorSnack(String message) =>
      AppToast.show(this, message, type: ToastType.error);
}
