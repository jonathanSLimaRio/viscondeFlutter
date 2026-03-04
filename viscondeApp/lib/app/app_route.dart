enum HomeTab { stories, game, achievements, profile }

abstract final class AppRoute {
  static const loading = '/loading';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const sessionPersona = '/session/persona';

  static const home = '/';
  static const avatarEditor = '/family/avatars';

  static const adultVirtueReports = '/adult/virtues/reports';
  static const adultVoices = '/adult/voices';

  static const vaultDetailPattern = '/vault/:id';
  static const storyCreate = '/stories/new';
  static const storyGameReady = '/stories/game-ready';
  static const storyRoomPattern = '/stories/:id/room';
  static const storySummaryPattern = '/stories/:id/summary';

  static const _storyRoomSuffix = '/room';
  static const _storySummarySuffix = '/summary';
  static const _adultAreaPrefix = '/adult/';
  static const _homeTabQuery = 'tab';

  static String vaultDetail(String collectionId) => '/vault/$collectionId';
  static String storyRoom(String storyId) => '/stories/$storyId/room';
  static String storySummary(String storyId) => '/stories/$storyId/summary';
  static String avatarEditorPath({String? source, String? childId}) {
    final query = <String, String>{};
    if (source != null && source.trim().isNotEmpty) {
      query['source'] = source.trim();
    }
    if (childId != null && childId.trim().isNotEmpty) {
      query['childId'] = childId.trim();
    }
    if (query.isEmpty) {
      return avatarEditor;
    }
    return Uri(path: avatarEditor, queryParameters: query).toString();
  }

  static String storyGameReadyPath({
    required String storyId,
    required String title,
  }) {
    return Uri(
      path: storyGameReady,
      queryParameters: <String, String>{
        'storyId': storyId,
        'title': title,
      },
    ).toString();
  }
  static String homePath({HomeTab tab = HomeTab.stories}) {
    if (tab == HomeTab.stories) {
      return home;
    }
    return Uri(
      path: home,
      queryParameters: {_homeTabQuery: _tabName(tab)},
    ).toString();
  }

  static HomeTab parseHomeTab(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'game':
        return HomeTab.game;
      case 'achievements':
      case 'conquistas':
        return HomeTab.achievements;
      case 'children':
      case 'adult':
        return HomeTab.profile;
      case 'profile':
        return HomeTab.profile;
      case 'stories':
      default:
        return HomeTab.stories;
    }
  }

  static String _tabName(HomeTab tab) {
    switch (tab) {
      case HomeTab.stories:
        return 'stories';
      case HomeTab.game:
        return 'game';
      case HomeTab.achievements:
        return 'achievements';
      case HomeTab.profile:
        return 'profile';
    }
  }

  static String storyCreatePath({bool resumeDraft = false}) {
    if (!resumeDraft) {
      return storyCreate;
    }
    return Uri(
      path: storyCreate,
      queryParameters: const {'resume': '1'},
    ).toString();
  }

  static bool isAuthRoute(String location) {
    return location == login ||
        location == signup ||
        location == forgotPassword;
  }

  static bool isSessionPersonaRoute(String location) {
    return location == sessionPersona;
  }

  static bool isAdultAreaRoute(String location) {
    return location.startsWith(_adultAreaPrefix);
  }

  static bool isStoryRoomPath(String location) {
    return location.startsWith('/stories/') &&
        location.endsWith(_storyRoomSuffix);
  }

  static bool isStorySummaryPath(String location) {
    return location.startsWith('/stories/') &&
        location.endsWith(_storySummarySuffix);
  }
}
