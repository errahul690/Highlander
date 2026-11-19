part of 'chat_screen.dart';

extension _ChatInPlaceSearch on _ChatScreenState {
  String? get _currentSearchId =>
      _searchIndex >= 0 && _searchIndex < _searchHits.length
      ? '${_searchHits[_searchIndex]['_id']}'
      : null;

  void _startChatSearch() {
    if (_editingMessage != null) return;
    _textFocus.unfocus();
    _update(() {
      _searching = true;
      _selectedIds.clear();
    });
    _searchFocus.requestFocus();
  }

  void _closeChatSearch() {
    _searchDebounce?.cancel();
    _searchVersion++;
    _quoteNavigation++;
    _highlightTimer?.cancel();
    _searchFocus.unfocus();
    _update(() {
      _searching = false;
      _searchBusy = false;
      _searchText.clear();
      _searchHits = [];
      _searchIndex = -1;
      _searchMore = false;
      _searchDate = null;
      _searchError = null;
      _highlightedMessage = null;
    });
  }

  void _scheduleChatSearch() {
    _searchDebounce?.cancel();
    _searchVersion++;
    _quoteNavigation++;
    _update(() {
      _searchHits = [];
      _searchIndex = -1;
      _searchMore = false;
      _searchError = null;
      _searchBusy = _searchText.text.trim().isNotEmpty || _searchDate != null;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 300), _runChatSearch);
  }

  Future<void> _runChatSearch({bool append = false}) async {
    if (!mounted || !_searching) return;
    final query = _searchText.text.trim();
    if (query.isEmpty && _searchDate == null) {
      _update(() => _searchBusy = false);
      return;
    }
    final version = ++_searchVersion;
    final date = _searchDate;
    final params = <String, String>{
      ..._chatScope.map((key, value) => MapEntry(key, '$value')),
      'type': 'search',
      'q': query,
      'limit': '50',
      'offset': append ? '${_searchHits.length}' : '0',
      if (date != null) ...{
        'after': DateTime(
          date.year,
          date.month,
          date.day,
        ).toUtc().toIso8601String(),
        'before': DateTime(
          date.year,
          date.month,
          date.day + 1,
        ).toUtc().toIso8601String(),
      },
    };
    _update(() {
      _searchBusy = true;
      _searchError = null;
    });
    try {
      final result = await CommunityApi.instance.request(
        '/message-search?${Uri(queryParameters: params).query}',
      );
      if (!mounted || !_searching || version != _searchVersion) return;
      if (result is! Map)
        throw Exception('Search is currently unavailable. Try again.');
      final hits = (result['messages'] as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      _update(() {
        final unique = <String, Map<String, dynamic>>{
          if (append)
            for (final row in _searchHits) '${row['_id']}': row,
          for (final row in hits) '${row['_id']}': row,
        };
        _searchHits = unique.values.toList();
        _searchMore = result['hasMore'] == true;
        if (!append) _searchIndex = _searchHits.isEmpty ? -1 : 0;
      });
      if (!append && _searchHits.isNotEmpty) await _navigateSearch(0);
    } catch (error) {
      if (mounted && _searching && version == _searchVersion) {
        _update(() => _searchError = userFacingError(error));
      }
    } finally {
      if (mounted && version == _searchVersion)
        _update(() => _searchBusy = false);
    }
  }

  Future<void> _navigateSearch(int index) async {
    if (!mounted || !_searching || index < 0 || index >= _searchHits.length)
      return;
    _update(() => _searchIndex = index);
    final version = _searchVersion;
    final match = Map<String, dynamic>.from(_searchHits[index]);
    if (_loading) await _load();
    if (mounted && _searching && version == _searchVersion)
      await _jumpToOriginal(match, highlight: false);
  }

  Future<void> _moveSearch({required bool older}) async {
    if (_searchBusy || _searchIndex < 0) return;
    final target = _searchIndex + (older ? 1 : -1);
    if (target >= _searchHits.length && _searchMore)
      await _runChatSearch(append: true);
    if (mounted && _searching) await _navigateSearch(target);
  }

  Future<void> _searchByDate() async {
    _searchFocus.unfocus();
    final now = DateTime.now().add(_serverTimeOffset);
    final date = await showDatePicker(
      context: context,
      initialDate: _searchDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (!mounted || !_searching || date == null) return;
    _update(() => _searchDate = date);
    _scheduleChatSearch();
  }

  PreferredSizeWidget _searchAppBar() => AppBar(
    toolbarHeight: const ClubHeader(title: '').preferredSize.height,
    automaticallyImplyLeading: false,
    backgroundColor: const Color(0xFFF8F7F9),
    foregroundColor: const Color(0xFF242832),
    elevation: 0,
    titleSpacing: 12,
    title: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0EFEC),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close search',
            onPressed: _closeChatSearch,
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: TextField(
              key: const ValueKey('chat-search-input'),
              controller: _searchText,
              focusNode: _searchFocus,
              maxLength: 100,
              style: const TextStyle(fontSize: 16, color: Color(0xFF242832)),
              decoration: const InputDecoration(
                hintText: 'Search...',
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (_) => _scheduleChatSearch(),
              onSubmitted: (_) {
                _searchDebounce?.cancel();
                _runChatSearch();
              },
            ),
          ),
          if (_searchText.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                _searchText.clear();
                _scheduleChatSearch();
              },
            ),
          IconButton(
            tooltip: 'Search by date',
            onPressed: _searchByDate,
            icon: Icon(
              Icons.calendar_month_outlined,
              color: _searchDate != null ? authRed : null,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _searchFooter() {
    final summary = _searchBusy
        ? 'Searching...'
        : _searchIndex >= 0
        ? '${_searchIndex + 1} of ${_searchHits.length}${_searchMore ? '+' : ''}'
        : _searchText.text.trim().isEmpty && _searchDate == null
        ? 'Search this chat'
        : 'No matches';
    return Material(
      color: const Color(0xFFF8F7F9),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: _searchError != null
                    ? TextButton(
                        onPressed: _runChatSearch,
                        child: const Text('Search failed. Retry'),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary,
                            style: const TextStyle(
                              fontSize: 13,
                              color: authMuted,
                            ),
                          ),
                          if (_searchDate != null)
                            Text(
                              MaterialLocalizations.of(context)
                                  .formatShortDate(_searchDate!),
                              style: const TextStyle(
                                fontSize: 11,
                                color: authMuted,
                              ),
                            ),
                        ],
                      ),
              ),
              if (_searchDate != null)
                IconButton(
                  tooltip: 'Clear date filter',
                  icon: const Icon(Icons.event_busy_outlined),
                  onPressed: () {
                    _update(() => _searchDate = null);
                    _scheduleChatSearch();
                  },
                ),
              IconButton(
                tooltip: 'Older match',
                icon: const Icon(Icons.keyboard_arrow_up),
                onPressed:
                    !_searchBusy &&
                        _searchIndex >= 0 &&
                        (_searchIndex + 1 < _searchHits.length || _searchMore)
                    ? () => _moveSearch(older: true)
                    : null,
              ),
              IconButton(
                tooltip: 'Newer match',
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: !_searchBusy && _searchIndex > 0
                    ? () => _moveSearch(older: false)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
