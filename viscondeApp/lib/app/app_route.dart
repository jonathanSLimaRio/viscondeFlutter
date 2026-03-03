abstract final class AppRoute {
  static const loading = '/loading';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';

  static const home = '/';

  static const adultVirtueReports = '/adult/virtues/reports';
  static const adultInteractions = '/adult/interactions';
  static const adultVoices = '/adult/voices';

  static const adminDenied = '/adult/admin/denied';
  static const adminHub = '/adult/admin';
  static const adminThemes = '/adult/admin/themes';
  static const adminVirtues = '/adult/admin/virtues';
  static const adminPrompts = '/adult/admin/prompts';
  static const adminTemplates = '/adult/admin/templates';
  static const adminModeration = '/adult/admin/moderation';
  static const adminUxFunnel = '/adult/admin/ux/funnel';

  static const remoteJoin = '/remote/join';
  static const remoteRoom = '/remote/room';

  static const vaultDetailPattern = '/vault/:id';
  static const storyCreate = '/stories/new';
  static const storyRemotePattern = '/stories/:id/remote';
  static const storyRoomPattern = '/stories/:id/room';
  static const storySummaryPattern = '/stories/:id/summary';

  static const _storyRoomSuffix = '/room';
  static const _storyRemoteSuffix = '/remote';
  static const _storySummarySuffix = '/summary';

  static String vaultDetail(String collectionId) => '/vault/$collectionId';
  static String storyRoom(String storyId) => '/stories/$storyId/room';
  static String storyRemote(String storyId) => '/stories/$storyId/remote';
  static String storySummary(String storyId) => '/stories/$storyId/summary';

  static bool isAuthRoute(String location) {
    return location == login ||
        location == signup ||
        location == forgotPassword;
  }

  static bool isRemotePublicRoute(String location) {
    return location == remoteJoin || location == remoteRoom;
  }

  static bool isAdminDeniedRoute(String location) {
    return location == adminDenied;
  }

  static bool isAdminProtectedRoute(String location) {
    final denied = isAdminDeniedRoute(location);
    return (location == adminHub || location.startsWith('$adminHub/')) &&
        !denied;
  }

  static bool isStoryRoomPath(String location) {
    return location.startsWith('/stories/') &&
        location.endsWith(_storyRoomSuffix);
  }

  static bool isStoryRemotePath(String location) {
    return location.startsWith('/stories/') &&
        location.endsWith(_storyRemoteSuffix);
  }

  static bool isStorySummaryPath(String location) {
    return location.startsWith('/stories/') &&
        location.endsWith(_storySummarySuffix);
  }
}
