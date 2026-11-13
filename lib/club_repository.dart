import 'dart:convert';

import 'package:http/http.dart' as http;

import 'match_card_cache.dart';
import 'models.dart';
import 'otp_api.dart';
import 'network_read.dart';

class ClubRepository {
  ClubRepository({http.Client? client, MatchCardCache? cards})
    : _client = client ?? http.Client(),
      _cards = cards ?? MatchCardCache.instance;

  static final ClubRepository instance = ClubRepository();
  final http.Client _client;
  final MatchCardCache _cards;

  static String get apiBase => OtpApi.apiBase;
  static String mediaUrl(Object? value) {
    final image = value?.toString() ?? '';
    return image.isEmpty ? '' : Uri.parse(apiBase).resolve(image).toString();
  }

  static String _videoUrl(Object? videos) {
    if (videos is! List) return '';
    for (final video in videos.whereType<Map>()) {
      final url = Uri.tryParse('${video['url'] ?? ''}');
      if (url != null &&
          ['http', 'https'].contains(url.scheme) &&
          url.host.isNotEmpty) {
        return url.toString();
      }
    }
    return '';
  }

  static List<MatchLink> _links(Object? value, {bool allowUploads = false}) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .where((row) {
          if (allowUploads &&
              RegExp(
                r'^/uploads/[a-zA-Z0-9_-]+\.(mp4|webm)$',
                caseSensitive: false,
              ).hasMatch('${row['url'] ?? ''}'))
            return true;
          final uri = Uri.tryParse('${row['url'] ?? ''}');
          return uri != null &&
              ['http', 'https'].contains(uri.scheme) &&
              uri.host.isNotEmpty;
        })
        .map(
          (row) => MatchLink(
            url: '${row['url']}',
            title: '${row['title'] ?? ''}',
            sourceUrl: '${row['source_url'] ?? ''}',
            description: '${row['description'] ?? ''}',
          ),
        )
        .toList();
  }

  static String _storyHtml(Object? value) {
    return '${value ?? ''}'
        .replaceAll(
          RegExp(r'<(script|style)\b[^>]*>[\s\S]*?</\1>', caseSensitive: false),
          '',
        )
        .trim();
  }

  ClubContent? _cached;
  List<Player>? _lastPlayers;
  Future<ClubContent>? _pending;
  int _loadGeneration = 0;

  ClubContent? get cachedOrNull => _cached;
  ClubContent get cachedContent => _cached ?? clubFallback;

  Future<void> refreshCardOverlay() async {
    try {
      final response = await _client
          .get(Uri.parse('$apiBase/api/public/app-settings'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return;
      final settings = jsonDecode(response.body);
      if (settings is Map &&
          (settings.containsKey('match_card_overlay') ||
              settings.containsKey('match_card_image'))) {
        await _cards.sync(
          overlay: settings['match_card_overlay'],
          url: mediaUrl(settings['match_card_image']),
          client: _client,
        );
      }
    } catch (_) {}
  }

  Future<ClubContent> load({bool forceRefresh = false}) {
    if (!forceRefresh && _cached != null) {
      return Future.value(_cached!);
    }
    if (!forceRefresh && _pending != null) return _pending!;
    final generation = ++_loadGeneration;
    final pending = _fetch(generation, forceRefresh: forceRefresh);
    _pending = pending;
    return pending;
  }

  Future<ClubContent> _fetch(
    int generation, {
    bool forceRefresh = false,
  }) async {
    final stamp = forceRefresh
        ? '${DateTime.now().microsecondsSinceEpoch}'
        : null;
    final headers = forceRefresh
        ? const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'}
        : const <String, String>{};
    Uri endpoint(String path) =>
        Uri.parse('$apiBase$path')
            .replace(queryParameters: stamp == null ? null : {'t': stamp});
    try {
      final futures = await Future.wait([
        getWithRetry(
          _client,
          endpoint('/api/public/squad-members'),
          headers: headers,
          timeout: const Duration(seconds: 4),
          canRetry: () => generation == _loadGeneration,
        ).catchError((_) => http.Response('[]', 500)),
        _client
            .get(endpoint('/api/public/knockout-matches'), headers: headers)
            .timeout(Duration(seconds: forceRefresh ? 12 : 4))
            .catchError((_) => http.Response('[]', 500)),
        _client
            .get(Uri.parse('$apiBase/api/public/news'))
            .timeout(const Duration(seconds: 4))
            .catchError((_) => http.Response('[]', 500)),
        _client
            .get(Uri.parse('$apiBase/api/public/app-settings'))
            .timeout(const Duration(seconds: 4))
            .catchError((_) => http.Response('{}', 500)),
      ]);

      List<Player> players = _lastPlayers ?? _cached?.players ?? const [];
      var playersUnavailable = true;
      if (futures[0].statusCode == 200) {
        try {
          final parsed = (jsonDecode(futures[0].body) as List)
              .map(
                (row) => Player(
                  name: '${row['display_name'] ?? ''}',
                  jersey: '${row['jersey'] ?? ''}'.trim(),
                  position:
                      '${row['position_label']?.toString().isNotEmpty == true ? row['position_label'] : row['position'] ?? ''}',
                  image: mediaUrl(
                    row['profile_image']?.toString().isNotEmpty == true
                        ? row['profile_image']
                        : row['front_card_image'],
                  ),
                  frontImage: mediaUrl(
                    row['front_card_image']?.toString().isNotEmpty == true
                        ? row['front_card_image']
                        : row['profile_image'],
                  ),
                  quote: '${row['quote'] ?? ''}',
                  nationality: '${row['nationality'] ?? 'India'}',
                  firstName: '${row['first_name'] ?? ''}',
                  lastName: '${row['last_name'] ?? ''}',
                  positionCode: '${row['position'] ?? ''}',
                  displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
                ),
              )
              .where((player) => player.name.isNotEmpty)
              .toList();
          players = parsed;
          playersUnavailable = false;
          if (generation == _loadGeneration) _lastPlayers = parsed;
        } catch (_) {}
      }

      List<Fixture> fixtures = [];
      var fixturesUnavailable = true;
      if (futures[1].statusCode == 200) {
        try {
          final parsed = (jsonDecode(futures[1].body) as List)
              .map(
                (row) => Fixture(
                  id: '${row['id'] ?? row['_id'] ?? ''}',
                  home: '${row['home_team'] ?? ''}',
                  away: '${row['away_team'] ?? ''}',
                  date: '${row['match_date'] ?? ''}',
                  time: '${row['match_time'] ?? ''}',
                  venue: '${row['venue'] ?? ''}',
                  round: '${row['round'] ?? ''}',
                  section: '${row['section'] ?? ''}',
                  homeScore: (row['home_score'] as num?)?.toInt(),
                  awayScore: (row['away_score'] as num?)?.toInt(),
                  homeScoreText: '${row['home_score_text'] ?? ''}',
                  awayScoreText: '${row['away_score_text'] ?? ''}',
                  heading: '${row['match_heading'] ?? ''}',
                  homeAway: '${row['home_away'] ?? ''}',
                  homeLogo: mediaUrl(row['home_team_logo']),
                  awayLogo: mediaUrl(row['away_team_logo']),
                  homeLogoBackground: '${row['home_logo_background'] ?? ''}',
                  awayLogoBackground: '${row['away_logo_background'] ?? ''}',
                  details: MatchDetails.fromJson(row['match_details']),
                  videoUrl: _videoUrl(row['videos']),
                  summary: '${row['short_description'] ?? ''}',
                  report: _storyHtml(row['rich_content']),
                  sourceUrl: '${row['source_url'] ?? ''}',
                  winner: '${row['winner'] ?? ''}',
                  matchStatus: '${row['match_status'] ?? 'Upcoming'}',
                  feedThumbnail: mediaUrl(row['feed_thumbnail']),
                  previewThumbnail: mediaUrl(row['preview_thumbnail']),
                  reportThumbnail: mediaUrl(row['report_thumbnail']),
                  previewTitle: '${row['preview_title'] ?? ''}',
                  previewDescription: '${row['preview_description'] ?? ''}',
                  previewContent: _storyHtml(row['preview_content']),
                  liveThumbnail: '${row['live_thumbnail'] ?? ''}',
                  liveOverlay: (row['live_overlay'] as num?)?.toDouble(),
                  previewUrl: '${row['preview_url'] ?? ''}',
                  reportTitle: '${row['report_title'] ?? ''}',
                  reportUrl: '${row['report_url'] ?? ''}',
                  liveUrl: '${row['live_url'] ?? ''}',
                  journeyStage: '${row['journey_stage'] ?? ''}',
                  images: row['images'] is List
                      ? (row['images'] as List)
                            .whereType<String>()
                            .where((url) => url.isNotEmpty)
                            .map(mediaUrl)
                            .toList()
                      : [],
                  previewPhotos: row['preview_photos'] is List
                      ? (row['preview_photos'] as List)
                            .whereType<Map>()
                            .map((photo) {
                              final url = mediaUrl(photo['url']);
                              return url.isEmpty
                                  ? null
                                  : MatchPhoto(
                                      url: url,
                                      caption: '${photo['caption'] ?? ''}',
                                    );
                            })
                            .whereType<MatchPhoto>()
                            .toList()
                      : [],
                  previewVideos: _links(
                    row['preview_videos'],
                    allowUploads: true,
                  ),
                  videos: _links(row['videos'], allowUploads: true),
                  links: _links(row['links']),
                ),
              )
              .toList();
          fixtures = parsed;
          fixturesUnavailable = false;
        } catch (_) {}
      }

      List<Story> stories = clubFallback.stories;
      if (futures[2].statusCode == 200) {
        try {
          final parsed = (jsonDecode(futures[2].body) as List)
              .map(
                (row) => Story(
                  title: '${row['title'] ?? ''}',
                  category: '${row['category'] ?? 'News'}',
                ),
              )
              .where((story) => story.title.isNotEmpty)
              .toList();
          if (parsed.isNotEmpty) {
            stories = parsed;
          }
        } catch (_) {}
      }

      var defaultThumbnail = _cached?.defaultMatchThumbnail ?? '';
      if (futures[3].statusCode == 200) {
        try {
          final settings = jsonDecode(futures[3].body);
          if (settings is Map && settings['success'] == true) {
            defaultThumbnail = mediaUrl(
              settings['feed_match_default_thumbnail'],
            );
            if (settings.containsKey('match_card_overlay') ||
                settings.containsKey('match_card_image')) {
              await _cards.sync(
                overlay: settings['match_card_overlay'],
                url: mediaUrl(settings['match_card_image']),
                client: _client,
              );
            }
          }
        } catch (_) {}
      }
      final content = ClubContent(
        players: players,
        playersUnavailable: playersUnavailable,
        fixtures: fixtures,
        fixturesUnavailable: fixturesUnavailable,
        stories: stories,
        defaultMatchThumbnail: defaultThumbnail,
      );
      if (generation == _loadGeneration &&
          !fixturesUnavailable &&
          !playersUnavailable) {
        _cached = content;
      }
      return content;
    } catch (_) {
      return ClubContent(
        players: _lastPlayers ?? _cached?.players ?? const [],
        playersUnavailable: true,
        fixtures: const [],
        stories: _cached?.stories ?? clubFallback.stories,
        fixturesUnavailable: true,
      );
    } finally {
      if (generation == _loadGeneration) _pending = null;
    }
  }
}

const clubFallback = ClubContent(
  players: [],
  fixtures: [],
  stories: [
    Story(
      title:
          'NorthEast United FC Reach Fourth Consecutive Durand Cup Semi-Final',
      category: 'Match Report',
    ),
  ],
);
