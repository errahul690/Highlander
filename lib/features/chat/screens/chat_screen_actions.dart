part of 'chat_screen.dart';

const _chatLanguages = {
  'auto': 'Detect language',
  'en': 'English',
  'hi': 'Hindi',
  'as': 'Assamese',
  'bn': 'Bengali',
  'ne': 'Nepali',
  'ta': 'Tamil',
  'te': 'Telugu',
  'ml': 'Malayalam',
  'kn': 'Kannada',
  'mr': 'Marathi',
  'pa': 'Punjabi',
  'gu': 'Gujarati',
};

extension _ChatActions on _ChatScreenState {
  Map<String, dynamic> get _chatScope => _direct
      ? {'email': widget.recipientEmail}
      : {'kind': widget.kind, 'roomId': '${widget.room?['_id']}'};
  String get _conversationKey => _direct
      ? ([
          Session.email.toLowerCase(),
          widget.recipientEmail!.toLowerCase(),
        ]..sort()).join('_')
      : '${widget.room?['_id']}';
  List<Map<String, dynamic>> get _selectedMessages => _messages
      .where((row) => _selectedIds.contains('${row['_id'] ?? row['id']}'))
      .toList();

  Future<void> _loadChatOptions() async {
    final version = ++_optionsVersion;
    try {
      final result = await CommunityApi.instance.request(
        '/message-options?${Uri(queryParameters: _chatScope.map((key, value) => MapEntry(key, '$value'))).query}',
      );
      if (!mounted || version != _optionsVersion) return;
      if (result is Map) {
        final serverNow = DateTime.tryParse('${result['serverNow'] ?? ''}');
        if (serverNow != null)
          _serverTimeOffset = serverNow.difference(DateTime.now());
      }
      if (result is Map)
        _update(() => _chatOptions = Map<String, dynamic>.from(result));
      _autoTranslateMessages();
    } catch (_) {
      /* Opening a conversation must still work with an offline server. */
    }
  }

  Future<void> _reloadChatActions() async {
    if (!mounted) return;
    _update(() {
      _historyEpoch++;
      _loadingOlder = false;
      _olderRequest = null;
      _selectedIds.clear();
    });
    await Future.wait([_load(replace: true), _loadChatOptions()]);
  }

  void _removeExpired() {
    if (!mounted) return;
    final expired = _messages
        .where((row) {
          final expiry = DateTime.tryParse('${row['expiresAt'] ?? ''}');
          return expiry != null && !expiry.isAfter(DateTime.now());
        })
        .map((row) => '${row['_id']}')
        .toSet();
    if (expired.isEmpty) return;
    _update(() {
      _messages.removeWhere((row) => expired.contains('${row['_id']}'));
      _selectedIds.removeAll(expired);
      if (_replyTo != null && expired.contains('${_replyTo!['_id']}'))
        _replyTo = null;
      for (final id in expired) {
        _translations.remove(id);
      }
      if (_chatOptions['pinned'] is Map &&
          expired.contains('${_chatOptions['pinned']['_id']}'))
        _chatOptions['pinned'] = null;
      for (final row in _messages)
        if (row['replyTo'] is Map &&
            expired.contains('${row['replyTo']['messageId']}')) {
          row['replyTo'] = {
            'messageId': row['replyTo']['messageId'],
            'content': 'Message unavailable',
          };
        }
    });
  }

  void _toggleMessage(Map<String, dynamic> message) {
    if (_actionBusy || _editingMessage != null) return;
    final id = '${message['_id'] ?? message['id'] ?? ''}';
    if (id.isEmpty) return;
    _textFocus.unfocus();
    _update(() {
      if (!_selectedIds.remove(id) && _selectedIds.length < 30)
        _selectedIds.add(id);
    });
  }

