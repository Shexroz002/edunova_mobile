import 'package:flutter/material.dart';

import '../../../features/tests/domain/quiz.dart';
import '../../theme/app_colors.dart';
import 'badges.dart';
import 'markdown_table.dart';
import 'math_text.dart';
import 'option_tile.dart';

/// Full question: meta line, text, optional table and images, and options.
///
/// The parent decides each option's [OptionState] and what tapping does,
/// so the same widget serves playing, detail preview and review.
class QuestionView extends StatelessWidget {
  const QuestionView({
    super.key,
    required this.question,
    required this.stateOf,
    this.onOptionTap,
    this.header,
  });

  final QuestionContent question;

  /// State of each option (selected / correct / wrong / idle).
  final OptionState Function(AnswerOption option) stateOf;

  /// Null makes options read-only.
  final ValueChanged<AnswerOption>? onOptionTap;

  /// Optional widget above the meta line (e.g. "Savol 3 / 30").
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final table = question.tableMarkdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[header!, const SizedBox(height: 10)],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (question.subject != null) SubjectBadge(question.subject),
            DifficultyChip(question.difficulty),
            if (question.topic != null)
              Text(question.topic!, style: TextStyle(fontSize: 12, color: c.textMuted)),
          ],
        ),
        const SizedBox(height: 14),
        MathText(
          question.text,
          style: TextStyle(
              fontSize: 17, height: 1.45, fontWeight: FontWeight.w600, color: c.textPrimary),
        ),
        if (table != null && table.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          MarkdownTable(table),
        ],
        for (final url in question.imageUrls) ...[
          const SizedBox(height: 14),
          _QuestionImage(url: url),
        ],
        const SizedBox(height: 20),
        for (final option in question.options) ...[
          OptionTile(
            label: option.label,
            text: option.text,
            state: stateOf(option),
            onTap: onOptionTap == null ? null : () => onOptionTap!(option),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _QuestionImage extends StatelessWidget {
  const _QuestionImage({required this.url});

  final String url;

  void _openZoom(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(maxScale: 5, child: Image.network(url)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openZoom(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
        ),
      ),
    );
  }
}
