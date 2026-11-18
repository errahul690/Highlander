import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:Highlanders/features/swoofi/data/swoofi_store_links.dart';

/// The uploaded document owns its scrolling, layout and JavaScript animations.
class SwoofiHtmlPage extends StatefulWidget {
  const SwoofiHtmlPage({
    super.key,
    required this.url,
    required this.onOpenLink,
    this.playStoreUrl = SwoofiStoreLinks.playStore,
    this.appStoreUrl = SwoofiStoreLinks.appStore,
  });

  final String url;
  final Future<void> Function(String) onOpenLink;
  final String playStoreUrl;
  final String appStoreUrl;

  @override
  State<SwoofiHtmlPage> createState() => _SwoofiHtmlPageState();
}

class _SwoofiHtmlPageState extends State<SwoofiHtmlPage> {
  WebViewController? _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Defer platform view creation until the route has a mounted surface.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || WebViewPlatform.instance == null) return;
      final controller = WebViewController()
        ..setBackgroundColor(const Color(0xFFF7F4EF))
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) setState(() => _loading = true);
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
              // Store links using target=_blank should use the app's URL opener.
              unawaited(
                _controller?.runJavaScript('''
document.addEventListener('click', function(event) {
  var link = event.target.closest && event.target.closest('a');
  if (!link) return;
  link.target = '_self';
  var host = new URL(link.href, document.baseURI).hostname;
  var store = host === 'play.google.com' ? ${jsonEncode(widget.playStoreUrl)} : host === 'apps.apple.com' ? ${jsonEncode(widget.appStoreUrl)} : null;
  if (store === '') event.preventDefault();
  else if (store !== null) link.href = store;
}, true);
'''),
              );
            },
            onWebResourceError: (error) {
              if (mounted && error.isForMainFrame == true) {
                setState(() {
                  _failed = true;
                  _loading = false;
                });
              }
            },
            onHttpError: (error) {
              if (mounted && error.request?.uri == Uri.parse(widget.url)) {
                setState(() {
                  _failed = true;
                  _loading = false;
                });
              }
            },
            onNavigationRequest: (request) {
              final initial = Uri.parse(widget.url);
              final target = Uri.tryParse(request.url);
              if (!request.isMainFrame ||
                  (target != null &&
                      target.replace(fragment: '') ==
                          initial.replace(fragment: ''))) {
                return NavigationDecision.navigate;
              }
              if (target != null && ['http', 'https'].contains(target.scheme)) {
                unawaited(widget.onOpenLink(request.url));
              }
              return NavigationDecision.prevent;
            },
          ),
        );
      setState(() => _controller = controller);
      unawaited(controller.loadRequest(Uri.parse(widget.url)));
    });
  }

  void _retry() {
    setState(() {
      _failed = false;
      _loading = true;
    });
    unawaited(_controller?.loadRequest(Uri.parse(widget.url)));
  }

  @override
  Widget build(BuildContext context) => Stack(
    key: const ValueKey('swoofi-html-page'),
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
              const Text('Could not load this page.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _retry, child: const Text('Retry')),
            ],
          ),
        ),
    ],
  );
}
