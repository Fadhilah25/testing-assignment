import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_supabase/local/task_local_db.dart';
import 'package:flutter_supabase/models/task.dart';

void main() {
  late TaskLocalDb localDb;

  setUpAll(() {
    // Initialize SQLite FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    localDb = TaskLocalDb();
    // Clear database before each test
    await localDb.clearAll();
  });

  tearDown(() async {
    // Clean up after each test
    await localDb.clearAll();
  });

  group('TaskLocalDb - Database Operations', () {
    test('should insert and retrieve task', () async {
      final task = Task(
        title: 'Test Task',
        description: 'Test Description',
        userId: 'user-123',
        completed: false,
        createdAt: DateTime.now(),
      );

      final id = await localDb.insertTask(task);
      expect(id, greaterThan(0));

      final tasks = await localDb.getAllTasks();
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Test Task');
      expect(tasks.first.localId, id);
    });

    test('should update existing task', () async {
      final task = Task(
        title: 'Original Task',
        description: 'Original Description',
        userId: 'user-123',
        completed: false,
      );

      final id = await localDb.insertTask(task);
      final insertedTask = task.copyWith(localId: id);

      final updatedTask = insertedTask.copyWith(
        title: 'Updated Task',
        completed: true,
      );

      await localDb.updateTask(updatedTask);

      final tasks = await localDb.getAllTasks();
      expect(tasks.first.title, 'Updated Task');
      expect(tasks.first.completed, true);
    });

    test('should delete task by localId', () async {
      final task = Task(
        title: 'Task to Delete',
        userId: 'user-123',
        completed: false,
      );

      final id = await localDb.insertTask(task);

      var tasks = await localDb.getAllTasks();
      expect(tasks.length, 1);

      await localDb.deleteTask(id);

      tasks = await localDb.getAllTasks();
      expect(tasks.length, 0);
    });

    test('should get unsynced tasks only', () async {
      final syncedTask = Task(
        title: 'Synced Task',
        userId: 'user-123',
        isSynced: true,
        serverId: 10,
      );

      final unsyncedTask = Task(
        title: 'Unsynced Task',
        userId: 'user-123',
        isSynced: false,
      );

      await localDb.insertTask(syncedTask);
      await localDb.insertTask(unsyncedTask);

      final unsyncedTasks = await localDb.getUnsyncedTasks();
      expect(unsyncedTasks.length, 1);
      expect(unsyncedTasks.first.title, 'Unsynced Task');
      expect(unsyncedTasks.first.isSynced, false);
    });

    test('should replace all tasks', () async {
      // Insert some initial tasks
      await localDb.insertTask(Task(
        title: 'Old Task 1',
        userId: 'user-123',
      ));
      await localDb.insertTask(Task(
        title: 'Old Task 2',
        userId: 'user-123',
      ));

      var tasks = await localDb.getAllTasks();
      expect(tasks.length, 2);

      // Replace with new tasks
      final newTasks = [
        Task(
          serverId: 100,
          title: 'New Task 1',
          userId: 'user-123',
          isSynced: true,
        ),
        Task(
          serverId: 200,
          title: 'New Task 2',
          userId: 'user-123',
          isSynced: true,
        ),
        Task(
          serverId: 300,
          title: 'New Task 3',
          userId: 'user-123',
          isSynced: true,
        ),
      ];

      await localDb.replaceAllTasks(newTasks);

      tasks = await localDb.getAllTasks();
      expect(tasks.length, 3);
      expect(tasks[0].title, contains('New Task'));
      expect(tasks.every((t) => t.isSynced), true);
    });

    test('should maintain data integrity with multiple operations', () async {
      // Insert multiple tasks
      final task1Id = await localDb.insertTask(Task(
        title: 'Task 1',
        userId: 'user-123',
      ));
      final task2Id = await localDb.insertTask(Task(
        title: 'Task 2',
        userId: 'user-123',
      ));

      // Update one
      await localDb.updateTask(Task(
        localId: task1Id,
        title: 'Task 1 Updated',
        userId: 'user-123',
        completed: true,
      ));

      // Delete another
      await localDb.deleteTask(task2Id);

      // Insert new
      await localDb.insertTask(Task(
        title: 'Task 3',
        userId: 'user-123',
      ));

      final tasks = await localDb.getAllTasks();
      expect(tasks.length, 2);
      expect(tasks.any((t) => t.title == 'Task 1 Updated'), true);
      expect(tasks.any((t) => t.title == 'Task 3'), true);
      expect(tasks.any((t) => t.title == 'Task 2'), false);
    });

    test('should clear all tasks', () async {
      await localDb.insertTask(Task(title: 'Task 1', userId: 'user-123'));
      await localDb.insertTask(Task(title: 'Task 2', userId: 'user-123'));
      await localDb.insertTask(Task(title: 'Task 3', userId: 'user-123'));

      var tasks = await localDb.getAllTasks();
      expect(tasks.length, 3);

      await localDb.clearAll();

      tasks = await localDb.getAllTasks();
      expect(tasks.length, 0);
    });

    test('should handle concurrent operations', () async {
      // Simulate concurrent inserts
      await Future.wait([
        localDb.insertTask(Task(title: 'Concurrent 1', userId: 'user-123')),
        localDb.insertTask(Task(title: 'Concurrent 2', userId: 'user-123')),
        localDb.insertTask(Task(title: 'Concurrent 3', userId: 'user-123')),
      ]);

      final tasks = await localDb.getAllTasks();
      expect(tasks.length, 3);
    });

    test('should preserve task order by created_at', () async {
      await Future.delayed(const Duration(milliseconds: 10));
      await localDb.insertTask(Task(
        title: 'First',
        userId: 'user-123',
        createdAt: DateTime.now(),
      ));

      await Future.delayed(const Duration(milliseconds: 10));
      await localDb.insertTask(Task(
        title: 'Second',
        userId: 'user-123',
        createdAt: DateTime.now(),
      ));

      await Future.delayed(const Duration(milliseconds: 10));
      await localDb.insertTask(Task(
        title: 'Third',
        userId: 'user-123',
        createdAt: DateTime.now(),
      ));

      final tasks = await localDb.getAllTasks();
      // getAllTasks returns DESC order (newest first)
      expect(tasks.first.title, 'Third');
      expect(tasks.last.title, 'First');
    });
  });

  group('TaskLocalDb - Edge Cases', () {
    test('should handle empty database', () async {
      final tasks = await localDb.getAllTasks();
      expect(tasks, isEmpty);

      final unsyncedTasks = await localDb.getUnsyncedTasks();
      expect(unsyncedTasks, isEmpty);
    });

    test('should handle task with null optional fields', () async {
      final task = Task(
        title: 'Minimal Task',
        userId: 'user-123',
      );

      final id = await localDb.insertTask(task);
      final tasks = await localDb.getAllTasks();

      expect(tasks.first.localId, id);
      expect(tasks.first.description, isEmpty);
      expect(tasks.first.serverId, null);
    });

    test('should handle task with all fields populated', () async {
      final task = Task(
        localId: null,
        serverId: 999,
        title: 'Complete Task',
        description: 'Full description',
        userId: 'user-123',
        completed: true,
        createdAt: DateTime.now(),
        isSynced: true,
      );

      await localDb.insertTask(task);
      final tasks = await localDb.getAllTasks();

      expect(tasks.first.title, 'Complete Task');
      expect(tasks.first.description, 'Full description');
      expect(tasks.first.completed, true);
      expect(tasks.first.isSynced, true);
    });
  });
}
