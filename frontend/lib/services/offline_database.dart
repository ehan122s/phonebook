import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// SQLite database helper for storing reports and caching templates offline.
///
/// Uses a singleton pattern so the database is opened only once and
/// shared across the entire application.
class OfflineDatabase {
  OfflineDatabase._();

  static final OfflineDatabase instance = OfflineDatabase._();
  static bool _ffiInitialized = false;

  Database? _database;

  /// Returns the singleton [Database] instance, creating the database
  /// and table on first access.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      if (!_ffiInitialized) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        _ffiInitialized = true;
      }
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'phonebook_offline.db');

    return openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
              'ALTER TABLE offline_reports ADD COLUMN photo_path TEXT',
            );
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute(
              'ALTER TABLE offline_reports ADD COLUMN photo_base64 TEXT',
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE offline_reports ADD COLUMN address TEXT',
            );
          } catch (_) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS offline_report_templates (
                id TEXT PRIMARY KEY,
                name TEXT,
                category TEXT,
                description TEXT,
                template_body TEXT,
                fields_config TEXT,
                placeholders TEXT,
                icon_key TEXT,
                default_title TEXT,
                require_photo INTEGER,
                require_location INTEGER,
                is_active INTEGER,
                updated_at TEXT
              )
            ''');
          } catch (_) {}
        }
        if (oldVersion < 5) {
          try {
            await db.execute(
              'ALTER TABLE offline_reports ADD COLUMN document_path TEXT',
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE offline_reports ADD COLUMN document_name TEXT',
            );
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE offline_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        activity_date TEXT NOT NULL,
        location TEXT NOT NULL,
        address TEXT,
        description TEXT,
        latitude REAL,
        longitude REAL,
        category_id INTEGER,
        status TEXT DEFAULT 'draft',
        jenis_laporan TEXT,
        sync_status TEXT DEFAULT 'pending',
        server_id INTEGER,
        photo_path TEXT,
        photo_base64 TEXT,
        document_path TEXT,
        document_name TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_report_templates (
        id TEXT PRIMARY KEY,
        name TEXT,
        category TEXT,
        description TEXT,
        template_body TEXT,
        fields_config TEXT,
        placeholders TEXT,
        icon_key TEXT,
        default_title TEXT,
        require_photo INTEGER,
        require_location INTEGER,
        is_active INTEGER,
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
      'address': data['address'],
      'description': data['description'],
      'latitude': data['latitude'],
      'longitude': data['longitude'],
      'category_id': data['category_id'],
      'status': data['status'] ?? 'draft',
      'jenis_laporan': data['jenis_laporan'],
      'sync_status': data['sync_status'] ?? 'pending',
      'server_id': data['server_id'],
      'photo_path': data['photo_path'],
      'photo_base64': data['photo_base64'],
      'document_path': data['document_path'],
      'document_name': data['document_name'],
      'created_at': data['created_at'] ?? now,
      'updated_at': now,
    };

    return db.insert('offline_reports', row);
  }

  /// Returns all reports whose [sync_status] is `pending` or `failed`.
  Future<List<Map<String, dynamic>>> getPendingReports() async {
    try {
      final db = await database;
      return await db.query(
        'offline_reports',
        where: "sync_status = ? OR sync_status = ? OR sync_status = ?",
        whereArgs: ['pending', 'failed', 'attachment_pending'],
        orderBy: 'created_at DESC',
      );
    } catch (_) {
      return [];
    }
  }

  /// Returns every report stored locally regardless of sync status.
  Future<List<Map<String, dynamic>>> getAllLocalReports() async {
    try {
      final db = await database;
      return await db.query(
        'offline_reports',
        orderBy: 'created_at DESC',
      );
    } catch (_) {
      return [];
    }
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
    try {
      final db = await database;
      final result = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM offline_reports "
        "WHERE sync_status = 'pending' OR sync_status = 'failed' OR sync_status = 'attachment_pending'",
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (_) {
      return 0;
    }
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

  /// Menyimpan seluruh template laporan ke tabel SQLite lokal untuk keperluan offline.
  Future<void> cacheTemplates(List<Map<String, dynamic>> templates) async {
    try {
      final db = await database;
      final batch = db.batch();
      for (final t in templates) {
        final id = (t['id'] ?? '').toString();
        if (id.isEmpty) continue;
        batch.insert(
          'offline_report_templates',
          {
            'id': id,
            'name': t['name'] ?? t['title'] ?? '',
            'category': t['category'] ?? '',
            'description': t['description'] ?? '',
            'template_body': t['template_body'] ?? t['templateBody'] ?? t['body'] ?? '',
            'fields_config': jsonEncode(t['fields_config'] ?? t['fieldsConfig'] ?? []),
            'placeholders': jsonEncode(t['placeholders'] ?? []),
            'icon_key': t['icon_key'] ?? t['iconKey'] ?? '',
            'default_title': t['default_title'] ?? t['defaultTitle'] ?? '',
            'require_photo': (t['require_photo'] == true || t['requirePhoto'] == true) ? 1 : 0,
            'require_location': (t['require_location'] == true || t['requireLocation'] == true) ? 1 : 0,
            'is_active': (t['is_active'] == false) ? 0 : 1,
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('OfflineDatabase cacheTemplates error: $e');
    }
  }

  /// Mengambil daftar template laporan terakhir yang tersimpan di SQLite.
  Future<List<Map<String, dynamic>>> getCachedTemplates() async {
    try {
      final db = await database;
      final rows = await db.query('offline_report_templates', orderBy: 'id ASC');
      if (rows.isEmpty) return [];

      return rows.map<Map<String, dynamic>>((row) {
        List<dynamic> fieldsConfig = [];
        List<dynamic> placeholders = [];
        try {
          if (row['fields_config'] != null) {
            fieldsConfig = jsonDecode(row['fields_config'].toString());
          }
        } catch (_) {}
        try {
          if (row['placeholders'] != null) {
            placeholders = jsonDecode(row['placeholders'].toString());
          }
        } catch (_) {}

        return {
          'id': row['id'],
          'name': row['name'],
          'title': row['name'],
          'category': row['category'],
          'description': row['description'],
          'template_body': row['template_body'],
          'templateBody': row['template_body'],
          'fields_config': fieldsConfig,
          'fieldsConfig': fieldsConfig,
          'placeholders': placeholders,
          'icon_key': row['icon_key'],
          'iconKey': row['icon_key'],
          'default_title': row['default_title'],
          'defaultTitle': row['default_title'],
          'require_photo': row['require_photo'] == 1,
          'requirePhoto': row['require_photo'] == 1,
          'require_location': row['require_location'] == 1,
          'requireLocation': row['require_location'] == 1,
          'is_active': row['is_active'] == 1,
        };
      }).toList();
    } catch (e) {
      debugPrint('OfflineDatabase getCachedTemplates error: $e');
      return [];
    }
  }
}