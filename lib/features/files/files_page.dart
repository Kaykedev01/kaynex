part of '../../main.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key, required this.store});
  final LocalStore store;
  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  late final TextEditingController _path;
  final _search = TextEditingController();
  final _extension = TextEditingController();
  final _destination = TextEditingController();
  final _renamePrefix = TextEditingController();
  final _ruleExtension = TextEditingController();
  final _ruleDestination = TextEditingController();
  List<Map<String, Object?>> _rules = [];
  List<Map<String, dynamic>> _items = [];
  final Set<String> _selected = {};
  final Set<String> _selectedDuplicates = {};
  final StorageScanner _scanner = StorageScanner();
  StorageScanResult? _scan;
  ScanProgress? _progress;
  String? _error;
  bool _busy = false;
  int _tab = 0;
  int _sort = 0;

  @override
  void initState() {
    super.initState();
    _path = TextEditingController(
      text: Platform.environment['USERPROFILE'] ?? 'C:\\',
    );
    _load();
    _loadRules();
  }

  @override
  void dispose() {
    _path.dispose();
    _search.dispose();
    _extension.dispose();
    _destination.dispose();
    _renamePrefix.dispose();
    _ruleExtension.dispose();
    _ruleDestination.dispose();
    super.dispose();
  }

  Future<void> _load([String? path]) async {
    if (path != null) _path.text = path;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await WindowsService.files(_path.text);
      if (mounted) {
        setState(() {
          _items = rows;
          _selected.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>> get _visibleItems {
    final rows = _items
        .where(
          (item) => (item['name'] as String).toLowerCase().contains(
            _search.text.toLowerCase(),
          ),
        )
        .toList();
    rows.sort((a, b) {
      if (a['directory'] != b['directory']) {
        return (a['directory'] as bool) ? -1 : 1;
      }
      return switch (_sort) {
        1 => (b['size'] as int).compareTo(a['size'] as int),
        2 => (b['modified'] as DateTime).compareTo(a['modified'] as DateTime),
        _ => (a['name'] as String).toLowerCase().compareTo(
          (b['name'] as String).toLowerCase(),
        ),
      };
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Arquivos',
          subtitle: 'Explore, analise e organize seus arquivos locais.',
        ),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.folder_open_rounded),
              label: Text('Explorador'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.pie_chart_outline_rounded),
              label: Text('Armazenamento'),
            ),
            ButtonSegment(
              value: 2,
              icon: Icon(Icons.copy_all_rounded),
              label: Text('Duplicados'),
            ),
            ButtonSegment(
              value: 3,
              icon: Icon(Icons.auto_fix_high_rounded),
              label: Text('Organizar'),
            ),
          ],
          selected: {_tab},
          onSelectionChanged: (value) => setState(() => _tab = value.first),
        ),
        const SizedBox(height: 18),
        if (_tab == 0) _explorer(),
        if (_tab == 1) _storage(),
        if (_tab == 2) _duplicates(),
        if (_tab == 3) _organize(),
      ],
    ),
  );

  Widget _pathField({
    String hint = 'Caminho do diretório',
    VoidCallback? onGo,
  }) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: _path,
          onSubmitted: (_) {
            if (onGo != null) {
              onGo();
            } else {
              _load();
            }
          },
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.folder_open_rounded, size: 18),
            hintText: hint,
          ),
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton(
        onPressed: () => _load(Directory(_path.text).parent.path),
        child: const Icon(Icons.arrow_upward_rounded, size: 17),
      ),
      const SizedBox(width: 8),
      FilledButton(
        onPressed: _busy
            ? null
            : () {
                if (onGo != null) {
                  onGo();
                } else {
                  _load();
                }
              },
        child: const Text('Abrir'),
      ),
    ],
  );

  Widget _explorer() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _pathField(),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                hintText: 'Pesquisar nesta pasta',
              ),
            ),
          ),
          DropdownButton<int>(
            value: _sort,
            items: const [
              DropdownMenuItem(value: 0, child: Text('Nome')),
              DropdownMenuItem(value: 1, child: Text('Maior tamanho')),
              DropdownMenuItem(value: 2, child: Text('Modificados recentes')),
            ],
            onChanged: (value) => setState(() => _sort = value ?? 0),
          ),
          OutlinedButton.icon(
            onPressed: _newFolder,
            icon: const Icon(Icons.create_new_folder_outlined, size: 17),
            label: const Text('Nova pasta'),
          ),
          if (_selected.isNotEmpty) ...[
            OutlinedButton.icon(
              onPressed: _renameSelected,
              icon: const Icon(Icons.drive_file_rename_outline, size: 17),
              label: Text('Renomear (${_selected.length})'),
            ),
            OutlinedButton.icon(
              onPressed: () => _copyOrMove(false),
              icon: const Icon(Icons.copy_rounded, size: 17),
              label: const Text('Copiar'),
            ),
            OutlinedButton.icon(
              onPressed: () => _copyOrMove(true),
              icon: const Icon(Icons.drive_file_move_outline, size: 17),
              label: const Text('Mover'),
            ),
            FilledButton.tonalIcon(
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text('Excluir'),
            ),
          ],
        ],
      ),
      const SizedBox(height: 10),
      if (_error != null) _ErrorBanner(message: _error!, onRetry: _load),
      if (_busy) const LinearProgressIndicator(minHeight: 2),
      Panel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            if (_visibleItems.isEmpty && !_busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Diretório vazio ou sem permissão de leitura.',
                  style: TextStyle(color: _muted),
                ),
              ),
            for (final item in _visibleItems)
              _ManagedFileRow(
                item: item,
                selected: _selected.contains(item['path']),
                onSelect: (selected) => setState(
                  () => selected
                      ? _selected.add(item['path'] as String)
                      : _selected.remove(item['path'] as String),
                ),
                onOpen: () => item['directory'] == true
                    ? _load(item['path'] as String)
                    : _open(item['path'] as String),
                onExplorer: () => _openExplorer(
                  item['path'] as String,
                  item['directory'] == true,
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _storage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _pathField(onGo: _startScan),
      const SizedBox(height: 10),
      Row(
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              controller: _extension,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.filter_alt_outlined, size: 18),
                hintText: 'Extensão, ex.: pdf',
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _startScan,
            icon: const Icon(Icons.manage_search_rounded),
            label: const Text('Analisar pasta'),
          ),
          if (_busy) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _cancel,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar'),
            ),
          ],
        ],
      ),
      if (_progress case final progress?)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 5),
              Text(
                '${progress.files} arquivos · ${bytesLabel(progress.bytes)} · ${progress.currentPath}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
      if (_scan case final summary?) ...[
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _summaryPanel(
              'Arquivos encontrados',
              '${summary.fileCount}',
              '${bytesLabel(summary.totalBytes)} analisados',
            ),
            _summaryPanel(
              'Itens sem acesso',
              '${summary.skipped}',
              'Arquivos/pastas ignorados',
            ),
            _summaryPanel(
              'Potencial duplicado',
              bytesLabel(summary.reclaimableBytes),
              '${summary.duplicates.length} grupos confirmados por SHA-256',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 400,
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PanelHeading(
                      'Distribuição por categoria',
                      'Bytes ocupados por tipos de arquivo',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(height: 230, child: _categoryChart(summary)),
                    for (final entry in summary.categoryBytes.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Text(
                              bytesLabel(entry.value),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 480,
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PanelHeading(
                      'Maiores arquivos',
                      'Top 100 por tamanho',
                    ),
                    const SizedBox(height: 8),
                    for (final entry in summary.topFiles.take(20))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          bytesLabel(entry.value),
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 480,
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PanelHeading(
                      'Maiores diretórios',
                      'Tamanho recursivo aproximado',
                    ),
                    const SizedBox(height: 8),
                    for (final entry in summary.topDirectories.take(20))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          bytesLabel(entry.value),
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ],
  );

  Widget _duplicates() {
    final groups = _scan?.duplicates ?? const <DuplicateGroup>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Localize cópias binariamente idênticas após filtrar pelo tamanho. A análise não remove arquivos.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _startScan,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Analisar diretório atual'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_busy)
          Row(
            children: [
              const Expanded(child: LinearProgressIndicator()),
              TextButton(onPressed: _cancel, child: const Text('Cancelar')),
            ],
          ),
        if (_scan != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${groups.length} grupos · até ${bytesLabel(_scan!.reclaimableBytes)} recuperáveis se selecionados',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ),
        if (_selectedDuplicates.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _deleteDuplicateSelection,
              icon: const Icon(Icons.delete_outline),
              label: Text(
                'Excluir selecionados (${_selectedDuplicates.length})',
              ),
            ),
          ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_scan == null)
                const Text(
                  'Execute uma análise na aba Armazenamento ou neste diretório.',
                  style: TextStyle(color: _muted),
                ),
              if (_scan != null && groups.isEmpty)
                const Text(
                  'Nenhum arquivo duplicado foi encontrado.',
                  style: TextStyle(color: _muted),
                ),
              for (var i = 0; i < groups.length; i++) ...[
                Text(
                  'Grupo ${i + 1} · ${bytesLabel(groups[i].size)} cada · SHA-256 ${groups[i].sha256.substring(0, 12)}…',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final path in groups[i].paths)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _selectedDuplicates.contains(path),
                    onChanged: (value) => setState(
                      () => value == true
                          ? _selectedDuplicates.add(path)
                          : _selectedDuplicates.remove(path),
                    ),
                    title: Text(path, style: const TextStyle(fontSize: 11)),
                    subtitle: Text(
                      bytesLabel(groups[i].size),
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ),
                const Divider(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _organize() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _pathField(onGo: _load),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _destination,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.drive_file_move_outline),
                hintText: 'Diretório destino para a organização',
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _previewOrganization,
            icon: const Icon(Icons.preview_outlined),
            label: const Text('Prévia'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'A prévia agrupa arquivos do diretório atual por extensão em subpastas. Nada é movido até você confirmar.',
        style: TextStyle(color: _muted, fontSize: 11),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelHeading(
              'Regras personalizadas',
              'Uma extensão pode ser direcionada para um diretório escolhido.',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _ruleExtension,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Extensão',
                      hintText: 'pdf',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _ruleDestination,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Diretório destino',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _addRule,
                  child: const Text('Adicionar'),
                ),
              ],
            ),
            for (final rule in _rules)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Switch(
                  value: rule['enabled'] == 1,
                  onChanged: (enabled) =>
                      _toggleRule(rule['id'] as int, enabled),
                ),
                title: Text(
                  '.${rule['extension']} → ${rule['destination']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                  tooltip: 'Remover regra',
                  onPressed: () => _removeRule(rule['id'] as int),
                  icon: const Icon(Icons.close_rounded, size: 17),
                ),
              ),
          ],
        ),
      ),
      if (_organizationPlan.isNotEmpty) ...[
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_organizationPlan.length} itens previstos',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final item in _organizationPlan.entries)
                Text(
                  '${item.key}  →  ${item.value}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, height: 1.8),
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _busy ? null : _executeOrganization,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Confirmar e organizar'),
              ),
            ],
          ),
        ),
      ],
    ],
  );

  final Map<String, String> _organizationPlan = {};

  Widget _summaryPanel(String title, String value, String note) => SizedBox(
    width: 220,
    child: Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(note, style: const TextStyle(color: _muted, fontSize: 10)),
        ],
      ),
    ),
  );

  Widget _categoryChart(StorageScanResult scan) {
    final colors = [
      const Color(0xFF9BCB75),
      const Color(0xFF7BA7D8),
      const Color(0xFFD3A46C),
      const Color(0xFFC98C9C),
      const Color(0xFFA797D2),
      const Color(0xFF6DB7AC),
      const Color(0xFF808780),
    ];
    final entries = scan.categoryBytes.entries
        .where((e) => e.value > 0)
        .toList();
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum byte classificável.',
          style: TextStyle(color: _muted),
        ),
      );
    }
    return PieChart(
      PieChartData(
        centerSpaceRadius: 54,
        sectionsSpace: 2,
        sections: [
          for (var i = 0; i < entries.length; i++)
            PieChartSectionData(
              value: entries[i].value.toDouble(),
              color: colors[i % colors.length],
              radius: 36,
              title:
                  '${(entries[i].value / scan.totalBytes * 100).toStringAsFixed(0)}%',
              titleStyle: const TextStyle(
                fontSize: 10,
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startScan() async {
    setState(() {
      _busy = true;
      _progress = null;
      _error = null;
      _scan = null;
      _selectedDuplicates.clear();
    });
    try {
      final result = await _scanner.scan(
        _path.text,
        extensionFilter: _extension.text,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) {
        setState(() {
          _scan = result;
          _selectedDuplicates.clear();
          _organizationPlan.clear();
        });
      }
      await widget.store.log(
        'Arquivos',
        'Análise de armazenamento',
        '${result.fileCount} arquivos · ${bytesLabel(result.totalBytes)} · ${result.duplicates.length} grupos duplicados',
        type: 'Análise',
      );
    } on StorageScanCancelled {
      if (mounted) {
        setState(
          () => _error =
              'Análise cancelada. Os resultados parciais não foram salvos.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  void _cancel() => _scanner.cancel();

  Future<void> _newFolder() async {
    final name = await _textDialog('Criar pasta', 'Nome da nova pasta');
    if (name == null || name.trim().isEmpty) return;
    try {
      final path = '${_path.text}${Platform.pathSeparator}${name.trim()}';
      await FileOperations.createDirectory(path);
      await widget.store.recordFileOperation(
        operation: 'Criar pasta',
        source: path,
        details: path,
      );
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _renameSelected() async {
    if (_selected.isEmpty) {
      _showError('Selecione um ou mais itens para renomear.');
      return;
    }
    if (_selected.length > 1) {
      await _renameBatch();
      return;
    }
    final source = _selected.first;
    final current = source.split(RegExp(r'[/\\]')).last;
    final name = await _textDialog(
      'Renomear item',
      'Novo nome',
      initial: current,
    );
    if (name == null || name.trim() == current) return;
    final destination =
        '${Directory(source).parent.path}${Platform.pathSeparator}${name.trim()}';
    if (!await _confirm('Confirmar renomeação', '$source\n\n→ $destination')) {
      return;
    }
    try {
      final moved = await FileOperations.rename(source, name);
      await widget.store.recordFileOperation(
        operation: 'Renomear',
        source: source,
        destination: moved,
        details: '$source → $moved',
      );
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _renameBatch() async {
    if (_selected.length > 500) {
      _showError(
        'Renomeie no máximo 500 itens por lote para revisar a prévia com segurança.',
      );
      return;
    }
    final prefix = await _textDialog(
      'Renomeação em lote',
      'Prefixo para os nomes',
      initial: 'arquivo',
    );
    if (prefix == null || prefix.trim().isEmpty) return;
    final sources = _selected.toList()..sort();
    final plan = <MapEntry<String, String>>[];
    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      final current = source.split(RegExp(r'[/\\]')).last;
      final dot = current.lastIndexOf('.');
      final extension = dot > 0 ? current.substring(dot) : '';
      final name =
          '${prefix.trim()}_${(i + 1).toString().padLeft(3, '0')}$extension';
      final destination =
          '${Directory(source).parent.path}${Platform.pathSeparator}$name';
      if (await FileSystemEntity.type(destination, followLinks: false) !=
          FileSystemEntityType.notFound) {
        _showError('A prévia encontrou um destino que já existe: $destination');
        return;
      }
      plan.add(MapEntry(source, name));
    }
    final preview = plan
        .map(
          (entry) =>
              '${entry.key}\n→ ${Directory(entry.key).parent.path}${Platform.pathSeparator}${entry.value}',
        )
        .join('\n\n');
    if (!await _confirm('Confirmar renomeação em lote', preview)) return;
    setState(() => _busy = true);
    var changed = 0;
    try {
      for (final entry in plan) {
        final destination = await FileOperations.rename(entry.key, entry.value);
        await widget.store.recordFileOperation(
          operation: 'Renomear em lote',
          source: entry.key,
          destination: destination,
          details: '${entry.key} → $destination',
        );
        changed++;
      }
      await _load();
    } catch (error) {
      _showError(
        'Lote interrompido após $changed de ${plan.length} itens: $error',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyOrMove(bool move) async {
    if (_selected.length > 500) {
      _showError(
        'Selecione no máximo 500 itens por lote para revisar a prévia.',
      );
      return;
    }
    final destinationDirectory = await _textDialog(
      move ? 'Mover itens' : 'Copiar itens',
      'Caminho da pasta destino',
      initial: Directory(_path.text).path,
    );
    if (destinationDirectory == null || destinationDirectory.trim().isEmpty) {
      return;
    }
    if (!await Directory(destinationDirectory.trim()).exists()) {
      _showError('A pasta de destino precisa existir.');
      return;
    }
    final planned = _selected
        .map(
          (source) => MapEntry(
            source,
            '${destinationDirectory.trim()}${Platform.pathSeparator}${source.split(RegExp(r'[/\\]')).last}',
          ),
        )
        .toList();
    if (!await _confirm(
      move ? 'Confirmar movimentação' : 'Confirmar cópia',
      planned.map((e) => '${e.key}\n→ ${e.value}').join('\n\n'),
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      for (final entry in planned) {
        if (move) {
          await FileOperations.move(entry.key, entry.value);
        } else {
          await FileOperations.copy(entry.key, entry.value);
        }
        await widget.store.recordFileOperation(
          operation: move ? 'Mover' : 'Copiar',
          source: entry.key,
          destination: entry.value,
          details: '${entry.key} → ${entry.value}',
        );
      }
      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.length > 500) {
      _showError('Exclua no máximo 500 itens por lote para revisar a prévia.');
      return;
    }
    if (_selected.isEmpty ||
        !await _confirm(
          'Excluir itens selecionados?',
          _selected.take(25).join('\n') +
              (_selected.length > 25
                  ? '\n… e mais ${_selected.length - 25} itens'
                  : ''),
        )) {
      return;
    }
    await _deletePaths(_selected.toList());
    await _load();
  }

  Future<void> _deleteDuplicateSelection() async {
    final paths = _selectedDuplicates.toList();
    if (paths.length > 500) {
      _showError('Exclua no máximo 500 duplicados por lote.');
      return;
    }
    final groups = _scan?.duplicates ?? const <DuplicateGroup>[];
    if (groups.any(
      (group) => group.paths.every(_selectedDuplicates.contains),
    )) {
      _showError('Mantenha ao menos uma cópia de cada grupo selecionada.');
      return;
    }
    if (paths.isEmpty ||
        !await _confirm(
          'Excluir duplicados selecionados?',
          '${paths.join('\n')}\n\nOs arquivos selecionados serão removidos permanentemente.',
        )) {
      return;
    }
    await _deletePaths(paths);
    if (mounted) setState(() => _selectedDuplicates.clear());
  }

  Future<void> _deletePaths(List<String> paths) async {
    setState(() => _busy = true);
    try {
      for (final path in paths) {
        final count = await FileOperations.delete(path);
        await widget.store.recordFileOperation(
          operation: 'Excluir',
          source: path,
          details: '$path · $count itens removidos',
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadRules() async {
    final rows = await widget.store.db.query(
      'organization_rules',
      orderBy: 'extension ASC',
    );
    if (mounted) setState(() => _rules = rows);
  }

  Future<void> _addRule() async {
    final extension = _ruleExtension.text.trim().toLowerCase().replaceFirst(
      RegExp(r'^\.'),
      '',
    );
    final destination = _ruleDestination.text.trim();
    if (!RegExp(r'^[a-z0-9][a-z0-9._+-]{0,15}$').hasMatch(extension) ||
        destination.isEmpty) {
      _showError('Informe uma extensão válida e um caminho de destino.');
      return;
    }
    try {
      await FileOperations.validatePath(destination);
      final existing = await widget.store.db.query(
        'organization_rules',
        columns: ['id'],
        where: 'extension = ?',
        whereArgs: [extension],
        limit: 1,
      );
      if (existing.isEmpty) {
        await widget.store.db.insert('organization_rules', {
          'name': '.$extension',
          'extension': extension,
          'destination': destination,
          'enabled': 1,
        });
      } else {
        await widget.store.db.update(
          'organization_rules',
          {'destination': destination, 'enabled': 1},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
      await widget.store.log(
        'Arquivos',
        'Regra de organização salva',
        '.$extension → $destination',
        type: 'Regra',
      );
      _ruleExtension.clear();
      await _loadRules();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleRule(int id, bool enabled) async {
    await widget.store.db.update(
      'organization_rules',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _loadRules();
  }

  Future<void> _removeRule(int id) async {
    await widget.store.db.delete(
      'organization_rules',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _loadRules();
  }

  Future<void> _previewOrganization() async {
    if (!await Directory(_destination.text).exists()) {
      _showError('O destino deve ser um diretório existente.');
      return;
    }
    if (_items.where((item) => item['directory'] != true).length > 500) {
      _showError(
        'Este diretório contém mais de 500 arquivos. Analise uma pasta menor para revisar a prévia inteira.',
      );
      return;
    }
    final plan = <String, String>{};
    final destinations = <String, String>{
      for (final rule in _rules.where((rule) => rule['enabled'] == 1))
        '${rule['extension']}'.toLowerCase(): '${rule['destination']}',
    };
    for (final item in _items.where((item) => item['directory'] != true)) {
      final source = item['path'] as String;
      final name = item['name'] as String;
      final ext = name.contains('.')
          ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
          : 'sem_extensao';
      final folder =
          destinations[ext] ??
          '${_destination.text}${Platform.pathSeparator}$ext';
      await FileOperations.validatePath(folder);
      final target = '$folder${Platform.pathSeparator}$name';
      if (FileOperations._samePath(source, target)) {
        _showError('A regra de .$ext aponta para a própria pasta de origem.');
        return;
      }
      plan[source] = target;
    }
    setState(() {
      _organizationPlan
        ..clear()
        ..addAll(plan);
    });
  }

  Future<void> _executeOrganization() async {
    if (_organizationPlan.isEmpty ||
        !await _confirm(
          'Executar organização?',
          _organizationPlan.entries
              .map((e) => '${e.key}\n→ ${e.value}')
              .join('\n\n'),
        )) {
      return;
    }
    setState(() => _busy = true);
    var moved = 0;
    try {
      for (final entry in _organizationPlan.entries) {
        await FileOperations.ensureDirectory(File(entry.value).parent.path);
        await FileOperations.move(entry.key, entry.value);
        await widget.store.recordFileOperation(
          operation: 'Organizar por extensão',
          source: entry.key,
          destination: entry.value,
          details: '${entry.key} → ${entry.value}',
        );
        moved++;
      }
      _showMessage('$moved arquivos organizados.');
      _organizationPlan.clear();
      await _load();
    } catch (e) {
      _showError('$e · $moved itens foram movidos antes da falha.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String path) async {
    try {
      await Process.run('explorer.exe', [path], runInShell: false);
      await widget.store.log('Arquivos', 'Arquivo aberto', path, type: 'Abrir');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _openExplorer(String path, bool directory) async {
    try {
      await Process.run('explorer.exe', [
        directory ? path : '/select,$path',
      ], runInShell: false);
    } catch (error) {
      _showError('Não foi possível abrir o Explorador: $error');
    }
  }

  Future<String?> _textDialog(
    String title,
    String label, {
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<bool> _confirm(String title, String message) async {
    final detailed =
        await widget.store.preference('detailedConfirmations', 'true') ==
        'true';
    if (!mounted) return false;
    final display = detailed
        ? message
        : 'A operação afetará aproximadamente ${message.split('\n').where((line) => line.trim().isNotEmpty).length} linhas de detalhes.\n\nA confirmação continua obrigatória.';
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: SelectableText(
                display,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ==
        true;
  }

  void _showError(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: Colors.red.shade800),
      );
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _ManagedFileRow extends StatelessWidget {
  const _ManagedFileRow({
    required this.item,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onExplorer,
  });
  final Map<String, dynamic> item;
  final bool selected;
  final ValueChanged<bool> onSelect;
  final VoidCallback onOpen, onExplorer;
  @override
  Widget build(BuildContext context) {
    final directory = item['directory'] as bool;
    final name = item['name'] as String;
    final ext = directory || !name.contains('.')
        ? ''
        : name.substring(name.lastIndexOf('.') + 1).toUpperCase();
    final modified = item['modified'] as DateTime;
    return ListTile(
      dense: true,
      onTap: onOpen,
      contentPadding: EdgeInsets.zero,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: selected,
            onChanged: (value) => onSelect(value ?? false),
          ),
          Icon(
            directory ? Icons.folder_rounded : Icons.insert_drive_file_outlined,
            size: 19,
            color: directory ? _green : _muted,
          ),
        ],
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      subtitle: Text(
        '${ext.isEmpty ? (directory ? 'Pasta' : 'Arquivo') : '.$ext'} · ${modified.toString().substring(0, 16)}',
        style: const TextStyle(color: _muted, fontSize: 10),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            directory ? '' : bytesLabel(item['size'] as num?),
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          IconButton(
            tooltip: 'Abrir no Explorador de Arquivos',
            onPressed: onExplorer,
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}
