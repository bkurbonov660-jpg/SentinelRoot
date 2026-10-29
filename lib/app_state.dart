import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'theme.dart';

class AppState extends ChangeNotifier {
  SharedPreferences? _prefs;
  String period = 'day';
  bool includeSystemApps = false;
  bool showBackgroundRadar = true;
  bool showPowerHistory = true;
  bool loading = false;

  // МОДУЛЬ 2: Скрытый режим через Календарь
  bool stealthCalendarMode = false;

  // МОДУЛЬ 3 и 9: Пароль 9058 везде по умолчанию
  String ownerPin = '9058';
  String duressPin = '9999';
  String pcAccessPin = '9058';

  // МОДУЛЬ 1 и 6.3: Telegram настройки (chat_id 8271593233 по умолчанию)
  String telegramChatId = '8271593233';
  String telegramBotToken = '';

  // МОДУЛЬ 5 и 6: Расширенные настройки Часового
  bool wipeEnabled = false;
  int wipeIntervalHours = 24;
  int lastOwnerConfirmTs = DateTime.now().millisecondsSinceEpoch;
  bool useExactTriggerTime = false;
  int triggerHour = 3;
  int triggerMinute = 0;
  bool silentWipeMode = true;
  bool wipeAppsEnabled = true;
  bool wipeFilesEnabled = true;
  bool factoryResetEnabled = false;
  List<WipeTargetItem> wipeTargets = [];
  List<WipeLogEntry> wipeLogs = [];

  // МОДУЛЬ 4, 7, 8, 9: Статус самоуничтожения, USB и Panic Lockdown
  UsbGuardStatus usbStatus = const UsbGuardStatus();

  // МОДУЛЬ 10: Живой монитор скорости интернета (30 последних точек для Sparkline)
  String speedIfaceMode = 'auto'; // 'auto' | 'wifi' | 'mobile'
  NetSpeedSnapshot currentSpeed = const NetSpeedSnapshot();
  final List<int> rxSpeedHistory = List<int>.filled(30, 0, growable: true);
  final List<int> txSpeedHistory = List<int>.filled(30, 0, growable: true);

  PowerStateSnapshot power = const PowerStateSnapshot(
    bootTimeTs: 0,
    currentUptimeMs: 0,
    accumulatedActiveMs: 0,
    accumulatedOffMs: 0,
    firstInstallTs: 0,
    lastHeartbeatTs: 0,
    batteryPct: 100,
    isCharging: false,
    hasRoot: false,
    hasUsagePerm: false,
    ramTotalMb: 4096,
    ramUsedMb: 2048,
    history: [],
  );

  List<AppUsageItem> apps = [];
  int totalScreenMs = 0;
  int totalMobileBytes = 0;
  int totalWifiBytes = 0;

  Timer? _pollTimer;
  Timer? _secondTimer;
  bool _lifecycleActive = true;
  int _localTickMs = 0;
  int _lastSyncWallMs = DateTime.now().millisecondsSinceEpoch;

  int get liveCurrentUptimeMs =>
      power.currentUptimeMs > 0 ? power.currentUptimeMs + _localTickMs : 0;

  int get liveContinuousActiveMs =>
      power.accumulatedActiveMs + liveCurrentUptimeMs;

  int get nextWipeDeadlineTs => computeNextTriggerTimestamp(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        lastConfirmMs: lastOwnerConfirmTs,
        intervalHours: wipeIntervalHours,
        useExactTime: useExactTriggerTime,
        triggerHour: triggerHour,
        triggerMinute: triggerMinute,
      );

  int get remainingUntilWipeMs {
    final rem = nextWipeDeadlineTs - DateTime.now().millisecondsSinceEpoch;
    return rem > 0 ? rem : 0;
  }

  double get wipeCountdownProgress {
    final total = wipeIntervalHours * 3600 * 1000;
    if (total <= 0) return 1.0;
    return (remainingUntilWipeMs / total).clamp(0.0, 1.0);
  }

  bool get hasLargeSilentTarget =>
      silentWipeMode &&
      wipeFilesEnabled &&
      wipeTargets.any((t) => t.kind == 'file' && t.sizeBytes > 500 * 1024 * 1024);

