import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite database helper for storing reports offline.
///
/// Uses a singleton pattern so the database is opened only once and
/// shared across the entire application.
class OfflineDatabase {
  OfflineDatabase._();

  static final OfflineDatabase instance = OfflineDatabase._();

  Database? _database;

  /// Returns the singleton [Database] instance, creating the database
  /// and table on first access.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'phonebook_offline.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE offline_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        activity_date TEXT NOT NULL,
        location TEXT NOT NULL,
        description TEXT,
        latitude REAL,
        longitude REAL,
        category_id INTEGER,
        status TEXT DEFAULT 'draft',
        jenis_laporan TEXT,
        sync_status TEXT DEFAULT 'pending',
        server_id INTEGER,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  /// Inserts a new report into the local database and returns the
  /// auto-generated row id.
  Future<int> insertReport(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final row = <String, dynamic>{
      'title': data['title'],
      'activity_date': data['activity_date'],
      'location': data['location'],
      'description': data['description'],
      'latitude': data['latitude'],
      'longitude': data['longitude'],
      'category_id': data['category_id'],
      'status': data['status'] ?? 'draft',
      'jenis_laporan': data['jenis_laporan'],
      'sync_status': data['sync_status'] ?? 'pending',
      'server_id': data['server_id'],
      'created_at': data['created_at'] ?? now,
      'updated_at': now,
    };

    return db.insert('offline_reports', row);
  }

  /// Returns all reports whose [sync_status] is `pending` or `failed`.
  Future<List<Map<String, dynamic>>> getPendingReports() async {
    final db = await database;
    return db.query(
      'offline_reports',
      where: "sync_status = ? OR sync_status = ?",
      whereArgs: ['pending', 'failed'],
      orderBy: 'created_at DESC',
    );
  }

  /// Returns every report stored locally regardless of sync status.
  Future<List<Map<String, dynamic>>> getAllLocalReports() async {
    final db = await database;
    return db.query(
      'offline_reports',
      orderBy: 'created_at DESC',
    );
  }

  /// Updates the [sync_status] of a local report identified by
  /// [localId]. Optionally stores the [serverId] returned by the API
  /// after a successful sync.
  Future<void> updateSyncStatus(
    int localId,
    String status, {
    int? serverId,
  }) async {
    final db = await database;
    final values = <String, dynamic>{
      'sync_status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (serverId != null) {
      values['server_id'] = serverId;
    }

    await db.update(
      'offline_reports',
      values,
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Permanently removes a local report by its [localId].
  Future<void> deleteLocalReport(int localId) async {
    final db = await database;
    await db.delete(
      'offline_reports',
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Returns the number of reports that still need to be synced
  /// (`pending` or `failed`).
  Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM offline_reports "
      "WHERE sync_status = 'pending' OR sync_status = 'failed'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Deletes all reports that have already been synced successfully.
  Future<void> clearSyncedReports() async {
    final db = await database;
    await db.delete(
      'offline_reports',
      where: "sync_status = ?",
      whereArgs: ['synced'],
    );
  }
}
