import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_file_cache.dart';
import '../media_auto_download.dart';
import '../theme.dart';

class ChatFileAttachment extends StatefulWidget {
  const ChatFileAttachment({
    super.key,
    required this.url,
    required this.name,
    required this.mime,
  });
  final String url, name, mime;
  @override
  State<ChatFileAttachment> createState() => _ChatFileAttachmentState();
}

class _ChatFileAttachmentState extends State<ChatFileAttachment> {
  static const _channel = MethodChannel('highlanders/app_links');
  late final _preferences = MediaAutoDownload.instance;
  File? _file;
  bool _busy = false, _failed = false, _autoTried = false, _checking = true;
  int _version = 0;
  bool get _video => widget.mime.startsWith('video/');
  @override
  void initState() {
    super.initState();
    _preferences.addListener(_changed);
    unawaited(_preferences.restore());
    _resolve();
  }

  @override
  void dispose() {
    _preferences.removeListener(_changed);
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatFileAttachment old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.name != widget.name) _resolve();
  }

  Future<void> _resolve() async {
    final version = ++_version;
    _file = null;
    _checking = true;
    _autoTried = false;
    _busy = false;
    _failed = false;
    final file = await ChatFileCache.instance.cached(widget.url, widget.name);
    if (!mounted || version != _version) return;
    setState(() {
      if (file != null && _file == null) _file = file;
      _checking = false;
    });
    _maybeAuto();
  }

  void _changed() {
    _autoTried = false;
    _maybeAuto();
  }

  void _maybeAuto() {
    if (mounted &&
        !_busy &&
        !_checking &&
        _file == null &&
        !_autoTried &&
        _preferences.allows(widget.mime)) {
      _autoTried = true;
      unawaited(_download());
    }
  }

  Future<void> _download() async {
    if (_busy) return;
    final version = _version;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final file = await ChatFileCache.instance.download(widget.url, widget.name);
    if (!mounted || version != _version) return;
    setState(() {
      _file = file;
      _busy = false;
      _failed = file == null;
    });
  }

  Future<void> _tap() async {
    if (_busy) return;
    if (_file == null) {
      await _download();
      return;
    }
    try {
      await _channel.invokeMethod('openChatFile', {
        'path': _file!.path,
        'mime': widget.mime,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this file on your device.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Material(
      color: Colors.white.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _tap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 230),
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _video
                    ? Icons.video_file_outlined
                    : Icons.insert_drive_file_outlined,
                size: 24,
                color: authRed,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _busy
                          ? 'Downloading…'
                          : _file != null
                          ? 'Tap to open'
                          : _failed
                          ? 'Retry download'
                          : 'Download',
                      style: const TextStyle(fontSize: 11, color: authMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: authRed,
                  ),
                )
              else
                Icon(
                  _file != null
                      ? (_video ? Icons.play_circle_outline : Icons.open_in_new)
                      : Icons.download_rounded,
                  size: 20,
                  color: authRed,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
