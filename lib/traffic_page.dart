import 'package:flutter/material.dart';
import 'app_state.dart';
import 'models.dart';
import 'theme.dart';

class TrafficPage extends StatelessWidget {
  const TrafficPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final totalBytes = appState.totalMobileBytes + appState.totalWifiBytes;
        final sorted = List<AppUsageItem>.from(appState.apps)
          ..removeWhere((a) => !appState.includeSystemApps && a.isSystem && a.totalBytes < 1024 * 50)
          ..sort((a, b) => b.totalBytes.compareTo(a.totalBytes));

        final drainers = appState.apps.where((a) => a.isBackgroundDrainer).toList()
          ..sort((a, b) => b.totalBytes.compareTo(a.totalBytes));

        return RefreshIndicator(
          color: SColor.cyan,
          backgroundColor: SColor.panel,
          onRefresh: () => appState.refreshData(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
            children: [
              SegmentedRangeBar(
                current: appState.period,
                onChanged: (p) => appState.setPeriod(p),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SColor.panel,
                  border: Border.all(color: SColor.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    TelemetryRingGauge(
                      segments: [
                        (appState.totalMobileBytes.toDouble(), SColor.crimson),
                        (appState.totalWifiBytes.toDouble(), SColor.emerald),
                      ],
                      centerTitle: formatDataSize(totalBytes),
                      centerSubtitle: 'ВСЕГО ТРАФИКА',
                      size: 136,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'БАЛАНС СЕТЕВЫХ ИНТЕРФЕЙСОВ',
                            style: TextStyle(
                              color: SColor.sub,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TacticalBadge(
                            'Мобильная сеть: ${formatDataSize(appState.totalMobileBytes)}',
                            SColor.crimson,
                            icon: Icons.cell_tower_rounded,
                          ),
                          const SizedBox(height: 8),
                          TacticalBadge(
                            'Сеть Wi-Fi: ${formatDataSize(appState.totalWifiBytes)}',
                            SColor.emerald,
                            icon: Icons.wifi_rounded,
                          ),
                          const SizedBox(height: 8),
                          TacticalBadge(
                            'Firewall блок: ${sorted.where((x) => x.isNetBlocked).length} прил.',
                            SColor.amber,
                            icon: Icons.shield_rounded,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // НОВАЯ ФУНКЦИЯ: Радар скрытой фоновой активности
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: appState.toggleBackgroundRadar,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: SColor.panel,
                    border: Border.all(
                      color: drainers.isNotEmpty ? SColor.amber : SColor.border,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.radar_rounded, color: SColor.amber, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Радар скрытой фоновой активности',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            Text(
                              'Приложений, качающих трафик без включения экрана: ${drainers.length}',
                              style: const TextStyle(color: SColor.sub, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        appState.showBackgroundRadar ? 'Скрыть' : 'Показать',
                        style: const TextStyle(color: SColor.sub, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        appState.showBackgroundRadar
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: SColor.sub,
                      ),
                    ],
                  ),
                ),
              ),
              if (appState.showBackgroundRadar && drainers.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final d in drainers.take(10))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SColor.card,
                      border: Border.all(color: SColor.amber.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: SColor.amber, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.appName,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                              ),
                              Text(
                                'Экран: 0 мин · Скрытый трафик: ${formatDataSize(d.totalBytes)}',
                                style: const TextStyle(color: SColor.amber, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => appState.toggleFirewallForApp(d),
                          icon: Icon(
                            d.isNetBlocked ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                            color: d.isNetBlocked ? SColor.crimson : SColor.cyan,
                          ),
                          tooltip: 'Заблокировать сеть (Root iptables)',
                        ),
                        IconButton(
                          onPressed: () => appState.killAndCleanApp(d.packageName),
                          icon: const Icon(Icons.stop_circle_outlined, color: SColor.crimson),
                          tooltip: 'Принудительно остановить и очистить кэш',
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              const Text(
                'ВСЕ СЕТЕВЫЕ СОЕДИНЕНИЯ И ROOT-БРАНДМАУЭР',
                style: TextStyle(
                  color: SColor.sub,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              for (final a in sorted.take(100))
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SColor.panel,
                    border: Border.all(color: a.isNetBlocked ? SColor.crimson : SColor.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Моб: ${formatDataSize(a.mobileBytes)} · Wi-Fi: ${formatDataSize(a.wifiBytes)}',
                              style: const TextStyle(color: SColor.sub, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatDataSize(a.totalBytes),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          color: SColor.emerald,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => appState.toggleFirewallForApp(a),
                        icon: Icon(
                          a.isNetBlocked ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                          color: a.isNetBlocked ? SColor.crimson : SColor.cyan,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
