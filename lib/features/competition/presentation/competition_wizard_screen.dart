import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../tests/data/tests_repository.dart';
import '../../tests/domain/quiz.dart';
import '../data/competition_repository.dart';
import 'widgets/quiz_picker_sheet.dart';
import 'widgets/step_card.dart';

/// Participant counts offered as presets, and the bounds the web enforces.
const kParticipantPresets = [2, 4, 6, 10, 20];
const kMinParticipants = 2;
const kMaxParticipants = 100;

/// Duration presets and bounds (the backend itself sets none).
const kDurationPresets = [10, 20, 30, 45, 60];
const kMinMinutes = 1;
const kMaxMinutes = 180;

/// Values pre-filled once a quiz is picked, so the flow needs one decision.
const kDefaultParticipants = 4;
const kDefaultMinutes = 30;

/// Creates a competition in three steps: quiz → participants → duration.
///
/// Follows the web `StudentCompetitionPage.tsx`: one scrolling page with a hero
/// card, a progress row and three step cards that open one after another, then
/// a summary and the call to action. Adapted for a phone — the searchable
/// dropdown becomes a bottom sheet and the number fields become steppers, so
/// the keyboard never covers the flow.
class CompetitionWizardScreen extends ConsumerStatefulWidget {
  const CompetitionWizardScreen({super.key, this.initialQuizId});

  /// Preselects a quiz when opened from a test card.
  final int? initialQuizId;

  @override
  ConsumerState<CompetitionWizardScreen> createState() => _CompetitionWizardScreenState();
}

class _CompetitionWizardScreenState extends ConsumerState<CompetitionWizardScreen> {
  QuizSummary? _quiz;
  int? _participants;
  int? _minutes;

  /// Which step is open; a finished step collapses until it is tapped again.
  int _open = 1;

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
      setState(() {
        _quiz = QuizSummary(
          id: quiz.id,
          title: quiz.title,
          description: quiz.description,
          subject: quiz.subject,
          questionCount: quiz.questions.length,
          isNew: false,
          source: quiz.source,
        );
        _participants ??= kDefaultParticipants;
        _minutes ??= kDefaultMinutes;
        _open = 2;
      });
    } on ApiException {
      // A bad deep link just leaves step 1 open.
    }
  }

  bool get _step1Done => _quiz != null;
  bool get _step2Done => _participants != null;
  bool get _step3Done => _minutes != null;
  int get _doneCount => [_step1Done, _step2Done, _step3Done].where((d) => d).length;
  bool get _canCreate => _step1Done && _step2Done && _step3Done;

  Future<void> _pickQuiz() async {
    final quiz = await showQuizPickerSheet(context, selected: _quiz);
    if (quiz == null || !mounted) return;
    setState(() {
      _quiz = quiz;
      // The steppers already display these values, so committing them keeps the
      // summary honest instead of showing "30" next to "Belgilanmagan".
      _participants ??= kDefaultParticipants;
      _minutes ??= kDefaultMinutes;
      _open = 2;
    });
  }

  Future<void> _create() async {
    final quiz = _quiz;
    if (quiz == null || _participants == null || _minutes == null) return;

    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final info = await ref.read(competitionRepositoryProvider).create(
            quizId: quiz.id,
            durationMinutes: _minutes!,
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      body: SafeArea(
        child: ContentConstraint(
          child: ListView(
            padding: EdgeInsets.fromLTRB(context.pagePadding, 8, context.pagePadding, 32),
            children: [
              const PageHeader(
                title: 'Musobaqa yaratish',
                subtitle: "3 qadamda do'stlaringiz bilan musobaqa boshlang",
                titleMaxLines: 1,
              ),
              const SizedBox(height: 16),
              _ProgressRow(done: _doneCount),
              const SizedBox(height: 16),
              const _HeroCard(),
              const SizedBox(height: 14),
              StepCard(
                step: 1,
                title: 'Testni tanlang',
                subtitle: "Musobaqa uchun fan va mavzu bo'yicha test tanlang",
                icon: Icons.menu_book_rounded,
                color: AppColors.brand,
                done: _step1Done,
                expanded: _open == 1,
                summary: _quiz?.title,
                onTap: () => setState(() => _open = 1),
                child: _QuizField(quiz: _quiz, onTap: _pickQuiz),
              ),
              const SizedBox(height: 12),
              StepCard(
                step: 2,
                title: 'Ishtirokchilar soni',
                subtitle: 'Nechta foydalanuvchi qatnashadi',
                icon: Icons.people_alt_rounded,
                color: AppColors.success,
                done: _step2Done,
                expanded: _open == 2,
                summary: _participants == null ? null : '$_participants kishi',
                onTap: () => setState(() => _open = 2),
                child: NumberStepper(
                  value: _participants ?? kDefaultParticipants,
                  min: kMinParticipants,
                  max: kMaxParticipants,
                  step: 1,
                  presets: kParticipantPresets,
                  unit: 'kishi',
                  color: AppColors.success,
                  helperText: 'Musobaqa yaratilgach taklif kodi generatsiya qilinadi',
                  onChanged: (value) => setState(() => _participants = value),
                ),
              ),
              const SizedBox(height: 12),
              StepCard(
                step: 3,
                title: 'Musobaqa vaqti',
                subtitle: 'Musobaqa davomiyligi',
                icon: Icons.schedule_rounded,
                color: AppColors.warning,
                done: _step3Done,
                expanded: _open == 3,
                summary: _minutes == null ? null : formatMinutes(_minutes!),
                onTap: () => setState(() => _open = 3),
                child: NumberStepper(
                  value: _minutes ?? kDefaultMinutes,
                  min: kMinMinutes,
                  max: kMaxMinutes,
                  step: 5,
                  presets: kDurationPresets,
                  unit: 'daqiqa',
                  color: AppColors.warning,
                  helperText: 'Vaqt tugagach musobaqa avtomatik yakunlanadi',
                  onChanged: (value) => setState(() => _minutes = value),
                ),
              ),
              const SizedBox(height: 14),
              _SummaryCard(
                quiz: _quiz,
                participants: _participants,
                minutes: _minutes,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                ErrorBanner(_error!),
              ],
              const SizedBox(height: 16),
              GradientButton(
                label: _creating ? 'Musobaqa yaratilmoqda...' : 'Musobaqani boshlash',
                icon: Icons.emoji_events_rounded,
                enabled: _canCreate,
                loading: _creating,
                height: 54,
                onPressed: _create,
              ),
              if (!_canCreate) ...[
                const SizedBox(height: 10),
                Text(
                  "Avval test tanlang",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Three connected step dots plus "N/3 bajarildi".
class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.done});

  final int done;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      children: [
        for (var i = 1; i <= 3; i++) ...[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: i <= done ? AppColors.brand : c.bgCard,
              shape: BoxShape.circle,
              border: Border.all(color: i <= done ? AppColors.brand : c.border),
            ),
            child: i <= done
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : Center(
                    child: Text(
                      '$i',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.textMuted,
                      ),
                    ),
                  ),
          ),
          if (i < 3)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: i < done ? AppColors.brand : c.border,
              ),
            ),
        ],
        const SizedBox(width: 12),
        Text(
          '$done/3 bajarildi',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textMuted),
        ),
      ],
    );
  }
}

