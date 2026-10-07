import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/solution_models.dart';
import 'solution_tex.dart';

/// "Berilgan / Topish kerak", the way every physics problem is written at school.
class GivenFindCard extends StatelessWidget {
  const GivenFindCard({super.key, required this.given, required this.find});

  final List<GivenValue> given;
  final List<FindItem> find;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      // A table, not IntrinsicHeight around a row: the formulas scroll sideways,
      // and a scroll view under-reports its intrinsic height (an overflow of a
      // few pixels in the light theme). A table row simply takes the taller cell.
      child: Table(
        border: TableBorder(verticalInside: BorderSide(color: c.border)),
        children: [
          TableRow(
            children: [
              _Column(
                title: 'Berilgan',
                lines: [
                  for (final g in given) r'\hl' '${'abc'[(g.color - 1).clamp(0, 2)]}' '{${g.symbol} = ${texNumber(g.value)}\\ ${_unit(g.unit)}}',
                ],
              ),
              _Column(
                title: 'Topish kerak',
                lines: [for (final f in find) '${f.symbol} = \\,?'],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _unit(String unit) => unit.trim().isEmpty ? '' : '\\text{${unit.trim()}}';

class _Column extends StatelessWidget {
  const _Column({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: context.colors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          for (final line in lines) BoardFormula(line, size: 17),
        ],
      ),
    );
  }
}

/// The main formula, big, with every letter explained underneath.
class FormulaCardView extends StatelessWidget {
  const FormulaCardView({super.key, required this.formula});

  final FormulaCard formula;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (formula.name.isNotEmpty)
            Text(
              formula.name,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: context.readable(AppColors.brand)),
            ),
          Center(child: BoardFormula(formula.tex, size: 24)),
          if (formula.legend.isNotEmpty) ...[
            Divider(height: 18, color: c.border),
            for (final line in formula.legend)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: ProseMath(
                  '\$${line.symbol}\$ — ${line.meaning}${line.unit.trim().isEmpty ? '' : ', ${line.unit.trim()}'}',
                  style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
