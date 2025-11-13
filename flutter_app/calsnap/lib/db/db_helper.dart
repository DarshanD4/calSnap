import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class DBHelper {
  static Database? _db;
  static Future<Database> getDb() async {
    if (_db != null) return _db!;
    String path = join(await getDatabasesPath(), "calsnap.db");
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
        CREATE TABLE meals (
          id INTEGER PRIMARY KEY,
          timestamp INTEGER,
          note TEXT,
          total_calories REAL,
          items TEXT
        )
      ''');
      },
    );
    return _db!;
  }

  static Future<int> insertMeal(Map<String, dynamic> m) async {
    final db = await getDb();
    return await db.insert(
      "meals",
      m,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> getMeals() async {
    final db = await getDb();
    return await db.query("meals", orderBy: "timestamp DESC");
  }

  static Future<void> clearAll() async {
    final db = await getDb();
    await db.delete("meals");
  }
}
