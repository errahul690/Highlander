import 'dart:convert';

import 'package:http/http.dart' as http;

import 'match_card_cache.dart';
import 'models.dart';
import 'otp_api.dart';

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
          RegExp(
            r'<(script|style)\b[^>]*>[\s\S]*?</\1>',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  ClubContent? _cached;
  Future<ClubContent>? _pending;

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
    return _pending ??= _fetch();
  }

  Future<ClubContent> _fetch() async {
    try {
      final futures = await Future.wait([
        _client
            .get(Uri.parse('$apiBase/api/public/squad-members'))
            .timeout(const Duration(seconds: 4))
            .catchError((_) => http.Response('[]', 500)),
        _client
            .get(Uri.parse('$apiBase/api/public/knockout-matches'))
            .timeout(const Duration(seconds: 4))
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

      List<Player> players = fallbackPlayers;
      if (futures[0].statusCode == 200) {
        try {
          final parsed = (jsonDecode(futures[0].body) as List)
              .map(
                (row) => Player(
                  name: '${row['display_name'] ?? ''}',
                  jersey: (row['jersey'] as num?)?.toInt() ?? 0,
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
          if (parsed.isNotEmpty) {
            players = parsed;
          }
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
                      ? (row['preview_photos'] as List).whereType<Map>().map((photo) {
                          final url = mediaUrl(photo['url']);
                          return url.isEmpty
                              ? null
                              : MatchPhoto(url: url, caption: '${photo['caption'] ?? ''}');
                        }).whereType<MatchPhoto>().toList()
                      : [],
                  previewVideos: _links(row['preview_videos'], allowUploads: true),
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
        fixtures: fixtures,
        fixturesUnavailable: fixturesUnavailable,
        stories: stories,
        defaultMatchThumbnail: defaultThumbnail,
      );
      if (!fixturesUnavailable) _cached = content;
      return content;
    } catch (_) {
      return ClubContent(
        players: _cached?.players ?? fallbackPlayers,
        fixtures: const [],
        stories: _cached?.stories ?? clubFallback.stories,
        fixturesUnavailable: true,
      );
    } finally {
      _pending = null;
    }
  }
}

const fallbackPlayers = [
  Player(
    name: 'Redeem Tlang',
    jersey: 10,
    position: 'Midfielder',
    image: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/0cd35e30e_image.png',
    frontImage: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/0cd35e30e_image.png',
    quote: 'Shillong raised me. This badge repays it.',
    nationality: 'India',
  ),
  Player(
    name: 'Parthib Gogoi',
    jersey: 14,
    position: 'Forward',
    image: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/c74912fe7_image.png',
    frontImage: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/c74912fe7_image.png',
    quote: 'I played on these streets. Now I play for them.',
    nationality: 'India',
  ),
  Player(
    name: 'Alaeddine Ajaraie',
    jersey: 9,
    position: 'Forward',
    image: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/71e6ac447_image.png',
    frontImage: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/71e6ac447_image.png',
    quote: 'Give me half a chance. I only need half.',
    nationality: 'Morocco',
  ),
  Player(
    name: 'Michel Zabaco',
    jersey: 5,
    position: 'Defender',
    image: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/9cbcbcbb6_image.png',
    frontImage: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/9cbcbcbb6_image.png',
    quote: 'Defence is a language. I speak it fluently.',
    nationality: 'Spain',
  ),
  Player(
    name: 'Louis Nickson',
    jersey: 6,
    position: 'Midfielder',
    image: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/f723b4e88_image.png',
    frontImage: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/f723b4e88_image.png',
    quote: 'I break up the play so the artists can paint.',
    nationality: 'India',
  ),
  Player(
    name: 'Ankith Padmanabhan',
    jersey: 11,
    position: 'Forward',
    image: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/358482816_image.png',
    frontImage: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/358482816_image.png',
    quote: 'Speed is my language - I speak it in the final third.',
    nationality: 'India',
  ),
  Player(
    name: 'Tondonba Singh',
    jersey: 2,
    position: 'Defender',
    image: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/6c3c58e9d_image.png',
    frontImage: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/6c3c58e9d_image.png',
    quote: 'From Imphal to the fortress - I guard the left flank.',
    nationality: 'India',
  ),
];

const clubFallback = ClubContent(
  players: fallbackPlayers,
  fixtures: [],
  stories: [
    Story(
      title:
          'NorthEast United FC Reach Fourth Consecutive Durand Cup Semi-Final',
      category: 'Match Report',
    ),
  ],
);
