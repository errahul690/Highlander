import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class SavedGrounds {
  const SavedGrounds({
    required this.payload,
    this.html = '',
    this.imagePath = '',
    this.metadata = const {},
  });
  final Map<String, dynamic> payload;
  final String html, imagePath;
  final Map<String, dynamic> metadata;
}

/// Saves the selected public map and its settings across app launches.
class GroundsCache {
  GroundsCache({
    Future<Directory> Function()? directory,
    Future<List<int>> Function()? fontBytes,
  }) : _directory = directory ?? _defaultDirectory,
       _fontBytes = fontBytes ?? _bundledFont;

  final Future<Directory> Function() _directory;
  final Future<List<int>> Function() _fontBytes;
  Future<void> _writes = Future.value();

  static Future<Directory> _defaultDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/grounds');
  static Future<List<int>> _bundledFont() async =>
      (await rootBundle.load('assets/fonts/Manrope-Variable.ttf')).buffer
          .asUint8List();

  Future<SavedGrounds?> read(String baseUrl) async {
    try {
      final directory = await _directory();
      final metadata = Map<String, dynamic>.from(
        jsonDecode(await File('${directory.path}/settings.json').readAsString())
            as Map,
      );
      if (metadata['baseUrl'] != baseUrl || metadata['payload'] is! Map)
        return null;
      final payload = Map<String, dynamic>.from(metadata['payload'] as Map);
      final name = '${metadata['file'] ?? ''}';
      if (!RegExp(r'^map-[a-f0-9]+\.(html|img)$').hasMatch(name))
        return SavedGrounds(payload: payload);
      final file = File('${directory.path}/$name');
      if (!await file.exists() || await file.length() == 0)
        return SavedGrounds(payload: payload);
      return SavedGrounds(
        payload: payload,
        html: metadata['kind'] == 'html' ? await file.readAsString() : '',
        imagePath: metadata['kind'] == 'image' ? file.path : '',
        metadata: metadata,
      );
    } catch (_) {
      return null;
    }
  }

  Future<SavedGrounds> prepare(
    Map<String, dynamic> payload,
    String baseUrl,
    http.Client client,
  ) async {
    final previous = await read(baseUrl);
    final settings = payload['settings'] is Map
        ? payload['settings'] as Map
        : const {};
    final htmlUrl = '${settings['map_html'] ?? ''}'.trim();
    final imageUrl = '${settings['map_image'] ?? ''}'.trim();
    final kind = htmlUrl.isNotEmpty ? 'html' : 'image';
    final rawUrl = htmlUrl.isNotEmpty ? htmlUrl : imageUrl;
    final url = rawUrl.isEmpty
        ? ''
        : Uri.parse(baseUrl).resolve(rawUrl).toString();
    final sameMap =
        previous?.metadata['url'] == url && previous?.metadata['kind'] == kind;
    var metadata = <String, dynamic>{
      'baseUrl': baseUrl,
      'payload': payload,
      'url': url,
      'kind': kind,
    };
    var html = sameMap ? previous!.html : '';
    var imagePath = sameMap ? previous!.imagePath : '';
    if (sameMap)
      metadata.addAll({
        for (final field in ['file', 'etag', 'modified'])
          if (previous!.metadata[field] != null)
            field: previous.metadata[field],
      });

    if (url.isNotEmpty) {
      try {
        final response = await client
            .get(
              Uri.parse(url),
              headers: {
                if (sameMap && previous!.metadata['etag'] is String)
                  'If-None-Match': previous.metadata['etag'] as String,
                if (sameMap && previous!.metadata['modified'] is String)
                  'If-Modified-Since': previous.metadata['modified'] as String,
              },
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          var bytes = response.bodyBytes.toList();
          if (kind == 'html') {
            html = utf8.decode(bytes);
            // The current map embeds its artwork; embed its bundled Manrope font
            // as well, so opening it does not wait on Google Fonts.
            if (html.contains('fonts.googleapis.com') &&
                html.contains('Manrope')) {
              try {
                final font = base64Encode(await _fontBytes());
                html = html.replaceAll(
                  RegExp(
                    r'''<link\b[^>]*href\s*=\s*["']https://fonts\.(?:googleapis|gstatic)\.com[^"']*["'][^>]*>''',
                    caseSensitive: false,
                  ),
                  '',
                );
                final style =
                    '<style data-highlanders-cached-font>@font-face{font-family:Manrope;src:url(data:font/ttf;base64,$font) format("truetype");font-weight:200 800;font-display:swap}</style>';
                final head = RegExp(r'<head[^>]*>', caseSensitive: false);
                html = head.hasMatch(html)
                    ? html.replaceFirstMapped(
                        head,
                        (match) => '${match[0]}$style',
                      )
                    : '$style$html';
              } catch (_) {
                // Keep the original document if the optional bundled font is unavailable.
              }
            }
            bytes = utf8.encode(html);
          }
          final directory = await _directory();
          await directory.create(recursive: true);
          final name =
              'map-${_fingerprint(bytes)}.${kind == 'html' ? 'html' : 'img'}';
          final file = File('${directory.path}/$name');
          if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
          imagePath = kind == 'image' ? file.path : '';
          metadata = {
            ...metadata,
            'file': name,
            'etag': response.headers['etag'],
            'modified': response.headers['last-modified'],
          };
        }
      } catch (_) {
        // A failed refresh keeps a previously downloaded copy of this same map.
      }
    }
    return SavedGrounds(
      payload: payload,
      html: html,
      imagePath: imagePath,
      metadata: metadata,
    );
  }

  Future<void> commit(SavedGrounds saved, {bool Function()? isCurrent}) =>
      _writes = _writes.catchError((_) {}).then((_) async {
        if (isCurrent != null && !isCurrent()) return;
        final directory = await _directory();
        await directory.create(recursive: true);
        final pending = File('${directory.path}/settings.pending.json');
        await pending.writeAsString(jsonEncode(saved.metadata), flush: true);
        if (isCurrent == null || isCurrent()) {
          await pending.rename('${directory.path}/settings.json');
        }
      });

  static String _fingerprint(List<int> bytes) {
    var hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }
}
