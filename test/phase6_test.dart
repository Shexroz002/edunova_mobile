import 'package:edunova_mobile/core/utils/difficulty.dart';
import 'package:edunova_mobile/features/question_edit/domain/question_patch.dart';
import 'package:edunova_mobile/features/quiz_create/domain/quiz_job.dart';
import 'package:edunova_mobile/features/tests/domain/quiz.dart';
import 'package:flutter_test/flutter_test.dart';

QuestionContent _question({
  String text = 'Savol matni',
  String? topic = 'Vieta teoremasi',
  Difficulty difficulty = Difficulty.medium,
  List<AnswerOption> options = const [],
}) {
  return QuestionContent(
    id: 1318,
    text: text,
    topic: topic,
    difficulty: difficulty,
    options: options,
  );
}

QuestionForm _form({
  String text = 'Savol matni',
  String topic = 'Vieta teoremasi',
  Difficulty difficulty = Difficulty.medium,
  int? correctOptionId,
}) {
  return QuestionForm(
    text: text,
    topic: topic,
    difficulty: difficulty,
    correctOptionId: correctOptionId,
  );
}

void main() {
  group('QuizJob', () {
    test('parses the POST body, which has no quiz id yet', () {
      final job = QuizJob.fromJson(const {
        'job_id': '29dc2bff-f36b-470f-8d0b-060dd86de80f',
        'status': 'queued',
        'progress': 0,
        'message': 'Fayl qabul qilindi',
        'task_id': 'ab92e354',
      });

      expect(job.id, '29dc2bff-f36b-470f-8d0b-060dd86de80f');
      expect(job.status, JobStatus.queued);
      expect(job.isFinal, isFalse);
      expect(job.isDone, isFalse);
      expect(job.quizId, isNull);
    });

    test('parses the completed socket frame', () {
      final job = QuizJob.fromJson(const {
        'type': 'completed',
        'job_id': '29dc2bff',
        'status': 'completed',
        'progress': 100,
        'message': 'Test tayyor bo‘ldi',
        'quiz_id': 80,
        'question_count': 30,
      });

      expect(job.status, JobStatus.completed);
      expect(job.isDone, isTrue);
      expect(job.quizId, 80);
      expect(job.questionCount, 30);
    });

    test('a failed job also reports 100% progress', () {
      final job = QuizJob.fromJson(const {
        'job_id': 'x',
        'status': 'failed',
        'progress': 100,
        'message': 'AI xizmatida xatolik yuz berdi.',
        'error': 'ServerError None: 503 UNAVAILABLE.',
      });

      expect(job.status, JobStatus.failed);
      expect(job.progress, 100);
      expect(job.isFinal, isTrue);
      // Progress alone must never be read as success.
      expect(job.isDone, isFalse);
    });

    test('an unknown status falls back to queued', () {
      expect(JobStatus.parse('something-new'), JobStatus.queued);
      expect(JobStatus.parse(null), JobStatus.queued);
      expect(JobStatus.parse('PROCESSING'), JobStatus.processing);
    });

    test('merging keeps fields the newer frame omits', () {
      final first = QuizJob.fromJson(const {
        'job_id': 'x',
        'status': 'processing',
        'progress': 66,
        'message': 'AI qayta urinmoqda (2/3)',
      });
      final second = QuizJob.fromJson(const {
        'job_id': 'x',
        'status': 'processing',
        'progress': 74,
      });

      final merged = first.mergedWith(second);
      expect(merged.progress, 74);
      expect(merged.message, 'AI qayta urinmoqda (2/3)');
    });
  });

  group('QuestionPatch.diff', () {
    test('sends nothing when nothing changed', () {
      expect(QuestionPatch.diff(before: _question(), after: _form()).isEmpty, isTrue);
    });

    test('sends only the changed field', () {
      final patch = QuestionPatch.diff(
        before: _question(),
        after: _form(text: 'Yangi matn'),
      );

      expect(patch.toJson(), {'question_text': 'Yangi matn'});
    });

    test('writes the difficulty spelling the backend stores', () {
      final patch = QuestionPatch.diff(
        before: _question(),
        after: _form(difficulty: Difficulty.hard),
      );

      expect(patch.toJson(), {'difficulty': 'qiyin'});
    });

    test('clearing the topic sends an empty string, not null', () {
      final patch = QuestionPatch.diff(before: _question(), after: _form(topic: ''));
      expect(patch.toJson(), {'topic': ''});
    });

    test('a question without a topic starts clean', () {
      final patch = QuestionPatch.diff(
        before: _question(topic: null),
        after: _form(topic: ''),
      );

      expect(patch.isEmpty, isTrue);
    });
  });

  group('QuestionForm', () {
    test('reads the correct option id from the loaded question', () {
      final form = QuestionForm.of(
        _question(
          options: const [
            AnswerOption(id: 5227, label: 'A', text: 'x', isCorrect: false),
            AnswerOption(id: 5228, label: 'B', text: 'y', isCorrect: true),
          ],
        ),
      );

      expect(form.correctOptionId, 5228);
    });

    test('leaves the correct option unknown when options carry no ids', () {
      final form = QuestionForm.of(
        _question(options: const [AnswerOption(label: 'A', text: 'x', isCorrect: true)]),
      );

      expect(form.correctOptionId, isNull);
    });

    test('refuses an empty question text', () {
      expect(_form(text: '   ').validate(), isNotNull);
      expect(_form().validate(), isNull);
    });
  });

  group('Difficulty', () {
    test('round-trips the spellings the generator writes', () {
      for (final level in Difficulty.editable) {
        expect(Difficulty.parse(level.apiValue), level);
      }
    });

    test('unknown is written back as the medium value', () {
      expect(Difficulty.unknown.apiValue, "o'rta");
    });
  });

  group('QuestionImage', () {
    test('keeps the id the delete endpoint needs', () {
      final question = QuestionContent.fromJson(const {
        'id': 1,
        'question_text': 'x',
        'images': [
          {'id': 7, 'image_url': '/media/image/1/a.png'},
          {'id': 8, 'image_url': null},
        ],
        'options': [],
      });

      expect(question.images, hasLength(1));
      expect(question.images.single.id, 7);
      expect(question.imageUrls.single, endsWith('/media/image/1/a.png'));
    });
  });

  test('CreateLimits match what the backend enforces', () {
    // settings.MAX_PDF_SIZE, not the web's "Maksimal: 10 MB".
    expect(CreateLimits.maxPdfBytes, 5 * 1024 * 1024);
    expect(CreateLimits.defaultQuestions, inInclusiveRange(
      CreateLimits.minQuestions,
      CreateLimits.maxQuestions,
    ));
  });
}
