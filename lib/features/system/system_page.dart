part of '../../main.dart';

class SystemPage extends StatefulWidget {
  const SystemPage({super.key, required this.store});
  final LocalStore store;
  @override
  State<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  Map<String, dynamic>? _info;
  List<Map<String, dynamic>> _processes = [];
  List<Map<String, dynamic>> _adapters = [];
  final _filter = TextEditingController();
  final List<FlSpot> _cpu = [], _ram = [], _diskRead = [], _diskWrite = [];
  Timer? _timer;
  int _interval = 5, _view = 0, _sort = 0;
  bool _busy = false, _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _interval =
        int.tryParse(await widget.store.preference('refreshSeconds', '5')) ?? 5;
    await _loadHardware();
    await _refreshLive();
    _timer = Timer.periodic(
      Duration(seconds: _interval.clamp(2, 60)),
      (_) => _refreshLive(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _filter.dispose();
    super.dispose();
  }

  Future<void> _loadHardware() async {
    setState(() => _busy = true);
    try {
      final values = await Future.wait([
        WindowsService.system(),
        WindowsService.adapters(),
      ]);
      if (mounted) {
        setState(() {
          _info = values[0] as Map<String, dynamic>;
          _adapters = values[1] as List<Map<String, dynamic>>;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshLive() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final values = await Future.wait([
        WindowsService.sample(),
        WindowsService.processes(),
      ]);
      final sample = values[0] as Map<String, dynamic>;
      final rows = values[1] as List<Map<String, dynamic>>;
      final total = (sample['RamTotal'] as num?)?.toDouble() ?? 0;
      final available = (sample['RamAvailable'] as num?)?.toDouble() ?? 0;
      if (mounted) {
        setState(() {
          _processes = rows;
          if (_info != null) {
            _info!['CpuLoad'] = sample['Cpu'];
            _info!['RamTotal'] = total;
            _info!['RamFree'] = available;
          }
          _push(_cpu, (sample['Cpu'] as num?)?.toDouble());
          _push(_ram, total <= 0 ? null : ((total - available) / total * 100));
          _push(
            _diskRead,
            ((sample['ReadBytes'] as num?)?.toDouble() ?? 0) / 1048576,
          );
          _push(
            _diskWrite,
            ((sample['WriteBytes'] as num?)?.toDouble() ?? 0) / 1048576,
          );
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      _refreshing = false;
    }
  }

  void _push(List<FlSpot> points, double? value) {
    if (value == null || !value.isFinite) return;
    points.add(FlSpot(points.length.toDouble(), value < 0 ? 0 : value));
    if (points.length > 60) {
      points.removeAt(0);
      for (var i = 0; i < points.length; i++) {
        points[i] = FlSpot(i.toDouble(), points[i].y);
      }
    }
  }

  List<Map<String, dynamic>> get _visibleProcesses {
    final rows = _processes
        .where(
          (p) =>
              '${p['Name']}'.toLowerCase().contains(_filter.text.toLowerCase()),
        )
        .toList();
    rows.sort((a, b) {
      if (_sort == 1) {
        return ((b['CpuPercent'] as num?)?.toDouble() ?? -1).compareTo(
          (a['CpuPercent'] as num?)?.toDouble() ?? -1,
        );
      }
      return (b['Memory'] as num).compareTo(a['Memory'] as num);
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Sistema',
            subtitle: 'Monitoramento, hardware, processos e manutenção.',
            trailing: OutlinedButton.icon(
              onPressed: _busy ? null : _loadHardware,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Atualizar hardware'),
            ),
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.monitor_heart_outlined),
                label: Text('Monitoramento'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.memory_rounded),
                label: Text('Processos'),
              ),
              ButtonSegment(
                value: 2,
                icon: Icon(Icons.cleaning_services_outlined),
                label: Text('Manutenção'),
              ),
            ],
            selected: {_view},
            onSelectionChanged: (value) => setState(() => _view = value.first),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            _ErrorBanner(message: _error!, onRetry: _loadHardware),
          if (_view == 0) ...[_monitor(info)],
          if (_view == 1) ...[_processPanel()],
          if (_view == 2) ...[_MaintenancePanel(store: widget.store)],
          const SizedBox(height: 12),
          Text(
            'Atualização automática a cada $_interval s. Temperatura não é exibida porque não há uma fonte de leitura comum e confiável em todos os equipamentos.',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _monitor(Map<String, dynamic>? info) {
    final total = (info?['RamTotal'] as num?)?.toDouble() ?? 0;
    final free = (info?['RamFree'] as num?)?.toDouble() ?? 0;
    final disks = (info?['Disks'] as List?)?.cast<Map>() ?? [];
    final physical = (info?['PhysicalDisks'] as List?)?.cast<Map>() ?? [];
    final gpus = (info?['Gpus'] as List?)?.cast<Map>() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 340,
              child: _ResourceChart(
                title: 'CPU',
                unit: '%',
                values: _cpu,
                color: _green,
                maxY: 100,
              ),
            ),
            SizedBox(
              width: 340,
              child: _ResourceChart(
                title: 'Memória',
                unit: '%',
                values: _ram,
                color: const Color(0xFF7BA7D8),
                maxY: 100,
              ),
            ),
            SizedBox(
              width: 340,
              child: _ResourceChart(
                title: 'E/S disco',
                unit: 'MB/s',
                values: _diskRead,
                secondValues: _diskWrite,
                secondColor: const Color(0xFFD3A46C),
                color: const Color(0xFF6DB7AC),
                maxY: null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelHeading(
                'Hardware e Windows',
                'Inventário consultado via CIM',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 30,
                runSpacing: 18,
                children: [
                  _InfoCell(
                    'Sistema',
                    '${info?['Windows'] ?? '—'} · ${info?['Version'] ?? ''} (build ${info?['Build'] ?? '—'})',
                  ),
                  _InfoCell('Arquitetura', '${info?['Architecture'] ?? '—'}'),
                  _InfoCell('Dispositivo', '${info?['Computer'] ?? '—'}'),
                  _InfoCell('Processador', '${info?['Cpu'] ?? '—'}'),
                  _InfoCell(
                    'Núcleos / threads',
                    '${info?['Cores'] ?? '—'} / ${info?['Threads'] ?? '—'}',
                  ),
                  _InfoCell(
                    'Placa-mãe',
                    '${info?['BoardManufacturer'] ?? '—'} · ${info?['BoardModel'] ?? ''}',
                  ),
                  _InfoCell(
                    'RAM total / disponível',
                    '${bytesLabel(total)} / ${bytesLabel(free)}',
                  ),
                  _InfoCell(
                    'Tempo ligado',
                    _uptime(info?['UptimeSeconds'] as num?),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 520,
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PanelHeading(
                      'Unidades lógicas',
                      'Espaço total, utilizado e livre',
                    ),
                    const SizedBox(height: 12),
                    for (final d in disks)
                      _DiskLine(disk: Map<String, dynamic>.from(d)),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 520,
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PanelHeading(
                      'Discos físicos',
                      'Modelo e capacidade reportados pelo Windows',
                    ),
                    const SizedBox(height: 8),
                    if (physical.isEmpty)
                      const Text(
                        'Informação indisponível.',
                        style: TextStyle(color: _muted),
                      ),
                    for (final disk in physical)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.storage_rounded,
                          color: _green,
                        ),
                        title: Text(
                          '${disk['Model'] ?? 'Disco'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          '${disk['Interface'] ?? 'Interface desconhecida'}',
                          style: const TextStyle(fontSize: 10, color: _muted),
                        ),
                        trailing: Text(
                          bytesLabel(disk['Size'] as num?),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 520,
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PanelHeading(
                      'Placas de vídeo',
                      'Dados de inventário CIM; temperatura não é reportada',
                    ),
                    const SizedBox(height: 8),
                    if (gpus.isEmpty)
                      const Text(
                        'Informação indisponível.',
                        style: TextStyle(color: _muted),
                      ),
                    for (final gpu in gpus)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.display_settings_outlined,
                          color: _green,
                        ),
                        title: Text(
                          '${gpu['Name']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          'Driver ${gpu['DriverVersion'] ?? '—'} · memória ${bytesLabel(gpu['AdapterRAM'] as num?)}',
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 520,
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PanelHeading(
                      'Adaptadores de rede',
                      'Interfaces ativas e inativas, endereços e DNS',
                    ),
                    const SizedBox(height: 8),
                    if (_adapters.isEmpty)
                      const Text(
                        'Nenhum adaptador disponível.',
                        style: TextStyle(color: _muted),
                      ),
                    for (final adapter in _adapters)
                      _AdapterRow(adapter: adapter),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _processPanel() => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: _PanelHeading(
                'Processos ativos',
                'CPU é calculada entre duas amostras; o primeiro valor aparece após a próxima atualização.',
              ),
            ),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _filter,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  hintText: 'Pesquisar nome',
                ),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<int>(
              value: _sort,
              items: const [
                DropdownMenuItem(value: 0, child: Text('Memória')),
                DropdownMenuItem(value: 1, child: Text('CPU')),
              ],
              onChanged: (value) => setState(() => _sort = value ?? 0),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_processes.isEmpty) const LinearProgressIndicator(minHeight: 2),
        for (final process in _visibleProcesses.take(200))
          _ProcessRow(process: process, onKill: () => _kill(process)),
      ],
    ),
  );

  String _uptime(num? seconds) {
    if (seconds == null) return '—';
    final duration = Duration(seconds: seconds.toInt());
    final days = duration.inDays;
    return '$days d ${duration.inHours.remainder(24)} h ${duration.inMinutes.remainder(60)} min';
  }

  Future<void> _kill(Map<String, dynamic> process) async {
    final pid = process['Id'] as int;
    final path = process['Path']?.toString() ?? 'Caminho não disponível';
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Encerrar processo?'),
            content: Text(
              '${process['Name']} · PID $pid\n$path\n\nO encerramento pode perder trabalho não salvo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Encerrar'),
              ),
            ],
          ),
        ) ==
        true;
    if (!confirmed) return;
    try {
      await WindowsService.endProcess(pid);
      await widget.store.log(
        'Sistema',
        'Processo encerrado',
        '${process['Name']} · PID $pid · $path',
      );
      await _refreshLive();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível encerrar: $error')),
        );
      }
    }
  }
}

class _AdapterRow extends StatelessWidget {
  const _AdapterRow({required this.adapter});
  final Map<String, dynamic> adapter;
  @override
  Widget build(BuildContext context) {
    final ipv4 = (adapter['IPv4'] as List? ?? []).join(', ');
    final gateways = (adapter['Gateways'] as List? ?? []).join(', ');
    final dns = (adapter['Dns'] as List? ?? []).join(', ');
    return ExpansionTile(
      leading: Icon(
        Icons.wifi_tethering_rounded,
        color: adapter['Status'] == true ? _green : _muted,
        size: 18,
      ),
      title: Text(
        '${adapter['Name'] ?? adapter['Description']}',
        style: const TextStyle(fontSize: 12),
      ),
      subtitle: Text(
        adapter['Status'] == true
            ? 'Ativo · ${adapter['Mac'] ?? 'MAC indisponível'}'
            : 'Inativo',
        style: const TextStyle(color: _muted, fontSize: 10),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: SelectableText(
            'IPv4: $ipv4\nIPv6: ${(adapter['IPv6'] as List? ?? []).join(', ')}\nGateway: $gateways\nDNS: $dns',
            style: const TextStyle(fontSize: 11, height: 1.6),
          ),
        ),
      ],
    );
  }
}

class _MaintenancePanel extends StatefulWidget {
  const _MaintenancePanel({required this.store});
  final LocalStore store;
  @override
  State<_MaintenancePanel> createState() => _MaintenancePanelState();
}

class _MaintenancePanelState extends State<_MaintenancePanel> {
  final MaintenanceService _service = MaintenanceService();
  List<MaintenanceCategory> _categories = [];
  final Set<String> _selected = {};
  bool _busy = false;
  String? _status;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelHeading(
              'Limpeza seletiva',
              'Somente arquivos conhecidos, antigos e não usados em Downloads. A varredura não remove nada.',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _analyze,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Analisar temporários'),
                ),
                if (_categories.isNotEmpty)
                  FilledButton.tonalIcon(
                    onPressed: _busy || _selected.isEmpty ? null : _clean,
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: Text('Limpar selecionados (${_selected.length})'),
                  ),
              ],
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _status!,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
      if (_categories.isNotEmpty) ...[
        const SizedBox(height: 12),
        Panel(
          child: Column(
            children: [
              for (final category in _categories)
                CheckboxListTile(
                  value: _selected.contains(category.id),
                  onChanged: _busy || category.files == 0
                      ? null
                      : (value) => setState(
                          () => value == true
                              ? _selected.add(category.id)
                              : _selected.remove(category.id),
                        ),
                  title: Text(
                    category.label,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    category.accessError ??
                        '${category.files} arquivos candidatos · ${bytesLabel(category.bytes)} · ${category.root}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                  secondary: Text(
                    bytesLabel(category.bytes),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final category in _categories.where(
          (c) => _selected.contains(c.id) && c.preview.isNotEmpty,
        ))
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prévia · ${category.label}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                for (final path in category.preview.take(20))
                  Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                if (category.files > category.preview.length)
                  Text(
                    '… e mais ${category.files - category.preview.length} arquivos',
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
              ],
            ),
          ),
      ],
      const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text(
          'Elegibilidade: .tmp/.temp com mais de 24 h (usuário) ou 7 dias (Windows); cache thumbcache_*.db com mais de 14 dias; relatórios WER conhecidos com mais de 30 dias. Arquivos em uso e sem permissão são preservados. Lixeira indisponível nesta versão.',
          style: TextStyle(color: _muted, fontSize: 10),
        ),
      ),
    ],
  );

  Future<void> _analyze() async {
    setState(() {
      _busy = true;
      _status = 'Identificando candidatos…';
    });
    try {
      final categories = await _service.analyze(
        onProgress: (visited) {
          if (mounted) setState(() => _status = '$visited itens verificados…');
        },
      );
      if (mounted) {
        setState(() {
          _categories = categories;
          _selected.clear();
          _status = 'Análise concluída. Confira a prévia e selecione as categorias desejadas.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Falha na análise: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clean() async {
    final choices = _categories
        .where((category) => _selected.contains(category.id))
        .toList();
    final total = choices.fold<int>(0, (sum, category) => sum + category.bytes);
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar limpeza seletiva'),
            content: Text(
              '${choices.map((c) => '${c.label}: ${c.files} itens (${bytesLabel(c.bytes)} estimados)').join('\n')}\n\nPotencial estimado: ${bytesLabel(total)}. Arquivos que estiverem em uso ou inacessíveis serão ignorados.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Limpar'),
              ),
            ],
          ),
        ) ==
        true;
    if (!confirm) return;
    setState(() {
      _busy = true;
      _status = 'Limpando…';
    });
    try {
      final result = await _service.clean(
        _selected,
        onProgress: (count) {
          if (mounted) setState(() => _status = '$count arquivos removidos…');
        },
      );
      await widget.store.recordMaintenance(
        categories: choices.map((c) => c.id).toList(),
        examined: result.examined,
        deleted: result.deleted,
        freedBytes: result.freedBytes,
        result: result.failed == 0
            ? 'Concluído'
            : 'Concluído com ${result.failed} itens ignorados',
      );
      if (mounted) {
        setState(() {
          _selected.clear();
          _status =
              '${result.deleted} arquivos removidos · ${bytesLabel(result.freedBytes)} liberados · ${result.failed} itens ignorados.';
        });
      }
      await _analyze();
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'A limpeza foi interrompida: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({required this.process, required this.onKill});
  final Map<String, dynamic> process;
  final VoidCallback onKill;
  @override
  Widget build(BuildContext context) {
    final cpu = process['CpuPercent'] as num?;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.memory_rounded, size: 17, color: _muted),
      title: Text(
        '${process['Name']}',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      subtitle: Tooltip(
        message: process['Path']?.toString() ?? 'Caminho não disponível',
        child: Text(
          'PID ${process['Id']} · ${process['Path'] ?? 'Caminho não disponível'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: _muted),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 62,
            child: Text(
              cpu == null ? 'CPU —' : '${cpu.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 10, color: _muted),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            bytesLabel(process['Memory'] as num?),
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Encerrar processo',
            onPressed: onKill,
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}
