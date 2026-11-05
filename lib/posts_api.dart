import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'otp_api.dart';
import 'session.dart';

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
    try {
      if (await file.length() > 15 * 1024 * 1024) {
        throw Exception('Choose a file smaller than 15 MB.');
      }
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${OtpApi.apiBase}/api/integration/upload-file'),
      );
      request.headers['Authorization'] = 'Bearer ${Session.token}';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          await file.readAsBytes(),
          filename: name,
          contentType: MediaType.parse(type),
        ),
      );
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 60)),
      );
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || result['success'] != true) {
        throw Exception(result['message'] ?? 'Attachment upload failed.');
      }
      return {
        'url': result['file_url'] ?? result['url'],
        'name': result['originalname'] ?? name,
        'type': result['mimetype'] ?? type,
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
      response = await _client.get(uri, headers: headers).timeout(timeout);
    }
    final result = jsonDecode(response.body);
    if (result is! Map<String, dynamic>) {
      throw Exception('Could not load post.');
    }
    if (response.statusCode == 401) {
      throw Exception('Please log in to continue.');
    }
    if (response.statusCode >= 400 || result['success'] != true) {
      throw Exception(result['message'] ?? 'Request failed.');
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
