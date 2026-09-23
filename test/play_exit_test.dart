import 'package:edunova_mobile/core/network/api_client.dart';
import 'package:edunova_mobile/core/providers.dart';
import 'package:edunova_mobile/core/realtime/socket_service.dart';
import 'package:edunova_mobile/core/storage/token_storage.dart';
import 'package:edunova_mobile/core/utils/json_utils.dart';
import 'package:edunova_mobile/features/session/data/session_repository.dart';
import 'package:edunova_mobile/features/session/domain/session_models.dart';
import 'package:edunova_mobile/features/session/presentation/play/play_screen.dart';
import 'package:edunova_mobile/features/session/presentation/unfinished_sessions.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Leaving a test means different things depending on whether it is timed.
///
/// A timed test cannot be paused — its clock runs whether the app is open or
/// not — so walking out of one ends it. An untimed test has nothing running,
/// so the student picks: step away and come back, or hand it in for good.

Future<String?> _noToken() async => null;

class _FakeSessionRepository extends SessionRepository {
  _FakeSessionRepository({this.deadline})
      : super(ApiClient(tokenStorage: TokenStorage(), onSessionExpired: () {}));

  final DateTime? deadline;
  Map<int, String>? finishedWith;

  static const _question = {
    'id': 0,
    'question_text': 'Savol',
    'options': [
      {'label': 'A', 'text': 'a'},
      {'label': 'B', 'text': 'b'},
    ],
  };

  @override
  Future<SessionInfo> fetchInfo(int sessionId) async => SessionInfo.fromJson({
        'session_id': sessionId,
        'quiz_id': 1,
        'host_id': 1,
        'join_code': 'ABC123',
        'status': 'running',
        'duration_minutes': deadline == null ? null : 10,
        'questions_count': 2,
        'session_type': 'individual',
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'deadline_at': deadline?.toUtc().toIso8601String(),
      });

  @override
  Future<SessionQuestions> fetchQuestions(int sessionId) async => SessionQuestions.fromJson({
        'session_id': sessionId,
        'quiz_id': 1,
        'status': 'running',
        'deadline_at': deadline?.toUtc().toIso8601String(),
        'questions': [
          {..._question, 'id': 11},
          {..._question, 'id': 12},
        ],
      });

  @override
  Future<Map<int, String>> fetchSavedAnswers(int sessionId) async => const {};

  @override
  Future<void> saveAnswer({
    required int sessionId,
    required int questionId,
    required String label,
  }) async {}

  /// One open session, until the test is handed in — which is what the server
  /// does too: a finished session stops being resumable.
  bool open = true;
  int historyCalls = 0;

  @override
  Future<PageResult<HistoryItem>> fetchHistory({String? search, int page = 1, int size = 50}) async {
    historyCalls++;
    return PageResult(
      items: [
        if (open)
          HistoryItem.fromJson(const {
            'session_id': 7,
            'rank': 1,
            'title': 'Ochiq test',
            'created_at': '2026-09-23T09:00:00Z',
            'status': 'running',
            'attempt_finished': false,
            'answered_count': 1,
            'total_questions': 2,
          }),
      ],
      total: open ? 1 : 0,
      page: 1,
      size: size,
      pages: 1,
    );
  }

  @override
  Future<FinishResult> finish({
    required int sessionId,
    required Map<int, String> answers,
  }) async {
    open = false;
    finishedWith = Map.of(answers);
    return FinishResult.fromJson({
      'session_id': sessionId,
      'total_questions': 2,
      'answered_questions': answers.length,
      'correct_answers': 1,
      'wrong_answers': answers.length - 1,
      'topic_statistic': <Object>[],
    });
  }
}

