import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class OtpApi {
  OtpApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  bool smsDeliverySkipped = false;
  String mobileVerificationToken = '';
  String emailVerificationToken = '';
  static OtpApi instance = OtpApi();
  static String _apiBase = '';
  static String frontendUrl = '';
  static String get apiBase => _apiBase;
  static set apiBase(String value) {
    var base = value.trim().replaceFirst(RegExp(r'/+$'), '');
    // All app clients add /api themselves; keep the shared base at the server.
    if (base.endsWith('/api')) base = base.substring(0, base.length - 4);
    if (base.isNotEmpty) {
      final uri = Uri.tryParse(base);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw const OtpApiException(
          'API_BASE_URL must be an http:// or https:// server URL.',
        );
      }
    }
    _apiBase = base;
  }

  static Future<void> loadEnvironment() async {
    final raw = await rootBundle.loadString('.env');
    String? url;
    String? frontend;
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final split = trimmed.indexOf('=');
      if (split <= 0) continue;
      final key = trimmed.substring(0, split).trim();
      if (key != 'API_BASE_URL' && key != 'FRONTEND_URL') continue;
      var value = trimmed.substring(split + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      if (key == 'API_BASE_URL') {
        url = value.trim();
      } else {
        frontend = value.trim();
      }
    }
    if (url == null || url.isEmpty) {
      throw const OtpApiException('Set API_BASE_URL in the .env file.');
    }
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    apiBase = url;
    frontendUrl = frontend ?? '';
  }

  static List<String> get candidateBases {
    final base = apiBase.trim();
    return base.isEmpty ? const [] : [base];
  }

  static List<String> get _candidateBases => candidateBases;

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> body,
  ) async {
    final bases = _candidateBases;
    if (bases.isEmpty) {
      throw const OtpApiException('Set API_BASE_URL in the .env file.');
    }
    OtpApiException? lastOtpException;
    Object? lastError;

    for (final base in bases) {
      try {
        final response = await _client
            .post(
              Uri.parse('$base$path'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(body),
            )
            // SMTP delivery and the live-server round trip can exceed 5 seconds.
            .timeout(const Duration(seconds: 30));

        dynamic data;
        try {
          data = jsonDecode(response.body);
        } on FormatException {
          throw OtpApiException(
            'OTP server returned an invalid response (HTTP ${response.statusCode}). Check API_BASE_URL.',
          );
        }
        if (data is! Map<String, dynamic>) {
          throw OtpApiException(
            'OTP server returned an invalid response (HTTP ${response.statusCode}). Check API_BASE_URL.',
          );
        }
        if (response.statusCode < 200 ||
            response.statusCode >= 300 ||
            data['success'] != true) {
          final msg = data['message'] is String
              ? data['message'] as String
              : '';
          if (response.statusCode == 404 ||
              msg.toLowerCase().contains('invalid router') ||
              msg.toLowerCase().contains('not found')) {
            lastOtpException = OtpApiException(
              msg.isNotEmpty ? msg : 'Endpoint not found',
            );
            continue;
          }
          throw OtpApiException(
            msg.isNotEmpty ? msg : 'OTP request failed. Please try again.',
          );
        }

        apiBase = base;
        return data;
      } on OtpApiException catch (e) {
        lastOtpException = e;
        if (!e.message.toLowerCase().contains('not found') &&
            !e.message.toLowerCase().contains('invalid router')) {
          rethrow;
        }
      } on TimeoutException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastOtpException != null) throw lastOtpException;
    if (lastError is TimeoutException)
      throw const OtpApiException('Request timed out. Please try again.');
    throw const OtpApiException(
      'Cannot reach the OTP server. Please try again.',
    );
  }

  Future<int> send(String mobile) async {
    mobileVerificationToken = '';
    emailVerificationToken = '';
    final data = await _post('/api/common/otp/send', {'mobile': mobile});
    smsDeliverySkipped = data['deliverySkipped'] == true;
    return (data['resendAfterSeconds'] as num?)?.toInt() ?? 30;
  }

  Future<void> verify(String mobile, String otp) async {
    final data = await _post('/api/common/otp/verify', {
      'mobile': mobile,
      'otp': otp,
    });
    if (data['verified'] != true)
      throw const OtpApiException('OTP could not be verified.');
    mobileVerificationToken = _proofFromJson(data);
  }

  Future<int> resend(String mobile) async {
    mobileVerificationToken = '';
    final data = await _post('/api/common/otp/resend', {'mobile': mobile});
    smsDeliverySkipped = data['deliverySkipped'] == true;
    return (data['resendAfterSeconds'] as num?)?.toInt() ?? 30;
  }

  Future<SavedProfile?> findExistingProfile(String mobile) async {
    final data = await _post('/api/user/mobile-session', {
      'mobile': mobile,
      'mobileVerificationToken': mobileVerificationToken,
    });
    if (data['registered'] == false) return null;
    if (data['registered'] != true)
      throw const OtpApiException(
        'Could not check your account. Please try again.',
      );
    return SavedProfile.fromJson(data);
  }

  Future<EmailOtpResult> sendEmail(String email) async {
    emailVerificationToken = '';
    final data = await _post('/api/common/otp/email/send', {'email': email});
    return EmailOtpResult.fromJson(data);
  }

  Future<SavedProfile?> findEmailProfile(String email) async {
    final data = await _post('/api/user/email-session', {
      'email': email,
      'emailVerificationToken': emailVerificationToken,
    });
    if (data['registered'] == false) return null;
    if (data['registered'] != true) {
      throw const OtpApiException(
        'Could not check your account. Please try again.',
      );
    }
    return SavedProfile.fromJson(data);
  }

  Future<void> verifyEmail(String email, String otp, String requestId) async {
    final data = await _post('/api/common/otp/email/verify', {
      'email': email,
      'otp': otp,
      'requestId': requestId,
    });
    if (data['verified'] != true)
      throw const OtpApiException('Email could not be verified.');
    emailVerificationToken = _proofFromJson(data);
  }

  Future<EmailOtpResult> resendEmail(String email, String requestId) async {
    emailVerificationToken = '';
    final data = await _post('/api/common/otp/email/resend', {
      'email': email,
      'requestId': requestId,
    });
    return EmailOtpResult.fromJson(data);
  }

  String _proofFromJson(Map<String, dynamic> data) {
    final proof = data['verificationToken'];
    if (proof is! String || proof.isEmpty)
      throw const OtpApiException('Please restart the API and verify again.');
    return proof;
  }

  Future<SavedProfile> saveProfile({
    required String name,
    required String city,
    required String email,
    required String gender,
    String mobile = '',
    String dob = '',
  }) async {
    final data = await _post('/api/user/complete-profile', {
      'full_name': name,
      'city': city,
      'email': email,
      'gender': gender,
      'mobile': mobile,
      if (dob.isNotEmpty) 'dob': dob,
      'emailVerificationToken': emailVerificationToken,
    });
    return SavedProfile.fromJson(data);
  }
}

