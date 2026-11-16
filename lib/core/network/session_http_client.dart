import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:Highlanders/core/session/session.dart';

/// Expired/missing bearer credentials sign out the session that made the request.
/// A late response from an old session cannot clear a newer login.
class SessionHttpClient extends http.BaseClient {
  SessionHttpClient(this._inner);
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final authorization = request.headers['authorization'];
    final bearer = authorization?.startsWith('Bearer ') == true;
    final expectedToken = bearer ? authorization!.substring(7) : '';
    final path = request.url.path;
    final requiresSession =
        path.endsWith('/auth/me') ||
        path.startsWith('/api/community') ||
        path.startsWith('/api/integration/') ||
        (path.startsWith('/api/user/') &&
            !const {
              '/api/user/email-session',
              '/api/user/mobile-session',
              '/api/user/complete-profile',
            }.contains(path));
    final response = await _inner.send(request);
    if (response.statusCode == 401 && (bearer || requiresSession)) {
      final bytes = await response.stream.toBytes();
      var emailVerificationRequired = false;
      if (request.method == 'PUT' && path.endsWith('/auth/me')) {
        try {
          final data = jsonDecode(utf8.decode(bytes));
          // This authenticated endpoint also uses 401 for missing email OTP
          // proof. Those errors must not discard a valid login session.
          emailVerificationRequired =
              data is Map &&
              const {
                'Verify your existing email address with OTP before changing it.',
                'Verify the new email address with OTP before saving.',
              }.contains(data['message']);
        } catch (_) {}
      }
      if (!emailVerificationRequired) {
        await Session.invalidate(expectedToken, allowEmpty: true);
      }
      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        headers: response.headers,
        contentLength: bytes.length,
        request: response.request,
        reasonPhrase: response.reasonPhrase,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
      );
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
