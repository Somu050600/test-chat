import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/conversation_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/notification_provider.dart';
import '../widgets/conversation_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final ProviderSubscription<User?> _authForNotifications;

  @override
  void initState() {
    super.initState();
    final initialUser = ref.read(currentUserProvider);
    if (initialUser != null) {
      _initNotifications(initialUser.uid);
    }

    _authForNotifications = ref.listenManual<User?>(
      currentUserProvider,
      (previous, next) {
        if (next != null) _initNotifications(next.uid);
      },
    );
  }

  @override
  void dispose() {
    _authForNotifications.close();
    super.dispose();
  }

  Future<void> _initNotifications(String userId) async {
    await ref.read(notificationServiceProvider).initialize(userId);
  }

  void _markAllAsDelivered(List<ConversationModel> conversations, String? uid) {
    if (uid == null) return;
    final chatService = ref.read(chatServiceProvider);
    for (final convo in conversations) {
      chatService.markMessagesAsDelivered(convo.id, uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (user != null) {
                await ref
                    .read(notificationServiceProvider)
                    .deleteToken(user.uid);
              }
              await ref.read(authServiceProvider).signOut();
            },
          ),
        ],
      ),
      body: conversations.when(
        data: (list) {
          _markAllAsDelivered(list, user?.uid);
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to start a new chat',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final conversation = list[index];
              final otherUid = conversation.otherMember(user?.uid ?? '');
              return ConversationTile(
                conversation: conversation,
                otherUserId: otherUid,
                onTap: () => context.go('/chat/${conversation.id}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/new-chat'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