class SavedProfile {
  const SavedProfile({
    required this.id,
    required this.token,
    required this.name,
    required this.email,
    required this.mobile,
    required this.city,
    this.emailVerified = true,
    this.mobileVerified = false,
    this.profilePhoto = '',
    this.coverPhoto = '',
    this.gender = '',
    this.dob = '',
  });
  final String id, token, name, email, mobile, city;
  final bool emailVerified, mobileVerified;
  final String profilePhoto;
  final String coverPhoto;
  final String gender;
  final String dob;

  factory SavedProfile.fromJson(Map<String, dynamic> data) {
    final user = data['user'];
    if (user is! Map<String, dynamic> ||
        user['role'] != 'user' ||
        data['token'] is! String ||
        user['id'] is! String) {
      throw const OtpApiException(
        'Profile could not be saved. Please try again.',
      );
    }
    return SavedProfile(
      id: user['id'] as String,
      token: data['token'] as String,
      name: user['full_name'] as String? ?? '',
      email: user['email'] as String? ?? '',
      mobile: user['mobile'] as String? ?? '',
      city: user['city'] as String? ?? '',
      gender: user['gender'] as String? ?? '',
      dob: user['dob'] as String? ?? '',
      emailVerified: user['email_verified'] == true,
      mobileVerified: user['mobile_verified'] == true,
      profilePhoto: (user['profile_photo'] as String?)?.isNotEmpty == true
          ? user['profile_photo'] as String
          : user['profileImage'] as String? ?? '',
      coverPhoto: (user['cover_photo'] as String?)?.isNotEmpty == true
          ? user['cover_photo'] as String
          : user['coverImage'] as String? ?? '',
    );
  }
}

class EmailOtpResult {
  const EmailOtpResult(
    this.requestId,
    this.resendAfterSeconds, {
    this.deliverySkipped = false,
  });
  final String requestId;
  final int resendAfterSeconds;
  final bool deliverySkipped;

  factory EmailOtpResult.fromJson(Map<String, dynamic> data) {
    if (data['requestId'] is! String || (data['requestId'] as String).isEmpty) {
      throw const OtpApiException(
        'Email OTP request failed. Please try again.',
      );
    }
    return EmailOtpResult(
      data['requestId'] as String,
      (data['resendAfterSeconds'] as num?)?.toInt() ?? 30,
      deliverySkipped: data['deliverySkipped'] == true,
    );
  }
}

class OtpApiException implements Exception {
  const OtpApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
