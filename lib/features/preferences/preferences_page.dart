part of '../../main.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({
    super.key,
    required this.store,
    required this.isLight,
    required this.onThemeChanged,
    required this.accentHex,
    required this.onAccentChanged,
  });
  final LocalStore store;
  final bool isLight;
  final ValueChanged<bool> onThemeChanged;
  final String accentHex;
  final ValueChanged<String> onAccentChanged;
  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  int _interval = 5, _limit = 5000, _homePage = 0;
  bool _detailedConfirmations = true, _busy = false;
  String _status = '';
  late final TextEditingController _backupPath;
  final _restorePath = TextEditingController();

  @override
  void initState() {
    super.initState();
    _backupPath = TextEditingController(
      text: '${widget.store.path}.backup.sqlite',
    );
    _load();
  }

  @override
  void dispose() {
    _backupPath.dispose();
    _restorePath.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      widget.store.preference('refreshSeconds', '5'),
      widget.store.preference('maxHistory', '5000'),
      widget.store.preference('homePage', '0'),
      widget.store.preference('detailedConfirmations', 'true'),
    ]);
    if (mounted) {
      setState(() {
        _interval = int.tryParse(values[0]) ?? 5;
        _limit = int.tryParse(values[1]) ?? 5000;
        _homePage = int.tryParse(values[2]) ?? 0;
        _detailedConfirmations = values[3] == 'true';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          'Preferências',
          subtitle: 'Configurações e backup local do KAYNEX.',
        ),
        Panel(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tema claro', style: TextStyle(fontSize: 13)),
                subtitle: const Text(
                  'O tema escuro permanece como padrão.',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
                value: widget.isLight,
                activeThumbColor: _green,
                onChanged: (value) {
                  widget.onThemeChanged(value);
                  _log('Tema atualizado', value ? 'Claro' : 'Escuro');
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Cor de destaque',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Aplica-se aos controles Material; o verde da marca permanece fixo.',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
                trailing: DropdownButton<String>(
                  value: widget.accentHex,
                  items: const [
                    DropdownMenuItem(value: '9BCB75', child: Text('Verde')),
                    DropdownMenuItem(value: '79A9E0', child: Text('Azul')),
                    DropdownMenuItem(value: 'D5A65F', child: Text('Âmbar')),
                    DropdownMenuItem(value: 'B299DC', child: Text('Violeta')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      widget.onAccentChanged(value);
                      _log('Cor de destaque', value);
                    }
                  },
                ),
              ),
              const Divider(),
              _dropdown<int>(
                title: 'Intervalo de monitoramento',
                subtitle: 'Consultas de telemetria; mínimo de 3 segundos.',
                value: _interval,
                values: const [3, 5, 10, 30],
                changed: (value) =>
                    _save('refreshSeconds', value, (v) => _interval = v),
              ),
              const Divider(),
              _dropdown<int>(
                title: 'Página inicial',
                subtitle: 'Abre esta seção ao iniciar o aplicativo.',
                value: _homePage,
                values: const [0, 1, 2, 3],
                changed: (value) =>
                    _save('homePage', value, (v) => _homePage = v),
                labels: const ['Visão geral', 'Sistema', 'Arquivos', 'Rede'],
              ),
              const Divider(),
              _dropdown<int>(
                title: 'Limite de atividades',
                subtitle:
                    'Registros mais antigos são removidos automaticamente.',
                value: _limit,
                values: const [1000, 5000, 10000, 50000],
                changed: (value) async {
                  await _save('maxHistory', value, (v) => _limit = v);
                  await widget.store.trimHistory(value);
                },
                labels: const ['1.000', '5.000', '10.000', '50.000'],
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Mostrar detalhes nos avisos de confirmação',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'A confirmação obrigatória permanece ativa; esta opção controla a lista de caminhos exibida.',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
                value: _detailedConfirmations,
                activeThumbColor: _green,
                onChanged: (value) async {
                  await widget.store.setPreference(
                    'detailedConfirmations',
                    '$value',
                  );
                  setState(() => _detailedConfirmations = value);
                  await _log(
                    'Detalhes das confirmações',
                    value ? 'Ativado' : 'Desativado',
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Banco de dados local',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 6),
              SelectableText(
                widget.store.path,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _backupPath,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Salvar backup SQLite em',
                  prefixIcon: Icon(Icons.save_alt_rounded),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _backup,
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('Criar backup'),
                ),
              ),
              const Divider(height: 24),
              TextField(
                controller: _restorePath,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Caminho do arquivo SQLite para restaurar',
                  prefixIcon: Icon(Icons.restore_rounded),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : _restore,
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Validar e restaurar'),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: LinearProgressIndicator(),
                ),
              if (_status.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _status,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sobre o KAYNEX',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 10),
              const Text(
                'KAYNEX — Windows Utility Suite',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 5),
              const Text(
                'Versão 1.0.0 · Aplicativo local, sem conta ou servidor.',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
              const SizedBox(height: 6),
              const Text(
                'Dados e preferências permanecem no arquivo SQLite acima.',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _dropdown<T>({
    required String title,
    required String subtitle,
    required T value,
    required List<T> values,
    required ValueChanged<T> changed,
    List<String>? labels,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: const TextStyle(fontSize: 13)),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: _muted, fontSize: 11),
    ),
    trailing: DropdownButton<T>(
      value: value,
      items: [
        for (var i = 0; i < values.length; i++)
          DropdownMenuItem(
            value: values[i],
            child: Text(labels == null ? '${values[i]} s' : labels[i]),
          ),
      ],
      onChanged: (next) {
        if (next != null) changed(next);
      },
    ),
  );

  Future<void> _save<T>(String key, T value, void Function(T) update) async {
    await widget.store.setPreference(key, '$value');
    if (mounted) setState(() => update(value));
    await _log('Preferência alterada', '$key = $value');
  }

  Future<void> _log(String title, String details) async {
    try {
      await widget.store.log(
        'Preferências',
        title,
        details,
        type: 'Configuração',
      );
    } catch (_) {
      /* A preferência já foi gravada; falha de auditoria não a reverte. */
    }
  }

  Future<void> _backup() async {
    final target = _backupPath.text.trim();
    if (target.isEmpty || FileOperations._samePath(target, widget.store.path)) {
      setState(
        () =>
            _status = 'Informe um caminho de destino diferente do banco atual.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Criando backup…';
    });
    try {
      await widget.store.backupTo(target);
      await _log('Backup SQLite criado', target);
      if (mounted) setState(() => _status = 'Backup criado em $target');
    } catch (error) {
      if (mounted) setState(() => _status = 'Falha no backup: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final source = _restorePath.text.trim();
    if (source.isEmpty || FileOperations._samePath(source, widget.store.path)) {
      setState(
        () =>
            _status = 'Informe um arquivo de backup diferente do banco ativo.',
      );
      return;
    }
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Substituir o banco local?'),
            content: Text(
              'O banco atual será substituído pelo backup:\n\n$source\n\nFaça um backup atual antes de continuar.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Validar e restaurar'),
              ),
            ],
          ),
        ) ==
        true;
    if (!confirm) return;
    setState(() {
      _busy = true;
      _status = 'Validando banco e restaurando…';
    });
    try {
      await widget.store.restoreFrom(source);
      if (mounted) {
        setState(
          () => _status = 'Banco restaurado. Reinicie o KAYNEX para recarregar preferências de inicialização.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Restauração cancelada: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: Colors.red.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: Colors.orangeAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    ),
  );
}
