import 'package:flutter/material.dart';

class FeedBackground extends StatelessWidget {
  const FeedBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color(0xFFFCF5F9),
      image: DecorationImage(
        image: AssetImage('assets/images/feed-background.png'),
        fit: BoxFit.fill,
      ),
    ),
    child: child,
  );
}
