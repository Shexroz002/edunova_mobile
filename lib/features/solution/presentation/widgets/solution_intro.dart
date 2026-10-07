import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/solution_models.dart';
import 'physics_cards.dart';
import 'solution_tex.dart';
import 'step_card.dart';
import 'tape_bar.dart';

/// Before any maths: the problem, what it asks in plain words, and the plan.
///
/// Many students stop not at the arithmetic but at "what am I supposed to do".
/// This screen solves nothing; it turns the question into plain words and shows
/// the road ahead.
class SolutionIntro extends StatelessWidget {
  const SolutionIntro({super.key, required this.solution, this.problem});

  final Solution solution;

  /// The problem as the student saw it; may hold `$…$` maths.
  final String? problem;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brand = context.readable(AppColors.brand);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (problem != null && problem!.trim().isNotEmpty) ...[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Masala'),
                const SizedBox(height: 7),
                ProseMath(problem!.trim(), style: const TextStyle(fontSize: 15.5)),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (solution.asked.isNotEmpty) ...[
          _Card(
            tint: AppColors.brand,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🎯 Bizdan nima so‘ralyapti?',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: brand)),
                const SizedBox(height: 6),
                ProseMath(solution.asked),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (solution.isPhysics) ...[
          GivenFindCard(given: solution.given, find: solution.find),
          const SizedBox(height: 10),
          if (solution.formula != null) ...[
            FormulaCardView(formula: solution.formula!),
            const SizedBox(height: 10),
          ],
        ] else if (solution.values.isNotEmpty) ...[
          _Values(values: solution.values),
          const SizedBox(height: 10),
        ],
        if (solution.tape != null) ...[
          _Card(child: TapeBar(tape: solution.tape!)),
          const SizedBox(height: 10),
        ],
        if (solution.plan.isNotEmpty)
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🗺 Reja — ${solution.plan.length} qadam',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                for (final (i, item) in solution.plan.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        StepNumber(number: i + 1, size: 24),
                        const SizedBox(width: 11),
                        Expanded(child: ProseMath(item, style: TextStyle(fontSize: 14.5, color: c.textPrimary))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The problem's key numbers, each in the colour it keeps on the board.
class _Values extends StatelessWidget {
  const _Values({required this.values});

  final List<MathValue> values;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Masaladagi sonlar'),
          const SizedBox(height: 8),
          for (final v in values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(v.label, style: TextStyle(fontSize: 13.5, color: c.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  BoardFormula(r'\hl' '${'abc'[(v.color - 1).clamp(0, 2)]}{${texNumber(v.value)}}', size: 20, bold: true),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: context.colors.textMuted,
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.tint});

  final Widget child;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: tint == null ? c.bgCard : AppColors.tint(tint!, 0x17),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint == null ? c.border : AppColors.tint(tint!, 0x59)),
      ),
      child: child,
    );
  }
}
