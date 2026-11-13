import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'chat_media_cache.dart';
import 'chat_file_cache.dart';

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'otp_api.dart';
import 'session.dart';
import 'network_read.dart';

class PostsApi {
  PostsApi({http.Client? client}) : _client = client ?? http.Client();
  static PostsApi instance = PostsApi();
  final http.Client _client;

  Future<Map<String, dynamic>> uploadChatAttachment({
    required String path,
    required String name,
    required String type,
  }) async {
    final file = File(path);
    final uploadToken = Session.token;
    try {
      if (await file.length() > 15 * 1024 * 1024) {
        throw Exception('Choose a file smaller than 15 MB.');
      }
      final bytes = await file.readAsBytes();
      Future<Map<String, dynamic>> uploadBytes(
        Uint8List content,
        String filename,
        String mime,
      ) async {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${OtpApi.apiBase}/api/integration/upload-file'),
        );
        request.headers['Authorization'] = 'Bearer $uploadToken';
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            content,
            filename: filename,
            contentType: MediaType.parse(mime),
          ),
        );
        final response = await http.Response.fromStream(
          await _client.send(request).timeout(const Duration(seconds: 60)),
        );
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode >= 400 || result['success'] != true) {
          throw Exception(result['message'] ?? 'Attachment upload failed.');
        }
        return result;
      }

      final preview = type.startsWith('image/')
          ? createChatThumbnail(bytes).catchError((Object _) => Uint8List(0))
          : Future.value(Uint8List(0));
      final result = await uploadBytes(bytes, name, type);
      final url = '${result['file_url'] ?? result['url']}';
      String? thumbnail;
      if (type.startsWith('image/')) {
        if (Session.token == uploadToken) {
          unawaited(ChatMediaCache.instance.seed(url, bytes));
        }
        final small = await preview;
        if (small.isNotEmpty && small.length < bytes.length * .8) {
          try {
            final uploaded = await uploadBytes(
              small,
              'chat-preview.png',
              'image/png',
            );
            thumbnail = '${uploaded['file_url'] ?? uploaded['url']}';
            if (Session.token == uploadToken) {
              unawaited(
                ChatMediaCache.instance.seed(
                  thumbnail,
                  small,
                  saveDisplay: false,
                ),
              );
            }
          } catch (_) {
            /* A failed preview must not discard a successful photo upload. */
          }
        }
      }
      if (!type.startsWith('image/') && Session.token == uploadToken) {
        await ChatFileCache.instance.seed(url, name, bytes);
      }
      return {
        'url': url,
        'name': result['originalname'] ?? name,
        'type': result['mimetype'] ?? type,
        'thumbnail': ?thumbnail,
      };
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<String> upload(XFile file) async {
    if (await file.length() > 15 * 1024 * 1024) {
      throw Exception('Choose a file smaller than 15 MB.');
    }
    final extension = file.name.split('.').last.toLowerCase();
    const types = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'avif': 'image/avif',
      'mp4': 'video/mp4',
      'webm': 'video/webm',
    };
    final type = types[extension];
    if (type == null) {
      throw Exception('Choose a supported image, MP4 or WebM video.');
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${OtpApi.apiBase}/api/user/posts/uploads'),
    );
    request.headers['Authorization'] = 'Bearer ${Session.token}';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await file.readAsBytes(),
        filename: file.name,
        contentType: MediaType.parse(type),
      ),
    );
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 60)),
    );
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || result['success'] != true) {
      throw Exception(result['message'] ?? 'Upload failed.');
    }
    return result['file_url'] as String;
  }

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = Uri.parse('${OtpApi.apiBase}$path');
    final sessionToken = Session.token;
    final headers = {
      'Content-Type': 'application/json',
      if (Session.token.isNotEmpty) 'Authorization': 'Bearer ${Session.token}',
    };
    http.Response response;
    if (method == 'POST') {
      response = await _client
          .post(uri, headers: headers, body: jsonEncode(body ?? {}))
          .timeout(timeout);
    } else if (method == 'PUT') {
      response = await _client
          .put(uri, headers: headers, body: jsonEncode(body ?? {}))
          .timeout(timeout);
    } else if (method == 'DELETE') {
      response = await _client.delete(uri, headers: headers).timeout(timeout);
    } else {
      response = await getWithRetry(
        _client,
        uri,
        headers: headers,
        timeout: timeout,
        canRetry: () => Session.token == sessionToken,
      );
    }
    dynamic result;
    try {
      result = jsonDecode(response.body);
    } on FormatException {
      throw ApiRequestException(
        response.statusCode == 401
            ? 'Please log in to continue.'
            : 'Could not load this content. Please try again.',
        response.statusCode,
      );
    }
    if (result is! Map<String, dynamic>) {
      throw Exception('Could not load post.');
    }
    if (result['code'] == 'ACCOUNT_INACTIVE') {
      await Session.invalidate(sessionToken);
    }
    if (response.statusCode == 401) {
      throw ApiRequestException(
        'Please log in to continue.',
        response.statusCode,
      );
    }
    if (response.statusCode >= 400 || result['success'] != true) {
      throw ApiRequestException(
        '${result['message'] ?? 'Request failed.'}',
        response.statusCode,
      );
    }
    return result;
  }

  String get readPath =>
      Session.token.isEmpty ? '/api/public/posts' : '/api/user/posts';
  Future<Map<String, dynamic>> getPost(String id) async =>
      (await request('$readPath/$id'))['post'] as Map<String, dynamic>;

  Future<void> deletePost(String id) async {
    await request('/api/user/posts/$id', method: 'DELETE');
  }

  Future<Map<String, dynamic>> updatePost(
    String id, {
    required String content,
    String? backgroundColor,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (backgroundColor != null && backgroundColor.isNotEmpty) {
      body['backgroundColor'] = backgroundColor;
    }
    final res = await request('/api/user/posts/$id', method: 'PUT', body: body);
    return res['post'] as Map<String, dynamic>;
  }

  Future<void> reportPost(
    String id, {
    required String reason,
    String reportType = 'report_post',
  }) async {
    await request(
      '/api/user/posts/$id/report',
      method: 'POST',
      body: {'reason': reason, 'report_type': reportType},
    );
  }

  Future<void> blockUser(String id) async {
    await request('/api/user/posts/$id/block', method: 'POST');
  }
}
