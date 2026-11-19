import 'package:Highlanders/shared/widgets/app_popup_menu.dart';

import 'dart:async';

import 'package:Highlanders/shared/widgets/club_header.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:Highlanders/features/community/data/community_api.dart';
import 'package:Highlanders/core/network/network_read.dart';
import 'package:Highlanders/features/chat/data/chat_media_cache.dart';
import 'package:Highlanders/features/chat/widgets/chat_media_image.dart';
import 'package:Highlanders/features/chat/widgets/chat_file_attachment.dart';
import 'package:Highlanders/features/chat/data/chat_updates.dart';
import 'package:Highlanders/features/auth/data/otp_api.dart';
import 'package:Highlanders/core/session/session.dart';
import 'package:Highlanders/features/support/data/support_hub_repository.dart';
import 'package:Highlanders/features/chat/utils/chat_dates.dart';
import 'package:Highlanders/core/theme/theme.dart';
import 'package:Highlanders/features/chat/widgets/chat_wallpaper.dart';
import 'package:Highlanders/features/chat/widgets/chat_reply_preview.dart';
import 'package:Highlanders/features/chat/widgets/chat_keyboard_inset.dart';
import 'package:Highlanders/features/chat/widgets/chat_message_bubble.dart';
import 'package:Highlanders/features/chat/widgets/chat_post_preview.dart';
import 'package:Highlanders/features/support/widgets/highlander_care_chat.dart';
import 'package:Highlanders/features/chat/widgets/earlier_messages_button.dart';
import 'package:Highlanders/shared/widgets/user_avatar.dart';
import 'package:Highlanders/features/community/widgets/invite_members_sheet.dart';
import 'package:Highlanders/features/community/widgets/group_invitation_actions.dart';
import 'package:Highlanders/features/chat/screens/chat_settings_screen.dart';
import 'package:Highlanders/features/community/screens/group_info_screen.dart';
import 'package:Highlanders/features/posts/widgets/post_share_sheet.dart';

