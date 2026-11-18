import 'package:flutter/material.dart';

/// Colours and display type from the supplied sponsors HTML reference.
abstract final class SponsorStyle {
  static const ink = Color(0xFFFAFAFB);
  static const night = Color(0xFF0F1016);
  static const arena = Color(0xFF15151B);
  static const panel = Color(0xFFFFFFFF);
  static const line = Color(0xFFECEBED);
  static const red = Color(0xFFA50831);
  static const text = Color(0xFF171923);
  static const soft = Color(0xFF777984);
  static const grey = Color(0xFF817B84);
  static const gold = Color(0xFFD9B25C);
  static const amber = Color(0xFFFFB547);

  static const display = TextStyle(
    fontFamily: 'Montserrat',
    fontWeight: FontWeight.w900,
    color: text,
    height: 1.04,
  );
  static const mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 10,
    color: grey,
    letterSpacing: 1,
    height: 1.4,
  );

  static const tierLabels = {
    'all': 'All',
    'principal': 'Principal',
    'kit': 'Kit',
    'associate': 'Associate',
    'official': 'Official',
    'gov': 'Govt',
    'cause': 'Cause',
  };

  static Color tierColor(String tier) => switch (tier) {
    'principal' => red,
    'kit' => gold,
    'associate' => const Color(0xFFFF8A87),
    'cause' => const Color(0xFFB07CC6),
    _ => const Color(0xFF85838C),
  };
}
