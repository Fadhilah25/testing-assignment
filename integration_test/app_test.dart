import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_supabase/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End User Flow Tests', () {
    testWidgets('App should start and show login screen', (tester) async {
      // Start app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should show login screen initially - check for key widgets
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byKey(const Key('emailField')), findsOneWidget);
      expect(find.byKey(const Key('passwordField')), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    });

    testWidgets('Should be able to switch to register mode', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Switch to register mode
      await tester
          .tap(find.widgetWithText(TextButton, 'Belum punya akun? Register'));
      await tester.pumpAndSettle();

      // Should show register mode
      expect(find.text('Register'), findsWidgets);
      expect(find.widgetWithText(TextButton, 'Sudah punya akun? Login'),
          findsOneWidget);
    });

    testWidgets('Offline mode: Should be able to work without server',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // App should load even without server connection
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byKey(const Key('emailField')), findsOneWidget);
    });

    testWidgets('Form validation should work', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Try to login with empty fields
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      // App should still be on login screen (validation prevents submission)
      expect(find.byKey(const Key('emailField')), findsOneWidget);
      expect(find.text('Email harus diisi'), findsOneWidget);
    });
  });
}
