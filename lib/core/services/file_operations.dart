part of '../../main.dart';

class FileOperations {
  static final List<String> _protectedRoots = [
    Platform.environment['WINDIR'],
    Platform.environment['ProgramFiles'],
    Platform.environment['ProgramFiles(x86)'],
    Platform.environment['ProgramData'],
  ].whereType<String>().map(_normalize).toList();

  static String _normalize(String value) {
    final absolute = File(value).absolute.path.replaceAll('/', '\\');
    final drive = RegExp(r'^[a-zA-Z]:').firstMatch(absolute)?.group(0) ?? '';
    final rooted = absolute.startsWith('\\');
    final parts = <String>[];
    for (final part in absolute.substring(drive.length).split('\\')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isNotEmpty && parts.last != '..') {
          parts.removeLast();
        } else if (!rooted && drive.isEmpty) {
          parts.add(part);
        }
      } else {
        parts.add(part);
      }
    }
    return '${drive.toLowerCase()}${rooted ? '\\' : ''}${parts.join('\\')}'
        .replaceFirst(RegExp(r'\\+$'), '')
        .toLowerCase();
  }

  static bool _inside(String path, String root) {
    final p = _normalize(path);
    final r = _normalize(root);
    return p == r || p.startsWith('$r\\');
  }

  static void _guard(String path) {
    if (RegExp(r'(^|[/\\])\.\.([/\\]|$)').hasMatch(path)) {
      throw FileSystemException(
        'Caminhos com segmentos .. são bloqueados para operações.',
        path,
      );
    }
    final systemDrive = Platform.environment['SystemDrive'] ?? 'C:';
    if (_normalize(path) == _normalize('$systemDrive\\') ||
        _protectedRoots.any((root) => _inside(path, root))) {
      throw FileSystemException(
        'Operações nesta localização protegida pelo Windows são bloqueadas.',
        path,
      );
    }
  }

  static Future<void> createDirectory(String path) async {
    final name = path.split(RegExp(r'[/\\]')).last;
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.contains(RegExp(r'[<>:"/\\|?*]')) ||
        name.endsWith('.') ||
        name.endsWith(' ')) {
      throw ArgumentError('Nome de pasta inválido.');
    }
    _guard(path);
    await _rejectLinkAncestors(path);
    final directory = Directory(path);
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Já existe um arquivo ou pasta com esse nome.',
        path,
      );
    }
    await directory.create(recursive: false);
  }

  static Future<void> ensureDirectory(String path) async {
    _guard(path);
    await _rejectLinkAncestors(path);
    await Directory(path).create(recursive: true);
  }

  static Future<void> validatePath(String path) async {
    _guard(path);
    await _rejectLinkAncestors(path);
  }

  static Future<String> rename(String source, String newName) async {
    _guard(source);
    if (newName.trim().isEmpty ||
        newName.contains(RegExp(r'[<>:"/\\|?*]')) ||
        newName.endsWith('.') ||
        newName.endsWith(' ') ||
        RegExp(
          r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$',
          caseSensitive: false,
        ).hasMatch(newName)) {
      throw ArgumentError('Nome de arquivo inválido.');
    }
    final entity = FileSystemEntity.isDirectorySync(source)
        ? Directory(source)
        : File(source);
    final destination =
        '${entity.parent.path}${Platform.pathSeparator}${newName.trim()}';
    _guard(destination);
    if (await FileSystemEntity.type(destination, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('O destino já existe.', destination);
    }
    await _rejectLinkAncestors(source);
    await entity.rename(destination);
    return destination;
  }

  static Future<int> copy(
    String source,
    String destination, {
    void Function(int bytes)? onProgress,
  }) async {
    _guard(source);
    _guard(destination);
    await _rejectLinkAncestors(source);
    await _rejectLinkAncestors(destination);
    if (await FileSystemEntity.type(destination, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('O destino já existe.', destination);
    }
    if (_inside(destination, source)) {
      throw FileSystemException(
        'Uma pasta não pode ser copiada para dentro dela mesma.',
        destination,
      );
    }
    var bytes = 0;
    await _copyEntity(source, destination, (chunk) {
      bytes += chunk;
      onProgress?.call(bytes);
    });
    return bytes;
  }

  static Future<void> move(
    String source,
    String destination, {
    void Function(int bytes)? onProgress,
  }) async {
    _guard(source);
    _guard(destination);
    await _rejectLinkAncestors(source);
    await _rejectLinkAncestors(destination);
    if (await FileSystemEntity.type(destination, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('O destino já existe.', destination);
    }
    if (_inside(destination, source)) {
      throw FileSystemException(
        'Uma pasta não pode ser movida para dentro dela mesma.',
        destination,
      );
    }
    final type = await FileSystemEntity.type(source, followLinks: false);
    try {
      if (type == FileSystemEntityType.directory) {
        await Directory(source).rename(destination);
      } else if (type == FileSystemEntityType.file) {
        await File(source).rename(destination);
      } else if (type == FileSystemEntityType.link) {
        await Link(source).rename(destination);
      } else {
        throw FileSystemException('O item de origem não existe.', source);
      }
    } on FileSystemException {
      await copy(source, destination, onProgress: onProgress);
      await delete(source, onProgress: (_) {});
    }
  }

  static Future<int> delete(
    String path, {
    void Function(int count)? onProgress,
  }) async {
    _guard(path);
    await _rejectLinkAncestors(path);
    var count = 0;
    await _deleteEntity(path, (removed) {
      count += removed;
      onProgress?.call(count);
    });
    return count;
  }

  static Future<void> _copyEntity(
    String source,
    String destination,
    void Function(int) onChunk,
  ) async {
    if (await FileSystemEntity.type(destination, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('O destino já existe.', destination);
    }
    final type = await FileSystemEntity.type(source, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw FileSystemException('Links simbólicos não são copiados.', source);
    }
    if (type == FileSystemEntityType.directory) {
      await Directory(destination).create(recursive: false);
      await for (final child in Directory(source).list(followLinks: false)) {
        await _copyEntity(
          child.path,
          '${Directory(destination).path}${Platform.pathSeparator}${child.uri.pathSegments.where((part) => part.isNotEmpty).last}',
          onChunk,
        );
      }
      return;
    }
    if (type != FileSystemEntityType.file) {
      throw FileSystemException('Arquivo de origem indisponível.', source);
    }
    final output = File(destination).openWrite(mode: FileMode.write);
    try {
      await for (final chunk in File(source).openRead()) {
        output.add(chunk);
        onChunk(chunk.length);
      }
      await output.flush();
    } catch (_) {
      await output.close();
      try {
        await File(destination).delete();
      } on FileSystemException {
        // Preserva o erro original da cópia.
      }
      rethrow;
    }
    await output.close();
  }

  static Future<void> _deleteEntity(
    String path,
    void Function(int) onRemoved,
  ) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await for (final child in Directory(path).list(followLinks: false)) {
        await _deleteEntity(child.path, onRemoved);
      }
      await Directory(path).delete();
    } else if (type == FileSystemEntityType.link) {
      await Link(path).delete();
    } else if (type == FileSystemEntityType.file) {
      await File(path).delete();
    } else {
      throw FileSystemException('O item não existe mais.', path);
    }
    onRemoved(1);
  }

  static Future<void> _rejectLinkAncestors(String path) async {
    var current = Directory(File(path).absolute.path);
    while (true) {
      if (await FileSystemEntity.type(current.path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw FileSystemException(
          'A operação em um caminho com link simbólico foi bloqueada.',
          current.path,
        );
      }
      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
  }

  static bool _samePath(String left, String right) =>
      _normalize(left) == _normalize(right);
}
