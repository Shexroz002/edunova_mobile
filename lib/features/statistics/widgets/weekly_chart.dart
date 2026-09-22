import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../analytics/domain/analytics_models.dart';

/// Sessions per day over the last week, split by whether they were finished.
///
/// The chart used to count sessions *started*, which flatters the week: a test
/// opened and left after five questions stood as tall as one answered to the
/// end, and the results list showed how many of those there are. The solid part
/// of each bar is what the student finished; the hatched part is what they
/// walked away from.
class WeeklyChart extends StatelessWidget {
  const WeeklyChart({super.key, required this.days});

  final List<DailyActivity> days;

  /// Tallest bar, never below 1 so an empty week still draws a baseline.
  int get _peak =>
      days.fold<int>(1, (peak, day) => day.total > peak ? day.total : peak);

  int get _total => days.fold<int>(0, (sum, day) => sum + day.total);

  int get _done => days.fold<int>(0, (sum, day) => sum + day.done);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brand = context.readable(AppColors.brand);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Haftalik faollik',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _total == 0
              ? 'Bu hafta test ishlanmagan'
              : '$_total ta sessiya · $_done tasi tugallangan',
          style: TextStyle(fontSize: 11.5, color: c.textMuted),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final day in days)
              Expanded(child: _Bar(day: day, peak: _peak, color: brand)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Key(label: 'Tugallangan', color: brand),
            const SizedBox(width: 14),
            _Key(label: 'Tashlab ketilgan', color: c.textMuted, hatched: true),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.day, required this.peak, required this.color});

  final DailyActivity day;
  final int peak;
  final Color color;

  /// Height the bars are drawn in, above the weekday label.
  static const _track = 82.0;

  /// Height of a day with no sessions, so the baseline stays visible.
  static const _floor = 3.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final height = day.total == 0 ? _floor : (day.total / peak) * _track;

    return Tooltip(
      message: day.total == 0
          ? 'Sessiya yo‘q'
          : '${day.total} ta sessiya, ${day.done} tasi tugallangan',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // One painter draws the whole bar. Stacking a hatched box over a
          // solid one — whether flexed or measured — left the solid share
          // unpainted on device and lifted mixed days off the baseline.
          SizedBox(
            height: _track,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 26,
                height: height,
                child: CustomPaint(
                  painter: _BarPainter(
                    done: day.done,
                    total: day.total,
                    color: color,
                    hatch: c.textMuted,
                    empty: c.border,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(day.label, style: TextStyle(fontSize: 10, color: c.textMuted)),
        ],
      ),
    );
  }
}

/// One day's bar: the finished share filled from the bottom, the rest hatched.
class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.done,
    required this.total,
    required this.color,
    required this.hatch,
    required this.empty,
  });

  final int done;
  final int total;
  final Color color;
  final Color hatch;

  /// Fill for a day with no sessions at all.
  final Color empty;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final shape = RRect.fromRectAndCorners(
      bounds,
      topLeft: const Radius.circular(6),
      topRight: const Radius.circular(6),
    );

    canvas.save();
    canvas.clipRRect(shape);

    if (total == 0) {
      canvas.drawRect(bounds, Paint()..color = empty);
      canvas.restore();
      return;
    }

    final doneHeight = size.height * done / total;
    final split = size.height - doneHeight;

    if (doneHeight > 0) {
      canvas.drawRect(
        Rect.fromLTRB(0, split, size.width, size.height),
        Paint()..color = color,
      );
    }

    if (split > 0) {
      const step = 6.0;
      final pen = Paint()
        ..color = hatch.withValues(alpha: 0.55)
        ..strokeWidth = 1.6;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, size.width, split));
      for (var x = -split; x < size.width; x += step) {
        canvas.drawLine(Offset(x, split), Offset(x + split, 0), pen);
      }
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.done != done || old.total != total || old.color != color;
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.color, this.hatched = false});

  final String label;
  final Color color;
  final bool hatched;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            width: 11,
            height: 11,
            child: hatched
                ? DecoratedBox(
                    decoration: BoxDecoration(border: Border.all(color: c.border)),
                    child: CustomPaint(
                      painter: _BarPainter(
                        done: 0,
                        total: 1,
                        color: color,
                        hatch: color,
                        empty: c.bgCard,
                      ),
                    ),
                  )
                : ColoredBox(color: color),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 10.5, color: c.textMuted)),
      ],
    );
  }
}
