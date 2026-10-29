import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

// Классическая выверенная палитра Obsidian Cyber-Slate (приятная для глаз, высокий контраст)
class SColor {
  static const bg = Color(0xFF090C12);
  static const panel = Color(0xFF111622);
  static const card = Color(0xFF171E2E);
  static const glass = Color(0xFF1F283D);
  static const border = Color(0xFF28334A);
  static const ink = Color(0xFFF1F5F9);
  static const sub = Color(0xFF94A3B8);
  static const cyan = Color(0xFF38BDF8);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const crimson = Color(0xFFF43F5E);
  static const violet = Color(0xFF818CF8);
}

// Классическая типографика с табличными цифрами (tabularFigures) для идеального выравнивания таймеров
class SText {
  static const String fontFamily = 'Roboto';

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: SColor.ink,
    letterSpacing: -0.2,
    height: 1.25,
  );

  static const TextStyle section = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: SColor.sub,
    letterSpacing: 0.7,
    height: 1.2,
  );

  static const TextStyle metric = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: SColor.ink,
    letterSpacing: -0.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle mono = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: SColor.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

String pad2(int n) => n.toString().padLeft(2, '0');

String formatDuration(int ms, {bool clockMode = false}) {
  if (ms <= 0) return clockMode ? '00:00:00' : '0 мин';
  final totalSec = ms ~/ 1000;
  final days = totalSec ~/ 86400;
  final hours = (totalSec % 86400) ~/ 3600;
  final mins = (totalSec % 3600) ~/ 60;
  final secs = totalSec % 60;
  if (clockMode) {
    if (days > 0) return '${days}д ${pad2(hours)}:${pad2(mins)}:${pad2(secs)}';
    return '${pad2(hours)}:${pad2(mins)}:${pad2(secs)}';
  }
  final parts = <String>[];
  if (days > 0) parts.add('$days д');
  if (hours > 0) parts.add('$hours ч');
  if (mins > 0 || parts.isEmpty) parts.add('$mins мин');
  return parts.join(' ');
}

String formatDataSize(int bytes) {
  if (bytes <= 0) return '0 Б';
  const kb = 1024.0;
  const mb = kb * 1024.0;
  const gb = mb * 1024.0;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} ГБ';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} МБ';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} КБ';
  return '$bytes Б';
}

// МОДУЛЬ 10.8: Точное форматирование скорости сети (0 B/s, 1.00 KB/s, 1.00 MB/s)
String formatSpeed(int bytesPerSec) {
  if (bytesPerSec <= 0) return '0 B/s';
  const kb = 1024.0;
  const mb = kb * 1024.0;
  if (bytesPerSec >= mb) {
    return '${(bytesPerSec / mb).toStringAsFixed(2)} MB/s';
  }
  if (bytesPerSec >= kb) {
    return '${(bytesPerSec / kb).toStringAsFixed(2)} KB/s';
  }
  return '$bytesPerSec B/s';
}

