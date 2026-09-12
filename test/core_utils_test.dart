import 'package:edunova_mobile/core/network/media_url.dart';
import 'package:edunova_mobile/core/storage/token_storage.dart';
import 'package:edunova_mobile/core/utils/difficulty.dart';
import 'package:edunova_mobile/core/utils/json_utils.dart';
import 'package:edunova_mobile/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final apiBase = Uri.parse('http://10.0.2.2:8000');

  group('MediaUrl.resolve', () {
    test('rewrites localhost hosts to the API base', () {
      expect(
        MediaUrl.resolve('http://127.0.0.1:8000/media/avatars/a.jpg', apiBase: apiBase),
        'http://10.0.2.2:8000/media/avatars/a.jpg',
      );
    });

    test('makes relative paths absolute and collapses double slashes', () {
      expect(
        MediaUrl.resolve('media/avatars/a.jpg', apiBase: apiBase),
        'http://10.0.2.2:8000/media/avatars/a.jpg',
      );
      expect(
        MediaUrl.resolve('https://api.myedunova.uz//media/image/q.png', apiBase: apiBase),
        'https://api.myedunova.uz/media/image/q.png',
      );
    });

    test('drops empty values and host-only placeholders', () {
      expect(MediaUrl.resolve(null, apiBase: apiBase), isNull);
      expect(MediaUrl.resolve('  ', apiBase: apiBase), isNull);
      expect(MediaUrl.resolve('http://localhost:8000/', apiBase: apiBase), isNull);
    });
  });

  group('json helpers', () {
    test('asDouble accepts Decimal strings', () {
      expect(asDouble('89.50'), 89.5);
      expect(asDouble(3), 3.0);
      expect(asDouble(null), isNull);
    });

    test('parseTashkentDate treats naive values as UTC+5', () {
      final date = parseTashkentDate('2026-04-01T10:00:00')!;
      expect(date.toUtc(), DateTime.utc(2026, 4, 1, 5));
    });

    test('parseUtcDate keeps explicit offsets', () {
      final date = parseUtcDate('2026-04-01T10:00:00Z')!;
      expect(date.toUtc(), DateTime.utc(2026, 4, 1, 10));
    });

    test('PageResult parses fastapi-pagination shape', () {
      final page = PageResult<int>.fromJson(
        {'items': [{'v': 1}, {'v': 2}], 'total': 5, 'page': 1, 'size': 2, 'pages': 3},
        (json) => json['v'] as int,
      );
      expect(page.items, [1, 2]);
      expect(page.hasMore, isTrue);
    });
  });

  group('AuthUser', () {
    test('parses /auth/me/ nested subjects and detects students', () {
      final user = AuthUser.fromJson({
        'id': 7,
        'username': 'ali',
        'first_name': 'Ali',
        'last_name': 'Valiyev',
        'role': 'schoolboy',
        'subjects': [
          {'id': 1, 'subject': {'id': 3, 'name': 'Matematika', 'type': null, 'icon': '📐'}},
        ],
      });
      expect(user.isStudent, isTrue);
      expect(user.fullName, 'Ali Valiyev');
      expect(user.subjects.single.id, 3);
      expect(AuthUser.fromJson(user.toJson()).subjects.single.name, 'Matematika');
    });

    test('teachers are not students', () {
      final user = AuthUser.fromJson({'id': 1, 'username': 't', 'role': 'teacher'});
      expect(user.isStudent, isFalse);
    });
  });

  group('AuthTokens', () {
    test('reads exp from a JWT', () {
      // Payload: {"sub":"1","exp":4102444800} (2100-01-01).
      const token = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwiZXhwIjo0MTAyNDQ0ODAwfQ.sig';
      const tokens = AuthTokens(accessToken: token, refreshToken: token);
      expect(tokens.accessExpiresAt!.toUtc().year, 2100);
      expect(tokens.isAccessExpiringSoon(), isFalse);
    });
  });

  group('Difficulty.parse', () {
    test('normalizes backend spellings', () {
      expect(Difficulty.parse('oson'), Difficulty.easy);
      expect(Difficulty.parse("o'son"), Difficulty.easy);
      expect(Difficulty.parse('o‘rta'), Difficulty.medium);
      expect(Difficulty.parse("O'rta"), Difficulty.medium);
      expect(Difficulty.parse(' Qiyin '), Difficulty.hard);
      expect(Difficulty.parse(null), Difficulty.unknown);
      expect(Difficulty.parse('???'), Difficulty.unknown);
    });
  });
}
