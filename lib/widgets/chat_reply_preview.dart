import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../session.dart';
import 'chat_media_image.dart';
import '../theme.dart';

class ChatReplyPreview extends StatelessWidget {
  const ChatReplyPreview({
    super.key,
    required this.message,
    this.onCancel,
    this.onTap,
  });
  final Map<String, dynamic> message;
  final VoidCallback? onCancel, onTap;

  @override
  Widget build(BuildContext context) {
    final own = message['senderEmail'] == Session.email;
    final author = own ? 'You' : '${message['senderName'] ?? 'Highlander'}';
    final content = '${message['content'] ?? ''}'.trim();
    final attachment = '${message['attachmentUrl'] ?? message['image'] ?? ''}'
        .trim();
    final type = '${message['attachmentType'] ?? ''}';
    final isPhoto =
        type.startsWith('image/') || (type.isEmpty && message['image'] != null);
    final isVideo = type.startsWith('video/');
    final hasMedia = isPhoto || isVideo || attachment.isNotEmpty;
    final summary = content.isNotEmpty
        ? content
        : isPhoto
        ? 'Photo'
        : isVideo
        ? 'Video'
        : '${message['attachmentName'] ?? 'Message'}';
    final textStyle = const TextStyle(
      fontSize: 13,
      color: Color(0xFF596275),
      height: 1.3,
    );
    final authorStyle = const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: authRed,
      height: 1.2,
    );

    double textWidth(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 280.0;
        final contentWidth = textWidth(summary, textStyle).clamp(120.0, 240.0);
        final nameWidth = textWidth(author, authorStyle);
        final desired =
            (contentWidth > nameWidth ? contentWidth : nameWidth) +
            26 +
            (isPhoto ? 54 : 0);
        final width = onCancel != null
            ? available
            : desired.clamp(0.0, available);
        return Container(
          width: width,
          margin: const EdgeInsets.only(bottom: 6),
          padding: onCancel == null ? EdgeInsets.zero : const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: onCancel == null ? Colors.transparent : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    key: const ValueKey('quoted-message-block'),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E1E7),
                      border: const Border(
                        left: BorderSide(color: authRed, width: 4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 8,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: authorStyle,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (hasMedia) ...[
                                        Icon(
                                          isPhoto
                                              ? Icons.image_outlined
                                              : isVideo
                                              ? Icons.videocam_outlined
                                              : Icons.attach_file,
                                          size: 15,
                                          color: const Color(0xFF596275),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          summary,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: textStyle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isPhoto && attachment.isNotEmpty)
                            SizedBox(
                              width: 54,
                              child: ChatMediaImage(
                                url: attachment,
                                thumbnail:
                                    '${message['attachmentThumbnail'] ?? ''}',
                                key: const ValueKey('reply-photo-thumbnail'),
                                width: 54,
                                height: 54,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (onCancel != null)
                IconButton(
                  tooltip: 'Cancel reply',
                  onPressed: onCancel,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, size: 20, color: authMuted),
                ),
            ],
          ),
        );
      },
    );
  }
}

class ChatReplyGesture extends StatefulWidget {
  const ChatReplyGesture({
    super.key,
    required this.messageId,
    required this.child,
    required this.onReply,
    required this.onLongPress,
  });
  final String messageId;
  final Widget child;
  final VoidCallback? onReply;
  final VoidCallback onLongPress;

  @override
  State<ChatReplyGesture> createState() => _ChatReplyGestureState();
}

class _ChatReplyGestureState extends State<ChatReplyGesture>
    with SingleTickerProviderStateMixin {
  static const _threshold = 48.0;
  late final AnimationController _slide;
  double _dragDistance = 0;
  double get _distance => _slide.value;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  void _reset({bool reply = false}) {
    _dragDistance = 0;
    _slide.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    if (reply) widget.onReply?.call();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('reply-swipe-${widget.messageId}'),
    behavior: HitTestBehavior.opaque,
    onLongPress: widget.onLongPress,
    onHorizontalDragStart: widget.onReply == null
        ? null
        : (_) {
            _slide.stop();
            _dragDistance = _distance;
          },
    onHorizontalDragUpdate: widget.onReply == null
        ? null
        : (details) {
            final before = _distance;
            _dragDistance = (_dragDistance + details.delta.dx).clamp(
              0.0,
              240.0,
            );
            // Follow the finger directly, with gentle resistance past the trigger.
            _slide.value = _dragDistance <= _threshold
                ? _dragDistance
                : _threshold + (_dragDistance - _threshold) * .22;
            if (before < _threshold && _distance >= _threshold) {
              HapticFeedback.selectionClick();
            }
          },
    onHorizontalDragEnd: widget.onReply == null
        ? null
        : (_) => _reset(reply: _distance >= _threshold),
    onHorizontalDragCancel: () => _reset(),
    child: Stack(
      alignment: Alignment.centerLeft,
      children: [
        if (_distance > 0)
          Positioned(
            left: 8,
            child: Opacity(
              opacity: (_distance / _threshold).clamp(0.0, 1.0),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _distance >= _threshold ? authRed : Colors.white,
                ),
                child: Icon(
                  Icons.reply_rounded,
                  size: 20,
                  color: _distance >= _threshold ? Colors.white : authRed,
                ),
              ),
            ),
          ),
        Transform.translate(offset: Offset(_distance, 0), child: widget.child),
      ],
    ),
  );
}
