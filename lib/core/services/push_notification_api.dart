import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/env.dart';

class PushNotificationApi {
  /// Server loads message text and sender from Firestore after verifying the ID token.
  Future<void> sendNotification({
    required String conversationId,
    required String messageId,
  }) async {
    if (Env.notifyApiUrl.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final idToken = await user.getIdToken();
      await http.post(
        Uri.parse(Env.notifyApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'conversationId': conversationId,
          'messageId': messageId,
        }),
      );
    } catch (e) {
      debugPrint('Push notification API error: $e');
    }
  }
}
