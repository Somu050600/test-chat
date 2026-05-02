import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android only: dismiss notifications for a conversation (same tag as FCM).
class NativeNotificationService {
  static const _channel = MethodChannel(
    'com.example.test_chat_1/notifications',
  );

  static Future<void> cancelConversationNotifications(String conversationId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('cancelConversationNotifications', {
        'tag': conversationId,
      });
    } catch (_) {
      // Ignore if channel unavailable (e.g. tests).
    }
  }
}
