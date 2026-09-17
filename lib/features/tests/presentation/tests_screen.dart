import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/paged_list_view.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_views.dart';
import '../data/tests_repository.dart';
import '../domain/quiz.dart';
import 'quiz_card.dart';
import 'system_quiz_notice.dart';
import 'start_test_sheet.dart';

/// The student's quizzes with search and infinite scroll.
///
/// Follows the web `StudentTestsPage.tsx`: an in-page header, a gradient hero
/// card with the three counters, the search field, a result line, then the
/// cards. Sized for a phone — bigger tap targets and a single column.
class TestsScreen extends ConsumerStatefulWidget {
  const TestsScreen({super.key});

  @override
  ConsumerState<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends ConsumerState<TestsScreen> {
  String _search = '';

  /// Counters for the hero card, filled in as pages load.
  int _total = 0;
  int _newCount = 0;
  int _subjectCount = 0;

  Future<void> _start(QuizSummary quiz) async {
    final sessionId = await showStartTestSheet(context, quiz: quiz);
    if (sessionId != null && mounted) context.push('/session/$sessionId/play');
  }

  void _onLoaded(List<QuizSummary> items, int total) {
    final subjects = items
        .map((q) => q.subject?.trim().toLowerCase())
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet();
    setState(() {
      _total = total;
      _newCount = items.where((q) => q.isNew).length;
      _subjectCount = subjects.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repository = ref.watch(testsRepositoryProvider);

    return Scaffold(
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
        child: ContentConstraint(
          maxWidth: 760,
          child: PagedListView<QuizSummary>(
            reloadKey: _search,
            padding: EdgeInsets.fromLTRB(context.pagePadding, 8, context.pagePadding, 28),
            fetchPage: (page) => repository.fetchQuizzes(search: _search, page: page),
            onLoaded: _onLoaded,
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeader(title: 'Testlar', subtitle: "Mavjud testlar ro'yxati"),
                const SizedBox(height: 16),
                _HeroCard(total: _total, newCount: _newCount, subjects: _subjectCount),
                const SizedBox(height: 14),
                SearchField(
                  hint: 'Testlarni izlash...',
                  initialValue: _search,
                  onChanged: (value) => setState(() => _search = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.brand,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_total ta test topildi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
            empty: EmptyView(
              icon: Icons.quiz_outlined,
              title: _search.isEmpty ? "Hozircha testlar yo'q" : 'Hech narsa topilmadi',
              subtitle: _search.isEmpty
                  ? 'PDF yoki AI orqali test yarating'
                  : "Boshqa so'z bilan qidirib ko'ring",
            ),
            itemBuilder: (context, quiz) => QuizCard(
              quiz: quiz,
              // A system quiz has no detail to open: the page would list its
              // questions, which is the answer sheet for a test not yet taken.
              onOpen: () => quiz.canEdit
                  ? context.push('/tests/${quiz.id}')
                  : showSystemQuizNotice(
                      context,
                      canStart: quiz.questionCount > 0,
                      onStart: () => _start(quiz),
                    ),
              onStart: () => _start(quiz),
              onCompete: () => context.push('/competition/new?quizId=${quiz.id}'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient intro card with the three counters from the web.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.total, required this.newCount, required this.subjects});

  final int total;
  final int newCount;
  final int subjects;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF312E81), Color(0xFF4C1D95)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bolt_rounded, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Testlar',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Bilimingizni sinab ko'ring va natijalarni yaxshilang",
                      style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFFCBD5E1)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatPill(label: '$total ta test', color: AppColors.brandLight),
              _StatPill(label: '$newCount ta yangi', color: const Color(0xFFA78BFA)),
              _StatPill(label: '$subjects ta fan', color: AppColors.sky),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
