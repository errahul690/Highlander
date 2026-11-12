import '../brand_colors.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models.dart';
import '../screens/full_squad_screen.dart';
import '../screens/player_screen.dart';
import 'squad_stage_background.dart';

const _ink = Color(0xFF101014), _muted = Color(0xFF62626C);
const _red = brandAccent,
    _gold = Color(0xFFB98A2F),
    _line = Color(0xFFE4E4E8);
const _positions = [
  'ALL',
  'GOALKEEPER',
  'DEFENDER',
  'MIDFIELDER',
  'FORWARD',
  'COACH',
];
const _labels = [
  'ALL',
  'GOALKEEPERS',
  'DEFENDERS',
  'MIDFIELDERS',
  'FORWARDS',
  'COACH',
];
const _transition = Duration(milliseconds: 420);

class SquadShowcase extends StatefulWidget {
  const SquadShowcase({
    super.key,
    required this.players,
    this.autoPlay = true,
    this.imageProvider,
  });
  final List<Player> players;
  final bool autoPlay;
  final ImageProvider Function(Player player)? imageProvider;
  @override
  State<SquadShowcase> createState() => _SquadShowcaseState();
}

class _SquadShowcaseState extends State<SquadShowcase>
    with WidgetsBindingObserver {
  late List<Player> _all;
  String _filter = 'ALL';
  int _index = 0;
  bool _reduced = false, _foreground = true, _dragging = false;
  Timer? _timer;
  late final PageController _pager;
  late int _page;
  final _prefetched = <ImageProvider>{};
  List<Player> get _players =>
      _filter == 'ALL' ? _all : _all.where((p) => p.group == _filter).toList();
  bool get _running =>
      widget.autoPlay &&
      !_reduced &&
      _foreground &&
      !_dragging &&
      _players.length > 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readPlayers();
    _page = _players.length < 2 ? 0 : _players.length * 1000 + _index;
    _pager = PageController(initialPage: _page, viewportFraction: .52);
  }

  void _readPlayers() {
    _all = List.of(widget.players)
      ..sort((a, b) {
        final group = _positions
            .indexOf(a.group)
            .compareTo(_positions.indexOf(b.group));
        if (group != 0) return group;
        final aNumber = int.tryParse(a.jerseyLabel);
        final bNumber = int.tryParse(b.jerseyLabel);
        final jersey = aNumber != null && bNumber != null
            ? aNumber.compareTo(bNumber)
            : a.jerseyLabel.compareTo(b.jerseyLabel);
        return jersey != 0 ? jersey : a.displayOrder.compareTo(b.displayOrder);
      });
    if (_filter != 'ALL' && !_all.any((p) => p.group == _filter)) {
      _filter = 'ALL';
    }
    _index = _initialIndex();
  }

  int _initialIndex() {
    if (_filter != 'ALL') return 0;
    final index = _players.indexWhere(
      (p) => p.jerseyLabel == '10' && p.group != 'COACH',
    );
    return index < 0 ? 0 : index;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    _precache(_players);
    _schedule();
  }

  @override
  void didUpdateWidget(SquadShowcase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.players != widget.players) {
      final selected = _players.isEmpty ? null : _players[_index].name;
      _readPlayers();
      final retained = _players.indexWhere((p) => p.name == selected);
      if (retained >= 0) _index = retained;
      _resetPager();
      _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) setState(_schedule);
  }

  void _schedule() {
    _timer?.cancel();
    if (_running) {
      _timer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          if (ModalRoute.of(context)?.isCurrent ?? true) {
            _goToPage(_page + 1);
          } else {
            _schedule();
          }
        }
      });
    }
  }

  void _goToPage(int page) {
    if (!_pager.hasClients || _players.length < 2) return;
    if (_reduced) {
      _pager.jumpToPage(page);
    } else {
      _pager.animateToPage(
        page,
        duration: _transition,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _resetPager() {
    _dragging = false;
    _page = _players.length < 2 ? 0 : _players.length * 1000 + _index;
    _precache(_players);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pager.hasClients) _pager.jumpToPage(_page);
    });
  }

  void _onPageChanged(int page) {
    _updateScrollState(() {
      _page = page;
      _index = page % _players.length;
      _schedule();
    });
    _precache(_players);
  }

  void _updateScrollState(VoidCallback update) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      update();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(update);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pager.dispose();
    super.dispose();
  }

  ImageProvider? _provider(Player player) {
    if (widget.imageProvider != null) return widget.imageProvider!(player);
    final url = player.frontImage.isNotEmpty ? player.frontImage : player.image;
    if (url.isEmpty) return null;
    return ResizeImage.resizeIfNeeded(
      (MediaQuery.sizeOf(context).width *
              .78 *
              MediaQuery.devicePixelRatioOf(context))
          .ceil(),
      null,
      NetworkImage(url),
    );
  }

  Widget _photo(Player player) {
    final provider = _provider(player);
    if (provider == null) {
      return const Icon(Icons.person_outline_rounded, color: _muted, size: 72);
    }
    return Image(
      image: provider,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, error, stack) =>
          const Icon(Icons.person_outline_rounded, color: _muted, size: 72),
    );
  }

  void _precache(List<Player> players) {
    if (players.isEmpty) return;
    for (final index in {
      _index,
      (_index + 1) % players.length,
      (_index - 1 + players.length) % players.length,
    }) {
      final player = players[index];
      final provider = _provider(player);
      if (provider != null && _prefetched.add(provider)) {
        precacheImage(provider, context).catchError((_) {});
      }
    }
  }

  void _detail(Player player) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => PlayerScreen(player: player)));

  @override
  Widget build(BuildContext context) {
    final players = _players;
    return CustomScrollView(
      key: const PageStorageKey('squad-showcase-scroll'),
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: true,
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 580;
                final gap = compact ? 5.0 : 8.0;
                return Padding(
                  padding: EdgeInsets.fromLTRB(16, compact ? 8 : 14, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: compact ? 36 : 46,
                        child: Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'MEET THE',
                                      style: TextStyle(
                                        fontFamily: 'Gilroy',
                                        color: _muted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2.4,
                                      ),
                                    ),
                                    Text(
                                      'HIGHLANDERS',
                                      style: TextStyle(
                                        fontFamily: 'Gilroy',
                                        color: _red,
                                        fontSize: 26,
                                        height: 1.15,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF2F1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_all.length} MEMBERS',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: _red,
                                  letterSpacing: .6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: gap),
                      SingleChildScrollView(
                        key: const ValueKey('squad-filters-scroll'),
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < _positions.length; i++)
                              if (i == 0 ||
                                  _all.any((p) => p.group == _positions[i]))
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _tab(_positions[i], _labels[i]),
                                ),
                          ],
                        ),
                      ),
                      SizedBox(height: gap),
                      Expanded(
                        child: players.isEmpty
                            ? const Center(
                                child: Text(
                                  'No active squad members available.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _muted),
                                ),
                              )
                            : _stage(players),
                      ),
                      if (players.isNotEmpty) ...[
                        SizedBox(
                          height: compact ? 58 : 70,
                          child: AnimatedSwitcher(
                            duration: _reduced
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            child: SizedBox(
                              key: ValueKey('squad-name-$_filter-$_index'),
                              width: double.infinity,
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _plate(
                                    players[_index],
                                    constraints.maxWidth - 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: gap),
                        SizedBox(
                          height: compact ? 36 : 42,
                          child: FilledButton(
                            key: const ValueKey('squad-full-roster'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FullSquadScreen(),
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'SEE THE FULL SQUAD',
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _tab(String category, String label) {
    final count = category == 'ALL'
        ? _all.length
        : _all.where((p) => p.group == category).length;
    final selected = _filter == category;
    return Semantics(
      selected: selected,
      button: true,
      label: '$label, $count',
      child: ClipPath(
        clipper: const SquadSlant(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? _red : Colors.transparent,
            border: Border.all(color: selected ? _red : _line),
          ),
          child: TextButton(
            key: ValueKey('squad-filter-$category'),
            onPressed: () {
              if (_filter == category) return;
              setState(() {
                _filter = category;
                _index = _initialIndex();
                _resetPager();
                _schedule();
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: selected ? Colors.white : _muted,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const RoundedRectangleBorder(),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: label),
                  TextSpan(
                    text: '  $count',
                    style: TextStyle(
                      color: (selected ? Colors.white : _muted).withValues(
                        alpha: .6,
                      ),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: .8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _number(Player p) => p.jerseyLabel;
  Widget _stage(List<Player> players) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      key: const ValueKey('squad-player-stage'),
      clipBehavior: Clip.hardEdge,
      fit: StackFit.expand,
      children: [
        Positioned(
          top: constraints.maxHeight * .08,
          left: 0,
          right: 0,
          child: ExcludeSemantics(
            child: AnimatedSwitcher(
              duration: _reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: Text(
                _number(players[_index]),
                key: ValueKey(_number(players[_index])),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: math.min(
                    constraints.maxHeight * .64,
                    constraints.maxWidth * .65,
                  ),
                  height: .85,
                  letterSpacing: -6,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.5
                    ..color = const Color(0x38E01F1B),
                ),
              ),
            ),
          ),
        ),
        if (players.length == 1)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth * .11,
            ),
            child: Semantics(
              button: true,
              label: 'View ${players.single.name}',
              child: GestureDetector(
                onTap: () => _detail(players.single),
                child: RepaintBoundary(child: _photo(players.single)),
              ),
            ),
          )
        else
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth != 0) return false;
              if (notification is ScrollStartNotification) {
                _updateScrollState(() {
                  _dragging = true;
                  _schedule();
                });
              } else if (notification is ScrollEndNotification) {
                _updateScrollState(() {
                  _dragging = false;
                  _schedule();
                });
              }
              return false;
            },
            child: PageView.builder(
              key: const ValueKey('squad-player-pager'),
              controller: _pager,
              allowImplicitScrolling: true,
              physics: const PageScrollPhysics(),
              onPageChanged: _onPageChanged,
              itemBuilder: (context, page) {
                final player = players[page % players.length];
                return OverflowBox(
                  minWidth: constraints.maxWidth * .78,
                  maxWidth: constraints.maxWidth * .78,
                  minHeight: constraints.maxHeight,
                  maxHeight: constraints.maxHeight,
                  child: AnimatedBuilder(
                    animation: _pager,
                    child: RepaintBoundary(child: _photo(player)),
                    builder: (context, child) {
                      final current =
                          _pager.hasClients &&
                              _pager.position.hasContentDimensions
                          ? _pager.page ?? _page.toDouble()
                          : _page.toDouble();
                      final focus = (1 - (page - current).abs()).clamp(
                        0.0,
                        1.0,
                      );
                      final offset = (page - current).clamp(-1.0, 1.0);
                      return Transform.translate(
                        key: ValueKey('squad-hero-$page'),
                        offset: Offset(-offset * constraints.maxWidth * .17, 0),
                        child: Transform.scale(
                          scale: .36 + .64 * focus,
                          alignment: Alignment.bottomCenter,
                          child: Opacity(
                            opacity: .35 + .65 * focus,
                            child: Semantics(
                              button: true,
                              label: 'View ${player.name}',
                              child: GestureDetector(
                                onTap: () => page == _page
                                    ? _detail(player)
                                    : _goToPage(page),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );

  Widget _plate(Player player, double width) {
    final parts = player.name.trim().split(RegExp(r'\s+'));
    final first = player.firstName.isNotEmpty || player.lastName.isNotEmpty
        ? player.firstName
        : parts.length > 1
        ? parts.take(parts.length - 1).join(' ')
        : '';
    final last = player.firstName.isNotEmpty || player.lastName.isNotEmpty
        ? player.lastName
        : parts.last;
    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: GestureDetector(
          onTap: () => _detail(player),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (player.jerseyLabel.isNotEmpty)
                  ClipPath(
                    clipper: const SquadSlant(onlyRight: true),
                    child: Container(
                      color: _red,
                      constraints: const BoxConstraints(minWidth: 56),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                      child: Text(
                        player.jerseyLabel,
                        style: const TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 34,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _line),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (first.isNotEmpty)
                          Text(
                            first.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                              color: _muted,
                            ),
                          ),
                        Text(
                          last.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 20,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          player.position.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 10,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w800,
                            color: _gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