  bool get hasAnySelectedTarget {
    final hasApp = wipeAppsEnabled && wipeTargets.any((t) => t.kind == 'app');
    final hasFile = wipeFilesEnabled && wipeTargets.any((t) => t.kind == 'file');
    return hasApp || hasFile || factoryResetEnabled;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    showBackgroundRadar = _prefs?.getBool('ui_bg_radar') ?? true;
    showPowerHistory = _prefs?.getBool('ui_pwr_hist') ?? true;
    includeSystemApps = _prefs?.getBool('ui_sys_apps') ?? false;
    stealthCalendarMode = _prefs?.getBool('stealth_calendar_mode') ?? false;
    speedIfaceMode = _prefs?.getString('speed_iface_mode') ?? 'auto';

    wipeEnabled = _prefs?.getBool('wipe_enabled') ?? false;
    wipeIntervalHours = _prefs?.getInt('wipe_hours') ?? 24;
    useExactTriggerTime = _prefs?.getBool('wipe_use_exact_time') ?? false;
    triggerHour = _prefs?.getInt('wipe_trigger_hour') ?? 3;
    triggerMinute = _prefs?.getInt('wipe_trigger_minute') ?? 0;
    silentWipeMode = _prefs?.getBool('wipe_silent_mode') ?? true;
    wipeAppsEnabled = _prefs?.getBool('wipe_apps_enabled') ?? true;
    wipeFilesEnabled = _prefs?.getBool('wipe_files_enabled') ?? true;
    factoryResetEnabled = _prefs?.getBool('wipe_factory_reset') ?? false;

    ownerPin = _prefs?.getString('wipe_owner_pin') ?? '9058';
    if (ownerPin == '1111') ownerPin = '9058';
    duressPin = _prefs?.getString('wipe_duress_pin') ?? '9999';
    pcAccessPin = _prefs?.getString('pc_access_pin') ?? '9058';
    telegramChatId = _prefs?.getString('tg_chat_id') ?? '8271593233';
    telegramBotToken = _prefs?.getString('tg_bot_token') ?? '';

    lastOwnerConfirmTs = _prefs?.getInt('wipe_last_confirm') ??
        DateTime.now().millisecondsSinceEpoch;

    final rawTargets = _prefs?.getString('wipe_targets');
    if (rawTargets != null && rawTargets.isNotEmpty) {
      try {
        final list = jsonDecode(rawTargets);
        if (list is List) {
          wipeTargets = list
              .whereType<Map>()
              .map((e) => WipeTargetItem.fromJson(e))
              .toList();
        }
      } catch (_) {}
    }

    await refreshData();
    _startRealtimeTimers();
  }

