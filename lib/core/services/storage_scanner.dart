part of '../../main.dart';

class ScanProgress {
  const ScanProgress({
    required this.files,
    required this.bytes,
    required this.currentPath,
  });
  final int files;
  final int bytes;
  final String currentPath;
}

class DuplicateGroup {
  const DuplicateGroup(this.size, this.paths, this.sha256);
  final int size;
  final List<String> paths;
  final String sha256;
}

class StorageScanResult {
  const StorageScanResult({
    required this.fileCount,
    required this.totalBytes,
    required this.topFiles,
    required this.topDirectories,
    required this.categoryBytes,
    required this.extensionCounts,
    required this.duplicates,
    required this.skipped,
  });
  final int fileCount;
  final int totalBytes;
  final List<MapEntry<String, int>> topFiles;
  final List<MapEntry<String, int>> topDirectories;
  final Map<String, int> categoryBytes;
  final Map<String, int> extensionCounts;
  final List<DuplicateGroup> duplicates;
  final int skipped;
  int get reclaimableBytes => duplicates.fold(
    0,
    (sum, group) => sum + group.size * (group.paths.length - 1),
  );
}

class StorageScanCancelled implements Exception {
  const StorageScanCancelled();
}

/// Incremental scanner: file contents are never buffered; only path metadata,
/// top-N results, directory totals and equal-size duplicate candidates persist.
class StorageScanner {
  bool _cancelled = false;
  void cancel() => _cancelled = true;

  Future<StorageScanResult> scan(
    String root, {
    String? extensionFilter,
    void Function(ScanProgress progress)? onProgress,
  }) async {
    _cancelled = false;
    final base = Directory(root);
    if (!await base.exists()) {
      throw FileSystemException('Diretório não encontrado', root);
    }
    final queue = <Directory>[base];
    final topFiles = <MapEntry<String, int>>[];
    final directoryBytes = <String, int>{};
    final categoryBytes = <String, int>{};
    final extensionCounts = <String, int>{};
    final sizeCandidates = <int, List<String>>{};
    final normalizedExtension = extensionFilter
        ?.trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^\.'), '');
    var fileCount = 0;
    var totalBytes = 0;
    var skipped = 0;
    while (queue.isNotEmpty) {
      if (_cancelled) throw const StorageScanCancelled();
      final directory = queue.removeLast();
      try {
        await for (final entity in directory.list(followLinks: false)) {
          if (_cancelled) throw const StorageScanCancelled();
          if (entity is Directory) {
            queue.add(entity);
            directoryBytes.putIfAbsent(entity.path, () => 0);
            continue;
          }
          if (entity is! File) continue;
          try {
            final stat = await entity.stat();
            if (!stat.type.toString().contains('file')) continue;
            final ext = _extension(entity.path);
            if (normalizedExtension != null &&
                normalizedExtension.isNotEmpty &&
                ext != normalizedExtension) {
              continue;
            }
            final size = stat.size;
            fileCount++;
            totalBytes += size;
            extensionCounts[ext.isEmpty ? '(sem extensão)' : '.$ext'] =
                (extensionCounts[ext.isEmpty ? '(sem extensão)' : '.$ext'] ??
                    0) +
                1;
            final category = _category(ext);
            categoryBytes[category] = (categoryBytes[category] ?? 0) + size;
            _insertTop(topFiles, MapEntry(entity.path, size), 100);
            var parent = File(entity.path).parent;
            while (_within(parent.path, base.path)) {
              directoryBytes[parent.path] =
                  (directoryBytes[parent.path] ?? 0) + size;
              if (_same(parent.path, base.path)) break;
              parent = parent.parent;
            }
            if (size > 0) {
              sizeCandidates
                  .putIfAbsent(size, () => <String>[])
                  .add(entity.path);
            }
            if (fileCount % 100 == 0) {
              onProgress?.call(
                ScanProgress(
                  files: fileCount,
                  bytes: totalBytes,
                  currentPath: entity.path,
                ),
              );
            }
          } on FileSystemException {
            skipped++;
          }
        }
      } on FileSystemException {
        skipped++;
      }
    }
    onProgress?.call(
      ScanProgress(files: fileCount, bytes: totalBytes, currentPath: root),
    );
    final duplicateGroups = <DuplicateGroup>[];
    for (final candidateGroup in sizeCandidates.entries.where(
      (entry) => entry.value.length > 1,
    )) {
      if (_cancelled) throw const StorageScanCancelled();
      final byHash = <String, List<String>>{};
      for (final path in candidateGroup.value) {
        if (_cancelled) throw const StorageScanCancelled();
        try {
          var hashedBytes = 0;
          final stream = File(path).openRead().map((chunk) {
            if (_cancelled) throw const StorageScanCancelled();
            hashedBytes += chunk.length;
            if (hashedBytes % (1024 * 1024) < chunk.length) {
              onProgress?.call(
                ScanProgress(
                  files: fileCount,
                  bytes: totalBytes,
                  currentPath: path,
                ),
              );
            }
            return chunk;
          });
          final digest = await sha256.bind(stream).first;
          byHash.putIfAbsent(digest.toString(), () => <String>[]).add(path);
        } on FileSystemException {
          skipped++;
        }
      }
      for (final entry in byHash.entries.where(
        (entry) => entry.value.length > 1,
      )) {
        duplicateGroups.add(
          DuplicateGroup(
            candidateGroup.key,
            List.unmodifiable(entry.value),
            entry.key,
          ),
        );
      }
    }
    final topDirectories = directoryBytes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return StorageScanResult(
      fileCount: fileCount,
      totalBytes: totalBytes,
      topFiles: List.unmodifiable(topFiles),
      topDirectories: List.unmodifiable(topDirectories.take(100)),
      categoryBytes: Map.unmodifiable(categoryBytes),
      extensionCounts: Map.unmodifiable(extensionCounts),
      duplicates: List.unmodifiable(duplicateGroups),
      skipped: skipped,
    );
  }

