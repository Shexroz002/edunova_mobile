import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/hint_pill.dart';
import '../domain/job_stage.dart';
import '../domain/quiz_job.dart';
import 'job_controller.dart';
import 'widgets/progress_ring.dart';
import 'widgets/source_card.dart';
import 'widgets/stage_list.dart';

/// Live progress of a generation job.
///
/// The screen is built around the four [JobStage]s rather than the raw
/// percentage: the backend moves in jumps of up to forty seconds, so a bare
/// number reads as a freeze. Its `message` is never rendered, because the text
/// names the AI provider.
class JobProgressView extends ConsumerStatefulWidget {
  const JobProgressView({
    super.key,
    required this.started,
    required this.method,
    required this.source,
    required this.onDone,
    required this.onRetry,
    required this.onChangeMethod,
  });

  /// The job as the `POST` returned it; the controller takes it from there.
  final QuizJob started;
  final CreateMethod method;
  final JobSource source;

  /// Called with the finished quiz id.
  final void Function(int quizId) onDone;
  final VoidCallback onRetry;

  /// Back to step 1, so a failed PDF can be retried as an AI request.
  final VoidCallback onChangeMethod;

  @override
  ConsumerState<JobProgressView> createState() => _JobProgressViewState();
}

class _JobProgressViewState extends ConsumerState<JobProgressView> {
  /// How long the finished card stays up before the quiz opens. Long enough to
  /// read the question count, short enough not to feel like a wall.
  static const _successDelay = Duration(seconds: 2);

  /// After this the wait is called out as slower than usual, rather than
  /// leaving the student guessing.
  static const _slowAfter = Duration(seconds: 90);

  final _startedAt = DateTime.now();
  Timer? _ticker;
  Timer? _open;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _open?.cancel();
    super.dispose();
  }

  Duration get _elapsed => DateTime.now().difference(_startedAt);

  /// `48 soniya` / `1 daqiqa 20 soniya`.
  String get _elapsedText {
    final seconds = _elapsed.inSeconds;
    if (seconds < 60) return '$seconds soniya';
    final rest = seconds % 60;
    final minutes = seconds ~/ 60;
    return rest == 0 ? '$minutes daqiqa' : '$minutes daqiqa $rest soniya';
  }

  /// The worker writes "AI qayta urinmoqda (2/3)" while it retries. The text
  /// itself is not shown — only the fact that a retry is running.
  bool _isRetrying(QuizJob job) =>
      (job.message ?? '').toLowerCase().contains('qayta urin');

  void _finish(int quizId) {
    if (_finished) return;
    setState(() => _finished = true);
    _ticker?.cancel();
    _open = Timer(_successDelay, () {
      if (mounted) widget.onDone(quizId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobControllerProvider(widget.started));
    final job = state.job;

    // Checked here rather than in a listener: a job that is already finished
    // when the view mounts never fires one, and the screen would sit at 100 %.
    if (job.isDone && !_finished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finish(job.quizId!);
      });
    }

    if (job.status == JobStatus.failed || state.timedOut) {
      return _Failure(
        method: widget.method,
        source: widget.source,
        timedOut: state.timedOut,
        onRetry: widget.onRetry,
        onChangeMethod: widget.onChangeMethod,
      );
    }

    if (_finished) {
      return _Success(
        method: widget.method,
        source: widget.source,
        questionCount: job.questionCount,
        elapsed: _elapsedText,
        onOpen: () => widget.onDone(job.quizId!),
      );
    }

    final retrying = _isRetrying(job);
    final slow = retrying || _elapsed > _slowAfter;
    final stage = JobStage.of(job.progress);
    final tone = context.readable(slow ? AppColors.warning : AppColors.sky);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Head(
                percent: job.progress,
                tone: tone,
                // The heading names the job, not the stage, so it stays put
                // while the checklist below ticks along.
                title: widget.method == CreateMethod.pdf
                    ? 'PDF testga aylantirilmoqda'
                    : 'AI test yaratilmoqda',
                headline: stage.headline(widget.method),
                caption: slow
                    ? '$_elapsedText · odatdagidan uzoqroq'
                    : '$_elapsedText · odatda 1–2 daqiqa',
                center: _Percent(percent: job.progress, stage: stage, tone: tone),
              ),
              const _Divider(),
              StageList(
                method: widget.method,
                current: stage,
                note: retrying ? 'Qayta urinilmoqda' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SourceCard(source: widget.source, tone: slow ? AppColors.warning : AppColors.sky),
        const SizedBox(height: 12),
        HintPill(
          text: slow
              ? 'Katta fayllar va uzun mavzular uzoqroq ishlanadi. Jarayon davom '
                  'etmoqda — ilovani yopmang.'
              : 'Test tayyor bo‘lgach shu yerda ochiladi. Ilovani yopmang.',
          tone: slow ? AppColors.warning : null,
        ),
      ],
    );
  }
}

