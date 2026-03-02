import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/app/app_route.dart';

void main() {
  group('AppRoute', () {
    test('builds dynamic routes consistently', () {
      expect(AppRoute.storyRoom('abc'), '/stories/abc/room');
      expect(AppRoute.storyRemote('abc'), '/stories/abc/remote');
      expect(AppRoute.storySummary('abc'), '/stories/abc/summary');
      expect(AppRoute.vaultDetail('vault-1'), '/vault/vault-1');
    });

    test('categorizes route groups correctly', () {
      expect(AppRoute.isAuthRoute(AppRoute.login), isTrue);
      expect(AppRoute.isAuthRoute(AppRoute.signup), isTrue);
      expect(AppRoute.isAuthRoute(AppRoute.home), isFalse);

      expect(AppRoute.isRemotePublicRoute(AppRoute.remoteJoin), isTrue);
      expect(AppRoute.isRemotePublicRoute(AppRoute.remoteRoom), isTrue);
      expect(AppRoute.isRemotePublicRoute(AppRoute.storyCreate), isFalse);

      expect(AppRoute.isAdminProtectedRoute(AppRoute.adminHub), isTrue);
      expect(AppRoute.isAdminProtectedRoute(AppRoute.adminThemes), isTrue);
      expect(AppRoute.isAdminProtectedRoute(AppRoute.adminDenied), isFalse);
    });
  });
}
