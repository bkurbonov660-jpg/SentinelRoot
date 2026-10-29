import 'package:flutter/material.dart';
import 'app_state.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'theme.dart';

class UsagePage extends StatefulWidget {
  const UsagePage({super.key});

  @override
  State<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends State<UsagePage> {
  String _search = '';
  String? _expandedPkg;

  static const List<Color> _ringColors = [
    SColor.cyan,
    SColor.emerald,
    SColor.violet,
    SColor.amber,
    SColor.crimson,
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final filtered = appState.apps.where((a) {
          if (!appState.includeSystemApps && a.isSystem && a.usageMs < 60000) {
            return false;
          }
          if (_search.trim().isEmpty) return true;
          final q = _search.trim().toLowerCase();
          return a.appName.toLowerCase().contains(q) ||
              a.packageName.toLowerCase().contains(q);
        }).toList()
          ..sort((a, b) => b.usageMs.compareTo(a.usageMs));

        final top5 = filtered.take(5).toList();
        final ringSegments = <(double, Color)>[
          for (var i = 0; i < top5.length; i++)
            (top5[i].usageMs.toDouble(), _ringColors[i % _ringColors.length]),
        ];

        return RefreshIndicator(
          color: SColor.cyan,
          backgroundColor: SColor.panel,
          onRefresh: () => appState.refreshData(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 105),
            children: [
              SegmentedRangeBar(
                current: appState.period,
                onChanged: (p) => appState.setPeriod(p),
              ),
              const SizedBox(height: 14),
              if (!appState.power.hasUsagePerm)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SColor.panel,
                    border: Border.all(color: SColor.amber),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bolt_rounded, color: SColor.amber, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Требуется активация Root-доступа к телеметрии',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => appState.grantRootPermissions(),
                              icon: const Icon(Icons.terminal_rounded, size: 16),
                              label: const Text('Активировать через SU'),
                              style: FilledButton.styleFrom(
                                backgroundColor: SColor.cyan,
                                foregroundColor: SColor.bg,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => NativeBridge.openUsageSettings(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: SColor.border),
                              foregroundColor: SColor.ink,
                            ),
                            child: const Text('Вручную'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                      segments: ringSegments.isEmpty
                          ? [(1.0, SColor.border)]
                          : ringSegments,
                      centerTitle: formatDuration(appState.totalScreenMs),
                      centerSubtitle: 'ЭКРАННОЕ ВРЕМЯ',
                      size: 138,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('РАСПРЕДЕЛЕНИЕ АКТИВНОСТИ', style: SText.section),
                          const SizedBox(height: 8),
                          if (top5.isEmpty)
                            const Text(
                              'Нет активных сессий за выбранный период',
                              style: TextStyle(color: SColor.sub, fontSize: 12),
                            )
                          else
                            for (var i = 0; i < top5.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _ringColors[i % _ringColors.length],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        top5[i].appName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: SColor.ink,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      formatDuration(top5[i].usageMs),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: SColor.sub,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(color: SColor.ink, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Фильтр по имени или пакету…',
                        hintStyle: const TextStyle(color: SColor.sub, fontSize: 12.5),
                        prefixIcon: const Icon(Icons.search_rounded, color: SColor.sub, size: 19),
                        filled: true,
                        fillColor: SColor.panel,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: SColor.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: SColor.cyan),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Системные'),
                    selected: appState.includeSystemApps,
                    selectedColor: SColor.cyan.withOpacity(0.22),
                    checkmarkColor: SColor.cyan,
                    backgroundColor: SColor.panel,
                    side: const BorderSide(color: SColor.border),
                    labelStyle: TextStyle(
                      color: appState.includeSystemApps ? SColor.cyan : SColor.sub,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    onSelected: (v) => appState.toggleSystemApps(v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final item in filtered.take(100)) _buildTacticalAppCard(item),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTacticalAppCard(AppUsageItem item) {
    final maxMs = appState.totalScreenMs > 0 ? appState.totalScreenMs : 1;
    final ratio = (item.usageMs / maxMs).clamp(0.02, 1.0);
    final expanded = _expandedPkg == item.packageName;
    final mins = item.usageMs ~/ 60000;
    final hrs = (item.usageMs / 3600000).toStringAsFixed(1);
    // МОДУЛЬ 10.6: Текущая скорость пакета за последнюю секунду
    final liveUidRx = appState.currentSpeed.uidRxBps[item.uid] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: SColor.panel,
        border: Border.all(
          color: item.isFrozen
              ? SColor.crimson
              : (item.isNetBlocked ? SColor.amber : SColor.border),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              _expandedPkg = expanded ? null : item.packageName;
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: SColor.card,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: SColor.border),
                        ),
                        child: Text(
                          item.appName.isNotEmpty ? item.appName[0].toUpperCase() : 'A',
                          style: const TextStyle(
                            color: SColor.cyan,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    item.appName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      color: SColor.ink,
                                    ),
                                  ),
                                ),
                                if (liveUidRx > 0) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '↓ ${formatSpeed(liveUidRx)}',
                                    style: const TextStyle(
                                      color: SColor.emerald,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.packageName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: SColor.sub, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatDuration(item.usageMs),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: SColor.cyan,
                            ),
                          ),
                          Text(
                            '$mins мин ($hrs ч)',
                            style: const TextStyle(color: SColor.sub, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: SColor.sub,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 5,
                      color: SColor.cyan,
                      backgroundColor: SColor.card,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      TacticalBadge(
                        'Сеть: ${formatDataSize(item.totalBytes)}',
                        SColor.emerald,
                        icon: Icons.swap_vert_rounded,
                      ),
                      if (item.dailyLimitMinutes > 0)
                        TacticalBadge(
                          'Лимит: ${item.dailyLimitMinutes}м',
                          SColor.amber,
                          icon: Icons.timer_rounded,
                        ),
                      if (item.isNetBlocked)
                        const TacticalBadge(
                          'FIREWALL БЛОК',
                          SColor.crimson,
                          icon: Icons.wifi_off_rounded,
                        ),
                      if (item.isFrozen)
                        const TacticalBadge(
                          'ЗАМОРОЖЕНО',
                          SColor.crimson,
                          icon: Icons.ac_unit_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: const BoxDecoration(
                color: SColor.card,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ТАКТИЧЕСКОЕ УПРАВЛЕНИЕ ПАКЕТОМ (ROOT)', style: SText.section),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final m in [0, 15, 30, 60, 120])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(m == 0 ? 'Без лимита' : '$m мин/д'),
                              selected: item.dailyLimitMinutes == m,
                              selectedColor: SColor.cyan,
                              backgroundColor: SColor.panel,
                              labelStyle: TextStyle(
                                color: item.dailyLimitMinutes == m ? SColor.bg : SColor.ink,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                              onSelected: (_) =>
                                  appState.setDailyLimitForApp(item.packageName, m),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => appState.toggleFirewallForApp(item),
                          icon: Icon(
                            item.isNetBlocked ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                            size: 16,
                            color: item.isNetBlocked ? SColor.emerald : SColor.amber,
                          ),
                          label: Text(
                            item.isNetBlocked ? 'Вкл. сеть' : 'Блок сети',
                            style: const TextStyle(color: SColor.ink, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: SColor.border),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              appState.toggleFreezeForApp(item.packageName, !item.isFrozen),
                          icon: Icon(
                            item.isFrozen ? Icons.play_arrow_rounded : Icons.ac_unit_rounded,
                            size: 16,
                            color: item.isFrozen ? SColor.emerald : SColor.crimson,
                          ),
                          label: Text(
                            item.isFrozen ? 'Разморозить' : 'Заморозить',
                            style: const TextStyle(color: SColor.ink, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: SColor.border),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await appState.killAndCleanApp(item.packageName);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Кэш ${item.appName} очищен, процесс остановлен')),
                              );
                            }
                          },
                          icon: const Icon(Icons.cleaning_services_rounded, size: 16, color: SColor.cyan),
                          label: const Text(
                            'Стоп+Кэш',
                            style: TextStyle(color: SColor.ink, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: SColor.border),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
