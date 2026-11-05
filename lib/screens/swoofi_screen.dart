import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../app_navigation.dart';
import '../club_repository.dart';
import '../explore_repository.dart';
import '../otp_api.dart';

class SwoofiCard {
  const SwoofiCard({required this.imageUrl, required this.link});
  final String imageUrl;
  final String link;
}

class SwoofiRepository extends ChangeNotifier {
  SwoofiRepository({http.Client? client}) : _client = client ?? http.Client();
  static final SwoofiRepository instance = SwoofiRepository();
  final http.Client _client;
  List<SwoofiCard> cards = const [];
  bool loaded = false;

  Future<File> _cacheFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}swoofi-cache.json');
  }

  Future<void> restore() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map || data['cards'] is! List) return;
      cards = _cardsFrom(data['cards'] as List);
      loaded = true;
      for (final card in cards) {
        warmNetworkImage(card.imageUrl);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(
        jsonEncode({
          'cards': [
            for (final card in cards)
              {'image_url': card.imageUrl, 'link': card.link},
          ],
        }),
      );
    } catch (_) {}
  }

  List<SwoofiCard> _cardsFrom(List rows) => [
    for (final item in rows)
      if (item is Map &&
          item['image_url'] is String &&
          (item['image_url'] as String).isNotEmpty)
        SwoofiCard(
          imageUrl: item['image_url'] as String,
          link: item['link'] is String ? item['link'] as String : '',
        ),
  ];

  Future<List<SwoofiCard>> load({bool force = false}) async {
    if (loaded && !force) return cards;
    final response = await _client
        .get(Uri.parse('${OtpApi.apiBase}/api/public/swoofi'))
        .timeout(const Duration(seconds: 8));
    final body = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        body is! Map ||
        body['success'] != true ||
        body['swoofi'] is! Map ||
        (body['swoofi'] as Map)['cards'] is! List) {
      throw const FormatException();
    }
    cards = _cardsFrom((body['swoofi'] as Map)['cards'] as List);
    loaded = true;
    unawaited(_persist());
    for (final card in cards) {
      warmNetworkImage(card.imageUrl);
    }
    notifyListeners();
    return cards;
  }

  void close() => _client.close();
}

class SwoofiScreen extends StatefulWidget {
  const SwoofiScreen({super.key, this.repository});
  final SwoofiRepository? repository;
  @override
  State<SwoofiScreen> createState() => _SwoofiScreenState();
}

class _SwoofiScreenState extends State<SwoofiScreen> {
  late final SwoofiRepository _repository =
      widget.repository ?? SwoofiRepository.instance;
  List<SwoofiCard> _cards = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cards = _repository.cards;
    _loading = !_repository.loaded;
    _repository.addListener(_applyCards);
    if (!_repository.loaded) _loadCards();
  }

  void _applyCards() {
    if (!mounted) return;
    setState(() {
      _cards = _repository.cards;
      _loading = false;
    });
  }

  Future<void> _loadCards() async {
    try {
      final cards = await _repository.load();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_applyCards);
    super.dispose();
  }

  Future<void> _openCard(SwoofiCard card) async {
    final link = card.link.trim();
    if (link.isEmpty || link == '/swoofi' || !mounted) return;
    await openAppDestination(context, link);
  }

  @override
  Widget build(BuildContext context) {
    final scale = math.min(MediaQuery.sizeOf(context).width, 600) / 471;
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Gilroy'),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4EF),
        appBar: AppBar(
          backgroundColor: const Color(0xFFAD0C0E),
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 70 * scale,
          centerTitle: true,
          automaticallyImplyLeading: false,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          flexibleSpace: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -.15),
                radius: .85,
                colors: [Color(0xFFD10F11), Color(0xFFAA0C0E)],
              ),
            ),
          ),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Swoofi',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: math.max(20.0, 24 * scale),
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 3 * scale),
              Text(
                'ABOUT THE APP',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: math.max(12.5, 14 * scale),
                  fontWeight: FontWeight.w500,
                  letterSpacing: math.max(2.5, 3.0 * scale),
                  height: 1.4,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _cards.isEmpty
            ? const Center(
                child: Text(
                  'No cards yet',
                  key: ValueKey('swoofi-empty'),
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B7F87),
                  ),
                ),
              )
            : SingleChildScrollView(
                key: const PageStorageKey('swoofi-scroll'),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < _cards.length; index++)
                      _UploadedCard(
                        card: _cards[index],
                        index: index,
                        onOpen: () => _openCard(_cards[index]),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _UploadedCard extends StatelessWidget {
  const _UploadedCard({
    required this.card,
    required this.index,
    required this.onOpen,
  });
  final SwoofiCard card;
  final int index;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      ClubRepository.mediaUrl(card.imageUrl),
      key: ValueKey('swoofi-card-$index'),
      width: double.infinity,
      fit: BoxFit.fitWidth,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (_, __, ___) => const SizedBox(
        height: 160,
        child: ColoredBox(
          color: Color(0xFFF4F1EC),
          child: Center(child: Text('Image unavailable')),
        ),
      ),
    );
    if (card.link.trim().isEmpty) return image;
    return InkWell(onTap: onOpen, child: image);
  }
}
