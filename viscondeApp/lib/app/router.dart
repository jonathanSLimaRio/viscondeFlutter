import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_route.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/ui/forgot_password_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/signup_screen.dart';
import '../features/admin/ui/admin_access_denied_screen.dart';
import '../features/admin/ui/admin_hub_screen.dart';
import '../features/admin/ui/moderation_admin_screen.dart';
import '../features/admin/ui/prompt_admin_screen.dart';
import '../features/admin/ui/template_admin_screen.dart';
import '../features/admin/ui/theme_admin_screen.dart';
import '../features/admin/ui/ux_funnel_admin_screen.dart';
import '../features/admin/ui/virtue_admin_screen.dart';
import '../features/profile/ui/home_shell_screen.dart';
import '../features/remote_room/ui/remote_join_screen.dart';
import '../features/remote_room/ui/remote_room_screen.dart';
import '../features/security/ui/story_interactions_adult_screen.dart';
import '../features/security/ui/virtue_reports_screen.dart';
import '../features/security/ui/voice_profiles_screen.dart';
import '../features/story_creation/ui/create_story_screen.dart';
import '../features/story_room/models/story_models.dart';
import '../features/story_room/ui/story_room_screen.dart';
import '../features/story_room/ui/story_summary_screen.dart';
import '../features/story_vault/ui/story_vault_detail_screen.dart';
import '../shared/loading_screen.dart';

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
        path: AppRoute.adultVirtueReports,
        builder: (context, state) => const VirtueReportsScreen(),
      ),
      GoRoute(
        path: AppRoute.adultInteractions,
        builder: (context, state) => const StoryInteractionsAdultScreen(),
      ),
      GoRoute(
        path: AppRoute.adultVoices,
        builder: (context, state) => const VoiceProfilesScreen(),
      ),
      GoRoute(
        path: AppRoute.adminDenied,
        builder: (context, state) => const AdminAccessDeniedScreen(),
      ),
      GoRoute(
        path: AppRoute.adminHub,
        builder: (context, state) => const AdminHubScreen(),
      ),
      GoRoute(
        path: AppRoute.adminThemes,
        builder: (context, state) => const ThemeAdminScreen(),
      ),
      GoRoute(
        path: AppRoute.adminVirtues,
        builder: (context, state) => const VirtueAdminScreen(),
      ),
      GoRoute(
        path: AppRoute.adminPrompts,
        builder: (context, state) => const PromptAdminScreen(),
      ),
      GoRoute(
        path: AppRoute.adminTemplates,
        builder: (context, state) => const TemplateAdminScreen(),
      ),
      GoRoute(
        path: AppRoute.adminModeration,
        builder: (context, state) => const ModerationAdminScreen(),
      ),
      GoRoute(
        path: AppRoute.adminUxFunnel,
        builder: (context, state) => const UxFunnelAdminScreen(),
      ),
      GoRoute(
        path: AppRoute.remoteJoin,
        builder: (context, state) =>
            RemoteJoinScreen(prefilledCode: state.uri.queryParameters['code']),
      ),
      GoRoute(
        path: AppRoute.remoteRoom,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is RemoteJoinBundle) {
            return RemoteRoomScreen.guest(joinBundle: extra);
          }
          return const RemoteJoinScreen();
        },
      ),
      GoRoute(
        path: AppRoute.vaultDetailPattern,
        builder: (context, state) {
          final collectionId = state.pathParameters['id'] ?? '';
          return StoryVaultDetailScreen(collectionId: collectionId);
        },
      ),
      GoRoute(
        path: AppRoute.storyCreate,
        builder: (context, state) => CreateStoryScreen(
          resumeDraft: state.uri.queryParameters['resume'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoute.storyRemotePattern,
        builder: (context, state) {
          final storyId = state.pathParameters['id'] ?? '';
          return RemoteRoomScreen.host(storyId: storyId);
        },
      ),
      GoRoute(
        path: AppRoute.storyRoomPattern,
        builder: (context, state) {
          final storyId = state.pathParameters['id'] ?? '';
          return StoryRoomScreen(storyId: storyId);
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
      final isRemotePublicRoute = AppRoute.isRemotePublicRoute(location);
      final isAdminDeniedRoute = AppRoute.isAdminDeniedRoute(location);
      final isAdminProtectedRoute = AppRoute.isAdminProtectedRoute(location);

      if (auth.status == AuthStatus.loading) {
        return location == AppRoute.loading ? null : AppRoute.loading;
      }

      if (auth.status == AuthStatus.unauthenticated) {
        if (isAuthRoute || isRemotePublicRoute) {
          return null;
        }

        final from = state.uri.toString();
        return Uri(
          path: AppRoute.login,
          queryParameters: {'from': from},
        ).toString();
      }

      if (auth.status == AuthStatus.authenticated) {
        final isAdmin = auth.user?.isAdmin ?? false;
        if (location == AppRoute.loading || isAuthRoute) {
          final from = state.uri.queryParameters['from'];
          if (from != null &&
              from.startsWith('/') &&
              !AppRoute.isAuthRoute(from)) {
            return from;
          }
          return AppRoute.home;
        }
        if (isAdminProtectedRoute && !isAdmin) {
          return AppRoute.adminDenied;
        }
        if (isAdminDeniedRoute && isAdmin) {
          return AppRoute.adminHub;
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