  static void _insertTop(
    List<MapEntry<String, int>> rows,
    MapEntry<String, int> item,
    int limit,
  ) {
    final index = rows.indexWhere((row) => row.value < item.value);
    if (index < 0) {
      rows.add(item);
    } else {
      rows.insert(index, item);
    }
    if (rows.length > limit) rows.removeLast();
  }

  static String _extension(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    return dot < 1 ? '' : name.substring(dot + 1).toLowerCase();
  }

  static String _category(String extension) {
    const groups = <String, Set<String>>{
      'Imagens': {
        'jpg',
        'jpeg',
        'png',
        'gif',
        'bmp',
        'webp',
        'svg',
        'tif',
        'tiff',
        'heic',
        'raw',
      },
      'Vídeos': {
        'mp4',
        'mkv',
        'mov',
        'avi',
        'wmv',
        'webm',
        'm4v',
        'mpeg',
        'mpg',
      },
      'Áudios': {'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma', 'opus'},
      'Documentos': {
        'pdf',
        'doc',
        'docx',
        'odt',
        'txt',
        'rtf',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'csv',
      },
      'Compactados': {'zip', '7z', 'rar', 'tar', 'gz', 'bz2', 'xz'},
      'Executáveis': {'exe', 'msi', 'msix', 'appx', 'bat', 'cmd', 'ps1', 'com'},
    };
    for (final entry in groups.entries) {
      if (entry.value.contains(extension)) return entry.key;
    }
    return 'Outros';
  }

  static bool _same(String a, String b) =>
      Platform.isWindows ? a.toLowerCase() == b.toLowerCase() : a == b;
  static bool _within(String candidate, String root) {
    final c = Platform.isWindows ? candidate.toLowerCase() : candidate;
    final r = Platform.isWindows ? root.toLowerCase() : root;
    return c == r ||
        c.startsWith(
          r.endsWith(Platform.pathSeparator)
              ? r
              : '$r${Platform.pathSeparator}',
        );
  }
}
