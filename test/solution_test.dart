import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:edunova_mobile/core/theme/app_colors.dart';
import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/solution/data/solution_repository.dart';
import 'package:edunova_mobile/features/solution/domain/solution_models.dart';
import 'package:edunova_mobile/features/solution/presentation/mistake_sheet.dart';
import 'package:edunova_mobile/features/solution/presentation/question_solution_screen.dart';
import 'package:edunova_mobile/features/solution/presentation/solution_controllers.dart';
import 'package:edunova_mobile/features/solution/presentation/solution_view.dart';
import 'package:edunova_mobile/features/solution/presentation/solve_request_screen.dart';
import 'package:edunova_mobile/features/solution/presentation/widgets/board.dart';
import 'package:edunova_mobile/features/solution/presentation/widgets/dispute_card.dart';
import 'package:edunova_mobile/features/solution/presentation/widgets/done_row.dart';
import 'package:edunova_mobile/features/solution/presentation/widgets/solution_tex.dart';
import 'package:edunova_mobile/features/solution/presentation/widgets/waiting_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real replies from the solution model, captured on 2026-10-05.
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/solution/$name.json').readAsStringSync()) as Map<String, dynamic>;

class _FakeRepo implements SolutionRepository {
  _FakeRepo({this.explanationReply, this.requestReply});

  final Map<String, dynamic>? explanationReply;
  final Map<String, dynamic>? requestReply;
  int retries = 0;

  @override
  Future<ExplanationResult> explanation(int questionId, {String? chosen}) async =>
      ExplanationResult.fromJson(explanationReply);

  @override
  Future<SolveRequestItem> request(int id) async => SolveRequestItem.fromJson(requestReply);

  @override
  Future<SolveRequestItem> retry(int id) async {
    retries++;
    return SolveRequestItem.fromJson({...?requestReply, 'status': 'pending'});
  }

