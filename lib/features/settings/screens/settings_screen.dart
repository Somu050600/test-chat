import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/launcher_platform_service.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/notification_provider.dart';

class LauncherVariantOption {
  final String id;
  final String label;
  final IconData previewIcon;

  const LauncherVariantOption({
    required this.id,
    required this.label,
    required this.previewIcon,
  });
}

final _launcherVariants = [
  const LauncherVariantOption(
    id: LauncherPlatformService.aliasDefault,
    label: 'Chat App',
    previewIcon: Icons.chat_bubble_outline,
  ),
  const LauncherVariantOption(
    id: LauncherPlatformService.aliasNotes,
    label: 'Notes',
    previewIcon: Icons.note_alt_outlined,
  ),
  const LauncherVariantOption(
    id: LauncherPlatformService.aliasWork,
    label: 'Work',
    previewIcon: Icons.work_outline,
  ),
  const LauncherVariantOption(
    id: LauncherPlatformService.aliasPrivate,
    label: 'Private',
    previewIcon: Icons.lock_outline,
  ),
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _appNameController = TextEditingController();
  bool _nameInitialized = false;
  bool _appNameSynced = false;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    _appNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto(String uid) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (xfile == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final ext = xfile.name.contains('.')
          ? xfile.name.split('.').last.toLowerCase()
          : 'jpg';
      final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
      final refStorage = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(uid)
          .child('profile_${DateTime.now().millisecondsSinceEpoch}.$safeExt');

      final bytes = await xfile.readAsBytes();
      await refStorage.putData(
        bytes,
        SettableMetadata(contentType: 'image/$safeExt'),
      );
      final url = await refStorage.getDownloadURL();
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Set a display name first')),
          );
        }
        return;
      }
      await ref.read(authServiceProvider).updateProfile(name: name, photoUrl: url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name')),
      );
      return;
    }
    try {
      await ref.read(authServiceProvider).updateProfile(name: name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  Future<void> _saveAppNameOverride() async {
    await ref
        .read(appSettingsProvider.notifier)
        .setCustomAppName(_appNameController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('In-app name updated')),
      );
    }
  }

  Future<void> _logout() async {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref.read(notificationServiceProvider).deleteToken(user.uid);
    }
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProfileProvider, (_, next) {
      next.whenOrNull(data: (profile) {
        if (profile != null && !_nameInitialized) {
          _nameInitialized = true;
          _nameController.text = profile.name;
        }
      });
    });

    ref.listen(appSettingsProvider, (_, next) {
      next.whenOrNull(data: (s) {
        if (!_appNameSynced) {
          _appNameSynced = true;
          _appNameController.text = s.displayAppName;
        }
      });
    });

    final profileAsync = ref.watch(currentUserProfileProvider);
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          profileAsync.when(
            data: (profile) {
              if (profile == null) {
                return const Text('Not signed in');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: profile.photoUrl.isNotEmpty
                              ? NetworkImage(profile.photoUrl)
                              : null,
                          child: profile.photoUrl.isEmpty
                              ? Text(
                                  profile.name.isNotEmpty
                                      ? profile.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(fontSize: 36),
                                )
                              : null,
                        ),
                        if (_uploadingPhoto)
                          const Positioned.fill(
                            child: Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        else
                          IconButton.filled(
                            onPressed: () => _pickAndUploadPhoto(profile.uid),
                            icon: const Icon(Icons.camera_alt, size: 20),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _saveName,
                    child: const Text('Save name'),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 32),
          Text('App appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'In-app title (stored on this device only)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _appNameController,
            decoration: const InputDecoration(
              labelText: 'App name in title bar',
              hintText: 'Leave empty to use default',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _saveAppNameOverride(),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _saveAppNameOverride,
            child: const Text('Apply in-app name'),
          ),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
            const SizedBox(height: 24),
            Text(
              'Launcher icon & name (Android only)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose one home-screen shortcut. Other aliases are hidden.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            settingsAsync.when(
              data: (settings) => Column(
                children: _launcherVariants.map((v) {
                  final selected = settings.launcherAliasId == v.id;
                  return Card(
                    child: ListTile(
                      leading: Icon(v.previewIcon, size: 32),
                      title: Text(v.label),
                      subtitle: Text(selected ? 'Active' : 'Tap to select'),
                      trailing: selected
                          ? Icon(Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary)
                          : const Icon(Icons.circle_outlined),
                      onTap: () async {
                        await ref
                            .read(appSettingsProvider.notifier)
                            .setLauncherAlias(v.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Launcher set to ${v.label}. '
                              'Your home screen may update shortly.',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ],
          const SizedBox(height: 40),
          FilledButton.tonal(
            onPressed: _logout,
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
