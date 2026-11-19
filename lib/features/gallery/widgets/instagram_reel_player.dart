import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class InstagramReelPlayer extends StatefulWidget {
  const InstagramReelPlayer({super.key, required this.permalink});
  final Uri permalink;

  @override
  State<InstagramReelPlayer> createState() => _InstagramReelPlayerState();
}

class _InstagramReelPlayerState extends State<InstagramReelPlayer>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == true && mounted) {
                setState(() {
                  _failed = true;
                  _loading = false;
                });
              }
            },
            onNavigationRequest: (request) {
              if (request.url == 'about:blank') {
                return NavigationDecision.navigate;
              }
              if (!request.isMainFrame) return NavigationDecision.navigate;
              final uri = Uri.tryParse(request.url);
              return uri?.scheme == 'https' &&
                      uri?.host == 'www.instagram.com' &&
                      uri?.path == '${widget.permalink.path}embed/'
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            },
          ),
        );
      if (!mounted) return;
      setState(() => _controller = controller);
      await controller.loadRequest(widget.permalink.resolve('embed/'));
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  void _pause() {
    _controller
        ?.runJavaScript(
          'document.querySelectorAll("video").forEach(function(v){v.pause();});',
        )
        .catchError((Object _) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  @override
  void dispose() {
    _pause();
    _controller
        ?.loadRequest(Uri.parse('about:blank'))
        .catchError((Object _) {});
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null && !_failed)
              WebViewWidget(controller: _controller!),
            if (_loading && !_failed)
              const Center(child: CircularProgressIndicator()),
            if (_failed)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Reel could not be loaded.',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
