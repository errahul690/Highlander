import 'posts_api.dart';

class CommunityApi {
  static CommunityApi instance = CommunityApi();
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final result = await PostsApi.instance.request(
      '/api/community$path',
      method: method,
      body: body,
    );
    return result['data'];
  }

  Future<List<Map<String, dynamic>>> list(String path) async =>
      (await request(path) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .where(
            (row) =>
                path.split('?').first != '/groups' ||
                row['membership'] == 'active' ||
                row['canManage'] == true,
          )
          .toList();

  Future<Map<String, dynamic>> uploadAttachment(Map<String, dynamic> picked) =>
      PostsApi.instance.uploadChatAttachment(
        path: '${picked['path']}',
        name: '${picked['name']}',
        type: '${picked['type'] ?? 'application/octet-stream'}',
      );
}
