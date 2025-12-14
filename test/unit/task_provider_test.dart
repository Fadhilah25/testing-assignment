import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_supabase/providers/task_provider.dart';
import 'package:flutter_supabase/models/task.dart';

import '../mocks/mock_annotations.mocks.dart';

void main() {
  late TaskProvider taskProvider;
  late MockTaskApiService mockApiService;
  late MockTaskLocalDb mockLocalDb;

  setUp(() {
    mockApiService = MockTaskApiService();
    mockLocalDb = MockTaskLocalDb();
    taskProvider = TaskProvider(mockApiService, mockLocalDb);
  });

  group('TaskProvider - Authentication', () {
    test('checkSession should set authenticated when session exists', () async {
      // Arrange
      final mockSession = {
        'email': 'test@example.com',
        'userId': 'user-123',
      };

      when(mockApiService.loadSession()).thenAnswer((_) async => mockSession);
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);

      // Act
      await taskProvider.checkSession();

      // Assert
      expect(taskProvider.isAuthenticated, true);
      expect(taskProvider.email, 'test@example.com');
      expect(taskProvider.userId, 'user-123');
      expect(taskProvider.isAuthLoading, false);
      verify(mockApiService.loadSession()).called(1);
    });

    test('checkSession should not authenticate when no session', () async {
      // Arrange
      when(mockApiService.loadSession()).thenAnswer((_) async => null);

      // Act
      await taskProvider.checkSession();

      // Assert
      expect(taskProvider.isAuthenticated, false);
      expect(taskProvider.email, null);
      expect(taskProvider.userId, null);
      expect(taskProvider.isAuthLoading, false);
    });

    test('login should authenticate user on success', () async {
      // Arrange
      final mockLoginResponse = {
        'user': {
          'id': 'user-456',
          'email': 'login@example.com',
        },
      };

      when(mockApiService.login('login@example.com', 'password'))
          .thenAnswer((_) async => mockLoginResponse);
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      when(mockLocalDb.replaceAllTasks(any)).thenAnswer((_) async => {});

      // Act
      final result = await taskProvider.login('login@example.com', 'password');

      // Assert
      expect(result, true);
      expect(taskProvider.isAuthenticated, true);
      expect(taskProvider.email, 'login@example.com');
      expect(taskProvider.userId, 'user-456');
      expect(taskProvider.errorMessage, null);
    });

    test('login should set error message on failure', () async {
      // Arrange
      when(mockApiService.login('wrong@example.com', 'wrongpass'))
          .thenAnswer((_) async => null);

      // Act
      final result = await taskProvider.login('wrong@example.com', 'wrongpass');

      // Assert
      expect(result, false);
      expect(taskProvider.isAuthenticated, false);
      expect(taskProvider.errorMessage, isNotNull);
      expect(taskProvider.errorMessage, contains('Login gagal'));
    });

    test('register should authenticate user on success', () async {
      // Arrange
      final mockRegisterResponse = {
        'user': {
          'id': 'user-789',
          'email': 'register@example.com',
        },
      };

      when(mockApiService.register('register@example.com', 'password'))
          .thenAnswer((_) async => mockRegisterResponse);
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      when(mockLocalDb.replaceAllTasks(any)).thenAnswer((_) async => {});

      // Act
      final result =
          await taskProvider.register('register@example.com', 'password');

      // Assert
      expect(result, true);
      expect(taskProvider.isAuthenticated, true);
      expect(taskProvider.email, 'register@example.com');
      expect(taskProvider.userId, 'user-789');
    });

    test('register should set error message on failure', () async {
      // Arrange
      when(mockApiService.register('existing@example.com', 'password'))
          .thenAnswer((_) async => null);

      // Act
      final result =
          await taskProvider.register('existing@example.com', 'password');

      // Assert
      expect(result, false);
      expect(taskProvider.isAuthenticated, false);
      expect(taskProvider.errorMessage, isNotNull);
      expect(taskProvider.errorMessage, contains('Registrasi gagal'));
    });

    test('logout should clear all data', () async {
      // Arrange
      when(mockApiService.logout()).thenAnswer((_) async {});
      when(mockLocalDb.clearAll()).thenAnswer((_) async {});

      // Simulate logged in state
      final mockSession = {
        'email': 'logout@example.com',
        'userId': 'user-logout',
      };
      when(mockApiService.loadSession()).thenAnswer((_) async => mockSession);
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      await taskProvider.checkSession();

      // Act
      await taskProvider.logout();

      // Assert
      expect(taskProvider.isAuthenticated, false);
      expect(taskProvider.email, null);
      expect(taskProvider.userId, null);
      expect(taskProvider.tasks, isEmpty);
      verify(mockApiService.logout()).called(1);
      verify(mockLocalDb.clearAll()).called(1);
    });
  });

  group('TaskProvider - Load Tasks Offline-First', () {
    setUp(() async {
      // Setup authenticated user for task operations
      final mockLoginResponse = {
        'user': {
          'id': 'user-123',
          'email': 'test@example.com',
        },
      };

      when(mockApiService.login('test@example.com', 'password'))
          .thenAnswer((_) async => mockLoginResponse);
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      when(mockLocalDb.replaceAllTasks(any)).thenAnswer((_) async => {});

      await taskProvider.login('test@example.com', 'password');
    });

    test('loadTasksOfflineFirst should load from local db first', () async {
      // Arrange
      final localTasks = [
        Task(
            localId: 1,
            title: 'Local Task',
            userId: 'user-123',
            isSynced: false),
      ];

      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => localTasks);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      when(mockLocalDb.replaceAllTasks(any)).thenAnswer((_) async => {});

      // Act
      await taskProvider.loadTasksOfflineFirst();

      // Assert
      verify(mockLocalDb.getAllTasks()).called(greaterThan(0));
      expect(taskProvider.isTaskLoading, false);
    });

    test('loadTasksOfflineFirst should sync with server', () async {
      // Arrange
      final remoteTasks = [
        Task(serverId: 1, title: 'Server Task', userId: 'user-123'),
      ];

      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => remoteTasks);
      when(mockLocalDb.replaceAllTasks(any)).thenAnswer((_) async => {});

      // Act
      await taskProvider.loadTasksOfflineFirst();

      // Assert
      // Called during login setUp and loadTasksOfflineFirst
      verify(mockApiService.getTasks()).called(greaterThan(0));
      verify(mockLocalDb.replaceAllTasks(any)).called(greaterThan(0));
    });

    test('loadTasksOfflineFirst should handle sync errors gracefully',
        () async {
      // Arrange
      final localTasks = [
        Task(localId: 1, title: 'Offline Task', userId: 'user-123'),
      ];

      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => localTasks);
      when(mockApiService.getTasks()).thenThrow(Exception('Network error'));

      // Act
      await taskProvider.loadTasksOfflineFirst();

      // Assert
      expect(taskProvider.tasks, isNotEmpty); // Still shows local tasks
      expect(taskProvider.errorMessage, isNotNull);
      expect(taskProvider.errorMessage, contains('mode offline'));
    });
  });

  group('TaskProvider - Add Task', () {
    setUp(() async {
      // Setup authenticated user
      final mockSession = {
        'email': 'test@example.com',
        'userId': 'user-123',
      };
      when(mockApiService.loadSession()).thenAnswer((_) async => mockSession);
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      await taskProvider.checkSession();
    });

    test('addTask should save locally first (optimistic)', () async {
      // Arrange
      when(mockLocalDb.insertTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.createTask(any)).thenAnswer((_) async => Task(
            serverId: 10,
            title: 'New Task',
            userId: 'user-123',
            isSynced: true,
          ));
      when(mockLocalDb.updateTask(any)).thenAnswer((_) async => 1);

      // Act
      final result = await taskProvider.addTask('New Task', 'Description');

      // Assert
      expect(result, true);
      verify(mockLocalDb.insertTask(any)).called(1);
      expect(taskProvider.tasks.length, 1);
      expect(taskProvider.tasks.first.title, 'New Task');
    });

    test('addTask should sync with server and update local', () async {
      // Arrange
      when(mockLocalDb.insertTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.createTask(any)).thenAnswer((_) async => Task(
            serverId: 20,
            title: 'Synced Task',
            userId: 'user-123',
            isSynced: true,
            createdAt: DateTime.now(),
          ));
      when(mockLocalDb.updateTask(any)).thenAnswer((_) async => 1);

      // Act
      await taskProvider.addTask('Synced Task', 'Description');

      // Assert
      verify(mockApiService.createTask(any)).called(1);
      verify(mockLocalDb.updateTask(any)).called(1);
      expect(taskProvider.tasks.first.serverId, 20);
      expect(taskProvider.tasks.first.isSynced, true);
    });

    test('addTask should handle server failure gracefully', () async {
      // Arrange
      when(mockLocalDb.insertTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.createTask(any)).thenAnswer((_) async => null);

      // Act
      final result = await taskProvider.addTask('Failed Task', 'Description');

      // Assert
      expect(result, true); // Still successful locally
      expect(taskProvider.tasks.first.isSynced, false);
      expect(taskProvider.errorMessage, isNotNull);
      expect(taskProvider.errorMessage, contains('gagal ke server'));
    });

    test('addTask should work offline', () async {
      // Arrange
      when(mockLocalDb.insertTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.createTask(any))
          .thenThrow(Exception('Network error'));

      // Act
      final result = await taskProvider.addTask('Offline Task', 'Description');

      // Assert
      expect(result, true);
      expect(taskProvider.tasks.first.isSynced, false);
      expect(taskProvider.errorMessage, contains('Mode offline'));
    });
  });

  group('TaskProvider - Toggle Task', () {
    setUp(() async {
      // Setup authenticated user
      final mockSession = {
        'email': 'test@example.com',
        'userId': 'user-123',
      };
      when(mockApiService.loadSession()).thenAnswer((_) async => mockSession);
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      await taskProvider.checkSession();
    });

    test('toggleTask should update completed status locally', () async {
      // Arrange
      final task = Task(
        localId: 1,
        serverId: 10,
        title: 'Toggle Task',
        userId: 'user-123',
        completed: false,
      );

      when(mockLocalDb.updateTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.updateTask(any)).thenAnswer((_) async => true);

      // Add task to provider's list
      taskProvider.tasks.add(task);

      // Act
      await taskProvider.toggleTask(task);

      // Assert
      verify(mockLocalDb.updateTask(any)).called(greaterThan(0));
      expect(taskProvider.tasks.first.completed, true);
    });

    test('toggleTask should sync with server if serverId exists', () async {
      // Arrange
      final task = Task(
        localId: 1,
        serverId: 10,
        title: 'Synced Toggle',
        userId: 'user-123',
        completed: false,
      );

      when(mockLocalDb.updateTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.updateTask(any)).thenAnswer((_) async => true);

      taskProvider.tasks.add(task);

      // Act
      await taskProvider.toggleTask(task);

      // Assert
      verify(mockApiService.updateTask(any)).called(1);
    });

    test('toggleTask should skip server sync if no serverId', () async {
      // Arrange
      final task = Task(
        localId: 1,
        title: 'Local Only',
        userId: 'user-123',
        completed: false,
      );

      when(mockLocalDb.updateTask(any)).thenAnswer((_) async => 1);

      taskProvider.tasks.add(task);

      // Act
      await taskProvider.toggleTask(task);

      // Assert
      verifyNever(mockApiService.updateTask(any));
      verify(mockLocalDb.updateTask(any)).called(1);
    });
  });

  group('TaskProvider - Delete Task', () {
    setUp(() async {
      // Setup authenticated user
      final mockSession = {
        'email': 'test@example.com',
        'userId': 'user-123',
      };
      when(mockApiService.loadSession()).thenAnswer((_) async => mockSession);
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      await taskProvider.checkSession();
    });

    test('deleteTask should remove from local db', () async {
      // Arrange
      final task = Task(
        localId: 1,
        serverId: 10,
        title: 'Delete Task',
        userId: 'user-123',
      );

      when(mockLocalDb.deleteTask(1)).thenAnswer((_) async => 1);
      when(mockApiService.deleteTask(10)).thenAnswer((_) async => true);

      taskProvider.tasks.add(task);

      // Act
      await taskProvider.deleteTask(task);

      // Assert
      verify(mockLocalDb.deleteTask(1)).called(1);
      expect(taskProvider.tasks, isEmpty);
    });

    test('deleteTask should sync deletion with server if serverId exists',
        () async {
      // Arrange
      final task = Task(
        localId: 1,
        serverId: 10,
        title: 'Server Delete',
        userId: 'user-123',
      );

      when(mockLocalDb.deleteTask(1)).thenAnswer((_) async => 1);
      when(mockApiService.deleteTask(10)).thenAnswer((_) async => true);

      taskProvider.tasks.add(task);

      // Act
      await taskProvider.deleteTask(task);

      // Assert
      verify(mockApiService.deleteTask(10)).called(1);
    });

    test('deleteTask should skip server deletion if no serverId', () async {
      // Arrange
      final task = Task(
        localId: 1,
        title: 'Local Delete',
        userId: 'user-123',
      );

      when(mockLocalDb.deleteTask(1)).thenAnswer((_) async => 1);

      taskProvider.tasks.add(task);

      // Act
      await taskProvider.deleteTask(task);

      // Assert
      verifyNever(mockApiService.deleteTask(any));
    });
  });

  group('TaskProvider - Getters', () {
    test('unsyncedCount should return correct count', () async {
      // Arrange
      final tasks = [
        Task(localId: 1, title: 'Synced', userId: 'user-1', isSynced: true),
        Task(
            localId: 2, title: 'Unsynced 1', userId: 'user-1', isSynced: false),
        Task(
            localId: 3, title: 'Unsynced 2', userId: 'user-1', isSynced: false),
        Task(localId: 4, title: 'Synced 2', userId: 'user-1', isSynced: true),
      ];

      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => tasks);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      when(mockLocalDb.replaceAllTasks(any)).thenAnswer((_) async => {});

      // Setup authenticated user
      final mockSession = {
        'email': 'test@example.com',
        'userId': 'user-1',
      };
      when(mockApiService.loadSession()).thenAnswer((_) async => mockSession);
      await taskProvider.checkSession();

      // Act
      final count = taskProvider.unsyncedCount;

      // Assert
      expect(count, 2);
    });
  });

  group('TaskProvider - Error Handling', () {
    test('clearError should remove error message', () async {
      // Arrange
      when(mockApiService.login('wrong@example.com', 'wrong'))
          .thenAnswer((_) async => null);
      await taskProvider.login('wrong@example.com', 'wrong');
      expect(taskProvider.errorMessage, isNotNull);

      // Act
      taskProvider.clearError();

      // Assert
      expect(taskProvider.errorMessage, null);
    });
  });
}
