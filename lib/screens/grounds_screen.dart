import '../widgets/club_page_body.dart';

import 'package:flutter/material.dart';

import 'dart:io';

import '../widgets/club_header.dart';
import '../widgets/app_bottom_navigation.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../grounds_repository.dart';
import '../grounds_map_html.dart';
import '../theme.dart';

class GroundsScreen extends StatefulWidget {
  const GroundsScreen({super.key, this.active = true});

  final bool active;

  static Route<void> route() => PageRouteBuilder<void>(
    pageBuilder: (_, _, _) => const GroundsScreen(),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );

  @override
  State<GroundsScreen> createState() => _GroundsScreenState();
}

class _GroundsScreenState extends State<GroundsScreen> {
  late Future<GroundsContent> _content;
  late final ValueNotifier<(String, String)> _headerText;
  late final PreferredSizeWidget _persistentHeader;
  int _contentVersion = 0;

  @override
  void initState() {
    super.initState();
    final cached = GroundsRepository.instance.cachedContent;
    _headerText = ValueNotifier((
      cached?.title ?? 'GROUNDS',
      cached?.subtitle ?? 'The Home Of The Highlanders',
    ));
    _persistentHeader = PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: ValueListenableBuilder<(String, String)>(
        valueListenable: _headerText,
        builder: (_, text, _) =>
            ClubHeader(title: text.$1, subtitle: text.$2, showBack: true),
      ),
    );
    _content = _loadContent();
  }

  Future<GroundsContent> _loadContent({bool force = false}) async {
    final version = ++_contentVersion;
    final content = await (force
        ? GroundsRepository.instance.load()
        : GroundsRepository.instance.loadForDisplay());
    final headerText = (content.title, content.subtitle);
    if (mounted &&
        version == _contentVersion &&
        _headerText.value != headerText) {
      _headerText.value = headerText;
    }
    return content;
  }

  @override
  void didUpdateWidget(GroundsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      final cached = GroundsRepository.instance.cachedContent;
      if (cached != null) {
        _headerText.value = (cached.title, cached.subtitle);
        _content = Future.value(cached);
      }
    }
  }

  @override
  void dispose() {
    _headerText.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = _loadContent(force: true);
    setState(() {
      _content = next;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder shows the retry state while retaining any cached content.
    }
  }

  Widget _image(
    String url, {
    required double height,
    BorderRadius? radius,
    String localPath = '',
  }) => ClipRRect(
    borderRadius: radius ?? BorderRadius.zero,
    child: url.isEmpty
        ? Container(
            height: height,
            color: const Color(0xFFE9EAED),
            alignment: Alignment.center,
            child: const Icon(
              Icons.stadium_outlined,
              color: authMuted,
              size: 38,
            ),
          )
        : Image(
            image: localPath.isNotEmpty
                ? FileImage(File(localPath))
                : NetworkImage(url) as ImageProvider,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              height: height,
              color: const Color(0xFFE9EAED),
              alignment: Alignment.center,
              child: const Icon(
                Icons.stadium_outlined,
                color: authMuted,
                size: 38,
              ),
            ),
          ),
  );

  Widget _card(GroundRecord ground, int index) => Container(
    key: ValueKey('ground-card-${ground.id}'),
    margin: const EdgeInsets.only(bottom: 13),
    padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFDADDE2)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroundDetailScreen(ground: ground)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 94,
            child: _image(
              ground.image,
              height: 94,
              radius: BorderRadius.circular(13),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFD62E24),
              shape: BoxShape.circle,
            ),
            child: Text(
              (index + 1).toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ground.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1C1D21),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                if (ground.location.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    ground.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: authMuted, fontSize: 12),
                  ),
                ],
                if (ground.type.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    ground.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: authMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF25262A)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ClubScaffold(
    backgroundColor: const Color(0xFFF4F4F5),
    appBar: _persistentHeader,
    bottomNavigationBar: const AppBottomNavigation(),
    body: FutureBuilder<GroundsContent>(
      future: _content,
      initialData: GroundsRepository.instance.cachedContent,
      builder: (context, snapshot) {
        final content =
            snapshot.data ?? GroundsRepository.instance.cachedContent;
        return content == null
            ? snapshot.hasError
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Could not load grounds.'),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      key: const ValueKey('grounds-loading'),
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (var index = 0; index < 3; index++)
                          Container(
                            height: 120,
                            margin: const EdgeInsets.only(bottom: 13),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: clubLine),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 94,
                                  height: 94,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE9EAED),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: LinearProgressIndicator(
                                    minHeight: 3,
                                    color: authMuted,
                                    backgroundColor: clubCloud,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
            : Column(
                children: [
                  if (snapshot.hasError)
                    MaterialBanner(
                      content: const Text(
                        'Could not refresh grounds. Showing the last loaded content.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        key: const PageStorageKey('grounds-list'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          MediaQuery.paddingOf(context).bottom + 24,
                        ),
                        children: [
                          if (content.mapHtml.isNotEmpty) ...[
                            _HtmlGroundBanner(
                              url: content.mapHtml,
                              html: content.mapHtmlContent,
                              height: content.mapHtmlHeight,
                            ),
                            const SizedBox(height: 15),
                          ] else if (content.mapImage.isNotEmpty) ...[
                            _image(
                              content.mapImage,
                              height: 210,
                              radius: BorderRadius.circular(18),
                              localPath: content.mapImagePath,
                            ),
                            const SizedBox(height: 15),
                          ],
                          if (content.grounds.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 70),
                              child: Center(
                                child: Text(
                                  'No grounds configured yet.',
                                  style: TextStyle(color: authMuted),
                                ),
                              ),
                            ),
                          for (
                            var index = 0;
                            index < content.grounds.length;
                            index++
                          )
                            _card(content.grounds[index], index),
                        ],
                      ),
                    ),
                  ),
                ],
              );
      },
    ),
  );
}

