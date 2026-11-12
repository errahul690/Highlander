import '../brand_colors.dart';
import 'package:flutter/material.dart';

class SupportHubAvatar extends StatelessWidget {
  const SupportHubAvatar({super.key, this.radius = 25});

  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFF7E7E5),
    child: Icon(
      Icons.support_agent_rounded,
      size: radius * 1.3,
      color: brandAccent,
    ),
  );
}
