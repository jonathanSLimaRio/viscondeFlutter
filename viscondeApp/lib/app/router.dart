import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/ui/forgot_password_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/signup_screen.dart';
import '../features/profile/ui/home_shell_screen.dart';
import '../features/remote_room/ui/remote_join_screen.dart';
import '../features/remote_room/ui/remote_room_screen.dart';
import '../features/security/ui/story_interactions_adult_screen.dart';
import '../features/security/ui/virtue_reports_screen.dart';
import '../features/story_creation/ui/create_story_screen.dart';
import '../features/story_room/models/story_models.dart';
import '../features/story_room/ui/story_room_screen.dart';
import '../features/story_room/ui/story_summary_screen.dart';
import '../features/story_vault/ui/story_vault_detail_screen.dart';
import '../shared/loading_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/loading',
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/adult/virtues/reports',
        builder: (context, state) => const VirtueReportsScreen(),
      ),
      GoRoute(
        path: '/adult/interactions',
        builder: (context, state) => const StoryInteractionsAdultScreen(),
      ),
      GoRoute(
        path: '/remote/join',
        builder: (context, state) =>
            RemoteJoinScreen(prefilledCode: state.uri.queryParameters['code']),
      ),
      GoRoute(
        path: '/remote/room',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is RemoteJoinBundle) {
            return RemoteRoomScreen.guest(joinBundle: extra);
          }
          return const RemoteJoinScreen();
        },
      ),
      GoRoute(
        path: '/vault/:id',
        builder: (context, state) {
          final collectionId = state.pathParameters['id'] ?? '';
          return StoryVaultDetailScreen(collectionId: collectionId);
        },
      ),
      GoRoute(
        path: '/stories/new',
        builder: (context, state) => const CreateStoryScreen(),
      ),
      GoRoute(
        path: '/stories/:id/remote',
        builder: (context, state) {
          final storyId = state.pathParameters['id'] ?? '';
          return RemoteRoomScreen.host(storyId: storyId);
        },
      ),
      GoRoute(
        path: '/stories/:id/room',
        builder: (context, state) {
          final storyId = state.pathParameters['id'] ?? '';
          return StoryRoomScreen(storyId: storyId);
        },
      ),
      GoRoute(
        path: '/stories/:id/summary',
        builder: (context, state) {
          final storyId = state.pathParameters['id'] ?? '';
          return StorySummaryScreen(storyId: storyId);
        },
      ),
      GoRoute(path: '/', builder: (context, state) => const HomeShellScreen()),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      final isAuthRoute =
          location == '/login' ||
          location == '/signup' ||
          location == '/forgot-password';
      final isRemotePublicRoute =
          location == '/remote/join' || location == '/remote/room';

      if (auth.status == AuthStatus.loading) {
        return location == '/loading' ? null : '/loading';
      }

      if (auth.status == AuthStatus.unauthenticated) {
        return (isAuthRoute || isRemotePublicRoute) ? null : '/login';
      }

      if (auth.status == AuthStatus.authenticated) {
        if (location == '/loading' || isAuthRoute) {
          return '/';
        }
      }

      return null;
    },
  );

  ref.listen<AuthState>(authControllerProvider, (_, next) {
    if (next.status == AuthStatus.loading) {
      return;
    }
    router.refresh();
  });

  ref.onDispose(router.dispose);

  return router;
});
