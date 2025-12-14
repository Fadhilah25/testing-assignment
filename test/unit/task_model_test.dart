import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_supabase/models/task.dart';

void main() {
  group('Task Model - JSON Serialization (Supabase)', () {
    test('fromJson should create Task from valid JSON', () {
      final json = {
        'id': 1,
        'title': 'Test Task',
        'description': 'Test Description',
        'completed': true,
        'user_id': 'user-123',
        'created_at': '2024-01-01T10:00:00.000Z',
      };

      final task = Task.fromJson(json);

      expect(task.serverId, 1);
      expect(task.title, 'Test Task');
      expect(task.description, 'Test Description');
      expect(task.completed, true);
      expect(task.userId, 'user-123');
      expect(task.createdAt, isNotNull);
      expect(task.isSynced, true); // Data from server is synced
    });

    test('fromJson should handle missing optional fields', () {
      final json = {
        'id': 2,
        'title': 'Minimal Task',
        'user_id': 'user-456',
      };

      final task = Task.fromJson(json);

      expect(task.serverId, 2);
      expect(task.title, 'Minimal Task');
      expect(task.description, ''); // Default empty
      expect(task.completed, false); // Default false
      expect(task.userId, 'user-456');
      expect(task.createdAt, null);
    });

    test('fromJson should handle null values gracefully', () {
      final json = {
        'id': null,
        'title': null,
        'description': null,
        'completed': null,
        'user_id': null,
        'created_at': null,
      };

      final task = Task.fromJson(json);

      expect(task.serverId, null);
      expect(task.title, '');
      expect(task.description, '');
      expect(task.completed, false);
      expect(task.userId, '');
      expect(task.createdAt, null);
    });

    test('toJson should convert Task to JSON for server', () {
      final task = Task(
        serverId: 1,
        title: 'Server Task',
        description: 'Server Description',
        completed: true,
        userId: 'user-789',
        createdAt: DateTime.parse('2024-01-01T10:00:00.000Z'),
        isSynced: true,
      );

      final json = task.toJson();

      expect(json['id'], 1);
      expect(json['title'], 'Server Task');
      expect(json['description'], 'Server Description');
      expect(json['completed'], true);
      expect(json['user_id'], 'user-789');
      expect(json['created_at'], '2024-01-01T10:00:00.000Z');
      expect(json.containsKey('local_id'), false); // Local ID not sent
    });

    test('toJson should not include id for new tasks', () {
      final task = Task(
        title: 'New Task',
        description: 'New Description',
        userId: 'user-999',
      );

      final json = task.toJson();

      expect(json.containsKey('id'), false); // No ID for create operation
      expect(json['title'], 'New Task');
    });
  });

  group('Task Model - SQLite Serialization', () {
    test('fromMap should create Task from SQLite row', () {
      final map = {
        'local_id': 10,
        'server_id': 20,
        'title': 'Local Task',
        'description': 'Local Description',
        'completed': 1,
        'user_id': 'local-user',
        'created_at': '2024-01-01T10:00:00.000Z',
        'is_synced': 0,
      };

      final task = Task.fromMap(map);

      expect(task.localId, 10);
      expect(task.serverId, 20);
      expect(task.title, 'Local Task');
      expect(task.description, 'Local Description');
      expect(task.completed, true);
      expect(task.userId, 'local-user');
      expect(task.createdAt, isNotNull);
      expect(task.isSynced, false);
    });

    test('fromMap should handle boolean as int (SQLite format)', () {
      final map = {
        'local_id': 11,
        'title': 'Boolean Test',
        'user_id': 'test-user',
        'completed': 0, // SQLite stores bool as 0/1
        'is_synced': 1,
      };

      final task = Task.fromMap(map);

      expect(task.completed, false);
      expect(task.isSynced, true);
    });

    test('toMap should convert Task to SQLite row format', () {
      final task = Task(
        localId: 15,
        serverId: 25,
        title: 'Map Task',
        description: 'Map Description',
        completed: true,
        userId: 'map-user',
        createdAt: DateTime.parse('2024-01-01T10:00:00.000Z'),
        isSynced: false,
      );

      final map = task.toMap();

      expect(map['local_id'], 15);
      expect(map['server_id'], 25);
      expect(map['title'], 'Map Task');
      expect(map['description'], 'Map Description');
      expect(map['completed'], 1); // Converted to int
      expect(map['user_id'], 'map-user');
      expect(map['created_at'], '2024-01-01T10:00:00.000Z');
      expect(map['is_synced'], 0); // Converted to int
    });

    test('toMap should handle null optional fields', () {
      final task = Task(
        title: 'Minimal Map Task',
        userId: 'minimal-user',
      );

      final map = task.toMap();

      expect(map['local_id'], null);
      expect(map['server_id'], null);
      expect(map['created_at'], null);
    });
  });

  group('Task Model - copyWith', () {
    test('copyWith should update only specified fields', () {
      final original = Task(
        localId: 1,
        serverId: 10,
        title: 'Original',
        description: 'Original Description',
        completed: false,
        userId: 'user-1',
        isSynced: false,
      );

      final updated = original.copyWith(
        title: 'Updated',
        completed: true,
      );

      expect(updated.localId, 1); // Unchanged
      expect(updated.serverId, 10); // Unchanged
      expect(updated.title, 'Updated'); // Changed
      expect(updated.description, 'Original Description'); // Unchanged
      expect(updated.completed, true); // Changed
      expect(updated.userId, 'user-1'); // Unchanged
      expect(updated.isSynced, false); // Unchanged
    });

    test('copyWith should update isSynced flag', () {
      final unsynced = Task(
        title: 'Unsynced',
        userId: 'user-2',
        isSynced: false,
      );

      final synced = unsynced.copyWith(
        serverId: 100,
        isSynced: true,
      );

      expect(synced.serverId, 100);
      expect(synced.isSynced, true);
      expect(synced.title, 'Unsynced'); // Unchanged
    });

    test('copyWith without arguments should return identical copy', () {
      final original = Task(
        localId: 5,
        title: 'Test',
        userId: 'user-5',
      );

      final copy = original.copyWith();

      expect(copy.localId, original.localId);
      expect(copy.title, original.title);
      expect(copy.userId, original.userId);
    });
  });

  group('Task Model - Edge Cases', () {
    test('should handle empty strings', () {
      final task = Task(
        title: '',
        description: '',
        userId: '',
      );

      expect(task.title, '');
      expect(task.description, '');
      expect(task.userId, '');
    });

    test('should handle very long strings', () {
      final longString = 'A' * 1000;
      final task = Task(
        title: longString,
        description: longString,
        userId: 'user-long',
      );

      expect(task.title.length, 1000);
      expect(task.description.length, 1000);
    });

    test('should handle special characters in strings', () {
      final task = Task(
        title: 'Task with 特殊字符 émojis 🎉',
        description: 'Line1\nLine2\tTab',
        userId: 'user-special',
      );

      expect(task.title, contains('特殊字符'));
      expect(task.title, contains('🎉'));
      expect(task.description, contains('\n'));
    });

    test('should handle future dates', () {
      final futureDate = DateTime.now().add(Duration(days: 365));
      final task = Task(
        title: 'Future Task',
        userId: 'user-future',
        createdAt: futureDate,
      );

      expect(task.createdAt, futureDate);
    });

    test('should handle past dates', () {
      final pastDate = DateTime.parse('1990-01-01T00:00:00.000Z');
      final task = Task(
        title: 'Past Task',
        userId: 'user-past',
        createdAt: pastDate,
      );

      expect(task.createdAt, pastDate);
    });
  });

  group('Task Model - Default Values', () {
    test('should use correct default values', () {
      final task = Task(
        title: 'Default Test',
        userId: 'user-default',
      );

      expect(task.localId, null);
      expect(task.serverId, null);
      expect(task.description, ''); // Default
      expect(task.completed, false); // Default
      expect(task.createdAt, null);
      expect(task.isSynced, false); // Default
    });
  });
}
