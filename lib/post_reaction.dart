import 'brand_colors.dart';

import 'package:flutter/material.dart';

enum PostReaction {
  like('Like', '👍', Color(0xFF1877F2)),
  love('Love', '❤️', brandAccent),
  haha('Haha', '😂', Color(0xFFB57800)),
  wow('Wow', '😮', Color(0xFFB57800)),
  sad('Sad', '😢', Color(0xFFB57800)),
  angry('Angry', '😡', Color(0xFFD44720)),
  fire('Fire', '🔥', Color(0xFFD44720));

  const PostReaction(this.label, this.emoji, this.color);
  final String label, emoji;
  final Color color;

  static PostReaction? fromValue(Object? value) {
    for (final reaction in values) {
      if (reaction.name == value) return reaction;
    }
    return null;
  }
}

Future<PostReaction?> showPostReactionPicker(
  BuildContext context, {
  required Rect anchor,
}) => showGeneralDialog<PostReaction>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Dismiss reactions',
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 150),
  pageBuilder: (context, animation, secondaryAnimation) {
    final media = MediaQuery.of(context);
    final width = (media.size.width - 24).clamp(0.0, 360.0);
    const height = 56.0;
    final left = (anchor.left - 8).clamp(12.0, media.size.width - width - 12);
    final minTop = media.padding.top + 8;
    final maxTop = media.size.height - media.padding.bottom - height - 8;
    final top =
        (anchor.top - height - 8 >= minTop
                ? anchor.top - height - 8
                : anchor.bottom + 8)
            .clamp(minTop, maxTop);
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: Material(
            key: const ValueKey('post-reaction-picker'),
            elevation: 6,
            shadowColor: const Color(0x24000000),
            surfaceTintColor: Colors.transparent,
            color: Colors.white,
            borderRadius: BorderRadius.circular(38),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  for (final reaction in PostReaction.values)
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(context, reaction),
                        child: Semantics(
                          button: true,
                          label: reaction.label,
                          child: Center(
                            child: PostReactionIcon(
                              reaction: reaction,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  },
  transitionBuilder: (context, animation, secondaryAnimation, child) =>
      FadeTransition(opacity: animation, child: child),
);

/// Keeps reaction rendering consistent with the original emoji reactions.
class PostReactionIcon extends StatelessWidget {
  const PostReactionIcon({super.key, required this.reaction, this.size = 20});
  final PostReaction reaction;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: reaction == PostReaction.like
          ? Icon(Icons.thumb_up, size: size, color: brandAccent)
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                reaction.emoji,
                textScaler: TextScaler.noScaling,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(fontSize: size, height: 1),
              ),
            ),
    ),
  );
}
