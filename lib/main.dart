import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'autowipe_page.dart';
import 'power_page.dart';
import 'theme.dart';
import 'traffic_page.dart';
import 'usage_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: SColor.bg,
  ));
  runApp(const SentinelRootApp());
  appState.init();
}

class SentinelRootApp extends StatelessWidget {
  const SentinelRootApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'SentinelRoot',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: SColor.bg,
        textTheme: base.textTheme.apply(bodyColor: SColor.ink, displayColor: SColor.ink),
        colorScheme: const ColorScheme.dark(
          primary: SColor.cyan,
          onPrimary: SColor.bg,
          secondary: SColor.emerald,
          surface: SColor.panel,
          onSurface: SColor.ink,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: SColor.card,
          contentTextStyle: TextStyle(color: SColor.ink),
        ),
      ),
      home: const ObsidianCommandShell(),
    );
  }
}

class ObsidianCommandShell extends StatefulWidget {
  const ObsidianCommandShell({super.key});

  @override
  State<ObsidianCommandShell> createState() => _ObsidianCommandShellState();
}

class _ObsidianCommandShellState extends State<ObsidianCommandShell>
    with WidgetsBindingObserver {
  int _tab = 0;

  static const _tabs = [
    (Icons.donut_large_rounded, 'Аналитика'),
    (Icons.radar_rounded, 'Сеть и Радар'),
    (Icons.memory_rounded, 'Ядро и ОЗУ'),
    (Icons.shield_rounded, 'Часовой'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      appState.refreshData(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Верхний тактический HUD-блок (создан с нуля)
                ListenableBuilder(
                  listenable: appState,
                  builder: (context, _) {
                    final p = appState.power;
                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: SColor.panel,
                        border: Border.all(color: SColor.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: p.hasRoot ? SColor.emerald : SColor.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'SENTINEL ROOT',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13.5,
                                        letterSpacing: 0.8,
                                        color: SColor.ink,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    TacticalBadge(
                                      p.hasRoot ? 'SU АКТИВЕН' : 'БЕЗ ROOT',
                                      p.hasRoot ? SColor.emerald : SColor.amber,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Таймер ядра: ${formatDuration(appState.liveContinuousActiveMs, clockMode: true)} · ОЗУ ${p.ramUsagePct}%',
                                  style: const TextStyle(
                                    color: SColor.cyan,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () async {
                              final msg = await appState.boostRamAndPurgeCaches();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg)),
                                );
                              }
                            },
                            icon: const Icon(Icons.cleaning_services_rounded, color: SColor.emerald, size: 19),
                            tooltip: 'Быстрый сброс кэша и ОЗУ (Root)',
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: appState.loading ? null : () => appState.refreshData(),
                            icon: appState.loading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: SColor.cyan),
                                  )
                                : const Icon(Icons.sync_rounded, color: SColor.sub, size: 19),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: const [
                      UsagePage(),
                      TrafficPage(),
                      PowerPage(),
                      AutoWipePage(),
                    ],
                  ),
                ),
              ],
            ),

            // Плавающий нижний командный док (с нуля вместо стандартного NavigationBar)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: SColor.panel.withOpacity(0.96),
                  border: Border.all(color: SColor.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _tab == i ? SColor.cyan : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _tabs[i].$1,
                                  size: 20,
                                  color: _tab == i ? SColor.bg : SColor.sub,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _tabs[i].$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: _tab == i ? SColor.bg : SColor.sub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
