import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiRequestException implements Exception {
  const ApiRequestException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

bool _temporaryStatus(int status) =>
    const {408, 429, 500, 502, 503, 504}.contains(status);

bool isTemporaryReadFailure(Object error) =>
    error is TimeoutException ||
    error is SocketException ||
    error is http.ClientException ||
    (error is ApiRequestException && _temporaryStatus(error.statusCode));

/// Retry only reads, once, without replaying user actions or auth failures.
Future<http.Response> getWithRetry(
  http.Client client,
  Uri uri, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 10),
  Duration retryDelay = const Duration(milliseconds: 400),
  bool Function()? canRetry,
}) async {
  var delay = retryDelay;
  for (var attempt = 0; ; attempt++) {
    try {
      final response = await client.get(uri, headers: headers).timeout(timeout);
      if (attempt != 0 ||
          !_temporaryStatus(response.statusCode) ||
          canRetry?.call() == false) {
        return response;
      }
      final retryAfter = response.headers['retry-after'];
      if (retryAfter != null) {
        final seconds = int.tryParse(retryAfter);
        // Respect longer server cooldowns; a screen refresh can try again later.
        if (seconds == null || seconds > 2 || seconds < 0) return response;
        final requestedDelay = Duration(seconds: seconds);
        if (requestedDelay > delay) delay = requestedDelay;
      } else if (response.statusCode == 429) {
        return response;
      }
      await Future<void>.delayed(delay);
      if (canRetry?.call() == false) return response;
    } catch (error) {
      if (attempt != 0 ||
          !isTemporaryReadFailure(error) ||
          canRetry?.call() == false) {
        rethrow;
      }
      await Future<void>.delayed(delay);
      if (canRetry?.call() == false) rethrow;
    }
  }
}

/// Screen-local state: keep a successful result during temporary refresh failures.
class RetainedRead<T extends Object> {
  T? value;
  int _version = 0;

  Future<T> load(Future<T> Function() fetch) async {
    final version = ++_version;
    try {
      final result = await fetch();
      if (version == _version) value = result;
      return result;
    } catch (error) {
      if (version == _version &&
          error is ApiRequestException &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        value = null;
      }
      if (value != null && isTemporaryReadFailure(error)) return value!;
      rethrow;
    }
  }
}
