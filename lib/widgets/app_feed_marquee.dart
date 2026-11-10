import 'dart:async';

import 'package:flutter/material.dart';

import '../media_cache.dart';
import '../realtime_client.dart';
import '../app_marquee_repository.dart';
import '../app_navigation.dart';
import '../theme.dart';
import '../otp_api.dart';

// The Feed announcement uses the independent admin marquee configuration.
class AppFeedMarquee extends StatefulWidget {
  const AppFeedMarquee({super.key, this.repository});
  final AppMarqueeRepository? repository;
  @override
  State<AppFeedMarquee> createState() => _AppFeedMarqueeState();
}

class _AppFeedMarqueeState extends State<AppFeedMarquee>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _icons = {
    'notifications': Icons.notifications_active_outlined,
    'megaphone': Icons.campaign_outlined,
    'ticket': Icons.confirmation_number_outlined,
    'calendar': Icons.calendar_month_outlined,
    'trophy': Icons.emoji_events_outlined,
    'football': Icons.sports_soccer,
    'star': Icons.star_outline,
    'info': Icons.info_outline,
  };
  Widget _announcementIcon() {
    final fallback = Icon(
      _icons[_marquee.icon] ?? Icons.notifications_active_outlined,
      color: authRed,
      size: 18,
    );
    if (_marquee.iconUrl.isEmpty) return fallback;
    final iconUrl = Uri.parse(OtpApi.apiBase).resolve(_marquee.iconUrl).toString();
    return Image.network(
      iconUrl,
      key: ValueKey('$iconUrl-${MediaCache.instance.generation.value}'),
      width: 20,
      height: 20,
      fit: BoxFit.contain,
      errorBuilder: (_, error, stack) => fallback,
    );
  }

  AppMarqueeRepository get _repository =>
      widget.repository ?? AppMarqueeRepository.instance;
  late AppMarquee _marquee;
  StreamSubscription<Map<String, dynamic>>? _settingsSubscription;
  bool _reloadAgain = false;
  void _listenForUpdates() {
    _settingsSubscription = RealtimeClient.instance.settingsChanges.listen((
      event,
    ) {
      if (event['resource'] == 'feed-refresh') {
        RealtimeClient.instance.trackFeedRefresh(_reload());
      } else if (event['resource'] == 'all' || event['resource'] == 'marquee') {
        _reload();
      }
    });
  }

  late AnimationController _animation;
  bool _loading = false, _moving = false;
  double _distance = 0;
  String? _dismissedAnnouncement;
  String _announcementKey(AppMarquee value) =>
      '${value.id}\n${value.text}\n${value.link}\n${value.icon}\n${value.iconUrl}';
  void _dismiss() {
    _animation.stop();
    setState(() => _dismissedAnnouncement = _announcementKey(_marquee));
  }

  @override
  void initState() {
    super.initState();
    _listenForUpdates();
    _marquee = _repository.current;
    _animation = AnimationController(vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    if (_loading) {
      _reloadAgain = true;
      return;
    }
    _loading = true;
    final marquee = await _repository.load();
    _loading = false;
    if (!mounted) return;
    _animation.stop();
    _moving = false;
    _distance = 0;
    setState(() {
      _marquee = marquee;
      if (_announcementKey(_marquee) != _dismissedAnnouncement)
        _dismissedAnnouncement = null;
    });
    if (_reloadAgain && mounted) {
      _reloadAgain = false;
      await _reload();
    }
  }

  void _configureMotion(bool moving, double distance) {
    if (_moving == moving && _distance == distance) return;
    _moving = moving;
    _distance = distance;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _moving != moving || _distance != distance) return;
      if (moving) {
        _animation.duration = Duration(
          milliseconds: (distance / 35 * 1000).round(),
        );
        _animation.value = 0;
        _animation.repeat();
      } else {
        _animation.stop();
        _animation.value = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_marquee.enabled ||
        _marquee.text.trim().isEmpty ||
        _dismissedAnnouncement == _announcementKey(_marquee)) {
      _configureMotion(false, 0);
      return const SizedBox.shrink();
    }
    final style = DefaultTextStyle.of(context).style.merge(
      const TextStyle(
        fontFamily: clubFontFamily,
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF171717),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        key: const ValueKey('app-marquee'),
        color: const Color(0xFFFBF0F0),
        elevation: 1,
        shadowColor: const Color(0x16000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.white),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _marquee.link.isEmpty
              ? null
              : () => openAppDestination(context, _marquee.link),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Row(
              children: [
                _announcementIcon(),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final painter = TextPainter(
                        text: TextSpan(text: _marquee.text, style: style),
                        textDirection: Directionality.of(context),
                        textScaler: MediaQuery.textScalerOf(context),
                      )..layout();
                      final width = painter.width, height = painter.height;
                      painter.dispose();
                      final moving =
                          width > constraints.maxWidth &&
                          !MediaQuery.disableAnimationsOf(context);
                      _configureMotion(moving, width + 48);
                      if (!moving)
                        return Text(
                          _marquee.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        );
                      return Semantics(
                        label: _marquee.text,
                        child: ExcludeSemantics(
                          child: SizedBox(
                            height: height,
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.centerLeft,
                                minWidth: width * 2 + 48,
                                maxWidth: width * 2 + 48,
                                child: AnimatedBuilder(
                                  animation: _animation,
                                  builder: (context, child) =>
                                      Transform.translate(
                                        offset: Offset(
                                          -_animation.value * (width + 48),
                                          0,
                                        ),
                                        child: child,
                                      ),
                                  child: Row(
                                    children: [
                                      Text(_marquee.text, style: style),
                                      const SizedBox(width: 48),
                                      Text(_marquee.text, style: style),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  key: const ValueKey('dismiss-marquee'),
                  tooltip: 'Hide announcement',
                  onPressed: _dismiss,
                  icon: const Icon(Icons.close, color: authRed, size: 18),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
