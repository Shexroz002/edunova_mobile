import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../session/data/session_repository.dart';

/// Time limits offered to the student (same as the web `TestTimeModal`).
const kTestTimeOptions = [10, 15, 20, 30, 45, 60, 90, 120];

/// Asks for a time limit, starts a single-player session and returns its id
/// (null if the sheet was dismissed).
Future<int?> showStartTestSheet(
  BuildContext context, {
  required int quizId,
  required String title,
  required int questionCount,
  required int suggestedMinutes,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.colors.bgCard,
    builder: (_) => _StartTestSheet(
      quizId: quizId,
      title: title,
      questionCount: questionCount,
      suggestedMinutes: suggestedMinutes,
    ),
  );
}

class _StartTestSheet extends ConsumerStatefulWidget {
  const _StartTestSheet({
    required this.quizId,
    required this.title,
    required this.questionCount,
    required this.suggestedMinutes,
  });

  final int quizId;
  final String title;
  final int questionCount;
  final int suggestedMinutes;

  @override
  ConsumerState<_StartTestSheet> createState() => _StartTestSheetState();
}

class _StartTestSheetState extends ConsumerState<_StartTestSheet> {
  late int _minutes = _recommended;
  bool _starting = false;
  String? _error;

  /// The smallest option that fits the suggestion (or the largest option).
  int get _recommended => kTestTimeOptions.firstWhere(
        (option) => option >= widget.suggestedMinutes,
        orElse: () => kTestTimeOptions.last,
      );

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final sessionId = await ref
          .read(sessionRepositoryProvider)
          .startSinglePlayer(quizId: widget.quizId, minutes: _minutes);
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.questionCount} ta savol · vaqtni tanlang',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in kTestTimeOptions)
                  ChoiceChip(
                    label: Text(formatMinutes(option)),
                    selected: option == _minutes,
                    onSelected: _starting ? null : (_) => setState(() => _minutes = option),
                    avatar:
                        option == _recommended ? const Icon(Icons.star_rounded, size: 16) : null,
                    showCheckmark: false,
                    selectedColor: c.accentMuted,
                    side: BorderSide(color: option == _minutes ? AppColors.brand : c.border),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: option == _minutes ? c.accent : c.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "⭐ — tavsiya etilgan vaqt. Vaqt tugaganda test avtomatik yakunlanadi.",
              style: TextStyle(fontSize: 12, color: c.textMuted),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Testni boshlash',
              icon: Icons.play_arrow_rounded,
              loading: _starting,
              onPressed: _start,
            ),
          ],
        ),
      ),
    );
  }
}
