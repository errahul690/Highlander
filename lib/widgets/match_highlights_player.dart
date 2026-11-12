import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'match_highlights_source.dart';
import 'post_video.dart';
import 'web_video_fullscreen.dart';

class MatchHighlightsPlayer extends StatelessWidget {
  const MatchHighlightsPlayer({super.key, required this.source});
  final String source;
  @override
  Widget build(BuildContext context) {
    final id = youtubeVideoId(source);
    return id == null
        ? PostVideo(source: source, autoPlay: true, aspectRatio: 16 / 9)
        : _YoutubeHighlights(videoId: id);
  }
}

class _YoutubeHighlights extends StatefulWidget {
  const _YoutubeHighlights({required this.videoId});
  final String videoId;
  @override
  State<_YoutubeHighlights> createState() => _YoutubeHighlightsState();
}

class _YoutubeHighlightsState extends State<_YoutubeHighlights>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _failed = false);
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.black);
      if (!mounted) return;
      await configureWebVideoFullscreen(context, controller);
      if (controller.platform is AndroidWebViewController) {
        await (controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => youtubeStaysInApp(request.url)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted)
              setState(() => _failed = true);
          },
        ),
      );
      // Supply the installed app's identity, as required for embedded YouTube in a WebView.
      if (!mounted) return;
      _controller = controller;
      await controller.loadRequest(
        youtubeEmbedUri(widget.videoId),
        headers: const {'Referer': youtubeAppReferrer},
      );
      if (mounted) setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  void _stop() {
    _controller
        ?.runJavaScript(
          'document.querySelectorAll("video").forEach(function(v){v.pause();});',
        )
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _stop();
    _controller
        ?.loadRequest(Uri.parse('about:blank'))
        .catchError((Object _) {});
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 210),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: _failed
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Highlights could not be loaded.',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
            : _controller == null
            ? const Center(child: CircularProgressIndicator())
            : WebViewWidget(controller: _controller!),
      ),
    ),
  );
}
