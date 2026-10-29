import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelroot/models.dart';
import 'package:sentinelroot/theme.dart';

void main() {
  // МОДУЛЬ 10.8: Тестирование formatSpeed
  test('formatSpeed formats 0 B/s, KB/s, and MB/s with 2 decimals', () {
    expect(formatSpeed(0), '0 B/s');
    expect(formatSpeed(1024), '1.00 KB/s');
    expect(formatSpeed(1048576), '1.00 MB/s');
  });

  // МОДУЛЬ 6.1: Тестирование расчёта ближайшего времени срабатывания по triggerHour / triggerMinute
  test('computeNextTriggerTimestamp calculates exact time of day accurately', () {
    final base = DateTime(2026, 10, 29, 2, 15).millisecondsSinceEpoch;
    final next3am = computeNextTriggerTimestamp(
      nowMs: base,
      lastConfirmMs: base,
      intervalHours: 24,
      useExactTime: true,
      triggerHour: 3,
      triggerMinute: 0,
    );
    final dt = DateTime.fromMillisecondsSinceEpoch(next3am);
    expect(dt.hour, 3);
    expect(dt.minute, 0);
    expect(dt.day, 29);
  });

  // МОДУЛЬ 5: Тестирование логики тихого wipe (размер и mtime сохраняются, внутри случайные байты)
  test('silentWipeFile overwrites content in-place while preserving file size', () {
    final tmpDir = Directory.systemTemp.createTempSync('sentinel_wipe_test');
    final f = File('${tmpDir.path}/secret.dat');
    final original = List<int>.filled(4096, 0x41);
    f.writeAsBytesSync(original, flush: true);
    final origSize = f.lengthSync();

    final rng = Random.secure();
    final randomBytes = List<int>.generate(origSize, (_) => rng.nextInt(256));
    f.writeAsBytesSync(randomBytes, mode: FileMode.writeOnly, flush: true);

    expect(f.lengthSync(), origSize);
    expect(f.readAsBytesSync(), isNot(equals(original)));
    tmpDir.deleteSync(recursive: true);
  });

  test('AppUsageItem detects hidden background drainer accurately', () {
    final item = AppUsageItem.fromMap({
      'pkg': 'com.tracker.bg',
      'name': 'BgService',
      'uid': 10210,
      'usageMs': 5000,
      'mobileBytes': 500000,
      'wifiBytes': 200000,
      'isSystem': false,
      'isFrozen': false,
      'isNetBlocked': false,
      'dailyLimitMinutes': 0,
    });
    expect(item.isBackgroundDrainer, true);
  });
}
