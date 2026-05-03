import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android: enable one activity-alias and disable others for launcher icon/name.
class LauncherPlatformService {
  static const _channel = MethodChannel('com.example.test_chat_1/launcher');

  static const String aliasDefault = 'default';
  static const String aliasNotes = 'notes';
  static const String aliasWork = 'work';
  static const String aliasPrivate = 'private';

  static Future<void> applyLauncherAlias(String aliasId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setLauncherAlias', {'alias': aliasId});
    } catch (_) {}
  }

  static Future<String?> getCurrentLauncherAlias() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final v = await _channel.invokeMethod<String>('getLauncherAlias');
      return v;
    } catch (_) {
      return null;
    }
  }
}
