import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/solution_models.dart';
import 'solution_tex.dart';
import 'tex_prose.dart';

/// A word problem drawn as one bar: the parts side by side, the total above.
///
/// Turning words into an equation is the hard part of a word problem; with the
/// parts on one line under their total, the equation can be read off the
/// picture.
class TapeBar extends StatelessWidget {
  const TapeBar({super.key, required this.tape});

  final TapeSpec tape;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final flex = [for (final p in tape.parts) (p.weight * 100).round().clamp(1, 100000)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tape.total.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              '◀  jami ${texPreview(tape.total)}  ▶',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: c.textSecondary),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              border: Border.all(color: c.border, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, part) in tape.parts.indexed)
                  Expanded(
                    flex: flex[i],
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.tint(context.mathValue(i % 3 + 1), 0x38),
                        border: i == 0 ? null : Border(left: BorderSide(color: c.border, width: 1.5)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: BoardFormula(r'\hl' '${'abc'[i % 3]}{${part.expr}}', size: 16),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            for (final (i, part) in tape.parts.indexed)
              Expanded(
                flex: flex[i],
                child: Text(
                  texPreview(part.label),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textMuted),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
