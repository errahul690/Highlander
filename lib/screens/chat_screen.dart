import '../widgets/club_page_body.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../community_api.dart';
import '../chat_updates.dart';
import '../otp_api.dart';
import '../session.dart';
import '../support_hub_repository.dart';
import '../chat_dates.dart';
import '../theme.dart';
import '../widgets/chat_wallpaper.dart';
import '../widgets/highlander_care_chat.dart';
import '../widgets/user_avatar.dart';
import '../widgets/invite_members_sheet.dart';
import 'chat_settings_screen.dart';

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
  static const _appLinks = MethodChannel('highlanders/app_links');
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _attachmentDraft;
  bool _loading = true, _sending = false, _uploadingAttachment = false;
  String? _loadError;
  late String _permission;
  io.Socket? _socket;
  int _loadVersion = 0;
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
              (_permission != 'admins' || widget.room?['canManage'] == true)));
  String get _path => _direct
      ? '/direct/messages'
      : '/${widget.kind}/${widget.room!['_id']}/messages';
  @override
  void initState() {
    super.initState();
    _permission = '${widget.room?['chatPermission'] ?? 'all'}';
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socket?.dispose();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    try {
      final rows = await CommunityApi.instance.list(
        '$_path${_direct ? '?email=${Uri.encodeComponent(widget.recipientEmail!)}' : ''}',
      );
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
        _messages = rows;
        _loading = false;
        _loadError = null;
      });
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
          _loadError = '$error'.replaceFirst('Exception: ', '');
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
      if (mounted)
        setState(() => _loadError = '$error'.replaceFirst('Exception: ', ''));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
        );
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
          _careCleared = true;
        } else {
          _careBlocked = result['blocked'] == true;
          _blockedBy = result['blockedBy'] == true;
        }
      });
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
        );
    } finally {
      if (mounted) setState(() => _careBusy = false);
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    final attachment = _attachmentDraft;
    if ((text.isEmpty && attachment == null) ||
        _sending ||
        _uploadingAttachment ||
        !_canSend) {
      return;
    }
    setState(() => _sending = true);
    try {
      await CommunityApi.instance.request(
        _path,
        method: 'POST',
        body: {
          'content': text,
          if (_direct) 'email': widget.recipientEmail,
          if (attachment != null) ...{
            'attachmentUrl': attachment['url'],
            'attachmentName': attachment['name'],
            'attachmentType': attachment['type'],
          },
        },
      );
      if (mounted) {
        if (_text.text.trim() == text) _text.clear();
        if (_attachmentDraft == attachment) _attachmentDraft = null;
        await _load();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  Future<void> _pickCamera() async {
    if (_uploadingAttachment || _sending) return;
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _pickAttachment() async {
    if (_uploadingAttachment || _sending) return;
    try {
      final picked = await _appLinks.invokeMapMethod<String, dynamic>(
        'pickChatAttachment',
      );
      if (picked == null || !mounted) return;
      await _uploadPicked(picked);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
        );
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
        builder: (_) =>
            ChatSettingsScreen(kind: widget.kind, room: widget.room),
      ),
    );
    if (mounted && result != null) {
      if (result['deleted'] == true) {
        Navigator.of(context).pop(result);
      } else {
        setState(() => _permission = '${result['chatPermission'] ?? 'all'}');
      }
    }
  }

  Future<void> _inviteMembers() async {
    if (widget.room == null) return;
    await InviteMembersSheet.show(
      context,
      roomId: '${widget.room!['_id']}',
      roomTitle: widget.title,
      kind: widget.kind ?? 'groups',
    );
  }

  Widget? _attachment(Map<String, dynamic> message) {
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
          child: Image.network(
            url,
            width: 230,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(
              width: 230,
              height: 90,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      );
    }
    if (type == 'group_invite') {
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
                const Expanded(
                  child: Text(
                    'Group Invitation',
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
            SizedBox(
              width: double.infinity,
              height: 34,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: authRed,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        title: groupName,
                        kind: 'groups',
                        room: {
                          '_id': groupId,
                          'name': groupName,
                          'membership': 'active',
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: const Text(
                  'Open Group',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        onTap: () => _appLinks.invokeMethod('openUrl', {'url': url}),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 230),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .65),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.attach_file, size: 19, color: authRed),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> message) {
    final own = message['senderEmail'] == Session.email;
    final time = messageTimeLabel(message);
    return Align(
      key: ValueKey('chat-message-${message['_id'] ?? message['id']}'),
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .8,
        ),
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: own ? const Color(0xFFFFE6E2) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: own
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!_direct)
              Text(
                '${message['senderName'] ?? 'Highlander'}',
                style: const TextStyle(
                  color: authRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            if (_attachment(message) case final attachment?) attachment,
            if ('${message['content'] ?? ''}'.isNotEmpty)
              Text(
                '${message['content']}',
                style: const TextStyle(fontSize: 16, height: 1.35),
              ),
            if (time.isNotEmpty || (_direct && own)) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: authMuted,
                      ),
                    ),
                  if (time.isNotEmpty && _direct && own)
                    const SizedBox(width: 4),
                  if (_direct && own)
                    Icon(
                      message['read'] == true || message['delivered'] == true
                          ? Icons.done_all
                          : Icons.done,
                      key: ValueKey('message-status-${message['_id']}'),
                      semanticLabel: message['read'] == true
                          ? 'Read'
                          : message['delivered'] == true
                          ? 'Delivered'
                          : 'Sent',
                      size: 17,
                      color: message['read'] == true
                          ? const Color(0xFF168BD2)
                          : authMuted,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _chatBar({
    required String image,
    required List<Widget> actions,
    String? subtitle,
  }) => AppBar(
    toolbarHeight: 64,
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: const Color(0xFF991C24),
    foregroundColor: Colors.white,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    titleSpacing: 0,
    leadingWidth: 42,
    flexibleSpace: const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF831B20), Color(0xFFB52626), Color(0xFF991C24)],
          stops: [0, .55, 1],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    ),
    leading: IconButton(
      tooltip: 'Back',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
      onPressed: () => Navigator.of(context).maybePop(),
    ),
    title: Row(
      children: [
        UserAvatar(
          email: widget.recipientEmail ?? '',
          name: widget.title,
          image: image,
          radius: 18,
          backgroundColor: const Color(0xFFFFF0EE),
          foregroundColor: const Color(0xFF8C1E24),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
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
    actions: actions,
  );

  Widget _chatMenu({
    required String tooltip,
    required List<PopupMenuEntry<String>> items,
    required ValueChanged<String> onSelected,
  }) => PopupMenuButton<String>(
    tooltip: tooltip,
    offset: const Offset(0, 48),
    color: Colors.white,
    elevation: 10,
    shadowColor: const Color(0x33000000),
    surfaceTintColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    onSelected: onSelected,
    itemBuilder: (context) => items,
    icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
  );

  PopupMenuItem<String> _menuItem(
    String value,
    String label,
    IconData icon, {
    bool enabled = true,
    bool danger = false,
  }) => PopupMenuItem<String>(
    value: value,
    enabled: enabled,
    height: 46,
    child: Row(
      children: [
        Icon(icon, size: 18, color: danger ? authRed : clubInk),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: danger ? authRed : clubInk,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.isCare) {
      return HighlanderCareChat(
        messages: _messages,
        controller: _text,
        scrollController: _scroll,
        loading: _loading,
        busy: _sending || _careBusy,
        uploading: _uploadingAttachment,
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
        attachmentBuilder: _attachment,
        attachmentName: _attachmentDraft?['name']?.toString(),
        onRemoveAttachment: () => setState(() => _attachmentDraft = null),
      );
    }

    final isGroup = widget.kind == 'groups';
    final isCircle = widget.kind == 'circles';
    final photo = widget.image.isNotEmpty
        ? widget.image
        : '${widget.room?['iconImage'] ?? widget.room?['profile_photo'] ?? widget.room?['profileImage'] ?? ''}';
    final PreferredSizeWidget appBar = _chatBar(
      image: photo,
      subtitle: _direct
          ? 'Direct message'
          : isCircle
          ? 'Huddle'
          : isGroup
          ? 'Group'
          : null,
      actions: [
        if (isGroup) ...[
          IconButton(
            tooltip: 'Invite members',
            icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 22),
            onPressed: _inviteMembers,
          ),
          if (widget.room?['canManage'] == true)
            IconButton(
              tooltip: 'Group settings',
              icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
              onPressed: _settings,
            ),
        ] else if (_direct)
          _chatMenu(
            tooltip: 'Chat options',
            onSelected: (value) => _careAction(clear: value == 'clear'),
            items: [
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
            },
            items: [
              _menuItem(
                'exit',
                'Leave huddle',
                Icons.logout_rounded,
                enabled: !_careBusy,
                danger: true,
              ),
              if (widget.room?['canManage'] == true)
                _menuItem('settings', 'Huddle settings', Icons.settings_outlined),
            ],
          ),
        const SizedBox(width: 6),
      ],
    );

    return ClubScaffold(
      backgroundColor: clubCloud,
      appBar: appBar,
      body: ChatWallpaper(
        child: Column(
          children: [
            if (_loadError != null)
              MaterialBanner(
                content: Text(_loadError!),
                actions: [
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
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
                      child: ListView.builder(
                        reverse: true,
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                        itemCount: _messages.length,
                        itemBuilder: (context, reverseIndex) {
                          final index = _messages.length - 1 - reverseIndex;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (messageDate(_messages[index]) case final date?)
                                if (index == 0 ||
                                    !sameChatDay(
                                      date,
                                      messageDate(_messages[index - 1]),
                                    ))
                                  Center(
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                        top: 8,
                                        bottom: 16,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: clubLine),
                                      ),
                                      child: Text(
                                        chatDateLabel(date),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: authMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                              _messageBubble(_messages[index]),
                            ],
                          );
                        },
                      ),
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: !_canSend
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
                          if (_attachmentDraft != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
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
                            crossAxisAlignment: CrossAxisAlignment.end,
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
                                        onPressed: _sending
                                            ? null
                                            : _chooseEmoji,
                                        constraints: const BoxConstraints.tightFor(
                                          width: 40,
                                          height: 44,
                                        ),
                                        icon: const Icon(
                                          Icons.sentiment_satisfied_alt_outlined,
                                          color: authRed,
                                        ),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: _text,
                                          maxLength: 10000,
                                          minLines: 1,
                                          maxLines: 4,
                                          decoration: const InputDecoration(
                                            hintText: 'Message',
                                            counterText: '',
                                            filled: true,
                                            fillColor: Colors.white,
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(
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
                                      IconButton(
                                        key: const ValueKey('chat-attachment'),
                                        tooltip: 'Upload file',
                                        visualDensity: VisualDensity.compact,
                                        onPressed:
                                            _sending || _uploadingAttachment
                                            ? null
                                            : _pickAttachment,
                                        constraints: const BoxConstraints.tightFor(
                                          width: 36,
                                          height: 44,
                                        ),
                                        icon: _uploadingAttachment
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.upload_file_outlined,
                                                color: authRed,
                                              ),
                                      ),
                                      IconButton(
                                        key: const ValueKey('chat-camera'),
                                        tooltip: 'Open camera',
                                        visualDensity: VisualDensity.compact,
                                        onPressed:
                                            _sending || _uploadingAttachment
                                            ? null
                                            : _pickCamera,
                                        constraints: const BoxConstraints.tightFor(
                                          width: 36,
                                          height: 44,
                                        ),
                                        padding: const EdgeInsets.only(right: 4),
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
                                padding: const EdgeInsets.only(bottom: 2),
                                child: IconButton.filled(
                                  tooltip: 'Send message',
                                  style: IconButton.styleFrom(
                                    backgroundColor: authRed,
                                    minimumSize: const Size(46, 46),
                                  ),
                                  onPressed: _sending || _uploadingAttachment
                                      ? null
                                      : _send,
                                  icon: _sending
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.send),
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
    );
  }
}
