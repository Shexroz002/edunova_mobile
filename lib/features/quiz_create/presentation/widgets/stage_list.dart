import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/job_stage.dart';
import '../../domain/quiz_job.dart';

/// The four job stages as a checklist, so the wait has a visible shape.
///
/// A bare percentage sits still for up to forty seconds between the backend's
/// steps and reads as a freeze; a ticked-off list keeps saying where the job is
/// and what is left.
class StageList extends StatelessWidget {
  const StageList({
    super.key,
    required this.method,
    required this.current,
    this.finished = false,
    this.note,
  });

  final CreateMethod method;

  /// The stage the job is working on.
  final JobStage current;

  /// Every stage is done, so nothing is shown as running.
  final bool finished;

  /// Warning shown under the running stage, e.g. the AI retry.
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final stage in JobStage.values)
          _StageRow(
            labels: stage.labels(method),
            state: finished || stage.index < current.index
                ? _RowState.done
                : stage == current
                    ? _RowState.active
                    : _RowState.pending,
            note: stage == current && !finished ? note : null,
            last: stage == JobStage.values.last,
          ),
      ],
    );
  }
}

enum _RowState { done, active, pending }

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.labels,
    required this.state,
    required this.last,
    this.note,
  });

  final StageLabels labels;
  final _RowState state;
  final bool last;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = context.readable(AppColors.emerald);
    final active = context.readable(AppColors.sky);

    final (label, color, weight) = switch (state) {
      _RowState.done => (labels.done, c.textSecondary, FontWeight.w600),
      _RowState.active => (labels.active, c.textPrimary, FontWeight.w800),
      _RowState.pending => (labels.pending, c.textMuted, FontWeight.w600),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                _Dot(state: state, doneColor: done, activeColor: active),
                if (!last)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: state == _RowState.done ? done.withValues(alpha: 0.45) : c.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 14, fontWeight: weight, color: color),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 8),
                    _Note(text: note!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The circle in the gutter: a tick, a small spinner, or an idle dot.
class _Dot extends StatelessWidget {
  const _Dot({required this.state, required this.doneColor, required this.activeColor});

  final _RowState state;
  final Color doneColor;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (background, border, child) = switch (state) {
      _RowState.done => (
          AppColors.tint(doneColor, 0x24),
          AppColors.tint(doneColor, 0x73),
          Icon(Icons.check_rounded, size: 15, color: doneColor),
        ),
      _RowState.active => (
          AppColors.tint(activeColor, 0x29),
          AppColors.tint(activeColor, 0x99),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: activeColor),
          ),
        ),
      _RowState.pending => (
          c.bgInner,
          c.border,
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: c.textMuted.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
          ),
        ),
    };

    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final warning = context.readable(AppColors.warning);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tint(warning, 0x1F),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.tint(warning, 0x59)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: warning),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: warning),
            ),
          ),
        ],
      ),
    );
  }
}
