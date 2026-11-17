part of '../../main.dart';

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key, required this.store});
  final LocalStore store;
  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  String _category = 'Todas', _query = '';
  DateTime? _from, _to;
  bool _descending = true, _busy = true;
  List<Map<String, Object?>> _items = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final rows = await widget.store.activities(
        category: _category,
        query: _query,
        from: _from,
        to: _to,
        descending: _descending,
      );
      if (mounted) {
        setState(() {
          _items = rows;
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao consultar o histórico: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Atividades',
          subtitle: 'Histórico local no SQLite, com busca e filtros por módulo e período.',
          trailing: PopupMenuButton<String>(
            tooltip: 'Gerenciar histórico',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: _manageHistory,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'selected',
                child: Text('Limpar filtros atuais'),
              ),
              PopupMenuItem(
                value: 'all',
                child: Text('Apagar todo o histórico'),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(isDense: true),
                items:
                    const [
                          'Todas',
                          'Sistema',
                          'Arquivos',
                          'Rede',
                          'Preferências',
                        ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (value) {
                  setState(() => _category = value ?? 'Todas');
                  _load();
                },
              ),
            ),
            SizedBox(
              width: 235,
              child: TextField(
                onChanged: (value) {
                  _query = value;
                  _load();
                },
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  hintText: 'Pesquisar',
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(true),
              icon: const Icon(Icons.calendar_today_outlined, size: 15),
              label: Text(_from == null ? 'De' : _date(_from!)),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(false),
              icon: const Icon(Icons.calendar_today_outlined, size: 15),
              label: Text(_to == null ? 'Até' : _date(_to!)),
            ),
            if (_from != null || _to != null)
              IconButton(
                tooltip: 'Remover datas',
                onPressed: () {
                  setState(() {
                    _from = null;
                    _to = null;
                  });
                  _load();
                },
                icon: const Icon(Icons.clear_rounded),
              ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _descending = !_descending);
                _load();
              },
              icon: Icon(
                _descending ? Icons.south_rounded : Icons.north_rounded,
                size: 15,
              ),
              label: Text(_descending ? 'Recentes' : 'Antigas'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            children: [
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              if (_items.isEmpty && !_busy)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhuma atividade corresponde aos filtros.',
                    style: TextStyle(color: _muted),
                  ),
                ),
              for (final item in _items)
                InkWell(
                  onTap: () => _showDetails(item),
                  child: _ActivityRow(item: item),
                ),
              if (_items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_items.length} registros (máximo de 300 por consulta)',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  Future<void> _pickDate(bool from) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected == null) return;
    setState(() {
      if (from) {
        _from = selected;
      } else {
        _to = selected;
      }
    });
    await _load();
  }

  Future<void> _showDetails(Map<String, Object?> item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          item['title'] as String? ?? item['type'] as String? ?? 'Atividade',
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            'Módulo: ${item['module'] ?? item['category']}\nTipo: ${item['type'] ?? '—'}\nData: ${DateTime.tryParse(item['created_at'] as String? ?? '')?.toLocal() ?? '—'}\nResultado: ${item['result'] ?? '—'}\n\n${item['details'] ?? ''}',
            style: const TextStyle(fontSize: 12, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _manageHistory(String action) async {
    final all = action == 'all';
    final scope = all
        ? 'Todos os registros serão apagados.'
        : 'Módulo: $_category · De: ${_from == null ? '—' : _date(_from!)} · Até: ${_to == null ? 'agora' : _date(_to!)}. A busca textual não altera quais linhas são apagadas.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          all ? 'Apagar todo o histórico?' : 'Limpar histórico filtrado?',
        ),
        content: Text(scope),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (all) {
      await widget.store.clearActivities();
    } else {
      await widget.store.deleteActivities(
        category: _category == 'Todas' ? null : _category,
        after: _from,
        before: _to?.add(const Duration(days: 1)),
      );
    }
    await _load();
  }
}
