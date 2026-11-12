import '../brand_colors.dart';
import '../widgets/club_page_body.dart';

import 'package:flutter/material.dart';

import 'dart:io';

import '../widgets/club_header.dart';
import '../widgets/ground_icons.dart';
import '../widgets/app_bottom_navigation.dart';

import 'package:webview_flutter/webview_flutter.dart';

import '../grounds_repository.dart';
import '../grounds_map_html.dart';
import '../theme.dart';
import 'photo_viewer_screen.dart';

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
      cached?.subtitle ?? '',
    ));
    _persistentHeader = PreferredSize(
      preferredSize: const ClubHeader(title: '').preferredSize,
      child: ValueListenableBuilder<(String, String)>(
        valueListenable: _headerText,
        builder: (_, text, _) => ClubHeader(
          title: text.$1,
          subtitle: text.$2,
          showBack: false,
          showSearch: false,
          showSupport: false,
        ),
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
  int _selectedTab = 0;
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

  void _openPhotos(List<String> urls, int index) {
    final photos = urls.where((url) => url.isNotEmpty).toList();
    if (photos.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewerScreen(
          images: photos,
          initialIndex: index.clamp(0, photos.length - 1),
          authorName: ground.name,
        ),
      ),
    );
  }

  static const _red = brandAccent;
  static const _ink = Color(0xFF1B1E2D);
  static const _muted = Color(0xFF565656);
  static const _background = Color(0xFFF7F7FB);

  Widget _photo(String url) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: url.isEmpty
        ? _photoPlaceholder()
        : Image.network(
            url,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _photoPlaceholder(),
          ),
  );

  Widget _photoPlaceholder() => Container(
    color: const Color(0xFFE9EAED),
    alignment: Alignment.center,
    child: const Icon(Icons.stadium_outlined, size: 42, color: authMuted),
  );

  Widget _identity() => _GroundSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ground.name,
          style: const TextStyle(
            fontSize: 18,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        if (ground.type.isNotEmpty) ...[
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFBDDE4),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stadium_outlined, color: _red, size: 15),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    ground.type,
                    style: const TextStyle(
                      color: _red,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (ground.location.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const GroundLocationIcon(),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ground.location,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _tabs() {
    const labels = ['Overview', 'Facilities', 'Photos'];
    const icons = [
      Icons.info_outline,
      Icons.stadium_outlined,
      Icons.photo_library_outlined,
    ];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              selected: _selectedTab == index,
              child: Material(
                color: _selectedTab == index ? _red : Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: 5,
                shadowColor: const Color(0x180F162D),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selectedTab = index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 24,
                          child: Icon(
                            icons[index],
                            size: 23,
                            color: _selectedTab == index ? Colors.white : _ink,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            labels[index],
                            maxLines: 2,
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: _selectedTab == index
                                  ? Colors.white
                                  : _ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _overview() {
    final description = ground.description.trim();
    final canExpand = description.length > 155;
    final rows = <(IconData, String, String)>[
      (
        Icons.account_balance_outlined,
        'Venue type',
        ground.name.toLowerCase().contains('stadium') ? 'Stadium' : 'Ground',
      ),
      if (ground.city.isNotEmpty)
        (Icons.location_on_outlined, 'City', ground.city),
      if (ground.state.isNotEmpty)
        (Icons.sports_soccer_outlined, 'State', ground.state),
      if (ground.pitch.isNotEmpty)
        (Icons.grass_outlined, 'Pitch', ground.pitch),
      if (ground.capacity.isNotEmpty)
        (Icons.people_outline, 'Capacity', ground.capacity),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About the ground',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF191919),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 54,
          height: 4,
          decoration: BoxDecoration(
            color: _red,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          description.isEmpty
              ? 'Ground information will be available soon.'
              : description,
          maxLines: canExpand && !_expanded ? 3 : null,
          overflow: canExpand && !_expanded ? TextOverflow.ellipsis : null,
          style: const TextStyle(fontSize: 14, height: 1.45, color: _muted),
        ),
        if (canExpand)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              foregroundColor: _red,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            iconAlignment: IconAlignment.end,
            icon: Icon(
              _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20,
            ),
            label: Text(
              _expanded ? 'Read less' : 'Read more',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        const SizedBox(height: 22),
        _GroundSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ground information',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < rows.length; index++)
                _GroundInfoRow(
                  icon: rows[index].$1,
                  label: rows[index].$2,
                  value: rows[index].$3,
                  divider: index < rows.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _facilities() => ground.displayFacilities.isEmpty
      ? const Padding(
          padding: EdgeInsets.all(30),
          child: Center(child: Text('No facilities added yet.')),
        )
      : Column(
          children: [
            for (final item in ground.displayFacilities)
              Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFECEBF2)),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Row(
                  children: [
                    _GroundIcon(
                      child: GroundFacilityIcon(
                        name: item.name,
                        icon: item.icon,
                        iconUrl: item.iconUrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Available',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
          ],
        );

  Widget _photos() => photoItems.isEmpty
      ? const Padding(
          padding: EdgeInsets.all(30),
          child: Center(child: Text('No photos added yet.')),
        )
      : LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var index = 0; index < photoItems.length; index++)
                  SizedBox(
                    width: photoItems[index].fullWidth
                        ? constraints.maxWidth
                        : (constraints.maxWidth - gap) / 2,
                    height: photoItems[index].fullWidth ? 190 : 135,
                    child: GestureDetector(
                      onTap: () => _openPhotos([
                        for (final item in photoItems) item.url,
                      ], index),
                      child: _photo(photoItems[index].url),
                    ),
                  ),
              ],
            );
          },
        );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: const ClubHeader(
      title: 'GROUNDS',
      showBack: false,
      showSearch: false,
      showSupport: false,
      titleFontSize: 18,
      backButtonWidth: 48,
    ),
    body: SingleChildScrollView(
      key: const PageStorageKey('ground-detail-scroll'),
      padding: EdgeInsets.fromLTRB(
        17,
        16,
        17,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2.46,
            child: images.isEmpty
                ? _photo('')
                : PageView.builder(
                    controller: _galleryController,
                    itemCount: images.length,
                    onPageChanged: (index) =>
                        setState(() => _photoIndex = index),
                    itemBuilder: (_, index) => GestureDetector(
                      onTap: () => _openPhotos(images, index),
                      child: _photo(images[index]),
                    ),
                  ),
          ),
          if (images.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < images.length; index++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _photoIndex
                            ? _red
                            : const Color(0xFFD5D7DC),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          _identity(),
          const SizedBox(height: 20),
          _tabs(),
          const SizedBox(height: 22),
          switch (_selectedTab) {
            1 => _facilities(),
            2 => _photos(),
            _ => _overview(),
          },
        ],
      ),
    ),
  );
}

class _GroundSurface extends StatelessWidget {
  const _GroundSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x100F162D),
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: CustomPaint(
        painter: const _GroundWaves(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: child,
        ),
      ),
    ),
  );
}

class _GroundWaves extends CustomPainter {
  const _GroundWaves();

  @override
  void paint(Canvas canvas, Size size) {
    for (final (start, rise, color) in [
      (.56, 83.0, const Color(0xFFFDF0F3)),
      (.68, 61.0, const Color(0xFFFCE2E9)),
      (.8, 39.0, const Color(0xFFF7CDD9)),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width * start, size.height)
          ..quadraticBezierTo(
            size.width * .94,
            size.height - 5,
            size.width,
            size.height - rise,
          )
          ..lineTo(size.width, size.height)
          ..close(),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_GroundWaves oldDelegate) => false;
}

class _GroundIcon extends StatelessWidget {
  const _GroundIcon({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: const Color(0xFFFCE6EA),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Center(child: child),
  );
}

class _GroundInfoRow extends StatelessWidget {
  const _GroundInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.divider = true,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool divider;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _GroundIcon(
        child: icon == Icons.location_on_outlined
            ? const GroundLocationIcon()
            : Icon(icon, size: 21, color: const Color(0xFF1B1E2D)),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: divider
                ? const Border(bottom: BorderSide(color: Color(0xFFECEBF2)))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF565656),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B1E2D),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
