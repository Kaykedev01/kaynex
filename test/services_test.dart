import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaynex/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'SQLite persists preferences, operations, and filtered history',
    () async {
      final directory = await Directory.systemTemp.createTemp('kaynex-db-');
      final path = '${directory.path}${Platform.pathSeparator}kaynex.sqlite';
      var store = await LocalStore.openAt(path);
      await store.setPreference('theme', 'light');
      await store.log('Sistema', 'Monitoramento iniciado', 'teste');
      await store.recordNetwork(
        mode: 'DNS',
        target: 'example.test',
        summary: '192.0.2.1',
        result: 'Sucesso',
      );
      await store.recordFileOperation(
        operation: 'Mover',
        source: 'a',
        destination: 'b',
        details: 'a → b',
      );
      final rows = await store.activities(
        category: 'Rede',
        query: 'example',
        from: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(rows, hasLength(1));
      expect(rows.single['module'], 'Rede');
      expect((await store.networkHistory()).single['mode'], 'DNS');
      expect(
        (await store.db.query('file_operations')).single['destination'],
        'b',
      );
      await store.close();
      store = await LocalStore.openAt(path);
      expect(await store.preference('theme'), 'light');
      expect(await store.activities(), hasLength(3));
      await store.close();
      await directory.delete(recursive: true);
    },
  );

  test('SQLite migrates the previous activity schema to version 2', () async {
    final directory = await Directory.systemTemp.createTemp(
      'kaynex-migration-',
    );
    final path = '${directory.path}${Platform.pathSeparator}old.sqlite';
    final old = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE activities(id INTEGER PRIMARY KEY AUTOINCREMENT, category TEXT NOT NULL, title TEXT NOT NULL, details TEXT NOT NULL, result TEXT NOT NULL, created_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE preferences(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.insert('activities', {
          'category': 'Rede',
          'title': 'Ping antigo',
          'details': '127.0.0.1',
          'result': 'Sucesso',
          'created_at': DateTime.now().toIso8601String(),
        });
      },
    );
    await old.close();
    final migrated = await LocalStore.openAt(path);
    final rows = await migrated.activities();
    expect(rows.single['module'], 'Rede');
    expect(rows.single['type'], 'Rede');
    expect(
      await migrated.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='network_diagnostics'",
      ),
      hasLength(1),
    );
    await migrated.close();
    await directory.delete(recursive: true);
  });

  test(
    'SQLite backup restore validates and restores a consistent snapshot',
    () async {
      final directory = await Directory.systemTemp.createTemp('kaynex-backup-');
      final path = '${directory.path}${Platform.pathSeparator}kaynex.sqlite';
      final backup = '${directory.path}${Platform.pathSeparator}backup.sqlite';
      final store = await LocalStore.openAt(path);
      await store.log('Sistema', 'Antes do backup', 'mantido');
      await store.backupTo(backup);
      await store.log('Sistema', 'Depois do backup', 'será revertido');
      await store.restoreFrom(backup);
      final rows = await store.activities();
      expect(rows, hasLength(1));
      expect(rows.single['title'], 'Antes do backup');
      await store.close();
      await directory.delete(recursive: true);
    },
  );

  test(
    'storage scanner streams files and confirms duplicates by SHA-256',
    () async {
      final directory = await Directory.systemTemp.createTemp('kaynex-scan-');
      final root = Directory('${directory.path}${Platform.pathSeparator}source')
        ..createSync();
      await File('${root.path}${Platform.pathSeparator}one.txt')
          .writeAsString('same text');
      await File('${root.path}${Platform.pathSeparator}two.txt')
          .writeAsString('same text');
      await File('${root.path}${Platform.pathSeparator}other.txt')
          .writeAsString('other txt');
      final result = await StorageScanner().scan(root.path);
      expect(result.fileCount, 3);
      expect(result.duplicates, hasLength(1));
      expect(result.duplicates.single.paths, hasLength(2));
      expect(result.reclaimableBytes, 9);
      expect(result.categoryBytes['Documentos'], 27);
      await directory.delete(recursive: true);
    },
  );

  test('file operations copy, rename, move, and delete only confirmed paths', () async {
    final directory = await Directory.systemTemp.createTemp('kaynex-files-');
    final root = Directory('${directory.path}${Platform.pathSeparator}root')
      ..createSync();
    final target = Directory('${directory.path}${Platform.pathSeparator}target')
      ..createSync();
    final source = '${root.path}${Platform.pathSeparator}source.txt';
    await File(source).writeAsString('KAYNEX');
    final copied = '${target.path}${Platform.pathSeparator}copy.txt';
    expect(await FileOperations.copy(source, copied), 6);
    final renamed = await FileOperations.rename(copied, 'renamed.txt');
    expect(await File(renamed).readAsString(), 'KAYNEX');
    final moved = '${root.path}${Platform.pathSeparator}moved.txt';
    await FileOperations.move(renamed, moved);
    expect(await File(moved).exists(), isTrue);
    expect(await FileOperations.delete(moved), 1);
    await expectLater(
      FileOperations.createDirectory(
        '${root.path}${Platform.pathSeparator}..${Platform.pathSeparator}unsafe',
      ),
      throwsA(isA<FileSystemException>()),
    );
    await directory.delete(recursive: true);
  });

  test(
    'network diagnostic validators reject unsafe input before starting tools',
    () async {
      await expectLater(
        WindowsService.pingMany('127.0.0.1', 21),
        throwsArgumentError,
      );
      await expectLater(
        WindowsService.dns('invalid host'),
        throwsArgumentError,
      );
      await expectLater(
        WindowsService.tcpTest('127.0.0.1', 0),
        throwsArgumentError,
      );
    },
  );
}
