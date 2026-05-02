import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When non-null, open this conversation after the user is authenticated
/// (e.g. notification tap while logged out, or auth still loading).
class PendingChatConversationIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setPending(String conversationId) {
    state = conversationId;
  }

  void clear() {
    state = null;
  }
}

final pendingChatConversationIdProvider =
    NotifierProvider<PendingChatConversationIdNotifier, String?>(
  PendingChatConversationIdNotifier.new,
);
