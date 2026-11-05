import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_dates.dart';
import '../session.dart';
import 'care_verified_badge.dart';
import 'chat_wallpaper.dart';

const careRed = Color(0xFFC92922);
const _background = Color(0xFFFFFAFA);

class HighlanderCareChat extends StatelessWidget {
  const HighlanderCareChat({
    super.key,
    required this.messages,
    required this.controller,
    required this.scrollController,
    required this.loading,
    required this.busy,
    required this.uploading,
    required this.blocked,
    this.blockedBy = false,
    required this.online,
    required this.cleared,
    required this.onSend,
    required this.onAttach,
    required this.onCamera,
    required this.onEmoji,
    required this.onClear,
    required this.onBlock,
    required this.onRefresh,
    required this.attachmentBuilder,
    required this.onRemoveAttachment,
    this.attachmentName,
    this.error,
  });

  final List<Map<String, dynamic>> messages;
  final TextEditingController controller;
  final ScrollController scrollController;
  final bool loading, busy, uploading, blocked, online, cleared;
  final bool blockedBy;
  final VoidCallback onSend, onAttach, onCamera, onEmoji, onClear, onBlock;
  final VoidCallback onRemoveAttachment;
  final Future<void> Function() onRefresh;
  final Widget? Function(Map<String, dynamic>) attachmentBuilder;
  final String? attachmentName, error;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      toolbarHeight: 72,
      titleSpacing: 0,
      foregroundColor: Colors.white,
      backgroundColor: const Color(0xFFA32118),
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: Colors.black26,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: BackButton(onPressed: () => Navigator.maybePop(context)),
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF932017), Color(0xFFBB2920), Color(0xFF941E17)],
          ),
        ),
      ),
      title: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF8B48B2),
            child: Text(
              '\u{1F431}',
              style: TextStyle(
                fontSize: 23,
                fontFamilyFallback: ['Segoe UI Emoji'],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Highlander Care',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    CareVerifiedBadge(),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 6,
                      color: blocked || blockedBy
                          ? Colors.white54
                          : online
                          ? const Color(0xFF86E854)
                          : Colors.white54,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      blockedBy
                          ? 'Messaging unavailable'
                          : blocked
                          ? 'Blocked'
                          : online
                          ? 'Online'
                          : 'Offline',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Chat options',
          enabled: !busy,
          icon: const Icon(Icons.more_vert),
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          position: PopupMenuPosition.under,
          onSelected: (action) => action == 'clear' ? onClear() : onBlock(),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.black87, size: 21),
                  SizedBox(width: 10),
                  Text('Clear Chat'),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  const Icon(Icons.block, color: Colors.black87, size: 21),
                  const SizedBox(width: 10),
                  Text(blocked ? 'Unblock' : 'Block'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 6),
      ],
    ),
    body: ChatWallpaper(
      child: Column(
      children: [
        if (error != null)
          MaterialBanner(
            content: Text(error!),
            actions: [
              TextButton(onPressed: onRefresh, child: const Text('Retry')),
            ],
          ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: careRed))
              : RefreshIndicator(
                  color: careRed,
                  onRefresh: onRefresh,
                  child: ListView.builder(
                    reverse: messages.isNotEmpty,
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                    itemCount: messages.isEmpty ? 1 : messages.length,
                    itemBuilder: (context, reverseIndex) {
                      if (messages.isEmpty) {
                        if (cleared || error != null)
                          return const SizedBox.shrink();
                        return CareMessageBubble(
                          own: false,
                          child: Text(
                            'Hi ${Session.name.trim().isEmpty ? 'Highlander' : Session.name.trim().split(RegExp(r'\s+')).first}! \u{1F44B}\nWelcome to Highlander Care. How can we help you today?',
                          ),
                        );
                      }
                      final index = messages.length - 1 - reverseIndex;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (messageDate(messages[index]) case final date?)
                            if (index == 0 ||
                                !sameChatDay(
                                  date,
                                  messageDate(messages[index - 1]),
                                ))
                              Center(
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    bottom: 18,
                                    top: 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    chatDateLabel(date),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF777777),
                                    ),
                                  ),
                                ),
                              ),
                          _message(messages[index]),
                        ],
                      );
                    },
                  ),
                ),
        ),
        _composer(context),
      ],
    ),
  ),
);

  Widget _message(Map<String, dynamic> message) => CareMessageBubble(
    key: ValueKey('chat-message-${message['_id'] ?? message['id']}'),
    own: message['senderEmail'] == Session.email,
    time: messageTimeLabel(message),
    status: message['senderEmail'] != Session.email
        ? null
        : Icon(
            message['read'] == true || message['delivered'] == true
                ? Icons.done_all
                : Icons.done,
            key: ValueKey('message-status-${message['_id']}'),
            semanticLabel: message['read'] == true
                ? 'Read'
                : message['delivered'] == true
                ? 'Delivered'
                : 'Sent',
            size: 13,
            color: message['read'] == true
                ? const Color(0xFF168BD2)
                : const Color(0xFF818181),
          ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (attachmentBuilder(message) case final attachment?) attachment,
        if ('${message['content'] ?? ''}'.isNotEmpty)
          Text('${message['content']}'),
      ],
    ),
  );

  Widget _composer(BuildContext context) => SafeArea(
    key: const ValueKey('care-composer'),
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: blocked || blockedBy
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      blockedBy
                          ? 'Highlander Care has blocked you.'
                          : 'You blocked Highlander Care.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF737373),
                      ),
                    ),
                  ),
                  if (blocked)
                    TextButton(
                      onPressed: busy ? null : onBlock,
                      child: const Text(
                        'Unblock',
                        style: TextStyle(color: careRed),
                      ),
                    ),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (attachmentName != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file, color: careRed, size: 18),
                        Expanded(
                          child: Text(
                            attachmentName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove attachment',
                          onPressed: busy ? null : onRemoveAttachment,
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
                        child: Row(
                          children: [
                            IconButton(
                              key: const ValueKey('chat-emoji'),
                              tooltip: 'Add emoji',
                              onPressed: busy ? null : onEmoji,
                              constraints: const BoxConstraints.tightFor(
                                width: 40,
                                height: 44,
                              ),
                              icon: const Icon(
                                Icons.emoji_emotions,
                                color: careRed,
                                size: 23,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: controller,
                                enabled: !busy,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: 10000,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF282828),
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Type a message...',
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 12,
                                  ),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) => onSend(),
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('chat-attachment'),
                              tooltip: 'Upload file',
                              onPressed: busy || uploading ? null : onAttach,
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 44,
                              ),
                              padding: EdgeInsets.zero,
                              icon: uploading
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: careRed,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.upload_file_outlined,
                                      size: 23,
                                      color: careRed,
                                    ),
                            ),
                            IconButton(
                              key: const ValueKey('chat-camera'),
                              tooltip: 'Open camera',
                              onPressed: busy || uploading ? null : onCamera,
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 44,
                              ),
                              padding: const EdgeInsets.only(right: 4),
                              icon: const Icon(
                                Icons.photo_camera_outlined,
                                size: 23,
                                color: careRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: IconButton(
                        tooltip: 'Send message',
                        onPressed: busy || uploading || loading ? null : onSend,
                        icon: CircleAvatar(
                          radius: 22,
                          backgroundColor: careRed,
                          child: busy
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    ),
  );
}

