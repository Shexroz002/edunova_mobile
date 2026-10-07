import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../domain/solution_models.dart';
import 'solution_controllers.dart';
import 'widgets/dispute_card.dart';
import 'widgets/solution_tex.dart';
import 'widgets/step_card.dart';

/// Opens "Qayerda adashdingiz?" for a question the student just got wrong.
Future<void> showMistakeSheet(
  BuildContext context, {
  required int questionId,
  required String chosen,
  String? subject,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.bgCard,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => MistakeSheet(questionId: questionId, chosen: chosen, subject: subject),
  );
}

/// Where the student's wrong option probably came from, before the full solution.
///
/// Finding the mistake matters more than the solution: the option the student
/// picked is known, so the sheet can say *where* the paths split. The first
/// line encourages, the right and wrong lines stand side by side, and a small
/// note admits the app sees only the likely cause, not the student's thinking.
class MistakeSheet extends ConsumerWidget {
  const MistakeSheet({super.key, required this.questionId, required this.chosen, this.subject});

  final int questionId;
  final String chosen;

  /// Passed on to the full solution's waiting screen.
  final String? subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (questionId: questionId, chosen: chosen);
    final state = ref.watch(explanationControllerProvider(args));
    final c = context.colors;

    void openFull() {
      Navigator.of(context).pop();
      context.push(Routes.questionSolutionPath(questionId, chosen: chosen, subject: subject));
    }

    final body = state.when(
      loading: () => const _Busy(),
      error: (_, __) => const _Line('Yechimni yuklab bo‘lmadi. Internetni tekshiring.'),
      data: (result) => switch (result.status) {
        ExplanationStatus.pending => const _Busy(),
        ExplanationStatus.unavailable => _Line(result.message ?? 'Bu savol uchun yechim yo‘q.'),
        ExplanationStatus.disputed => DisputeCard(result: result),
        ExplanationStatus.ready => result.hint == null
            ? const _Line('Bu variant qanday chiqqanini aniqlab bo‘lmadi. To‘liq yechimni ko‘ring.')
            : _Hint(hint: result.hint!, correct: result.correctOption),
      },
    );
    final ready = state.valueOrNull?.status == ExplanationStatus.ready;
    // A dispute means the student may not have gone wrong at all.
    final disputed = state.valueOrNull?.status == ExplanationStatus.disputed;

    // The bottom inset keeps the last button clear of the system navigation
    // bar, which is drawn over the sheet in edge-to-edge mode.
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(9)),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            disputed ? 'Javobingiz haqida' : 'Qayerda adashdingiz?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const SizedBox(height: 12),
          Flexible(child: SingleChildScrollView(child: body)),
          if (ready) ...[
            const SizedBox(height: 14),
            GradientButton(label: 'To‘liq yechimni ko‘rish', height: 50, onPressed: openFull),
          ],
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.hint, this.correct});

  final SolutionHint hint;
  final String? correct;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final green = context.readable(AppColors.success);
    final red = context.readable(AppColors.error);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hint.headline.isNotEmpty) ProseMath(hint.headline, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (hint.rightTex.isNotEmpty || hint.wrongTex.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: c.bgInner,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                if (hint.rightTex.isNotEmpty) _Compare(label: 'To‘g‘ri', tone: green, tex: hint.rightTex),
                if (hint.wrongTex.isNotEmpty) _Compare(label: 'Siz', tone: red, tex: hint.wrongTex),
              ],
            ),
          ),
        ],
        if (hint.why.isNotEmpty) ...[
          const SizedBox(height: 12),
          ProseMath(hint.why, style: const TextStyle(fontSize: 14)),
        ],
        if (hint.tip.isNotEmpty) ...[
          const SizedBox(height: 12),
          SolutionNote(icon: '✋', text: hint.tip, tone: AppColors.warning),
        ],
        const SizedBox(height: 10),
        Text(
          'Bu xato ko‘pincha shu sababdan chiqadi',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: c.textMuted),
        ),
      ],
    );
  }
}

class _Compare extends StatelessWidget {
  const _Compare({required this.label, required this.tone, required this.tex});

  final String label;
  final Color tone;
  final String tex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tint(tone, 0x29),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: tone)),
          ),
          const SizedBox(width: 10),
          Expanded(child: BoardFormula(tex, size: 17)),
        ],
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(height: 12),
            Text(
              'Yechim tayyorlanmoqda — odatda 20–40 soniya.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.colors.textMuted),
            ),
          ],
        ),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text, style: TextStyle(fontSize: 14, height: 1.5, color: context.colors.textSecondary)),
      );
}
