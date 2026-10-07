import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// What the server does with a problem, in order: (done, now, ahead) wording.
const _stages = [
  ('Masala o‘qildi', 'Masala o‘qilmoqda', 'Masala o‘qiladi'),
  ('Yechim yo‘li tanlandi', 'Yechim yo‘li tanlanmoqda', 'Yechim yo‘li tanlanadi'),
  ('Qadamlar yozildi', 'Qadamlar yozilmoqda', 'Qadamlar yoziladi'),
  ('Javob tekshirildi', 'Javob tekshirilmoqda', 'Javob tekshiriladi'),
];

/// Headline for the stage in progress.
const stageHeadlines = [
  'Masalani o‘qiyapmiz…',
  'Yechim yo‘lini tanlayapmiz…',
  'Qadamlarni yozyapmiz…',
  'Javobni tekshiryapmiz…',
];

/// Number of stages, for callers that advance them.
int get stageCount => _stages.length;

/// The four stages, in words rather than dots.
///
/// The server reports no progress, so the caller advances [current] on a
/// timer. The last stage is therefore never ticked by time: only [allDone],
/// set when the solution has really arrived, closes it.
class WaitingStages extends StatelessWidget {
  const WaitingStages({super.key, required this.current, this.allDone = false});

  /// Index of the stage in progress.
  final int current;
  final bool allDone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for (final (i, (done, now, ahead)) in _stages.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.border.withAlpha(0x99)),
            _StageRow(
              number: i + 1,
              label: allDone || i < current ? done : (i == current ? now : ahead),
              state: allDone || i < current ? _State.done : (i == current ? _State.now : _State.ahead),
            ),
          ],
        ],
      ),
    );
  }
}

enum _State { done, now, ahead }

class _StageRow extends StatelessWidget {
  const _StageRow({required this.number, required this.label, required this.state});

  final int number;
  final String label;
  final _State state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final green = context.readable(AppColors.success);
    final brand = context.readable(AppColors.brand);
    final dot = switch (state) {
      _State.done => Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.tint(AppColors.success, 0x2E),
            border: Border.all(color: AppColors.tint(AppColors.success, 0x8C), width: 1.5),
          ),
          child: Icon(Icons.check_rounded, size: 13, color: green),
        ),
      _State.now => _PulseDot(number: number, color: brand),
      _State.ahead => Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.border, width: 1.5)),
          child: Text('$number', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.textMuted)),
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          dot,
          const SizedBox(width: 11),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              // Replaces the ambient style rather than merging, so start from it.
              style: DefaultTextStyle.of(context).style.copyWith(
                fontSize: 13.5,
                fontWeight: state == _State.now ? FontWeight.w700 : FontWeight.w500,
                color: switch (state) {
                  _State.done => c.textSecondary,
                  _State.now => c.textPrimary,
                  _State.ahead => c.textMuted,
                },
              ),
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

/// The stage in progress: its number inside a softly widening ring.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.number, required this.color});

  final int number;
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Transform.scale(
              scale: 1 + 0.55 * _pulse.value,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withAlpha((0x99 * (1 - _pulse.value)).round()),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.tint(AppColors.brand, 0x2E),
              border: Border.all(color: widget.color, width: 1.5),
            ),
            child: Text(
              '${widget.number}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: widget.color),
            ),
          ),
        ],
      ),
    );
  }
}
