import 'dart:math' as math;
import 'package:flutter/material.dart';

// Полностью новая палитра Obsidian Cyber-Slate (создана с нуля)
class SColor {
  static const bg = Color(0xFF080A0F);
  static const panel = Color(0xFF10141E);
  static const card = Color(0xFF161C2A);
  static const glass = Color(0xFF1E2638);
  static const border = Color(0xFF263044);
  static const ink = Color(0xFFEEF4FA);
  static const sub = Color(0xFF8492A6);
  static const cyan = Color(0xFF38BDF8);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const crimson = Color(0xFFF43F5E);
  static const violet = Color(0xFF818CF8);
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

String formatTimestamp(int ts) {
  if (ts <= 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  return '${pad2(d.day)}.${pad2(d.month)}.${d.year} ${pad2(d.hour)}:${pad2(d.minute)}:${pad2(d.second)}';
}

// Кастомная круговая диаграмма телеметрии (нарисована с нуля через CustomPainter)
class TelemetryRingGauge extends StatelessWidget {
  final List<(double, Color)> segments;
  final String centerTitle;
  final String centerSubtitle;
  final double size;

  const TelemetryRingGauge({
    required this.segments,
    required this.centerTitle,
    required this.centerSubtitle,
    this.size = 152,
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
                  child: Text(
                    centerTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: SColor.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  centerSubtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SColor.sub,
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
      ..strokeWidth = 11
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
        ..strokeWidth = 11
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
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
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
        color: color.withOpacity(0.14),
        border: Border.all(color: color.withOpacity(0.45)),
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
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
