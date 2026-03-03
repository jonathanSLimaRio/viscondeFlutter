import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:visconde_app/app/app_route.dart';
import 'package:visconde_app/design_system/visconde.dart';
import 'package:visconde_app/features/auth/ui/login_screen.dart';
import 'package:visconde_app/features/auth/ui/signup_screen.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('navigates to signup when tapping "Criar conta"', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoute.login,
      routes: [
        GoRoute(
          path: AppRoute.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoute.signup,
          builder: (context, state) => const SignupScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: authOverrides(user: buildTestUser(), authenticated: false),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ViscondeTheme.buildLightTheme(),
          builder: (context, child) => ViscondeScaffoldBackground(
            child: child ?? const SizedBox.shrink(),
          ),
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Não tem conta? Criar conta'));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
  });

  testWidgets('renders Google and Apple social buttons disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapTestApp(
        const LoginScreen(),
        overrides: authOverrides(user: buildTestUser(), authenticated: false),
      ),
    );

    await tester.pumpAndSettle();

    final googleButton = find.widgetWithText(
      OutlinedButton,
      'Continuar com Google',
    );
    final appleButton = find.widgetWithText(
      OutlinedButton,
      'Continuar com Apple',
    );

    expect(googleButton, findsOneWidget);
    expect(appleButton, findsOneWidget);
    expect(tester.widget<OutlinedButton>(googleButton).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(appleButton).onPressed, isNull);

    final googleOpacity = find.ancestor(
      of: googleButton,
      matching: find.byWidgetPredicate(
        (widget) => widget is Opacity && (widget.opacity - 0.55).abs() < 0.0001,
      ),
    );
    final appleOpacity = find.ancestor(
      of: appleButton,
      matching: find.byWidgetPredicate(
        (widget) => widget is Opacity && (widget.opacity - 0.55).abs() < 0.0001,
      ),
    );

    expect(googleOpacity, findsOneWidget);
    expect(appleOpacity, findsOneWidget);
  });
}
