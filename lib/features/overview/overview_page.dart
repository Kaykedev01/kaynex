part of '../../main.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({
    super.key,
    required this.store,
    required this.onNavigate,
  });
  final LocalStore store;
  final ValueChanged<int> onNavigate;
  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  Timer? _timer;
  int _interval = 5;
  List<Map<String, Object?>> _recent = [];
  final List<FlSpot> _cpuHistory = [];
  final List<FlSpot> _ramHistory = [];
  final List<FlSpot> _diskHistory = [];
  bool _sampling = false;
  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    _interval =
        int.tryParse(await widget.store.preference('refreshSeconds', '5')) ?? 5;
    await _load();
    _timer = Timer.periodic(Duration(seconds: _interval), (_) => _sample());
  }

  Future<void> _load() async {
    try {
      final result = await WindowsService.system();
      final recent = await widget.store.activities();
      if (mounted) {
        setState(() {
          _data = result;
          _recent = recent.take(4).toList();
          _error = null;
          _loading = false;
        });
      }
      _appendSample(result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _sample() async {
    if (_sampling) return;
    _sampling = true;
    try {
      final sample = await WindowsService.sample();
      if (!mounted) return;
      final total = (sample['RamTotal'] as num?)?.toDouble() ?? 0;
      final available = (sample['RamAvailable'] as num?)?.toDouble() ?? 0;
      final cpu = (sample['Cpu'] as num?)?.toDouble();
      setState(() {
        if (_data != null) {
          _data!['CpuLoad'] = cpu;
          _data!['RamTotal'] = total;
          _data!['RamFree'] = available;
          _data!['DiskReadBytesPerSec'] = sample['ReadBytes'];
          _data!['DiskWriteBytesPerSec'] = sample['WriteBytes'];
        }
        _appendHistory(_cpuHistory, cpu, ceiling: 100);
        _appendHistory(
          _ramHistory,
          total <= 0 ? null : ((total - available) / total * 100),
          ceiling: 100,
        );
        final io =
            ((sample['ReadBytes'] as num?)?.toDouble() ?? 0) +
            ((sample['WriteBytes'] as num?)?.toDouble() ?? 0);
        _appendHistory(_diskHistory, io / (1024 * 1024));
      });
      if (_cpuHistory.length % 6 == 0) {
        final recent = await widget.store.activities();
        if (mounted) setState(() => _recent = recent.take(4).toList());
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Telemetria indisponível: $e');
    } finally {
      _sampling = false;
    }
  }

  void _appendSample(Map<String, dynamic> sample) {
    final cpu = (sample['CpuLoad'] ?? sample['CpuFallback']) as num?;
    final total = (sample['RamTotal'] as num?)?.toDouble() ?? 0;
    final free = (sample['RamFree'] as num?)?.toDouble() ?? 0;
    _appendHistory(_cpuHistory, cpu?.toDouble(), ceiling: 100);
    _appendHistory(
      _ramHistory,
      total <= 0 ? null : ((total - free) / total * 100),
      ceiling: 100,
    );
    final io =
        ((sample['DiskReadBytesPerSec'] as num?)?.toDouble() ?? 0) +
        ((sample['DiskWriteBytesPerSec'] as num?)?.toDouble() ?? 0);
    _appendHistory(_diskHistory, io / (1024 * 1024));
  }

  void _appendHistory(List<FlSpot> history, double? value, {double? ceiling}) {
    if (value == null || !value.isFinite) return;
    final bounded = value < 0
        ? 0.0
        : ceiling == null
        ? value
        : value.clamp(0, ceiling).toDouble();
    history.add(FlSpot(history.length.toDouble(), bounded));
    if (history.length > 60) {
      history.removeAt(0);
      for (var i = 0; i < history.length; i++) {
        history[i] = FlSpot(i.toDouble(), history[i].y);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final total = (d?['RamTotal'] as num?)?.toDouble() ?? 0;
    final free = (d?['RamFree'] as num?)?.toDouble() ?? 0;
    final used = total == 0 ? 0.0 : (total - free) / total;
    final disks = (d?['Disks'] as List?)?.cast<Map>() ?? [];
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Visão geral',
            subtitle: d == null
                ? 'Resumo do computador e das atividades recentes.'
                : '${d['Computer']}  ·  ${d['Windows']}',
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            _ErrorBanner(
              message: 'Não foi possível consultar o Windows: $_error',
              onRetry: _load,
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 860;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: wide
                        ? (constraints.maxWidth - 28) * .64
                        : constraints.maxWidth,
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _PanelHeading(
                            'Recursos do sistema',
                            'Dados coletados diretamente do Windows',
                          ),
                          const SizedBox(height: 22),
                          _MetricLine(
                            label: 'Processador',
                            value: '${d?['CpuLoad'] ?? '—'}%',
                            caption:
                                d?['Cpu']?.toString() ??
                                'Carregando informações',
                            progress:
                                ((d?['CpuLoad'] as num?)?.toDouble() ?? 0) /
                                100,
                          ),
                          const SizedBox(height: 20),
                          _MetricLine(
                            label: 'Memória RAM',
                            value: '${(used * 100).toStringAsFixed(0)}%',
                            caption:
                                '${bytesLabel(total - free)} em uso de ${bytesLabel(total)}',
                            progress: used,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: wide
                        ? (constraints.maxWidth - 28) * .36
                        : constraints.maxWidth,
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _PanelHeading(
                            'Armazenamento',
                            'Unidades locais',
                          ),
                          const SizedBox(height: 16),
                          if (disks.isEmpty)
                            const Text(
                              'Nenhuma unidade disponível',
                              style: TextStyle(color: _muted),
                            )
                          else
                            for (final disk in disks.take(3))
                              _DiskLine(disk: Map<String, dynamic>.from(disk)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: wide
                        ? (constraints.maxWidth - 28) * .56
                        : constraints.maxWidth,
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _PanelHeading(
                            'Atividade recente',
                            'Operações registradas localmente',
                          ),
                          const SizedBox(height: 12),
                          if (_recent.isEmpty)
                            const Text(
                              'As atividades aparecerão aqui conforme você usar as ferramentas.',
                              style: TextStyle(color: _muted, fontSize: 13),
                            )
                          else
                            for (final a in _recent) _ActivityRow(item: a),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: wide
                        ? (constraints.maxWidth - 28) * .44
                        : constraints.maxWidth,
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _PanelHeading('Acesso rápido', 'Ferramentas'),
                          const SizedBox(height: 8),
                          _QuickLink(
                            icon: Icons.memory_rounded,
                            label: 'Processos e hardware',
                            onTap: () => widget.onNavigate(1),
                          ),
                          _QuickLink(
                            icon: Icons.folder_open_rounded,
                            label: 'Explorar arquivos',
                            onTap: () => widget.onNavigate(2),
                          ),
                          _QuickLink(
                            icon: Icons.wifi_rounded,
                            label: 'Diagnóstico de rede',
                            onTap: () => widget.onNavigate(3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 900;
              final itemWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 28) / 3;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _ResourceChart(
                      title: 'CPU',
                      unit: '%',
                      values: _cpuHistory,
                      color: _green,
                      maxY: 100,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ResourceChart(
                      title: 'Memória RAM',
                      unit: '%',
                      values: _ramHistory,
                      color: const Color(0xFF7BA7D8),
                      maxY: 100,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ResourceChart(
                      title: 'Leitura + gravação',
                      unit: 'MB/s',
                      values: _diskHistory,
                      color: const Color(0xFFD3A46C),
                      maxY: null,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Atualização automática a cada $_interval s · Algumas métricas dependem do suporte do Windows.',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ResourceChart extends StatelessWidget {
  const _ResourceChart({
    required this.title,
    required this.unit,
    required this.values,
    required this.color,
    required this.maxY,
    this.secondValues,
    this.secondColor,
  });
  final String title, unit;
  final List<FlSpot> values;
  final Color color;
  final double? maxY;
  final List<FlSpot>? secondValues;
  final Color? secondColor;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PanelHeading(
          title,
          values.isEmpty
              ? 'Aguardando amostras'
              : '${values.last.y.toStringAsFixed(1)} $unit · últimas ${values.length} amostras',
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 104,
          child: values.length < 2
              ? const Center(
                  child: Text(
                    'O gráfico será preenchido automaticamente.',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                )
              : LineChart(
                  LineChartData(
                    minX: values.first.x,
                    maxX: values.last.x,
                    minY: 0,
                    maxY:
                        maxY ??
                        (values.map((e) => e.y).reduce(math.max) * 1.25).clamp(
                          1,
                          double.infinity,
                        ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY == null ? null : maxY! / 4,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Theme.of(context).dividerColor,
                        strokeWidth: .6,
                      ),
                    ),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: values,
                        isCurved: true,
                        color: color,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withValues(alpha: .08),
                        ),
                      ),
                      if (secondValues != null && secondValues!.length > 1)
                        LineChartBarData(
                          spots: secondValues!,
                          isCurved: true,
                          color: secondColor ?? _muted,
                          barWidth: 1.5,
                          dotData: const FlDotData(show: false),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading(this.title, this.subtitle);
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
    ],
  );
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
    required this.caption,
    required this.progress,
  });
  final String label, value, caption;
  final double progress;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: progress.clamp(0, 1),
          minHeight: 6,
          backgroundColor: Theme.of(context).dividerColor,
          color: _green,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        caption,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _muted, fontSize: 11),
      ),
    ],
  );
}

class _DiskLine extends StatelessWidget {
  const _DiskLine({required this.disk});
  final Map<String, dynamic> disk;
  @override
  Widget build(BuildContext context) {
    final size = (disk['Size'] as num?)?.toDouble() ?? 0;
    final free = (disk['Free'] as num?)?.toDouble() ?? 0;
    final used = size == 0 ? 0.0 : (size - free) / size;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${disk['Name']}  ${disk['Label'] ?? ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(used * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: used,
              minHeight: 5,
              color: _green,
              backgroundColor: Theme.of(context).dividerColor,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${bytesLabel(free)} livres de ${bytesLabel(size)}',
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, size: 17, color: _green),
    title: Text(label, style: const TextStyle(fontSize: 12)),
    trailing: const Icon(
      Icons.arrow_forward_ios_rounded,
      size: 12,
      color: _muted,
    ),
    onTap: onTap,
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});
  final Map<String, Object?> item;
  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(item['created_at'] as String? ?? '')
        ?.toLocal();
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.check_circle_outline_rounded,
        size: 17,
        color: _green,
      ),
      title: Text(
        item['title'] as String? ?? '',
        style: const TextStyle(fontSize: 12),
      ),
      subtitle: Text(
        '${item['category']} · ${date?.toString().substring(0, 16) ?? ''}',
        style: const TextStyle(fontSize: 10, color: _muted),
      ),
    );
  }
}
