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
                            'Выбор любых приложений (${list.length})',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
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
                              fontWeight: FontWeight.w800,
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
                              fontWeight: FontWeight.w800,
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
                              fontWeight: FontWeight.w800,
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
                            fontWeight: FontWeight.w800,
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
                            fontWeight: FontWeight.w800,
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
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
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
        onSelectPath: (path, label, isDir) {
          appState.addWipeTarget(
            WipeTargetItem(
              id: 'file:$path',
              kind: 'file',
              mode: 'delete',
              label: label,
              target: path,
            ),
          );
          _snack('Добавлено в протокол: $label');
        },
      ),
    );
  }

  Future<void> _showPinVerifyModal() async {
    final ctl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SColor.panel,
        title: const Text('Код доступа владельца'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Обычный PIN (${appState.ownerPin}) сбрасывает таймер.\nКод принуждения (${appState.duressPin}) мгновенно выполняет удаление всех целей.',
              style: const TextStyle(color: SColor.sub, fontSize: 12.5, height: 1.35),
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
              final isDuress = await appState.verifyPinOrTriggerDuress(text);
              if (isDuress) {
                _snack('Сработал Duress PIN: цели удалены');
              } else {
                _snack('Таймер подтверждён на ${appState.wipeIntervalHours} ч.');
              }
            },
            style: FilledButton.styleFrom(backgroundColor: SColor.emerald, foregroundColor: SColor.bg),
            child: const Text('Проверить'),
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

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
          children: [
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
                                  child: Text(
                                    'ЧАСОВОЙ (DEAD MAN SWITCH)',
                                    style: TextStyle(
                                      color: SColor.sub,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: appState.wipeEnabled,
                                  activeColor: SColor.crimson,
                                  onChanged: (v) => appState.setWipeEnabled(v),
                                ),
                              ],
                            ),
                            Text(
                              appState.wipeEnabled
                                  ? 'Активен · Требуется отметка каждые ${appState.wipeIntervalHours} ч.'
                                  : 'Отключён · Автоудаление на паузе',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: SColor.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
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
                            _snack('Подтверждено! Таймер сброшен на ${appState.wipeIntervalHours} ч.');
                          },
                          icon: const Icon(Icons.verified_user_rounded, size: 18),
                          label: const Text(
                            'Я владелец (Сбросить таймер)',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
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
                        label: const Text('PIN', style: TextStyle(color: SColor.ink, fontWeight: FontWeight.w800)),
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
                        backgroundColor: SColor.panel,
                        labelStyle: TextStyle(
                          color: appState.wipeIntervalHours == h ? SColor.bg : SColor.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                        onSelected: (_) => appState.setWipeIntervalHours(h),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _showPickAllAppsSheet,
                    icon: const Icon(Icons.apps_rounded, size: 18, color: SColor.crimson),
                    label: const Text(
                      'Все приложения',
                      style: TextStyle(color: SColor.ink, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: SColor.panel,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: SColor.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _openFileExplorer,
                    icon: const Icon(Icons.folder_open_rounded, size: 18, color: SColor.cyan),
                    label: const Text(
                      'Файловый менеджер',
                      style: TextStyle(color: SColor.ink, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: SColor.panel,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: SColor.border),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (appState.wipeTargets.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: SColor.panel,
                  border: Border.all(color: SColor.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Список целей пуст. Выберите любые приложения или откройте встроенный Root-проводник, чтобы указать файлы и папки для автоматической очистки.',
                  style: TextStyle(color: SColor.sub, fontSize: 12.5, height: 1.35),
                ),
              )
            else ...[
              for (final t in appState.wipeTargets)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: SColor.panel,
                    border: Border.all(color: SColor.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        t.kind == 'app' ? Icons.android_rounded : Icons.folder_zip_rounded,
                        color: t.kind == 'app' ? SColor.crimson : SColor.cyan,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.label,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                            Text(
                              '${t.kind == "app" ? (t.mode == "freeze" ? "Заморозка (pm hide)" : "Удаление (pm uninstall)") : "Удаление (rm -rf)"} · ${t.target}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: SColor.sub, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => appState.removeWipeTarget(t.id),
                        icon: const Icon(Icons.close_rounded, color: SColor.sub, size: 18),
                      ),
                    ],
                  ),
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
                    style: TextStyle(color: SColor.crimson, fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SColor.crimson),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
            if (appState.wipeLogs.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'ЖУРНАЛ ВЫПОЛНЕННЫХ ОПЕРАЦИЙ',
                style: TextStyle(color: SColor.sub, fontSize: 11, fontWeight: FontWeight.w900),
              ),
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
