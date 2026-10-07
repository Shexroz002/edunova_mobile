import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/solution_models.dart';
import 'solution_tex.dart';

/// What is written on the board for one step, line by line.
class SolutionBoard extends StatelessWidget {
  const SolutionBoard({super.key, required this.lines});

  final List<BoardLine> lines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // A formula is written quieter than the working that follows it. Alone on
    // the board it is the step itself, and grey would read as disabled.
    final hasWorking = lines.any((l) => l.role != BoardRole.formula);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: c.bgInner,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            BoardFormula(
              line.tex,
              muted: hasWorking && line.role == BoardRole.formula,
              bold: line.role == BoardRole.result,
            ),
        ],
      ),
    );
  }
}
