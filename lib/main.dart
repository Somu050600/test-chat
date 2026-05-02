import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/notification_payload.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/pending_chat_navigation_provider.dart';
import 'providers/notification_provider.dart';
import 'routes/app_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const ProviderScope(child: ChatApp()));
}

class ChatApp extends ConsumerStatefulWidget {
  const ChatApp({super.key});

  @override
  ConsumerState<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends ConsumerState<ChatApp> with WidgetsBindingObserver {
  late final ProviderSubscription<String?> _pendingChatSubscription;
  late final ProviderSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnline();

    final notificationService = ref.read(notificationServiceProvider);
    notificationService.setupBackgroundTapHandler((RemoteMessage message) {
      final conversationId = conversationIdFromRemoteMessage(message);
      if (conversationId == null) return;
      _openChatFromNotification(conversationId);
    });

    _pendingChatSubscription = ref.listenManual<String?>(
      pendingChatConversationIdProvider,
      (_, _) => _tryOpenPendingChat(),
    );
    _authSubscription = ref.listenManual<User?>(
      currentUserProvider,
      (_, _) => _tryOpenPendingChat(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _handleInitialNotification());
  }

  @override
  void dispose() {
    _pendingChatSubscription.close();
    _authSubscription.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _openChatFromNotification(String conversationId) {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      ref.read(routerProvider).go(
            '/chat/$conversationId?fromNotification=1',
          );
      return;
    }
    ref.read(pendingChatConversationIdProvider.notifier).setPending(conversationId);
  }

  void _tryOpenPendingChat() {
    final pending = ref.read(pendingChatConversationIdProvider);
    if (pending == null || pending.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref.read(pendingChatConversationIdProvider.notifier).clear();
    ref.read(routerProvider).go('/chat/$pending?fromNotification=1');
  }

  Future<void> _handleInitialNotification() async {
    final message =
        await ref.read(notificationServiceProvider).getInitialMessage();
    final conversationId = conversationIdFromRemoteMessage(message);
    if (conversationId == null) return;
    ref.read(pendingChatConversationIdProvider.notifier).setPending(conversationId);
    _tryOpenPendingChat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _setOffline();
      default:
        break;
    }
  }

  void _setOnline() {
    ref.read(authServiceProvider).setOnlineStatus(true);
  }

  void _setOffline() {
    ref.read(authServiceProvider).updateLastSeen();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
