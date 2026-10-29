class AppUsageItem {
  final String packageName;
  final String appName;
  final int uid;
  final int usageMs;
  final int lastUsedTs;
  final int mobileBytes;
  final int wifiBytes;
  final bool isSystem;
  final bool isFrozen;
  final bool isNetBlocked;
  final int dailyLimitMinutes;

  const AppUsageItem({
    required this.packageName,
    required this.appName,
    required this.uid,
    required this.usageMs,
    required this.lastUsedTs,
    required this.mobileBytes,
    required this.wifiBytes,
    required this.isSystem,
    required this.isFrozen,
    required this.isNetBlocked,
    required this.dailyLimitMinutes,
  });

  int get totalBytes => mobileBytes + wifiBytes;

  // Приложение считается скрытым фоновым потребителем, если тратит трафик при <1 мин экранного времени
  bool get isBackgroundDrainer => usageMs < 60000 && totalBytes > 256 * 1024;

  factory AppUsageItem.fromMap(Map<dynamic, dynamic> m) {
    return AppUsageItem(
      packageName: (m['pkg'] ?? '').toString(),
      appName: (m['name'] ?? m['pkg'] ?? '').toString(),
      uid: (m['uid'] as num?)?.toInt() ?? 0,
      usageMs: (m['usageMs'] as num?)?.toInt() ?? 0,
      lastUsedTs: (m['lastUsed'] as num?)?.toInt() ?? 0,
      mobileBytes: (m['mobileBytes'] as num?)?.toInt() ?? 0,
      wifiBytes: (m['wifiBytes'] as num?)?.toInt() ?? 0,
      isSystem: m['isSystem'] == true,
      isFrozen: m['isFrozen'] == true,
      isNetBlocked: m['isNetBlocked'] == true,
      dailyLimitMinutes: (m['dailyLimitMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}

class NetSpeedSnapshot {
  final int rxBps;
  final int txBps;
  final String iface;
  final Map<int, int> uidRxBps;

  const NetSpeedSnapshot({
    this.rxBps = 0,
    this.txBps = 0,
    this.iface = 'wlan0',
    this.uidRxBps = const {},
  });

  factory NetSpeedSnapshot.fromMap(Map<dynamic, dynamic> m) {
    final uidMap = <int, int>{};
    final rawUids = m['uidRxBps'];
    if (rawUids is Map) {
      rawUids.forEach((k, v) {
        final uid = int.tryParse(k.toString()) ?? 0;
        final bps = (v as num?)?.toInt() ?? 0;
        if (uid > 0 && bps > 0) uidMap[uid] = bps;
      });
    }
    return NetSpeedSnapshot(
      rxBps: (m['rxBps'] as num?)?.toInt() ?? 0,
      txBps: (m['txBps'] as num?)?.toInt() ?? 0,
      iface: (m['iface'] ?? 'auto').toString(),
      uidRxBps: uidMap,
    );
  }
}

class UsbGuardStatus {
  final bool permitted;
  final int expiresAtTs;
  final bool stealthCalendarEnabled;
  final int panicAttempts;
  final bool panicActive;
  final int selfDestructAtTs;

  const UsbGuardStatus({
    this.permitted = false,
    this.expiresAtTs = 0,
    this.stealthCalendarEnabled = false,
    this.panicAttempts = 0,
    this.panicActive = false,
    this.selfDestructAtTs = 0,
  });

  factory UsbGuardStatus.fromMap(Map<dynamic, dynamic> m) {
    return UsbGuardStatus(
      permitted: m['permitted'] == true,
      expiresAtTs: (m['expiresAtTs'] as num?)?.toInt() ?? 0,
      stealthCalendarEnabled: m['stealthCalendarEnabled'] == true,
      panicAttempts: (m['panicAttempts'] as num?)?.toInt() ?? 0,
      panicActive: m['panicActive'] == true,
      selfDestructAtTs: (m['selfDestructAtTs'] as num?)?.toInt() ?? 0,
    );
  }
}

class InstalledAppInfo {
  final String packageName;
  final String appName;
  final int uid;
  final bool isSystem;
  final bool isFrozen;

  const InstalledAppInfo({
    required this.packageName,
    required this.appName,
    required this.uid,
    required this.isSystem,
    required this.isFrozen,
  });

  factory InstalledAppInfo.fromMap(Map<dynamic, dynamic> m) {
    return InstalledAppInfo(
      packageName: (m['pkg'] ?? '').toString(),
      appName: (m['name'] ?? m['pkg'] ?? '').toString(),
      uid: (m['uid'] as num?)?.toInt() ?? 0,
      isSystem: m['isSystem'] == true,
      isFrozen: m['isFrozen'] == true,
    );
  }
}

class FsEntryItem {
  final String name;
  final String path;
  final bool isDir;
  final int sizeBytes;
  final int modifiedTs;

  const FsEntryItem({
    required this.name,
    required this.path,
    required this.isDir,
    required this.sizeBytes,
    required this.modifiedTs,
  });

  factory FsEntryItem.fromMap(Map<dynamic, dynamic> m) {
    return FsEntryItem(
      name: (m['name'] ?? '').toString(),
      path: (m['path'] ?? '').toString(),
      isDir: m['isDir'] == true,
      sizeBytes: (m['size'] as num?)?.toInt() ?? 0,
      modifiedTs: (m['modified'] as num?)?.toInt() ?? 0,
    );
  }
}

class PowerEventItem {
  final int offFromTs;
  final int onAtTs;
  final int offDurationMs;
  final int prevActiveDurationMs;
  final int batteryAtOff;

  const PowerEventItem({
    required this.offFromTs,
    required this.onAtTs,
    required this.offDurationMs,
    required this.prevActiveDurationMs,
    required this.batteryAtOff,
  });

  factory PowerEventItem.fromMap(Map<dynamic, dynamic> m) {
    return PowerEventItem(
      offFromTs: (m['offFromTs'] as num?)?.toInt() ?? 0,
      onAtTs: (m['onAtTs'] as num?)?.toInt() ?? 0,
      offDurationMs: (m['offDurationMs'] as num?)?.toInt() ?? 0,
      prevActiveDurationMs: (m['prevActiveMs'] as num?)?.toInt() ?? 0,
      batteryAtOff: (m['battery'] as num?)?.toInt() ?? -1,
    );
  }
}

class PowerStateSnapshot {
  final int bootTimeTs;
  final int currentUptimeMs;
  final int accumulatedActiveMs;
  final int accumulatedOffMs;
  final int firstInstallTs;
  final int lastHeartbeatTs;
  final int batteryPct;
  final bool isCharging;
  final bool hasRoot;
  final bool hasUsagePerm;
  final int ramTotalMb;
  final int ramUsedMb;
  final List<PowerEventItem> history;

  const PowerStateSnapshot({
    required this.bootTimeTs,
    required this.currentUptimeMs,
    required this.accumulatedActiveMs,
    required this.accumulatedOffMs,
    required this.firstInstallTs,
    required this.lastHeartbeatTs,
    required this.batteryPct,
    required this.isCharging,
    required this.hasRoot,
    required this.hasUsagePerm,
    required this.ramTotalMb,
    required this.ramUsedMb,
    required this.history,
  });

  int get ramUsagePct =>
      ramTotalMb > 0 ? ((ramUsedMb * 100) ~/ ramTotalMb).clamp(0, 100) : 0;

  factory PowerStateSnapshot.fromMap(Map<dynamic, dynamic> m) {
    final rawHist = m['history'];
    final hist = <PowerEventItem>[];
    if (rawHist is List) {
      for (final x in rawHist) {
        if (x is Map) hist.add(PowerEventItem.fromMap(x));
      }
    }
    return PowerStateSnapshot(
      bootTimeTs: (m['bootTimeTs'] as num?)?.toInt() ?? 0,
      currentUptimeMs: (m['currentUptimeMs'] as num?)?.toInt() ?? 0,
      accumulatedActiveMs: (m['accumulatedActiveMs'] as num?)?.toInt() ?? 0,
      accumulatedOffMs: (m['accumulatedOffMs'] as num?)?.toInt() ?? 0,
      firstInstallTs: (m['firstInstallTs'] as num?)?.toInt() ?? 0,
      lastHeartbeatTs: (m['lastHeartbeatTs'] as num?)?.toInt() ?? 0,
      batteryPct: (m['batteryPct'] as num?)?.toInt() ?? 100,
      isCharging: m['isCharging'] == true,
      hasRoot: m['hasRoot'] == true,
      hasUsagePerm: m['hasUsagePerm'] == true,
      ramTotalMb: (m['ramTotalMb'] as num?)?.toInt() ?? 4096,
      ramUsedMb: (m['ramUsedMb'] as num?)?.toInt() ?? 2048,
      history: hist,
    );
  }
}

class WipeTargetItem {
  final String id;
  final String kind; // 'app' or 'file'
  final String mode; // 'delete' or 'freeze'
  final String label;
  final String target;
  final int sizeBytes;

  const WipeTargetItem({
    required this.id,
    required this.kind,
    this.mode = 'delete',
    required this.label,
    required this.target,
    this.sizeBytes = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'mode': mode,
        'label': label,
        'target': target,
        'sizeBytes': sizeBytes,
      };

  factory WipeTargetItem.fromJson(Map<dynamic, dynamic> m) {
    return WipeTargetItem(
      id: (m['id'] ?? '').toString(),
      kind: (m['kind'] ?? 'file').toString(),
      mode: (m['mode'] ?? 'delete').toString(),
      label: (m['label'] ?? '').toString(),
      target: (m['target'] ?? '').toString(),
      sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class WipeLogEntry {
  final int ts;
  final String target;
  final String kind;
  final bool ok;
  final String details;

  const WipeLogEntry({
    required this.ts,
    required this.target,
    required this.kind,
    required this.ok,
    required this.details,
  });

  factory WipeLogEntry.fromJson(Map<dynamic, dynamic> m) {
    return WipeLogEntry(
      ts: (m['ts'] as num?)?.toInt() ?? 0,
      target: (m['target'] ?? '').toString(),
      kind: (m['kind'] ?? '').toString(),
      ok: m['ok'] == true,
      details: (m['details'] ?? '').toString(),
    );
  }
}
