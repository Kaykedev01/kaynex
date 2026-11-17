part of '../../main.dart';

class MaintenanceCategory {
  const MaintenanceCategory({
    required this.id,
    required this.label,
    required this.root,
    required this.files,
    required this.bytes,
    required this.preview,
    this.accessError,
  });
  final String id, label, root;
  final int files, bytes;
  final List<String> preview;
  final String? accessError;
}

class MaintenanceResult {
  const MaintenanceResult({
    required this.deleted,
    required this.freedBytes,
    required this.failed,
    required this.examined,
  });
  final int deleted, freedBytes, failed, examined;
}

/// Only known disposable file types, with a category-specific minimum age,
/// are eligible. User downloads and arbitrary unknown files are never listed.
class MaintenanceService {
  static final List<
    ({
      String id,
      String label,
      String root,
      Set<String> extensions,
      Duration age,
      String? prefix,
    })
  >
  _definitions = [
    (
      id: 'user_temp',
      label: 'Temporários do usuário',
      root: Platform.environment['TEMP'] ?? Platform.environment['TMP'] ?? '',
      extensions: {'.tmp', '.temp'},
      age: const Duration(hours: 24),
      prefix: null,
    ),
    (
      id: 'windows_temp',
      label: 'Temporários do Windows',
      root: '${Platform.environment['WINDIR'] ?? r'C:\Windows'}\\Temp',
      extensions: {'.tmp', '.temp'},
      age: const Duration(days: 7),
      prefix: null,
    ),
    (
      id: 'thumbnails',
      label: 'Cache de miniaturas',
      root:
          '${Platform.environment['LOCALAPPDATA'] ?? ''}\\Microsoft\\Windows\\Explorer',
      extensions: {'.db'},
      age: const Duration(days: 14),
      prefix: 'thumbcache_',
    ),
    (
      id: 'wer_archive',
      label: 'Relatórios antigos de falhas',
      root:
          '${Platform.environment['ProgramData'] ?? ''}\\Microsoft\\Windows\\WER\\ReportArchive',
      extensions: {'.wer', '.dmp', '.mdmp', '.hdmp'},
      age: const Duration(days: 30),
      prefix: null,
    ),
  ];

  Future<List<MaintenanceCategory>> analyze({
    void Function(int visited)? onProgress,
  }) async {
    final results = <MaintenanceCategory>[];
    var visited = 0;
    for (final definition in _definitions) {
      final root = definition.root;
      var files = 0;
      var bytes = 0;
      var accessError = null as String?;
      final preview = <String>[];
      if (root.isEmpty || !await Directory(root).exists()) {
        results.add(
          MaintenanceCategory(
            id: definition.id,
            label: definition.label,
            root: root,
            files: 0,
            bytes: 0,
            preview: const [],
            accessError: 'Diretório indisponível neste computador.',
          ),
        );
        continue;
      }
      try {
        await for (final entry in Directory(
          root,
        ).list(recursive: true, followLinks: false)) {
          visited++;
          if (entry is! File) continue;
          try {
            final stat = await entry.stat();
            if (stat.type != FileSystemEntityType.file ||
                DateTime.now().difference(stat.modified) < definition.age) {
              continue;
            }
            final name = entry.uri.pathSegments.last.toLowerCase();
            final dot = name.lastIndexOf('.');
            final ext = dot < 0 ? '' : name.substring(dot);
            if (!definition.extensions.contains(ext)) continue;
            if (definition.prefix != null &&
                !name.startsWith(definition.prefix!)) {
              continue;
            }
            files++;
            bytes += stat.size;
            if (preview.length < 100) preview.add(entry.path);
          } on FileSystemException {
            // Arquivo em uso ou sem acesso será ignorado.
          }
          if (visited % 100 == 0) onProgress?.call(visited);
        }
      } on FileSystemException catch (error) {
        accessError = error.message;
      }
      results.add(
        MaintenanceCategory(
          id: definition.id,
          label: definition.label,
          root: root,
          files: files,
          bytes: bytes,
          preview: List.unmodifiable(preview),
          accessError: accessError,
        ),
      );
    }
    onProgress?.call(visited);
    return results;
  }

  Future<MaintenanceResult> clean(
    Set<String> categoryIds, {
    void Function(int deleted)? onProgress,
  }) async {
    var examined = 0;
    var deleted = 0;
    var freed = 0;
    var failed = 0;
    for (final definition in _definitions.where(
      (item) => categoryIds.contains(item.id),
    )) {
      if (definition.root.isEmpty) continue;
      try {
        await for (final entry in Directory(
          definition.root,
        ).list(recursive: true, followLinks: false)) {
          examined++;
          if (entry is! File) continue;
          try {
            final stat = await entry.stat();
            if (stat.type != FileSystemEntityType.file ||
                DateTime.now().difference(stat.modified) < definition.age) {
              continue;
            }
            final name = entry.uri.pathSegments.last.toLowerCase();
            final dot = name.lastIndexOf('.');
            final ext = dot < 0 ? '' : name.substring(dot);
            if (!definition.extensions.contains(ext) ||
                (definition.prefix != null &&
                    !name.startsWith(definition.prefix!))) {
              continue;
            }
            final before = stat.size;
            await entry.delete();
            deleted++;
            freed += before;
            if (deleted % 20 == 0) onProgress?.call(deleted);
          } on FileSystemException {
            failed++;
          }
        }
      } on FileSystemException {
        failed++;
      }
    }
    onProgress?.call(deleted);
    return MaintenanceResult(
      deleted: deleted,
      freedBytes: freed,
      failed: failed,
      examined: examined,
    );
  }
}
