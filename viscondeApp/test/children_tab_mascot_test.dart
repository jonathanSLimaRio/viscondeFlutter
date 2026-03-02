import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/design_system/visconde.dart';
import 'package:visconde_app/features/children/ui/children_tab.dart';
import 'package:visconde_app/shared/providers.dart';

import 'helpers/test_harness.dart';

void main() {
  testWidgets('ChildrenTab empty state renders mascot', (tester) async {
    await tester.pumpWidget(
      wrapTestApp(
        const Scaffold(body: ChildrenTab()),
        overrides: [
          ...authOverrides(user: buildTestUser(), authenticated: true),
          childrenApiProvider.overrideWith(
            (ref) => FakeChildrenApi(children: const []),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ViscondeMascot), findsOneWidget);
    expect(find.text('Nenhuma criança cadastrada ainda.'), findsOneWidget);
  });
}
