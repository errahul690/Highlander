import 'dart:async';

import 'package:flutter/material.dart';
import 'package:Highlanders/shared/widgets/startup_loader.dart';

/// Build and prepare the feed behind a loading view before revealing it once.
class FeedLoadingGate extends StatefulWidget {
  const FeedLoadingGate({
    super.key,
    required this.prepare,
    required this.child,
    this.slowAfter = const Duration(seconds: 15),
  });
  final Future<void> Function() prepare;
  final Widget child;
  final Duration slowAfter;

  @override
  State<FeedLoadingGate> createState() => _FeedLoadingGateState();
}

class _FeedLoadingGateState extends State<FeedLoadingGate> {
  bool _ready = false, _slow = false;
  int _attempt = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final attempt = ++_attempt;
    _timer?.cancel();
    _slow = false;
    _timer = Timer(widget.slowAfter, () {
      if (mounted && attempt == _attempt && !_ready) {
        setState(() => _slow = true);
      }
    });
    Future<void>.sync(widget.prepare).then(
      (_) async {
        // Let the already-mounted image widgets consume their warmed cache.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || attempt != _attempt) return;
        _timer?.cancel();
        setState(() => _ready = true);
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted || attempt != _attempt) return;
        _timer?.cancel();
        setState(() => _slow = true);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Offstage(
        offstage: !_ready,
        child: TickerMode(enabled: _ready, child: widget.child),
      ),
      if (!_ready)
        Semantics(
          key: const ValueKey('feed-loading-view'),
          label: 'Loading your feed',
          liveRegion: true,
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: _slow
                  ? IconButton(
                      key: const ValueKey('feed-loading-retry'),
                      tooltip: 'Retry loading feed',
                      onPressed: () => setState(_start),
                      color: Theme.of(context).colorScheme.primary,
                      iconSize: 26,
                      icon: const Icon(Icons.refresh_rounded),
                    )
                  : const StartupLoader(),
            ),
          ),
        ),
    ],
  );
}
