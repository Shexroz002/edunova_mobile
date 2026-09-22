import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';



import '../../core/network/api_exception.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/page_app_bar.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/state_views.dart';
import '../analytics/data/analytics_repository.dart';
import '../analytics/domain/analytics_models.dart';
import '../auth/presentation/auth_controller.dart';
import '../competition/presentation/join_code_sheet.dart';
import '../notifications/presentation/widgets/notification_bell.dart';
import '../tests/presentation/start_test_sheet.dart';
import 'widgets/competition_block.dart';
import 'widgets/hello_row.dart';
import 'widgets/play_hero.dart';
import 'widgets/quick_actions.dart';
import '../analytics/presentation/subject_list.dart';

/// Student home: greeting, the one primary action, the secondary actions, the
/// competition block and the subject list.
///
/// The page used to be a vertical menu about 1 400 dp tall on a 607 dp
/// viewport, so the only blocks with real content — the competition card and
/// the subject list — never reached the first screen. Three things came out:
/// the three stat cards (the same numbers the Statistika tab shows, and none of
/// them says what to do next), the second way into a test, and the per-tile
/// descriptions. What is left fits about one screen.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Opens the start sheet and, once a session exists, the play screen.
  ///
  /// [subject] pre-filters the quiz picker, which is how a subject row starts a
  /// test in its own subject.
  static Future<void> _startTest(BuildContext context, {String? subject}) async {
    final sessionId = await showStartTestSheet(context, subject: subject);
    if (sessionId != null && context.mounted) context.push('/session/$sessionId/play');
  }

  /// Joins a competition by code and opens its lobby.
  static Future<void> _joinCompetition(BuildContext context) async {
    final sessionId = await showJoinCodeSheet(context);
    if (sessionId != null && context.mounted) context.push('/session/$sessionId/lobby');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final subjects = ref.watch(subjectStatsProvider);
    // No subject has been answered yet, so no test has been taken.
    final firstTest = subjects.valueOrNull?.isEmpty ?? false;

    return Scaffold(
      appBar: PageAppBar(
        title: context.isPhone ? const BrandTitle(size: 40) : const Text('Bosh sahifa'),
        actions: const [NotificationBell()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(subjectStatsProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(context.pagePadding, 12, context.pagePadding, 28),
          children: [
            ContentConstraint(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HelloRow(
                    user: user,
                    onCompleteProfile: () => context.push(Routes.profileEdit),
                  ),
                  const SizedBox(height: 12),
                  PlayHero(
                    isFirstTest: firstTest,
                    onStart: () => _startTest(context),
                  ),
                  const SizedBox(height: 12),
                  QuickActions(
                    actions: [
                      QuickAction(
                        icon: Icons.add_box_outlined,
                        color: AppColors.emerald,
                        label: 'Test yaratish',
                        onTap: () => context.push(Routes.quizCreate),
                      ),
                      QuickAction(
                        icon: Icons.play_circle_outline_rounded,
                        color: AppColors.brandLight,
                        label: 'Testlar',
                        onTap: () => context.push(Routes.tests),
                      ),
                      QuickAction(
                        icon: Icons.history_rounded,
                        color: AppColors.warning,
                        label: 'Natijalar',
                        onTap: () => context.push(Routes.results),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CompetitionBlock(
                    onCreate: () => context.push(Routes.competitionNew),
                    onJoin: () => _joinCompetition(context),
                  ),
                  const SizedBox(height: 20),
                  _Subjects(subjects: subjects),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Fanlarim", or an invitation while there is nothing to show.
class _Subjects extends StatelessWidget {
  const _Subjects({required this.subjects});

  final AsyncValue<List<SubjectStats>> subjects;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = subjects.valueOrNull ?? const <SubjectStats>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                'Fanlarim',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: c.textPrimary,
                ),
              ),
            ),
            if (rows.isNotEmpty)
              InkWell(
                onTap: () => context.go(Routes.statistics),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(
                    'Statistika →',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: context.readable(AppColors.brand),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        subjects.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => ErrorBanner(ApiException.from(error).message),
          data: (items) => items.isEmpty
              ? const _NoSubjects()
              : SubjectList(
                  subjects: items,
                  onPractise: (subject) => HomeScreen._startTest(context, subject: subject),
                ),
        ),
      ],
    );
  }
}

/// Shown until the first test is finished.
class _NoSubjects extends StatelessWidget {
  const _NoSubjects();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Text(
            'Hali natija yo‘q',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Birinchi testni ishlang — shundan keyin har bir fan '
            'bo‘yicha o‘sishingiz shu yerda chiqadi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.45, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}
