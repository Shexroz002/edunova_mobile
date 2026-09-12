import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../tests/data/tests_repository.dart';
import '../../../tests/domain/quiz.dart';

/// Picks a quiz for a competition.
///
/// The web uses a searchable dropdown; on a phone a full-height sheet with a
/// search field and large tap targets is the better equivalent.
Future<QuizSummary?> showQuizPickerSheet(BuildContext context, {QuizSummary? selected}) {
  return showModalBottomSheet<QuizSummary>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.colors.bgCard,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, controller) =>
          _QuizPickerSheet(selected: selected, scrollController: controller),
    ),
  );
}

class _QuizPickerSheet extends ConsumerStatefulWidget {
  const _QuizPickerSheet({required this.scrollController, this.selected});

  final ScrollController scrollController;
  final QuizSummary? selected;

  @override
  ConsumerState<_QuizPickerSheet> createState() => _QuizPickerSheetState();
}

class _QuizPickerSheetState extends ConsumerState<_QuizPickerSheet> {
  String _search = '';
  late Future<List<QuizSummary>> _future = _load();

  Future<List<QuizSummary>> _load() async {
    final page = await ref
        .read(testsRepositoryProvider)
        .fetchQuizzes(search: _search.isEmpty ? null : _search, page: 1, size: 50);
    return page.items;
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Testni tanlang',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
          const SizedBox(height: 12),
          SearchField(
            hint: 'Testlarni izlash...',
            initialValue: _search,
            onChanged: (value) {
              _search = value;
              _reload();
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<QuizSummary>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
                if (snapshot.hasError) {
                  return ErrorView(
                    message: ApiException.from(snapshot.error!).message,
                    onRetry: _reload,
                  );
                }
                final quizzes = snapshot.data ?? const <QuizSummary>[];
                if (quizzes.isEmpty) {
                  return const EmptyView(
                    icon: Icons.quiz_outlined,
                    title: 'Testlar topilmadi',
                    subtitle: "Boshqa so'z bilan qidirib ko'ring",
                  );
                }
                return ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: quizzes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final quiz = quizzes[index];
                    final isSelected = widget.selected?.id == quiz.id;
                    return _QuizRow(
                      quiz: quiz,
                      selected: isSelected,
                      onTap: () => Navigator.of(context).pop(quiz),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizRow extends StatelessWidget {
  const _QuizRow({required this.quiz, required this.selected, required this.onTap});

  final QuizSummary quiz;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: selected ? c.accentMuted : c.bgInner,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.brand : c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${quiz.subject ?? "Fan ko'rsatilmagan"} · ${quiz.questionCount} ta savol',
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: selected ? AppColors.brand : c.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
