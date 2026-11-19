import 'package:flutter/material.dart';

import 'package:Highlanders/core/theme/theme.dart';

/// Shared compact message layout for private, community and support chats.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.own,
    this.text = '',
    this.leading,
    this.author,
    this.time = '',
    this.status,
    this.starred = false,
    this.edited = false,
    this.searchQuery = '',
  });

  final bool own;
  final bool starred, edited;
  final String text, time;
  final String searchQuery;
  final String? author;
  final Widget? leading, status;

  @override
  Widget build(BuildContext context) {
    final receipt = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 14,
          child: Visibility(
            visible: starred,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: const Icon(
              Icons.star_rounded,
              size: 12,
              color: Color(0xFFAD852D),
              semanticLabel: 'Starred',
            ),
          ),
        ),
        if (edited)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text(
              'edited',
              style: TextStyle(fontSize: 11, color: Color(0xFF83808A)),
            ),
          ),
        if (time.isNotEmpty)
          Text(
            time,
            style: const TextStyle(
              fontFamily: clubFontFamily,
              fontSize: 11,
              height: 1.2,
              color: Color(0xFF83808A),
            ),
          ),
        if (status != null) ...[const SizedBox(width: 3), status!],
      ],
    );
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        decoration: BoxDecoration(
          color: own ? const Color(0xFFF7E8ED) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(own ? 14 : 5),
            topRight: Radius.circular(own ? 5 : 14),
            bottomLeft: const Radius.circular(14),
            bottomRight: const Radius.circular(14),
          ),
          border: Border.all(
            color: own ? const Color(0xFFEEDAE2) : const Color(0xFFECE9E6),
            width: .6,
          ),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: clubFontFamily,
            fontFamilyFallback: ['Segoe UI Emoji'],
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w400,
            color: Color(0xFF242127),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (author != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    author!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: authRed,
                    ),
                  ),
                ),
              if (leading != null) leading!,
              if (text.isNotEmpty)
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    _messageText(),
                    if (time.isNotEmpty || status != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: receipt,
                      ),
                  ],
                )
              else if (time.isNotEmpty || status != null)
                Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: receipt,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageText() {
    if (searchQuery.isEmpty) return Text(text);
    final matches = RegExp(
      RegExp.escape(searchQuery),
      caseSensitive: false,
    ).allMatches(text).toList();
    if (matches.isEmpty) return Text(text);
    final spans = <TextSpan>[];
    var end = 0;
    for (final match in matches) {
      if (match.start > end)
        spans.add(TextSpan(text: text.substring(end, match.start)));
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: const TextStyle(
            backgroundColor: Color(0xFFFFDF75),
            color: Color(0xFF242127),
          ),
        ),
      );
      end = match.end;
    }
    if (end < text.length) spans.add(TextSpan(text: text.substring(end)));
    return Text.rich(TextSpan(children: spans));
  }
}

class ChatDateChip extends StatelessWidget {
  const ChatDateChip({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xF2F6F3F1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEAE5E1), width: .6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: clubFontFamily,
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: Color(0xFF79737B),
        ),
      ),
    ),
  );
}
