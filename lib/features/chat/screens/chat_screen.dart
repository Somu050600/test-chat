import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/native_notification_service.dart';
import '../../../models/message_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/notification_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  /// After opening from a notification, scroll to the oldest unread bubble once.
  final bool scrollToOldestUnread;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.scrollToOldestUnread = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _oldestUnreadAnchorKey = GlobalKey();

  bool _markedAsRead = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _didUnreadAnchorScroll = false;
  final List<MessageModel> _olderMessages = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    NativeNotificationService.cancelConversationNotifications(
      widget.conversationId,
    );
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _olderMessages.clear();
      _hasMore = true;
      _didUnreadAnchorScroll = false;
      _markedAsRead = false;
    }
    if (oldWidget.scrollToOldestUnread != widget.scrollToOldestUnread &&
        widget.scrollToOldestUnread) {
      _didUnreadAnchorScroll = false;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final messages = ref.read(messagesProvider(widget.conversationId)).value;
    if (messages == null || messages.isEmpty) return;

    final allMessages = [...messages, ..._olderMessages];
    final lastMsg = allMessages.last;

    setState(() => _isLoadingMore = true);

    try {
      final chatService = ref.read(chatServiceProvider);
      final doc = await chatService.getMessageDocument(
          widget.conversationId, lastMsg.id);
      if (doc == null) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      final older = await chatService.loadMoreMessages(
        widget.conversationId,
        lastDocument: doc,
      );

      setState(() {
        _olderMessages.addAll(older);
        _hasMore = older.length >= 30;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _markAsRead() {
    if (_markedAsRead) return;
    _markedAsRead = true;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref
        .read(chatServiceProvider)
        .markMessagesAsRead(widget.conversationId, user.uid);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToOldestUnreadAnchor() {
    final ctx = _oldestUnreadAnchorKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.85,
      );
    }
    if (mounted) {
      setState(() => _didUnreadAnchorScroll = true);
    }
  }

  /// In reverse ListView, index 0 = newest. Oldest unread = last index in list
  /// where message is from other and not read.
  int? _findOldestUnreadIndex(
    List<MessageModel> allMessages,
    String? uid,
  ) {
    if (uid == null) return null;
    for (var i = allMessages.length - 1; i >= 0; i--) {
      final m = allMessages[i];
      if (m.senderId != uid && m.status != MessageStatus.read) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (recentMessages) {
                final allMessages = [...recentMessages, ..._olderMessages];
                if (allMessages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet.\nSend the first one!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  );
                }

                final hasUnread = recentMessages.any(
                  (m) =>
                      m.senderId != currentUser?.uid &&
                      m.status != MessageStatus.read,
                );
                if (hasUnread) {
                  _markedAsRead = false;
                  SchedulerBinding.instance
                      .addPostFrameCallback((_) => _markAsRead());
                } else if (!_markedAsRead) {
                  SchedulerBinding.instance
                      .addPostFrameCallback((_) => _markAsRead());
                }

                final oldestUnreadIdx =
                    _findOldestUnreadIndex(allMessages, currentUser?.uid);
                final shouldAnchorUnread = widget.scrollToOldestUnread &&
                    oldestUnreadIdx != null &&
                    !_didUnreadAnchorScroll;

                if (shouldAnchorUnread) {
                  SchedulerBinding.instance
                      .addPostFrameCallback((_) => _scrollToOldestUnreadAnchor());
                } else if (!widget.scrollToOldestUnread || oldestUnreadIdx == null) {
                  SchedulerBinding.instance
                      .addPostFrameCallback((_) => _scrollToBottom());
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: allMessages.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == allMessages.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final message = allMessages[index];
                    final isMe = message.senderId == currentUser?.uid;
                    final useAnchor = shouldAnchorUnread &&
                        index == oldestUnreadIdx;
                    Widget bubble = MessageBubble(
                      message: message,
                      isMe: isMe,
                    );
                    if (useAnchor) {
                      bubble = KeyedSubtree(
                        key: _oldestUnreadAnchorKey,
                        child: bubble,
                      );
                    }
                    return bubble;
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          MessageInput(
            onSend: (text) async {
              if (currentUser == null) return;
              final messageId = await ref.read(chatServiceProvider).sendMessage(
                    conversationId: widget.conversationId,
                    senderId: currentUser.uid,
                    text: text,
                  );
              ref.read(pushNotificationApiProvider).sendNotification(
                    conversationId: widget.conversationId,
                    messageId: messageId,
                  );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    final currentUser = ref.watch(currentUserProvider);
    final convosAsync = ref.watch(conversationsProvider);

    return convosAsync.when(
      data: (convos) {
        final convo = convos.where((c) => c.id == widget.conversationId);
        if (convo.isEmpty) return const Text('Chat');
        final otherUid = convo.first.otherMember(currentUser?.uid ?? '');
        final userAsync = ref.watch(userStreamProvider(otherUid));
        return userAsync.when(
          data: (user) {
            if (user == null) return const Text('Chat');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: const TextStyle(fontSize: 16)),
                Text(
                  user.presenceText,
                  style: TextStyle(
                    fontSize: 12,
                    color: user.isRecentlyOnline
                        ? Colors.green
                        : Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
          loading: () => const Text('Loading...'),
          error: (e, s) => const Text('Chat'),
        );
      },
      loading: () => const Text('Loading...'),
      error: (e, s) => const Text('Chat'),
    );
  }
}
