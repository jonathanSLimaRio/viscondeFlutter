import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/design_system/typography/visconde_typography.dart';

void main() {
  test('ViscondeTypography mantém escala conservadora configurada', () {
    final textTheme = ViscondeTypography.build();

    expect(textTheme.headlineLarge?.fontSize, 30);
    expect(textTheme.headlineMedium?.fontSize, 25);
    expect(textTheme.headlineSmall?.fontSize, 21);

    expect(textTheme.titleLarge?.fontSize, 18);
    expect(textTheme.titleMedium?.fontSize, 16);
    expect(textTheme.titleSmall?.fontSize, 15);

    expect(textTheme.bodyLarge?.fontSize, 14);
    expect(textTheme.bodyMedium?.fontSize, 14);
    expect(textTheme.bodySmall?.fontSize, 12);

    expect(textTheme.labelLarge?.fontSize, 14);
    expect(textTheme.labelMedium?.fontSize, 13);
    expect(textTheme.labelSmall?.fontSize, 11);
  });

  test(
    'ViscondeTypography preserva hierarquia headline > title > body > label',
    () {
      final textTheme = ViscondeTypography.build();

      expect(
        textTheme.headlineLarge!.fontSize!,
        greaterThan(textTheme.headlineMedium!.fontSize!),
      );
      expect(
        textTheme.headlineMedium!.fontSize!,
        greaterThan(textTheme.headlineSmall!.fontSize!),
      );
      expect(
        textTheme.headlineSmall!.fontSize!,
        greaterThan(textTheme.titleLarge!.fontSize!),
      );
      expect(
        textTheme.titleLarge!.fontSize!,
        greaterThan(textTheme.titleMedium!.fontSize!),
      );
      expect(
        textTheme.titleMedium!.fontSize!,
        greaterThan(textTheme.titleSmall!.fontSize!),
      );

      expect(
        textTheme.titleSmall!.fontSize!,
        greaterThanOrEqualTo(textTheme.bodyLarge!.fontSize!),
      );
      expect(
        textTheme.bodyLarge!.fontSize!,
        greaterThanOrEqualTo(textTheme.bodyMedium!.fontSize!),
      );
      expect(
        textTheme.bodyMedium!.fontSize!,
        greaterThan(textTheme.bodySmall!.fontSize!),
      );

      expect(
        textTheme.bodySmall!.fontSize!,
        greaterThan(textTheme.labelSmall!.fontSize!),
      );
    },
  );
}
