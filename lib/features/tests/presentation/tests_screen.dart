import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/paged_list_view.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_views.dart';
import '../data/tests_repository.dart';
import '../domain/quiz.dart';
import 'start_test_sheet.dart';
import 'system_quiz_notice.dart';
import 'widgets/quiz_row.dart';

/// The student's quizzes with search and infinite scroll.
///
/// The web opens on a gradient card carrying three counters; one of them
/// repeated the result line below it word for word, and the other two — how
/// many are new, how many subjects — are numbers rather than filters. With the
/// card and the in-page header gone, the list starts 90 dp down the page rather
/// than 318, and each quiz is a row instead of a 298 dp card.
class TestsScreen extends ConsumerStatefulWidget {
  const TestsScreen({super.key});

  @override
  ConsumerState<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends ConsumerState<TestsScreen> {
  String _search = '';
  int _total = 0;

  Future<void> _start(QuizSummary quiz) async {
    final sessionId = await showStartTestSheet(context, quiz: quiz);
    if (sessionId != null && mounted) context.push('/session/$sessionId/play');
  }

  /// Opens the detail, or the notice a system quiz shows instead of one.
  void _open(QuizSummary quiz) {
    if (quiz.canEdit) {
      context.push('/tests/${quiz.id}');
      return;
    }
    // A system quiz has no detail to open: the page would list its questions,
    // which is the answer sheet for a test not yet taken.
    showSystemQuizNotice(
      context,
      canStart: quiz.questionCount > 0,
      onStart: () => _start(quiz),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repository = ref.watch(testsRepositoryProvider);

    return Scaffold(
      appBar: const PageAppBar(title: Text('Testlar'), showFriends: false),
      // The web puts "Test yaratish" in the page header; on a phone it reads
      // better as a floating action that survives scrolling.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.quizCreate),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Test yaratish'),
      ),
      body: SafeArea(
        top: false,
        child: ContentConstraint(
          maxWidth: 760,
          child: PagedListView<QuizSummary>(
            reloadKey: _search,
            // The last row used to finish under the floating button, which cut
            // its title in half; the extra bottom padding clears it.
            padding: EdgeInsets.fromLTRB(context.pagePadding, 12, context.pagePadding, 92),
            fetchPage: (page) => repository.fetchQuizzes(search: _search, page: page),
            onLoaded: (items, total) {
              if (total != _total) setState(() => _total = total);
            },
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchField(
                  hint: 'Testlarni izlash...',
                  initialValue: _search,
                  onChanged: (value) => setState(() => _search = value),
                ),
                const SizedBox(height: 14),
                Text(
                  "$_total TA TEST",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: c.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
            empty: EmptyView(
              icon: Icons.quiz_outlined,
              title: _search.isEmpty ? 'Hozircha test yo‘q' : 'Hech narsa topilmadi',
              subtitle: _search.isEmpty
                  ? 'PDF yuklang yoki AI dan so‘rang — test bir necha '
                      'daqiqada tayyor bo‘ladi.'
                  : "Boshqa so'z bilan qidirib ko'ring",
              actionLabel: _search.isEmpty ? 'Test yaratish' : null,
              onAction: _search.isEmpty ? () => context.push(Routes.quizCreate) : null,
            ),
            itemBuilder: (context, quiz) => QuizRow(
              quiz: quiz,
              onOpen: () => _open(quiz),
              onStart: () => _start(quiz),
            ),
          ),
        ),
      ),
    );
  }
}
