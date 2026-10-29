import 'package:flutter/material.dart';
import 'app_state.dart';
import 'decoy_calendar_page.dart';
import 'native_bridge.dart';
import 'theme.dart';

class PcAccessPage extends StatefulWidget {
  const PcAccessPage({super.key});

  @override
  State<PcAccessPage> createState() => _PcAccessPageState();
}

class _PcAccessPageState extends State<PcAccessPage> {
  final TextEditingController _pinCtl = TextEditingController();
  int _selectedMinutes = 15;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _pinCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const durations = [5, 15, 30, 60];
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final st = appState.usbStatus;
        final now = DateTime.now().millisecondsSinceEpoch;
        final permitted = st.permitted && st.expiresAtTs > now;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 105),
          children: [
            // Статус блокировки USB / ADB / MTP
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SColor.panel,
                border: Border.all(
                  color: permitted ? SColor.emerald : SColor.cyan,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        permitted ? Icons.usb_rounded : Icons.usb_off_rounded,
                        color: permitted ? SColor.emerald : SColor.crimson,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          permitted
                              ? '🔓 Разрешено до ${formatTimestamp(st.expiresAtTs)}'
                              : '🔒 USB заблокирован (ADB / MTP / Порты 5555 и 5037 закрыты)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: SColor.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'По умолчанию любое подключение кабеля или ноутбука без предварительного ввода PC-Access-PIN блокирует передачу данных (sys.usb.config=none, stop adbd) и отправляет тревогу в Telegram.',
                    style: TextStyle(color: SColor.sub, fontSize: 12, height: 1.35),
                  ),
                  if (permitted) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await NativeBridge.revokeUsbAccess();
                          await appState.refreshData(silent: true);
                          _snack('USB и ADB немедленно заблокированы');
                        },
                        icon: const Icon(Icons.lock_rounded, color: SColor.crimson, size: 18),
                        label: const Text(
                          'Заблокировать доступ с ПК сейчас',
                          style: TextStyle(color: SColor.crimson, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: SColor.crimson)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // МОДУЛЬ 9: Многошаговый сценарий разрешения доступа к ПК
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
                  const Text('РАЗРЕШИТЬ ДОСТУП С ПК (MTP + ADB)', style: SText.section),
                  const SizedBox(height: 10),
                  const Text(
                    '1. Введите отдельный PC-Access-PIN (по умолчанию 9058 или 9058-PC):',
                    style: TextStyle(color: SColor.ink, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pinCtl,
                    obscureText: true,
                    style: const TextStyle(color: SColor.ink, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'Введите PC-Access-PIN…',
                      filled: true,
                      fillColor: SColor.card,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '2. Выберите длительность сессии:',
                    style: TextStyle(color: SColor.ink, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final m in durations)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('$m мин'),
                              selected: _selectedMinutes == m,
                              selectedColor: SColor.cyan,
                              backgroundColor: SColor.card,
                              labelStyle: TextStyle(
                                color: _selectedMinutes == m ? SColor.bg : SColor.ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() => _selectedMinutes = m),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final pin = _pinCtl.text.trim();
                        if (pin.isEmpty) {
                          _snack('Введите PC-Access-PIN');
                          return;
                        }
                        final ok = await NativeBridge.grantUsbAccess(
                          durationMin: _selectedMinutes,
                          pin: pin,
                        );
                        _pinCtl.clear();
                        await appState.refreshData(silent: true);
                        if (ok) {
                          _snack('🔓 USB и MTP разрешены на $_selectedMinutes мин.');
                        } else {
                          _snack('Неверный PC-Access-PIN! Попытка зафиксирована.');
                        }
                      },
                      icon: const Icon(Icons.laptop_mac_rounded, size: 18),
                      label: Text(
                        'Разрешить доступ с ПК на $_selectedMinutes мин.',
                        style: const TextStyle(fontWeight: FontWeight.w700),
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

            // МОДУЛЬ 2: Управление скрытым режимом «Календарь»
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
                  const Text('СКРЫТЫЙ РЕЖИМ («КАЛЕНДАРЬ»)', style: SText.section),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: appState.stealthCalendarMode,
                    activeColor: SColor.cyan,
                    title: const Text(
                      'Маскировка под системный «Календарь»',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    subtitle: const Text(
                      'Меняет иконку в лончере на «Календарь». Для входа нажмите 3 раза подряд на дату 5 февраля (5.02) за 3 секунды и введите PIN 9058.',
                      style: TextStyle(color: SColor.sub, fontSize: 11.5, height: 1.35),
                    ),
                    onChanged: (v) async {
                      await appState.setStealthCalendar(v);
                      _snack(v
                          ? 'Включён скрытый режим «Календарь»'
                          : 'Возвращена стандартная иконка SentinelRoot');
                    },
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const DecoyCalendarPage()),
                        );
                      },
                      icon: const Icon(Icons.calendar_month_rounded, size: 18, color: SColor.cyan),
                      label: const Text(
                        'Перейти в прикрытие «Календарь» сейчас',
                        style: TextStyle(color: SColor.ink, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: SColor.border)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // МОДУЛЬ 8: Счётчик попыток отключения защиты и Panic Lockdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SColor.panel,
                border: Border.all(
                  color: st.panicActive ? SColor.crimson : SColor.border,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.crisis_alert_rounded, color: SColor.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'СЧЁТЧИК ПОПЫТОК ОТКЛЮЧЕНИЯ: ${st.panicAttempts} / 3',
                          style: SText.section,
                        ),
                      ),
                      TacticalBadge(
                        st.panicActive ? 'PANIC АКТИВЕН' : 'НОРМА',
                        st.panicActive ? SColor.crimson : SColor.emerald,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'При 3 попытках отключения защиты (попытка снять права администратора, несанкционированный ADB, 3 неверных PIN) включается Panic Lockdown: отключаются все сети, яркость 100% и сирена на максимальной громкости.',
                    style: TextStyle(color: SColor.sub, fontSize: 12, height: 1.35),
                  ),
                  if (st.panicActive || st.panicAttempts > 0) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await NativeBridge.stopPanicLockdown(appState.ownerPin);
                          await appState.refreshData(silent: true);
                          _snack('Счётчик тревоги сброшен, сирена остановлена');
                        },
                        icon: const Icon(Icons.verified_user_rounded, size: 18),
                        label: const Text('Сбросить тревогу (PIN владельца 9058)'),
                        style: FilledButton.styleFrom(
                          backgroundColor: SColor.emerald,
                          foregroundColor: SColor.bg,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
