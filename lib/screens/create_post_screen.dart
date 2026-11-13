import 'dart:io';

import 'package:flutter/material.dart';

import '../widgets/club_header.dart';
import '../widgets/club_page_body.dart';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../theme.dart';
import '../posts_api.dart';
import '../realtime_client.dart';
import '../session.dart';
import '../widgets/post_video.dart';
import '../widgets/user_avatar.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _body = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  XFile? _video;
  bool _saving = false;
  bool _rewriting = false;
  String _error = '';

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final remaining = 4 - _images.length;
      if (remaining == 0) return;
      List<XFile> files;
      if (remaining == 1) {
        final file = await _picker.pickImage(source: ImageSource.gallery);
        files = file == null ? [] : [file];
      } else {
        files = await _picker.pickMultiImage(limit: remaining);
      }
      for (final file in files.take(remaining)) {
        if (await file.length() > 15 * 1024 * 1024) {
          throw Exception('Each image must be smaller than 15 MB.');
        }
      }
      if (mounted) {
        setState(() {
          _images.addAll(files.take(remaining));
          _error = '';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;
      if (await file.length() > 15 * 1024 * 1024) {
        throw Exception('Choose a video smaller than 15 MB.');
      }
      if (mounted) {
        setState(() {
          _video = file;
          _error = '';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _rewrite() async {
    if (_rewriting || _saving) return;
    final draft = _body.text;
    setState(() {
      _rewriting = true;
      _error = '';
    });
    try {
      final result = await PostsApi.instance.request(
        '/api/user/posts/rewrite',
        timeout: const Duration(seconds: 30),
        method: 'POST',
        body: {'content': draft.trim()},
      );
      if (!mounted) return;
      if (_body.text != draft) {
        setState(
          () => _error = 'Your draft changed. Tap Rewrite again to create a caption from the latest text.',
        );
        return;
      }
      setState(() {
        _body.text = result['content'] as String;
        _body.selection = TextSelection.collapsed(offset: _body.text.length);
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _rewriting = false);
    }
  }

  Future<void> _post() async {
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final images = <String>[];
      for (final image in _images) {
        images.add(await PostsApi.instance.upload(image));
      }
      final video = _video == null
          ? ''
          : await PostsApi.instance.upload(_video!);
      await PostsApi.instance.request(
        '/api/user/posts',
        method: 'POST',
        body: {'content': _body.text.trim(), 'images': images, 'video': video},
      );
      RealtimeClient.instance.dispatchSettingsUpdate({'resource': 'posts'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post created successfully!'),
          backgroundColor: Color(0xFF1B8755),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _attachment(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? onTap,
  ) => Expanded(
    child: CustomPaint(
      painter: _DashedBorder(),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFF7F7F9),
                child: Icon(icon, color: clubRed, size: 22),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 10, color: authMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _rewriting;
    final name = Session.name.trim().isEmpty
        ? 'Highlander'
        : Session.name.trim();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: ClubHeader(
          title: 'Create Post',
          showSearch: false,
          showSupport: false,
          showNotifications: false,
          onBack: () {
            if (!busy) Navigator.of(context).maybePop();
          },
        ),
        body: ClubPageBody(
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFF3DED1),
                                  width: 3,
                                ),
                              ),
                              child: const UserAvatar(
                                currentUser: true,
                                radius: 19,
                                backgroundColor: Color(0xFF8C238E),
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          height: 172,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFFD9DEE8),
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(19),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const ValueKey('post-body'),
                                  controller: _body,
                                  enabled: !busy,
                                  maxLength: 500,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'What is on your mind?',
                                    hintStyle: TextStyle(
                                      color: authMuted,
                                      fontSize: 14,
                                    ),
                                    counterText: '',
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Share a moment. Let the Highland roar.',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: authMuted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      [
                                        _body.text.characters.length,
                                        500,
                                      ].join('/'),
                                      style: const TextStyle(
                                        color: authMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _attachment(
                              'Add Images',
                              'Up to 4',
                              Icons.image_outlined,
                              busy || _images.length == 4 ? null : _pickImages,
                            ),
                            const SizedBox(width: 12),
                            _attachment(
                              'Add Video',
                              'Up to 1',
                              Icons.smart_display_outlined,
                              busy ? null : _pickVideo,
                            ),
                          ],
                        ),
                        if (_images.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _images
                                  .map(
                                    (file) => Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Image.file(
                                            File(file.path),
                                            width: 70,
                                            height: 70,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: InkWell(
                                            onTap: busy
                                                ? null
                                                : () => setState(
                                                    () => _images.remove(file),
                                                  ),
                                            child: const CircleAvatar(
                                              radius: 12,
                                              backgroundColor: authRed,
                                              child: Icon(
                                                Icons.close,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        if (_video != null) ...[
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Selected video',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove video',
                                onPressed: busy
                                    ? null
                                    : () => setState(() => _video = null),
                                icon: const Icon(Icons.close, color: authRed),
                              ),
                            ],
                          ),
                          PostVideo(
                            key: ValueKey(_video!.path),
                            source: _video!.path,
                            local: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                  child: Column(
                    children: [
                      if (_error.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error,
                            style: const TextStyle(
                              color: authRed,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                disabledForegroundColor: authRed,
                                foregroundColor: authRed,
                                side: const BorderSide(
                                  color: Color(0xFFE8C3BF),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                minimumSize: const Size(0, 46),
                              ),
                              onPressed: busy || _body.text.trim().isEmpty
                                  ? null
                                  : _rewrite,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_outlined,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _rewriting ? 'Writing...' : 'Rewrite',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const Text(
                                          'Football fan caption',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: authMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                disabledBackgroundColor: authRed,
                                disabledForegroundColor: Colors.white,
                                backgroundColor: authRed,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                minimumSize: const Size(0, 46),
                              ),
                              onPressed:
                                  busy ||
                                      (_body.text.trim().isEmpty &&
                                          _images.isEmpty &&
                                          _video == null)
                                  ? null
                                  : _post,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_outlined, size: 16),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _saving ? 'Posting...' : 'Submit Post',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
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
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      );
    final paint = Paint()
      ..color = const Color(0xFFD9DEE8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 10) {
        canvas.drawPath(metric.extractPath(start, start + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}
