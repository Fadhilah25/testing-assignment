import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_supabase/providers/task_provider.dart';
import 'package:flutter_supabase/screens/login_screen.dart';
import 'package:flutter_supabase/screens/task_list_screen.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'api/task_api.dart';
import 'local/task_local_db.dart';

void main() {
  // Inisialisasi SQLite untuk Windows/Linux/macOS
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize services
  final apiService = TaskApiService();
  final localDb = TaskLocalDb();

  runApp(
    ChangeNotifierProvider(
      create: (context) {
        final taskProvider = TaskProvider(apiService, localDb);
        taskProvider.checkSession(); // Check saved session + load offline data
        return taskProvider;
      },
      child: MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline-First Tasks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Selector<TaskProvider, bool>(
        selector: (context, provider) => provider.isAuthLoading,
        builder: (context, isAuthLoading, child) {
          return Consumer<TaskProvider>(
            builder: (context, taskProvider, child) {
              if (isAuthLoading) {
                return Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              return taskProvider.isAuthenticated
                  ? TaskListScreen()
                  : LoginScreen();
            },
          );
        },
      ),
    );
  }
}
