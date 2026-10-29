import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'main.dart';
import 'native_bridge.dart';
import 'theme.dart';

// МОДУЛЬ 2: Скрытый вход через реалистичный «Календарь» (3 нажатия на 5 февраля за 3 сек -> PIN 9058)
class DecoyCalendarPage extends StatefulWidget {
  const DecoyCalendarPage({super.key});

  @override
  State<DecoyCalendarPage> createState() => _DecoyCalendarPageState();
}

class _DecoyCalendarPageState extends State<DecoyCalendarPage> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, 2, 1);
  DateTime _selectedDate = DateTime.now();

  int _feb5TapCount = 0;
  DateTime? _firstFeb5TapTime;
  int _failedPinAttempts = 0;

  static const List<String> _monthNames = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  static const List<String> _weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  List<(String, String, String)> _eventsForDay(DateTime d) {
    final seed = d.day % 4;
    if (seed == 0) {
      return const [
        ('10:00', 'Планёрка с командой', 'Кабинет 304 · Google Meet'),
        ('14:30', 'Созвон по бюджету', 'Финансовый отдел'),
        ('18:00', 'Тренировка в зале', 'Фитнес-клуб'),
      ];
    } else if (seed == 1) {
      return const [
        ('09:30', 'Проверка отчётов за неделю', 'Документооборот'),
        ('13:00', 'Деловой обед', 'Центральный офис'),
        ('16:15', 'Звонок поставщику', 'Логистика'),
      ];
    } else if (seed == 2) {
      return const [
        ('11:00', 'Встреча с клиентом', 'Переговорная А'),
        ('15:00', 'Ревью задач спринта', 'Онлайн-конференция'),
      ];
    }
    return const [
      ('10:30', 'Анализ показателей', 'Ежедневный отчёт'),
      ('14:30', 'Созвон 14:30 · Рабочая группа', 'Телемост'),
      ('17:30', 'Личные дела / Покупки', 'Список задач'),
    ];
  }

  void _onDayTapped(DateTime date) {
    setState(() {
      _selectedDate = date;
    });

    // Проверяем, нажата ли дата 5 февраля (5.02)
    if (date.month == 2 && date.day == 5) {
      final now = DateTime.now();
      if (_firstFeb5TapTime == null ||
          now.difference(_firstFeb5TapTime!).inMilliseconds > 3000) {
        _firstFeb5TapTime = now;
        _feb5TapCount = 1;
      } else {
        _feb5TapCount += 1;
        if (_feb5TapCount >= 3) {
          _feb5TapCount = 0;
          _firstFeb5TapTime = null;
          _showSecretPinDialog();
        }
      }
    } else {
      _feb5TapCount = 0;
      _firstFeb5TapTime = null;
    }
  }

  Future<void> _showSecretPinDialog() async {
    final ctl = TextEditingController();
    String? errorMsg;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: SColor.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: SColor.border),
          ),
          title: const Text('Синхронизация календаря', style: SText.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Введите код доступа к защищённому профилю:',
                style: TextStyle(color: SColor.sub, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctl,
                autofocus: true,
                keyboardType: TextInputType.number,
                obscureText: true,
                style: const TextStyle(
                  color: SColor.ink,
                  fontSize: 20,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  hintText: '••••',
                  errorText: errorMsg,
                  filled: true,
                  fillColor: SColor.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена', style: TextStyle(color: SColor.sub)),
            ),
            FilledButton(
              onPressed: () async {
                final pin = ctl.text.trim();
                final res = await appState.verifyPinCentralized(pin);
                if (res == 'OWNER' || res == 'DURESS') {
                  _failedPinAttempts = 0;
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const ObsidianCommandShell()),
                  );
                } else {
                  _failedPinAttempts += 1;
                  if (_failedPinAttempts >= 3) {
                    // МОДУЛЬ 2.8 и МОДУЛЬ 4: 3 неверных PIN -> запуск самоуничтожения через 25 мин и закрытие
                    await NativeBridge.scheduleSelfDestruct(25 * 60 * 1000);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    SystemNavigator.pop();
                  } else {
                    setS(() {
                      ctl.clear();
                      errorMsg = 'Неверный код (осталось попыток: ${3 - _failedPinAttempts})';
                    });
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: SColor.cyan,
                foregroundColor: SColor.bg,
              ),
              child: const Text('Войти', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final leadingBlanks = firstDay.weekday - 1;
    final events = _eventsForDay(_selectedDate);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // Обычный выход кнопкой «Назад» просто закрывает приложение без пароля
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: SColor.bg,
        appBar: AppBar(
          backgroundColor: SColor.panel,
          elevation: 0,
          title: const Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: SColor.cyan, size: 22),
              SizedBox(width: 10),
              Text(
                'Календарь и Расписание',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SColor.ink),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
                  _selectedDate = DateTime.now();
                });
              },
              icon: const Icon(Icons.today_rounded, color: SColor.sub),
              tooltip: 'Сегодня',
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SColor.panel,
                  border: Border.all(color: SColor.border),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                            });
                          },
                          icon: const Icon(Icons.chevron_left_rounded, color: SColor.ink),
                        ),
                        Text(
                          '${_monthNames[(_focusedMonth.month - 1) % 12]} ${_focusedMonth.year}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: SColor.ink,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                            });
                          },
                          icon: const Icon(Icons.chevron_right_rounded, color: SColor.ink),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final wd in _weekDays)
                          Expanded(
                            child: Center(
                              child: Text(
                                wd,
                                style: const TextStyle(
                                  color: SColor.sub,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: leadingBlanks + daysInMonth,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        childAspectRatio: 1.15,
                      ),
                      itemBuilder: (_, idx) {
                        if (idx < leadingBlanks) return const SizedBox.shrink();
                        final day = idx - leadingBlanks + 1;
                        final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
                        final isSelected = _selectedDate.year == date.year &&
                            _selectedDate.month == date.month &&
                            _selectedDate.day == date.day;
                        // Дата 5 февраля никак не выделяется визуально среди остальных
                        return GestureDetector(
                          onTap: () => _onDayTapped(date),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? SColor.cyan : SColor.card,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: isSelected ? SColor.bg : SColor.ink,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      'СОБЫТИЯ НА ${pad2(_selectedDate.day)}.${pad2(_selectedDate.month)}.${_selectedDate.year}',
                      style: SText.section,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: events.length,
                  itemBuilder: (_, i) {
                    final ev = events[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SColor.panel,
                        border: Border.all(color: SColor.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: SColor.card,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ev.$1,
                              style: const TextStyle(
                                color: SColor.cyan,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ev.$2,
                                  style: const TextStyle(
                                    color: SColor.ink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ev.$3,
                                  style: const TextStyle(color: SColor.sub, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
