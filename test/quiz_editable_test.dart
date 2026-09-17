import 'package:edunova_mobile/core/utils/difficulty.dart';
import 'package:edunova_mobile/features/tests/domain/quiz.dart';
import 'package:edunova_mobile/features/tests/presentation/quiz_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `is_update` decides whether the editor is offered.
///
/// The quiz list mixes the student's own quizzes with the shared catalogue.
/// Catalogue rows have no owner, and both the quiz `PUT` and the question
/// editor are owner-scoped, so an edit offered on one of them can only 404.
void main() {
  group('parsing', () {
    test('an own quiz comes back editable', () {
      final quiz = QuizSummary.fromJson(const {
        'quiz_id': 127,
        'title': 'Eritmalar haqida Test',
        'subject': 'Kimyo',
        'question_count': 10,
        'is_new': false,
        'is_update': true,
        'quiz_generate_type': 'AI_GENERATE',
        'created_at': '2026-09-15T17:20:51.099447Z',
      });

      expect(quiz.canEdit, isTrue);
    });

    test('a catalogue quiz does not', () {
      final quiz = QuizSummary.fromJson(const {
        'quiz_id': 106,
        'title': 'Matematika: murakkab savollar testi',
        'question_count': 30,
        'is_update': false,
        'quiz_generate_type': 'MANUAL',
      });

      expect(quiz.canEdit, isFalse);
    });

    test('a missing flag is treated as not editable', () {
      // An older server, or a response that simply omits it: the safe answer is
      // to hide the editor rather than offer one that fails.
      final quiz = QuizSummary.fromJson(const {
        'quiz_id': 5,
        'title': 'Test',
        'quiz_generate_type': 'MANUAL',
      });

      expect(quiz.canEdit, isFalse);
    });

    test('the detail response carries the same flag', () {
      final own = QuizDetail.fromJson(const {
        'id': 127,
        'title': 'Eritmalar haqida Test',
        'quiz_generate_type': 'AI_GENERATE',
        'is_update': true,
        'questions': <dynamic>[],
      });
      final catalogue = QuizDetail.fromJson(const {
        'id': 106,
        'title': 'Matematika',
        'quiz_generate_type': 'MANUAL',
        'is_update': false,
        'questions': <dynamic>[],
      });

      expect(own.canEdit, isTrue);
      expect(catalogue.canEdit, isFalse);
      // Screens that take a summary must not lose it on the way.
      expect(own.asSummary.canEdit, isTrue);
      expect(catalogue.asSummary.canEdit, isFalse);
    });
  });

  group('the edit action', () {
    QuizDetail quiz({required bool canEdit}) => QuizDetail(
          id: 1,
          title: 'Test',
          source: QuizSource.manual,
          canEdit: canEdit,
          questions: const [
            QuizQuestionBrief(id: 11, text: '2 + 2 = ?', difficulty: Difficulty.easy),
          ],
        );

    Future<void> openPreview(WidgetTester tester, {required bool canEdit}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quizDetailProvider(1).overrideWith((ref) async => quiz(canEdit: canEdit)),
            questionPreviewProvider(11).overrideWith(
              (ref) async => const QuestionContent(
                id: 11,
                text: '2 + 2 = ?',
                difficulty: Difficulty.easy,
                options: [
                  AnswerOption(label: 'A', text: '4', isCorrect: true),
                  AnswerOption(label: 'B', text: '5'),
                ],
              ),
            ),
          ],
          child: const MaterialApp(home: QuizDetailScreen(quizId: 1)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('2 + 2 = ?').first);
      await tester.pumpAndSettle();
    }

    testWidgets('is offered on the student\'s own quiz', (tester) async {
      await openPreview(tester, canEdit: true);
      expect(find.text('Tahrirlash'), findsOneWidget);
    });

    testWidgets('is hidden on a catalogue quiz', (tester) async {
      await openPreview(tester, canEdit: false);
      expect(find.text('Tahrirlash'), findsNothing);
    });
  });
}
