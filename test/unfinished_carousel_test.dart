import 'dart:io';

import 'package:edunova_mobile/core/network/api_client.dart';
import 'package:edunova_mobile/core/storage/token_storage.dart';
import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/core/utils/json_utils.dart';
import 'package:edunova_mobile/features/home/widgets/unfinished_carousel.dart';
import 'package:edunova_mobile/features/session/data/session_repository.dart';
import 'package:edunova_mobile/features/session/domain/session_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The home page's band of tests the student walked away from.
///
/// It carries only untimed sessions — a timed one cannot be resumed — and it
/// disappears entirely when there are none, rather than showing an empty card
/// on the busiest screen in the app.

Future<void> loadFonts() async {
  const dir = '/usr/pgadmin4/web/pgadmin/static/fonts';
  if (!Directory(dir).existsSync()) return;
  final loader = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    loader.addFont(File('$dir/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

Json openRow({
  required int sessionId,
  required String title,
  String subject = 'Matematika',
  int answered = 3,
  int? total = 10,
  int? limitMinutes,
  String? deadlineAt,
}) =>
    {
      'session_id': sessionId,
      'rank': 1,
      'title': title,
      'subject': subject,
      'created_at': '2026-09-23T09:00:00Z',
      'status': 'running',
      'attempt_finished': false,
      'answered_count': answered,
      'total_questions': total,
      'duration_minutes': limitMinutes,
      'deadline_at': deadlineAt,
    };

Json finishedRow(int sessionId) => {
      'session_id': sessionId,
      'rank': 1,
      'title': 'Yakunlangan test',
      'subject': 'Fizika',
      'created_at': '2026-09-22T09:00:00Z',
      'status': 'finished',
      'attempt_finished': true,
      'correct_answers': 4,
      'wrong_answers': 1,
      'total_questions': 5,
    };

class _FakeRepository extends SessionRepository {
  _FakeRepository(this.rows)
      : super(ApiClient(tokenStorage: TokenStorage(), onSessionExpired: () {}));

  final List<Json> rows;
  int calls = 0;

  @override
  Future<PageResult<HistoryItem>> fetchHistory({String? search, int page = 1, int size = 50}) async {
    calls++;
    return PageResult(
      items: rows.map(HistoryItem.fromJson).toList(),
      total: rows.length,
      page: 1,
      size: size,
      pages: 1,
    );
  }
}

void main() {
  setUpAll(loadFonts);

  Future<void> pump(WidgetTester tester, List<Json> rows) async {
    tester.view.physicalSize = const Size(1170, 1500);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [sessionRepositoryProvider.overrideWithValue(_FakeRepository(rows))],
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(
                body: Padding(padding: EdgeInsets.all(16), child: UnfinishedCarousel()),
              ),
            ),
            GoRoute(
              path: '/session/:sessionId/play',
              builder: (_, state) =>
                  Scaffold(body: Text('play ${state.pathParameters['sessionId']}')),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows nothing at all when no test is open', (tester) async {
    await pump(tester, [finishedRow(1)]);

    expect(find.text('Tugallanmagan'), findsNothing);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('carries an open untimed test, with how far it got', (tester) async {
    await pump(tester, [openRow(sessionId: 7, title: "Kasrlar bo'yicha test")]);

    expect(find.text('Tugallanmagan'), findsOneWidget);
    expect(find.text("Kasrlar bo'yicha test"), findsOneWidget);
    expect(find.text('Matematika · 3/10 javob berilgan'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('Davom ettirish'), findsOneWidget);
  });

  testWidgets('leaves a timed session out — it cannot be resumed', (tester) async {
    await pump(tester, [
      openRow(
        sessionId: 8,
        title: 'Vaqtli test',
        limitMinutes: 30,
        deadlineAt: '2099-01-01T00:00:00Z',
      ),
    ]);

    expect(find.text('Tugallanmagan'), findsNothing);
  });

  testWidgets('a test opened but not answered offers to start it', (tester) async {
    await pump(tester, [openRow(sessionId: 9, title: 'Yangi test', answered: 0, total: 5)]);

    expect(find.text('Boshlash'), findsOneWidget);
    expect(find.textContaining('hali javob berilmagan'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('one card gets no dots; several do', (tester) async {
    await pump(tester, [openRow(sessionId: 1, title: 'Bitta')]);
    // AnimatedContainer is what a dot is made of; the card itself uses none.
    expect(find.byType(AnimatedContainer), findsNothing);

    await pump(tester, [
      openRow(sessionId: 1, title: 'Birinchi'),
      openRow(sessionId: 2, title: 'Ikkinchi'),
      openRow(sessionId: 3, title: 'Uchinchi'),
    ]);
    expect(find.byType(AnimatedContainer), findsNWidgets(3));
  });

  testWidgets('only one card is on screen; the next needs a swipe', (tester) async {
    await pump(tester, [
      openRow(sessionId: 1, title: 'Birinchi'),
      openRow(sessionId: 2, title: 'Ikkinchi'),
    ]);

    expect(find.text('Birinchi'), findsOneWidget);
    expect(find.text('Ikkinchi'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Ikkinchi'), findsOneWidget);
    expect(find.text('Birinchi'), findsNothing);
  });

  testWidgets('the button opens that session', (tester) async {
    await pump(tester, [openRow(sessionId: 42, title: 'Kasrlar')]);

    await tester.tap(find.text('Davom ettirish'));
    await tester.pumpAndSettle();

    expect(find.text('play 42'), findsOneWidget);
  });

  testWidgets('caps the band and points the rest at Natijalar', (tester) async {
    await pump(tester, [
      for (var i = 1; i <= 7; i++) openRow(sessionId: i, title: 'Test $i'),
    ]);

    expect(find.text('Barchasi →'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(5));
  });
}