  void _actionError(Object error) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userFacingError(error))));
  }

  Future<dynamic> _messageAction(
    String action, {
    Map<String, dynamic> extra = const {},
    List<String>? ids,
  }) {
    final body = {
      ..._chatScope,
      'messageIds': ids ?? _selectedIds.toList(),
      'action': action,
      ...extra,
    };
    return action == 'translate'
        ? CommunityApi.instance.translateMessage(body)
        : CommunityApi.instance.request(
            '/message-actions',
            method: 'POST',
            body: body,
          );
  }

  Future<void> _changeMessages(
    String action,
    Map<String, dynamic> extra,
  ) async {
    if (_actionBusy || _selectedIds.isEmpty) return;
    final ids = _selectedIds.toList();
    _update(() => _actionBusy = true);
    try {
      await _messageAction(action, extra: extra, ids: ids);
      if (!mounted) return;
      if (action == 'star') {
        _applyMessageChange({
          'action': 'star',
          'messageIds': ids,
          'starred': extra['enabled'],
        });
        _update(() => _selectedIds.clear());
      } else {
        await _reloadChatActions();
      }
    } catch (error) {
      _actionError(error);
    } finally {
      if (mounted) _update(() => _actionBusy = false);
    }
  }

  bool _canChangeMessage(Map<String, dynamic> message, {bool edit = false}) {
    if (message['senderEmail'] != Session.email || message['deletedAt'] != null)
      return false;
    final created = DateTime.tryParse('${message['createdAt'] ?? ''}');
    if (created == null) return false;
    final age = DateTime.now().add(_serverTimeOffset).difference(created);
    final seconds =
        (_chatOptions[edit ? 'editWindowSeconds' : 'deleteWindowSeconds']
                as num?)
            ?.toInt() ??
        900;
    if (age.isNegative || age >= Duration(seconds: seconds)) return false;
    return !edit ||
        (_canSend &&
            !_sending &&
            !_uploadingAttachment &&
            _chatOptions['editWindowSeconds'] != null &&
            '${message['content'] ?? ''}'.trim().isNotEmpty &&
            message['sharedPostId'] == null &&
            !RegExp(r'^(group_|poll_)')
                .hasMatch('${message['attachmentType'] ?? ''}'));
  }

  void _applyMessageChange(Map<String, dynamic> event) {
    if (!mounted) return;
    _update(() {
      if (event['action'] == 'star') {
        final ids = (event['messageIds'] as List? ?? [])
            .map((id) => '$id')
            .toSet();
        for (final row in _messages) {
          if (ids.contains('${row['_id']}'))
            row['starred'] = event['starred'] == true;
        }
      } else if (event['action'] == 'edit' && event['message'] is Map) {
        final edited = event['message'] as Map;
        if (edited['content'] is! String || edited['_id'] == null) return;
        final id = '${edited['_id']}';
        final quoteText = edited['content'] as String;
        _translations.remove(id);
        for (final row in _messages) {
          if ('${row['_id']}' == id) {
            row['content'] = edited['content'];
            row['editedAt'] = edited['editedAt'];
          }
          if (row['replyTo'] is Map && '${row['replyTo']['messageId']}' == id) {
            row['replyTo'] = {
              ...(row['replyTo'] as Map),
              'content': quoteText.length > 1000
                  ? quoteText.substring(0, 1000)
                  : quoteText,
            };
          }
        }
        if (_replyTo != null && '${_replyTo!['_id']}' == id) {
          _replyTo = {..._replyTo!, 'content': edited['content']};
        }
        if (_chatOptions['pinned'] is Map &&
            '${_chatOptions['pinned']['_id']}' == id) {
          _chatOptions['pinned'] = {
            ..._chatOptions['pinned'] as Map,
            'content': edited['content'],
          };
        }
      }
    });
  }

  Future<void> _editMessage(Map<String, dynamic> message) async {
    _beginInlineEdit(message);
  }

  Future<void> _deleteSelected() async {
    final everyone =
        _selectedMessages.isNotEmpty &&
        _selectedMessages.every((row) => _canChangeMessage(row));
    final mode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete ${_selectedIds.length == 1 ? 'message' : 'messages'}?',
        ),
        content: const Text(
          'Delete for everyone is available for 15 minutes after sending. Delete for me only removes messages from your own chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'me'),
            child: const Text('Delete for me'),
          ),
          if (everyone)
            TextButton(
              onPressed: () => Navigator.pop(context, 'everyone'),
              child: const Text('Delete for everyone'),
            ),
        ],
      ),
    );
    if (mode != null && mounted)
      await _changeMessages('delete', {'mode': mode});
  }

  Future<void> _forwardSelected() async {
    final sent = await showChatForwardSheet(
      context,
      _selectedIds.toList(),
      _chatScope,
    );
    if (mounted && sent) _update(() => _selectedIds.clear());
  }

  Future<void> _messageInfo() async {
    _update(() => _actionBusy = true);
    try {
      final data = await _messageAction('info');
      if (!mounted || data is! Map) return;
      String timestamp(dynamic value) {
        final date = DateTime.tryParse('$value')?.toLocal();
        if (date == null) return '';
        return '${date.day}/${date.month}/${date.year} ${TimeOfDay.fromDateTime(date).format(context)}';
      }

      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Message info',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.check),
                title: const Text('Sent'),
                subtitle: Text(timestamp(data['sentAt'])),
              ),
              if (data['direct'] == true) ...[
                ListTile(
                  leading: const Icon(Icons.done_all),
                  title: const Text('Delivered'),
                  subtitle: Text(
                    data['delivered'] == true
                        ? timestamp(data['deliveredAt']).isEmpty
                              ? 'Delivered'
                              : timestamp(data['deliveredAt'])
                        : 'Not delivered yet',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.done_all, color: Color(0xFF168BD2)),
                  title: const Text('Read'),
                  subtitle: Text(
                    data['read'] == true
                        ? timestamp(data['readAt']).isEmpty
                              ? 'Read'
                              : timestamp(data['readAt'])
                        : 'Not read yet',
                  ),
                ),
              ] else
                const ListTile(
                  subtitle: Text(
                    'Individual read receipts are unavailable for this group.',
                  ),
                ),
              if (data['expiresAt'] != null)
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Disappears'),
                  subtitle: Text(timestamp(data['expiresAt'])),
                ),
            ],
          ),
        ),
      );
    } catch (error) {
      _actionError(error);
    } finally {
      if (mounted) _update(() => _actionBusy = false);
    }
  }

  void _hideTranslation(String id) {
    _update(() {
      _translations.remove(id);
      _hiddenTranslations.add(id);
      _autoTranslated.add(id);
    });
  }

  Future<void> _translateMessage(String id, {bool automatic = false}) async {
    if (!automatic) _hiddenTranslations.remove(id);
    if (automatic && _hiddenTranslations.contains(id)) return;
    if (_translationPending.contains(id)) return;
    _translationPending.add(id);
    final source = '${_chatOptions['sourceLanguage'] ?? 'auto'}';
    final target = '${_chatOptions['targetLanguage'] ?? 'en'}';
    try {
      final result = await _messageAction(
        'translate',
        ids: [id],
        extra: {'sourceLanguage': source, 'targetLanguage': target},
      );
      if (mounted &&
          result is Map &&
          result['text'] is String &&
          !_hiddenTranslations.contains(id) &&
          source == '${_chatOptions['sourceLanguage'] ?? 'auto'}' &&
          target == '${_chatOptions['targetLanguage'] ?? 'en'}')
        _update(() {
          _translations[id] = result['text'];
          if (!automatic) _selectedIds.clear();
        });
    } catch (error) {
      if (!automatic) _actionError(error);
    } finally {
      _translationPending.remove(id);
    }
  }

  void _autoTranslateMessages() {
    if (!mounted) return;
    // History and previously visible messages are the baseline. Only messages
    // received after opening/enabling translation are sent automatically.
    final seen = _messages.map((row) => '${row['_id']}').toSet();
    if (!_translationBaselineReady || _chatOptions['autoTranslate'] != true) {
      _autoTranslated.addAll(seen);
      if (!_loading) _translationBaselineReady = true;
      return;
    }
    final incoming = _messages.reversed
        .where(
          (row) =>
              row['senderEmail'] != Session.email &&
              row['deletedAt'] == null &&
              '${row['content'] ?? ''}'.trim().isNotEmpty &&
              !_hiddenTranslations.contains('${row['_id']}') &&
              !_autoTranslated.contains('${row['_id']}'),
        )
        .take(3)
        .toList();
    for (final row in incoming) {
      final id = '${row['_id']}';
      _autoTranslated.add(id);
      unawaited(_translateMessage(id, automatic: true));
    }
  }

  PreferredSizeWidget _selectionBar() {
    final rows = _selectedMessages;
    final single = rows.length == 1 ? rows.first : null;
    final available =
        rows.isNotEmpty && rows.every((row) => row['deletedAt'] == null);
    final allStarred = rows.every((row) => row['starred'] == true);
    final canEdit = single != null && _canChangeMessage(single, edit: true);
    return AppBar(
      toolbarHeight: const ClubHeader(title: '').preferredSize.height,
      backgroundColor: const Color(0xFFF8F7F9),
      foregroundColor: const Color(0xFF242832),
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        tooltip: 'Cancel selection',
        icon: const Icon(Icons.arrow_back),
        onPressed: _actionBusy
            ? null
            : () => _update(() => _selectedIds.clear()),
      ),
      title: Text(
        '${_selectedIds.length}',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      actions: [
        if (_canSend && single != null && available)
          IconButton(
            tooltip: 'Reply',
            icon: const Icon(Icons.reply_rounded),
            onPressed: _actionBusy
                ? null
                : () {
                    _update(() => _selectedIds.clear());
                    _beginReply(single);
                  },
          ),
        if (available)
          IconButton(
            tooltip: canEdit
                ? 'Edit'
                : allStarred
                ? 'Unstar'
                : 'Star',
            icon: Icon(
              canEdit
                  ? Icons.edit_outlined
                  : allStarred
                  ? Icons.star
                  : Icons.star_border_rounded,
            ),
            onPressed: _actionBusy
                ? null
                : () => canEdit
                      ? _editMessage(single)
                      : _changeMessages('star', {'enabled': !allStarred}),
          ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: _actionBusy ? null : _deleteSelected,
        ),
        if (available)
          IconButton(
            tooltip: 'Forward',
            icon: const Icon(Icons.forward_rounded),
            onPressed: _actionBusy ? null : _forwardSelected,
          ),
        AppPopupMenu<String>(
          tooltip: 'Message actions',
          enabled: !_actionBusy,
          onSelected: (value) async {
            if (value == 'copy') {
              await Clipboard.setData(
                ClipboardData(
                  text: rows
                      .map((row) => '${row['content'] ?? ''}')
                      .where((text) => text.isNotEmpty)
                      .join('\n'),
                ),
              );
              if (mounted) {
                _update(() => _selectedIds.clear());
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Copied')));
              }
            } else if (value == 'info') {
              await _messageInfo();
            } else if (value == 'star') {
              await _changeMessages('star', {'enabled': !allStarred});
            } else if (value == 'edit' && single != null) {
              await _editMessage(single);
            } else if (value == 'pin') {
              await _changeMessages('pin', {
                'enabled': single?['pinnedAt'] == null,
              });
            } else if (value == 'translate' && single != null) {
              final changed = await _openChatSettings(initial: 'translate');
              if (changed && mounted)
                await _translateMessage('${single['_id']}');
            }
          },
          itemBuilder: (_) => [
            if (single != null && single['senderEmail'] == Session.email)
              _menuItem('info', 'Info', Icons.info_outline),
            if (canEdit)
              _menuItem(
                'star',
                allStarred ? 'Unstar' : 'Star',
                allStarred ? Icons.star : Icons.star_outline_rounded,
              ),
            if (rows.any((row) => '${row['content'] ?? ''}'.isNotEmpty) &&
                available)
              _menuItem('copy', 'Copy', Icons.copy_outlined),
            if (single != null && available && _canSend)
              _menuItem(
                'pin',
                single['pinnedAt'] == null ? 'Pin' : 'Unpin',
                Icons.push_pin_outlined,
              ),
            if (single != null &&
                available &&
                '${single['content'] ?? ''}'.trim().isNotEmpty)
              _menuItem('translate', 'Translate', Icons.translate),
          ],
        ),
      ],
    );
  }

  List<PopupMenuEntry<String>> get _commonChatItems => [
    _menuItem('search', 'Search', Icons.search),
    _menuItem('media', 'Media, links and docs', Icons.perm_media_outlined),
    _menuItem('starred', 'Starred messages', Icons.star_outline_rounded),
    _menuItem('disappear', 'Disappearing messages', Icons.timer_outlined),
    _menuItem('theme', 'Chat theme', Icons.palette_outlined),
    _menuItem('translate', 'Translation options', Icons.translate),
  ];

  void _chatMenuAction(String value) {
    if (value == 'search') {
      _startChatSearch();
    } else if (['media', 'starred'].contains(value)) {
      unawaited(_browseChat(value));
    } else {
      unawaited(_openChatSettings(initial: value));
    }
  }

  Future<void> _browseChat(String type) async {
    final message = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _ChatBrowsePage(scope: _chatScope, type: type),
      ),
    );
    if (message != null && mounted) await _jumpToOriginal(message);
  }

  Future<bool> _openChatSettings({required String initial}) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _ChatOptionsPage(
          scope: _chatScope,
          current: _chatOptions,
          initial: initial,
          canSend: _canSend,
        ),
      ),
    );
    if (result == null || !mounted) return false;
    _update(() {
      _optionsVersion++;
      _chatOptions = result;
      _translations.clear();
      _autoTranslated.clear();
      _translationBaselineReady = false;
    });
    _autoTranslateMessages();
    return true;
  }

  Widget _conversationNotice() => Material(
    color: const Color(0xFFF7F2F4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_chatOptions['pinned'] is Map)
          ListTile(
            dense: true,
            leading: const Icon(
              Icons.push_pin_rounded,
              size: 18,
              color: authRed,
            ),
            title: Text(
              '${_chatOptions['pinned']['content'] ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _jumpToOriginal(
              Map<String, dynamic>.from(_chatOptions['pinned'] as Map),
            ),
          ),
        if ((_chatOptions['disappearSeconds'] as num? ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              'New messages disappear after ${_durationLabel((_chatOptions['disappearSeconds'] as num).toInt())}',
              style: const TextStyle(fontSize: 11, color: authMuted),
            ),
          ),
      ],
    ),
  );
}

