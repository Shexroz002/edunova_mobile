import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/quiz_create/domain/job_stage.dart';
import 'package:edunova_mobile/features/quiz_create/domain/quiz_job.dart';
import 'package:edunova_mobile/features/quiz_create/presentation/job_controller.dart';
import 'package:edunova_mobile/features/quiz_create/presentation/job_progress_view.dart';
import 'package:edunova_mobile/features/quiz_create/presentation/widgets/source_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns the job state without touching the socket or the poll timer.
class _FrozenJobController extends JobController {
  _FrozenJobController(this.frozen);

  final JobState frozen;

  @override
  JobState build(QuizJob arg) => frozen;
}

QuizJob _job({
  required int progress,
  JobStatus status = JobStatus.processing,
  String? message,
}) {
  return QuizJob(id: 'job-1', status: status, progress: progress, message: message);
}

const _source = JobSource(
  icon: Icons.picture_as_pdf_rounded,
  title: 'fizika_8_sinf.pdf',
  meta: '1.40 MB · PDF fayldan',
);

Future<void> _pumpProgress(
  WidgetTester tester, {
  required QuizJob job,
  CreateMethod method = CreateMethod.pdf,
  bool timedOut = false,
  ThemeData? theme,
  void Function(int quizId)? onDone,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        jobControllerProvider.overrideWith(
          () => _FrozenJobController(JobState(job: job, timedOut: timedOut)),
        ),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: JobProgressView(
              started: job,
              method: method,
              source: _source,
              onDone: onDone ?? (_) {},
              onRetry: () {},
              onChangeMethod: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('JobStage.of', () {
    test('maps the progress values the PDF worker really reports', () {
      // app/services/pdf/tasks/quiz_tasks.py and the Mistral provider.
      expect(JobStage.of(10), JobStage.prepare);
      expect(JobStage.of(15), JobStage.send);
      expect(JobStage.of(30), JobStage.send);
      expect(JobStage.of(50), JobStage.generate);
      expect(JobStage.of(80), JobStage.generate);
      expect(JobStage.of(85), JobStage.save);
      expect(JobStage.of(100), JobStage.save);
    });

    test('maps the progress values the AI worker really reports', () {
      expect(JobStage.of(10), JobStage.prepare);
      expect(JobStage.of(50), JobStage.generate);
      expect(JobStage.of(75), JobStage.generate);
      expect(JobStage.of(85), JobStage.save);
    });

    test('covers the retry percentages as generation, not saving', () {
      for (final progress in [58, 66, 75]) {
        expect(JobStage.of(progress), JobStage.generate);
      }
    });

    test('numbers the stages from one', () {
      expect(JobStage.prepare.step, 1);
      expect(JobStage.save.step, JobStage.count);
    });

    test('names the first two stages differently per method', () {
      expect(JobStage.prepare.labels(CreateMethod.pdf).done, 'Fayl tekshirildi');
      expect(JobStage.prepare.labels(CreateMethod.ai).done, 'So‘rov tayyorlandi');
      expect(
        JobStage.generate.labels(CreateMethod.pdf).active,
        JobStage.generate.labels(CreateMethod.ai).active,
      );
    });
  });

  group('JobProgressView', () {
    testWidgets('never shows the backend message, which names the AI provider',
        (tester) async {
      // The worker writes this text verbatim; rendering it leaked "Mistral"
      // onto the student's screen.
      await _pumpProgress(
        tester,
        job: _job(progress: 30, message: 'PDF Mistral serveriga yuklanmoqda'),
      );

      expect(find.textContaining('Mistral'), findsNothing);
      expect(find.textContaining('serveriga'), findsNothing);
      expect(find.text('PDF testga aylantirilmoqda'), findsOneWidget);
      expect(find.text('Fayl yuborilmoqda'), findsOneWidget);
    });

    testWidgets('shows the stage before it as done and the one after as pending',
        (tester) async {
      await _pumpProgress(tester, job: _job(progress: 50));

      expect(find.text('Fayl tekshirildi'), findsOneWidget);
      expect(find.text('Fayl yuborildi'), findsOneWidget);
      expect(find.text('Savollar yaratilmoqda'), findsOneWidget);
      expect(find.text('Testga saqlash'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('3 / 4-bosqich'), findsOneWidget);
    });

    testWidgets('calls the retry out without quoting the worker', (tester) async {
      await _pumpProgress(
        tester,
        job: _job(progress: 58, message: 'AI qayta urinmoqda (2/3)'),
      );

      expect(find.text('Qayta urinilmoqda'), findsOneWidget);
      expect(find.textContaining('(2/3)'), findsNothing);
    });

    testWidgets('a timed-out job offers a retry and a way back to step 1',
        (tester) async {
      await _pumpProgress(tester, job: _job(progress: 50), timedOut: true);

      expect(find.text('Test yaratilmadi'), findsOneWidget);
      expect(find.text('NIMA QILISH MUMKIN'), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
      expect(find.text('Boshqa usulni tanlash'), findsOneWidget);
    });

    testWidgets('the failure advice follows the method', (tester) async {
      await _pumpProgress(
        tester,
        job: _job(progress: 100, status: JobStatus.failed),
        method: CreateMethod.ai,
      );

      expect(find.textContaining('PDF ichida'), findsNothing);
      expect(find.textContaining('Mavzuni aniqroq yozing'), findsOneWidget);
    });

    testWidgets('a finished job shows the result before opening it',
        (tester) async {
      // The finish used to be caught by a listener, which never fires for a job
      // that is already complete when the view mounts.
      var opened = 0;
      await _pumpProgress(
        tester,
        job: const QuizJob(
          id: 'job-1',
          status: JobStatus.completed,
          progress: 100,
          quizId: 481,
          questionCount: 5,
          message: 'Test tayyor bo‘ldi',
        ),
        onDone: (quizId) => opened = quizId,
      );
      await tester.pump();

      expect(find.text('Test tayyor bo‘ldi'), findsOneWidget);
      expect(find.textContaining('5 ta savol yaratildi'), findsOneWidget);
      expect(find.text('Testni ochish'), findsOneWidget);
      expect(find.text('Testga saqlandi'), findsOneWidget);
      expect(opened, 0, reason: 'the card is held on screen for a moment');

      await tester.pump(const Duration(seconds: 3));
      expect(opened, 481);
    });

    testWidgets('renders in light mode too', (tester) async {
      await _pumpProgress(
        tester,
        job: _job(progress: 85),
        theme: AppTheme.light(),
      );

      expect(find.text('Testga saqlanmoqda'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
