import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:flutter_supabase/screens/login_screen.dart';
import 'package:flutter_supabase/providers/task_provider.dart';

import '../mocks/mock_annotations.mocks.dart';

void main() {
  late MockTaskApiService mockApiService;
  late MockTaskLocalDb mockLocalDb;

  setUp(() {
    mockApiService = MockTaskApiService();
    mockLocalDb = MockTaskLocalDb();
    // Mock loadSession to return null (not authenticated)
    when(mockApiService.loadSession()).thenAnswer((_) async => null);
  });

  Future<TaskProvider> createProvider() async {
    final provider = TaskProvider(mockApiService, mockLocalDb);
    // Call checkSession to initialize isAuthLoading to false
    await provider.checkSession();
    return provider;
  }

  Widget createLoginScreen(TaskProvider provider) {
    return MaterialApp(
      home: ChangeNotifierProvider<TaskProvider>.value(
        value: provider,
        child: const LoginScreen(),
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('should display login form', (tester) async {
      final provider = await createProvider();
      await tester.pumpWidget(createLoginScreen(provider));
      await tester.pump();

      expect(find.text('Login'), findsWidgets);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('should validate empty email', (tester) async {
      final provider = await createProvider();
      await tester.pumpWidget(createLoginScreen(provider));

      // Tap login button without entering email
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Email harus diisi'), findsOneWidget);
    });

    testWidgets('should validate invalid email format', (tester) async {
      final provider = await createProvider();
      await tester.pumpWidget(createLoginScreen(provider));

      // Enter invalid email
      await tester.enterText(
          find.byKey(const Key('emailField')), 'invalid-email');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Email tidak valid'), findsOneWidget);
    });

    testWidgets('should validate empty password', (tester) async {
      final provider = await createProvider();
      await tester.pumpWidget(createLoginScreen(provider));

      // Enter only email
      await tester.enterText(
          find.byKey(const Key('emailField')), 'test@example.com');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Password harus diisi'), findsOneWidget);
    });

    testWidgets('should validate password length', (tester) async {
      final provider = await createProvider();
      await tester.pumpWidget(createLoginScreen(provider));

      // Enter short password
      await tester.enterText(
          find.byKey(const Key('emailField')), 'test@example.com');
      await tester.enterText(find.byKey(const Key('passwordField')), '12345');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Password minimal 6 karakter'), findsOneWidget);
    });

    testWidgets('should toggle password visibility', (tester) async {
      final provider = await createProvider();
      await tester.pumpWidget(createLoginScreen(provider));

      // Initially should show visibility icon (password is obscured)
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      // Tap visibility toggle
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      // Should now show visibility_off icon (password is visible)
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('should switch to register mode', (tester) async {
      final provider = await createProvider();
      await tester.pumpWidget(createLoginScreen(provider));

      // Tap register link
      await tester.tap(find.byType(TextButton));
      await tester.pump();

      // Should show register mode
      expect(find.text('Register'), findsWidgets);
      expect(find.text('Sudah punya akun? Login'), findsOneWidget);
    });

    testWidgets('should show loading on login', (tester) async {
      when(mockApiService.login(any, any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return {
          'user': {'email': 'test@example.com', 'id': 'user-123'},
          'access_token': 'fake-token'
        };
      });
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      when(mockLocalDb.replaceAllTasks(any)).thenAnswer((_) async => {});

      final provider = await createProvider();
      await tester.pumpWidget(createLoginScreen(provider));

      await tester.enterText(
          find.byKey(const Key('emailField')), 'test@example.com');
      await tester.enterText(
          find.byKey(const Key('passwordField')), 'password123');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for async operation to complete
      await tester.pumpAndSettle();
    });

    testWidgets('should handle login error', (tester) async {
      when(mockApiService.login(any, any)).thenAnswer((_) async => null);

      final provider = await createProvider();
      await tester.pumpWidget(createLoginScreen(provider));

      await tester.enterText(
          find.byKey(const Key('emailField')), 'test@example.com');
      await tester.enterText(
          find.byKey(const Key('passwordField')), 'password');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      // Should show error snackbar
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
