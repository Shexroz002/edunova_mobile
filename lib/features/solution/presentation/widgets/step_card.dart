import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/solution_models.dart';
import 'board.dart';
import 'solution_tex.dart';

/// The step being explained: what the teacher says, then the board.
///
/// "Tushunmadim" opens [SolutionStep.simpler] under the board: the same step
/// again, one operation per sentence, and the school rule it rests on.
class StepCard extends StatelessWidget {
  const StepCard({super.key, required this.number, required this.step, required this.simplerOpen});

  final int number;
  final SolutionStep step;
  final bool simplerOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            StepNumber(number: number),
            const SizedBox(width: 10),
            Expanded(
              child: ProseMath(
                step.title,
                style: const TextStyle(fontSize: 17, height: 1.35, fontWeight: FontWeight.w800, letterSpacing: -0.25),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ProseMath(step.say),
        const SizedBox(height: 10),
        SolutionBoard(lines: step.board),
        if (step.tip != null) ...[
          const SizedBox(height: 10),
          SolutionNote(icon: '⚠️', text: step.tip!, tone: AppColors.warning),
        ],
        if (simplerOpen && step.simpler.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Simpler(lines: step.simpler, rule: step.rule),
        ],
      ],
    );
  }
}

/// The round gradient number in front of a step title.
class StepNumber extends StatelessWidget {
  const StepNumber({super.key, required this.number, this.size = 28});

  final int number;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AppColors.brand, AppColors.violet]),
      ),
      child: Text(
        '$number',
        style: TextStyle(fontSize: size * 0.46, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }
}

/// A one-line note with an emoji, tinted by [tone]: a trap, a hint, a fact.
class SolutionNote extends StatelessWidget {
  const SolutionNote({super.key, required this.icon, required this.text, required this.tone});

  final String icon;
  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.tint(tone, 0x1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.tint(tone, 0x59)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 15, height: 1.35)),
          const SizedBox(width: 9),
          Expanded(child: ProseMath(text, style: const TextStyle(fontSize: 13.5, height: 1.5))),
        ],
      ),
    );
  }
}

class _Simpler extends StatelessWidget {
  const _Simpler({required this.lines, this.rule});

  final List<String> lines;
  final String? rule;

  @override
  Widget build(BuildContext context) {
    final sky = context.mathValue(1);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: AppColors.tint(sky, 0x14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tint(sky, 0x73), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💬 SODDAROQ TUSHUNTIRAMAN',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.2, color: sky),
          ),
          for (final line in lines) ...[
            const SizedBox(height: 7),
            ProseMath(line, style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
          if (rule != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.tint(sky, 0x29),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Qoida: ${rule!}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: sky),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
