import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelroot/models.dart';
import 'package:sentinelroot/theme.dart';

void main() {
  test('formatDuration formats clock and human strings accurately', () {
    expect(formatDuration(0, clockMode: true), '00:00:00');
    expect(formatDuration(3661000, clockMode: true), '01:01:01');
    expect(formatDuration(3600000), '1 ч');
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
