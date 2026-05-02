import 'package:firebase_messaging/firebase_messaging.dart';

/// FCM `data` keys are sometimes exposed as nested maps on web; normalize.
String? conversationIdFromRemoteMessage(RemoteMessage? message) {
  if (message == null) return null;
  final data = message.data;
  final raw = data['conversationId'];
  if (raw is String && raw.isNotEmpty) return raw;
  return null;
}