class CareMessageBubble extends StatelessWidget {
  const CareMessageBubble({
    super.key,
    required this.own,
    required this.child,
    this.time = '',
    this.status,
  });
  final bool own;
  final Widget child;
  final String time;
  final Widget? status;

  @override
  Widget build(BuildContext context) => Align(
    alignment: own ? Alignment.centerRight : Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: PhysicalShape(
        clipper: _BubbleClipper(own),
        color: own ? const Color(0xFFECF4FF) : const Color(0xFFF9E5E6),
        elevation: 1,
        shadowColor: const Color(0x26000000),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .74,
          ),
          padding: EdgeInsets.fromLTRB(own ? 14 : 23, 10, own ? 23 : 9, 5),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'SwoofiSans',
              fontFamilyFallback: ['Segoe UI Emoji'],
              fontSize: 16,
              height: 1.45,
              color: Color(0xFF161616),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                child,
                if (time.isNotEmpty || status != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.1,
                            color: Color(0xFF777777),
                          ),
                        ),
                      if (status != null) ...[
                        const SizedBox(width: 3),
                        status!,
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _BubbleClipper extends CustomClipper<Path> {
  const _BubbleClipper(this.own);
  final bool own;
  @override
  Path getClip(Size size) {
    final left = own ? 0.0 : 13.0;
    final right = size.width - (own ? 13 : 0);
    final body = Path()
      ..addRRect(
        RRect.fromLTRBR(left, 0, right, size.height, const Radius.circular(11)),
      );
    final tail = Path()
      ..moveTo(own ? right - 10 : left + 10, 0)
      ..lineTo(own ? size.width : 0, 0)
      ..lineTo(own ? right - 1 : left + 1, 15)
      ..close();
    return Path.combine(PathOperation.union, body, tail);
  }

  @override
  bool shouldReclip(_BubbleClipper oldClipper) => own != oldClipper.own;
}
