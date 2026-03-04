import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/core/models/app_user.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/features/profile/profile_api.dart';
import 'package:visconde_app/features/profile/ui/profile_hub_tab.dart';
import 'package:visconde_app/features/security/security_api.dart';
import 'package:visconde_app/shared/providers.dart';

import '../../helpers/test_harness.dart';

class _FakeProfileApi extends ProfileApi {
  _FakeProfileApi(this.user) : super(Dio());

  final AppUser user;

  @override
  Future<AppUser> getMe(String accessToken) async {
    return user;
  }
}

class _FakeSecurityApi extends SecurityApi {
  _FakeSecurityApi() : super(Dio());

  @override
  Future<bool> hasPin(String accessToken) async {
    return true;
  }
}

void main() {
  testWidgets('ProfileHubTab alterna Conta, Crianças e Área do pai', (
    tester,
  ) async {
    final user = buildTestUser();

    await tester.pumpWidget(
      wrapTestApp(
        const Scaffold(body: ProfileHubTab()),
        overrides: [
          ...authOverrides(user: user, authenticated: true),
          profileApiProvider.overrideWith((ref) => _FakeProfileApi(user)),
          childrenApiProvider.overrideWith(
            (ref) => FakeChildrenApi(
              children: [
                ChildProfile(
                  id: 'child-1',
                  name: 'Lia',
                  birthDate: DateTime(2018, 1, 1),
                  favoriteThemes: const ['Aventura'],
                  isArchived: false,
                ),
              ],
            ),
          ),
          securityApiProvider.overrideWith((ref) => _FakeSecurityApi()),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Central do Perfil'), findsOneWidget);
    expect(find.text('Conta'), findsOneWidget);

    await tester.tap(find.text('Crianças'));
    await tester.pumpAndSettle();
    expect(find.text('Adicionar criança'), findsOneWidget);

    await tester.tap(find.text('Área do pai'));
    await tester.pumpAndSettle();
    expect(
      find.text('Gerencie PIN e acessos protegidos da área do pai.'),
      findsOneWidget,
    );
    expect(find.text('Área do pai protegida'), findsOneWidget);
  });
}
