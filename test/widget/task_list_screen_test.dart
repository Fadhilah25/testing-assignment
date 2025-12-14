import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:flutter_supabase/screens/task_list_screen.dart';
import 'package:flutter_supabase/providers/task_provider.dart';
import 'package:flutter_supabase/models/task.dart';

import '../mocks/mock_annotations.mocks.dart';

void main() {
  late MockTaskApiService mockApiService;
  late MockTaskLocalDb mockLocalDb;

  setUp(() {
    mockApiService = MockTaskApiService();
    mockLocalDb = MockTaskLocalDb();
    when(mockApiService.loadSession()).thenAnswer((_) async => {
          'email': 'test@example.com',
          'userId': 'user-123',
        });
  });

  Future<TaskProvider> createProvider() async {
    final provider = TaskProvider(mockApiService, mockLocalDb);
    // Mock initial data
    when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
    when(mockApiService.getTasks()).thenAnswer((_) async => []);
    await provider.checkSession();
    return provider;
  }

  Widget createTaskListScreen(TaskProvider provider) {
    return MaterialApp(
      home: ChangeNotifierProvider<TaskProvider>.value(
        value: provider,
        child: const TaskListScreen(),
      ),
    );
  }

  group('TaskListScreen Widget Tests', () {
    testWidgets('should display empty state when no tasks', (tester) async {
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);

      final provider = await createProvider();
      when(mockApiService.loadSession()).thenAnswer((_) async => {
            'email': 'test@example.com',
            'userId': 'user-123',
          });
      await provider.checkSession();

      await tester.pumpWidget(createTaskListScreen(provider));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada tasks'), findsOneWidget);
      expect(find.text('Tap + untuk menambah task pertama'), findsOneWidget);
    });

    testWidgets('should display task list', (tester) async {
      final tasks = [
        Task(
          localId: 1,
          serverId: 1,
          title: 'Task 1',
          description: 'Description 1',
          completed: false,
          userId: 'user-123',
          isSynced: true,
        ),
        Task(
          localId: 2,
          serverId: 2,
          title: 'Task 2',
          description: 'Description 2',
          completed: true,
          userId: 'user-123',
          isSynced: true,
        ),
      ];

      // Create provider with tasks
      final provider = TaskProvider(mockApiService, mockLocalDb);
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => tasks);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      await provider.checkSession();

      await tester.pumpWidget(createTaskListScreen(provider));
      await tester.pump();

      expect(find.text('Task 1'), findsOneWidget);
      expect(find.text('Task 2'), findsOneWidget);
    });

    testWidgets('should show unsynced indicator', (tester) async {
      final tasks = [
        Task(
          localId: 1,
          serverId: null,
          title: 'Unsynced Task',
          description: 'Not synced yet',
          completed: false,
          userId: 'user-123',
          isSynced: false,
        ),
      ];

      final provider = TaskProvider(mockApiService, mockLocalDb);
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => tasks);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      await provider.checkSession();

      await tester.pumpWidget(createTaskListScreen(provider));
      await tester.pump();

      expect(find.byIcon(Icons.offline_bolt), findsOneWidget);
      expect(find.text('Belum terkirim ke server'), findsOneWidget);
    });

    testWidgets('should toggle task completion', (tester) async {
      final task = Task(
        localId: 1,
        serverId: 1,
        title: 'Test Task',
        description: '',
        completed: false,
        userId: 'user-123',
        isSynced: true,
      );

      final provider = TaskProvider(mockApiService, mockLocalDb);
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => [task]);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      when(mockLocalDb.updateTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.updateTask(any)).thenAnswer((_) async => true);
      await provider.checkSession();

      await tester.pumpWidget(createTaskListScreen(provider));
      await tester.pump();

      // Tap checkbox to toggle
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Should update task locally (called at least once during initial load + toggle)
      verify(mockLocalDb.updateTask(any)).called(greaterThanOrEqualTo(1));
    });

    testWidgets('should show delete confirmation dialog', (tester) async {
      final task = Task(
        localId: 1,
        serverId: 1,
        title: 'Test Task',
        description: '',
        completed: false,
        userId: 'user-123',
        isSynced: true,
      );

      final provider = TaskProvider(mockApiService, mockLocalDb);
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => [task]);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      await provider.checkSession();

      await tester.pumpWidget(createTaskListScreen(provider));
      await tester.pump();

      // Tap popup menu (first one is from task item, not FAB)
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      // Tap delete option
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      // Should show confirmation dialog
      expect(find.text('Hapus Task'), findsOneWidget);
      expect(find.text('Yakin ingin menghapus task ini?'), findsOneWidget);
    });

    testWidgets('should delete task when confirmed', (tester) async {
      final task = Task(
        localId: 1,
        serverId: 1,
        title: 'Test Task',
        description: '',
        completed: false,
        userId: 'user-123',
        isSynced: true,
      );

      final provider = TaskProvider(mockApiService, mockLocalDb);
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => [task]);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      when(mockLocalDb.deleteTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.deleteTask(any)).thenAnswer((_) async => true);
      await provider.checkSession();

      await tester.pumpWidget(createTaskListScreen(provider));
      await tester.pump();

      // Tap popup menu (first one is from task item)
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      // Tap delete
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      // Confirm delete
      await tester.tap(find.text('Hapus').last);
      await tester.pumpAndSettle();

      verify(mockLocalDb.deleteTask(1)).called(1);
    });

    testWidgets('should show sync status subtitle', (tester) async {
      final provider = TaskProvider(mockApiService, mockLocalDb);
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockLocalDb.getUnsyncedTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      await provider.checkSession();

      await tester.pumpWidget(createTaskListScreen(provider));
      await tester.pump();

      // Should show sync status
      expect(find.text('Semua data tersinkron'), findsOneWidget);
    });
  });
}