  void _startRealtimeTimers() {
    _secondTimer?.cancel();
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_lifecycleActive) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      _localTickMs = now - _lastSyncWallMs;
      final spd = await NativeBridge.getNetSpeed(ifaceMode: speedIfaceMode);
      currentSpeed = spd;
      if (rxSpeedHistory.length >= 30) rxSpeedHistory.removeAt(0);
      if (txSpeedHistory.length >= 30) txSpeedHistory.removeAt(0);
      rxSpeedHistory.add(spd.rxBps);
      txSpeedHistory.add(spd.txBps);
      notifyListeners();
    });

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!_lifecycleActive) return;
      refreshData(silent: true);
    });
  }

  // МОДУЛЬ 10.4: Остановка таймера скорости при сворачивании приложения
  void setLifecycleActive(bool active) {
    _lifecycleActive = active;
    if (active) {
      refreshData(silent: true);
      _startRealtimeTimers();
    } else {
      _secondTimer?.cancel();
      _pollTimer?.cancel();
    }
  }

  void cycleSpeedIfaceMode() {
    if (speedIfaceMode == 'auto') {
      speedIfaceMode = 'wifi';
    } else if (speedIfaceMode == 'wifi') {
      speedIfaceMode = 'mobile';
    } else {
      speedIfaceMode = 'auto';
    }
    _prefs?.setString('speed_iface_mode', speedIfaceMode);
    notifyListeners();
  }

  void setSpeedIfaceMode(String mode) {
    speedIfaceMode = mode;
    _prefs?.setString('speed_iface_mode', mode);
    notifyListeners();
  }

  Future<void> setStealthCalendar(bool v) async {
    stealthCalendarMode = v;
    await _prefs?.setBool('stealth_calendar_mode', v);
    await NativeBridge.setStealthCalendarMode(v);
    await refreshData(silent: true);
  }

  Future<void> setPeriod(String p) async {
    if (period == p) return;
    period = p;
    notifyListeners();
    await refreshData();
  }

  void toggleSystemApps(bool v) {
    includeSystemApps = v;
    _prefs?.setBool('ui_sys_apps', v);
    notifyListeners();
  }

  void toggleBackgroundRadar() {
    showBackgroundRadar = !showBackgroundRadar;
    _prefs?.setBool('ui_bg_radar', showBackgroundRadar);
    notifyListeners();
  }

  void togglePowerHistory() {
    showPowerHistory = !showPowerHistory;
    _prefs?.setBool('ui_pwr_hist', showPowerHistory);
    notifyListeners();
  }

  Future<void> refreshData({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    try {
      final data = await NativeBridge.getDashboard(period: period);
      usbStatus = await NativeBridge.getUsbStatus();
      if (data.isNotEmpty) {
        if (data['power'] is Map) {
          power = PowerStateSnapshot.fromMap(data['power'] as Map);
        }
        final rawApps = data['apps'];
        if (rawApps is List) {
          apps = rawApps
              .whereType<Map>()
              .map((e) => AppUsageItem.fromMap(e))
              .toList();
        }
        totalScreenMs = (data['totalScreenMs'] as num?)?.toInt() ?? 0;
        totalMobileBytes = (data['totalMobileBytes'] as num?)?.toInt() ?? 0;
        totalWifiBytes = (data['totalWifiBytes'] as num?)?.toInt() ?? 0;

        if (data['wipe'] is Map) {
          final wm = data['wipe'] as Map;
          if (wm['enabled'] is bool) wipeEnabled = wm['enabled'] as bool;
          if (wm['intervalHours'] is num) {
            wipeIntervalHours = (wm['intervalHours'] as num).toInt();
          }
          if (wm['lastConfirmTs'] is num) {
            lastOwnerConfirmTs = (wm['lastConfirmTs'] as num).toInt();
          }
          if (wm['useExactTime'] is bool) {
            useExactTriggerTime = wm['useExactTime'] as bool;
          }
          if (wm['triggerHour'] is num) {
            triggerHour = (wm['triggerHour'] as num).toInt();
          }
          if (wm['triggerMinute'] is num) {
            triggerMinute = (wm['triggerMinute'] as num).toInt();
          }
          if (wm['silent'] is bool) {
            silentWipeMode = wm['silent'] as bool;
          }
          if (wm['wipeAppsEnabled'] is bool) {
            wipeAppsEnabled = wm['wipeAppsEnabled'] as bool;
          }
          if (wm['wipeFilesEnabled'] is bool) {
            wipeFilesEnabled = wm['wipeFilesEnabled'] as bool;
          }
          if (wm['factoryResetEnabled'] is bool) {
            factoryResetEnabled = wm['factoryResetEnabled'] as bool;
          }
          if (wm['targets'] is List) {
            wipeTargets = (wm['targets'] as List)
                .whereType<Map>()
                .map((e) => WipeTargetItem.fromJson(e))
                .toList();
          }
          if (wm['logs'] is List) {
            wipeLogs = (wm['logs'] as List)
                .whereType<Map>()
                .map((e) => WipeLogEntry.fromJson(e))
                .toList();
          }
        }
        _lastSyncWallMs = DateTime.now().millisecondsSinceEpoch;
        _localTickMs = 0;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> grantRootPermissions() async {
    final ok = await NativeBridge.requestRootAndPermissions();
    await refreshData();
    return ok;
  }

  Future<void> toggleFirewallForApp(AppUsageItem item) async {
    await NativeBridge.toggleAppFirewall(item.uid, item.packageName, !item.isNetBlocked);
    await refreshData(silent: true);
  }

  Future<void> toggleFreezeForApp(String pkg, bool freeze) async {
    await NativeBridge.toggleAppFreeze(pkg, freeze);
    await refreshData(silent: true);
  }

  Future<void> killAndCleanApp(String pkg) async {
    await NativeBridge.forceStopAndClearCache(pkg);
    await refreshData(silent: true);
  }

  Future<String> boostRamAndPurgeCaches() async {
    final msg = await NativeBridge.purgeSystemRamAndCaches();
    await refreshData(silent: true);
    return msg;
  }

  Future<void> setDailyLimitForApp(String pkg, int minutes) async {
    await NativeBridge.setAppDailyLimit(pkg, minutes);
    await refreshData(silent: true);
  }

  Future<void> _persistWipeSettings() async {
    await _prefs?.setBool('wipe_enabled', wipeEnabled);
    await _prefs?.setInt('wipe_hours', wipeIntervalHours);
    await _prefs?.setInt('wipe_last_confirm', lastOwnerConfirmTs);
    await _prefs?.setBool('wipe_use_exact_time', useExactTriggerTime);
    await _prefs?.setInt('wipe_trigger_hour', triggerHour);
    await _prefs?.setInt('wipe_trigger_minute', triggerMinute);
    await _prefs?.setBool('wipe_silent_mode', silentWipeMode);
    await _prefs?.setBool('wipe_apps_enabled', wipeAppsEnabled);
    await _prefs?.setBool('wipe_files_enabled', wipeFilesEnabled);
    await _prefs?.setBool('wipe_factory_reset', factoryResetEnabled);
    await _prefs?.setString('wipe_owner_pin', ownerPin);
    await _prefs?.setString('wipe_duress_pin', duressPin);
    await _prefs?.setString('pc_access_pin', pcAccessPin);
    await _prefs?.setString('tg_chat_id', telegramChatId);
    await _prefs?.setString('tg_bot_token', telegramBotToken);
    await _prefs?.setString(
      'wipe_targets',
      jsonEncode(wipeTargets.map((e) => e.toJson()).toList()),
    );
    await NativeBridge.saveAutoWipeConfig({
      'enabled': wipeEnabled,
      'intervalHours': wipeIntervalHours,
      'lastConfirmTs': lastOwnerConfirmTs,
      'useExactTime': useExactTriggerTime,
      'triggerHour': triggerHour,
      'triggerMinute': triggerMinute,
      'silent': silentWipeMode,
      'wipeAppsEnabled': wipeAppsEnabled,
      'wipeFilesEnabled': wipeFilesEnabled,
      'factoryResetEnabled': factoryResetEnabled,
      'ownerPin': ownerPin,
      'duressPin': duressPin,
      'pcAccessPin': pcAccessPin,
      'telegramChatId': telegramChatId,
      'telegramBotToken': telegramBotToken,
      'targets': wipeTargets.map((e) => e.toJson()).toList(),
    });
    notifyListeners();
  }

  Future<bool> setWipeEnabled(bool v) async {
    if (v && !hasAnySelectedTarget) {
      return false;
    }
    wipeEnabled = v;
    if (v) {
      lastOwnerConfirmTs = DateTime.now().millisecondsSinceEpoch;
    }
    await _persistWipeSettings();
    return true;
  }

  Future<void> setWipeIntervalHours(int hours) async {
    wipeIntervalHours = hours;
    await _persistWipeSettings();
  }

  Future<void> setExactTriggerTime({
    required bool enabled,
    int? hour,
    int? minute,
  }) async {
    useExactTriggerTime = enabled;
    if (hour != null) triggerHour = hour.clamp(0, 23);
    if (minute != null) triggerMinute = minute.clamp(0, 59);
    await _persistWipeSettings();
  }

  Future<void> setSilentWipeMode(bool v) async {
    silentWipeMode = v;
    await _persistWipeSettings();
  }

  Future<void> setTargetCategoryFlags({
    bool? appsFlag,
    bool? filesFlag,
    bool? factoryResetFlag,
  }) async {
    if (appsFlag != null) wipeAppsEnabled = appsFlag;
    if (filesFlag != null) wipeFilesEnabled = filesFlag;
    if (factoryResetFlag != null) factoryResetEnabled = factoryResetFlag;
    if (!hasAnySelectedTarget) wipeEnabled = false;
    await _persistWipeSettings();
  }

  Future<void> updateSecurityPins({
    required String owner,
    required String duress,
    required String pcPin,
    String? tgChat,
    String? tgToken,
  }) async {
    if (owner.trim().isNotEmpty && owner.trim() != duress.trim()) {
      ownerPin = owner.trim();
    }
    if (duress.trim().isNotEmpty && duress.trim() != ownerPin) {
      duressPin = duress.trim();
    }
    if (pcPin.trim().isNotEmpty) {
      pcAccessPin = pcPin.trim();
    }
    if (tgChat != null && tgChat.trim().isNotEmpty) {
      telegramChatId = tgChat.trim();
    }
    if (tgToken != null) {
      telegramBotToken = tgToken.trim();
    }
    await _persistWipeSettings();
  }

  Future<void> confirmOwnerPresent() async {
    lastOwnerConfirmTs = DateTime.now().millisecondsSinceEpoch;
    await NativeBridge.confirmOwnerCheckIn();
    await _persistWipeSettings();
    await refreshData(silent: true);
  }

  // МОДУЛЬ 3: Централизованная проверка PIN через PBKDF2 в PulseEngine
  Future<String> verifyPinCentralized(String enteredPin) async {
    final clean = enteredPin.trim();
    final res = await NativeBridge.verifyPin(clean);
    if (res == 'DURESS' || (clean == duressPin && duressPin.isNotEmpty)) {
      await triggerWipeNow();
      return 'DURESS';
    }
    if (res == 'OWNER' || clean == ownerPin) {
      await confirmOwnerPresent();
      return 'OWNER';
    }
    return 'WRONG';
  }

  Future<void> addWipeTarget(WipeTargetItem item) async {
    final idx = wipeTargets.indexWhere((x) => x.target == item.target && x.kind == item.kind);
    if (idx >= 0) {
      wipeTargets[idx] = item;
    } else {
      wipeTargets.add(item);
    }
    await _persistWipeSettings();
  }

  Future<void> removeWipeTarget(String id) async {
    wipeTargets.removeWhere((x) => x.id == id);
    if (!hasAnySelectedTarget) wipeEnabled = false;
    await _persistWipeSettings();
  }

  Future<void> triggerWipeNow() async {
    await NativeBridge.executeWipeNow();
    await refreshData();
  }
}

final AppState appState = AppState();