part 'chat_screen_actions.dart';
part 'chat_inline_edit.dart';
part 'chat_in_place_search.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.title,
    this.recipientEmail,
    this.kind,
    this.room,
    this.image = '',
    this.isCare = false,
  });
  final String title;
  final String? recipientEmail, kind;
  final Map<String, dynamic>? room;
  final String image;
  final bool isCare;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  void _update(VoidCallback change) => setState(change);
  static const _appLinks = MethodChannel('highlanders/app_links');
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _textFocus = FocusNode();
  Map<String, dynamic>? _replyTo;
  Map<String, dynamic>? _editingMessage;
  TextEditingValue? _draftBeforeEdit;
  Map<String, dynamic>? _attachmentBeforeEdit, _replyBeforeEdit;
  bool _savingEdit = false;
  DateTime? _editDeadline;
  String? _editError;
  final _searchText = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searching = false, _searchBusy = false, _searchMore = false;
  Timer? _searchDebounce;
  int _searchVersion = 0, _searchIndex = -1;
  List<Map<String, dynamic>> _searchHits = [];
  DateTime? _searchDate;
  String? _searchError;
  final _selectedIds = <String>{};
  final _translations = <String, String>{};
  final _hiddenTranslations = <String>{};
  final _translationPending = <String>{};
  final _autoTranslated = <String>{};
  bool _translationBaselineReady = false;
  Map<String, dynamic> _chatOptions = {};
  int _optionsVersion = 0;
  Duration _serverTimeOffset = Duration.zero;
  bool _actionBusy = false;
  Timer? _expiryTimer;
  final _messageAnchors = <String, GlobalKey>{};
  String? _highlightedMessage;
  Timer? _highlightTimer;
  int _quoteNavigation = 0;
  bool _replySupportConfirmed = false;
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _attachmentDraft;
  bool _loading = true, _sending = false, _uploadingAttachment = false;
  String? _loadError;
  late String _permission;
  late Map<String, dynamic> _roomInfo;
  io.Socket? _socket;
  int _loadVersion = 0;
  static const _pageSize = 100;
  bool _hasOlder = false, _loadingOlder = false, _olderError = false;
  int _historyEpoch = 0;
  bool _careBlocked = false, _careCleared = false, _careOnline = false;
  bool _blockedBy = false;
  bool _careBusy = false;
  bool get _direct => widget.recipientEmail != null;
  bool get _visible =>
      mounted &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  bool _markingRead = false, _readPending = false;
  Future<void> _markRead() async {
    if (!_direct || !_visible) return;
    if (_markingRead) {
      _readPending = true;
      return;
    }
    _markingRead = true;
    try {
      do {
        _readPending = false;
        // Persist through HTTP too: seeing history must not depend on a socket
        // having connected, or on a read broadcast reaching the shell socket.
        await CommunityApi.instance.request(
          '/direct/read',
          method: 'PUT',
          body: {'senderEmail': widget.recipientEmail},
        );
        ChatUpdates.instance.notifyChanged();
      } while (_readPending && _visible);
    } catch (_) {
      if (_visible && _socket?.connected == true) {
        _socket!.emitWithAck(
          'markAllRead',
          {'senderEmail': widget.recipientEmail},
          ack: (result) {
            if (result is Map && result['success'] == true)
              ChatUpdates.instance.notifyChanged();
          },
        );
      }
    } finally {
      _markingRead = false;
    }
  }

  void _receipt(dynamic data, {required bool read, bool single = false}) {
    if (!mounted || !_direct || data is! Map) return;
    if (!single &&
        (read ? data['readerEmail'] : data['receiverEmail']) !=
            widget.recipientEmail)
      return;
    final ids = data['messageIds'];
    setState(() {
      for (final message in _messages) {
        if (message['senderEmail'] != Session.email ||
            message['receiverEmail'] != widget.recipientEmail)
          continue;
        if (single && '${message['_id']}' != '${data['messageId']}') continue;
        if (!read && ids is List && !ids.contains('${message['_id']}'))
          continue;
        message['delivered'] = true;
        if (read) message['read'] = true;
      }
    });
    // Supersede any history request that started before this persisted receipt.
    _load();
  }

  bool get _canSend =>
      !_careBlocked &&
      !_blockedBy &&
      !_careBusy &&
      (_direct ||
          (_permission != 'off' &&
              (_permission != 'admins' || _roomInfo['canManage'] == true)));
  String get _path => _direct
      ? '/direct/messages'
      : '/${widget.kind}/${widget.room!['_id']}/messages';
  @override
  void initState() {
    super.initState();
    unawaited(_loadChatOptions());
    _expiryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _removeExpired();
      if (mounted && (_selectedIds.isNotEmpty || _editingMessage != null))
        _update(() {});
    });
    _roomInfo = {...?widget.room};
    _permission = '${widget.room?['chatPermission'] ?? 'all'}';
    if (widget.kind == 'groups') _refreshGroupInfo();
    WidgetsBinding.instance.addObserver(this);
    _load();
    if (_direct) _loadCareStatus();
    if (Session.token.isNotEmpty) {
      _socket = io.io(
        OtpApi.apiBase,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': Session.token})
            .disableAutoConnect()
            .enableForceNew()
            .build(),
      );
      _socket!.onConnect((_) {
        if (_direct) _loadCareStatus();
        if (widget.isCare) {
          _socket!.emitWithAck(
            'checkStatus',
            widget.recipientEmail,
            ack: (data) {
              if (mounted && data is Map)
                setState(() => _careOnline = data['isOnline'] == true);
            },
          );
        }
        if (!_direct) {
          _socket!.emit('joinConversation', '${widget.room!['_id']}');
        }
        _load();
      });
      if (widget.isCare) {
        _socket!.on('userOnline', (data) {
          if (mounted && data is Map && data['email'] == widget.recipientEmail)
            setState(() => _careOnline = true);
        });
        _socket!.on('userOffline', (data) {
          if (mounted && data is Map && data['email'] == widget.recipientEmail)
            setState(() => _careOnline = false);
        });
        _socket!.onDisconnect((_) {
          if (mounted) setState(() => _careOnline = false);
        });
      }
      _socket!.on('receiveMessage', (dynamic message) {
        if (message is! Map) return;
        final relevant = _direct
            ? (message['senderEmail'] == widget.recipientEmail &&
                      message['receiverEmail'] == Session.email) ||
                  (message['receiverEmail'] == widget.recipientEmail &&
                      message['senderEmail'] == Session.email)
            : message['conversationId'] == widget.room!['_id'];
        if (relevant) _load();
      });
      _socket!.on('chatMessagesChanged', (dynamic event) {
        if (event is Map && event['conversationId'] == _conversationKey) {
          if (event['action'] == 'star' || event['action'] == 'edit') {
            _applyMessageChange(Map<String, dynamic>.from(event));
          } else {
            unawaited(_reloadChatActions());
          }
        }
      });
      _socket!.on('blockStatusChanged', (data) {
        if (mounted &&
            _direct &&
            data is Map &&
            data['email'] == widget.recipientEmail) {
          setState(() {
            _careBlocked = data['blocked'] == true;
            _blockedBy = data['blockedBy'] == true;
          });
        }
      });
      _socket!.on('messagesDelivered', (data) => _receipt(data, read: false));
      _socket!.on(
        'messageRead',
        (data) => _receipt(data, read: true, single: true),
      );
      _socket!.on('allMessagesRead', (data) => _receipt(data, read: true));
      _socket!.connect();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _socket?.connect();
      _load();
      if (_direct) _loadCareStatus();
    }
    if (state == AppLifecycleState.paused) _socket?.disconnect();
  }

  @override
  void didChangeMetrics() {
    if (_editingMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _revealEditedMessage(),
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchVersion++;
    _searchText.dispose();
    _searchFocus.dispose();
    _expiryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _socket?.dispose();
    _quoteNavigation++;
    _highlightTimer?.cancel();
    _text.dispose();
    _textFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _historyPath({Map<String, dynamic>? before}) {
    final query = <String, String>{
      if (_direct) 'email': widget.recipientEmail!,
      'limit': '$_pageSize',
      if (before != null) ...{
        'before': messageDate(before)!.toUtc().toIso8601String(),
        'beforeId': '${before['_id']}',
      },
    };
    return '$_path?${Uri(queryParameters: query).query}';
  }

  void _mergeHistory(List<Map<String, dynamic>> rows) {
    final byId = <String, Map<String, dynamic>>{
      for (final message in _messages) '${message['_id']}': message,
      for (final message in rows) '${message['_id']}': message,
    };
    _messages = byId.values.toList()
      ..sort((first, second) {
        final a = messageDate(first);
        final b = messageDate(second);
        final dateOrder = a != null && b != null ? a.compareTo(b) : 0;
        return dateOrder != 0
            ? dateOrder
            : '${first['_id']}'.compareTo('${second['_id']}');
      });
    unawaited(ChatMediaCache.instance.prefetchMessages(_messages));
  }

  Future<void>? _olderRequest;
  Future<void> _loadOlder() {
    if (_olderRequest != null) return _olderRequest!;
    final request = _fetchOlder();
    _olderRequest = request;
    return request.whenComplete(() {
      if (identical(_olderRequest, request)) _olderRequest = null;
    });
  }

  Future<void> _fetchOlder() async {
    if (_loadingOlder || !_hasOlder || _messages.isEmpty) return;
    final epoch = _historyEpoch;
    setState(() {
      _loadingOlder = true;
      _olderError = false;
    });
    try {
      final rows = await CommunityApi.instance.list(
        _historyPath(before: _messages.first),
      );
      if (!mounted || epoch != _historyEpoch) return;
      _autoTranslated.addAll(rows.map((row) => '${row['_id']}'));
      setState(() {
        _hasOlder = rows.length >= _pageSize;
        _mergeHistory(
          rows
              .skip(rows.length > _pageSize ? rows.length - _pageSize : 0)
              .toList(),
        );
      });
    } catch (_) {
      if (mounted && epoch == _historyEpoch) {
        setState(() => _olderError = true);
      }
    } finally {
      if (mounted && epoch == _historyEpoch) {
        setState(() => _loadingOlder = false);
      }
    }
  }

  Future<void> _load({bool replace = false}) async {
    final version = ++_loadVersion;
    try {
      final page = await CommunityApi.instance.list(_historyPath());
      final hasOlder = page.length >= _pageSize;
      final rows = page.skip(hasOlder ? page.length - _pageSize : 0).toList();
      // Catch up after reconnecting without leaving a gap before loaded history.
      final existingIds = _messages.map((message) => message['_id']).toSet();
      final oldestLoaded = _messages.isEmpty ? null : _messages.first['_id'];
      var nextPage = page;
      while (existingIds.isNotEmpty &&
          nextPage.length >= _pageSize &&
          (replace
              ? !rows.any((message) => message['_id'] == oldestLoaded)
              : !nextPage.any(
                  (message) => existingIds.contains(message['_id']),
                ))) {
        final oldest = rows.first;
        if (messageDate(oldest) == null || oldest['_id'] == null) break;
        nextPage = await CommunityApi.instance.list(
          _historyPath(before: oldest),
        );
        if (!mounted || version != _loadVersion) return;
        final earlier = nextPage
            .skip(nextPage.length > _pageSize ? nextPage.length - _pageSize : 0)
            .toList();
        if (earlier.isEmpty || earlier.first['_id'] == oldest['_id']) break;
        rows.insertAll(0, earlier);
      }
      rows.sort((first, second) {
        final firstDate = messageDate(first);
        final secondDate = messageDate(second);
        return firstDate != null && secondDate != null
            ? firstDate.compareTo(secondDate)
            : 0;
      });
      if (!mounted || version != _loadVersion) return;
      final wasLoading = _loading;
      final nearBottom = !_scroll.hasClients || _scroll.position.pixels < 80;
      final changed =
          rows.length != _messages.length ||
          (rows.isNotEmpty &&
              (_messages.isEmpty || rows.last['_id'] != _messages.last['_id']));
      setState(() {
        if (replace) {
          _messages = [];
          _hasOlder = nextPage.length >= _pageSize;
        } else if (_messages.isEmpty) {
          _hasOlder = hasOlder;
        }
        _mergeHistory(rows);
        _loading = false;
        _loadError = null;
      });
      _autoTranslateMessages();
      if (_direct) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
      }
      if (changed && !wasLoading && nearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.animateTo(
              0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (error) {
      if (mounted && version == _loadVersion) {
        setState(() {
          _loading = false;
          _loadError = userFacingError(error);
        });
      }
    }
  }

  String get _carePath =>
      '/support-conversation?email=${Uri.encodeComponent(widget.recipientEmail!)}';

  Future<void> _loadCareStatus() async {
    try {
      final status = await CommunityApi.instance.request(
        widget.isCare
            ? _carePath
            : '/direct/status?email=${Uri.encodeComponent(widget.recipientEmail!)}',
      );
      if (mounted && status is Map)
        setState(() {
          _careBlocked = status['blocked'] == true;
          _blockedBy = status['blockedBy'] == true;
          _careCleared = status['cleared'] == true;
          _careOnline = status['online'] == true;
        });
    } catch (error) {
      if (mounted) setState(() => _loadError = userFacingError(error));
    }
  }

  Future<void> _refreshCare() async {
    await _load();
    await _loadCareStatus();
  }

  Future<void> _exitCircle() async {
    if (_careBusy || widget.room == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave huddle?'),
        content: Text(
          'You will leave ${widget.title}. You can join again if the huddle is open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave huddle', style: TextStyle(color: careRed)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _careBusy = true);
    try {
      await CommunityApi.instance.request(
        '/circles/${widget.room!['_id']}/leave',
        method: 'POST',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    } finally {
      if (mounted) setState(() => _careBusy = false);
    }
  }

  Future<void> _careAction({required bool clear}) async {
    if (_careBusy || _sending || _uploadingAttachment) return;
    final contactName = widget.isCare
        ? SupportHubRepository.instance.name
        : widget.title;
    final action = clear
        ? 'Clear Chat'
        : _careBlocked
        ? 'Unblock'
        : 'Block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(clear ? 'Clear Chat?' : '$action $contactName?'),
        content: Text(
          clear
              ? widget.isCare
                    ? 'Messages will be cleared only for you. $contactName will keep its copy.'
                    : 'Messages will be cleared only for you. $contactName will still have this chat.'
              : _careBlocked
              ? 'You can send and receive messages with $contactName again.'
              : 'You will stop receiving messages from $contactName. They will see that you blocked them. You can unblock them from this chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: const TextStyle(color: careRed)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _careBusy = true);
    try {
      final result = await CommunityApi.instance.request(
        widget.isCare
            ? _carePath
            : clear
            ? '/direct/messages?email=${Uri.encodeComponent(widget.recipientEmail!)}'
            : '/direct/block?email=${Uri.encodeComponent(widget.recipientEmail!)}',
        method: clear ? 'DELETE' : 'PUT',
        body: clear ? null : {'blocked': !_careBlocked},
      );
      if (!mounted) return;
      setState(() {
        if (clear) {
          ++_loadVersion;
          _messages = [];
          ++_historyEpoch;
          _hasOlder = false;
          _loadingOlder = false;
          _olderError = false;
          _careCleared = true;
        } else {
          _careBlocked = result['blocked'] == true;
          _blockedBy = result['blockedBy'] == true;
        }
      });
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
    } finally {
      if (mounted) setState(() => _careBusy = false);
    }
  }

  Future<void> _send() async {
    if (_editingMessage != null) {
      await _saveInlineEdit();
      return;
    }
    final text = _text.text.trim();
    final attachment = _attachmentDraft;
    final reply = _replyTo;
    if ((text.isEmpty && attachment == null) ||
        _sending ||
        _uploadingAttachment ||
        !_canSend) {
      return;
    }
    setState(() => _sending = true);
    try {
      if (reply != null && !_replySupportConfirmed) {
        Object? features;
        try {
          features = await CommunityApi.instance.request('/message-features');
        } catch (_) {
          throw Exception(
            'Reply is currently unavailable. Your message has not been sent. Please try again later.',
          );
        }
        if (features is! Map || features['replies'] != true) {
          throw Exception(
            'Reply is currently unavailable. Your message has not been sent. Please try again later.',
          );
        }
        _replySupportConfirmed = true;
      }
      await CommunityApi.instance.request(
        _path,
        method: 'POST',
        body: {
          'content': text,
          if (reply != null) 'replyToId': '${reply['_id']}',
          if (_direct) 'email': widget.recipientEmail,
          if (attachment != null) ...{
            'attachmentUrl': attachment['url'],
            'attachmentName': attachment['name'],
            'attachmentType': attachment['type'],
            if (attachment['thumbnail'] != null)
              'attachmentThumbnail': attachment['thumbnail'],
            for (final field in [
              'attachmentWidth',
              'attachmentHeight',
              'attachmentPreview',
            ])
              if (attachment[field] != null) field: attachment[field],
          },
        },
      );
      if (mounted) {
        if (_text.text.trim() == text) _text.clear();
        if (_attachmentDraft == attachment) _attachmentDraft = null;
        if (identical(_replyTo, reply)) _replyTo = null;
        await _load();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _uploadPicked(Map<String, dynamic> picked) async {
    setState(() => _uploadingAttachment = true);
    try {
      final uploaded = await CommunityApi.instance.uploadAttachment(picked);
      if (mounted) setState(() => _attachmentDraft = uploaded);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  Future<void> _pickCamera() async {
    if (_editingMessage != null) return;
    if (_uploadingAttachment || _sending) return;
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (file == null || !mounted) return;
      final extension = file.name.split('.').last.toLowerCase();
      const types = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
      };
      await _uploadPicked({
        'path': file.path,
        'name': file.name,
        'type': types[extension] ?? 'image/jpeg',
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    }
  }

  Future<void> _pickAttachment() async {
    if (_editingMessage != null) return;
    if (_uploadingAttachment || _sending) return;
    try {
      final picked = await _appLinks.invokeMapMethod<String, dynamic>(
        'pickChatAttachment',
      );
      if (picked == null || !mounted) return;
      await _uploadPicked(picked);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    }
  }

  void _insertEmoji(String emoji) {
    final selection = _text.selection;
    final start = selection.isValid ? selection.start : _text.text.length;
    final end = selection.isValid ? selection.end : start;
    final next = _text.text.replaceRange(start, end, emoji);
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _chooseEmoji() async {
    const emojis = [
      '😀',
      '😂',
      '😍',
      '🥳',
      '😎',
      '🤩',
      '😊',
      '😉',
      '👍',
      '👏',
      '🙌',
      '💪',
      '🙏',
      '❤️',
      '🔥',
      '⚽',
      '🏆',
      '🎉',
      '✅',
      '⭐',
      '💯',
      '🚀',
      '👋',
      '🤝',
    ];
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 6,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [
            for (final value in emojis)
              InkWell(
                onTap: () => Navigator.pop(context, value),
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Text(value, style: const TextStyle(fontSize: 27)),
                ),
              ),
          ],
        ),
      ),
    );
    if (emoji != null) _insertEmoji(emoji);
  }

  Future<void> _settings() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ChatSettingsScreen(
          kind: widget.kind,
          room: widget.kind == 'groups' ? _roomInfo : widget.room,
        ),
      ),
    );
    if (mounted && result != null) {
      if (result['deleted'] == true) {
        Navigator.of(context).pop(result);
      } else {
        setState(() {
          _permission = '${result['chatPermission'] ?? 'all'}';
          _roomInfo.addAll(result);
          if (widget.kind == 'groups') {
            _roomInfo['canInvite'] =
                _roomInfo['canManage'] == true ||
                result['allowMemberInvites'] == true;
          }
        });
      }
    }
  }

  Future<void> _refreshGroupInfo() async {
    if (widget.kind != 'groups' || widget.room == null) return;
    try {
      final data = await CommunityApi.instance.request(
        '/groups/${widget.room!['_id']}/info',
      );
      if (mounted && data is Map)
        setState(() {
          _roomInfo = Map<String, dynamic>.from(data);
          _permission = '${data['chatPermission'] ?? _permission}';
        });
    } catch (_) {
      /* Existing message history can still render while info retries. */
    }
  }

  Future<void> _openGroupInfo() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => GroupInfoScreen(groupId: '${widget.room!['_id']}'),
      ),
    );
    if (!mounted) return;
    if (result?['left'] == true || result?['deleted'] == true) {
      Navigator.pop(context, result);
      return;
    }
    await _refreshGroupInfo();
  }

  Future<void> _inviteMembers() async {
    if (widget.room == null) return;
    if (widget.kind == 'groups' &&
        _roomInfo['canManage'] != true &&
        _roomInfo['canInvite'] != true)
      return;
    await InviteMembersSheet.show(
      context,
      roomId: '${widget.room!['_id']}',
      roomTitle: widget.title,
      kind: widget.kind ?? 'groups',
    );
  }

  Widget? _attachment(Map<String, dynamic> message) {
    final sharedPostId = '${message['sharedPostId'] ?? ''}';
    if (sharedPostId.isNotEmpty) {
      return ChatPostPreview(
        key: ValueKey('shared-message-${message['_id']}'),
        postId: sharedPostId,
        preview: Map<String, dynamic>.from(message['sharedPost'] as Map? ?? {}),
      );
    }
    final raw = '${message['attachmentUrl'] ?? message['image'] ?? ''}';
    if (raw.isEmpty) return null;
    final url = raw.startsWith('/') ? '${OtpApi.apiBase}$raw' : raw;
    final type = '${message['attachmentType'] ?? ''}';
    final name = '${message['attachmentName'] ?? 'Attachment'}';
    final image =
        type.startsWith('image/') || (type.isEmpty && message['image'] != null);
    if (image) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ChatMediaImage(
            url: url,
            thumbnail: '${message['attachmentThumbnail'] ?? ''}',
            mediaWidth: (message['attachmentWidth'] as num?)?.toDouble(),
            mediaHeight: (message['attachmentHeight'] as num?)?.toDouble(),
            preview: '${message['attachmentPreview'] ?? ''}',
            openOnTap: true,
          ),
        ),
      );
    }
    if (type == 'group_invite' || type == 'group_added') {
      final groupName = name.isNotEmpty ? name : 'Group';
      final groupId = raw.replaceFirst('/groups/', '');
      final own = message['senderEmail'] == Session.email;
      return Container(
        constraints: const BoxConstraints(maxWidth: 240),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: own
              ? Colors.white.withValues(alpha: .9)
              : const Color(0xFFFFF1F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: authRed.withValues(alpha: .3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: authRed.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.group_add, color: authRed, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    type == 'group_added'
                        ? 'Added to group'
                        : 'Group invitation',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: authRed,
                      letterSpacing: .3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              groupName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            GroupInvitationActions(
              key: ValueKey('invite-actions-${message['_id']}'),
              groupId: groupId,
              groupName: groupName,
              sentByMe: own,
              wasAdded: type == 'group_added',
            ),
          ],
        ),
      );
    }
    return ChatFileAttachment(
      url: url,
      name: name,
      mime: type,
      thumbnail: '${message['attachmentThumbnail'] ?? ''}',
      mediaWidth: (message['attachmentWidth'] as num?)?.toDouble(),
      mediaHeight: (message['attachmentHeight'] as num?)?.toDouble(),
      preview: '${message['attachmentPreview'] ?? ''}',
    );
  }

  void _beginReply(Map<String, dynamic> message) {
    if (_editingMessage != null) return;
    if (!_canSend || message['_id'] == null) return;
    setState(() => _replyTo = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_replyTo, message) && _editingMessage == null) {
        _textFocus.requestFocus();
      }
    });
  }

  void _messageOptions(Map<String, dynamic> message) => _toggleMessage(message);

  Future<void> _jumpToOriginal(
    Map<String, dynamic> quote, {
    bool highlight = true,
  }) async {
    final id = '${quote['messageId'] ?? quote['_id'] ?? ''}';
    if (id.isEmpty) return;
    final navigation = ++_quoteNavigation;
    _textFocus.unfocus();
    bool current() => mounted && navigation == _quoteNavigation;
    bool hasMessage() =>
        _messages.any((message) => '${message['_id'] ?? message['id']}' == id);
    while (current() && !hasMessage() && _hasOlder) {
      final oldest = _messages.isEmpty ? null : _messages.first['_id'];
      await _loadOlder();
      if (!mounted || navigation != _quoteNavigation) return;
      if (_olderError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not load the original message.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _jumpToOriginal(quote),
            ),
          ),
        );
        return;
      }
      if (_messages.isEmpty || _messages.first['_id'] == oldest) break;
    }
    if (!mounted || navigation != _quoteNavigation) return;
    if (!hasMessage()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The original message is no longer available.'),
        ),
      );
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || navigation != _quoteNavigation || !_scroll.hasClients)
      return;
    // Messages are lazy and variable-height. Walk toward the target until its
    // row is built, then use its actual layout to center it precisely.
    for (
      var attempt = 0;
      current() && attempt < _messages.length + 4;
      attempt++
    ) {
      final anchor = _messageAnchors[id]?.currentContext;
      if (anchor != null && anchor.mounted) {
        await Scrollable.ensureVisible(
          anchor,
          alignment: .5,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        );
        if (!mounted || navigation != _quoteNavigation) return;
        _highlightTimer?.cancel();
        setState(() => _highlightedMessage = highlight ? id : null);
        if (highlight)
          _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
            if (mounted && _highlightedMessage == id) {
              setState(() => _highlightedMessage = null);
            }
          });
        return;
      }
      final targetIndex = _messages.indexWhere(
        (message) => '${message['_id'] ?? message['id']}' == id,
      );
      final builtIndices = <int>[
        for (var i = 0; i < _messages.length; i++)
          if (_messageAnchors['${_messages[i]['_id'] ?? _messages[i]['id']}']
                  ?.currentContext !=
              null)
            i,
      ];
      final towardOlder =
          builtIndices.isEmpty || targetIndex < builtIndices.first;
      final position = _scroll.position;
      final step = position.viewportDimension * .8;
      final next = (position.pixels + (towardOlder ? step : -step)).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((next - position.pixels).abs() < .5) break;
      _scroll.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Widget _replyGesture(Map<String, dynamic> message, Widget child) {
    final id = '${message['_id'] ?? message['id']}';
    return KeyedSubtree(
      key: _messageAnchors.putIfAbsent(id, () => GlobalKey()),
      child: AnimatedContainer(
        key: ValueKey('message-highlight-$id'),
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _selectedIds.contains(id) || _highlightedMessage == id
              ? const Color(0x33900F32)
              : _searching && _currentSearchId == id
              ? const Color(0x44F4C84B)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ChatReplyGesture(
          messageId: id,
          onTap: _selectedIds.isEmpty ? null : () => _toggleMessage(message),
          onReply:
              !_searching &&
                  _editingMessage == null &&
                  _selectedIds.isEmpty &&
                  _canSend &&
                  message['_id'] != null &&
                  message['deletedAt'] == null
              ? () => _beginReply(message)
              : null,
          onLongPress: () {
            if (_editingMessage != null) return;
            if (_searching) _closeChatSearch();
            _messageOptions(message);
          },
          child: AbsorbPointer(
            absorbing: _selectedIds.isNotEmpty || _editingMessage != null,
            child: Opacity(
              opacity:
                  _editingMessage != null && '${_editingMessage!['_id']}' != id
                  ? .35
                  : 1,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget? _attachmentsWithReply(Map<String, dynamic> message) {
    if (message['deletedAt'] != null) return null;
    final attachment = _attachment(message);
    final id = '${message['_id'] ?? message['id']}';
    final translated = _translations[id];
    final indicators =
        message['pinnedAt'] != null || message['forwarded'] == true;
    if (message['replyTo'] is! Map && translated == null && !indicators)
      return attachment;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (indicators)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message['forwarded'] == true)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text(
                      '↪ Forwarded',
                      style: TextStyle(color: authMuted, fontSize: 11),
                    ),
                  ),
                if (message['pinnedAt'] != null)
                  const Icon(
                    Icons.push_pin_rounded,
                    size: 13,
                    color: authMuted,
                  ),
              ],
            ),
          ),
        if (message['replyTo'] is Map)
          ChatReplyPreview(
            message: Map<String, dynamic>.from(message['replyTo'] as Map),
            onTap: () => _jumpToOriginal(
              Map<String, dynamic>.from(message['replyTo'] as Map),
            ),
          ),
        if (attachment != null) attachment,
        if (translated != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Translation',
                      style: TextStyle(color: authMuted, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      key: ValueKey('hide-translation-$id'),
                      onPressed: () => _hideTranslation(id),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Show original',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                Text(translated, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _messageBubble(Map<String, dynamic> message) {
    final own = message['senderEmail'] == Session.email;
    return _replyGesture(
      message,
      ChatMessageBubble(
        key: ValueKey('chat-message-${message['_id'] ?? message['id']}'),
        own: own,
        starred: message['starred'] == true && message['deletedAt'] == null,
        edited: message['editedAt'] != null && message['deletedAt'] == null,
        searchQuery: _searching ? _searchText.text.trim() : '',
        text: message['deletedAt'] != null
            ? 'This message was deleted'
            : '${message['content'] ?? ''}',
        author: !_direct && !own
            ? '${message['senderName'] ?? 'Highlander'}'
            : null,
        leading: _attachmentsWithReply(message),
        time: messageTimeLabel(message),
        status: _direct && own
            ? Icon(
                message['read'] == true || message['delivered'] == true
                    ? Icons.done_all
                    : Icons.done,
                key: ValueKey('message-status-${message['_id']}'),
                semanticLabel: message['read'] == true
                    ? 'Read'
                    : message['delivered'] == true
                    ? 'Delivered'
                    : 'Sent',
                size: 14,
                color: message['read'] == true
                    ? const Color(0xFF168BD2)
                    : const Color(0xFF83808A),
              )
            : null,
      ),
    );
  }

  PreferredSizeWidget _chatBar({
    required String image,
    required List<Widget> actions,
    String? subtitle,
  }) => _editingMessage != null
      ? _editAppBar()
      : _searching
      ? _searchAppBar()
      : _selectedIds.isNotEmpty
      ? _selectionBar()
      : ClubHeader(
          title: widget.title,
          trailingPadding: 4,
          showSearch: false,
          showSupport: false,
          showNotifications: false,
          titleWidget: InkWell(
            key: widget.kind == 'groups'
                ? const ValueKey('group-info-open')
                : null,
            onTap: widget.kind == 'groups' ? _openGroupInfo : null,
            child: Row(
              children: [
                UserAvatar(
                  email: widget.recipientEmail ?? '',
                  name: widget.title,
                  image: image,
                  radius: 16,
                  backgroundColor: const Color(0xFFFFF0EE),
                  foregroundColor: const Color(0xFF8C1E24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.kind == 'groups'
                            ? '${_roomInfo['name'] ?? widget.title}'
                            : widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .78),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          trailing: actions,
        );

  Widget _chatMenu({
    required String tooltip,
    required List<PopupMenuEntry<String>> items,
    required ValueChanged<String> onSelected,
  }) => AppPopupMenu<String>(
    tooltip: tooltip,
    onSelected: onSelected,
    itemBuilder: (context) => items,
    icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
  );

  AppMenuItem<String> _menuItem(
    String value,
    String label,
    IconData icon, {
    bool enabled = true,
    bool danger = false,
  }) => AppMenuItem<String>(
    value: value,
    label: label,
    icon: icon,
    enabled: enabled,
    danger: danger,
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIds.isEmpty && !_searching && _editingMessage == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _editingMessage != null) {
          if (!_savingEdit) _cancelInlineEdit();
        } else if (!didPop && _searching) {
          _closeChatSearch();
        } else if (!didPop && _selectedIds.isNotEmpty && !_actionBusy) {
          setState(() => _selectedIds.clear());
        }
      },
      child: _buildChat(context),
    );
  }

  Widget _buildChat(BuildContext context) {
    if (widget.isCare) {
      return HighlanderCareChat(
        appBarOverride: _editingMessage != null
            ? _editAppBar()
            : _searching
            ? _searchAppBar()
            : _selectedIds.isNotEmpty
            ? _selectionBar()
            : null,
        editing: _editingMessage != null,
        canSaveEdit: _canConfirmInlineEdit,
        composerNotice: _editingMessage != null ? _inlineEditNotice() : null,
        footerOverride: _searching ? _searchFooter() : null,
        searchQuery: _searching ? _searchText.text.trim() : '',
        menuItems: _commonChatItems,
        onMenuAction: _chatMenuAction,
        theme: '${_chatOptions['theme'] ?? 'default'}',
        notice:
            _chatOptions['pinned'] is Map ||
                (_chatOptions['disappearSeconds'] as num? ?? 0) > 0
            ? _conversationNotice()
            : null,
        messages: _messages,
        controller: _text,
        scrollController: _scroll,
        loading: _loading,
        busy: _editingMessage != null ? _savingEdit : _sending || _careBusy,
        uploading: _editingMessage == null && _uploadingAttachment,
        blocked: _careBlocked,
        blockedBy: _blockedBy,
        online: _careOnline,
        cleared: _careCleared,
        error: _loadError,
        onSend: _send,
        onAttach: _pickAttachment,
        onCamera: _pickCamera,
        onEmoji: _chooseEmoji,
        onClear: () => _careAction(clear: true),
        onBlock: () => _careAction(clear: false),
        onRefresh: _refreshCare,
        onKeyboardSettled: _revealEditedMessage,
        earlierMessages: _hasOlder
            ? EarlierMessagesButton(
                loading: _loadingOlder,
                error: _olderError,
                onPressed: _loadOlder,
              )
            : null,
        attachmentBuilder: _attachmentsWithReply,
        messageWrapper: _replyGesture,
        replyBanner: ChatComposerReply(
          message: _replyTo,
          onCancel: () => setState(() => _replyTo = null),
        ),
        focusNode: _textFocus,
        attachmentName: _attachmentDraft?['name']?.toString(),
        onRemoveAttachment: () => setState(() => _attachmentDraft = null),
      );
    }

    final isGroup = widget.kind == 'groups';
    final hasNotice =
        _chatOptions['pinned'] is Map ||
        (_chatOptions['disappearSeconds'] as num? ?? 0) > 0;
    final photo = widget.image.isNotEmpty
        ? widget.image
        : '${widget.room?['iconImage'] ?? widget.room?['profile_photo'] ?? widget.room?['profileImage'] ?? ''}';
    final PreferredSizeWidget appBar = _chatBar(
      image: photo,
      // subtitle: _direct
      //     ? 'Direct message'
      //     : isCircle
      //     ? 'Huddle'
      //     : isGroup
      //     ? 'Group'
      //     : null,
      actions: [
        if (isGroup) ...[
          _chatMenu(
            tooltip: 'Chat options',
            items: _commonChatItems,
            onSelected: _chatMenuAction,
          ),
          IconButton(
            tooltip: 'Group info',
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _openGroupInfo,
            icon: const Icon(Icons.info_outline, size: 22),
          ),
          if (_roomInfo['canManage'] == true || _roomInfo['canInvite'] == true)
            IconButton(
              tooltip: 'Add members',
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(
                Icons.person_add_alt_1,
                color: Colors.white,
                size: 22,
              ),
              onPressed: _inviteMembers,
            ),
          if (_roomInfo['canManage'] == true)
            IconButton(
              tooltip: 'Group settings',
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(
                Icons.settings_outlined,
                color: Colors.white,
                size: 22,
              ),
              onPressed: _settings,
            ),
        ] else if (_direct)
          _chatMenu(
            tooltip: 'Chat options',
            onSelected: (value) {
              if (value == 'block' || value == 'clear') {
                _careAction(clear: value == 'clear');
              } else {
                _chatMenuAction(value);
              }
            },
            items: [
              ..._commonChatItems,
              _menuItem(
                'block',
                _careBlocked ? 'Unblock' : 'Block',
                _careBlocked ? Icons.lock_open_rounded : Icons.block,
                enabled: !_careBusy,
                danger: !_careBlocked,
              ),
              _menuItem(
                'clear',
                'Clear chat',
                Icons.chat_bubble_outline,
                enabled: !_careBusy,
              ),
            ],
          )
        else
          _chatMenu(
            tooltip: 'Huddle options',
            onSelected: (value) {
              if (value == 'exit') _exitCircle();
              if (value == 'settings') _settings();
              if (value != 'exit' && value != 'settings')
                _chatMenuAction(value);
            },
            items: [
              ..._commonChatItems,
              _menuItem(
                'exit',
                'Leave huddle',
                Icons.logout_rounded,
                enabled: !_careBusy,
                danger: true,
              ),
              if (_roomInfo['canManage'] == true)
                _menuItem(
                  'settings',
                  'Huddle settings',
                  Icons.settings_outlined,
                ),
            ],
          ),
      ],
    );

    return ChatWallpaper(
      dimmed: _editingMessage != null,
      theme: '${_chatOptions['theme'] ?? 'default'}',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
        appBar: appBar,
        body: ChatKeyboardInset(
          onSettled: _revealEditedMessage,
          child: Column(
            children: [
              if (hasNotice)
                Padding(
                  padding: EdgeInsets.only(
                    top:
                        MediaQuery.paddingOf(context).top +
                        appBar.preferredSize.height,
                  ),
                  child: _conversationNotice(),
                ),
              if (_loadError != null)
                Padding(
                  padding: EdgeInsets.only(
                    top: hasNotice
                        ? 0
                        : MediaQuery.paddingOf(context).top +
                              appBar.preferredSize.height,
                  ),
                  child: MaterialBanner(
                    content: Text(_loadError!),
                    actions: [
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet.',
                          style: TextStyle(color: authMuted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        edgeOffset: hasNotice || _loadError != null
                            ? 0
                            : MediaQuery.paddingOf(context).top +
                                  appBar.preferredSize.height,
                        child: ListView.builder(
                          reverse: true,
                          controller: _scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            12,
                            _loadError == null && !hasNotice
                                ? MediaQuery.paddingOf(context).top +
                                      appBar.preferredSize.height +
                                      8
                                : 8,
                            12,
                            2,
                          ),
                          itemCount: _messages.length + (_hasOlder ? 1 : 0),
                          itemBuilder: (context, reverseIndex) {
                            if (reverseIndex == _messages.length) {
                              return EarlierMessagesButton(
                                loading: _loadingOlder,
                                error: _olderError,
                                onPressed: _loadOlder,
                              );
                            }
                            final index = _messages.length - 1 - reverseIndex;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (messageDate(_messages[index])
                                    case final date?)
                                  if (index == 0 ||
                                      !sameChatDay(
                                        date,
                                        messageDate(_messages[index - 1]),
                                      ))
                                    ChatDateChip(label: chatDateLabel(date)),
                                _messageBubble(_messages[index]),
                              ],
                            );
                          },
                        ),
                      ),
              ),
              if (_searching)
                _searchFooter()
              else
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: !_canSend && _editingMessage == null
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              _blockedBy
                                  ? '${widget.title} has blocked you.'
                                  : _careBlocked
                                  ? 'You blocked ${widget.title}. Use Unblock to message again.'
                                  : _permission == 'off'
                                  ? 'Chat is turned off.'
                                  : 'Only the admin / creator can send messages.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: authMuted),
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_editingMessage != null) _inlineEditNotice(),
                              ChatComposerReply(
                                message: _replyTo,
                                onCancel: () => setState(() => _replyTo = null),
                              ),
                              if (_attachmentDraft != null)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    7,
                                    4,
                                    7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.attach_file,
                                        size: 19,
                                        color: authRed,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${_attachmentDraft!['name']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        key: const ValueKey(
                                          'remove-chat-attachment',
                                        ),
                                        tooltip: 'Remove attachment',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => setState(
                                          () => _attachmentDraft = null,
                                        ),
                                        icon: const Icon(Icons.close, size: 18),
                                      ),
                                    ],
                                  ),
                                ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(26),
                                      ),
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            key: const ValueKey('chat-emoji'),
                                            tooltip: 'Add emoji',
                                            onPressed: _sending || _savingEdit
                                                ? null
                                                : _chooseEmoji,
                                            constraints:
                                                const BoxConstraints.tightFor(
                                                  width: 40,
                                                  height: 44,
                                                ),
                                            icon: const Icon(
                                              Icons
                                                  .sentiment_satisfied_alt_outlined,
                                              color: authRed,
                                            ),
                                          ),
                                          Expanded(
                                            child: TextField(
                                              controller: _text,
                                              enabled: !_savingEdit,
                                              key: const ValueKey(
                                                'chat-message-input',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                height: 1.3,
                                                color: Color(0xFF242127),
                                              ),
                                              focusNode: _textFocus,
                                              maxLength: 10000,
                                              minLines: 1,
                                              maxLines: 4,
                                              decoration: const InputDecoration(
                                                hintText: 'Message',
                                                counterText: '',
                                                filled: false,
                                                fillColor: Colors.white,
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 12,
                                                    ),
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                              ),
                                              onSubmitted: (_) => _send(),
                                            ),
                                          ),
                                          if (_editingMessage == null)
                                            IconButton(
                                              key: const ValueKey(
                                                'chat-attachment',
                                              ),
                                              tooltip: 'Attach file',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed:
                                                  _sending ||
                                                      _uploadingAttachment
                                                  ? null
                                                  : _pickAttachment,
                                              constraints:
                                                  const BoxConstraints.tightFor(
                                                    width: 36,
                                                    height: 44,
                                                  ),
                                              icon: _uploadingAttachment
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons.attach_file_rounded,
                                                      color: authRed,
                                                    ),
                                            ),
                                          if (_editingMessage == null)
                                            IconButton(
                                              key: const ValueKey(
                                                'chat-camera',
                                              ),
                                              tooltip: 'Open camera',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed:
                                                  _sending ||
                                                      _uploadingAttachment
                                                  ? null
                                                  : _pickCamera,
                                              constraints:
                                                  const BoxConstraints.tightFor(
                                                    width: 36,
                                                    height: 44,
                                                  ),
                                              padding: const EdgeInsets.only(
                                                right: 4,
                                              ),
                                              icon: const Icon(
                                                Icons.photo_camera_outlined,
                                                color: authRed,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Padding(
                                    padding: EdgeInsets.zero,
                                    child: ValueListenableBuilder<TextEditingValue>(
                                      valueListenable: _text,
                                      builder: (context, value, child) =>
                                          IconButton.filled(
                                            tooltip: _editingMessage != null
                                                ? 'Save edit'
                                                : 'Send message',
                                            style: IconButton.styleFrom(
                                              backgroundColor: authRed,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor: authRed,
                                              disabledForegroundColor:
                                                  Colors.white70,
                                              minimumSize: const Size(48, 48),
                                              maximumSize: const Size(48, 48),
                                              padding: EdgeInsets.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            onPressed: _editingMessage != null
                                                ? (_canSaveInlineEdit
                                                      ? _saveInlineEdit
                                                      : null)
                                                : (_sending ||
                                                          _uploadingAttachment
                                                      ? null
                                                      : _send),
                                            icon:
                                                (_editingMessage != null
                                                    ? _savingEdit
                                                    : _sending)
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : Icon(
                                                    _editingMessage != null
                                                        ? Icons.check_rounded
                                                        : Icons.send,
                                                    color: Colors.white,
                                                  ),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
