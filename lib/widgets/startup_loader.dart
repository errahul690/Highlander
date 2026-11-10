import 'package:flutter/material.dart';

import 'animated_football.dart';

/// An inline indicator, shown only while content is loading.
class StartupLoader extends StatelessWidget {
  const StartupLoader({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    container: true,
    child: const Center(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: ExcludeSemantics(child: AnimatedFootball()),
      ),
    ),
  );
}
