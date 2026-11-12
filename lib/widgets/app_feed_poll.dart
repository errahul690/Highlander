import '../brand_colors.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app_poll_repository.dart';
import '../realtime_client.dart';
import '../theme.dart';
import '../club_repository.dart';
import 'poll_background_image.dart';

const _pollRed = brandAccent;

class AppFeedPoll extends StatefulWidget {
  const AppFeedPoll({super.key, this.repository, this.initialPollId});
  final String? initialPollId;
  final AppPollRepository? repository;
  @override
  State<AppFeedPoll> createState() => _AppFeedPollState();
}

class _AppFeedPollState extends State<AppFeedPoll> {
  AppPollRepository get _repository =>
      widget.repository ?? AppPollRepository.instance;
  List<AppPoll> _polls = [];
  int _currentIndex = 0;
  final _pager = PageController();
  final Map<String, double> _heights = {};
  bool _initialPollSelected = false;
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
      } else if (event['resource'] == 'all' ||
          event['resource'] == 'poll' ||
          event['resource'] == 'poll-background') {
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
    final currentId = _polls.isEmpty
        ? null
        : _polls[_currentIndex.clamp(0, _polls.length - 1)].id;
    await _repository.load(pollId: widget.initialPollId);
    _loading = false;
    if (mounted) {
      setState(() {
        _polls = List.of(_repository.polls);
        final desiredId = !_initialPollSelected
            ? widget.initialPollId ?? currentId
            : currentId;
        final desiredIndex = _polls.indexWhere((poll) => poll.id == desiredId);
        if (desiredIndex >= 0) {
          _currentIndex = desiredIndex;
          _initialPollSelected = true;
        }
        if (_polls.isEmpty && _repository.current != null) {
          _polls = [_repository.current!];
        }
        if (_currentIndex >= _polls.length) {
          _currentIndex = _polls.isEmpty ? 0 : _polls.length - 1;
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _pager.hasClients &&
            _pager.page?.round() != _currentIndex) {
          _pager.jumpToPage(_currentIndex);
        }
      });
      _scheduleExpiry();
      if (_reloadAgain) {
        _reloadAgain = false;
        await _load();
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

  void _goToPoll(int index) {
    if (!_pager.hasClients) return;
    _pager.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
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
    _pager.dispose();
    _expiryTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_polls.isEmpty) {
      if (widget.initialPollId != null) {
        return Center(
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('This poll is no longer available.'),
        );
      }
      return const SizedBox.shrink();
    }
    final poll = _polls[_currentIndex.clamp(0, _polls.length - 1)];
    return KeyedSubtree(
      key: const ValueKey('feed-poll'),
      child: _card(context, poll),
    );
  }

  Widget _pollPages(BuildContext context, AppPoll poll) {
    if (_polls.length == 1) return _pollContent(poll);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: _heights[poll.id] ?? 300,
        child: PageView.builder(
          key: const ValueKey('poll-pager'),
          controller: _pager,
          physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
          itemCount: _polls.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
              _error = '';
            });
            _scheduleExpiry();
          },
          itemBuilder: (context, index) {
            final page = _polls[index];
            return OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: _PollSizeReporter(
                onSize: (size) {
                  if (mounted && _heights[page.id] != size.height) {
                    setState(() => _heights[page.id] = size.height);
                  }
                },
                child: _pollContent(page),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _pagination() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < _polls.length; i++)
        Semantics(
          label: 'Poll ${i + 1} of ${_polls.length}',
          selected: i == _currentIndex,
          button: true,
          child: InkWell(
            onTap: () => _goToPoll(i),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _currentIndex
                      ? _pollRed
                      : const Color(0xFFA6A4AD),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _card(BuildContext context, AppPoll poll) {
    final hasMultiple = _polls.length > 1;
    final backgroundImage = _repository.backgroundFor(poll);
    return Container(
      key: const ValueKey('feed-poll-card'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: poll.cardBackgroundColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            offset: Offset(0, 5),
            blurRadius: 12,
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            if (backgroundImage.isNotEmpty)
              Positioned.fill(
                child: PollBackgroundImage(
                  source: ClubRepository.mediaUrl(backgroundImage),
                  key: ValueKey('poll-background-$backgroundImage'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .88),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x07000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bar_chart_rounded,
                          color: _pollRed,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            poll.pollName?.isNotEmpty == true
                                ? poll.pollName!
                                : 'FAN POLL',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _pollRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your call, Highlander.',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.4,
                      color: Color(0xFF1C1C21),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _pollPages(context, poll),
                  const SizedBox(height: 10),
                  Row(
                    key: const ValueKey('poll-footer'),
                    children: [
                      ...[
                        Image.asset(
                          'assets/icons/poll-voters.png',
                          width: 18,
                          height: 18,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${poll.totalVotes} votes',
                          style: const TextStyle(
                            color: Color(0xFF595664),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (hasMultiple)
                        KeyedSubtree(
                          key: const ValueKey('poll-pagination'),
                          child: _pagination(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pollContent(AppPoll poll) {
    final results = poll.selectedOptionId != null || poll.expired;
    final selectedOptionId = _selectedOptionByPoll[poll.id];
    return Column(
      key: ValueKey('poll-content-${poll.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          poll.question,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF595664),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 22),
        if (poll.expired)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Voting closed',
              style: TextStyle(color: authMuted, fontSize: 12),
            ),
          ),
        if (!poll.started)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
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
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _pollRed,
                  disabledBackgroundColor: _pollRed.withValues(alpha: .45),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _voting || selectedOptionId == null || !poll.started
                    ? null
                    : () => _vote(poll, selectedOptionId),
                child: Text(
                  _voting ? 'Saving your vote...' : poll.effectiveCtaText,
                ),
              ),
            ),
          ),
      ],
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? const Color(0xFFFCEBF0)
            : Colors.white.withValues(alpha: .92),
        elevation: 2,
        shadowColor: const Color(0x16000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? const Color(0xFFFFA9BE) : const Color(0xFFF3F1F8),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _voting || results || !poll.started
              ? null
              : () =>
                    setState(() => _selectedOptionByPoll[poll.id] = option.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: selected ? _pollRed : const Color(0xFF858491),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              option.text,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1C1C21),
                              ),
                            ),
                          ),
                          if (results) ...[
                            const SizedBox(width: 8),
                            Text(
                              '$percent%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: percent > 0
                                    ? _pollRed
                                    : const Color(0xFF302C45),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (results) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            borderRadius: BorderRadius.circular(8),
                            value: (percent / 100).clamp(0, 1),
                            backgroundColor: selected
                                ? const Color(0xFFEEDAE3)
                                : const Color(0xFFDCD9E4),
                            color: _pollRed,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ],
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

class _PollSizeReporter extends SingleChildRenderObjectWidget {
  const _PollSizeReporter({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _PollSizeRenderObject(onSize);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _PollSizeRenderObject renderObject,
  ) => renderObject.onSize = onSize;
}

class _PollSizeRenderObject extends RenderProxyBox {
  _PollSizeRenderObject(this.onSize);
  ValueChanged<Size> onSize;
  Size? _previous;
  @override
  void performLayout() {
    super.performLayout();
    if (_previous == size) return;
    _previous = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(measured);
    });
  }
}