  @override
  Future<void> feedback({int? explanationId, int? solveRequestId, required String verdict}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Future<void> _pump(WidgetTester tester, Widget child, {ThemeData? theme, _FakeRepo? repo}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [if (repo != null) solutionRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: theme ?? AppTheme.dark(), home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('parsing real model output', () {
    test('a bank explanation keeps its steps, values and hint', () {
      final result = ExplanationResult.fromJson(fixture('explanation_ready'));
      expect(result.status, ExplanationStatus.ready);
      expect(result.correctOption, 'B');
      expect(result.questionText, contains('5-hadi 15'));
      final solution = result.solution!;
      expect(solution.steps, hasLength(4));
      expect(solution.plan, hasLength(solution.steps.length));
      expect(solution.values.map((v) => v.color), [1, 2]);
      expect(solution.answer.words, 'uch');
      expect(result.hint, isNotNull, reason: 'the student picked A, a wrong option');
    });

    test('a physics solution has its given values, units and formula card', () {
      final item = SolveRequestItem.fromJson(fixture('solve_physics'));
      final solution = item.solution!;
      expect(solution.isPhysics, isTrue);
      expect(solution.given.map((g) => '${g.symbol}=${g.value} ${g.unit}'), ['m=2 kg', 'a=5 m/s²']);
      expect(solution.formula!.legend, hasLength(3));
      expect(solution.realLife, isNotNull);
    });

    test('a word problem carries a bar of parts', () {
      final solution = SolveRequestItem.fromJson(fixture('solve_word')).solution!;
      expect(solution.kind, SolutionKind.word);
      expect(solution.tape!.parts, hasLength(3));
      expect(solution.answer.tex, r'35 \text{ kg}');
    });

    test('a dispute says which option the solutions agreed on', () {
      final result = ExplanationResult.fromJson(fixture('explanation_disputed'));
      expect(result.status, ExplanationStatus.disputed);
      expect(result.modelOption, 'A');
      expect(result.correctOption, 'D');
      expect(result.studentMayBeRight, isTrue);
    });

    test('a ready reply without steps is treated as unavailable', () {
      final result = ExplanationResult.fromJson({'status': 'ready', 'solution': {'steps': []}});
      expect(result.status, ExplanationStatus.unavailable);
    });

    test('a failed request says whether asking again can help', () {
      final failed = SolveRequestItem.fromJson(fixture('solve_failed'));
      expect(failed.status, SolveStatus.failed);
      expect(failed.retryable, isTrue, reason: 'it failed on a model quota, not on the problem');
    });
  });

  group('formulas written without dollars', () {
    testWidgets('a collapsed step draws its formula, not its source', (tester) async {
      // Seen on the device: "\angle ACB = 68^\circ" as plain text.
      const step = SolutionStep(
        title: 'Burchakni topamiz',
        say: 'Yig‘indidan ayiramiz.',
        board: [BoardLine(tex: r'\angle ACB = 68^\circ', role: BoardRole.result)],
        summary: r'\angle ACB = 68^\circ',
        simpler: ['180 dan ayiramiz.'],
      );
      await _pump(tester, const DoneRow(number: 3, step: step));
      expect(find.byType(Math), findsOneWidget);
      expect(find.textContaining(r'\angle', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a step title with maths draws it', (tester) async {
      final solution = Solution.fromJson({
        'kind': 'math',
        'plan': ['bitta'],
        'steps': [
          {
            'title': r'$x$ ni topamiz',
            'say': r'Ikkala tomonni $2$ ga bo‘lamiz.',
            'board': [{'tex': 'x = 3', 'role': 'result'}],
            'summary': r'$x = 3$',
            'simpler': ['Bo‘lamiz.'],
          },
        ],
        'answer': {'tex': 'x = 3', 'words': 'uch'},
      })!;
      await _pump(tester, SolutionView(solution: solution));
      await tester.tap(find.text('Boshladik'));
      await tester.pumpAndSettle();
      expect(find.textContaining(r'$x$', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('numbers on the board', () {
    test('a decimal comma is braced, so LaTeX does not read it as "1, 5"', () {
      expect(texNumber('1,5'), '1{,}5');
      expect(texNumber('0,625'), '0{,}625');
      expect(texNumber('175'), '175');
      expect(texNumber('a, b'), 'a, b', reason: 'only a comma between digits is a decimal one');
    });
  });

  group('colour marks', () {
    testWidgets('are painted from the theme, so dark and light differ', (tester) async {
      String? dark, light;
      await _pump(tester, Builder(builder: (c) {
        dark = paintTex(c, r'\hla{2} + \hlb{3} = \hlc{5}');
        return const SizedBox();
      }));
      await _pump(tester, Builder(builder: (c) {
        light = paintTex(c, r'\hla{2} + \hlb{3} = \hlc{5}');
        return const SizedBox();
      }), theme: AppTheme.light());
      // MaterialApp animates a theme change; read the colour once it has landed.
      await tester.pumpAndSettle();
      expect(dark, r'\textcolor{#38BDF8}{2} + \textcolor{#C4B5FD}{3} = \textcolor{#F472B6}{5}');
      expect(light, r'\textcolor{#0369A1}{2} + \textcolor{#7C3AED}{3} = \textcolor{#BE185D}{5}');
    });

    test('stay readable as text on cards and on the board in both themes', () {
      // The first light picks (0284C7, DB2777) failed this; it is kept as a test.
      for (final (dark, colors) in [(true, AppColors.dark), (false, AppColors.light)]) {
        for (final i in [1, 2, 3]) {
          final value = AppColors.mathValue(i, dark: dark);
          expect(_contrast(value, colors.bgCard), greaterThanOrEqualTo(4.5), reason: 'colour $i on card, dark=$dark');
          expect(_contrast(value, colors.bgInner), greaterThanOrEqualTo(4.5), reason: 'colour $i on board, dark=$dark');
        }
      }
    });

    testWidgets('every board line of the captured solutions parses as maths', (tester) async {
      // Guards the escape bug: a mark that reached the screen as text would
      // show its own source.
      final lines = [
        for (final name in ['solve_physics', 'solve_word'])
          ...SolveRequestItem.fromJson(fixture(name)).solution!.steps.expand((s) => s.board),
        ...ExplanationResult.fromJson(fixture('explanation_ready')).solution!.steps.expand((s) => s.board),
      ];
      await _pump(tester, SingleChildScrollView(child: SolutionBoard(lines: lines)));
      expect(find.byType(Math), findsNWidgets(lines.length));
      expect(find.textContaining(r'\hl'), findsNothing);
      expect(find.textContaining(r'\text'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('SolutionView', () {
    Solution word() => SolveRequestItem.fromJson(fixture('solve_word')).solution!;

    testWidgets('starts with the question in plain words and the plan, before any step', (tester) async {
      final solution = word();
      await _pump(tester, SolutionView(solution: solution, problem: 'Do‘kon 3 kunda 175 kg sotdi.'));
      expect(find.text('🎯 Bizdan nima so‘ralyapti?'), findsOneWidget);
      expect(find.text('🗺 Reja — ${solution.plan.length} qadam'), findsOneWidget);
      expect(find.text('Boshladik'), findsOneWidget);
      expect(find.text('🤔 Tushunmadim'), findsNothing);
    });

    testWidgets('teaches one step at a time and folds the finished ones', (tester) async {
      final solution = word();
      await _pump(tester, SolutionView(solution: solution));
      await tester.tap(find.text('Boshladik'));
      await tester.pumpAndSettle();
      expect(find.text(solution.steps[0].title), findsWidgets);
      expect(find.textContaining('1-qadam', findRichText: true), findsOneWidget);

      await tester.tap(find.text('Keyingisi'));
      await tester.pumpAndSettle();
      expect(find.text(solution.steps[1].title), findsWidgets);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget, reason: 'step 1 folded to one green line');
    });

    testWidgets('"Tushunmadim" opens the simpler explanation and changes the button', (tester) async {
      await _pump(tester, SolutionView(solution: word()));
      await tester.tap(find.text('Boshladik'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🤔 Tushunmadim'));
      await tester.pumpAndSettle();
      expect(find.text('💬 SODDAROQ TUSHUNTIRAMAN'), findsOneWidget);
      expect(find.text('Tushundim, keyingisi'), findsOneWidget);
      expect(find.text('🤔 Tushunmadim'), findsNothing);
    });

    testWidgets('ends on the answer, read aloud, with the option it is', (tester) async {
      final solution = ExplanationResult.fromJson(fixture('explanation_ready')).solution!;
      await _pump(tester, SolutionView(solution: solution, option: 'B'));
      await tester.tap(find.text('Boshladik'));
      await tester.pumpAndSettle();
      for (var i = 0; i < solution.steps.length; i++) {
        await tester.tap(find.text(i == solution.steps.length - 1 ? 'Javob' : 'Keyingisi'));
        await tester.pumpAndSettle();
      }
      expect(find.text('🎉 JAVOB'), findsOneWidget);
      expect(find.textContaining('uch'), findsWidgets);
      expect(find.text('B variant'), findsOneWidget);
      expect(find.textContaining('Tayyor!', findRichText: true), findsOneWidget);
    });

    testWidgets('draws a physics solution in light mode too', (tester) async {
      final solution = SolveRequestItem.fromJson(fixture('solve_physics')).solution!;
      await _pump(tester, SolutionView(solution: solution), theme: AppTheme.light());
      expect(find.text('BERILGAN'), findsOneWidget);
      expect(find.text('TOPISH KERAK'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('QuestionSolutionScreen', () {
    testWidgets('a dispute tells the student they may have been right', (tester) async {
      await _pump(
        tester,
        const QuestionSolutionScreen(questionId: 675, chosen: 'A'),
        repo: _FakeRepo(explanationReply: fixture('explanation_disputed')),
      );
      await tester.pump();
      expect(find.byType(DisputeCard), findsOneWidget);
      expect(find.text('Siz haq bo‘lishingiz mumkin'), findsOneWidget);
      expect(find.text('Yechim: A'), findsOneWidget);
      expect(find.text('Kalit: D'), findsOneWidget);
    });

    testWidgets('waits honestly while the solution is being written', (tester) async {
      await _pump(
        tester,
        const QuestionSolutionScreen(questionId: 1),
        repo: _FakeRepo(explanationReply: {'status': 'pending'}),
      );
      await tester.pump();
      expect(find.byType(WaitingView), findsOneWidget);
      expect(find.textContaining('20–40 soniya'), findsOneWidget);
      // Leave no poll timer running past the test.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows the reason when there will be no solution', (tester) async {
      await _pump(
        tester,
        const QuestionSolutionScreen(questionId: 41),
        repo: _FakeRepo(explanationReply: {'status': 'unavailable', 'message': 'Kalit aniq emas.'}),
      );
      await tester.pump();
      expect(find.text('Kalit aniq emas.'), findsOneWidget);
    });
  });

  group('polling', () {
    test('outlasts the server\'s four minutes before a lost task is queued again', () {
      expect(solutionPollFor, greaterThan(const Duration(minutes: 4)));
    });

    testWidgets('gives up into the "taking too long" view, not an endless spinner', (tester) async {
      await _pump(
        tester,
        const SolveRequestScreen(requestId: 7),
        repo: _FakeRepo(requestReply: {'id': 7, 'status': 'pending', 'subject': 'matematika', 'text': 'x'}),
      );
      await tester.pump();
      expect(find.text('Yechim kechikyapti'), findsNothing);
      // Five minutes of three-second polls.
      for (var i = 0; i < 101; i++) {
        await tester.pump(solutionPollEvery);
      }
      expect(find.text('Yechim kechikyapti'), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('MistakeSheet', () {
    testWidgets('puts the right line next to the likely wrong one', (tester) async {
      await _pump(
        tester,
        const MistakeSheet(questionId: 677, chosen: 'A'),
        repo: _FakeRepo(explanationReply: fixture('explanation_ready')),
      );
      await tester.pump();
      expect(find.text('Qayerda adashdingiz?'), findsOneWidget);
      expect(find.text('To‘g‘ri'), findsOneWidget);
      expect(find.text('Siz'), findsOneWidget);
      expect(find.text('Bu xato ko‘pincha shu sababdan chiqadi'), findsOneWidget);
      expect(find.text('To‘liq yechimni ko‘rish'), findsOneWidget);
    });
  });

  group('SolveRequestScreen', () {
    testWidgets('shows the server\'s reason, so a spent daily quota is not called a moment\'s wait', (tester) async {
      await _pump(
        tester,
        const SolveRequestScreen(requestId: 7),
        repo: _FakeRepo(requestReply: {
          'id': 7,
          'status': 'failed',
          'subject': 'matematika',
          'text': 'x = ?',
          'message': 'Bugun masala yechish xizmatining kunlik limiti tugadi. Ertaga qayta urinib ko‘ring.',
          'retryable': true,
        }),
      );
      await tester.pump();
      expect(find.textContaining('kunlik limiti tugadi'), findsOneWidget);
      expect(find.textContaining('limitingizdan olinmaydi'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a busy model offers a free retry', (tester) async {
      final repo = _FakeRepo(requestReply: fixture('solve_failed'));
      await _pump(tester, const SolveRequestScreen(requestId: 5), repo: repo);
      await tester.pump();
      expect(find.textContaining('Qayta urinish limitingizdan olinmaydi.'), findsOneWidget);
      await tester.tap(find.text('Qayta urinish'));
      await tester.pump();
      expect(repo.retries, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an incomplete problem says what is missing', (tester) async {
      await _pump(
        tester,
        const SolveRequestScreen(requestId: 9),
        repo: _FakeRepo(requestReply: {
          'id': 9,
          'status': 'failed',
          'subject': 'fizika',
          'text': 'Kuchni toping.',
          'message': 'Massa berilmagan.',
          'retryable': false,
        }),
      );
      await tester.pump();
      expect(find.text('Masalada nimadir yetishmayapti'), findsOneWidget);
      expect(find.text('Massa berilmagan.'), findsOneWidget);
      expect(find.text('Yangi masala'), findsOneWidget);
    });
  });
}
