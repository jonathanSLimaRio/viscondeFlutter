import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/features/gamification/models/gamification_models.dart';
import 'package:visconde_app/shared/ui/post_publish_celebration_dialog.dart';

void main() {
  testWidgets('renders celebration content and returns selected CTA', (
    tester,
  ) async {
    PostPublishAction? selectedAction;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  selectedAction = await showPostPublishCelebrationDialog(
                    context,
                    source: 'test',
                    flow: 'summary',
                    storyId: 'story-1',
                    gamification: PublishGamificationSummaryModel(
                      wallet: const WalletModel(
                        coins: 100,
                        stars: 80,
                        recentTransactions: [],
                      ),
                      deltaCoins: 20,
                      deltaStars: 10,
                      unlockedAchievements: const [],
                      completedMissions: const [],
                      streak: const StreakModel(
                        currentDays: 2,
                        bestDays: 4,
                        shieldCount: 0,
                        lastCountedDate: null,
                      ),
                    ),
                  );
                },
                child: const Text('abrir'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Capítulo publicado!'), findsOneWidget);
    expect(find.text('Continuar saga'), findsOneWidget);
    expect(find.text('Ir para Game'), findsOneWidget);
    expect(find.text('Voltar ao baú'), findsOneWidget);
    expect(find.textContaining('+20 moedas'), findsOneWidget);

    await tester.tap(find.text('Ir para Game'));
    await tester.pumpAndSettle();

    expect(selectedAction, PostPublishAction.goGame);
  });
}
