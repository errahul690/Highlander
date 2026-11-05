import 'package:flutter/material.dart';

/// The shared content surface below the club header.
class ClubPageBody extends StatelessWidget {
  const ClubPageBody({
    super.key,
    required this.child,
    this.color = Colors.white,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    child: SizedBox.expand(child: child),
  );
}

/// Standard scaffold for pages whose club header is in the app-bar slot.
class ClubScaffold extends StatelessWidget {
  const ClubScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.backgroundColor = Colors.white,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color backgroundColor;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    backgroundColor: backgroundColor,
    resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    bottomNavigationBar: bottomNavigationBar,
    floatingActionButton: floatingActionButton,
    body: appBar == null
        ? body
        : ClubPageBody(color: backgroundColor, child: body),
  );
}
