import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/design_system/visconde.dart';
import 'package:visconde_app/features/story_room/ui/widgets/story_room_header.dart';

Widget _wrapHeader({
  required int xpAnimationNonce,
  int currentStep = 2,
  Widget? trailingAction,
}) {
  return MaterialApp(
    theme: ViscondeTheme.buildLightTheme(),
    home: Scaffold(
      body: StoryRoomHeader(
        currentStep: currentStep,
        totalSteps: 12,
        xp: 83,
        maxXp: 500,
        backgroundImageAsset: 'assets/design/maps/stage_01.png',
        trailingAction: trailingAction,
        xpAnimationNonce: xpAnimationNonce,
      ),
    ),
  );
}

void main() {
  testWidgets('does not render top stage bar and keeps scene badge', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapHeader(xpAnimationNonce: 0));

    expect(
      find.byKey(const ValueKey<String>('story_room_stage_label')),
      findsNothing,
    );
    expect(find.byIcon(Icons.picture_in_picture_alt), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('story_room_scene_badge')),
      findsOneWidget,
    );
    expect(find.text('Cena 2/12'), findsOneWidget);
  });

  testWidgets('renders shield+sword xp icon', (tester) async {
    await tester.pumpWidget(_wrapHeader(xpAnimationNonce: 0));

    expect(
      find.byKey(const ValueKey<String>('story_room_xp_shield_sword')),
      findsOneWidget,
    );
  });

  testWidgets('moves avatars when current step changes', (tester) async {
    const parentAvatarKey = ValueKey<String>('story_room_parent_avatar');
    const childAvatarKey = ValueKey<String>('story_room_child_avatar');

    await tester.pumpWidget(_wrapHeader(xpAnimationNonce: 0, currentStep: 2));

    final parentAtStep2 = tester.getTopLeft(find.byKey(parentAvatarKey));
    final childAtStep2 = tester.getTopLeft(find.byKey(childAvatarKey));

    await tester.pumpWidget(_wrapHeader(xpAnimationNonce: 0, currentStep: 9));
    await tester.pumpAndSettle();

    final parentAtStep9 = tester.getTopLeft(find.byKey(parentAvatarKey));
    final childAtStep9 = tester.getTopLeft(find.byKey(childAvatarKey));

    expect(parentAtStep9.dx, greaterThan(parentAtStep2.dx));
    expect(parentAtStep9.dy, lessThan(parentAtStep2.dy));
    expect(childAtStep9.dx, greaterThan(childAtStep2.dx));
    expect(childAtStep9.dy, lessThan(childAtStep2.dy));
  });

  testWidgets('renders trailing action when provided', (tester) async {
    await tester.pumpWidget(
      _wrapHeader(
        xpAnimationNonce: 0,
        trailingAction: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Editar detalhes'),
        ),
      ),
    );

    expect(find.text('Editar detalhes'), findsOneWidget);
  });

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
