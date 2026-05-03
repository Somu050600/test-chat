import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../core/services/launcher_platform_service.dart';

const _keyCustomAppName = 'custom_app_display_name';
const _keyLauncherAlias = 'selected_launcher_alias';

class AppSettings {
  final String displayAppName;
  final String launcherAliasId;

  const AppSettings({
    required this.displayAppName,
    required this.launcherAliasId,
  });
}

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString(_keyCustomAppName)?.trim();
    final name = (custom != null && custom.isNotEmpty)
        ? custom
        : AppConstants.appName;
    final alias =
        prefs.getString(_keyLauncherAlias) ?? LauncherPlatformService.aliasDefault;
    return AppSettings(displayAppName: name, launcherAliasId: alias);
  }

  Future<void> setCustomAppName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null || name.trim().isEmpty) {
      await prefs.remove(_keyCustomAppName);
    } else {
      await prefs.setString(_keyCustomAppName, name.trim());
    }
    ref.invalidateSelf();
  }

  Future<void> setLauncherAlias(String aliasId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLauncherAlias, aliasId);
    await LauncherPlatformService.applyLauncherAlias(aliasId);
    ref.invalidateSelf();
  }

  Future<void> reloadFromPrefs() async {
    ref.invalidateSelf();
  }
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);
