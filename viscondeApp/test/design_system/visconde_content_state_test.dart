import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/design_system/widgets/visconde_content_state.dart';
import 'package:visconde_app/design_system/widgets/visconde_skeleton.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('renderiza variante loading com skeleton', (tester) async {
    await tester.pumpWidget(
      wrapTestApp(
        const ViscondeContentState.loading(
          title: 'Carregando',
          description: 'Aguarde um momento.',
        ),
      ),
    );

    expect(find.text('Carregando'), findsOneWidget);
    expect(find.text('Aguarde um momento.'), findsOneWidget);
    expect(find.byType(ViscondeSkeletonBox), findsAtLeastNWidgets(2));
  });

  testWidgets('renderiza variante empty com ações', (tester) async {
    var primaryTapped = 0;
    var secondaryTapped = 0;

    await tester.pumpWidget(
      wrapTestApp(
        ViscondeContentState.empty(
          title: 'Sem conteúdo',
          description: 'Crie algo para começar.',
          primaryActionLabel: 'Criar',
          onPrimaryAction: () => primaryTapped += 1,
          secondaryActionLabel: 'Voltar',
          onSecondaryAction: () => secondaryTapped += 1,
        ),
      ),
    );

    await tester.tap(find.text('Criar'));
    await tester.pump();
    await tester.tap(find.text('Voltar'));
    await tester.pump();

    expect(primaryTapped, 1);
    expect(secondaryTapped, 1);
  });

  testWidgets('renderiza variante error com ação de retry', (tester) async {
    await tester.pumpWidget(
      wrapTestApp(
        const ViscondeContentState.error(
          title: 'Falha ao carregar',
          description: 'Tente novamente.',
          primaryActionLabel: 'Tentar novamente',
        ),
      ),
    );

    expect(find.text('Falha ao carregar'), findsOneWidget);
    expect(find.text('Tente novamente.'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });
}
