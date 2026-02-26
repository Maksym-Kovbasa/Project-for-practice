import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
  });

  final int id;
  final String username;
  final String email;
  final String password;
}

class SqliteAuthService {
  SqliteAuthService._();

  static final SqliteAuthService instance = SqliteAuthService._();
  Database? _db;

  Future<Database> get _database async {
    if (_db != null) {
      return _db!;
    }
    _db = await _openDatabase();
    return _db!;
  }

  Future<Database> _openDatabase() async {
    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, 'auth.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            email TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL
          )
        ''');
        await db.insert('users', {
          'username': 'demo',
          'email': 'demo@example.com',
          'password': 'demo123',
        });
      },
    );
  }

  Future<AuthUser> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final db = await _database;

    final existingUsername = await db.query(
      'users',
      columns: ['id'],
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (existingUsername.isNotEmpty) {
      throw AuthException('Username already exists.');
    }

    final existingEmail = await db.rawQuery(
      'SELECT id FROM users WHERE lower(email) = lower(?) LIMIT 1',
      [email],
    );
    if (existingEmail.isNotEmpty) {
      throw AuthException('Email is already in use.');
    }

    final userId = await db.insert('users', {
      'username': username,
      'email': email,
      'password': password,
    });

    return AuthUser(
      id: userId,
      username: username,
      email: email,
      password: password,
    );
  }

  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw AuthException('Invalid username or password.');
    }

    final row = rows.first;
    return AuthUser(
      id: row['id'] as int,
      username: row['username'] as String,
      email: row['email'] as String,
      password: row['password'] as String,
    );
  }
}
