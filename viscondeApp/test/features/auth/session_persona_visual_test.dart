import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/features/auth/ui/session_persona_screen.dart';
import 'package:visconde_app/shared/providers.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('renderiza avatares dinâmicos nos cards de persona', (
    tester,
  ) async {
    final user = buildTestUser().copyWith(
      imageUrl: 'https://example.com/parent-avatar.png',
    );

    final children = <ChildProfile>[
      ChildProfile(
        id: 'child-archived',
        name: 'Antigo',
        birthDate: DateTime(2017, 1, 1),
        favoriteThemes: const <String>['Aventura'],
        isArchived: true,
        avatarUrl: 'https://example.com/archived-child.png',
      ),
      ChildProfile(
        id: 'child-active',
        name: 'Lia',
        birthDate: DateTime(2018, 2, 2),
        favoriteThemes: const <String>['Fantasia'],
        isArchived: false,
        avatarUrl: 'https://example.com/child-avatar.png',
      ),
    ];

    await tester.pumpWidget(
      wrapTestApp(
        const SessionPersonaScreen(),
        overrides: <Override>[
          ...authOverrides(user: user, authenticated: true),
          childrenApiProvider.overrideWith(
            (ref) => FakeChildrenApi(children: children),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('persona_child_avatar_square')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('persona_parent_avatar_square')),
      findsOneWidget,
    );
    expect(find.text('Quem está usando o app agora?'), findsOneWidget);
    expect(find.text('Pai e Filho'), findsOneWidget);

    expect(
      find.byKey(
        const ValueKey<String>('persona_parent_avatar_source_network'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('persona_child_avatar_source_network')),
      findsOneWidget,
    );
  });

  testWidgets('faz fallback de avatar quando usuário/criança não têm imagem', (
    tester,
  ) async {
    final user = buildTestUser();

    await tester.pumpWidget(
      wrapTestApp(
        const SessionPersonaScreen(),
        overrides: <Override>[
          ...authOverrides(user: user, authenticated: true),
          childrenApiProvider.overrideWith(
            (ref) => FakeChildrenApi(children: const <ChildProfile>[]),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('persona_parent_avatar_source_asset')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('persona_child_avatar_source_asset')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('persona_together_button')),
      findsOneWidget,
    );
  });
}