/// Gradient intro card with the four feature pills from the web.
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  static const _features = [
    (Icons.bolt_rounded, 'Real-vaqt', Color(0xFFFBBF24)),
    (Icons.emoji_events_rounded, 'Reyting', Color(0xFFA78BFA)),
    (Icons.people_alt_rounded, "Ko'p o'yinchi", Color(0xFF38BDF8)),
    (Icons.track_changes_rounded, 'Raqobat', Color(0xFF22C55E)),
  ];

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
                child: const Icon(Icons.emoji_events_rounded, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Do'stlar bilan musobaqa!",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Real vaqt rejimida bellashing. Test tanlang, ishtirokchilar va vaqtni belgilang.',
                      style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFFCBD5E1)),
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
              for (final (icon, label, color) in _features)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: color),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tappable field that opens the quiz picker.
class _QuizField extends StatelessWidget {
  const _QuizField({required this.quiz, required this.onTap});

  final QuizSummary? quiz;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = quiz;

    return Material(
      color: c.bgInner,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected == null ? c.border : AppColors.brand),
          ),
          child: Row(
            children: [
              Icon(
                selected == null ? Icons.search_rounded : Icons.menu_book_rounded,
                size: 18,
                color: selected == null ? c.textMuted : AppColors.brand,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: selected == null
                    ? Text(
                        'Testni tanlang...',
                        style: TextStyle(fontSize: 14, color: c.textMuted),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected.title,
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
                            '${selected.subject ?? "Fan ko'rsatilmagan"} · ${selected.questionCount} ta savol',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.textSecondary),
                          ),
                        ],
                      ),
              ),
              Icon(Icons.expand_more_rounded, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Musobaqa xulosasi" — one row per step with its value and a short note.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.quiz, required this.participants, required this.minutes});

  final QuizSummary? quiz;
  final int? participants;
  final int? minutes;

  /// Wording the web uses under each summary value.
  static String _groupNote(int people) =>
      people <= 5 ? 'Kichik guruh' : (people <= 20 ? "O'rta guruh" : 'Katta guruh');

  static String _lengthNote(int value) =>
      value < 15 ? 'Qisqa musobaqa' : (value < 40 ? "O'rtacha musobaqa" : 'Uzoq musobaqa');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ready = quiz != null && participants != null && minutes != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ready ? c.accentBorder : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 16,
                color: ready ? AppColors.brandLight : c.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'Musobaqa xulosasi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ready ? c.textPrimary : c.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            icon: Icons.menu_book_rounded,
            label: 'Tanlangan test',
            value: quiz?.title ?? '—',
            note: quiz == null
                ? 'Test tanlanmagan'
                : '${quiz!.subject ?? "Fan ko'rsatilmagan"} · ${quiz!.questionCount} ta savol',
            color: quiz == null ? c.textMuted : AppColors.brand,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.people_alt_rounded,
            label: 'Ishtirokchilar',
            value: participants == null ? '—' : '$participants kishi',
            note: participants == null ? 'Belgilanmagan' : _groupNote(participants!),
            color: participants == null ? c.textMuted : AppColors.success,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.schedule_rounded,
            label: 'Davomiyligi',
            value: minutes == null ? '—' : formatMinutes(minutes!),
            note: minutes == null ? 'Belgilanmagan' : _lengthNote(minutes!),
            color: minutes == null ? c.textMuted : AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: c.textMuted)),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              Text(
                note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
