import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

Future<void> configureWebVideoFullscreen(
  BuildContext context,
  WebViewController controller,
) async {
  final platform = controller.platform;
  if (platform is! AndroidWebViewController) return;
  Route<void>? fullscreenRoute;
  NavigatorState? navigator;
  await platform.setCustomWidgetCallbacks(
    onShowCustomWidget: (video, onHidden) async {
      if (!context.mounted || fullscreenRoute != null) {
        onHidden();
        return;
      }
      navigator = Navigator.of(context, rootNavigator: true);
      final route = MaterialPageRoute<void>(
        builder: (_) => WebVideoFullscreen(child: video),
        fullscreenDialog: true,
      );
      fullscreenRoute = route;
      try {
        await navigator!.push(route);
      } finally {
        fullscreenRoute = null;
        onHidden();
      }
    },
    onHideCustomWidget: () {
      final route = fullscreenRoute;
      if (route != null && route.isActive && navigator?.mounted == true) {
        navigator!.removeRoute(route);
      }
    },
  );
}

class WebVideoFullscreen extends StatefulWidget {
  const WebVideoFullscreen({super.key, required this.child});
  final Widget child;

  @override
  State<WebVideoFullscreen> createState() => _WebVideoFullscreenState();
}

class _WebVideoFullscreenState extends State<WebVideoFullscreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SizedBox.expand(child: widget.child),
  );
}
