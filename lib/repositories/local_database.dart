import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/report.dart';

/// Android : SQLite.
/// Chrome : stockage local de demonstration.
class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();
  static const String _webKey = 'road_alert_v2_reports_web';

  Database? _db;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite natif non disponible sur Chrome.',
      );
    }

    if (_db != null) {
      return _db!;
    }

    final file = p.join(
      await getDatabasesPath(),
      'road_alert_v2.db',
    );

    _db = await openDatabase(
      file,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE local_reports (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            gps_accuracy REAL NOT NULL,
            type TEXT NOT NULL,
            severity TEXT NOT NULL,
            comment TEXT NOT NULL,
            photo_path TEXT NOT NULL,
            status_local TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            created_at TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL,
            synced_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_local_sync '
          'ON local_reports(status_local)',
        );
      },
    );

    return _db!;
  }

  /// Lire tous les signalements.
  Future<List<RoadReport>> all() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final jsonText = prefs.getString(_webKey);

      if (jsonText == null || jsonText.isEmpty) {
        return [];
      }

      final entries = jsonDecode(jsonText) as List<dynamic>;

      final reports = entries.map((entry) {
        return RoadReport.fromMap(
          Map<String, dynamic>.from(entry as Map),
        );
      }).toList();

      reports.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      return reports;
    }

    final db = await database;

    final rows = await db.query(
      'local_reports',
      orderBy: 'created_at DESC',
    );

    return rows.map(RoadReport.fromMap).toList();
  }

  /// Enregistrer ou mettre a jour un signalement.
  Future<void> save(RoadReport report) async {
    if (kIsWeb) {
      final reports = await all();

      reports.removeWhere((item) => item.id == report.id);
      reports.insert(0, report);

      final prefs = await SharedPreferences.getInstance();

      final ok = await prefs.setString(
        _webKey,
        jsonEncode(
          reports.map((item) => item.toMap()).toList(),
        ),
      );

      if (!ok) {
        throw StateError('Echec de sauvegarde navigateur.');
      }

      return;
    }

    final db = await database;

    await db.insert(
      'local_reports',
      report.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Supprimer un signalement.
  Future<void> delete(String id) async {
    if (kIsWeb) {
      final reports = await all();

      reports.removeWhere((item) => item.id == id);

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _webKey,
        jsonEncode(
          reports.map((item) => item.toMap()).toList(),
        ),
      );

      return;
    }

    final db = await database;

    await db.delete(
      'local_reports',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
