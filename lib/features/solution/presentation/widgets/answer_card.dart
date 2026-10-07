import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/solution_models.dart';
import 'solution_tex.dart';
import 'step_card.dart';

/// The answer, read aloud, then the check, the real-life sense and the shortcut.
class AnswerCard extends StatelessWidget {
  const AnswerCard({super.key, required this.solution, this.option});

  final Solution solution;

  /// The test option this answer is, when the problem came from a test.
  final String? option;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final green = context.readable(AppColors.success);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.tint(AppColors.success, 0x26), AppColors.tint(AppColors.success, 0x0D)],
            ),
            border: Border.all(color: AppColors.tint(AppColors.success, 0x80), width: 1.8),
          ),
          child: Column(
            children: [
              Text('🎉 JAVOB',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: green)),
              const SizedBox(height: 6),
              BoardFormula(solution.answer.tex, size: 30, bold: true),
              if (solution.answer.words.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    text: 'o‘qilishi: ',
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                    children: [
                      TextSpan(
                        text: solution.answer.words,
                        style: TextStyle(fontWeight: FontWeight.w800, color: c.textPrimary),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (option != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.tint(AppColors.success, 0x2E),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('$option variant',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: green)),
                ),
              ],
            ],
          ),
        ),
        if (solution.check != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: c.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔍 Tekshirib ko‘ramiz', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                if (solution.check!.say.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ProseMath(solution.check!.say, style: const TextStyle(fontSize: 14)),
                ],
                const SizedBox(height: 4),
                BoardFormula(solution.check!.tex, size: 17),
              ],
            ),
          ),
        ],
        if (solution.realLife != null) ...[
          const SizedBox(height: 10),
          SolutionNote(icon: '🏋️', text: 'Hayotda: ${solution.realLife!}', tone: AppColors.brand),
        ],
        if (solution.shortcut != null) ...[
          const SizedBox(height: 10),
          _Shortcut(shortcut: solution.shortcut!),
        ],
      ],
    );
  }
}

/// The faster way, closed until a curious student opens it.
class _Shortcut extends StatefulWidget {
  const _Shortcut({required this.shortcut});

  final SolutionShortcut shortcut;

  @override
  State<_Shortcut> createState() => _ShortcutState();
}

class _ShortcutState extends State<_Shortcut> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 19)),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Qisqa yo‘li ham bor',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                        Text(
                          widget.shortcut.title.isEmpty
                              ? 'qiziquvchilar uchun'
                              : '${widget.shortcut.title} · qiziquvchilar uchun',
                          style: TextStyle(fontSize: 12, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: c.textMuted),
                ],
              ),
              if (_open) ...[
                const SizedBox(height: 10),
                if (widget.shortcut.say.isNotEmpty) ProseMath(widget.shortcut.say, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 6),
                for (final line in widget.shortcut.board) BoardFormula(line, size: 17),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
