import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/design_system/visconde.dart';
import 'package:visconde_app/features/story_room/ui/widgets/story_room_header.dart';

Widget _wrapHeader({required int xpAnimationNonce}) {
  return MaterialApp(
    theme: ViscondeTheme.buildLightTheme(),
    home: Scaffold(
      body: StoryRoomHeader(
        title: 'Aventura de Sofia',
        currentStep: 2,
        totalSteps: 12,
        xp: 83,
        maxXp: 500,
        themeArtKey: ViscondeArtKey.heroForest,
        xpAnimationNonce: xpAnimationNonce,
      ),
    ),
  );
}

void main() {
  testWidgets('shows trophy animation when xpAnimationNonce changes', (
    tester,
  ) async {
    const trophyKey = ValueKey<String>('story_room_xp_trophy');

    await tester.pumpWidget(_wrapHeader(xpAnimationNonce: 0));
    expect(find.byKey(trophyKey), findsNothing);

    await tester.pumpWidget(_wrapHeader(xpAnimationNonce: 1));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(trophyKey), findsOneWidget);
  });
}
