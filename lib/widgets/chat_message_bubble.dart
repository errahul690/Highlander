import 'package:flutter/material.dart';

import '../theme.dart';

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
  });

  final bool own;
  final String text, time;
  final String? author;
  final Widget? leading, status;

  @override
  Widget build(BuildContext context) {
    final receipt = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (time.isNotEmpty)
          Text(
            time,
            style: const TextStyle(
              fontFamily: clubFontFamily,
              fontSize: 10,
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
            fontSize: 15,
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
                      fontSize: 12,
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
                    Text(text),
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
