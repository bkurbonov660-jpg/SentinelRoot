import 'package:flutter/material.dart';
import 'app_state.dart';
import 'file_explorer_sheet.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'theme.dart';

class AutoWipePage extends StatefulWidget {
  const AutoWipePage({super.key});

  @override
  State<AutoWipePage> createState() => _AutoWipePageState();
}

class _AutoWipePageState extends State<AutoWipePage> {
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showPickAllAppsSheet() async {
    final installed = await NativeBridge.listAllInstalledApps();
    if (!mounted) return;
    String q = '';
    String filterTab = 'all';
    String actionMode = 'delete';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SColor.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final list = installed.where((a) {
            if (filterTab == 'user' && a.isSystem) return false;
            if (filterTab == 'system' && !a.isSystem) return false;
            if (q.trim().isEmpty) return true;
            final qq = q.trim().toLowerCase();
            return a.appName.toLowerCase().contains(qq) ||
                a.packageName.toLowerCase().contains(qq);
          }).toList()
            ..sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 14, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.85),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.apps_rounded, color: SColor.crimson, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Выбор приложений (${list.length})',
                            style: SText.title,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded, color: SColor.sub),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text('Все (${installed.length})'),
                            selected: filterTab == 'all',
                            selectedColor: SColor.cyan,
                            labelStyle: TextStyle(
                              color: filterTab == 'all' ? SColor.bg : SColor.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            onSelected: (_) => setS(() => filterTab = 'all'),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Пользовательские'),
                            selected: filterTab == 'user',
                            selectedColor: SColor.cyan,
                            labelStyle: TextStyle(
                              color: filterTab == 'user' ? SColor.bg : SColor.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            onSelected: (_) => setS(() => filterTab = 'user'),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Системные'),
                            selected: filterTab == 'system',
                            selectedColor: SColor.cyan,
                            labelStyle: TextStyle(
                              color: filterTab == 'system' ? SColor.bg : SColor.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            onSelected: (_) => setS(() => filterTab = 'system'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Режим:', style: TextStyle(color: SColor.sub, fontSize: 12)),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Удалить (pm uninstall)'),
                          selected: actionMode == 'delete',
                          selectedColor: SColor.crimson,
                          labelStyle: TextStyle(
                            color: actionMode == 'delete' ? SColor.ink : SColor.sub,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                          onSelected: (_) => setS(() => actionMode = 'delete'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Заморозить (pm hide)'),
                          selected: actionMode == 'freeze',
                          selectedColor: SColor.emerald,
                          labelStyle: TextStyle(
                            color: actionMode == 'freeze' ? SColor.bg : SColor.sub,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                          onSelected: (_) => setS(() => actionMode = 'freeze'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (v) => setS(() => q = v),
                      style: const TextStyle(color: SColor.ink),
                      decoration: InputDecoration(
                        hintText: 'Поиск по названию или пакету…',
                        hintStyle: const TextStyle(color: SColor.sub, fontSize: 12.5),
                        prefixIcon: const Icon(Icons.search_rounded, color: SColor.sub),
                        filled: true,
                        fillColor: SColor.card,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final a = list[i];
                          final already = appState.wipeTargets.any(
                              (x) => x.kind == 'app' && x.target == a.packageName);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              a.isSystem ? Icons.settings_suggest_rounded : Icons.android_rounded,
                              color: a.isSystem ? SColor.sub : SColor.cyan,
                            ),
                            title: Text(
                              a.appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                            subtitle: Text(
                              a.packageName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: SColor.sub, fontSize: 11),
                            ),
                            trailing: IconButton(
                              onPressed: () {
                                if (already) {
                                  appState.removeWipeTarget('app:${a.packageName}');
                                } else {
                                  appState.addWipeTarget(
                                    WipeTargetItem(
                                      id: 'app:${a.packageName}',
                                      kind: 'app',
                                      mode: actionMode,
                                      label: a.appName,
                                      target: a.packageName,
                                    ),
                                  );
                                }
                                setS(() {});
                              },
                              icon: Icon(
                                already
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                color: already ? SColor.emerald : SColor.crimson,
                              ),
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
        },
      ),
    );
  }

  Future<void> _openFileExplorer() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SColor.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FileExplorerSheet(
        onSelectPath: (path, label, isDir, sizeBytes) {
          appState.addWipeTarget(
            WipeTargetItem(
              id: 'file:$path',
              kind: 'file',
              mode: 'delete',
              label: label,
              target: path,
              sizeBytes: sizeBytes,
            ),
          );
          _snack('Добавлено в протокол: $label');
        },
      ),
    );
  }

  // МОДУЛЬ 6.2: Подтверждение полного сброса телефона с вводом слова «СБРОС»
  Future<void> _confirmFactoryResetToggle(bool enable) async {
    if (!enable) {
      await appState.setTargetCategoryFlags(factoryResetFlag: false);
      return;
    }
    final ctl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SColor.panel,
        title: const Text('⚠️ Полный сброс телефона', style: SText.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ Это сотрёт ВСЁ: фото, контакты, SMS, все приложения и разделы данных.\n\nЧтобы включить эту цель, введите слово СБРОС заглавными буквами:',
              style: TextStyle(color: SColor.crimson, fontSize: 12.5, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: SColor.ink, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: 'СБРОС',
                filled: true,
                fillColor: SColor.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              if (ctl.text.trim() == 'СБРОС') {
                Navigator.of(ctx).pop();
                await appState.setTargetCategoryFlags(factoryResetFlag: true);
                _snack('Полный сброс телефона включён в цели Часового');
              } else {
                _snack('Введите точную фразу: СБРОС');
              }
            },
            style: FilledButton.styleFrom(backgroundColor: SColor.crimson, foregroundColor: SColor.ink),
            child: const Text('Подтвердить СБРОС'),
          ),
        ],
      ),
    );
  }

  // МОДУЛЬ 4: Отмена 25-минутного самоуничтожения по PIN 9058
  Future<void> _showCancelSelfDestructDialog() async {
    final ctl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SColor.panel,
        title: const Text('Отмена самоуничтожения', style: SText.title),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          obscureText: true,
          style: const TextStyle(color: SColor.ink, fontSize: 18, letterSpacing: 4),
          decoration: InputDecoration(
            hintText: 'PIN владельца (9058)',
            filled: true,
            fillColor: SColor.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Закрыть'),
          ),
          FilledButton(
            onPressed: () async {
              final pin = ctl.text.trim();
              Navigator.of(ctx).pop();
              final ok = await NativeBridge.cancelSelfDestruct(pin);
              await appState.refreshData(silent: true);
              _snack(ok ? 'Самоуничтожение отменено!' : 'Неверный PIN владельца');
            },
            style: FilledButton.styleFrom(backgroundColor: SColor.emerald, foregroundColor: SColor.bg),
            child: const Text('Отменить таймер'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPinVerifyModal() async {
    final ctl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SColor.panel,
        title: const Text('Код доступа владельца (9058)', style: SText.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ввод PIN владельца (по умолчанию 9058) сбрасывает таймер и счётчик тревоги.\nВвод Duress PIN мгновенно запускает очистку.',
              style: TextStyle(color: SColor.sub, fontSize: 12.5, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: SColor.ink, fontSize: 18, letterSpacing: 4),
              decoration: InputDecoration(
                hintText: '••••',
                filled: true,
                fillColor: SColor.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final text = ctl.text.trim();
              Navigator.of(ctx).pop();
              final res = await appState.verifyPinCentralized(text);
              if (res == 'DURESS') {
                _snack('Сработал Duress PIN: цели удалены');
              } else if (res == 'OWNER') {
                _snack('Таймер подтверждён на ${appState.wipeIntervalHours} ч.');
              } else {
                _snack('Неверный PIN');
              }
            },
            style: FilledButton.styleFrom(backgroundColor: SColor.emerald, foregroundColor: SColor.bg),
            child: const Text('Проверить'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTelegramAndPinConfigModal() async {
    final ownerCtl = TextEditingController(text: appState.ownerPin);
    final duressCtl = TextEditingController(text: appState.duressPin);
    final pcCtl = TextEditingController(text: appState.pcAccessPin);
    final chatCtl = TextEditingController(text: appState.telegramChatId);
    final tokenCtl = TextEditingController(text: appState.telegramBotToken);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SColor.panel,
        title: const Text('Настройки PIN (PBKDF2) и Telegram', style: SText.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ownerCtl,
                decoration: const InputDecoration(labelText: 'PIN владельца (по умолч. 9058)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: duressCtl,
                decoration: const InputDecoration(labelText: 'Duress PIN принуждения (9999)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pcCtl,
                decoration: const InputDecoration(labelText: 'PC-Access-PIN для USB (9058)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: chatCtl,
                decoration: const InputDecoration(labelText: 'Telegram Chat ID (8271593233)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tokenCtl,
                decoration: const InputDecoration(labelText: 'Telegram Bot Token (необязательно)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await appState.updateSecurityPins(
                owner: ownerCtl.text,
                duress: duressCtl.text,
                pcPin: pcCtl.text,
                tgChat: chatCtl.text,
                tgToken: tokenCtl.text,
              );
              _snack('PBKDF2-хеши PIN и параметры Telegram сохранены');
            },
            style: FilledButton.styleFrom(backgroundColor: SColor.cyan, foregroundColor: SColor.bg),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const intervals = <int>[1, 6, 12, 24, 48, 72];
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final remMs = appState.remainingUntilWipeMs;
        final pct = appState.wipeCountdownProgress;
        final sdTs = appState.usbStatus.selfDestructAtTs;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final sdActive = sdTs > nowMs;
        final appTargets = appState.wipeTargets.where((t) => t.kind == 'app').toList();
        final fileTargets = appState.wipeTargets.where((t) => t.kind == 'file').toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 105),
          children: [
            // МОДУЛЬ 4 и 6.4: Блок «САМОУНИЧТОЖЕНИЕ» (если активен маркер)
            if (sdActive)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SColor.crimson.withOpacity(0.16),
                  border: Border.all(color: SColor.crimson, width: 1.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_rounded, color: SColor.crimson, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⚠️ Самоуничтожение запланировано на ${formatTimestamp(sdTs)} (осталось ${formatDuration(sdTs - nowMs, clockMode: true)})',
                            style: const TextStyle(
                              color: SColor.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _showCancelSelfDestructDialog,
                        icon: const Icon(Icons.shield_rounded, size: 18),
                        label: const Text('Отменить самоуничтожение (PIN 9058)'),
                        style: FilledButton.styleFrom(
                          backgroundColor: SColor.crimson,
                          foregroundColor: SColor.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // МОДУЛЬ 6.4: Блок «ТАЙМЕР»
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SColor.panel,
                border: Border.all(
                  color: appState.wipeEnabled ? SColor.crimson : SColor.border,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      TelemetryRingGauge(
                        segments: [
                          (pct, appState.wipeEnabled ? SColor.emerald : SColor.sub),
                          ((1.0 - pct).clamp(0.0, 1.0), SColor.crimson.withOpacity(0.35)),
                        ],
                        centerTitle: appState.wipeEnabled
                            ? formatDuration(remMs, clockMode: true)
                            : 'ПАУЗА',
                        centerSubtitle: 'ДО ОЧИСТКИ',
                        size: 132,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('ТАЙМЕР ЧАСОВОГО', style: SText.section),
                                ),
                                Switch(
                                  value: appState.wipeEnabled,
                                  activeColor: SColor.crimson,
                                  onChanged: (v) async {
                                    final ok = await appState.setWipeEnabled(v);
                                    if (!ok) {
                                      _snack('Выберите хотя бы одну цель (приложение, папку или сброс)');
                                    }
                                  },
                                ),
                              ],
                            ),
                            Text(
                              appState.wipeEnabled
                                  ? 'Активен · Интервал ${appState.wipeIntervalHours} ч.'
                                  : 'Отключён · Выберите цели ниже',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: SColor.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Отметка: ${formatTimestamp(appState.lastOwnerConfirmTs)}',
                              style: const TextStyle(color: SColor.sub, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await appState.confirmOwnerPresent();
                            _snack('Таймер сброшен на ${appState.wipeIntervalHours} ч.');
                          },
                          icon: const Icon(Icons.verified_user_rounded, size: 18),
                          label: const Text(
                            'Я владелец (Сбросить таймер)',
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
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _showPinVerifyModal,
                        icon: const Icon(Icons.dialpad_rounded, size: 16, color: SColor.crimson),
                        label: const Text('PIN', style: TextStyle(color: SColor.ink, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: SColor.border),
                          backgroundColor: SColor.card,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // МОДУЛЬ 6.1 и 6.4: Блок «ВРЕМЯ СРАБАТЫВАНИЯ»
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SColor.panel,
                border: Border.all(color: SColor.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ВРЕМЯ СРАБАТЫВАНИЯ И ИНТЕРВАЛ', style: SText.section),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final h in intervals)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(h == 24 ? '24 ч (Сутки)' : '$h ч'),
                              selected: appState.wipeIntervalHours == h,
                              selectedColor: SColor.cyan,
                              backgroundColor: SColor.card,
                              labelStyle: TextStyle(
                                color: appState.wipeIntervalHours == h ? SColor.bg : SColor.ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                              onSelected: (_) => appState.setWipeIntervalHours(h),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: appState.useExactTriggerTime,
                        activeColor: SColor.cyan,
                        onChanged: (v) => appState.setExactTriggerTime(enabled: v ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          'Точное время суток (TimePicker 00:00–23:59)',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: appState.triggerHour,
                              minute: appState.triggerMinute,
                            ),
                          );
                          if (picked != null) {
                            await appState.setExactTriggerTime(
                              enabled: true,
                              hour: picked.hour,
                              minute: picked.minute,
                            );
                          }
                        },
                        icon: const Icon(Icons.access_time_rounded, size: 16, color: SColor.cyan),
                        label: Text(
                          '${pad2(appState.triggerHour)}:${pad2(appState.triggerMinute)}',
                          style: SText.mono,
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: SColor.border),
                          backgroundColor: SColor.card,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // МОДУЛЬ 5 и 6.2: Блок «ЦЕЛИ (чекбоксы)» + Тихий режим (Идея 175)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SColor.panel,
                border: Border.all(color: SColor.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ЧТО УДАЛЯТЬ ПРИ СРАБАТЫВАНИИ (ЦЕЛИ)', style: SText.section),
                  const SizedBox(height: 6),
                  // МОДУЛЬ 5: Чекбокс «Тихий режим»
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: appState.silentWipeMode,
                    activeColor: SColor.emerald,
                    title: const Text(
                      'Тихий режим (файлы останутся на месте, но станут нечитаемыми)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Перезапись блоками по 64 КБ (SecureRandom) с сохранением размера и даты mtime',
                      style: TextStyle(fontSize: 11, color: SColor.sub),
                    ),
                    onChanged: (v) => appState.setSilentWipeMode(v ?? true),
                  ),
                  if (appState.hasLargeSilentTarget)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SColor.amber.withOpacity(0.12),
                        border: Border.all(color: SColor.amber),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '⚠️ Тихий wipe медленнее обычного: среди целей есть файлы >500 МБ, перезапись может занять несколько минут.',
                        style: TextStyle(color: SColor.amber, fontSize: 11.5),
                      ),
                    ),
                  const Divider(color: SColor.border),

                  // Чекбокс 1: Приложения
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: appState.wipeAppsEnabled,
                    activeColor: SColor.cyan,
                    title: Text(
                      'Удалить выбранные приложения (${appTargets.length})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    onChanged: (v) => appState.setTargetCategoryFlags(appsFlag: v ?? false),
                  ),
                  if (appState.wipeAppsEnabled) ...[
                    for (final t in appTargets)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.android_rounded, color: SColor.crimson, size: 18),
                        title: Text(t.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(t.target, style: const TextStyle(color: SColor.sub, fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: SColor.sub),
                          onPressed: () => appState.removeWipeTarget(t.id),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _showPickAllAppsSheet,
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: SColor.cyan),
                        label: const Text('+ Добавить приложение'),
                      ),
                    ),
                  ],
                  const Divider(color: SColor.border),

                  // Чекбокс 2: Папки и файлы
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: appState.wipeFilesEnabled,
                    activeColor: SColor.cyan,
                    title: Text(
                      'Удалить выбранные папки/файлы (${fileTargets.length})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    onChanged: (v) => appState.setTargetCategoryFlags(filesFlag: v ?? false),
                  ),
                  if (appState.wipeFilesEnabled) ...[
                    for (final t in fileTargets)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.folder_zip_rounded, color: SColor.cyan, size: 18),
                        title: Text(t.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(t.target, style: const TextStyle(color: SColor.sub, fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: SColor.sub),
                          onPressed: () => appState.removeWipeTarget(t.id),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _openFileExplorer,
                        icon: const Icon(Icons.create_new_folder_outlined, size: 16, color: SColor.emerald),
                        label: const Text('+ Добавить папку / файл'),
                      ),
                    ),
                  ],
                  const Divider(color: SColor.border),

                  // Чекбокс 3: Полный сброс телефона (Factory Reset)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: appState.factoryResetEnabled,
                    activeColor: SColor.crimson,
                    title: const Text(
                      'Полный сброс телефона (factory reset)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SColor.crimson),
                    ),
                    subtitle: const Text(
                      '⚠️ Это сотрёт ВСЁ: фото, контакты, SMS, все приложения',
                      style: TextStyle(fontSize: 11.5, color: SColor.amber),
                    ),
                    onChanged: (v) => _confirmFactoryResetToggle(v ?? false),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await appState.triggerWipeNow();
                        _snack('Протокол очистки выполнен');
                      },
                      icon: const Icon(Icons.local_fire_department_rounded, color: SColor.crimson, size: 18),
                      label: const Text(
                        'Выполнить очистку выбранных целей немедленно',
                        style: TextStyle(color: SColor.crimson, fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: SColor.crimson),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // МОДУЛЬ 1 и 6.3, 6.4: Блок «ОТЧЁТЫ»
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SColor.panel,
                border: Border.all(color: SColor.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.send_rounded, color: SColor.cyan, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Отчёты отправляются на @Ghtrdhy',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        Text(
                          'Автоматически за 5 мин до дедлайна и после очистки · Chat ID: ${appState.telegramChatId}',
                          style: const TextStyle(color: SColor.sub, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _showTelegramAndPinConfigModal,
                    icon: const Icon(Icons.tune_rounded, color: SColor.cyan),
                    tooltip: 'Настройки PIN и Telegram',
                  ),
                  IconButton(
                    onPressed: () async {
                      final ok = await NativeBridge.triggerTestTelegramAlert();
                      _snack(ok ? 'Тестовый отчёт отправлен в Telegram' : 'Не удалось отправить (проверьте сеть/токен)');
                    },
                    icon: const Icon(Icons.notifications_active_outlined, color: SColor.emerald),
                    tooltip: 'Проверить отправку в Telegram',
                  ),
                ],
              ),
            ),

            // МОДУЛЬ 6.4: Блок «ЖУРНАЛ»
            if (appState.wipeLogs.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('ЖУРНАЛ ВЫПОЛНЕННЫХ ОПЕРАЦИЙ', style: SText.section),
              const SizedBox(height: 8),
              for (final log in appState.wipeLogs)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SColor.panel,
                    border: Border.all(color: SColor.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        log.ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        color: log.ok ? SColor.emerald : SColor.crimson,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${log.target}\n${formatTimestamp(log.ts)} · ${log.details}',
                          style: const TextStyle(color: SColor.sub, fontSize: 11.5, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
