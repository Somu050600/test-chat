import 'package:chat_app/core/utils/notification_payload.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conversationIdFromRemoteMessage returns null for null message', () {
    expect(conversationIdFromRemoteMessage(null), isNull);
  });

  test('conversationIdFromRemoteMessage reads data.conversationId', () {
    final message = RemoteMessage(
      data: {'conversationId': 'abc123'},
    );
    expect(conversationIdFromRemoteMessage(message), 'abc123');
  });
}
