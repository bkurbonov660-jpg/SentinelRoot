import 'dart:convert';
import 'package:flutter/services.dart';
import 'models.dart';

class NativeBridge {
  static const MethodChannel _ch = MethodChannel('sentinelroot/native');

  static Future<Map<String, dynamic>> getDashboard({String period = 'day'}) async {
    try {
      final raw = await _ch.invokeMethod<String>('getDashboard', {'period': period});
      if (raw == null || raw.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  static Future<NetSpeedSnapshot> getNetSpeed({String ifaceMode = 'auto'}) async {
    try {
      final raw = await _ch.invokeMethod<String>('getNetSpeed', {'ifaceMode': ifaceMode});
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return NetSpeedSnapshot.fromMap(decoded);
      }
    } catch (_) {}
    return const NetSpeedSnapshot();
  }

  static Future<String> verifyPin(String pin) async {
    try {
      return (await _ch.invokeMethod<String>('verifyPin', {'pin': pin})) ?? 'WRONG';
    } catch (_) {
      return 'WRONG';
    }
  }

  static Future<bool> scheduleSelfDestruct(int delayMs) async {
    try {
      return (await _ch.invokeMethod<bool>('scheduleSelfDestruct', {'delayMs': delayMs})) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> cancelSelfDestruct(String pin) async {
    try {
      return (await _ch.invokeMethod<bool>('cancelSelfDestruct', {'pin': pin})) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<UsbGuardStatus> getUsbStatus() async {
    try {
      final raw = await _ch.invokeMethod<String>('getUsbStatus');
      if (raw != null && raw.isNotEmpty) {
        final m = jsonDecode(raw);
        if (m is Map) return UsbGuardStatus.fromMap(m);
      }
    } catch (_) {}
    return const UsbGuardStatus();
  }

  static Future<bool> grantUsbAccess({required int durationMin, required String pin}) async {
    try {
      return (await _ch.invokeMethod<bool>('grantUsbAccess', {
            'durationMin': durationMin,
            'pin': pin,
          })) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> revokeUsbAccess() async {
    try {
      return (await _ch.invokeMethod<bool>('revokeUsbAccess')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setStealthCalendarMode(bool enabled) async {
    try {
      return (await _ch.invokeMethod<bool>('setStealthCalendarMode', {'enabled': enabled})) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopPanicLockdown(String pin) async {
    try {
      return (await _ch.invokeMethod<bool>('stopPanicLockdown', {'pin': pin})) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> triggerTestTelegramAlert() async {
    try {
      return (await _ch.invokeMethod<bool>('triggerTestTelegramAlert')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestRootAndPermissions() async {
    try {
      return (await _ch.invokeMethod<bool>('requestRootAndPermissions')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openUsageSettings() async {
    try {
      return (await _ch.invokeMethod<bool>('openUsageSettings')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<InstalledAppInfo>> listAllInstalledApps() async {
    try {
      final raw = await _ch.invokeMethod<String>('listInstalledApps');
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw);
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => InstalledAppInfo.fromMap(e))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  static Future<List<FsEntryItem>> listDirectory(String dirPath) async {
    try {
      final raw = await _ch.invokeMethod<String>('listDirectory', {'path': dirPath});
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw);
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => FsEntryItem.fromMap(e))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  static Future<bool> toggleAppFirewall(int uid, String pkg, bool block) async {
    try {
      return (await _ch.invokeMethod<bool>('toggleAppFirewall', {
            'uid': uid,
            'pkg': pkg,
            'block': block,
          })) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> toggleAppFreeze(String pkg, bool freeze) async {
    try {
      return (await _ch.invokeMethod<bool>('toggleAppFreeze', {
            'pkg': pkg,
            'freeze': freeze,
          })) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> forceStopAndClearCache(String pkg) async {
    try {
      return (await _ch.invokeMethod<bool>('forceStopAndClearCache', {'pkg': pkg})) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> purgeSystemRamAndCaches() async {
    try {
      return (await _ch.invokeMethod<String>('purgeSystemRamAndCaches')) ?? 'Выполнено';
    } catch (_) {
      return 'Ошибка очистки';
    }
  }

  static Future<bool> setAppDailyLimit(String pkg, int minutes) async {
    try {
      return (await _ch.invokeMethod<bool>('setAppDailyLimit', {
            'pkg': pkg,
            'minutes': minutes,
          })) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> saveAutoWipeConfig(Map<String, dynamic> config) async {
    try {
      final payload = jsonEncode(config);
      return (await _ch.invokeMethod<bool>('saveAutoWipeConfig', payload)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> confirmOwnerCheckIn() async {
    try {
      return (await _ch.invokeMethod<bool>('confirmOwnerCheckIn')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> executeWipeNow() async {
    try {
      final raw = await _ch.invokeMethod<String>('executeWipeNow');
      if (raw != null && raw.isNotEmpty) {
        final m = jsonDecode(raw);
        if (m is Map) return Map<String, dynamic>.from(m);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  static Future<String?> pickSystemFile() async {
    try {
      return await _ch.invokeMethod<String>('pickFilePath');
    } catch (_) {
      return null;
    }
  }

  static Future<String?> pickSystemFolder() async {
    try {
      return await _ch.invokeMethod<String>('pickFolderPath');
    } catch (_) {
      return null;
    }
  }
}
