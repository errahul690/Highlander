import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';

class StoreUpdate {
  const StoreUpdate({required this.version, required this.url});
  final String version;
  final Uri url;

  static StoreUpdate? fromResult(Map<dynamic, dynamic>? result) {
    if (result?['available'] != true) return null;
    final version = '${result?['version'] ?? ''}'.trim();
    final url = Uri.tryParse('${result?['url'] ?? ''}');
    if (version.isEmpty ||
        url == null ||
        url.scheme != 'https' ||
        !['play.google.com', 'apps.apple.com'].contains(url.host))
      return null;
    return StoreUpdate(version: version, url: url);
  }
}

class StoreUpdateService {
  Future<StoreUpdate?> check() async {
    if (kDebugMode && const bool.fromEnvironment('PREVIEW_STORE_UPDATE')) {
      return StoreUpdate(
        version: 'preview',
        url: Uri.parse(
          'https://play.google.com/store/apps/details?id=com.highlander',
        ),
      );
    }
    try {
      Map<dynamic, dynamic>? data;
      if (Platform.isAndroid) {
        data = await const MethodChannel('neufc/store_update')
            .invokeMapMethod('check')
            .timeout(const Duration(seconds: 12));
      } else if (Platform.isIOS) {
        data = await const MethodChannel('highlanders/app_links')
            .invokeMapMethod('checkStoreUpdate')
            .timeout(const Duration(seconds: 12));
      }
      if (kDebugMode) debugPrint('Store update check: $data');
      return StoreUpdate.fromResult(data);
    } catch (error) {
      if (kDebugMode) debugPrint('Store update check failed: $error');
      return null;
    }
  }
}
