import 'package:mockito/annotations.dart';
import 'package:flutter_supabase/api/task_api.dart';
import 'package:flutter_supabase/local/task_local_db.dart';
import 'package:http/http.dart' as http;

@GenerateMocks([
  TaskApiService,
  TaskLocalDb,
], customMocks: [
  MockSpec<http.Client>(as: #MockHttpClient),
])
void main() {}