String formatTimestamp(int ts) {
  if (ts <= 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  return '${pad2(d.day)}.${pad2(d.month)}.${d.year} ${pad2(d.hour)}:${pad2(d.minute)}:${pad2(d.second)}';
}

// МОДУЛЬ 6.1: Расчёт ближайшего времени срабатывания по triggerHour / triggerMinute
int computeNextTriggerTimestamp({
  required int nowMs,
  required int lastConfirmMs,
  required int intervalHours,
  required bool useExactTime,
  required int triggerHour,
  required int triggerMinute,
}) {
  final safeHours = intervalHours < 1 ? 1 : intervalHours;
  if (!useExactTime) {
    return lastConfirmMs + safeHours * 3600 * 1000;
  }
  final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
  var candidate = DateTime(
    now.year,
    now.month,
    now.day,
    triggerHour.clamp(0, 23),
    triggerMinute.clamp(0, 59),
  );
  final stepHours = safeHours < 24 ? safeHours : 24;
  while (candidate.millisecondsSinceEpoch <= nowMs) {
    candidate = candidate.add(Duration(hours: stepHours));
  }
  return candidate.millisecondsSinceEpoch;
}

// Кастомная круговая диаграмма телеметрии (CustomPainter)
class TelemetryRingGauge extends StatelessWidget {
  final List<(double, Color)> segments;
  final String centerTitle;
  final String centerSubtitle;
  final double size;

  const TelemetryRingGauge({
    required this.segments,
    required this.centerTitle,
    required this.centerSubtitle,
    this.size = 148,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(segments),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(centerTitle, style: SText.metric),
                ),
                const SizedBox(height: 3),
                Text(
                  centerSubtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: SText.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: SColor.sub,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final List<(double, Color)> segments;
  _RingPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = SColor.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final total = segments.fold<double>(0, (p, c) => p + (c.$1 > 0 ? c.$1 : 0));
    if (total <= 0) return;

    var startAngle = -math.pi / 2;
    for (final seg in segments) {
      if (seg.$1 <= 0) continue;
      final sweep = (seg.$1 / total) * (2 * math.pi);
      final paint = Paint()
        ..color = seg.$2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.5
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        rect,
        startAngle + 0.03,
        math.max(0.02, sweep - 0.06),
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => true;
}

// МОДУЛЬ 10.5: Виджет SpeedBadge с 30-точечным Sparkline в верхнем HUD
class SpeedBadge extends StatelessWidget {
  final int rxBps;
  final int txBps;
  final List<int> rxHistory;
  final List<int> txHistory;
  final String ifaceLabel;
  final VoidCallback? onTap;

  const SpeedBadge({
    required this.rxBps,
    required this.txBps,
    required this.rxHistory,
    required this.txHistory,
    this.ifaceLabel = 'AUTO',
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: SColor.card,
          border: Border.all(color: SColor.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_downward_rounded, size: 12, color: SColor.emerald),
                const SizedBox(width: 2),
                Text(
                  formatSpeed(rxBps),
                  style: const TextStyle(
                    fontFamily: SText.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SColor.emerald,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_upward_rounded, size: 12, color: SColor.cyan),
                const SizedBox(width: 2),
                Text(
                  formatSpeed(txBps),
                  style: const TextStyle(
                    fontFamily: SText.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SColor.cyan,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ifaceLabel.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: SColor.sub,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 56,
                  height: 13,
                  child: CustomPaint(
                    painter: _SparklinePainter(rxHistory, SColor.emerald),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 44,
                  height: 13,
                  child: CustomPaint(
                    painter: _SparklinePainter(txHistory, SColor.cyan),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> values;
  final Color color;
  _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.fold<int>(1024, (p, c) => c > p ? c : p).toDouble();
    final path = Path();
    final stepX = values.length > 1 ? size.width / (values.length - 1) : size.width;

    for (var i = 0; i < values.length; i++) {
      final norm = (values[i] / maxVal).clamp(0.05, 1.0);
      final x = i * stepX;
      final y = size.height - norm * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}

// Сегментированный переключатель диапазона (День / Месяц / Год)
class SegmentedRangeBar extends StatelessWidget {
  final String current;
  final void Function(String) onChanged;

  const SegmentedRangeBar({
    required this.current,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      ('day', 'СУТКИ (24Ч)'),
      ('month', 'МЕСЯЦ (30Д)'),
      ('year', 'ГОД (365Д)'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SColor.panel,
        border: Border.all(color: SColor.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(it.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: current == it.$1 ? SColor.cyan : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    it.$2,
                    style: TextStyle(
                      fontFamily: SText.fontFamily,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: current == it.$1 ? SColor.bg : SColor.sub,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TacticalBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const TacticalBadge(this.text, this.color, {this.icon, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        border: Border.all(color: color.withOpacity(0.42)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontFamily: SText.fontFamily,
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