String _durationLabel(int seconds) => switch (seconds) {
  86400 => '24 hours',
  604800 => '7 days',
  7776000 => '90 days',
  _ => 'Off',
};

class _ChatOptionsPage extends StatefulWidget {
  const _ChatOptionsPage({
    required this.scope,
    required this.current,
    required this.initial,
    required this.canSend,
  });
  final Map<String, dynamic> scope, current;
  final String initial;
  final bool canSend;
  @override
  State<_ChatOptionsPage> createState() => _ChatOptionsPageState();
}

class _ChatOptionsPageState extends State<_ChatOptionsPage> {
  late String _theme, _source, _target;
  late int _seconds;
  late bool _auto;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _theme = '${widget.current['theme'] ?? 'default'}';
    _source = '${widget.current['sourceLanguage'] ?? 'auto'}';
    _target = '${widget.current['targetLanguage'] ?? 'en'}';
    _seconds = (widget.current['disappearSeconds'] as num?)?.toInt() ?? 0;
    _auto = widget.current['autoTranslate'] == true;
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = {
      ...widget.scope,
      if (widget.initial == 'theme') 'theme': _theme,
      if (widget.initial == 'disappear') 'disappearSeconds': _seconds,
      if (widget.initial == 'translate') ...{
        'autoTranslate': _auto,
        'sourceLanguage': _source,
        'targetLanguage': _target,
      },
    };
    try {
      final result = await CommunityApi.instance.request(
        '/message-options',
        method: 'PUT',
        body: body,
      );
      if (mounted && result is Map)
        Navigator.pop(context, Map<String, dynamic>.from(result));
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(switch (widget.initial) {
        'theme' => 'Chat theme',
        'disappear' => 'Disappearing messages',
        _ => 'Translation options',
      }),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.initial == 'theme') ...[
          const Text(
            'Choose a theme for your view of this chat.',
            style: TextStyle(color: authMuted),
          ),
          const SizedBox(height: 16),
          for (final entry in {
            'default': const Color(0xFFF8F6F3),
            'rose': const Color(0xFFF9EDF1),
            'sage': const Color(0xFFEDF5EF),
            'sky': const Color(0xFFEDF3FB),
            'sand': const Color(0xFFF8F0DF),
          }.entries)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: entry.value,
                child: _theme == entry.key
                    ? const Icon(Icons.check, color: authRed)
                    : null,
              ),
              title: Text(
                '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
              ),
              selected: _theme == entry.key,
              onTap: _busy ? null : () => setState(() => _theme = entry.key),
            ),
        ] else if (widget.initial == 'disappear') ...[
          const Text(
            'This changes the timer for new messages in this conversation. Existing messages keep their current expiry. Saved files, screenshots and forwarded copies may remain.',
            style: TextStyle(color: authMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          for (final seconds in [0, 86400, 604800, 7776000])
            ListTile(
              title: Text(_durationLabel(seconds)),
              trailing: Icon(
                _seconds == seconds
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: authRed,
              ),
              onTap: _busy || !widget.canSend
                  ? null
                  : () => setState(() => _seconds = seconds),
            ),
        ] else ...[
          const Text(
            'Choose a language for translations. Only messages you translate are sent to the configured translation provider. Automatic translation sends incoming text in this chat. Translations may contain mistakes.',
            style: TextStyle(color: authMuted, height: 1.4),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _source,
            decoration: const InputDecoration(labelText: 'Translate from'),
            items: _chatLanguages.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) => setState(() => _source = value!),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _target,
            decoration: const InputDecoration(labelText: 'Translate to'),
            items: _chatLanguages.entries
                .where((entry) => entry.key != 'auto')
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) => setState(() => _target = value!),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Translate new incoming messages'),
            value: _auto,
            onChanged: _busy ? null : (value) => setState(() => _auto = value),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy || (widget.initial == 'disappear' && !widget.canSend)
              ? null
              : _save,
          child: Text(
            _busy
                ? 'Saving…'
                : widget.initial == 'translate'
                ? 'Save translation options'
                : 'Save',
          ),
        ),
      ],
    ),
  );
}

