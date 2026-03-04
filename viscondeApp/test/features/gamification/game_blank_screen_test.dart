import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/features/gamification/game_adventure_session_controller.dart';
import 'package:visconde_app/features/gamification/ui/game_blank_screen.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('exibe fallback quando não existe aventura na sessão', (
    tester,
  ) async {
    await tester.pumpWidget(wrapTestApp(const GameBlankScreen()));

    expect(find.text('Nenhuma aventura criada'), findsOneWidget);
  });

  testWidgets('exibe somente o nome da aventura quando disponível', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapTestApp(
        const GameBlankScreen(),
        overrides: [
          gameAdventureSessionControllerProvider.overrideWith((ref) {
            final controller = GameAdventureSessionController();
            controller.setFromStory(
              storyId: 'story-1',
              title: 'Misterio na Floresta',
            );
            return controller;
          }),
        ],
      ),
    );

    expect(find.text('Misterio na Floresta'), findsOneWidget);
    expect(find.text('Nenhuma aventura criada'), findsNothing);
  });
}
