import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<void> restoreAppOrientation() => SystemChrome.setPreferredOrientations(
  defaultTargetPlatform == TargetPlatform.iOS
      ? const [DeviceOrientation.portraitUp]
      : const [],
);
