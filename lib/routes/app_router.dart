import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/home/screens/new_chat_screen.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
              GoRoute(
                path: 'chat/:conversationId',
                builder: (context, state) {
                  final conversationId = state.pathParameters['conversationId']!;
                  final scrollUnread =
                      state.uri.queryParameters['fromNotification'] == '1';
                  return ChatScreen(
                    conversationId: conversationId,
                    scrollToOldestUnread: scrollUnread,
                  );
                },
              ),
          GoRoute(
            path: 'new-chat',
            builder: (context, state) => const NewChatScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
