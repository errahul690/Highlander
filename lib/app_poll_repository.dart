import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'otp_api.dart';
import 'session.dart';

class AppPollOption {
  const AppPollOption({
    required this.id,
    required this.text,
    required this.votes,
  });
  final String id, text;
  final int votes;
}

class AppPoll {
  const AppPoll({
    required this.id,
    required this.question,
    required this.options,
    required this.totalVotes,
    this.selectedOptionId,
    this.expiresAt,
    this.startsAt,
    this.backgroundColor,
    this.ctaText,
    this.pollName,
  });
  final String id, question;
  final List<AppPollOption> options;
  final int totalVotes;
  final String? selectedOptionId;
  final DateTime? expiresAt;
  final DateTime? startsAt;
  final String? backgroundColor;
  final String? ctaText;
  final String? pollName;

  bool get expired => expiresAt != null && !expiresAt!.isAfter(DateTime.now());
  bool get started => startsAt == null || !startsAt!.isAfter(DateTime.now());

  Color get cardBackgroundColor {
    if (backgroundColor == null || backgroundColor!.trim().isEmpty) {
      return const Color(0xFFFCF4F4);
    }
    try {
      var hex = backgroundColor!.replaceAll('#', '').trim();
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    } catch (_) {}
    return const Color(0xFFFCF4F4);
  }

  Color get cardBorderColor {
    final bg = cardBackgroundColor;
    if (bg.toARGB32() == const Color(0xFFFCF4F4).toARGB32()) {
      return const Color(0xFFF6D0D1);
    }
    final hsl = HSLColor.fromColor(bg);
    return hsl.withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0)).toColor();
  }

  String get effectiveCtaText {
    if (ctaText != null && ctaText!.trim().isNotEmpty) {
      return ctaText!.trim();
    }
    return 'Vote to see results';
  }

  factory AppPoll.fromJson(Map value) {
    final rawOptions = value['options'];
    if (value['_id'] is! String ||
        value['question'] is! String ||
        rawOptions is! List ||
        rawOptions.length < 2) {
      throw const FormatException();
    }
    return AppPoll(
      id: value['_id'] as String,
      pollName: value['poll_name'] as String?,
      question: value['question'] as String,
      totalVotes: (value['total_votes'] as num?)?.toInt() ?? 0,
      selectedOptionId: value['selected_option_id'] as String?,
      backgroundColor: value['background_color'] as String?,
      ctaText: value['cta_text'] as String?,
      startsAt: value['starts_at'] is String
          ? DateTime.tryParse(value['starts_at'] as String)
          : null,
      expiresAt: value['expires_at'] is String
          ? DateTime.tryParse(value['expires_at'] as String)
          : null,
      options: rawOptions.map((option) {
        if (option is! Map ||
            option['_id'] is! String ||
            option['text'] is! String) {
          throw const FormatException();
        }
        return AppPollOption(
          id: option['_id'] as String,
          text: option['text'] as String,
          votes: (option['votes'] as num?)?.toInt() ?? 0,
        );
      }).toList(),
    );
  }
}

class AppPollRepository {
  AppPollRepository({http.Client? client}) : _client = client ?? http.Client();
  static AppPollRepository instance = AppPollRepository();
  final http.Client _client;
  List<AppPoll> _polls = [];
  List<AppPoll> get polls => _polls;
  AppPoll? _current;
  AppPoll? get current => _current ?? (_polls.isNotEmpty ? _polls.first : null);
  int _loadVersion = 0;

  Future<AppPoll?> load() async {
    final version = ++_loadVersion;
    try {
      final response = await _client
          .get(
            Uri.parse('${OtpApi.apiBase}/api/user/polls'),
            headers: {'Authorization': 'Bearer ${Session.token}'},
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return _current;
      final data = jsonDecode(response.body);
      if (data is! Map || data['success'] != true) return _current;

      final List<AppPoll> loaded = [];
      if (data['polls'] is List && (data['polls'] as List).isNotEmpty) {
        for (final item in data['polls'] as List) {
          if (item is Map) {
            try {
              loaded.add(AppPoll.fromJson(item));
            } catch (_) {}
          }
        }
      } else if (data['poll'] is Map) {
        try {
          loaded.add(AppPoll.fromJson(data['poll'] as Map));
        } catch (_) {}
      }

      if (version == _loadVersion) {
        _polls = loaded;
        _current = loaded.isNotEmpty ? loaded.first : null;
      }
    } catch (_) {
      /* Keep the last valid polls while offline. */
    }
    return _current;
  }

  Future<AppPoll> vote(String optionId, {String? pollId}) async {
    final payload = <String, dynamic>{'option_id': optionId};
    if (pollId != null && pollId.isNotEmpty) {
      payload['poll_id'] = pollId;
    }
    final response = await _client
        .post(
          Uri.parse('${OtpApi.apiBase}/api/user/polls/vote'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${Session.token}',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        data is! Map ||
        data['success'] != true ||
        data['poll'] is! Map) {
      throw const FormatException('Could not save vote.');
    }
    final poll = AppPoll.fromJson(data['poll'] as Map);
    _loadVersion++;
    final index = _polls.indexWhere((p) => p.id == poll.id);
    if (index >= 0) {
      _polls[index] = poll;
    } else {
      _polls.insert(0, poll);
    }
    _current = _polls.isNotEmpty ? _polls.first : poll;
    return poll;
  }
}
