import '../brand_colors.dart';
import 'package:flutter/material.dart';

class UnreadChatBadge extends StatelessWidget {
  const UnreadChatBadge({
    super.key,
    required this.count,
    this.inverted = false,
  });
  final int count;
  final bool inverted;
  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Semantics(
      label: '$count unread messages',
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: inverted ? Colors.white : brandAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            height: 1.3,
            fontWeight: FontWeight.w800,
            color: inverted ? brandAccent : Colors.white,
          ),
        ),
      ),
    );
  }
}