/// The Android back button, which is the only way out of the play screen.
Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// The default test font gives every glyph the same width, which makes the
/// status bar overflow in the harness though it fits on a phone. A real font
/// keeps the layout honest.
Future<void> loadFonts() async {
  const dir = '/usr/pgadmin4/web/pgadmin/static/fonts';
  if (!Directory(dir).existsSync()) return;
  final loader = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    loader.addFont(File('$dir/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

void main() {
  late SharedPreferences prefs;
  late GoRouter router;

  setUpAll(loadFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<_FakeSessionRepository> open(
    WidgetTester tester, {
    DateTime? deadline,
    bool enter = true,
  }) async {
    final repo = _FakeSessionRepository(deadline: deadline);
    // O'yin ekrani boshqa sahifa ustiga qo'yiladi: uni yopish stekni
    // bo'shatib qo'ymasligi kerak, aks holda router e'tiroz bildiradi.
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final open = ref.watch(unfinishedSessionsProvider).valueOrNull ?? const [];
                return Text('ochiq: ${open.length}');
              },
            ),
          ),
        ),
        GoRoute(path: '/play', builder: (_, __) => const PlayScreen(sessionId: 7)),
        GoRoute(
          path: '/session/:sessionId/result',
          builder: (_, __) => const Scaffold(body: Text('Natija')),
        ),
      ],
    );
    tester.view.physicalSize = const Size(1170, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
        socketFactoryProvider.overrideWithValue(const SocketFactory(_noToken, _noToken)),
      ],
      // Yakunlangach ekran natija sahifasiga o'tadi, shuning uchun router
      // kerak - aks holda o'tish "No GoRouter found" bilan yiqiladi.
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    if (enter) {
      router.push('/play');
      await tester.pumpAndSettle();
    }
    return repo;
  }

  group('an untimed test', () {
    testWidgets('offers stepping away and handing in as separate choices', (tester) async {
      await open(tester);

      await back(tester);

      expect(find.text("Testni to'xtatasizmi?"), findsOneWidget);
      expect(find.text('Chiqib ketish'), findsOneWidget);
      expect(find.text('Yakunlash'), findsOneWidget);
      expect(find.text('Qolish'), findsOneWidget);
    });

    testWidgets('stepping away does not hand the test in', (tester) async {
      final repo = await open(tester);

      await tester.tap(find.text('A').first);
      await tester.pumpAndSettle();
      await back(tester);
      await tester.tap(find.text('Chiqib ketish'));
      await tester.pumpAndSettle();

      // Nothing was scored, so the session is still the student's to come
      // back to.
      expect(repo.finishedWith, isNull);
    });

    testWidgets('handing in scores it', (tester) async {
      final repo = await open(tester);

      await tester.tap(find.text('A').first);
      await tester.pumpAndSettle();
      await back(tester);
      await tester.tap(find.text('Yakunlash'));
      await tester.pumpAndSettle();

      expect(repo.finishedWith, {11: 'A'});
    });
  });

  group('handing a test in', () {
    testWidgets('drops it from the home list without waiting for a refresh', (tester) async {
      // The play screen replaces itself with the result, so the push that
      // opened it never returns: whatever refresh hangs off that future never
      // runs, and the card would sit on the home page until pulled.
      final repo = await open(tester, enter: false);
      expect(find.text('ochiq: 1'), findsOneWidget);

      router.push('/play');
      await tester.pumpAndSettle();
      await tester.tap(find.text('A').first);
      await tester.pumpAndSettle();
      await back(tester);
      await tester.tap(find.text('Yakunlash'));
      await tester.pumpAndSettle();

      expect(repo.finishedWith, isNotNull);

      // Back on the home route the list is already right.
      await back(tester);
      await tester.pumpAndSettle();
      expect(find.text('ochiq: 0'), findsOneWidget);
    });
  });

  group('a timed test', () {
    testWidgets('has no way out that keeps it open', (tester) async {
      await open(tester, deadline: DateTime.now().add(const Duration(minutes: 9)));

      await back(tester);

      expect(find.text('Testni yakunlaysizmi?'), findsOneWidget);
      // Stepping away would be a promise the clock cannot keep.
      expect(find.text('Chiqib ketish'), findsNothing);
      expect(find.text('Yakunlash'), findsOneWidget);
      expect(find.text('Qolish'), findsOneWidget);
    });

    testWidgets('leaving it scores what was answered', (tester) async {
      final repo = await open(tester, deadline: DateTime.now().add(const Duration(minutes: 9)));

      await tester.tap(find.text('A').first);
      await tester.pumpAndSettle();
      await back(tester);
      await tester.tap(find.text('Yakunlash'));
      await tester.pumpAndSettle();

      expect(repo.finishedWith, {11: 'A'});
    });
  });
}
