import 'dart:async';

import 'package:flutter/material.dart';

import '../realtime_client.dart';
import '../app_banners_repository.dart';
import '../app_navigation.dart';
import '../otp_api.dart';
import '../theme.dart';

class AppFeedBanners extends StatefulWidget {
  const AppFeedBanners({
    super.key,
    this.repository,
    this.padding = EdgeInsets.zero,
  });
  final AppBannersRepository? repository;
  final EdgeInsetsGeometry padding;
  @override
  State<AppFeedBanners> createState() => _AppFeedBannersState();
}

class _AppFeedBannersState extends State<AppFeedBanners>
    with WidgetsBindingObserver {
  AppBannersRepository get _repository =>
      widget.repository ?? AppBannersRepository.instance;
  final _controller = PageController();
  late List<AppBanner> _banners;
  StreamSubscription<Map<String, dynamic>>? _settingsSubscription;
  bool _reloadAgain = false;
  void _listenForUpdates() {
    _settingsSubscription = RealtimeClient.instance.settingsChanges.listen((
      event,
    ) {
      if (event['resource'] == 'feed-refresh') {
        RealtimeClient.instance.trackFeedRefresh(_reload());
      } else if (event['resource'] == 'all' || event['resource'] == 'banners') {
        _reload();
      }
    });
  }

  bool _loading = false;
  bool _retriedEmpty = false;
  bool _refreshImagesAgain = false;
  int _imageEpoch = 0;
  int _page = 0;
  static const _bannerAspect = 1746 / 901;

  String _imageUrl(AppBanner banner) =>
      Uri.parse(OtpApi.apiBase).resolve(banner.imageUrl).toString();

  Widget _bannerPicture(AppBanner banner, int index) {
    final bytes = _repository.bytesFor(banner);
    if (bytes != null) {
      return Image.memory(
        bytes,
        key: ValueKey('app-banner-memory-$index-$_imageEpoch'),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      );
    }
    if (!_repository.imagesReady) {
      return const ColoredBox(color: Color(0xFFF4F1EC));
    }
    return Image.network(
      _imageUrl(banner),
      key: ValueKey('app-banner-image-$index-$_imageEpoch'),
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF342322)),
    );
  }

  @override
  void initState() {
    super.initState();
    _listenForUpdates();
    _repository.addListener(_bannerChanged);
    _banners = _repository.current.where((banner) => banner.enabled).toList();
    WidgetsBinding.instance.addObserver(this);
    if (_banners.isEmpty) {
      unawaited(_repository.ensureLoaded());
    } else if (!_repository.imagesReady) {
      unawaited(
        _repository.prepareImages(context).then((_) {
          if (mounted) setState(() {});
        }),
      );
    }
  }

  void _bannerChanged() {
    if (!mounted) return;
    setState(() {
      _banners = _repository.current.where((banner) => banner.enabled).toList();
      if (_page >= _banners.length) {
        _page = 0;
        if (_controller.hasClients) _controller.jumpToPage(0);
      }
    });
  }

  @override
  void dispose() {
    _repository.removeListener(_bannerChanged);
    _settingsSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload({bool refreshImages = false}) async {
    if (_loading) {
      _reloadAgain = true;
      _refreshImagesAgain = _refreshImagesAgain || refreshImages;
      return;
    }
    _loading = true;
    final banners = refreshImages
        ? await _repository.refresh()
        : await _repository.load();
    _loading = false;
    if (!mounted) return;
    if (!refreshImages &&
        banners.every((banner) => !banner.enabled) &&
        !_retriedEmpty) {
      _retriedEmpty = true;
      return _reload();
    }
    if (_controller.hasClients) _controller.jumpToPage(0);
    setState(() {
      _banners = banners.where((banner) => banner.enabled).toList();
      if (refreshImages) _imageEpoch++;
      _page = 0;
    });
    if (_reloadAgain && mounted) {
      _reloadAgain = false;
      final refreshAgain = _refreshImagesAgain;
      _refreshImagesAgain = false;
      await _reload(refreshImages: refreshAgain);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: widget.padding,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: _bannerAspect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: PageView.builder(
                key: const ValueKey('app-banner-slider'),
                controller: _controller,
                itemCount: _banners.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) {
                  final banner = _banners[index];
                  return Material(
                    color: const Color(0xFFF4F1EC),
                    child: InkWell(
                      key: ValueKey('app-banner-$index'),
                      onTap: banner.link.isEmpty
                          ? null
                          : () => openAppDestination(context, banner.link),
                      child: _bannerPicture(banner, index),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_banners.length > 1) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < _banners.length; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _page ? 8 : 6,
                    height: index == _page ? 8 : 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _page ? authRed : const Color(0xFFDADADA),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
