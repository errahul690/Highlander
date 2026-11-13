import 'app_popup_menu.dart';
import '../brand_colors.dart';

import 'package:flutter/material.dart';

import 'club_header.dart';

import '../chat_dates.dart';
import '../session.dart';
import '../support_hub_repository.dart';
import 'care_verified_badge.dart';
import 'chat_wallpaper.dart';
import 'chat_message_bubble.dart';
import 'support_hub_avatar.dart';

const careRed = brandAccent;

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
    this.earlierMessages,
    this.replyBanner,
    this.messageWrapper,
    this.focusNode,
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
  final Widget? earlierMessages, replyBanner;
  final Widget Function(Map<String, dynamic>, Widget)? messageWrapper;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SupportHubRepository.instance,
    builder: (context, _) => _view(context, SupportHubRepository.instance.name),
  );

  Widget _view(BuildContext context, String name) => ChatWallpaper(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: ClubHeader(
        title: name,
        showSearch: false,
        showSupport: false,
        showNotifications: false,
        trailing: [
          AppPopupMenu<String>(
            key: const ValueKey('support-chat-menu'),
            tooltip: 'Chat options',
            enabled: !busy && !uploading && !loading,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (_) => onClear(),
            itemBuilder: (_) => [
              AppMenuItem<String>(
                value: 'clear',
                label: 'Clear chat',
                icon: Icons.delete_outline,
                danger: true,
              ),
            ],
          ),
        ],
        titleWidget: Row(
          children: [
            const SupportHubAvatar(radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
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
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (error != null)
            Padding(
              padding: EdgeInsets.only(
                top:
                    MediaQuery.paddingOf(context).top +
                    const ClubHeader(title: '').preferredSize.height,
              ),
              child: MaterialBanner(
                content: Text(error!),
                actions: [
                  TextButton(onPressed: onRefresh, child: const Text('Retry')),
                ],
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: careRed))
                : RefreshIndicator(
                    color: careRed,
                    onRefresh: onRefresh,
                    edgeOffset:
                        MediaQuery.paddingOf(context).top +
                        const ClubHeader(title: '').preferredSize.height,
                    child: ListView.builder(
                      reverse: messages.isNotEmpty,
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        error == null
                            ? MediaQuery.paddingOf(context).top +
                                  const ClubHeader(title: '')
                                      .preferredSize
                                      .height +
                                  12
                            : 12,
                        16,
                        2,
                      ),
                      itemCount: messages.isEmpty
                          ? 1
                          : messages.length + (earlierMessages != null ? 1 : 0),
                      itemBuilder: (context, reverseIndex) {
                        if (messages.isNotEmpty &&
                            reverseIndex == messages.length) {
                          return earlierMessages!;
                        }
                        if (messages.isEmpty) {
                          if (cleared || error != null)
                            return const SizedBox.shrink();
                          return CareMessageBubble(
                            own: false,
                            child: Text(
                              'Hi ${Session.name.trim().isEmpty ? 'Highlander' : Session.name.trim().split(RegExp(r'\s+')).first}! \u{1F44B}\nWelcome to $name. How can we help you today?',
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
                                ChatDateChip(label: chatDateLabel(date)),
                            _message(messages[index]),
                          ],
                        );
                      },
                    ),
                  ),
          ),
          _composer(context, name),
        ],
      ),
    ),
  );

  Widget _message(Map<String, dynamic> message) {
    final bubble = _messageBubble(message);
    return messageWrapper?.call(message, bubble) ?? bubble;
  }

  Widget _messageBubble(Map<String, dynamic> message) => CareMessageBubble(
    key: ValueKey('chat-message-${message['_id'] ?? message['id']}'),
    own: message['senderEmail'] == Session.email,
    time: messageTimeLabel(message),
    text: '${message['content'] ?? ''}',
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
      ],
    ),
  );

  Widget _composer(BuildContext context, String name) => SafeArea(
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
                          ? '$name has blocked you.'
                          : 'You blocked $name.',
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
                if (replyBanner != null) replyBanner!,
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
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
                                Icons.sentiment_satisfied_alt_outlined,
                                color: careRed,
                                size: 23,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                enabled: !busy,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: 10000,
                                textAlignVertical: TextAlignVertical.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.3,
                                  color: Color(0xFF242127),
                                ),
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
                                onSubmitted: (_) => onSend(),
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('chat-attachment'),
                              tooltip: 'Attach file',
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
                                      Icons.attach_file_rounded,
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
                      padding: EdgeInsets.zero,
                      child: IconButton(
                        tooltip: 'Send message',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
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
    this.text = '',
    this.time = '',
    this.status,
  });
  final bool own;
  final Widget child;
  final String text, time;
  final Widget? status;

  @override
  Widget build(BuildContext context) => ChatMessageBubble(
    own: own,
    text: text,
    leading: child,
    time: time,
    status: status,
  );
}
