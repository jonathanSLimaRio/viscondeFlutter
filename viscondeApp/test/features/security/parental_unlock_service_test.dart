import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/core/models/app_user.dart';
import 'package:visconde_app/core/storage/session_storage.dart';
import 'package:visconde_app/features/auth/auth_api.dart';
import 'package:visconde_app/features/auth/auth_controller.dart';
import 'package:visconde_app/features/security/parental_gate_controller.dart';
import 'package:visconde_app/features/security/security_api.dart';
import 'package:visconde_app/shared/providers.dart';
import 'package:visconde_app/shared/ux_analytics.dart';

import '../../helpers/test_harness.dart';

class _ParentalAuthApi extends AuthApi {
  _ParentalAuthApi({required this.user}) : super(Dio());

  final AppUser user;

  @override
  Future<AppUser> me({required String accessToken}) async {
    return user;
  }
}

class _FakeSecurityApi extends SecurityApi {
  _FakeSecurityApi() : super(Dio());

  int verifyCalls = 0;
  PinVerifyResult result = PinVerifyResult(
    verified: true,
    unlockTtlMinutes: 10,
    parentalUnlockToken: 'unlock-token-new',
    parentalUnlockExpiresAt: DateTime.now().toUtc().add(
      const Duration(minutes: 10),
    ),
  );

  @override
  Future<PinVerifyResult> verifyPin(String accessToken, String pin) async {
    verifyCalls += 1;
    return result;
  }
}

Future<void> _waitAuthReady(
  WidgetTester tester,
  ProviderContainer container,
) async {
  for (var i = 0; i < 40; i++) {
    if (container.read(authControllerProvider).status != AuthStatus.loading) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 20));
  }
  throw StateError('AuthController did not leave loading state in time.');
}

void main() {
  group('ParentalUnlockService', () {
    late List<UxAnalyticsEvent> analyticsEvents;

    setUp(() {
      analyticsEvents = <UxAnalyticsEvent>[];
      UxAnalytics.configure(sink: analyticsEvents.add);
    });

    tearDown(() {
      UxAnalytics.clearSink();
    });

    testWidgets('reuses valid token without prompting PIN', (tester) async {
      final user = buildTestUser();
      final fakeSecurityApi = _FakeSecurityApi();
      final container = ProviderContainer(
        overrides: [
          authApiProvider.overrideWith((ref) => _ParentalAuthApi(user: user)),
          sessionStorageProvider.overrideWith(
            (ref) => MemorySessionStorage(
              StoredSession(
                accessToken: 'token-123',
                refreshToken: 'refresh-123',
                user: user,
              ),
            ),
          ),
          securityApiProvider.overrideWith((ref) => fakeSecurityApi),
        ],
      );
      addTearDown(container.dispose);

      await _waitAuthReady(tester, container);
      container
          .read(parentalGateControllerProvider.notifier)
          .setUnlocked(
            token: 'unlock-existing',
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          );

      BuildContext? context;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (ctx) {
                context = ctx;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final token = await container
          .read(parentalUnlockServiceProvider)
          .ensureUnlocked(context!, source: 'test_valid_token');

      expect(token, 'unlock-existing');
      expect(fakeSecurityApi.verifyCalls, 0);
      expect(find.text('PIN adulto'), findsNothing);
    });

    testWidgets('expired unlock prompts once and is single-flight', (
      tester,
    ) async {
      final user = buildTestUser();
      final fakeSecurityApi = _FakeSecurityApi()
        ..result = PinVerifyResult(
          verified: true,
          unlockTtlMinutes: 10,
          parentalUnlockToken: 'unlock-refreshed',
          parentalUnlockExpiresAt: DateTime.now().toUtc().add(
            const Duration(minutes: 10),
          ),
        );
      final container = ProviderContainer(
        overrides: [
          authApiProvider.overrideWith((ref) => _ParentalAuthApi(user: user)),
          sessionStorageProvider.overrideWith(
            (ref) => MemorySessionStorage(
              StoredSession(
                accessToken: 'token-123',
                refreshToken: 'refresh-123',
                user: user,
              ),
            ),
          ),
          securityApiProvider.overrideWith((ref) => fakeSecurityApi),
        ],
      );
      addTearDown(container.dispose);

      await _waitAuthReady(tester, container);
      container
          .read(parentalGateControllerProvider.notifier)
          .setUnlocked(
            token: 'unlock-expiring',
            expiresAt: DateTime.now().add(const Duration(seconds: 10)),
          );

      BuildContext? context;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (ctx) {
                context = ctx;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final service = container.read(parentalUnlockServiceProvider);
      final futureA = service.ensureUnlocked(context!, source: 'test_a');
      final futureB = service.ensureUnlocked(context!, source: 'test_b');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('PIN adulto'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final tokens = await Future.wait([futureA, futureB]);
      expect(tokens, ['unlock-refreshed', 'unlock-refreshed']);
      expect(fakeSecurityApi.verifyCalls, 1);
      expect(
        container.read(parentalGateControllerProvider).unlockToken,
        'unlock-refreshed',
      );
      expect(
        analyticsEvents.where((event) => event.name == 'pin_prompt_shown'),
        hasLength(1),
      );
      expect(
        analyticsEvents.where((event) => event.name == 'pin_prompt_success'),
        hasLength(1),
      );
    });
  });
}
