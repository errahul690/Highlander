import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'otp_api.dart';
import 'push_alerts.dart';

class Session {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'highlanders.session.v1';
  static String userId = '';
  static String token = '';
  static String role = 'user';
  static String phone = '';
  static bool phoneVerified = false;
  static int otpResendSeconds = 30;
  static String emailOtpRequestId = '';
  static bool emailOtpDeliverySkipped = false;
  static String city = '';
  static String email = '';
  static bool emailVerified = false;
  static String name = 'Highlander';
  static String profilePhoto = '';
  static final profileChanges = ValueNotifier<int>(0);
  static void Function()? onInvalidated;

  static Future<void> invalidate(String expectedToken) async {
    if (expectedToken.isEmpty || token != expectedToken) return;
    clear();
    onInvalidated?.call();
    await PushAlerts.stop(sessionToken: expectedToken);
    try {
      await _storage.delete(key: _storageKey);
    } catch (_) {
      // The server continues rejecting this session if storage is unavailable.
    }
  }

  static void handleSocketError(dynamic error, String expectedToken) {
    if (error is Map &&
        error['data'] is Map &&
        error['data']['code'] == 'ACCOUNT_INACTIVE') {
      invalidate(expectedToken);
    }
  }

  static String bio = '';
  static String username = '';
  static String gender = '';
  static String dob = '';
  static String favoritePlayer = '';

  // This only selects the startup screen. Protected APIs still verify the JWT.
  static bool get isSignedIn =>
      userId.isNotEmpty && _tokenIsCurrent(token, userId);
  static bool _tokenIsCurrent(String value, String id) {
    try {
      final parts = value.split('.');
      if (parts.length != 3) return false;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return claims is Map &&
          claims['role'] == 'user' &&
          (claims['_id'] ?? claims['id']) == id &&
          claims['exp'] is num &&
          (claims['exp'] as num) * 1000 > DateTime.now().millisecondsSinceEpoch;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveProfile(SavedProfile profile) async {
    await _storage.write(
      key: _storageKey,
      value: jsonEncode({
        'id': profile.id,
        'token': profile.token,
        'name': profile.name,
        'city': profile.city,
        'email': profile.email,
        'mobile': profile.mobile,
        'emailVerified': profile.emailVerified,
        'mobileVerified': profile.mobileVerified,
        'profilePhoto': profile.profilePhoto,
        'gender': profile.gender,
        'dob': profile.dob,
      }),
    );
    _applyProfile(profile);
  }

  static void _applyProfile(SavedProfile profile) {
    userId = profile.id;
    token = profile.token;
    role = 'user';
    name = profile.name.isEmpty ? 'Highlander' : profile.name;
    city = profile.city;
    email = profile.email;
    phone = profile.mobile.replaceFirst(RegExp(r'^91'), '');
    phoneVerified = profile.mobileVerified;
    emailVerified = profile.emailVerified;
    profilePhoto = profile.profilePhoto;
    gender = profile.gender;
    dob = profile.dob;
    profileChanges.value++;
  }

  static Future<bool> restore() async {
    clear();
    String? saved;
    try {
      saved = await _storage.read(key: _storageKey);
    } catch (_) {
      return false;
    } // A temporary storage failure must not erase data.
    if (saved == null) return false;
    try {
      final data = jsonDecode(saved) as Map<String, dynamic>;
      final profile = SavedProfile(
        id: data['id'] as String,
        token: data['token'] as String,
        name: data['name'] as String,
        email: data['email'] as String,
        mobile: data['mobile'] as String,
        city: data['city'] as String,
        emailVerified: data['emailVerified'] == true,
        mobileVerified: data['mobileVerified'] == true,
        profilePhoto: data['profilePhoto'] as String? ?? '',
        gender: data['gender'] as String? ?? '',
      );
      if (!_tokenIsCurrent(profile.token, profile.id)) {
        await _discardStoredSession();
        return false;
      }
      _applyProfile(profile);
      if (data['profilePhoto'] is String) {
        profilePhoto = data['profilePhoto'] as String;
      }
      if (data['bio'] is String) bio = data['bio'] as String;
      if (data['username'] is String) username = data['username'] as String;
      if (data['gender'] is String) gender = data['gender'] as String;
      if (data['dob'] is String) dob = data['dob'] as String;
      if (data['favoritePlayer'] is String) {
        favoritePlayer = data['favoritePlayer'] as String;
      }
      return true;
    } on FormatException {
      await _discardStoredSession();
      return false;
    } on TypeError {
      await _discardStoredSession();
      return false;
    }
  }

  static Future<void> updateDetails({
    String? name,
    String? phone,
    String? city,
    String? email,
    bool? emailVerified,
    String? profilePhoto,
    String? bio,
    String? username,
    String? gender,
    String? dob,
    String? favoritePlayer,
  }) async {
    if (name != null) Session.name = name;
    if (phone != null) Session.phone = phone;
    if (city != null) Session.city = city;
    if (email != null) Session.email = email;
    if (emailVerified != null) Session.emailVerified = emailVerified;
    if (profilePhoto != null) Session.profilePhoto = profilePhoto;
    if (bio != null) Session.bio = bio;
    if (username != null) Session.username = username;
    if (gender != null) Session.gender = gender;
    if (dob != null) Session.dob = dob;
    if (favoritePlayer != null) Session.favoritePlayer = favoritePlayer;

    if (profilePhoto != null && profilePhoto.isNotEmpty) {
      await NetworkImage(
        Uri.parse(OtpApi.apiBase).resolve(profilePhoto).toString(),
      ).evict();
    }
    profileChanges.value++;

    try {
      final existing = await _storage.read(key: _storageKey);
      final map = existing != null
          ? jsonDecode(existing) as Map<String, dynamic>
          : <String, dynamic>{};
      map['name'] = Session.name;
      map['mobile'] = Session.phone;
      map['city'] = Session.city;
      map['email'] = Session.email;
      map['emailVerified'] = Session.emailVerified;
      map['profilePhoto'] = Session.profilePhoto;
      map['bio'] = Session.bio;
      map['username'] = Session.username;
      map['gender'] = Session.gender;
      map['dob'] = Session.dob;
      map['favoritePlayer'] = Session.favoritePlayer;
      await _storage.write(key: _storageKey, value: jsonEncode(map));
    } catch (_) {}
  }

  static Future<void> logout() async {
    await PushAlerts.stop();
    await _storage.delete(key: _storageKey);
    clear();
  }

  static Future<void> _discardStoredSession() async {
    clear();
    await PushAlerts.stop();
    try {
      await _storage.delete(key: _storageKey);
    } catch (_) {
      /* Retry on next startup. */
    }
  }

  static void clear() {
    userId = '';
    token = '';
    role = 'user';
    phone = '';
    phoneVerified = false;
    otpResendSeconds = 30;
    emailOtpRequestId = '';
    emailOtpDeliverySkipped = false;
    city = '';
    email = '';
    emailVerified = false;
    name = 'Highlander';
    profilePhoto = '';
    bio = '';
    username = '';
    gender = '';
    dob = '';
    favoritePlayer = '';
    profileChanges.value++;
  }

  static void signIn(String value) {
    email = value.trim().toLowerCase();
    final local = email.split('@').first;
    name = local.isEmpty
        ? 'Highlander'
        : local[0].toUpperCase() + local.substring(1);
  }
}