/// Ring, stage title and the elapsed-time caption.
class _Head extends StatelessWidget {
  const _Head({
    required this.percent,
    required this.tone,
    required this.title,
    required this.headline,
    required this.caption,
    required this.center,
    this.spinning = true,
  });

  final int percent;
  final Color tone;
  final String title;
  final String headline;
  final String caption;
  final Widget center;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      children: [
        ProgressRing(
          percent: percent,
          color: tone,
          trackColor: c.bgInner,
          spinning: spinning,
          child: center,
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.textPrimary),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            headline,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_rounded, size: 14, color: c.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                caption,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "62%" over "3 / 4-bosqich".
class _Percent extends StatelessWidget {
  const _Percent({required this.percent, required this.stage, required this.tone});

  final int percent;
  final JobStage stage;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$percent%',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1, color: tone),
        ),
        const SizedBox(height: 3),
        Text(
          '${stage.step} / ${JobStage.count}-bosqich',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textMuted),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 22, 0, 20),
        child: Container(height: 1, color: context.colors.border),
      );
}

/// The finished job, held on screen just long enough to read.
class _Success extends StatelessWidget {
  const _Success({
    required this.method,
    required this.source,
    required this.questionCount,
    required this.elapsed,
    required this.onOpen,
  });

  final CreateMethod method;
  final JobSource source;
  final int? questionCount;
  final String elapsed;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final emerald = context.readable(AppColors.emerald);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Head(
                percent: 100,
                tone: emerald,
                spinning: false,
                title: 'Test tayyor bo‘ldi',
                headline: questionCount == null
                    ? 'Savollar yaratildi va testlaringizga saqlandi'
                    : '$questionCount ta savol yaratildi va testlaringizga saqlandi',
                caption: '$elapsed ichida tayyorlandi',
                center: Icon(Icons.check_rounded, size: 46, color: emerald),
              ),
              const _Divider(),
              StageList(method: method, current: JobStage.save, finished: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SourceCard(source: source, tone: AppColors.emerald),
        const SizedBox(height: 20),
        GradientButton(
          label: 'Testni ochish',
          icon: Icons.arrow_forward_rounded,
          onPressed: onOpen,
        ),
        const SizedBox(height: 10),
        Text(
          'Bir necha soniyadan so‘ng o‘zi ochiladi',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
      ],
    );
  }
}

/// Failure card: what went wrong, what to do about it, and two ways out.
class _Failure extends StatelessWidget {
  const _Failure({
    required this.method,
    required this.source,
    required this.timedOut,
    required this.onRetry,
    required this.onChangeMethod,
  });

  final CreateMethod method;
  final JobSource source;
  final bool timedOut;
  final VoidCallback onRetry;
  final VoidCallback onChangeMethod;

  /// The job's own `error` quotes the AI provider in English, so the reason is
  /// written here instead (`docs/BACKEND_ISSUES.md`).
  String get _reason => timedOut
      ? 'Jarayon juda uzoq davom etdi va to‘xtatildi. Xizmat band bo‘lishi mumkin.'
      : 'AI so‘rovni testga aylantira olmadi. Manba mos kelmasligi yoki xizmat '
          'band bo‘lishi mumkin.';


  /// Concrete next steps, which differ by method: a PDF usually fails because
  /// of the file, an AI request because of the wording.
  List<String> get _tips => method == CreateMethod.pdf
      ? const [
          'PDF ichida tanlanadigan matn bo‘lsin — faqat rasmdan iborat fayl o‘qilmaydi.',
          'Fayl hajmi 5 MB dan oshmasin.',
        ]
      : const [
          'Mavzuni aniqroq yozing: fan, bo‘lim va qamrab olinadigan savollar.',
          'Savollar sonini kamaytirib ko‘ring.',
        ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final error = context.readable(AppColors.error);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.tint(error, 0x21),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.tint(error, 0x59)),
                  ),
                  child: Icon(Icons.error_outline_rounded, size: 30, color: error),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Test yaratilmadi',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 290),
                  child: Text(
                    _reason,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                decoration: BoxDecoration(
                  color: c.bgInner,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NIMA QILISH MUMKIN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: c.textPrimary,
                      ),
                    ),
                    for (final tip in _tips) ...[
                      const SizedBox(height: 9),
                      _Tip(text: tip),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SourceCard(source: source, tone: AppColors.error),
        const SizedBox(height: 20),
        GradientButton(
          label: 'Qayta urinish',
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onChangeMethod,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.swap_vert_rounded, size: 19),
          label: const Text('Boshqa usulni tanlash'),
        ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(color: c.textMuted, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, height: 1.5, color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}
