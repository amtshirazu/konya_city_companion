import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class SavedPlacesDatabase {
  static const String tableName = 'saved_places';
  static const String columnPlaceId = 'place_id';
  static const String columnCreatedAt = 'created_at';
  static const int databaseVersion = 1;

  final DatabaseFactory? databaseFactoryOverride;
  final String dbName;
  Database? _db;

  SavedPlacesDatabase({
    this.databaseFactoryOverride,
    this.dbName = 'konya_companion.db',
    Database? database,
  }) : _db = database;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final factory = databaseFactoryOverride ?? databaseFactory;
    final String path;
    if (dbName == inMemoryDatabasePath) {
      path = inMemoryDatabasePath;
    } else {
      final dbPath = await factory.getDatabasesPath();
      path = p.join(dbPath, dbName);
    }

    return await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        $columnPlaceId TEXT PRIMARY KEY NOT NULL,
        $columnCreatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration handling for future schema updates.
    // Preserves existing data when version increases.
  }

  /// Retrieves all saved place IDs, ordered by creation date descending.
  Future<List<String>> getSavedPlaceIds() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      columns: [columnPlaceId],
      orderBy: '$columnCreatedAt DESC',
    );
    return maps.map((map) => map[columnPlaceId] as String).toList();
  }

  /// Checks whether a given place ID is saved in the database.
  Future<bool> isSaved(String placeId) async {
    final db = await database;
    final result = await db.query(
      tableName,
      columns: [columnPlaceId],
      where: '$columnPlaceId = ?',
      whereArgs: [placeId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Saves a place ID. Uses PRIMARY KEY constraint with REPLACE algorithm to prevent duplicates.
  Future<void> savePlace(String placeId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert(tableName, {
      columnPlaceId: placeId,
      columnCreatedAt: now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Removes a saved place ID from the database.
  Future<void> removePlace(String placeId) async {
    final db = await database;
    await db.delete(
      tableName,
      where: '$columnPlaceId = ?',
      whereArgs: [placeId],
    );
  }

  /// Clears all saved places from the database.
  Future<void> clearAll() async {
    final db = await database;
    await db.delete(tableName);
  }

  /// Closes the database connection safely.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
