import 'package:edunova_mobile/core/realtime/socket_service.dart';
import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/competition/domain/competition_models.dart';
import 'package:edunova_mobile/features/competition/presentation/widgets/join_code_card.dart';
import 'package:edunova_mobile/features/competition/presentation/widgets/lobby_bottom_bar.dart';
import 'package:edunova_mobile/features/competition/presentation/widgets/participants_card.dart';
import 'package:edunova_mobile/features/session/domain/session_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SessionInfo _info({String? quizName = 'Eritmalar haqida Test', String? subject = 'Kimyo'}) {
  return SessionInfo(
    sessionId: 118,
    quizId: 91,
    quizName: quizName,
    subjectName: subject,
    hostId: 2,
    joinCode: 'MYJLOI',
    status: 'waiting',
    durationMinutes: 30,
    questionsCount: 10,
    type: SessionType.public,
  );
}

SessionParticipant _person({
  int userId = 2,
  String name = 'Shehroz',
  String surname = 'Toshpo‘latov',
  bool host = false,
  ParticipantStatus status = ParticipantStatus.ready,
}) {
  return SessionParticipant(
    participantId: userId * 10,
    userId: userId,
    nickname: 'nick$userId',
    isHost: host,
    status: status,
    firstName: name,
    lastName: surname,
  );
}

Future<void> _pump(WidgetTester tester, Widget child, {ThemeData? theme}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('JoinCodeCard', () {
    testWidgets('groups the code and names the session it opens', (tester) async {
      // The quiz used to be named only in the header, which scrolled away, and
      // its length and question count sat in a separate amber card.
      await _pump(tester, JoinCodeCard(info: _info()));

      expect(find.text('MYJ LOI'), findsOneWidget);
      expect(find.text('MYJLOI'), findsNothing);
      expect(find.text('Eritmalar haqida Test'), findsOneWidget);
      expect(find.text('Kimyo'), findsOneWidget);
      expect(find.text('10 ta savol'), findsOneWidget);
      expect(find.text('30 daqiqa'), findsOneWidget);
    });

    testWidgets('survives a session with no quiz name or subject', (tester) async {
      // `quiz_name` and `subject_name` are both nullable in the info response.
      await _pump(tester, JoinCodeCard(info: _info(quizName: null, subject: null)));

      expect(find.text('Test'), findsOneWidget);
      expect(find.text('10 ta savol'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps both actions at the 44 dp floor', (tester) async {
      await _pump(tester, JoinCodeCard(info: _info()));

      for (final icon in [Icons.ios_share_rounded, Icons.copy_rounded]) {
        final button = find.ancestor(of: find.byIcon(icon), matching: find.byType(InkWell)).first;
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(44), reason: '$icon');
        expect(size.height, greaterThanOrEqualTo(44), reason: '$icon');
      }
    });
  });

  group('ParticipantsCard', () {
    testWidgets('counts only the people still in the room', (tester) async {
      // The backend keeps a row for somebody who left, so the count has to skip
      // them — and their row says why rather than showing a status pill on
      // everybody's row.
      await _pump(
        tester,
        ParticipantsCard(
          participants: [
            _person(userId: 2, host: true),
            _person(userId: 5, name: 'Aziza', surname: 'Karimova'),
            _person(
              userId: 7,
              name: 'Bekzod',
              surname: 'Norqulov',
              status: ParticipantStatus.disconnected,
            ),
          ],
          currentUserId: 2,
          onInvite: () {},
        ),
      );

      expect(find.text('2 kishi'), findsOneWidget);
      expect(find.text('Shehroz Toshpo‘latov'), findsOneWidget);
      expect(find.text('Siz'), findsOneWidget);
      expect(find.text('Aziza Karimova'), findsOneWidget);
      expect(find.text('Host'), findsOneWidget);
      expect(find.text('Ulanmagan'), findsOneWidget);
      // The pill that used to read "1/1 tayyor" is gone.
      expect(find.textContaining('tayyor'), findsNothing);
    });

    testWidgets('offers the invite row to a host and hides it from a joiner',
        (tester) async {
      var invited = false;
      await _pump(
        tester,
        ParticipantsCard(
          participants: [_person(host: true)],
          currentUserId: 5,
          onInvite: () => invited = true,
        ),
      );
      expect(find.text('Do‘st qo‘shish'), findsOneWidget);
      await tester.tap(find.text('Do‘st qo‘shish'));
      expect(invited, isTrue);

      await _pump(
        tester,
        ParticipantsCard(participants: [_person(host: true)], currentUserId: 5),
      );
      expect(find.text('Do‘st qo‘shish'), findsNothing);
    });
  });

  group('LobbyBottomBar', () {
    Widget bar({
      bool isHost = true,
      bool canStart = false,
      int presentCount = 1,
      SocketStatus status = SocketStatus.connected,
    }) {
      return LobbyBottomBar(
        isHost: isHost,
        canStart: canStart,
        starting: false,
        presentCount: presentCount,
        socketStatus: status,
        onStart: () async {},
      );
    }

    testWidgets('tells the host what is missing, then that it is ready',
        (tester) async {
      await _pump(tester, bar());
      expect(find.text('Kamida 2 kishi kerak'), findsOneWidget);
      expect(find.text('Testni boshlash'), findsOneWidget);

      await _pump(tester, bar(canStart: true, presentCount: 3));
      expect(find.text('3 ishtirokchi tayyor'), findsOneWidget);
    });

    testWidgets('a joiner waits instead of being offered a start button',
        (tester) async {
      await _pump(tester, bar(isHost: false, presentCount: 3));

      expect(find.text('Testni boshlash'), findsNothing);
      expect(find.text('Tashkilotchi boshlashini kutmoqda'), findsOneWidget);
      expect(find.text('Test boshlanishini kutmoqda'), findsOneWidget);
    });

    testWidgets('a dropped socket takes over the status line but not the button',
        (tester) async {
      // Starting goes over HTTP, so a blipped socket must not disable it.
      await _pump(
        tester,
        bar(canStart: true, presentCount: 3, status: SocketStatus.closed),
      );

      expect(find.text('Ulanish uzildi — qayta ulanmoqda'), findsOneWidget);
      expect(find.text('3 ishtirokchi tayyor'), findsNothing);
      expect(find.text('Testni boshlash'), findsOneWidget);
    });

    testWidgets('renders in light mode too', (tester) async {
      await _pump(tester, bar(canStart: true, presentCount: 2), theme: AppTheme.light());
      expect(tester.takeException(), isNull);
    });
  });
}
