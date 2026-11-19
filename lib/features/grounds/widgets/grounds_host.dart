import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:Highlanders/features/grounds/screens/grounds_screen.dart';
import 'package:Highlanders/core/theme/app_motion.dart';

/// Keeps the actual map surface laid out and painted behind the main app.
/// Offstage/IndexedStack would keep Dart state but skip painting the WebView.
class GroundsHost extends StatefulWidget {
  const GroundsHost({super.key, required this.child, this.groundsBuilder});

  final Widget child;
  final Widget Function(BuildContext context, bool active)? groundsBuilder;

  static bool open(BuildContext context) {
    final host = context.findAncestorStateOfType<_GroundsHostState>();
    if (host == null || !host._supported) return false;
    host._open();
    return true;
  }

  @override
  State<GroundsHost> createState() => _GroundsHostState();
}

class _GroundsHostState extends State<GroundsHost> {
  bool _warm = false;
  bool _visible = false;
  bool _foregroundOffstage = false;
  bool _disposed = false;
  LocalHistoryEntry? _history;

  bool get _supported =>
      widget.groundsBuilder != null || WebViewPlatform.instance != null;

  @override
  void initState() {
    super.initState();
    // Give the main app its first frame, then create the map once per session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _supported) setState(() => _warm = true);
    });
  }

  void _open() {
    if (_visible) return;
    _history = LocalHistoryEntry(
      onRemove: () {
        _history = null;
        if (mounted && !_disposed) {
          setState(() {
            _visible = false;
            _foregroundOffstage = false;
          });
        }
      },
    );
    ModalRoute.of(context)!.addLocalHistoryEntry(_history!);
    setState(() {
      _warm = true;
      _visible = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void dispose() {
    _disposed = true;
    _history?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (_warm)
        ExcludeFocus(
          excluding: !_visible,
          child: ExcludeSemantics(
            excluding: !_visible,
            child: IgnorePointer(
              ignoring: !_visible,
              child:
                  widget.groundsBuilder?.call(context, _visible) ??
                  GroundsScreen(active: _visible),
            ),
          ),
        ),
      // Only the foreground app is offstage; the map continues to paint.
      Offstage(
        offstage: _foregroundOffstage,
        child: IgnorePointer(
          ignoring: _visible,
          child: ExcludeSemantics(
            excluding: _visible,
            child: AnimatedOpacity(
              opacity: _visible ? 0 : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : appMotionDuration,
              curve: appMotionCurve,
              onEnd: () {
                if (mounted && _foregroundOffstage != _visible) {
                  setState(() => _foregroundOffstage = _visible);
                }
              },
              child: RepaintBoundary(child: widget.child),
            ),
          ),
        ),
      ),
    ],
  );
}
