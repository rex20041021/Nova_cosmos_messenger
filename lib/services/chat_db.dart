import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:nova_cosmos_messenger/models/chat_room.dart';
import 'package:nova_cosmos_messenger/models/chat_message.dart';

class ChatDB {
  static Database? _database;
  static const String _roomsTable = 'rooms';
  static const String _messagesTable = 'messages';

  static Future<Database> initDatabase() async {
    _database = await openDatabase(
      join(await getDatabasesPath(), 'chat.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_roomsTable(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE $_messagesTable(
            id TEXT PRIMARY KEY,
            room_id TEXT NOT NULL,
            text TEXT,
            apod_json TEXT,
            wiki_json TEXT,
            from_user INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_room ON $_messagesTable(room_id, created_at)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_messagesTable ADD COLUMN wiki_json TEXT',
          );
        }
      },
    );
    return _database!;
  }

  static Future<Database> _db() async {
    if (_database != null) return _database!;
    return await initDatabase();
  }

  static Future<List<ChatRoom>> getAllRooms() async {
    final db = await _db();
    final rows = await db.query(_roomsTable, orderBy: 'updated_at DESC');
    return rows.map((m) => ChatRoom.fromMap(m)).toList();
  }

  static Future<ChatRoom> createRoom(String name) async {
    final db = await _db();
    final now = DateTime.now();
    final room = ChatRoom(
      id: 'room${now.microsecondsSinceEpoch}',
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert(_roomsTable, room.toMap());
    return room;
  }

  static Future<void> renameRoom(String id, String name) async {
    final db = await _db();
    await db.update(
      _roomsTable,
      {'name': name, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteRoom(String id) async {
    final db = await _db();
    await db.delete(_messagesTable, where: 'room_id = ?', whereArgs: [id]);
    await db.delete(_roomsTable, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> _touchRoom(String id) async {
    final db = await _db();
    await db.update(
      _roomsTable,
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<List<ChatMessage>> getMessages(String roomId) async {
    final db = await _db();
    final rows = await db.query(
      _messagesTable,
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'created_at ASC',
    );
    return rows.map((m) => ChatMessage.fromMap(m)).toList();
  }

  static Future<void> addMessage(ChatMessage message) async {
    final db = await _db();
    await db.insert(_messagesTable, message.toMap());
    await _touchRoom(message.roomId);
  }
}
