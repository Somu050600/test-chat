import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../models/conversation_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';

class ConversationTile extends ConsumerWidget {
  final ConversationModel conversation;
  final String otherUserId;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.otherUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider(otherUserId));
    final theme = Theme.of(context);
    final uid = ref.watch(currentUserProvider)?.uid;
    final unread = uid != null ? conversation.unreadFor(uid) : 0;

    return userAsync.when(
      data: (user) {
        return ListTile(
          leading: CircleAvatar(
            backgroundImage:
                user?.photoUrl.isNotEmpty == true
                    ? NetworkImage(user!.photoUrl)
                    : null,
            child: user?.photoUrl.isEmpty != false
                ? Text(
                    (user?.name ?? '?').isNotEmpty
                        ? (user?.name ?? '?')[0].toUpperCase()
                        : '?',
                  )
                : null,
          ),
          title: Text(
            user?.name ?? 'Unknown',
            style: theme.textTheme.titleMedium,
          ),
          subtitle: conversation.lastMessage.isNotEmpty
              ? Text(
                  conversation.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (unread > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                DateFormatter.relative(conversation.updatedAt),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          onTap: onTap,
        );
      },
      loading: () => const ListTile(
        leading: CircleAvatar(child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('Loading...'),
      ),
      error: (e, s) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.error)),
        title: const Text('Unknown user'),
        onTap: onTap,
      ),
    );
  }
}
