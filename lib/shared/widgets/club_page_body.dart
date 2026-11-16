import 'package:flutter/material.dart';

/// Keeps the scroll viewport behind the transparent curve of the fixed header.
class ClubHeaderLayout extends StatelessWidget {
  const ClubHeaderLayout({super.key, required this.header, required this.body});

  final PreferredSizeWidget header;
  final Widget body;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _ClubHeaderScrollBody(
        headerHeight:
            MediaQuery.paddingOf(context).top + header.preferredSize.height,
        body: body,
      ),
      Positioned(top: 0, left: 0, right: 0, child: header),
    ],
  );
}

class _ClubHeaderScrollBody extends StatelessWidget {
  const _ClubHeaderScrollBody({
    required this.headerHeight,
    required this.body,
    this.controller,
  });

  final double headerHeight;
  final Widget body;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => NestedScrollView(
    controller: controller,
    headerSliverBuilder: (context, innerBoxIsScrolled) => [
      SliverToBoxAdapter(child: SizedBox(height: headerHeight)),
    ],
    body: body,
  );
}

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
    this.scrollController,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color backgroundColor;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: appBar,
      extendBodyBehindAppBar: appBar != null,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: appBar == null
          ? body
          : _ClubHeaderScrollBody(
              headerHeight:
                  MediaQuery.paddingOf(context).top +
                  appBar!.preferredSize.height,
              controller: scrollController,
              body: ClubPageBody(color: backgroundColor, child: body),
            ),
    );
    return bottomNavigationBar == null
        ? scaffold
        : ScrollNotificationObserver(child: scaffold);
  }
}
