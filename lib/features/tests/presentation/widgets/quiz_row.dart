import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/subject_style.dart';
import '../../domain/quiz.dart';

/// One quiz in the list: what it covers, how long it takes, and a way to start.
///
/// The card this replaces was 298 dp — three badges, a two-line title, a
/// description, three meta chips and two buttons — so a list of 44 quizzes ran
/// to about twenty-two screens and showed barely one at a time. What went:
///
/// * the description, which restates the title ("Ingliz tilidan prepozitsiyalar
///   bo'yicha test" / "Ingliz tilidagi prepozitsiyalar haqida test savollari");
/// * the NEW and AI/PDF badges — 16 of 44 are new, which is not selective
///   enough to help, and where a quiz came from says nothing about taking it.
///   "Tizim testi" stays: it is the minority, and it explains why the row opens
///   a notice rather than a detail page;
/// * the creation date, the least useful of the three meta chips;
/// * the "Musobaqa" button (owner decision) — competitions start from the
///   Musobaqa block on the home page, which picks a quiz of its own.
class QuizRow extends StatelessWidget {
  const QuizRow({
    super.key,
    required this.quiz,
    required this.onOpen,
    required this.onStart,
  });

  final QuizSummary quiz;

  /// Opens the quiz detail, or the notice a system quiz shows instead.
  final VoidCallback onOpen;

  final VoidCallback onStart;

  /// A quiz whose questions are not ready yet cannot be taken.
  bool get _ready => quiz.questionCount > 0;

  String get _meta {
    final subject = SubjectStyle.displayName(quiz.subject);
    final parts = [if (subject.isNotEmpty) subject];
    if (!_ready) {
      parts.add('savol yo‘q');
      return parts.join(' · ');
    }
    parts.add('${quiz.questionCount} savol');
    parts.add('~${quiz.suggestedMinutes} daqiqa');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = SubjectStyle.of(quiz.subject);

    return Opacity(
      opacity: _ready ? 1 : 0.6,
      child: Material(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: c.border),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.tint(style.color, 0x2B),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(style.icon, size: 19, color: context.readable(style.color)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        quiz.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                          height: 1.3,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (!quiz.canEdit) ...[
                            const _LibraryBadge(),
                            const SizedBox(width: 7),
                          ],
                          Flexible(
                            child: Text(
                              _meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: c.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                _StartButton(ready: _ready, onTap: onStart),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks a quiz from the shared library, which has no detail page of its own.
class _LibraryBadge extends StatelessWidget {
  const _LibraryBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          'Tizim testi',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c.textMuted),
        ),
      ),
    );
  }
}

/// Starts the quiz, or says why it cannot be started.
class _StartButton extends StatelessWidget {
  const _StartButton({required this.ready, required this.onTap});

  final bool ready;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: ready ? onTap : null,
          customBorder: const CircleBorder(),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ready ? AppColors.brandDark : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
                border: ready ? null : Border.all(color: c.border),
              ),
              child: Icon(
                ready ? Icons.play_arrow_rounded : Icons.lock_outline_rounded,
                size: ready ? 21 : 17,
                color: ready ? Colors.white : c.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
