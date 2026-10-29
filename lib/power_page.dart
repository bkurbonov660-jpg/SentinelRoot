import 'package:flutter/material.dart';
import 'app_state.dart';
import 'theme.dart';

class PowerPage extends StatelessWidget {
  const PowerPage({super.key});

  Widget _kvRow(String label, String val, {Color color = SColor.ink}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: SColor.sub, fontSize: 12.5)),
          ),
          Text(
            val,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final p = appState.power;
        final lastOff = p.history.isNotEmpty ? p.history.first : null;

        return RefreshIndicator(
          color: SColor.cyan,
          backgroundColor: SColor.panel,
          onRefresh: () => appState.refreshData(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 105),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: SColor.panel,
                  border: Border.all(color: SColor.cyan.withOpacity(0.6)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: SColor.cyan, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'НЕПРЕРЫВНЫЙ НАКОПИТЕЛЬНЫЙ ТАЙМЕР ЯДРА',
                            style: SText.section,
                          ),
                        ),
                        TacticalBadge(
                          'АКБ ${p.batteryPct}%',
                          p.isCharging ? SColor.emerald : SColor.cyan,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatDuration(appState.liveContinuousActiveMs, clockMode: true),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: SColor.cyan,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Текущая сессия после включения: ${formatDuration(appState.liveCurrentUptimeMs, clockMode: true)}',
                      style: const TextStyle(color: SColor.ink, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    _kvRow('Включён с', formatTimestamp(p.bootTimeTs), color: SColor.emerald),
                    _kvRow('Накоплено до перезагрузки', formatDuration(p.accumulatedActiveMs)),
                    _kvRow('Всего времени в выключенном состоянии', formatDuration(p.accumulatedOffMs), color: SColor.amber),
                    if (lastOff != null) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: SColor.border, height: 1),
                      ),
                      _kvRow('Последнее выключение / разрядка', formatTimestamp(lastOff.offFromTs), color: SColor.crimson),
                      _kvRow('Включился снова', formatTimestamp(lastOff.onAtTs), color: SColor.emerald),
                      _kvRow('Длительность отключения', formatDuration(lastOff.offDurationMs), color: SColor.amber),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SColor.panel,
                  border: Border.all(color: SColor.border),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.memory_rounded, color: SColor.emerald, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Оперативная память (ОЗУ): ${p.ramUsedMb} МБ из ${p.ramTotalMb} МБ (${p.ramUsagePct}%)',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (p.ramUsagePct / 100.0).clamp(0.05, 1.0),
                        minHeight: 8,
                        color: p.ramUsagePct > 85 ? SColor.crimson : SColor.emerald,
                        backgroundColor: SColor.card,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final msg = await appState.boostRamAndPurgeCaches();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                          }
                        },
                        icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                        label: const Text(
                          'Очистить кэш всех приложений и сбросить буферы ОЗУ (Root)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: SColor.emerald,
                          foregroundColor: SColor.bg,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: appState.togglePowerHistory,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: SColor.panel,
                    border: Border.all(color: SColor.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, color: SColor.cyan, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Журнал выключений и разрядок (${p.history.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      Text(
                        appState.showPowerHistory ? 'Скрыть' : 'Показать',
                        style: const TextStyle(color: SColor.sub, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              if (appState.showPowerHistory) ...[
                const SizedBox(height: 8),
                if (p.history.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: SColor.panel,
                      border: Border.all(color: SColor.border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Сторожевой таймер записывает контрольную точку каждую минуту в /data/local/tmp. При следующем выключении или полной разрядке телефона здесь появится точный интервал простоя.',
                      style: TextStyle(color: SColor.sub, fontSize: 12.5, height: 1.4),
                    ),
                  )
                else
                  for (final ev in p.history)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SColor.panel,
                        border: Border.all(color: SColor.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.power_off_rounded, size: 16, color: SColor.crimson),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Выключен: ${formatDuration(ev.offDurationMs)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                ),
                              ),
                              if (ev.batteryAtOff >= 0)
                                TacticalBadge('Заряд ${ev.batteryAtOff}%', SColor.amber),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'С ${formatTimestamp(ev.offFromTs)} по ${formatTimestamp(ev.onAtTs)}',
                            style: const TextStyle(color: SColor.sub, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
              ],
            ],
          ),
        );
      },
    );
  }
}
