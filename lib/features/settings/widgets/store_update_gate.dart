import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Highlanders/features/settings/services/store_update_service.dart';

class StoreUpdateGate extends StatefulWidget {
  const StoreUpdateGate({super.key, required this.child, this.service});
  final Widget child;
  final StoreUpdateService? service;
  @override
  State<StoreUpdateGate> createState() => _StoreUpdateGateState();
}

class _StoreUpdateGateState extends State<StoreUpdateGate>
    with WidgetsBindingObserver {
  static final _prompted = <String>{};
  bool _checking = false, _dialogOpen = false;
  StoreUpdate? _pendingUpdate;
  Timer? _promptRetry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _showPendingUpdate();
      _check();
    } else {
      _promptRetry?.cancel();
    }
  }

  Future<void> _check() async {
    if (!mounted || _checking || _dialogOpen) return;
    _checking = true;
    final update = await (widget.service ?? StoreUpdateService()).check();
    _checking = false;
    if (!mounted ||
        update == null ||
        _prompted.contains('${update.url}:${update.version}'))
      return;
    _pendingUpdate = update;
    await _showPendingUpdate();
  }

  Future<void> _showPendingUpdate() async {
    _promptRetry?.cancel();
    if (!mounted || _dialogOpen) return;
    final update = _pendingUpdate;
    if (update == null) return;
    if (_prompted.contains('${update.url}:${update.version}')) {
      _pendingUpdate = null;
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    if (ModalRoute.of(context)?.isCurrent != true) {
      // A deep link or another page can cover the feed while Play responds.
      // Keep the confirmed update and present it once the user returns.
      _promptRetry = Timer(const Duration(milliseconds: 500), _showPendingUpdate);
      return;
    }
    _pendingUpdate = null;
    _prompted.add('${update.url}:${update.version}');
    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      builder: (_) => StoreUpdateDialog(update: update),
    );
    _dialogOpen = false;
  }

  @override
  void dispose() {
    _promptRetry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class StoreUpdateDialog extends StatefulWidget {
  const StoreUpdateDialog({super.key, required this.update, this.openStore});
  final StoreUpdate update;
  final Future<bool> Function(Uri)? openStore;
  @override
  State<StoreUpdateDialog> createState() => _StoreUpdateDialogState();
}

class _StoreUpdateDialogState extends State<StoreUpdateDialog> {
  bool _opening = false;
  String? _error;

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final opened =
          await (widget.openStore?.call(widget.update.url) ??
              launchUrl(
                widget.update.url,
                mode: LaunchMode.externalApplication,
              ));
      if (!mounted) return;
      if (opened) {
        Navigator.pop(context);
        return;
      }
    } catch (_) {}
    if (mounted)
      setState(() {
        _opening = false;
        _error = 'Could not open the store. Please try again.';
      });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 190,
              width: double.infinity,
              child: Image.asset(
                'assets/images/store-update-artwork.png',
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBD5D8),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      'NEW UPDATE',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFCC0E10),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Your next level\nawaits.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF191919),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Update your app for a smoother experience and stay closer to the game.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Color(0xFF747474),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFCC0E10)),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3B3B3B),
                            minimumSize: const Size(0, 50),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            side: const BorderSide(color: Color(0xFFAAAAAF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _opening
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text(
                            'Maybe Later',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE7192D),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 50),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _opening ? null : _open,
                          child: Text(
                            _opening ? 'Opening...' : 'Update Now ↗',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
