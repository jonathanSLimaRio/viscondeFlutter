import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/ui/forgot_password_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/signup_screen.dart';
import '../features/profile/ui/home_shell_screen.dart';
import '../features/security/ui/virtue_reports_screen.dart';
import '../features/story_creation/ui/create_story_screen.dart';
import '../features/story_room/ui/story_room_screen.dart';
import '../features/story_room/ui/story_summary_screen.dart';
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
        path: '/stories/new',
        builder: (context, state) => const CreateStoryScreen(),
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

      if (auth.status == AuthStatus.loading) {
        return location == '/loading' ? null : '/loading';
      }

      if (auth.status == AuthStatus.unauthenticated) {
        return isAuthRoute ? null : '/login';
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
