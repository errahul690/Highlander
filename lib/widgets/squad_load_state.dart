import 'package:flutter/material.dart';

class SquadLoadState extends StatelessWidget {
  const SquadLoadState({
    super.key,
    required this.onRefresh,
    this.loading = false,
    this.unavailable = false,
  });

  final VoidCallback onRefresh;
  final bool loading, unavailable;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                const Icon(
                  Icons.groups_outlined,
                  size: 56,
                  color: Color(0xFF8C8C96),
                ),
              const SizedBox(height: 18),
              Text(
                loading
                    ? 'Loading the squad…'
                    : unavailable
                    ? 'Squad updates are taking a little longer.'
                    : 'No squad members available yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Color(0xFF62626D)),
              ),
              if (!loading) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh squad'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
