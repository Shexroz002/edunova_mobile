import 'package:edunova_mobile/core/utils/formatters.dart';
import 'package:edunova_mobile/core/utils/grade.dart';
import 'package:edunova_mobile/features/competition/data/competition_repository.dart';
import 'package:edunova_mobile/features/competition/domain/competition_models.dart';
import 'package:edunova_mobile/features/competition/presentation/lobby_controller.dart';
import 'package:edunova_mobile/features/notifications/domain/app_notification.dart';
import 'package:edunova_mobile/features/session/domain/session_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 3 logic, checked against payloads captured from the live backend
/// on 2026-09-11 (sessions 71 / 72) — see `docs/API_CONTRACT.md`.
void main() {
  group('join codes', () {
    test('are uppercased and stripped, because the backend compares exactly', () {
      // Verified live: the exact code works, the lowercase form returns 404.
      expect(CompetitionRepository.normalizeCode('0o1vhn'), '0O1VHN');
      expect(CompetitionRepository.normalizeCode(' 9jx d8a '), '9JXD8A');
      expect(CompetitionRepository.normalizeCode('ABC123'), 'ABC123');
    });
  });

  group('RoomEvent', () {
    test('accepts both spellings of the ready event', () {
      // The source broadcasts `participant_ready`; an earlier live capture
      // recorded `participant_read`. Both must map to the same event.
      expect(RoomEvent.parse('participant_ready'), RoomEvent.participantReady);
      expect(RoomEvent.parse('participant_read'), RoomEvent.participantReady);
    });

    test('maps the rest of the room events and ignores chat', () {
      expect(RoomEvent.parse('participant_joined'), RoomEvent.participantJoined);
      expect(RoomEvent.parse('participant_disconnected'), RoomEvent.participantDisconnected);
      expect(RoomEvent.parse('session_started'), RoomEvent.sessionStarted);
      expect(RoomEvent.parse('session_finished'), RoomEvent.sessionFinished);
      expect(RoomEvent.parse('chat_message'), RoomEvent.unknown);
      expect(RoomEvent.parse(null), RoomEvent.unknown);
    });
  });

  group('SessionParticipant', () {
    test('parses a participants/ row, treating the offset-less date as UTC', () {
      final participant = SessionParticipant.fromJson({
        'participant_id': 95,
        'nickname': 'shehroz',
        'profile_image': 'http://127.0.0.1:8000/media/avatars/x.jpg',
        'is_host': true,
        'first_name': 'Shehroz',
        'joined_at': '2026-09-11T16:38:41.167808',
        'last_name': "Toshpo'latov",
        'participant_status': 'ready',
        'user_id': 1,
      });

      expect(participant.participantId, 95);
      expect(participant.isHost, isTrue);
      expect(participant.status, ParticipantStatus.ready);
      expect(participant.displayName, "Shehroz Toshpo'latov");
      // Live check: session 71 was created at 21:38 Tashkent time and the row
      // reads 16:38 with no offset, so a naive `joined_at` is UTC — not +05:00.
      expect(participant.joinedAt!.toUtc().hour, 16);
      expect(participant.joinedAt!.toUtc().minute, 38);
    });

    test('falls back to the nickname when no name is set', () {
      final participant = SessionParticipant.fromJson({
        'participant_id': 1,
        'user_id': 2,
        'nickname': 'someone',
        'first_name': null,
        'last_name': '   ',
      });
      expect(participant.displayName, 'someone');
      expect(participant.status, ParticipantStatus.joined, reason: 'unknown status falls back');
    });

    test('builds from a participant_joined frame', () {
      final participant = SessionParticipant.fromJoinedEvent({
        'participant_id': 96,
        'user_id': 3,
        'is_host': false,
        'nickname': 'shehroz2',
        'first_name': 'Doston',
        'last_name': 'Eshmatov',
        'status': 'ready',
        'participants_online': 2,
      });
      expect(participant.displayName, 'Doston Eshmatov');
      expect(participant.status, ParticipantStatus.ready);
    });
  });

  group('LobbyState', () {
    SessionParticipant person(int id, ParticipantStatus status, {bool host = false}) =>
        SessionParticipant(
          participantId: id,
          userId: id,
          nickname: 'u$id',
          isHost: host,
          status: status,
        );

    const info = SessionInfo(
      sessionId: 71,
      quizId: 26,
      hostId: 1,
      joinCode: '0O1VHN',
      status: 'waiting',
      durationMinutes: 5,
      questionsCount: 5,
      type: SessionType.public,
    );

    test('excludes participants who left, because the backend keeps their row', () {
      // Verified live: leave/ returns 204 but the row stays as `disconnected`.
      final state = LobbyState(
        info: info,
        participants: [
          person(1, ParticipantStatus.ready, host: true),
          person(2, ParticipantStatus.ready),
          person(3, ParticipantStatus.disconnected),
        ],
      );

      expect(state.participants, hasLength(3));
      expect(state.present, hasLength(2));
      expect(state.readyCount, 2);
    });

    test('a room of only the host is not a competition', () {
      final state = LobbyState(
        info: info,
        participants: [person(1, ParticipantStatus.ready, host: true)],
      );
      // The backend would happily start this one (participants_count: 1).
      expect(state.present, hasLength(1));
    });
  });

  group('AppNotification', () {
    // Captured verbatim from GET /api/v1/notifications/.
    final competitionResult = {
      'id': 103,
      'type': 'competition_result',
      'action_type': 'open_result',
      'title': 'Competition result',
      'message': 'You finished 2 of 2',
      'is_read': false,
      'created_at': '2026-09-11T13:31:21.792565Z',
      'payload': {
        'session_id': 69,
        'quiz_id': 73,
        'quiz_title': 'Matematika: 1-variant',
        'rank': 2,
        'participants_count': 2,
        'score': 1,
        'total_questions': 20,
        'score_percent': 5.0,
        'wrong_answers': 9,
        'spend_time_seconds': 20,
      },
    };

    test('rebuilds Uzbek text for competition results, which the server sends in English', () {
      final notification = AppNotification.fromJson(competitionResult);

      expect(notification.kind, NotificationKind.competitionResult);
      expect(notification.title, 'Competition result');
      // The web replaces the English title with a fixed Uzbek heading and puts
      // the quiz name inside the congratulation sentence instead.
      expect(notification.displayTitle, 'Musobaqa natijasi');
      expect(notification.quizTitle, 'Matematika: 1-variant');
      expect(notification.rank, 2);
      expect(notification.medalLabel, "2-o'rin medali");
      expect(notification.percentLabel, '5% natija');
      expect(notification.rankMedal, '🥈');
      expect(notification.scorePercent, 5.0);
      expect(notification.resultSessionId, 69);
    });

    test('a competition result without a rank falls back to the web wording', () {
      final bare = AppNotification.fromJson({
        'id': 1,
        'type': 'competition_result',
        'title': 'Competition result',
        'message': 'x',
        'is_read': false,
        'created_at': '2026-09-11T13:31:21.792565Z',
        'payload': {'session_id': 69},
      });
      expect(bare.displayTitle, 'Musobaqa natijasi');
      expect(bare.displayMessage, AppNotification.competitionFallbackMessage);
      expect(bare.medalLabel, isNull);
    });

    test('reads the payload of a test invite and a friend request', () {
      final invite = AppNotification.fromJson({
        'id': 105,
        'type': 'test_invite_notification',
        'action_type': 'test_invite_notification',
        'title': 'Quiz Session  taklif',
        'message': 'Shehroz sizni taklif qilmoqda.',
        'is_read': false,
        'created_at': '2026-09-11T13:30:15.560143Z',
        'payload': {'session_code': '9JXD8A'},
      });
      expect(invite.kind, NotificationKind.testInvite);
      expect(invite.sessionCode, '9JXD8A');
      // Non-competition titles are already Uzbek and stay untouched.
      expect(invite.displayTitle, 'Quiz Session  taklif');

      final friend = AppNotification.fromJson({
        'id': 96,
        'type': 'friend_request',
        'action_type': 'friend_request',
        'title': "Yangi do'st so'rovi",
        'message': 'Shehroz sizga so\'rov yubordi',
        'is_read': true,
        'created_at': '2026-09-11T13:13:47.461561Z',
        'payload': {'friend_id': 2},
      });
      expect(friend.kind, NotificationKind.friendRequest);
      expect(friend.friendId, 2);
      expect(friend.isRead, isTrue);
    });

    test('a socket frame without is_read or created_at counts as unread, dated now', () {
      // The push producer omits both fields; the REST list always has them.
      final before = DateTime.now().toUtc();
      final pushed = AppNotification.fromJson({
        'id': 105,
        'type': 'test_invite_notification',
        'action_type': 'test_invite_notification',
        'title': 'Quiz Session  taklif',
        'message': 'Shehroz Toshpo\'latov sizni birgalikda test ishlashga taklif qilmoqda.',
        'payload': {'session_code': '9JXD8A'},
        'sender': {'id': 1, 'first_name': 'Shehroz', 'last_name': "Toshpo'latov"},
      });

      expect(pushed.isRead, isFalse);
      expect(pushed.createdAt.isBefore(before.subtract(const Duration(seconds: 1))), isFalse);
      expect(pushed.senderName, "Shehroz Toshpo'latov");
    });

    test('an unknown type still renders as a plain notification', () {
      final other = AppNotification.fromJson({
        'id': 1,
        'type': 'achievement',
        'title': 'Yutuq',
        'message': 'Tabriklaymiz',
        'is_read': false,
        'created_at': '2026-09-11T13:13:47.461561Z',
      });
      expect(other.kind, NotificationKind.other);
      expect(other.payload, isEmpty);
      expect(other.sessionCode, isNull);
    });
  });

  group('NotificationFilter', () {
    test('routes every kind to exactly one non-"all" tab', () {
      for (final kind in NotificationKind.values) {
        final tabs = NotificationFilter.values
            .where((f) => f != NotificationFilter.all && f.matches(kind))
            .toList();
        expect(tabs, hasLength(1), reason: '$kind must belong to one tab');
      }
      expect(NotificationFilter.tests.matches(NotificationKind.testInvite), isTrue);
      expect(NotificationFilter.tests.matches(NotificationKind.competitionResult), isTrue);
      expect(NotificationFilter.friends.matches(NotificationKind.friendRequest), isTrue);
      expect(NotificationFilter.system.matches(NotificationKind.other), isTrue);
    });
  });

  group('relative time', () {
    final now = DateTime.utc(2026, 9, 11, 18, 0);

    test('uses the same wording as the web notification list', () {
      expect(formatRelative(now.subtract(const Duration(seconds: 20)), now: now), 'Hozir');
      expect(formatRelative(now.subtract(const Duration(minutes: 5)), now: now), '5 daqiqa oldin');
      expect(formatRelative(now.subtract(const Duration(hours: 2)), now: now), '2 soat oldin');
      // The web has a dedicated "Kecha" step between hours and days.
      expect(formatRelative(now.subtract(const Duration(days: 1)), now: now), 'Kecha');
      expect(formatRelative(now.subtract(const Duration(days: 3)), now: now), '3 kun oldin');
      expect(formatRelative(now.subtract(const Duration(days: 30)), now: now), contains('avgust'));
    });

    test('a clock skew into the future reads as "Hozir", never negative', () {
      expect(formatRelative(now.add(const Duration(minutes: 5)), now: now), 'Hozir');
    });

    test('compact minutes fit a narrow stat tile', () {
      expect(formatMinutesCompact(45), '45 daq');
      expect(formatMinutesCompact(59), '59 daq');
      expect(formatMinutesCompact(60), '1 soat');
      expect(formatMinutesCompact(735), '12 soat');
    });

    test('the short form drops "oldin" so narrow tiles do not truncate', () {
      expect(formatRelativeShort(now.subtract(const Duration(seconds: 20)), now: now), 'hozir');
      expect(formatRelativeShort(now.subtract(const Duration(minutes: 5)), now: now), '5 daq');
      expect(formatRelativeShort(now.subtract(const Duration(hours: 5)), now: now), '5 soat');
      expect(formatRelativeShort(now.subtract(const Duration(days: 3)), now: now), '3 kun');
    });

    test('isToday compares local days', () {
      expect(isToday(now, now: now), isTrue);
      expect(isToday(now.subtract(const Duration(days: 1)), now: now), isFalse);
    });
  });

  group('Grade', () {
    test('uses the four performance words of the web result page', () {
      // getPerformanceLabel: A'lo >= 80, Yaxshi >= 60, Qoniqarli >= 40, else Zaif.
      expect(Grade.of(95).label, "A'lo");
      expect(Grade.of(80).label, "A'lo");
      expect(Grade.of(79.9).label, 'Yaxshi');
      expect(Grade.of(60).label, 'Yaxshi');
      expect(Grade.of(59).label, 'Qoniqarli');
      expect(Grade.of(40).label, 'Qoniqarli');
      expect(Grade.of(39).label, 'Zaif');
      expect(Grade.of(0).label, 'Zaif');
    });

    test('keeps the A+..D letters used by the history cards', () {
      expect(Grade.of(95).letter, 'A+');
      expect(Grade.of(85).letter, 'A');
      expect(Grade.of(65).letter, 'B');
      expect(Grade.of(45).letter, 'C');
      expect(Grade.of(10).letter, 'D');
    });
  });
}
