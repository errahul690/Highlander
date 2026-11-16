import 'package:flutter/material.dart';

/// An inline indicator, shown only while content is loading.
class StartupLoader extends StatelessWidget {
  const StartupLoader({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    container: true,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: MediaQuery.disableAnimationsOf(context) ? .5 : null,
          ),
        ),
      ),
    ),
  );
}
