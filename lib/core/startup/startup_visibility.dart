import 'package:flutter/widgets.dart';

/// Keeps the welcome clock stopped while its prebuilt page is behind splash.
class StartupVisibility extends InheritedNotifier<ValueNotifier<bool>> {
  const StartupVisibility({
    super.key,
    required ValueNotifier<bool> visible,
    required super.child,
  }) : super(notifier: visible);

  static bool isVisible(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<StartupVisibility>()
          ?.notifier
          ?.value ??
      true;
}
