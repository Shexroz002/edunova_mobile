import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/solution_models.dart';
import 'board.dart';
import 'solution_tex.dart';

/// A finished step, folded to its result. Tap to see its board again.
///
/// Keeps one step on screen at a time: a long ribbon of steps tires a child,
/// but "where did D = 49 come from?" is still one tap away.
class DoneRow extends StatefulWidget {
  const DoneRow({super.key, required this.number, required this.step});

  final int number;
  final SolutionStep step;

  @override
  State<DoneRow> createState() => _DoneRowState();
}

class _DoneRowState extends State<DoneRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final green = context.readable(AppColors.success);
    return Material(
      color: AppColors.tint(AppColors.success, 0x12),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.tint(AppColors.success, 0x40)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.tint(AppColors.success, 0x33),
                    ),
                    child: Icon(Icons.check_rounded, size: 14, color: green),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ProseMath(
                      widget.step.summary.isEmpty ? widget.step.title : widget.step.summary,
                      style: TextStyle(fontSize: 13.5, color: c.textSecondary),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 20,
                    color: c.textMuted,
                  ),
                ],
              ),
              if (_open) ...[
                const SizedBox(height: 8),
                SolutionBoard(lines: widget.step.board),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
