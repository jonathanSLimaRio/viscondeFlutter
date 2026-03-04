import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_route.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/session_persona_controller.dart';
import '../features/auth/ui/forgot_password_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/session_persona_screen.dart';
import '../features/auth/ui/signup_screen.dart';
import '../features/profile/ui/home_shell_screen.dart';
import '../features/security/ui/virtue_reports_screen.dart';
import '../features/security/ui/voice_profiles_screen.dart';
import '../features/story_creation/ui/create_story_screen.dart';
import '../features/story_room/ui/story_room_entry_screen.dart';
import '../features/story_room/ui/story_summary_screen.dart';
import '../features/story_vault/ui/story_vault_collection_redirect_screen.dart';
import '../shared/loading_screen.dart';

String _sanitizeFromForPersonaSelection(String? raw) {
  final candidate = raw?.trim();
  if (candidate == null || candidate.isEmpty) {
    return AppRoute.home;
  }

  final parsed = Uri.tryParse(candidate);
  final path = parsed?.path ?? candidate;
  if (!path.startsWith('/')) {
    return AppRoute.home;
  }

  if (path == AppRoute.loading ||
      AppRoute.isAuthRoute(path) ||
      AppRoute.isSessionPersonaRoute(path)) {
    return AppRoute.home;
  }
  return candidate;
}

String _resolvePostPersonaTarget(
  String? rawFrom,
  SessionPersonaState personaState,
) {
  final sanitized = _sanitizeFromForPersonaSelection(rawFrom);
  final path = Uri.tryParse(sanitized)?.path ?? sanitized;

  if (personaState.isChildMode && AppRoute.isAdultAreaRoute(path)) {
    return AppRoute.home;
  }
  return sanitized;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoute.loading,
    routes: [
      GoRoute(
        path: AppRoute.loading,
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        path: AppRoute.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoute.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoute.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoute.sessionPersona,
        builder: (context, state) =>
            SessionPersonaScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: AppRoute.adultVirtueReports,
        builder: (context, state) => const VirtueReportsScreen(),
      ),
      GoRoute(
        path: AppRoute.adultVoices,
        builder: (context, state) => const VoiceProfilesScreen(),
      ),
      GoRoute(
        path: AppRoute.vaultDetailPattern,
        builder: (context, state) {
          final collectionId = state.pathParameters['id'] ?? '';
          return StoryVaultCollectionRedirectScreen(collectionId: collectionId);
        },
      ),
      GoRoute(
        path: AppRoute.storyCreate,
        builder: (context, state) => CreateStoryScreen(
          resumeDraft: state.uri.queryParameters['resume'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoute.storyRoomPattern,
        builder: (context, state) {
          final storyId = state.pathParameters['id'] ?? '';
          return StoryRoomEntryScreen(storyId: storyId);
        },
      ),
      GoRoute(
        path: AppRoute.storySummaryPattern,
        builder: (context, state) {
          final storyId = state.pathParameters['id'] ?? '';
          return StorySummaryScreen(storyId: storyId);
        },
      ),
      GoRoute(
        path: AppRoute.home,
        builder: (context, state) => HomeShellScreen(
          initialTab: AppRoute.parseHomeTab(state.uri.queryParameters['tab']),
        ),
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final isAuthRoute = AppRoute.isAuthRoute(location);
      final isSessionPersonaRoute = AppRoute.isSessionPersonaRoute(location);
      final personaState = ref.read(sessionPersonaControllerProvider);

      if (auth.status == AuthStatus.loading) {
        return location == AppRoute.loading ? null : AppRoute.loading;
      }

      if (auth.status == AuthStatus.unauthenticated) {
        if (isAuthRoute) {
          return null;
        }

        final from = state.uri.toString();
        return Uri(
          path: AppRoute.login,
          queryParameters: {'from': from},
        ).toString();
      }

      if (auth.status == AuthStatus.authenticated) {
        if (personaState.isChildMode && AppRoute.isAdultAreaRoute(location)) {
          return AppRoute.home;
        }

        if (!personaState.hasSelection) {
          if (isSessionPersonaRoute) {
            return null;
          }
          final from = _sanitizeFromForPersonaSelection(state.uri.toString());
          return Uri(
            path: AppRoute.sessionPersona,
            queryParameters: from == AppRoute.home
                ? null
                : <String, String>{'from': from},
          ).toString();
        }

        if (isSessionPersonaRoute) {
          final from = state.uri.queryParameters['from'];
          return _resolvePostPersonaTarget(from, personaState);
        }

        if (location == AppRoute.loading || isAuthRoute) {
          final from = state.uri.queryParameters['from'];
          return _resolvePostPersonaTarget(from, personaState);
        }
      }

      return null;
    },
  );

  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    final wasAuthenticated = previous?.status == AuthStatus.authenticated;
    final isAuthenticated = next.status == AuthStatus.authenticated;
    if (wasAuthenticated && !isAuthenticated) {
      ref.read(sessionPersonaControllerProvider.notifier).clear();
    }
    if (next.status == AuthStatus.loading) {
      return;
    }
    router.refresh();
  });

  ref.listen<SessionPersonaState>(sessionPersonaControllerProvider, (
    previous,
    next,
  ) {
    router.refresh();
  });

  ref.onDispose(router.dispose);

  return router;
});
