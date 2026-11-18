import 'dart:async';

import 'package:flutter/material.dart';
import 'package:Highlanders/core/network/realtime_client.dart';
import 'package:Highlanders/features/sponsors/data/sponsors_repository.dart';
import 'package:Highlanders/features/sponsors/widgets/sponsor_big_screen.dart';
import 'package:Highlanders/features/sponsors/widgets/sponsor_flight.dart';
import 'package:Highlanders/features/sponsors/widgets/sponsor_logo_strip.dart';
import 'package:Highlanders/features/sponsors/widgets/sponsor_scene.dart';

import 'package:Highlanders/features/sponsors/widgets/sponsor_style.dart';
import 'package:Highlanders/features/sponsors/widgets/sponsor_category_menu.dart';
import 'package:Highlanders/features/sponsors/widgets/sponsor_hero.dart';
import 'package:Highlanders/shared/widgets/club_header.dart';

class SponsorsScreen extends StatefulWidget {
  const SponsorsScreen({super.key, this.repository});
  static const routeName = '/sponsors';
  final SponsorsRepository? repository;

  @override
  State<SponsorsScreen> createState() => _SponsorsScreenState();
}

class _SponsorsScreenState extends State<SponsorsScreen>
    with WidgetsBindingObserver {
  SponsorsRepository get _repository =>
      widget.repository ?? SponsorsRepository.instance;
  List<Sponsor> _sponsors = const [];
  String? _selectedId;
  String? _departingId;
  String _tier = 'all';
  bool _loading = true;
  bool _failed = false;
  bool _ambient = true;
  bool _motionAllowed = false;
  bool _foreground = true;
  int _generation = 0;
  int _revealTick = 0;
  final _cardKey = GlobalKey();
  OverlayEntry? _flight;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  List<Sponsor> get _filtered => _tier == 'all'
      ? _sponsors
      : _sponsors.where((sponsor) => sponsor.tier == _tier).toList();

  bool get _motion => _motionAllowed && _foreground;
  bool get _ambientMotion => _ambient && _motion;

  // String get _railLabel {
  //   if (_tier == 'all') return 'ALL PARTNERS';
  //   final name = SponsorStyle.tierLabels[_tier] ?? _tier;
  //   return '${name.toUpperCase()} PARTNERS';
  // }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sponsors = _repository.cached;
    _selectedId =
        _sponsors
            .where((sponsor) => sponsor.role.toLowerCase().contains('pitch'))
            .firstOrNull
            ?.id ??
        _sponsors.firstOrNull?.id;
    _loading = false;
    _subscription = RealtimeClient.instance.settingsChanges.listen((event) {
      if (event['resource'] == 'all') unawaited(_load());
    });
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionAllowed =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
  }

  void _step(int direction) {
    final list = _filtered;
    if (!mounted || list.isEmpty) return;
    final index = list.indexWhere((sponsor) => sponsor.id == _selectedId);
    setState(() {
      _selectedId = list[(index + direction + list.length) % list.length].id;
      _revealTick++;
    });
  }

  void _pick(Sponsor sponsor) {
    setState(() => _selectedId = sponsor.id);
  }

  void _fly(Sponsor sponsor, Rect origin) {
    if (!_motion || !mounted) return;
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return;
    final to = box.localToGlobal(Offset.zero) & box.size;
    if (to.width < 40 || origin.width < 40) return;
    _clearFlight();
    setState(() => _departingId = sponsor.id);
    _flight = OverlayEntry(
      builder: (_) => SponsorFlight(
        from: origin,
        to: to,
        sponsor: sponsor,
        onDone: _finishFlight,
      ),
    );
    Overlay.of(context).insert(_flight!);
  }

  void _clearFlight() {
    final entry = _flight;
    _flight = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  void _finishFlight() {
    if (mounted && _departingId != null) setState(() => _departingId = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _clearFlight());
  }

  void _filter(String tier) {
    setState(() {
      _tier = tier;
      _selectedId = _filtered.firstOrNull?.id;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) setState(() {});
    if (_foreground) unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final sponsors = await _repository.load();
      if (!mounted || generation != _generation) return;
      setState(() {
        _sponsors = sponsors;
        if (_filtered.isEmpty) _tier = 'all';
        if (!_filtered.any((sponsor) => sponsor.id == _selectedId)) {
          _selectedId = _filtered.firstOrNull?.id;
        }
        _failed = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _clearFlight();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _filtered
        .where((sponsor) => sponsor.id == _selectedId)
        .firstOrNull;
    final filtered = _filtered;
    final spotlightIndex = selected == null
        ? 0
        : filtered.indexWhere((sponsor) => sponsor.id == selected.id);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF080E1B),
      appBar: const ClubHeader(
        title: 'Our Sponsors',
        showSearch: false,
        showSupport: false,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SponsorScene(animate: _ambientMotion),
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 70,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return RefreshIndicator(
                  onRefresh: _load,
                  color: SponsorStyle.red,
                  backgroundColor: SponsorStyle.panel,
                  child: ListView(
                    key: const PageStorageKey('sponsors-scroll'),
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      SizedBox(
                        height: constraints.maxHeight,
                        child: Column(
                          children: [
                            SponsorHero(animate: _ambientMotion),
                            if (_sponsors.isNotEmpty) ...[
                              _partnersHeader(),
                              // _railLabelRow(),
                              SponsorLogoStrip(
                                key: ValueKey('sponsor-rail-$_tier'),
                                sponsors: filtered,
                                selectedId: selected?.id ?? '',
                                departingId: _departingId,
                                animate: _ambientMotion,
                                revealTick: _revealTick,
                                onSelected: _pick,
                                onFly: _fly,
                              ),
                              if (selected != null)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      17,
                                      8,
                                      17,
                                      0,
                                    ),
                                    child: SponsorBigScreen(
                                      key: const ValueKey('sponsor-spotlight'),
                                      cardKey: _cardKey,
                                      sponsor: selected,
                                      index: spotlightIndex < 0
                                          ? 0
                                          : spotlightIndex,
                                      count: filtered.length,
                                      animate: _ambientMotion,
                                      concealContent: _departingId != null,
                                      onPrevious: () => _step(-1),
                                      onNext: () => _step(1),
                                    ),
                                  ),
                                ),
                              if (_failed)
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                                  child: Text(
                                    'Could not refresh sponsors. Pull down to try again.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFEDEEF0),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ] else
                              Expanded(
                                child: _sponsors.isEmpty && _loading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: SponsorStyle.red,
                                        ),
                                      )
                                    : _emptySponsors(),
                              ),
                            SizedBox(
                              height: MediaQuery.paddingOf(context).bottom,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _partnersHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 4, 17, 12),
    child: Row(
      children: [
        const Expanded(
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF74868), Color(0xFFC00035)],
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0x70E81947), blurRadius: 12),
                  ],
                ),
                child: SizedBox(width: 6, height: 25),
              ),
              SizedBox(width: 9),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'MEET OUR PARTNERS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      height: 1.15,
                      shadows: [
                        Shadow(color: Color(0x99000000), blurRadius: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SponsorCategoryMenu(
          sponsors: _sponsors,
          selectedTier: _tier,
          onSelected: _filter,
        ),
      ],
    ),
  );

  // Widget _railLabelRow() => Padding(
  //   padding: const EdgeInsets.fromLTRB(18, 2, 16, 8),
  //   child: Text(
  //     _railLabel,
  //     maxLines: 1,
  //     overflow: TextOverflow.ellipsis,
  //     style: const TextStyle(
  //       color: Color(0xFFFF9BAD),
  //       fontSize: 9,
  //       fontWeight: FontWeight.w800,
  //       letterSpacing: 1.6,
  //     ),
  //   ),
  // );

  Widget _emptySponsors() => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.handshake_outlined, size: 44, color: SponsorStyle.red),
        const SizedBox(height: 16),
        Text(
          _failed
              ? 'Could not load sponsors.'
              : 'Our sponsors will appear here soon.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFEDEEF0)),
        ),
        if (_failed)
          TextButton(
            onPressed: _load,
            style: TextButton.styleFrom(foregroundColor: SponsorStyle.red),
            child: const Text('Retry'),
          ),
      ],
    ),
  );
}

class _MotionButton extends StatelessWidget {
  const _MotionButton({required this.playing, required this.onPressed});
  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: playing ? 'Pause animation' : 'Play animation',
    child: Material(
      color: const Color(0x1FFFFFFF),
      shape: const CircleBorder(side: BorderSide(color: Color(0x4DFFFFFF))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('sponsor-motion'),
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 29,
          height: 29,
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 15,
          ),
        ),
      ),
    ),
  );
}
