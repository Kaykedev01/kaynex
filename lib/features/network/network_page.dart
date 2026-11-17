part of '../../main.dart';

class NetworkPage extends StatefulWidget {
  const NetworkPage({super.key, required this.store});
  final LocalStore store;
  @override
  State<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  final _host = TextEditingController(text: '1.1.1.1');
  final _port = TextEditingController(text: '443');
  String _result = '', _mode = 'Ping';
  int _count = 4;
  bool _busy = false, _loadingAdapters = false;
  List<Map<String, dynamic>> _adapters = [];
  List<Map<String, Object?>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadAdapters();
    _loadHistory();
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _loadAdapters() async {
    setState(() => _loadingAdapters = true);
    try {
      final rows = await WindowsService.adapters();
      if (mounted) setState(() => _adapters = rows);
    } catch (e) {
      if (mounted) setState(() => _result = 'Falha ao ler adaptadores: $e');
    } finally {
      if (mounted) setState(() => _loadingAdapters = false);
    }
  }

  Future<void> _loadHistory() async {
    final rows = await widget.store.networkHistory();
    if (mounted) setState(() => _history = rows);
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Rede',
          subtitle:
              'Conexão local, diagnóstico de destinos e histórico consultável.',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelHeading(
                'Executar diagnóstico',
                'Escolha uma ferramenta e um destino autorizado.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<String>(
                      initialValue: _mode,
                      items: const [
                        DropdownMenuItem(value: 'Ping', child: Text('Ping')),
                        DropdownMenuItem(
                          value: 'DNS',
                          child: Text('Consulta DNS'),
                        ),
                        DropdownMenuItem(
                          value: 'Rota',
                          child: Text('Traceroute'),
                        ),
                        DropdownMenuItem(
                          value: 'TCP',
                          child: Text('Conexão TCP'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _mode = value ?? 'Ping'),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _host,
                      onSubmitted: (_) => _run(),
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.language_rounded, size: 18),
                        hintText: 'Domínio ou endereço IP',
                      ),
                    ),
                  ),
                  if (_mode == 'Ping')
                    SizedBox(
                      width: 145,
                      child: DropdownButtonFormField<int>(
                        initialValue: _count,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Pacotes',
                        ),
                        items: const [1, 4, 10, 20]
                            .map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Text('$v pacote${v == 1 ? '' : 's'}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _count = value ?? 4),
                      ),
                    ),
                  if (_mode == 'TCP')
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _port,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Porta TCP',
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _run,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Executar'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              if (_result.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    _result,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
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
              width: 600,
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: _PanelHeading(
                            'Adaptadores',
                            'IPv4, IPv6, gateway, DNS e MAC',
                          ),
                        ),
                        IconButton(
                          onPressed: _loadingAdapters ? null : _loadAdapters,
                          tooltip: 'Atualizar interfaces',
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                        ),
                      ],
                    ),
                    if (_loadingAdapters)
                      const LinearProgressIndicator(minHeight: 2),
                    if (_adapters.isEmpty && !_loadingAdapters)
                      const Text(
                        'Nenhum adaptador encontrado.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    for (final adapter in _adapters)
                      _AdapterRow(adapter: adapter),
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
                      'Resultados anteriores',
                      'Armazenados no SQLite',
                    ),
                    const SizedBox(height: 8),
                    if (_history.isEmpty)
                      const Text(
                        'Nenhum diagnóstico registrado.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    for (final item in _history.take(15))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onTap: () => setState(
                          () => _result =
                              '${item['summary']}\n\nResultado: ${item['result']}',
                        ),
                        leading: const Icon(
                          Icons.network_check_rounded,
                          size: 17,
                          color: _green,
                        ),
                        title: Text(
                          '${item['mode']} · ${item['target']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          '${item['created_at']}',
                          style: const TextStyle(fontSize: 10, color: _muted),
                        ),
                        trailing: Icon(
                          item['result'] == 'Falhou' ||
                                  item['result'] == 'Sem resposta'
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 16,
                          color: item['result'] == 'Falhou'
                              ? Colors.orange
                              : _green,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Ping limitado a 20 pacotes. TCP abre somente uma conexão de cliente ao host/porta informados. Traceroute respeita o limite de saltos do Windows.',
          style: TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    ),
  );

  Future<void> _run() async {
    final target = _host.text.trim();
    setState(() {
      _busy = true;
      _result = '';
    });
    try {
      String summary;
      String outcome;
      if (_mode == 'Ping') {
        final data = await WindowsService.pingMany(target, _count);
        summary =
            'Pacotes enviados: ${data['count']} · recebidos: ${data['received']} · perda: ${data['loss']}%\nLatência mín/méd/máx: ${data['min'] ?? '—'} / ${data['average'] ?? '—'} / ${data['max'] ?? '—'} ms';
        outcome = data['ok'] == true
            ? (data['loss'] == 0 ? 'Sucesso' : 'Parcial')
            : 'Sem resposta';
      } else if (_mode == 'DNS') {
        final values = await WindowsService.dns(target);
        summary = values.isEmpty
            ? 'Nenhum registro de endereço foi retornado.'
            : values.join('\n');
        outcome = values.isEmpty ? 'Sem registros' : 'Sucesso';
      } else if (_mode == 'TCP') {
        final data = await WindowsService.tcpTest(
          target,
          int.tryParse(_port.text) ?? 0,
        );
        summary = '${data['message']} · ${data['latencyMs']} ms';
        outcome = data['ok'] == true ? 'Sucesso' : 'Falhou';
      } else {
        summary = await WindowsService.trace(target);
        outcome = summary.isEmpty ? 'Sem resposta' : 'Concluído';
      }
      await widget.store.recordNetwork(
        mode: _mode,
        target: _mode == 'TCP' ? '$target:${_port.text}' : target,
        summary: summary,
        result: outcome,
      );
      if (mounted) setState(() => _result = summary);
      await _loadHistory();
    } catch (error) {
      final message = '$error';
      if (mounted) setState(() => _result = 'Falha no diagnóstico: $message');
      try {
        await widget.store.recordNetwork(
          mode: _mode,
          target: target,
          summary: message,
          result: 'Falhou',
        );
        await _loadHistory();
      } catch (_) {
        /* Preserva a falha principal do diagnóstico. */
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
