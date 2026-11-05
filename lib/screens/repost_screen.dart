import '../widgets/club_page_body.dart';

import 'package:flutter/material.dart';

import '../widgets/user_avatar.dart';
import '../posts_api.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/club_bar.dart';
import '../widgets/feed_post_card.dart';

class RepostScreen extends StatefulWidget {
  const RepostScreen({super.key, required this.post});
  final Map<String, dynamic> post;
  @override
  State<RepostScreen> createState() => _RepostScreenState();
}

class _RepostScreenState extends State<RepostScreen> {
  final _caption = TextEditingController();
  bool _saving = false;
  String _error = '';
  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await PostsApi.instance.request(
        '/api/user/posts/${widget.post['_id']}/reposts',
        method: 'POST',
        body: {'content': _caption.text},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ClubScaffold(
    appBar: const ClubBar(title: 'Repost'),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const UserAvatar(currentUser: true),
            const SizedBox(width: 12),
            Text(
              Session.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _caption,
          enabled: !_saving,
          maxLength: 500,
          minLines: 4,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'What’s on your mind?'),
        ),
        const SizedBox(height: 16),
        FeedPostCard(post: widget.post, showActions: false),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_error, style: const TextStyle(color: authRed)),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: authButtonStyle(),
          child: Text(_saving ? 'Reposting...' : 'Repost'),
        ),
      ],
    ),
  );
}
