import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/subject_style.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../session/data/session_repository.dart';
import '../data/tests_repository.dart';
import '../domain/quiz.dart';
import 'quiz_picker_sheet.dart';

/// Time limits offered to the student (same as the web `StartTestModal`).
const kTestTimeOptions = [10, 15, 20, 30, 45, 60, 90, 120];

/// Picks a quiz and a time limit, starts a single-player session and returns
/// its id (null if the sheet was dismissed).
///
/// Pass [quiz] when the caller already has one — the quiz detail and the test
/// list both do. From the home hero it is null, and the sheet asks: that used
/// to be four screens (list → quiz → detail → time sheet) for one intention.
Future<int?> showStartTestSheet(BuildContext context, {QuizSummary? quiz}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.colors.bgCard,
    builder: (_) => _StartTestSheet(quiz: quiz),
  );
}

/// Whether the student owns any quiz at all.
///
/// `quiz_list` filters by `user_id`, so a newly registered student has none and
/// needs Test yaratish rather than an empty picker.
final _hasQuizzesProvider = FutureProvider.autoDispose<bool>((ref) async {
  final page = await ref.watch(testsRepositoryProvider).fetchQuizzes(page: 1, size: 1);
  return page.items.isNotEmpty;
});

class _StartTestSheet extends ConsumerStatefulWidget {
  const _StartTestSheet({this.quiz});

  final QuizSummary? quiz;

  @override
  ConsumerState<_StartTestSheet> createState() => _StartTestSheetState();
}

class _StartTestSheetState extends ConsumerState<_StartTestSheet> {
  QuizSummary? _quiz;
  int? _minutes;
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _quiz = widget.quiz;
    _minutes = _recommended;
  }

  /// The smallest option that fits the quiz's suggestion, or null while no quiz
  /// is chosen — there is nothing to base a recommendation on yet.
  int? get _recommended {
    final quiz = _quiz;
    if (quiz == null) return null;
    return kTestTimeOptions.firstWhere(
      (option) => option >= quiz.suggestedMinutes,
      orElse: () => kTestTimeOptions.last,
    );
  }

  Future<void> _pickQuiz() async {
    final picked = await showQuizPickerSheet(context, selected: _quiz);
    if (picked == null || !mounted) return;
    setState(() {
      _quiz = picked;
      // The suggestion follows the quiz, so a fresh pick resets the limit.
      _minutes = _recommended;
      _error = null;
    });
  }

  Future<void> _start() async {
    final quiz = _quiz;
    final minutes = _minutes;
    if (quiz == null || minutes == null) return;

    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final sessionId = await ref
          .read(sessionRepositoryProvider)
          .startSinglePlayer(quizId: quiz.id, minutes: minutes);
      if (mounted) Navigator.of(context).pop(sessionId);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final quiz = _quiz;
    // A pending or failed check keeps the picker: being wrong that way costs an
    // empty sheet, the other way hides the only action.
    final hasQuizzes = ref.watch(_hasQuizzesProvider).valueOrNull ?? true;
    final empty = !hasQuizzes && quiz == null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 18),
              child: Container(height: 1, color: c.border),
            ),
            const _Label('Test *'),
            const SizedBox(height: 8),
            if (empty)
              const _NoQuiz()
            else
              _QuizRow(quiz: quiz, onTap: _starting ? null : _pickQuiz),
            if (!empty) ...[
              const SizedBox(height: 18),
              const _Label('Vaqt limiti'),
              const SizedBox(height: 8),
              _TimeChips(
                selected: _minutes,
                recommended: _recommended,
                enabled: quiz != null && !_starting,
                onChanged: (value) => setState(() => _minutes = value),
              ),
              const SizedBox(height: 12),
              _Hint(
                text: quiz == null
                    ? 'Test tanlangach tavsiya etilgan vaqt ★ bilan belgilanadi. '
                        'Vaqt tugaganda test avtomatik yakunlanadi.'
                    : 'Savollar soniga qarab ${formatMinutes(_recommended!)} tavsiya '
                        'etiladi. Vaqt tugaganda test avtomatik yakunlanadi.',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 18),
            if (empty)
              GradientButton(
                label: 'Test yaratish',
                icon: Icons.auto_awesome_rounded,
                height: 52,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(Routes.quizCreate);
                },
              )
            else
              GradientButton(
                label: 'Boshlash',
                icon: Icons.play_arrow_rounded,
                height: 52,
                enabled: quiz != null,
                loading: _starting,
                onPressed: _start,
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brand = context.readable(AppColors.brand);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.tint(brand, 0x2E),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.tint(brand, 0x57)),
          ),
          child: Icon(Icons.play_circle_outline_rounded, size: 22, color: brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Test ishlash',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                'Testni tanlang va vaqt limitini belgilang',
                style: TextStyle(fontSize: 12.5, color: c.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.colors.textSecondary,
        ),
      );
}

/// Opens the shared quiz picker; shows the choice once it is made.
class _QuizRow extends StatelessWidget {
  const _QuizRow({required this.quiz, required this.onTap});

  final QuizSummary? quiz;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chosen = quiz;
    final style = chosen == null ? null : SubjectStyle.of(chosen.subject);
    final accent = style == null ? c.textMuted : context.readable(style.color);

    return Material(
      color: c.bgInner,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: chosen == null ? 0 : 12),
          height: chosen == null ? 64 : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: chosen == null ? c.border : AppColors.tint(context.readable(AppColors.brand), 0x8C),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              if (chosen == null)
                Icon(Icons.search_rounded, size: 19, color: c.textMuted)
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.tint(accent, 0x2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.tint(accent, 0x57)),
                  ),
                  child: Icon(style!.icon, size: 19, color: accent),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: chosen == null
                    ? Text(
                        'Testni tanlang...',
                        style: TextStyle(fontSize: 14, color: c.textMuted),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chosen.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${chosen.subject ?? "Fan ko‘rsatilmagan"} · '
                            '${chosen.questionCount} ta savol',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.textSecondary),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The eight limits, with the recommended one starred.
class _TimeChips extends StatelessWidget {
  const _TimeChips({
    required this.selected,
    required this.recommended,
    required this.enabled,
    required this.onChanged,
  });

  final int? selected;
  final int? recommended;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brand = context.readable(AppColors.brand);
    final star = context.readable(AppColors.warning);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in kTestTimeOptions)
            Material(
              color: option == selected && enabled
                  ? AppColors.tint(brand, 0x29)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? () => onChanged(option) : null,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: option == selected && enabled
                          ? AppColors.tint(brand, 0x8C)
                          : c.border,
                    ),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (option == recommended && enabled) ...[
                          Icon(Icons.star_rounded, size: 14, color: star),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          formatMinutes(option),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: option == selected && enabled ? brand : c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.schedule_rounded, size: 15, color: c.textMuted),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, height: 1.5, color: c.textMuted),
          ),
        ),
      ],
    );
  }
}

/// A student with nothing to run yet.
class _NoQuiz extends StatelessWidget {
  const _NoQuiz();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: c.bgInner,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.tint(c.textMuted, 0x29),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Icon(Icons.menu_book_outlined, size: 23, color: c.textMuted),
          ),
          const SizedBox(height: 11),
          Text(
            'Sizda hali test yo‘q',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Ishlash uchun avval test yarating.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}
