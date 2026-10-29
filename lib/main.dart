import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'autowipe_page.dart';
import 'decoy_calendar_page.dart';
import 'pc_access_page.dart';
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
  await appState.init();
  runApp(const SentinelRootApp());
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
        textTheme: base.textTheme.apply(
          fontFamily: SText.fontFamily,
          bodyColor: SColor.ink,
          displayColor: SColor.ink,
        ),
        colorScheme: const ColorScheme.dark(
          primary: SColor.cyan,
          onPrimary: SColor.bg,
          secondary: SColor.emerald,
          surface: SColor.panel,
          onSurface: SColor.ink,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: SColor.card,
          contentTextStyle: TextStyle(color: SColor.ink, fontFamily: SText.fontFamily),
        ),
      ),
      // МОДУЛЬ 2: Если включён скрытый режим, первым открывается фейковый Календарь
      home: appState.stealthCalendarMode
          ? const DecoyCalendarPage()
          : const ObsidianCommandShell(),
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
    (Icons.radar_rounded, 'Сеть'),
    (Icons.memory_rounded, 'Ядро и ОЗУ'),
    (Icons.shield_rounded, 'Часовой'),
    (Icons.usb_rounded, 'О ПК'),
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
      appState.setLifecycleActive(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      appState.setLifecycleActive(false);
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
                // Верхний тактический HUD-блок + SpeedBadge (Модуль 10.5) и индикатор USB (Модуль 9)
                ListenableBuilder(
                  listenable: appState,
                  builder: (context, _) {
                    final p = appState.power;
                    final usb = appState.usbStatus;
                    final now = DateTime.now().millisecondsSinceEpoch;
                    final usbOpen = usb.permitted && usb.expiresAtTs > now;
                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: SColor.panel,
                        border: Border.all(color: SColor.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
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
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            letterSpacing: 0.6,
                                            color: SColor.ink,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        TacticalBadge(
                                          p.hasRoot ? 'SU' : 'NO ROOT',
                                          p.hasRoot ? SColor.emerald : SColor.amber,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Ядро: ${formatDuration(appState.liveContinuousActiveMs, clockMode: true)} · ОЗУ ${p.ramUsagePct}%',
                                      style: const TextStyle(
                                        color: SColor.cyan,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // МОДУЛЬ 10.5: SpeedBadge с живой скоростью и Sparkline
                              SpeedBadge(
                                rxBps: appState.currentSpeed.rxBps,
                                txBps: appState.currentSpeed.txBps,
                                rxHistory: appState.rxSpeedHistory,
                                txHistory: appState.txSpeedHistory,
                                ifaceLabel: appState.speedIfaceMode,
                                onTap: appState.cycleSpeedIfaceMode,
                              ),
                            ],
                          ),
                          if (usbOpen) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: SColor.emerald.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '🔓 USB разрешён до ${formatTimestamp(usb.expiresAtTs)}',
                                style: const TextStyle(
                                  color: SColor.emerald,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
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
                      PcAccessPage(),
                    ],
                  ),
                ),
              ],
            ),

            // Плавающий нижний командный док (5 вкладок)
            Positioned(
              left: 14,
              right: 14,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: SColor.panel.withOpacity(0.97),
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
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _tab == i ? SColor.cyan : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _tabs[i].$1,
                                  size: 19,
                                  color: _tab == i ? SColor.bg : SColor.sub,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _tabs[i].$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
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