class _HtmlGroundBanner extends StatefulWidget {
  const _HtmlGroundBanner({
    required this.url,
    required this.height,
    this.html = '',
  });

  final String url;
  final String html;
  final double height;

  @override
  State<_HtmlGroundBanner> createState() => _HtmlGroundBannerState();
}

class _HtmlGroundBannerState extends State<_HtmlGroundBanner> {
  WebViewController? _controller;
  Animation<double>? _routeAnimation;
  bool _initializing = false;
  bool _ready = false;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || _initializing) return;
    _routeAnimation?.removeStatusListener(_routeStatusChanged);
    _routeAnimation = ModalRoute.of(context)?.animation;
    if (_routeAnimation == null ||
        _routeAnimation!.status == AnimationStatus.completed) {
      _initializeAfterTransition();
    } else {
      _routeAnimation!.addStatusListener(_routeStatusChanged);
    }
  }

  void _routeStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _routeAnimation?.removeStatusListener(_routeStatusChanged);
      _initializeAfterTransition();
    }
  }

  void _initializeAfterTransition() {
    if (_initializing) return;
    _initializing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final initial = Uri.parse(widget.url);
      final controller = WebViewController()
        ..setBackgroundColor(Colors.white)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'GroundsMapReady',
          onMessageReceived: (message) {
            if (mounted && message.message == '$_generation') {
              setState(() => _ready = true);
            }
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              controllerReady();
            },
            onNavigationRequest: (request) {
              final initial = Uri.parse(widget.url);
              final target = Uri.tryParse(request.url);
              if (!request.isMainFrame ||
                  target == null ||
                  target == initial ||
                  target.scheme == 'about' ||
                  target.scheme == 'data' ||
                  (target.hasAuthority && target.origin == initial.origin)) {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.prevent;
            },
          ),
        );
      if (widget.html.isNotEmpty) {
        controller.loadHtmlString(
          prepareGroundsMapHtml(widget.html),
          baseUrl: initial.toString(),
        );
      } else {
        controller.loadRequest(initial);
      }
      setState(() => _controller = controller);
    });
  }

  void controllerReady() {
    _controller?.runJavaScript(groundsMapReadyScript(_generation));
  }

  @override
  void didUpdateWidget(_HtmlGroundBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.html != widget.html) {
      _generation++;
      _ready = false;
      if (widget.html.isNotEmpty) {
        _controller?.loadHtmlString(
          prepareGroundsMapHtml(widget.html),
          baseUrl: widget.url,
        );
      } else {
        _controller?.loadRequest(Uri.parse(widget.url));
      }
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_routeStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      key: const ValueKey('grounds-html-banner'),
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          IgnorePointer(
            ignoring: _ready,
            child: AnimatedOpacity(
              opacity: _ready ? 0 : 1,
              duration: const Duration(milliseconds: 220),
              child: const ColoredBox(
                color: Colors.white,
                child: Center(
                  child: Icon(
                    Icons.stadium_outlined,
                    color: authMuted,
                    size: 38,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class GroundDetailScreen extends StatefulWidget {
  const GroundDetailScreen({super.key, required this.ground});

  final GroundRecord ground;

  @override
  State<GroundDetailScreen> createState() => _GroundDetailScreenState();
}

class _GroundDetailScreenState extends State<GroundDetailScreen> {
  final PageController _galleryController = PageController();
  int _photoIndex = 0;
  bool _expanded = false;

  GroundRecord get ground => widget.ground;

  List<String> get images => [
    if (ground.image.isNotEmpty) ground.image,
    ...ground.gallery.where((image) => image != ground.image),
  ];

  List<GroundGalleryItem> get photoItems {
    final items = [...ground.galleryLayout];
    if (items.isEmpty && ground.image.isNotEmpty) {
      items.add(
        GroundGalleryItem(url: ground.image, fullWidth: true, displayOrder: 0),
      );
    }
    return items;
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  Future<void> _openDirections() async {
    final query = [
      ground.name,
      ground.address,
      ground.location,
    ].where((value) => value.trim().isNotEmpty).join(', ');
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open directions.')),
      );
    }
  }

  Widget _header() => const ClubHeader(
    title: 'Grounds',
    subtitle: 'The Home Of The Highlanders',
    embedded: true,
    showBack: true,
  );

  Widget _photo(String url) => ClipRRect(
    borderRadius: BorderRadius.circular(17),
    child: url.isEmpty
        ? Container(
            color: const Color(0xFFE9EAED),
            alignment: Alignment.center,
            child: const Icon(
              Icons.stadium_outlined,
              size: 42,
              color: authMuted,
            ),
          )
        : Image.network(
            url,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: const Color(0xFFE9EAED),
              alignment: Alignment.center,
              child: const Icon(
                Icons.stadium_outlined,
                size: 42,
                color: authMuted,
              ),
            ),
          ),
  );

  Widget _overview() {
    final description = ground.description.trim();
    final canExpand = description.length > 155;
    final venueType = ground.name.toLowerCase().contains('stadium')
        ? 'Stadium'
        : 'Ground';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 28),
      children: [
        const Text(
          'About the ground',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          description.isEmpty
              ? 'Ground information will be available soon.'
              : description,
          maxLines: canExpand && !_expanded ? 3 : null,
          overflow: canExpand && !_expanded ? TextOverflow.ellipsis : null,
          style: const TextStyle(color: authMuted, height: 1.45, fontSize: 12),
        ),
        if (canExpand)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: authRed,
                padding: const EdgeInsets.symmetric(vertical: 3),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              iconAlignment: IconAlignment.end,
              icon: Icon(
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 17,
              ),
              label: Text(_expanded ? 'Read less' : 'Read more'),
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD9DCE1)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ground information',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              _GroundInfoRow(
                icon: Icons.account_balance_outlined,
                label: 'Venue type',
                value: venueType,
              ),
              if (ground.city.isNotEmpty)
                _GroundInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'City',
                  value: ground.city,
                ),
              if (ground.state.isNotEmpty)
                _GroundInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'State',
                  value: ground.state,
                ),
              if (ground.pitch.isNotEmpty)
                _GroundInfoRow(
                  icon: Icons.grass_outlined,
                  label: 'Pitch',
                  value: ground.pitch,
                ),
              if (ground.capacity.isNotEmpty)
                _GroundInfoRow(
                  icon: Icons.groups_outlined,
                  label: 'Capacity',
                  value: ground.capacity,
                ),
            ],
          ),
        ),
        const SizedBox(height: 17),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _openDirections,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62E24),
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: const Color(0x55D62E24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            icon: const Icon(Icons.near_me_outlined, size: 22),
            label: const Text(
              'Directions',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _photos() => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 10.0;
      final halfWidth = (constraints.maxWidth - 24 - gap) / 2;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in photoItems)
              SizedBox(
                width: item.fullWidth ? constraints.maxWidth - 24 : halfWidth,
                height: item.fullWidth ? 190 : 135,
                child: _photo(item.url),
              ),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      backgroundColor: const Color(0xFFF8F8F9),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          Expanded(
            child: ClubPageBody(
              color: const Color(0xFFF8F8F9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: SizedBox(
                      height: 140,
                      child: images.isEmpty
                          ? _photo('')
                          : PageView.builder(
                              controller: _galleryController,
                              itemCount: images.length,
                              onPageChanged: (index) =>
                                  setState(() => _photoIndex = index),
                              itemBuilder: (_, index) => _photo(images[index]),
                            ),
                    ),
                  ),
                  if (images.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          images.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index == _photoIndex
                                  ? authRed
                                  : const Color(0xFFD5D7DC),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ground.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (ground.type.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE8E6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              ground.type,
                              style: const TextStyle(
                                color: authRed,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (ground.location.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 17,
                                color: authMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                ground.location,
                                style: const TextStyle(
                                  color: authMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const TabBar(
                    labelColor: authRed,
                    unselectedLabelColor: authMuted,
                    indicatorColor: authRed,
                    tabs: [
                      Tab(text: 'Overview'),
                      Tab(text: 'Facilities'),
                      Tab(text: 'Photos'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _overview(),
                        ground.facilities.isEmpty
                            ? const Center(
                                child: Text('No facilities added yet.'),
                              )
                            : ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  for (final item in ground.facilities)
                                    ListTile(
                                      leading: const Icon(
                                        Icons.check_circle_outline,
                                        color: authRed,
                                      ),
                                      title: Text(item),
                                    ),
                                ],
                              ),
                        photoItems.isEmpty
                            ? const Center(child: Text('No photos added yet.'))
                            : _photos(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _GroundInfoRow extends StatelessWidget {
  const _GroundInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE2E3E6))),
    ),
    child: Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF313237)),
        const SizedBox(width: 11),
        SizedBox(
          width: 105,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}
