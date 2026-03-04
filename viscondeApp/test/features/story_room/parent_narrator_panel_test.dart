import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/design_system/visconde.dart';
import 'package:visconde_app/features/story_room/ui/parent_narrator_panel.dart';

Widget _wrapPanel(ParentNarratorPanel panel) {
  return MaterialApp(
    theme: ViscondeTheme.buildLightTheme(),
    home: Scaffold(body: panel),
  );
}

Widget _wrapPanelInScrollView(
  ParentNarratorPanel panel, {
  required ScrollController controller,
}) {
  return MaterialApp(
    theme: ViscondeTheme.buildLightTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        controller: controller,
        child: Column(children: [const SizedBox(height: 520), panel]),
      ),
    ),
  );
}

void main() {
  testWidgets('renders buttons with expected order and next-step label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapPanel(
        ParentNarratorPanel(
          onSaveNarration: (_) async => true,
          onRequestIdeas: (_) {},
          ideas: const <String>[],
          ideasSource: null,
          ideasSafetyAdjusted: false,
        ),
      ),
    );

    final generateRect = tester.getRect(
      find.byKey(const ValueKey<String>('story_room_generate_idea_button')),
    );
    final nextStepRect = tester.getRect(
      find.byKey(const ValueKey<String>('story_room_next_step_button')),
    );

    expect(generateRect.center.dx, lessThan(nextStepRect.center.dx));
    expect(find.text('Próximo passo'), findsOneWidget);
  });

  testWidgets('shows loading state in generate idea button', (tester) async {
    await tester.pumpWidget(
      _wrapPanel(
        ParentNarratorPanel(
          onSaveNarration: (_) async => true,
          onRequestIdeas: (_) {},
          ideas: const <String>[],
          ideasSource: null,
          ideasSafetyAdjusted: false,
          isRequestingIdeas: true,
        ),
      ),
    );

    final generateButtonFinder = find.byKey(
      const ValueKey<String>('story_room_generate_idea_button'),
    );
    final generateButton = tester.widget<ElevatedButton>(generateButtonFinder);

    expect(generateButton.onPressed, isNull);
    expect(find.text('Gerando...'), findsOneWidget);
    expect(
      find.descendant(
        of: generateButtonFinder,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'selecting an idea fills narration field without saving immediately',
    (tester) async {
      final savedNarrations = <String>[];
      const idea =
          'Um amigo ficou triste e precisa de ajuda para voltar a sorrir.';

      await tester.pumpWidget(
        _wrapPanel(
          ParentNarratorPanel(
            onSaveNarration: (text) async {
              savedNarrations.add(text);
              return true;
            },
            onRequestIdeas: (_) {},
            ideas: const <String>[idea],
            ideasSource: 'TEMPLATE',
            ideasSafetyAdjusted: false,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add_comment_outlined));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, idea);
      expect(savedNarrations, isEmpty);
    },
  );

  testWidgets('save button sends narration text', (tester) async {
    final savedNarrations = <String>[];

    await tester.pumpWidget(
      _wrapPanel(
        ParentNarratorPanel(
          onSaveNarration: (text) async {
            savedNarrations.add(text);
            return true;
          },
          onRequestIdeas: (_) {},
          ideas: const <String>[],
          ideasSource: null,
          ideasSafetyAdjusted: false,
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField).first,
      'A equipe decide agir com calma e seguir em frente.',
    );
    await tester.tap(find.text('Próximo passo'));
    await tester.pump();

    expect(savedNarrations, <String>[
      'A equipe decide agir com calma e seguir em frente.',
    ]);
  });

  testWidgets('does not clear narration when save fails', (tester) async {
    await tester.pumpWidget(
      _wrapPanel(
        ParentNarratorPanel(
          onSaveNarration: (_) async => false,
          onRequestIdeas: (_) {},
          ideas: const <String>[],
          ideasSource: null,
          ideasSafetyAdjusted: false,
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField).first,
      'Trecho que deve permanecer após erro.',
    );
    await tester.tap(find.text('Próximo passo'));
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.controller?.text, 'Trecho que deve permanecer após erro.');
  });

  testWidgets(
    'auto-scrolls to suggestions when idea request finishes with results',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        _wrapPanelInScrollView(
          ParentNarratorPanel(
            onSaveNarration: (_) async => true,
            onRequestIdeas: (_) {},
            ideas: const <String>[],
            ideasSource: null,
            ideasSafetyAdjusted: false,
            isRequestingIdeas: true,
          ),
          controller: scrollController,
        ),
      );

      expect(scrollController.offset, 0);

      await tester.pumpWidget(
        _wrapPanelInScrollView(
          ParentNarratorPanel(
            onSaveNarration: (_) async => true,
            onRequestIdeas: (_) {},
            ideas: const <String>[
              'Uma nova pista surge no caminho da aventura.',
            ],
            ideasSource: 'TEST',
            ideasSafetyAdjusted: false,
            isRequestingIdeas: false,
          ),
          controller: scrollController,
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(scrollController.offset, greaterThan(0));
    },
  );
}
