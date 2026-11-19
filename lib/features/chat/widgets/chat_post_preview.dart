import 'package:flutter/material.dart';
import 'package:Highlanders/core/network/network_read.dart';
import 'package:Highlanders/features/gallery/widgets/gallery_image.dart';
import 'package:Highlanders/features/posts/data/posts_api.dart';
import 'package:Highlanders/features/posts/screens/post_detail_screen.dart';
import 'package:Highlanders/features/posts/screens/reels_screen.dart';
import 'package:Highlanders/shared/widgets/media/video_poster.dart';
import 'package:Highlanders/shared/widgets/user_avatar.dart';

/// A structured chat attachment. No public URL is displayed in the message.
class ChatPostPreview extends StatefulWidget {
  const ChatPostPreview({
    super.key,
    required this.postId,
    required this.preview,
  });
  final String postId;
  final Map<String, dynamic> preview;
  @override
  State<ChatPostPreview> createState() => _ChatPostPreviewState();
}

class _ChatPostPreviewState extends State<ChatPostPreview> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening || widget.preview['unavailable'] == true) return;
    setState(() => _opening = true);
    try {
      // Resolve again at tap time, including publication status and current data.
      final post = await PostsApi.instance.getPost(widget.postId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => '${post['video'] ?? ''}'.trim().isNotEmpty
              ? ReelsScreen(initialPost: post)
              : PostDetailScreen(postId: widget.postId),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final unavailable = preview['unavailable'] == true;
    final author = '${preview['authorName'] ?? 'Highlander'}';
    final image = '${preview['image'] ?? ''}';
    final video = '${preview['video'] ?? ''}';
    final isReel = preview['isReel'] == true || video.isNotEmpty;
    final content = '${preview['content'] ?? ''}';
    return SizedBox(
      width: 250,
      child: Material(
        key: ValueKey('chat-post-${widget.postId}'),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: unavailable ? null : _open,
          child: unavailable
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('This post is no longer available.'),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          UserAvatar(
                            name: author,
                            image: '${preview['authorImage'] ?? ''}',
                            radius: 15,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (_opening)
                            const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              isReel
                                  ? Icons.movie_outlined
                                  : Icons.photo_library_outlined,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                    if (image.isNotEmpty || video.isNotEmpty)
                      AspectRatio(
                        aspectRatio: isReel ? 4 / 5 : 1,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (image.isNotEmpty)
                              GalleryImage(url: image)
                            else
                              VideoPoster(source: video),
                            if (isReel)
                              const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 46,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (content.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                        child: Text(
                          content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, height: 1.3),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                      child: Text(
                        isReel ? 'View reel' : 'View post',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
