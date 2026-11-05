import 'dart:async';

import 'package:flutter/material.dart';

import '../app_poll_repository.dart';
import '../realtime_client.dart';
import '../theme.dart';

class AppFeedPoll extends StatefulWidget {
  const AppFeedPoll({super.key, this.repository});
  final AppPollRepository? repository;
  @override
  State<AppFeedPoll> createState() => _AppFeedPollState();
}

class _AppFeedPollState extends State<AppFeedPoll> {
  AppPollRepository get _repository =>
      widget.repository ?? AppPollRepository.instance;
  List<AppPoll> _polls = [];
  int _currentIndex = 0;
  bool _slideForward = true;
  double _dragDelta = 0.0;
  final Map<String, String> _selectedOptionByPoll = {};
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _expiryTimer;
  bool _loading = false, _voting = false, _reloadAgain = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _polls = _repository.polls;
    if (_polls.isEmpty && _repository.current != null) {
      _polls = [_repository.current!];
    }
    _subscription = RealtimeClient.instance.settingsChanges.listen((event) {
      if (event['resource'] == 'feed-refresh') {
        RealtimeClient.instance.trackFeedRefresh(_load());
      } else if (event['resource'] == 'all' || event['resource'] == 'poll') {
        _load();
      }
    });
    _load();
  }

  Future<void> _load() async {
    if (_loading) {
      _reloadAgain = true;
      return;
    }
    _loading = true;
    await _repository.load();
    _loading = false;
    if (mounted) {
      setState(() {
        _polls = _repository.polls;
        if (_polls.isEmpty && _repository.current != null) {
          _polls = [_repository.current!];
        }
        if (_currentIndex >= _polls.length) {
          _currentIndex = _polls.isEmpty ? 0 : _polls.length - 1;
        }
      });
      _scheduleExpiry();
      if (_reloadAgain) {
        _reloadAgain = false;
        _load();
      }
    }
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    if (_polls.isEmpty) return;
    final current = _polls[_currentIndex.clamp(0, _polls.length - 1)];
    final expiry = current.expiresAt;
    if (expiry != null && expiry.isAfter(DateTime.now())) {
      _expiryTimer = Timer(expiry.difference(DateTime.now()), () {
        if (mounted) setState(() {});
      });
    }
  }

  void _nextPoll() {
    if (_polls.length <= 1) return;
    setState(() {
      _slideForward = true;
      _currentIndex = (_currentIndex + 1) % _polls.length;
      _error = '';
    });
    _scheduleExpiry();
  }

  void _prevPoll() {
    if (_polls.length <= 1) return;
    setState(() {
      _slideForward = false;
      _currentIndex = (_currentIndex - 1 + _polls.length) % _polls.length;
      _error = '';
    });
    _scheduleExpiry();
  }

  Future<void> _vote(AppPoll poll, String optionId) async {
    if (_voting || poll.expired || poll.selectedOptionId != null) return;
    setState(() {
      _voting = true;
      _error = '';
    });
    try {
      final updated = await _repository.vote(optionId, pollId: poll.id);
      if (mounted) {
        setState(() {
          final index = _polls.indexWhere((p) => p.id == updated.id);
          if (index >= 0) {
            _polls[index] = updated;
          }
          _selectedOptionByPoll.remove(poll.id);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your vote. Try again.');
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_polls.isEmpty) return const SizedBox.shrink();
    final poll = _polls[_currentIndex.clamp(0, _polls.length - 1)];
    final results = poll.selectedOptionId != null || poll.expired;
    final selectedOptionId = _selectedOptionByPoll[poll.id];
    final hasMultiple = _polls.length > 1;

    return GestureDetector(
      key: const ValueKey('feed-poll'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _dragDelta = 0,
      onHorizontalDragUpdate: (details) =>
          _dragDelta += details.primaryDelta ?? 0,
      onHorizontalDragEnd: (details) {
        if (!hasMultiple) return;
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -120 || _dragDelta < -30) {
          _nextPoll();
        } else if (velocity > 120 || _dragDelta > 30) {
          _prevPoll();
        }
        _dragDelta = 0;
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.topCenter,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            final isIncoming =
                child.key == ValueKey('feed-poll-card-${poll.id}');
            final inOffset = Tween<Offset>(
              begin: Offset(_slideForward ? 1.0 : -1.0, 0),
              end: Offset.zero,
            );
            final outOffset = Tween<Offset>(
              begin: Offset(_slideForward ? -1.0 : 1.0, 0),
              end: Offset.zero,
            );

            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SlideTransition(
                position: (isIncoming ? inOffset : outOffset).animate(
                  animation,
                ),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              ),
            );
          },
          child: Container(
            key: ValueKey('feed-poll-card-${poll.id}'),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: poll.cardBackgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: poll.cardBorderColor),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x09000000),
                  offset: Offset(0, 2),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header Row
              Row(
                children: [
                  const Icon(
                    Icons.bar_chart_rounded,
                    color: Color(0xFFCD2921),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (poll.pollName != null && poll.pollName!.isNotEmpty)
                          ? poll.pollName!
                          : 'FAN POLL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFBD261F),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .3,
                      ),
                    ),
                  ),
                  if (hasMultiple) ...[
                    // Dot Page Indicators
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < _polls.length; i++)
                          GestureDetector(
                            onTap: () {
                              if (i == _currentIndex) return;
                              setState(() {
                                _slideForward = i > _currentIndex;
                                _currentIndex = i;
                                _error = '';
                              });
                              _scheduleExpiry();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: i == _currentIndex ? 14 : 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: i == _currentIndex
                                    ? const Color(0xFFBD261F)
                                    : const Color(
                                        0xFFBD261F,
                                      ).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    // Navigation Arrows
                    InkWell(
                      onTap: _prevPoll,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: Color(0xFFBD261F),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _nextPoll,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Color(0xFFBD261F),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Your call, Highlander.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                  color: Color(0xFF151626),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                poll.question,
                style: const TextStyle(fontSize: 14, color: Color(0xFF151626)),
              ),
              const SizedBox(height: 10),
              if (poll.expired)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Voting closed',
                    style: TextStyle(color: authMuted, fontSize: 12),
                  ),
                ),
              if (!poll.started)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Voting opens soon',
                    style: TextStyle(color: authMuted, fontSize: 12),
                  ),
                ),
              for (final option in poll.options)
                _option(poll, option, results, selectedOptionId),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _error,
                    style: const TextStyle(color: authRed, fontSize: 12),
                  ),
                ),
              if (!results)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD64C43),
                        disabledBackgroundColor: const Color(0xFFD64C43),
                        disabledForegroundColor: Colors.white,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      onPressed:
                          _voting || selectedOptionId == null || !poll.started
                          ? null
                          : () => _vote(poll, selectedOptionId),
                      child: Text(
                        _voting ? 'Saving your vote...' : poll.effectiveCtaText,
                      ),
                    ),
                  ),
                ),
              if (results) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${poll.totalVotes} votes',
                      style: const TextStyle(color: authMuted, fontSize: 11),
                    ),
                    if (hasMultiple)
                      Text(
                        'Swipe for next poll',
                        style: TextStyle(
                          color: authMuted.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ] else if (hasMultiple) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Swipe for next poll',
                    style: TextStyle(
                      color: authMuted.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _option(
    AppPoll poll,
    AppPollOption option,
    bool results,
    String? selectedOptionId,
  ) {
    final selected = (poll.selectedOptionId ?? selectedOptionId) == option.id;
    final percent = poll.totalVotes == 0
        ? 0
        : (option.votes / poll.totalVotes * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? const Color(0xFFD64C43) : const Color(0xFFEAE8E5),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _voting || results || !poll.started
              ? null
              : () =>
                    setState(() => _selectedOptionByPoll[poll.id] = option.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: selected ? authRed : const Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        option.text,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF151626),
                        ),
                      ),
                    ),
                    if (results)
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                if (results) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      backgroundColor: const Color(0xFFF4EEEE),
                      color: const Color(0xFFED444B),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
