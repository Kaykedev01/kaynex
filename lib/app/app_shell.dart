part of '../main.dart';

class KaynexApp extends StatefulWidget {
  const KaynexApp({super.key, required this.store, this.initialPage = 0});
  final LocalStore store;
  final int initialPage;
  @override
  State<KaynexApp> createState() => _KaynexAppState();
}

class _KaynexAppState extends State<KaynexApp> {
  ThemeMode _mode = ThemeMode.dark;
  Color _accent = _green;
  String _accentHex = '9BCB75';
  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final theme = await widget.store.preference('theme', 'dark');
    final accent = await widget.store.preference('accent', '9BCB75');
    if (!mounted) return;
    setState(() {
      _mode = theme == 'light' ? ThemeMode.light : ThemeMode.dark;
      _accentHex = accent;
      _accent = _accentFromHex(accent);
    });
  }

  Future<void> _setTheme(bool light) async {
    await widget.store.setPreference('theme', light ? 'light' : 'dark');
    if (mounted) {
      setState(() => _mode = light ? ThemeMode.light : ThemeMode.dark);
    }
  }

  Future<void> _setAccent(String hex) async {
    await widget.store.setPreference('accent', hex);
    if (mounted) {
      setState(() {
        _accentHex = hex;
        _accent = _accentFromHex(hex);
      });
    }
  }

  static Color _accentFromHex(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return value == null ? _green : Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'KAYNEX',
    debugShowCheckedModeBanner: false,
    themeMode: _mode,
    theme: _theme(Brightness.light, _accent),
    darkTheme: _theme(Brightness.dark, _accent),
    home: AppShell(
      store: widget.store,
      initialPage: widget.initialPage,
      isLight: _mode == ThemeMode.light,
      onThemeChanged: _setTheme,
      accentHex: _accentHex,
      onAccentChanged: _setAccent,
    ),
  );

  ThemeData _theme(Brightness brightness, Color accent) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: dark ? _bg : const Color(0xFFF5F7F3),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      dividerColor: dark ? _line : const Color(0xFFE0E5DE),
      fontFamily: 'Segoe UI',
      cardTheme: CardThemeData(
        color: dark ? _panel : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: dark ? _line : const Color(0xFFE4E8E1)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? _panel : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: dark ? _line : const Color(0xFFE0E5DE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: dark ? _line : const Color(0xFFE0E5DE)),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.store,
    required this.initialPage,
    required this.isLight,
    required this.onThemeChanged,
    required this.accentHex,
    required this.onAccentChanged,
  });
  final LocalStore store;
  final int initialPage;
  final bool isLight;
  final ValueChanged<bool> onThemeChanged;
  final String accentHex;
  final ValueChanged<String> onAccentChanged;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _page = 0;
  bool _collapsed = false;
  final _names = const [
    'Visão geral',
    'Sistema',
    'Arquivos',
    'Rede',
    'Atividades',
    'Preferências',
  ];
  final _icons = const [
    Icons.grid_view_rounded,
    Icons.memory_rounded,
    Icons.folder_open_rounded,
    Icons.wifi_rounded,
    Icons.history_rounded,
    Icons.tune_rounded,
  ];
  @override
  void initState() {
    super.initState();
    if (widget.initialPage >= 0 && widget.initialPage < _names.length) {
      _page = widget.initialPage;
    }
    widget.store.preference('homePage', '0').then((value) {
      final page = int.tryParse(value) ?? 0;
      if (mounted && page >= 0 && page < _names.length) {
        setState(() => _page = page);
      }
    });
  }

  Future<void> _goTo(int page) async {
    setState(() => _page = page);
    await widget.store.setPreference('homePage', '$page');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final collapsed = _collapsed || width < 900;
    final pages = [
      OverviewPage(store: widget.store, onNavigate: _goTo),
      SystemPage(store: widget.store),
      FilesPage(store: widget.store),
      NetworkPage(store: widget.store),
      ActivitiesPage(store: widget.store),
      PreferencesPage(
        store: widget.store,
        isLight: widget.isLight,
        onThemeChanged: widget.onThemeChanged,
        accentHex: widget.accentHex,
        onAccentChanged: widget.onAccentChanged,
      ),
    ];
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: collapsed ? 76 : 226,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF131713)
                  : const Color(0xFFFBFCFA),
              border: Border(
                right: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(collapsed ? 16 : 20, 24, 16, 27),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: _green,
                          size: 21,
                        ),
                      ),
                      if (!collapsed) ...[
                        const SizedBox(width: 10),
                        const Text(
                          'KAYNEX',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!collapsed)
                  const Padding(
                    padding: EdgeInsets.only(left: 20, bottom: 9),
                    child: Text(
                      'WORKSPACE',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                for (var i = 0; i < 4; i++) _navItem(i, collapsed),
                Padding(
                  padding: EdgeInsets.fromLTRB(collapsed ? 20 : 20, 24, 0, 9),
                  child: collapsed
                      ? const Divider()
                      : const Text(
                          'OUTROS',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                for (var i = 4; i < 6; i++) _navItem(i, collapsed),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton(
                    onPressed: () => setState(() => _collapsed = !_collapsed),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).dividerColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Icon(
                      _collapsed
                          ? Icons.chevron_right_rounded
                          : Icons.chevron_left_rounded,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 66,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _names[_page],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Local',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                      const SizedBox(width: 18),
                      Text(
                        DateTime.now().toString().substring(0, 10),
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: KeyedSubtree(
                      key: ValueKey(_page),
                      child: pages[_page],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, bool collapsed) {
    final selected = _page == index;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 9 : 12,
        vertical: 2,
      ),
      child: Tooltip(
        message: collapsed ? _names[index] : '',
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => _goTo(index),
          child: Container(
            height: 42,
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 15 : 12),
            decoration: BoxDecoration(
              color: selected
                  ? _green.withValues(alpha: .12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Icon(
                  _icons[index],
                  size: 18,
                  color: selected ? _green : _muted,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Text(
                    _names[index],
                    style: TextStyle(
                      color: selected
                          ? _green
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
