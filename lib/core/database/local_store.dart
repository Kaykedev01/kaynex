part of '../../main.dart';

class LocalStore {
  LocalStore(this.path, this.db);
  final String path;
  Database db;

  static Future<LocalStore> open() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}KAYNEX');
    await dir.create(recursive: true);
    final path = '${dir.path}${Platform.pathSeparator}kaynex.sqlite';
    return openAt(path);
  }

  static Future<LocalStore> openAt(String path) async {
    final db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE activities(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT NOT NULL, title TEXT NOT NULL, details TEXT NOT NULL,
          result TEXT NOT NULL, created_at TEXT NOT NULL,
          module TEXT NOT NULL, type TEXT NOT NULL)''');
        await db.execute(
          'CREATE INDEX activities_created_at ON activities(created_at)',
        );
        await _createOperationalTables(db);
        await db.execute('''CREATE TABLE preferences(
          key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
        await db.insert('preferences', {'key': 'theme', 'value': 'dark'});
        await db.insert('preferences', {'key': 'refreshSeconds', 'value': '5'});
        await db.insert('preferences', {'key': 'maxHistory', 'value': '5000'});
        await db.insert('preferences', {'key': 'accent', 'value': '9BCB75'});
        await db.insert('preferences', {'key': 'homePage', 'value': '0'});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE activities ADD COLUMN module TEXT NOT NULL DEFAULT 'Sistema'",
          );
          await db.execute(
            "ALTER TABLE activities ADD COLUMN type TEXT NOT NULL DEFAULT 'Operação'",
          );
          await db.execute(
            'UPDATE activities SET module = category, type = category',
          );
          await _createOperationalTables(db);
        }
      },
    );
    return LocalStore(path, db);
  }

  static Future<void> _createOperationalTables(DatabaseExecutor db) async {
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS network_diagnostics(
      id INTEGER PRIMARY KEY AUTOINCREMENT, mode TEXT NOT NULL, target TEXT NOT NULL,
      summary TEXT NOT NULL, result TEXT NOT NULL, created_at TEXT NOT NULL)''',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS network_diagnostics_date ON network_diagnostics(created_at)',
    );
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS file_operations(
      id INTEGER PRIMARY KEY AUTOINCREMENT, operation TEXT NOT NULL, source TEXT NOT NULL,
      destination TEXT, details TEXT NOT NULL, result TEXT NOT NULL, created_at TEXT NOT NULL)''',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS file_operations_date ON file_operations(created_at)',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS maintenance_runs(
      id INTEGER PRIMARY KEY AUTOINCREMENT, categories TEXT NOT NULL, examined_count INTEGER NOT NULL,
      deleted_count INTEGER NOT NULL, freed_bytes INTEGER NOT NULL, result TEXT NOT NULL,
      created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS organization_rules(
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, extension TEXT NOT NULL,
      destination TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 1)''');
  }

  Future<void> log(
    String category,
    String title,
    String details, {
    String result = 'Concluído',
    String? type,
  }) async {
    await db.insert('activities', {
      'category': category,
      'module': category,
      'type': type ?? title,
      'title': title,
      'details': details,
      'result': result,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _applyHistoryLimit();
  }

  Future<List<Map<String, Object?>>> activities({
    String? category,
    String? query,
    DateTime? from,
    DateTime? to,
    bool descending = true,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (category != null && category != 'Todas') {
      where.add('category = ?');
      args.add(category);
    }
    if (query != null && query.trim().isNotEmpty) {
      where.add('(title LIKE ? OR details LIKE ?)');
      args.addAll(['%${query.trim()}%', '%${query.trim()}%']);
    }
    if (from != null) {
      where.add('created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('created_at < ?');
      args.add(to.add(const Duration(days: 1)).toIso8601String());
    }
    return db.query(
      'activities',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at ${descending ? 'DESC' : 'ASC'}',
      limit: 300,
    );
  }

  Future<String> preference(String key, [String fallback = '']) async {
    final rows = await db.query(
      'preferences',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? fallback : rows.first['value']! as String;
  }

  Future<void> setPreference(String key, String value) => db.insert(
    'preferences',
    {'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  Future<void> clearActivities() => db.delete('activities');
  Future<void> close() => db.close();

  Future<void> deleteActivities({
    String? category,
    DateTime? after,
    DateTime? before,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }
    if (after != null) {
      where.add('created_at >= ?');
      args.add(after.toIso8601String());
    }
    if (before != null) {
      where.add('created_at < ?');
      args.add(before.toIso8601String());
    }
    if (where.isEmpty) {
      await clearActivities();
      return;
    }
    await db.delete('activities', where: where.join(' AND '), whereArgs: args);
  }

  Future<void> trimHistory(int maxRows) async {
    if (maxRows < 0) return;
    await db.execute(
      'DELETE FROM activities WHERE id NOT IN (SELECT id FROM activities ORDER BY created_at DESC LIMIT ?)',
      [maxRows],
    );
  }

  Future<void> _applyHistoryLimit() async {
    final limit = int.tryParse(await preference('maxHistory', '5000')) ?? 5000;
    await trimHistory(limit.clamp(100, 100000));
  }

  Future<void> recordNetwork({
    required String mode,
    required String target,
    required String summary,
    required String result,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('network_diagnostics', {
        'mode': mode,
        'target': target,
        'summary': summary,
        'result': result,
        'created_at': now,
      });
      await txn.insert('activities', {
        'category': 'Rede',
        'module': 'Rede',
        'type': mode,
        'title': '$mode · $target',
        'details': summary,
        'result': result,
        'created_at': now,
      });
    });
    await _applyHistoryLimit();
  }

  Future<List<Map<String, Object?>>> networkHistory({int limit = 100}) =>
      db.query('network_diagnostics', orderBy: 'created_at DESC', limit: limit);

  Future<void> recordFileOperation({
    required String operation,
    required String source,
    String? destination,
    required String details,
    String result = 'Concluído',
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('file_operations', {
        'operation': operation,
        'source': source,
        'destination': destination,
        'details': details,
        'result': result,
        'created_at': now,
      });
      await txn.insert('activities', {
        'category': 'Arquivos',
        'module': 'Arquivos',
        'type': operation,
        'title': operation,
        'details': details,
        'result': result,
        'created_at': now,
      });
    });
    await _applyHistoryLimit();
  }

  Future<void> recordMaintenance({
    required List<String> categories,
    required int examined,
    required int deleted,
    required int freedBytes,
    required String result,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('maintenance_runs', {
        'categories': categories.join(','),
        'examined_count': examined,
        'deleted_count': deleted,
        'freed_bytes': freedBytes,
        'result': result,
        'created_at': now,
      });
      await txn.insert('activities', {
        'category': 'Sistema',
        'module': 'Sistema',
        'type': 'Limpeza',
        'title': 'Limpeza seletiva',
        'details': '$deleted arquivos · $freedBytes bytes liberados',
        'result': result,
        'created_at': now,
      });
    });
    await _applyHistoryLimit();
  }

  Future<void> backupTo(String destination) async {
    if (FileOperations._samePath(destination, path)) {
      throw ArgumentError('O destino do backup é o banco ativo.');
    }
    if (await File(destination).exists()) {
      throw FileSystemException(
        'O destino já existe; escolha outro caminho.',
        destination,
      );
    }
    await db.execute('PRAGMA wal_checkpoint(FULL)');
    await File(path).copy(destination);
  }

  Future<void> restoreFrom(String source) async {
    final file = File(source);
    if (FileOperations._samePath(source, path)) {
      throw ArgumentError('O caminho informado é o banco ativo.');
    }
    if (!await file.exists()) {
      throw const FileSystemException('Arquivo de backup não encontrado.');
    }
    final handle = await file.open();
    final header = await handle.read(16);
    await handle.close();
    if (String.fromCharCodes(header) != 'SQLite format 3\u0000') {
      throw const FormatException(
        'O arquivo selecionado não é um banco SQLite válido.',
      );
    }
    final staged = File('$path.restore');
    if (await staged.exists()) await staged.delete();
    await file.copy(staged.path);
    final validation = await _openForRestore(staged.path);
    try {
      final integrity = await validation.rawQuery('PRAGMA quick_check');
      final tables = await validation.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('activities','preferences')",
      );
      final activityColumns = (await validation.rawQuery(
        'PRAGMA table_info(activities)',
      )).map((row) => row['name']).toSet();
      final preferenceColumns = (await validation.rawQuery(
        'PRAGMA table_info(preferences)',
      )).map((row) => row['name']).toSet();
      const requiredActivityColumns = {
        'id',
        'category',
        'module',
        'type',
        'title',
        'details',
        'result',
        'created_at',
      };
      const requiredPreferenceColumns = {'key', 'value'};
      if (integrity.isEmpty ||
          integrity.first.values.first != 'ok' ||
          tables.length != 2 ||
          !activityColumns.containsAll(requiredActivityColumns) ||
          !preferenceColumns.containsAll(requiredPreferenceColumns)) {
        throw const FormatException('O arquivo não é um banco KAYNEX íntegro.');
      }
    } finally {
      await validation.close();
    }
    await db.close();
    var originalMoved = false;
    var restoredFileInstalled = false;
    final previous = File('$path.previous');
    try {
      final current = File(path);
      if (await previous.exists()) await previous.delete();
      if (await current.exists()) {
        await current.rename(previous.path);
        originalMoved = true;
      }
      await staged.rename(path);
      restoredFileInstalled = true;
      db = await _openForRestore(path);
      if (await previous.exists()) await previous.delete();
    } catch (_) {
      try {
        await db.close();
      } catch (_) {
        // O handle original já estava fechado ou a nova conexão não abriu.
      }
      if (restoredFileInstalled && await File(path).exists()) {
        await File(path).delete();
      }
      if (originalMoved && await previous.exists()) {
        await previous.rename(path);
      }
      db = await _openForRestore(path);
      rethrow;
    }
  }

  static Future<Database> _openForRestore(String path) => openDatabase(
    path,
    version: 2,
    onUpgrade: (database, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await database.execute(
          "ALTER TABLE activities ADD COLUMN module TEXT NOT NULL DEFAULT 'Sistema'",
        );
        await database.execute(
          "ALTER TABLE activities ADD COLUMN type TEXT NOT NULL DEFAULT 'Operação'",
        );
        await database.execute(
          'UPDATE activities SET module = category, type = category',
        );
        await _createOperationalTables(database);
      }
    },
  );
}
