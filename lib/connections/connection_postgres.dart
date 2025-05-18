import 'package:postgres/postgres.dart';

class ConnectionPostgres {
  ConnectionPostgres._();

  static final instance = ConnectionPostgres._();
  PostgreSQLConnection? _db;

  static Future<void> init() async {
    instance._db = PostgreSQLConnection(
      'localhost',
      5433,
      'com3as1',
      username: 'postgres',
      password: '123456789',
    );

    try {
      await instance._db!.open();
      print('Database connection established');
    } catch (e) {
      print('Failed to connect to database: $e');
      throw Exception('Database connection failed');
    }
  }

  static PostgreSQLConnection get db {
    if (instance._db == null) {
      throw Exception('Please call init function in server.dart');
    }
    return instance._db!;
  }

  static Future<void> close() async {
    await instance._db?.close();
  }
}
