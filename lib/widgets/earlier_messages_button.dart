import '../brand_colors.dart';
import 'package:flutter/material.dart';

class EarlierMessagesButton extends StatelessWidget {
  const EarlierMessagesButton({
    super.key,
    required this.loading,
    required this.onPressed,
    this.error = false,
  });

  final bool loading, error;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextButton.icon(
        key: const ValueKey('load-earlier-messages'),
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.history, size: 18),
        label: Text(
          loading
              ? 'Loading earlier messages…'
              : error
              ? 'Try loading earlier messages again'
              : 'Load earlier messages',
        ),
        style: TextButton.styleFrom(
          foregroundColor: brandAccent,
          backgroundColor: Colors.white,
        ),
      ),
    ),
  );
}
