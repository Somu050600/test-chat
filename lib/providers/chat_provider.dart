import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/chat_service.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final conversationsProvider = StreamProvider<List<ConversationModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(chatServiceProvider).getConversations(user.uid);
});

final messagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, conversationId) {
  return ref.watch(chatServiceProvider).getMessages(conversationId);
});

final userProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  return ref.watch(chatServiceProvider).getUser(userId);
});

final userStreamProvider =
    StreamProvider.family<UserModel?, String>((ref, userId) {
  return ref.watch(chatServiceProvider).userStream(userId);
});

final allUsersProvider = StreamProvider<List<UserModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(chatServiceProvider).searchUsers(user.uid);
});

/// Signed-in user's Firestore profile (live).
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(chatServiceProvider).userStream(user.uid);
});
