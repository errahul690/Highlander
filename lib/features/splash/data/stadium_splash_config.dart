import 'package:flutter/material.dart';

class StadiumSplashConfig {
  const StadiumSplashConfig({
    this.firstStillDuration = const Duration(milliseconds: 500),
    this.nativeHandoffDuration = const Duration(milliseconds: 180),
    this.stageDuration = const Duration(milliseconds: 500),
    this.lastStillDuration = const Duration(milliseconds: 500),
    this.transitionDuration = const Duration(milliseconds: 180),
    this.readinessTimeout = const Duration(seconds: 3),
    this.imageTimeout = const Duration(seconds: 5),
    this.playbackStallTimeout = const Duration(seconds: 3),
    this.framePollInterval = const Duration(milliseconds: 32),
    this.enableSound = false,
    this.diagnostics = const bool.fromEnvironment('STADIUM_SPLASH_DIAGNOSTICS'),
  });

  static const background = Color(0xFF160B09);
  static const sourceSize = Size(608, 1080);
  static const videoAsset = 'assets/splash/splash_original.mp4';
  // The native launcher and Flutter both start at stadium_2, then show stadium_4.
  static const images = [
    'assets/splash/stadium_2.png',
    'assets/splash/stadium_4.png',
  ];

  final Duration firstStillDuration;
  final Duration nativeHandoffDuration;
  final Duration stageDuration;
  final Duration lastStillDuration;
  final Duration transitionDuration;
  final Duration readinessTimeout;
  final Duration imageTimeout;
  final Duration playbackStallTimeout;
  final Duration framePollInterval;
  final bool enableSound;
  final bool diagnostics;
}
