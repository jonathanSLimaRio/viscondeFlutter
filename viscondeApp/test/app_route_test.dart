import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/app/app_route.dart';

void main() {
  group('AppRoute', () {
    test('builds dynamic routes consistently', () {
      expect(AppRoute.storyRoom('abc'), '/stories/abc/room');
      expect(AppRoute.storySummary('abc'), '/stories/abc/summary');
      expect(AppRoute.vaultDetail('vault-1'), '/vault/vault-1');
      expect(AppRoute.avatarEditorPath(), AppRoute.avatarEditor);
      expect(
        AppRoute.storyGameReadyPath(storyId: 'story-1', title: 'Aventura'),
        '/stories/game-ready?storyId=story-1&title=Aventura',
      );
    });

    test('categorizes route groups correctly', () {
      expect(AppRoute.isAuthRoute(AppRoute.login), isTrue);
      expect(AppRoute.isAuthRoute(AppRoute.signup), isTrue);
      expect(AppRoute.isAuthRoute(AppRoute.home), isFalse);

      expect(AppRoute.isAdultAreaRoute(AppRoute.adultVirtueReports), isTrue);
      expect(AppRoute.isAdultAreaRoute(AppRoute.adultVoices), isTrue);
      expect(AppRoute.isAdultAreaRoute(AppRoute.storyCreate), isFalse);
    });
  });
}
