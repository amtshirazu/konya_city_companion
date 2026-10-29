import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Database service for GTFS transit queries on `konya_gtfs.db`.
class GtfsDatabase {
  GtfsDatabase({
    DatabaseFactory? databaseFactory,
    this.dbName = 'konya_gtfs.db',
  }) : _dbFactory = databaseFactory;

  final DatabaseFactory? _dbFactory;
  final String dbName;
  Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path;
    if (kIsWeb) {
      throw UnsupportedError(
        'GTFS SQLite database is not supported on web platform.',
      );
    } else if (Platform.isAndroid || Platform.isIOS) {
      final docDir = await getApplicationDocumentsDirectory();
      path = p.join(docDir.path, dbName);

      // Copy from asset bundle if database file does not exist on device
      if (!await File(path).exists()) {
        try {
          final data = await rootBundle.load('assets/gtfs/konya_gtfs.db');
          final bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          await File(path).writeAsBytes(bytes, flush: true);
        } catch (e) {
          debugPrint('Notice: GTFS database asset copy warning: $e');
        }
      }
    } else {
      // Desktop / Test environment
      const rootDbPath = 'konya_gtfs.db';
      if (await File(rootDbPath).exists()) {
        path = File(rootDbPath).absolute.path;
      } else {
        try {
          final sysTemp = await getTemporaryDirectory();
          path = p.join(sysTemp.path, dbName);
        } catch (_) {
          path = p.join(Directory.systemTemp.path, dbName);
        }

        if (!await File(path).exists()) {
          try {
            final data = await rootBundle.load('assets/gtfs/konya_gtfs.db');
            final bytes = data.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            );
            await File(path).writeAsBytes(bytes, flush: true);
          } catch (_) {}
        }
      }
    }

    final factory = _dbFactory ?? databaseFactory;
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true),
    );
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