class _ChatBrowsePage extends StatefulWidget {
  const _ChatBrowsePage({required this.scope, required this.type});
  final Map<String, dynamic> scope;
  final String type;
  @override
  State<_ChatBrowsePage> createState() => _ChatBrowsePageState();
}

class _ChatBrowsePageState extends State<_ChatBrowsePage> {
  final _search = TextEditingController();
  final _rows = <Map<String, dynamic>>[];
  Timer? _debounce;
  int _tab = 0, _version = 0;
  bool _busy = false, _more = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    final version = ++_version;
    final offset = append ? _rows.length : 0;
    setState(() {
      _busy = true;
      _error = null;
      if (!append) _rows.clear();
    });
    final params = {
      ...widget.scope,
      'type': widget.type == 'media'
          ? ['media', 'links', 'docs'][_tab]
          : widget.type,
      'q': _search.text.trim(),
      'offset': '$offset',
      'limit': '50',
    };
    try {
      final data = await CommunityApi.instance.request(
        '/message-search?${Uri(queryParameters: params.map((k, v) => MapEntry(k, '$v'))).query}',
      );
      if (mounted && version == _version && data is Map)
        setState(() {
          _rows.addAll(
            (data['messages'] as List? ?? []).whereType<Map>().map(
              (row) => Map<String, dynamic>.from(row),
            ),
          );
          _more = data['hasMore'] == true;
        });
    } catch (error) {
      if (mounted && version == _version)
        setState(() => _error = userFacingError(error));
    } finally {
      if (mounted && version == _version) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(switch (widget.type) {
        'media' => 'Media, links and docs',
        'starred' => 'Starred messages',
        _ => 'Search messages',
      }),
    ),
    body: Column(
      children: [
        if (widget.type == 'search')
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search this conversation',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) {
                _debounce?.cancel();
                ++_version;
                _debounce = Timer(const Duration(milliseconds: 300), _load);
              },
            ),
          ),
        if (widget.type == 'media')
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                for (final (index, label) in ['Media', 'Links', 'Docs'].indexed)
                  ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        color: _tab == index
                            ? Colors.white
                            : const Color(0xFF242832),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: Colors.white,
                    selectedColor: authRed,
                    showCheckmark: false,
                    selected: _tab == index,
                    onSelected: (_) {
                      setState(() => _tab = index);
                      _load();
                    },
                  ),
              ],
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: _busy && _rows.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
              ? Center(
                  child: _error != null
                      ? TextButton(onPressed: _load, child: const Text('Retry'))
                      : const Text('No messages found'),
                )
              : ListView.builder(
                  itemCount: _rows.length + (_more ? 1 : 0),
                  itemBuilder: (_, index) {
                    if (index == _rows.length)
                      return TextButton(
                        onPressed: _busy ? null : () => _load(append: true),
                        child: Text(_busy ? 'Loading…' : 'Load more'),
                      );
                    final row = _rows[index];
                    final type = '${row['attachmentType'] ?? ''}';
                    return ListTile(
                      leading: type.startsWith('image/')
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: ChatMediaImage(
                                url:
                                    '${row['attachmentUrl'] ?? row['image'] ?? ''}',
                                thumbnail:
                                    '${row['attachmentThumbnail'] ?? ''}',
                                preview: '${row['attachmentPreview'] ?? ''}',
                                width: 48,
                                height: 48,
                              ),
                            )
                          : Icon(
                              type.startsWith('video/')
                                  ? Icons.videocam_outlined
                                  : row['sharedPostId'] != null
                                  ? Icons.article_outlined
                                  : type.isNotEmpty
                                  ? Icons.description_outlined
                                  : Icons.chat_bubble_outline,
                            ),
                      title: Text(
                        '${row['content'] ?? ''}'.isNotEmpty
                            ? '${row['content']}'
                            : '${row['attachmentName'] ?? 'Shared post'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${row['senderName'] ?? ''} · ${messageTimeLabel(row)}',
                      ),
                      trailing: row['starred'] == true
                          ? const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFAD852D),
                              size: 18,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, row),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
