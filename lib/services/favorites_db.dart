import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:nova_cosmos_messenger/models/apod_data.dart';

class FavoritesDB {
  static Database? _database;
  static const String _table = 'favorites';

  static Future<Database> initDatabase() async {
    _database = await openDatabase(
      join(await getDatabasesPath(), 'favorites.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table(
            date TEXT PRIMARY KEY,
            title TEXT,
            explanation TEXT,
            url TEXT,
            hdurl TEXT,
            media_type TEXT,
            copyright TEXT,
            saved_at INTEGER
          )
        ''');
      },
    );
    return _database!;
  }

  static Future<Database> _db() async {
    if (_database != null) return _database!;
    return await initDatabase();
  }

  static Future<void> add(ApodData apod) async {
    final db = await _db();
    final map = apod.toMap();
    map['saved_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      _table,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<ApodData>> getAll() async {
    final db = await _db();
    final rows = await db.query(_table, orderBy: 'saved_at DESC');
    return rows.map((m) => ApodData.fromMap(m)).toList();
  }

  static Future<bool> exists(String date) async {
    final db = await _db();
    final rows = await db.query(
      _table,
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  static Future<void> remove(String date) async {
    final db = await _db();
    await db.delete(_table, where: 'date = ?', whereArgs: [date]);
  }
}
