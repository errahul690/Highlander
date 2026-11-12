import '../brand_colors.dart';
import 'package:flutter/material.dart';

import '../support_hub_repository.dart';

class CareVerifiedBadge extends StatelessWidget {
  const CareVerifiedBadge({super.key, this.size = 18});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Verified ${SupportHubRepository.instance.name}',
    child: SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.verified, size: size, color: brandAccent),
          Icon(Icons.check, size: size * .6, color: Colors.white),
        ],
      ),
    ),
  );
}
