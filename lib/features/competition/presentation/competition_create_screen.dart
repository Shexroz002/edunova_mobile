import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/hint_pill.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../tests/data/tests_repository.dart';
import '../../tests/domain/quiz.dart';
import '../../tests/presentation/quiz_picker_sheet.dart';
import '../data/competition_repository.dart';
import 'widgets/quiz_choice_card.dart';
import 'widgets/setting_row.dart';

/// Participant counts offered as presets, and the bounds the web enforces.
const kParticipantPresets = [2, 4, 6, 10, 20];
const kMinParticipants = 2;
const kMaxParticipants = 100;

/// Duration presets and bounds (the backend itself sets none).
const kDurationPresets = [10, 20, 30, 45, 60];
const kMinMinutes = 1;
const kMaxMinutes = 180;

/// Both settings start usable, so the screen has exactly one open decision.
const kDefaultParticipants = 4;
const kDefaultMinutes = 30;

/// Whether the student owns any quiz at all.
///
/// `quiz_list` filters by `user_id`, so a newly registered student has none and
/// must be sent to Test yaratish instead of an empty picker.
final _hasQuizzesProvider = FutureProvider.autoDispose<bool>((ref) async {
  final page = await ref.watch(testsRepositoryProvider).fetchQuizzes(page: 1, size: 1);
  return page.items.isNotEmpty;
});

/// Creates a competition: pick a quiz, adjust two settings, start.
///
/// This used to be a three-step accordion behind a full-screen marketing card,
/// about 1900 px tall for three decisions — two of which already had sensible
/// defaults. It is one screen now: the quiz choice, the two settings with their
/// values on show, and a pinned action that never scrolls away.
class CompetitionCreateScreen extends ConsumerStatefulWidget {
  const CompetitionCreateScreen({super.key, this.initialQuizId});

  /// Preselects a quiz when opened from a test card.
  final int? initialQuizId;

  @override
  ConsumerState<CompetitionCreateScreen> createState() => _CompetitionCreateScreenState();
}

class _CompetitionCreateScreenState extends ConsumerState<CompetitionCreateScreen> {
  QuizSummary? _quiz;
  int _participants = kDefaultParticipants;
  int _minutes = kDefaultMinutes;

  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuizId != null) _preselectQuiz(widget.initialQuizId!);
  }

  Future<void> _preselectQuiz(int quizId) async {
    try {
      final quiz = await ref.read(testsRepositoryProvider).fetchQuiz(quizId);
      if (!mounted) return;
      setState(() => _quiz = quiz.asSummary);
    } on ApiException {
      // A bad deep link just leaves the picker open.
    }
  }

  Future<void> _pickQuiz() async {
    final quiz = await showQuizPickerSheet(context, selected: _quiz);
    if (quiz == null || !mounted) return;
    setState(() => _quiz = quiz);
  }

  Future<void> _create() async {
    final quiz = _quiz;
    if (quiz == null) return;

    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final info = await ref.read(competitionRepositoryProvider).create(
            quizId: quiz.id,
            durationMinutes: _minutes,
            maxParticipants: _participants,
          );
      if (!mounted) return;
      // The lobby re-reads `info/` for the quiz name, which create leaves null.
      context.pushReplacement('/session/${info.sessionId}/lobby');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  /// Wording the web uses under each summary value.
  String get _groupNote => _participants <= 5
      ? 'Kichik guruh'
      : (_participants <= 20 ? "O‘rta guruh" : 'Katta guruh');

  String get _lengthNote =>
      _minutes < 15 ? 'Qisqa' : (_minutes < 40 ? "O‘rtacha" : 'Uzoq');

  @override
  Widget build(BuildContext context) {
    final quiz = _quiz;
    // A pending or failed check keeps the picker: being wrong that way costs an
    // empty sheet, the other way hides the only action.
    final hasQuizzes = ref.watch(_hasQuizzesProvider).valueOrNull ?? true;

    return Scaffold(
      appBar: const PageAppBar(title: Text('Musobaqa yaratish'), showThemeToggle: false),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(context.pagePadding),
                children: [
                  ContentConstraint(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        QuizChoiceCard(
                          quiz: quiz,
                          hasQuizzes: hasQuizzes,
                          onPick: _pickQuiz,
                          onCreateQuiz: () => context.push(Routes.quizCreate),
                        ),
                        const SizedBox(height: 12),
                        _SettingsCard(
                          participants: _participants,
                          minutes: _minutes,
                          groupNote: _groupNote,
                          lengthNote: _lengthNote,
                          onParticipants: (value) => setState(() => _participants = value),
                          onMinutes: (value) => setState(() => _minutes = value),
                        ),
                        const SizedBox(height: 12),
                        const HintPill(
                          text: 'Yaratilgach taklif kodi chiqadi — do‘stlaringiz shu kod '
                              'bilan qo‘shiladi.',
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          ErrorBanner(_error!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _BottomBar(
              ready: quiz != null,
              summary: quiz == null
                  ? (hasQuizzes
                      ? 'Boshlash uchun test tanlang'
                      : 'Musobaqa uchun avval test yarating')
                  : '${quiz.title} · $_participants kishi · ${formatMinutes(_minutes)}',
              creating: _creating,
              onStart: _create,
            ),
          ],
        ),
      ),
    );
  }
}

/// The two numbers, both already set.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.participants,
    required this.minutes,
    required this.groupNote,
    required this.lengthNote,
    required this.onParticipants,
    required this.onMinutes,
  });

  final int participants;
  final int minutes;
  final String groupNote;
  final String lengthNote;
  final ValueChanged<int> onParticipants;
  final ValueChanged<int> onMinutes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'MUSOBAQA SOZLAMALARI',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: c.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          SettingRow(
            icon: Icons.people_alt_rounded,
            color: AppColors.success,
            label: 'Ishtirokchilar',
            note: groupNote,
            value: participants,
            unit: 'kishi',
            min: kMinParticipants,
            max: kMaxParticipants,
            step: 1,
            presets: kParticipantPresets,
            onChanged: onParticipants,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(height: 1, color: c.border),
          ),
          SettingRow(
            icon: Icons.schedule_rounded,
            color: AppColors.warning,
            label: 'Davomiylik',
            note: lengthNote,
            value: minutes,
            unit: 'daqiqa',
            min: kMinMinutes,
            max: kMaxMinutes,
            step: 5,
            presets: kDurationPresets,
            onChanged: onMinutes,
          ),
        ],
      ),
    );
  }
}

/// Pinned summary and action, so the button is never scrolled out of reach.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.ready,
    required this.summary,
    required this.creating,
    required this.onStart,
  });

  final bool ready;
  final String summary;
  final bool creating;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = ready ? context.readable(AppColors.success) : c.textMuted;

    return Container(
      padding: EdgeInsets.fromLTRB(context.pagePadding, 12, context.pagePadding, 16),
      decoration: BoxDecoration(
        color: c.bgCard,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: ContentConstraint(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  ready ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                  size: 14,
                  color: tone,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: ready ? FontWeight.w600 : FontWeight.w400,
                      color: tone,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GradientButton(
              label: creating ? 'Musobaqa yaratilmoqda...' : 'Musobaqani boshlash',
              icon: Icons.emoji_events_rounded,
              enabled: ready,
              loading: creating,
              height: 54,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}
