import 'package:Highlanders/shared/widgets/club_page_body.dart';
import 'package:Highlanders/shared/widgets/club_header.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:Highlanders/app/app_navigation.dart';
import 'package:Highlanders/shared/data/club_repository.dart';
import 'package:Highlanders/features/explore/data/explore_repository.dart';
import 'package:Highlanders/features/auth/data/otp_api.dart';
import 'package:Highlanders/features/swoofi/widgets/swoofi_pet_invite.dart';
import 'package:Highlanders/features/swoofi/widgets/swoofi_html_page.dart';
import 'package:Highlanders/features/swoofi/data/swoofi_store_links.dart';

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
  String contentType = 'cards';
  String htmlUrl = '';
  String playStoreUrl = SwoofiStoreLinks.playStore;
  String appStoreUrl = SwoofiStoreLinks.appStore;
  bool get showsHtml => contentType == 'html' && htmlUrl.isNotEmpty;
  Future<List<SwoofiCard>>? _pending;

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
      _readPageSettings(data);
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
          'content_type': contentType,
          'html_url': htmlUrl,
          'play_store_url': playStoreUrl,
          'app_store_url': appStoreUrl,
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

  void _readPageSettings(Map data) {
    playStoreUrl = SwoofiStoreLinks.resolve(
      data['play_store_url'],
      SwoofiStoreLinks.playStore,
    );
    appStoreUrl = SwoofiStoreLinks.resolve(
      data['app_store_url'],
      SwoofiStoreLinks.appStore,
    );
    contentType = data['content_type'] == 'html' ? 'html' : 'cards';
    htmlUrl = data['html_url'] is String
        ? (data['html_url'] as String).trim()
        : '';
  }

  Future<List<SwoofiCard>> load({bool force = false}) {
    if (loaded && !force) return Future.value(cards);
    final pending = _pending;
    if (!force && pending != null) return pending;
    final request = _fetch();
    _pending = request;
    return request.whenComplete(() {
      if (identical(_pending, request)) _pending = null;
    });
  }

  Future<List<SwoofiCard>> _fetch() async {
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
    _readPageSettings(body['swoofi'] as Map);
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
  final _inviteTrigger = ValueNotifier(false);
  bool _inviteScheduled = false;

  void _scheduleInvite() {
    if (_loading ||
        _cards.isEmpty ||
        _repository.showsHtml ||
        _inviteTrigger.value ||
        _inviteScheduled) {
      return;
    }
    _inviteScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inviteScheduled = false;
      if (mounted && !_repository.showsHtml) _inviteTrigger.value = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _cards = _repository.cards;
    _loading = !_repository.loaded;
    _repository.addListener(_applyCards);
    if (!_repository.loaded) _loadCards();
    _scheduleInvite();
  }

  void _applyCards() {
    if (!mounted) return;
    setState(() {
      _cards = _repository.cards;
      _loading = false;
    });
    _scheduleInvite();
  }

  Future<void> _loadCards() async {
    try {
      final cards = await _repository.load();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });
      _scheduleInvite();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_applyCards);
    _inviteTrigger.dispose();
    super.dispose();
  }

  Future<void> _openCard(SwoofiCard card) async {
    final link = card.link.trim();
    if (link.isEmpty || link == '/swoofi' || !mounted) return;
    await openAppDestination(context, link);
  }

  bool _onScroll(ScrollUpdateNotification notification) {
    if (_repository.showsHtml ||
        _inviteTrigger.value ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final metrics = notification.metrics;
    final contentHeight = metrics.maxScrollExtent + metrics.viewportDimension;
    final threshold = (contentHeight * .74 - metrics.viewportDimension * .72)
        .clamp(40.0, double.infinity);
    if (metrics.pixels >= threshold) _inviteTrigger.value = true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final page = Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Gilroy'),
      ),
      child: ClubScaffold(
        backgroundColor: const Color(0xFFF7F4EF),
        appBar: const ClubHeader(
          title: 'Animal Welfare',
          showBack: true,
          showSearch: false,
          showSupport: false,
          uppercaseTitle: false,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _repository.showsHtml
            ? SwoofiHtmlPage(
                key: ValueKey((
                  _repository.htmlUrl,
                  _repository.playStoreUrl,
                  _repository.appStoreUrl,
                )),
                url: ClubRepository.mediaUrl(_repository.htmlUrl),
                onOpenLink: (link) => openAppDestination(context, link),
                playStoreUrl: _repository.playStoreUrl,
                appStoreUrl: _repository.appStoreUrl,
              )
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
            : NotificationListener<ScrollUpdateNotification>(
                onNotification: _onScroll,
                child: SingleChildScrollView(
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
      ),
    );
    if (_repository.showsHtml) return page;
    return SwoofiPetInvite(
      trigger: _inviteTrigger,
      onOpenStore: (link) => openAppDestination(context, link),
      playStoreUrl: _repository.playStoreUrl,
      appStoreUrl: _repository.appStoreUrl,
      child: page,
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
      errorBuilder: (_, _, _) => const SizedBox(
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
