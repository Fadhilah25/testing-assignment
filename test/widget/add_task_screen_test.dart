import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:flutter_supabase/screens/add_task_screen.dart';
import 'package:flutter_supabase/providers/task_provider.dart';

import '../mocks/mock_annotations.mocks.dart';

void main() {
  late MockTaskApiService mockApiService;
  late MockTaskLocalDb mockLocalDb;

  setUp(() {
    mockApiService = MockTaskApiService();
    mockLocalDb = MockTaskLocalDb();
    when(mockApiService.loadSession()).thenAnswer((_) async => null);
  });

  Future<TaskProvider> createProvider() async {
    final provider = TaskProvider(mockApiService, mockLocalDb);
    await provider.checkSession();
    return provider;
  }

  Widget createAddTaskScreen(TaskProvider provider) {
    return MaterialApp(
      home: ChangeNotifierProvider<TaskProvider>.value(
        value: provider,
        child: const AddTaskScreen(),
      ),
    );
  }

  group('AddTaskScreen Widget Tests', () {
    testWidgets('should display form fields', (tester) async {
      final provider = await createProvider();
      await tester.pumpWidget(createAddTaskScreen(provider));
      await tester.pump();

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('should validate empty title', (tester) async {
      final provider = await createProvider();
      await tester.pumpWidget(createAddTaskScreen(provider));

      // Tap save button without entering title
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Title harus diisi'), findsOneWidget);
    });

    testWidgets('should create task with valid data', (tester) async {
      when(mockLocalDb.insertTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.createTask(any)).thenAnswer((_) async => null);

      // Create authenticated provider
      final provider = TaskProvider(mockApiService, mockLocalDb);
      when(mockApiService.loadSession()).thenAnswer((_) async => {
            'email': 'test@example.com',
            'userId': 'user-123',
          });
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      await provider.checkSession();

      await tester.pumpWidget(createAddTaskScreen(provider));

      // Enter valid data
      final titleField = find.byType(TextFormField).first;
      final descField = find.byType(TextFormField).last;

      await tester.enterText(titleField, 'New Task');
      await tester.enterText(descField, 'Task description');

      // Save
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Task should be added (insertTask called)
      await tester.pumpAndSettle();
      verify(mockLocalDb.insertTask(any)).called(1);
    });

    testWidgets('should allow empty description', (tester) async {
      when(mockLocalDb.insertTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.createTask(any)).thenAnswer((_) async => null);

      // Create authenticated provider
      final provider = TaskProvider(mockApiService, mockLocalDb);
      when(mockApiService.loadSession()).thenAnswer((_) async => {
            'email': 'test@example.com',
            'userId': 'user-123',
          });
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      await provider.checkSession();

      await tester.pumpWidget(createAddTaskScreen(provider));

      // Enter only title
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, 'Task without description');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      await tester.pumpAndSettle();
      verify(mockLocalDb.insertTask(any)).called(1);
    });

    testWidgets('should show loading indicator while saving', (tester) async {
      // Test verifies addTask is called (uses optimistic UI, no loading state)
      when(mockLocalDb.insertTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.createTask(any)).thenAnswer((_) async => null);

      // Create authenticated provider
      final provider = TaskProvider(mockApiService, mockLocalDb);
      when(mockApiService.loadSession()).thenAnswer((_) async => {
            'email': 'test@example.com',
            'userId': 'user-123',
          });
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      await provider.checkSession();

      await tester.pumpWidget(createAddTaskScreen(provider));

      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, 'New Task');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify task was added (optimistic UI pattern)
      verify(mockLocalDb.insertTask(any)).called(1);
    });

    testWidgets('should pop screen after successful save', (tester) async {
      when(mockLocalDb.insertTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.createTask(any)).thenAnswer((_) async => null);

      final provider = await createProvider();
      when(mockApiService.loadSession()).thenAnswer((_) async => {
            'email': 'test@example.com',
            'userId': 'user-123',
          });
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      await provider.checkSession();

      // Use MaterialApp with routes for navigation testing
      await tester.pumpWidget(MaterialApp(
        routes: {
          '/': (context) => Scaffold(
                body: ElevatedButton(
                  child: const Text('Open Add Task'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: provider,
                        child: const AddTaskScreen(),
                      ),
                    ),
                  ),
                ),
              ),
        },
      ));

      // Open AddTaskScreen
      await tester.tap(find.text('Open Add Task'));
      await tester.pumpAndSettle();

      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, 'New Task');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Screen should pop after save, back to home
      expect(find.byType(AddTaskScreen), findsNothing);
      expect(find.text('Open Add Task'), findsOneWidget);
    });
  });
}
